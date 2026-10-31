function value=cam_app_async(command,app,varargin)
% External UI service. No class properties or running synchronous solver are
% changed by installing this layer. All UI callbacks remain named cells.
value=[]; valid=isa(app,'CamReplicaApp') && isvalid(app) && isgraphics(app.Figure);
if ~valid
    if strcmp(command,'complete')
        future=varargin{1}; cam_app_async_registry('remove',sprintf('future:%g',future.ID));
    end
    return;
end
state=getState(app); active=~isempty(state) && ismember(state.status,{'queued','running','stopping','finishing'});
switch command
    case 'ui'
        key=varargin{1}; value=true;
        switch key
            case 'execution-background', cam_app_async('mode',app,'background');
            case 'execution-foreground', cam_app_async('mode',app,'foreground');
            case 'execution-force-cancel', cam_app_async('cancel',app);
            case 'action/stop'
                if active, requestStop(app,state,false); else, value=false; end
            case 'closeRequested'
                if active, requestStop(app,state,true); else, value=false; end
            otherwise
                kinds={'action/calculate','action/optimize','checkActualClosure'};
                index=find(strcmp(key,kinds));
                if isempty(index) || app.Busy || app.SimulationMode || app.MapEditMode, value=false; return; end
                % A source update alone must not migrate a user's existing
                % live session. launch/install explicitly activates the UI.
                if ~isappdata(app.Figure,'camAsyncInstalled'), value=false; return; end
                if strcmp(mode(app),'foreground')
                    if index==2 && isappdata(app.Figure,'camCandidateEnabled') && getappdata(app.Figure,'camCandidateEnabled')
                        app.Status.Text='候选并行需要选择后台计算；未启动串行替代任务。'; app.message(app.Status.Text); return;
                    end
                    value=false; return;
                end
                names={'calculate','optimize','actual-closure'};
                try, start(app,names{index});
                catch ex, app.Status.Text=['后台未启动：',ex.message]; app.message(app.Status.Text); end
        end
    case 'install', install(app);
    case 'mode'
        assert(~app.Busy,'cam:BackgroundBusy','请先停止当前任务，再切换执行方式。');
        next=varargin{1}; assert(ismember(next,{'background','foreground'}),'cam:BackgroundMode','未知执行方式。');
        setappdata(app.Figure,'camExecutionMode',next); install(app);
        if strcmp(next,'background'), text='已选择后台计算；数值任务在后台运行，搜索顺序及预算不变。';
        else, text='已选择前台兼容；计算会占用界面，不会自动切回或重复执行。'; end
        app.message(text); app.Status.Text=text; value=next;
    case 'status'
        value=struct('mode',mode(app),'active',active,'status','idle','runId','','kind','','backupFile','');
        if ~isempty(state)
            for field={'status','runId','kind','backupFile'}, value.(field{1})=state.(field{1}); end
            if isfield(state,'summary'), value.summary=state.summary; end
        end
    case 'receive'
        message=varargin{1};
        if ~active || ~strcmp(state.runId,message.runId), return; end
        if state.rendering && strcmp(message.type,'progress'), return; end
        if strcmp(message.type,'ready')
            state.control=message.control; state.status='running';
            if state.stopRequested, send(state.control,true); state.status='stopping'; end
            setState(app,state);
        elseif strcmp(message.type,'progress')
            if state.rendering || message.sequence<=state.lastSequence, return; end
            if state.stopRequested, acknowledge(state); return; end
            preview(app,state,message);
        end
    case 'cancel'
        if ~active, return; end
        state.forceCanceled=true; state.stopRequested=true; state.status='stopping'; setState(app,state);
        if isfield(state,'candidateWorkers') && state.candidateWorkers>0
            requestStop(app,state,false);
            app.Status.Text='候选并行正在结算当前批次，随后取消发布并恢复原状态；不遗弃已启动的物理尝试。'; return;
        end
        if ~isempty(state.future), cancel(state.future); end
        app.Status.Text='已强制取消本次后台任务；保留原结果与历史，本次没有最终验收。';
    case 'complete'
        future=varargin{1};
        if ~active || isempty(state.future) || future.ID~=state.future.ID, return; end
        if state.rendering, state.deferredTerminal=future; setState(app,state); return; end
        finish(app,state,future);
    otherwise, error('cam:BackgroundCommand','Unknown background UI command.');
end
end
function start(app,kind)
assert(~app.hasPendingTrainingInputs(),'cam:TrainingPending','请先“保形应用”或“还原”待应用训练输入；原结果和输入保留。');
if strcmp(kind,'optimize')
    reason=app.optimizationBlockedReason(); assert(isempty(reason),'cam:OptimizationBlocked','%s',reason);
end
assert(exist('backgroundPool','builtin')==5 || ~isempty(which('backgroundPool')),'cam:BackgroundUnavailable', ...
    '本机后台计算不可用；可在“计算执行方式”菜单明确选择前台兼容。');
candidate=app.inputProject(); assertPlain(candidate);
n=0;
if strcmp(kind,'optimize') && isappdata(app.Figure,'camCandidateEnabled') && getappdata(app.Figure,'camCandidateEnabled')
    assert(ismember(app.AlgorithmSelector.Value,{'feasibility-four-direction-v1','relay-sqp-v1','multistart-relay-sqp-v1'}), ...
        'cam:CandidateBackend','候选并行目前只支持可行性四方向及接力中的四方向阶段。请选择支持的方法或关闭开关。');
    n=2; if isappdata(app.Figure,'camCandidateWorkers'), n=getappdata(app.Figure,'camCandidateWorkers'); end
end
[~,executor]=cam_app_async_pool(kind,app.AlgorithmSelector.Value,false,n);
if n>0, executor='process'; end
[~,runId]=fileparts(tempname); runId=['cam-' runId];
folder=fullfile(fileparts(mfilename('fullpath')),'local','background_jobs'); if ~isfolder(folder), mkdir(folder); end
backup=app.snapshotModelSwitchState(); backup.reason=['background-' kind]; %#ok<NASGU>
backupFile=fullfile(folder,[runId '.mat']); save(backupFile,'backup','-v7');
state=struct('runId',runId,'kind',kind,'status','queued','future',[],'completion',[],'queue',[], ...
    'control',[],'stopRequested',false,'forceCanceled',false,'closeAfterStop',false,'backupFile',backupFile, ...
    'before',backup,'beforeStopRequested',app.StopRequested,'priorModelBackup',app.ModelSwitchBackupPath, ...
    'priorBackupText',app.ModelSwitchBackupInfo.Text,'priorBackupTooltip',app.ModelSwitchBackupInfo.Tooltip, ...
    'priorSeedText',app.AutoTuneSeed.Text,'rendering',false,'deferredTerminal',[],'lastSequence',0,'previewed',false, ...
    'expected',struct('Project',app.Project,'Result',app.Result,'History',app.History),'executor',executor,'candidateWorkers',n);
job=struct('runId',runId,'kind',kind,'project',candidate,'algorithm',app.AlgorithmSelector.Value,'candidateWorkers',n);
queue=parallel.pool.DataQueue; afterEach(queue,@cam_app_async_receive); state.queue=queue; setState(app,state);
entry=struct('runId',runId,'app',app,'future',[]); cam_app_async_registry('put',runId,entry);
app.StopRequested=false; app.setBusy(true);
try
    if strcmp(executor,'process')
        app.Status.Text='正在准备后台进程池；首次启动可能等待数秒。此时尚未执行数值任务，不会失败后重复运行算法。';
        app.message(app.Status.Text); drawnow;
    end
    assert(isgraphics(app.Figure),'cam:BackgroundClosed','窗口已关闭，任务未提交。');
    [pool,~,created]=cam_app_async_pool(kind,job.algorithm,true,n);
    if created, app.message('已创建单worker后台进程池；仅一个任务拥有搜索预算，后续可复用。'); end
    future=parfeval(pool,@cam_app_async_worker,1,job,queue);
    state=getState(app); state.future=future; setState(app,state); entry.future=future;
    cam_app_async_registry('put',runId,entry); cam_app_async_registry('put',sprintf('future:%g',future.ID),entry);
    if state.forceCanceled, cancel(future); end
    app.Status.Text=['后台任务已提交（',executor,'）；搜索仍按原顺序执行，路线/凸轮/评分按节流周期预览。'];
    if strcmp(kind,'actual-closure')
        app.ResultsTabs.SelectedTab=app.ActualClosureTab;
        app.ActualClosureStatus.Text='后台检查实际轮廓闭环；可停止，原检查记录保留至完成。';
    end
    completion=afterAll(future,@cam_app_async_complete,0,'PassFuture',true);
    % afterAll may run immediately for an already-finished future. Merge
    % only into a still-active state; never overwrite ready/terminal flags.
    if isgraphics(app.Figure)
        state=getState(app);
        if strcmp(state.runId,runId) && ismember(state.status,{'queued','running','stopping'})
            state.completion=completion; setState(app,state);
        end
        install(app);
    end
catch ex
    if ~isempty(state.future), cancel(state.future); cam_app_async_registry('remove',sprintf('future:%g',state.future.ID)); end
    cam_app_async_registry('remove',runId);
    if isgraphics(app.Figure), state.status='error'; setState(app,state); app.setBusy(false); end
    rethrow(ex);
end
end
function preview(app,state,message)
state.rendering=true; state.lastSequence=message.sequence; setState(app,state);
try
    current=app.snapshotModelSwitchState();
    assert(sameEngineeringInputs(current.inputs,state.before.inputs),'cam:BackgroundInputsChanged','任务期间输入已改变，暂停预览。');
    if ~isempty(message.result)
        app.Project=message.project; app.Result=message.result;
        app.History=message.history; app.HistoryProject=message.project;
        app.OptimizationInfo=struct('algorithm',message.algorithm,'backgroundPreview',true,'reason','running');
        app.OptimizationDirection=message.last;
        app.render(); % No optimizationUpdate/drawnow/re-evaluation here.
        app.refreshTrainingRuntime();
        app.ScoreSummary.Text=['后台预览（待最终验收）',newline,app.ScoreSummary.Text];
        app.LengthSummary.Text=['后台预览 · ',app.LengthSummary.Text];
        state=getState(app); state.previewed=true;
        state.expected=struct('Project',app.Project,'Result',app.Result,'History',app.History); setState(app,state);
    end
    state=getState(app);
    if ~state.stopRequested && isempty(state.deferredTerminal)
        app.Status.Text=[sprintf('后台训练预览（非最终验收）· 第 %d 轮 · %.1f 秒\n',message.iteration,message.elapsedSeconds),app.Status.Text];
    end
catch ex
    app.message(['后台预览未刷新：',ex.identifier,' ',ex.message]);
    state=getState(app); state.previewed=true; setState(app,state); % Restore even a partial render.
end
state=getState(app); state.rendering=false; pending=state.deferredTerminal; state.deferredTerminal=[]; setState(app,state);
acknowledge(state);
if ~isempty(pending), finish(app,state,pending); end
end
function acknowledge(state)
if ~isempty(state.control), send(state.control,struct('type','preview-ack')); end
end
function finish(app,state,future)
state.status='finishing'; state.rendering=true; setState(app,state); install(app);
status='error'; text=''; outcome=[]; resultFile='';
try
    if isempty(future.Error)
        outcome=fetchOutputs(future);
        [folder,name]=fileparts(state.backupFile); resultFile=fullfile(folder,[name '-result.mat']);
        save(resultFile,'outcome','-v7');
    end
    if state.forceCanceled || ~isempty(future.Error)
        if state.forceCanceled || strcmp(future.Error.identifier,'parallel:fevalqueue:ExecutionCancelled')
            status='canceled'; text='后台任务已取消；原结果、历史和输入保留，本次没有最终验收。';
        else, text=['后台未完成：',future.Error.message,'；原结果保留，可明确选择前台兼容后重试。']; end
    else
        % Preserve completed work BEFORE any UI/token/input/publication guard.
        % A rejected publication must not discard a fully computed candidate.
        assert(strcmp(outcome.runId,state.runId),'cam:BackgroundToken','后台任务标识不匹配。');
        if strcmp(outcome.status,'error')
            text=['后台未完成：',outcome.errorIdentifier,' ',outcome.errorMessage,'；原结果与历史保留。未自动重试。'];
        elseif strcmp(outcome.status,'stopped')
            status='stopped'; text='后台任务已正常停止；原结果与历史保留，本次没有最终验收。';
        else
            current=app.snapshotModelSwitchState();
            assert(sameEngineeringInputs(current.inputs,state.before.inputs) && isequaln(current.state.Project,state.expected.Project) ...
                && isequaln(current.state.Result,state.expected.Result) && isequaln(current.state.History,state.expected.History), ...
                'cam:BackgroundInputsChanged','任务期间输入或已确认结果改变，未覆盖当前状态。');
            state.previewed=true; publish(app,outcome); status='finished';
            text=sprintf('后台%s完成，用时 %.2f 秒；图形已刷新。',kindText(state.kind),outcome.elapsedSeconds);
            if strcmp(state.kind,'optimize')
                if isfield(outcome.info,'reason') && strcmp(outcome.info.reason,'user_stop')
                    text='后台训练正常停止；已收回算法完整检查的保留候选，最终验收结论见训练记录。';
                end
                text=[text,sprintf(' 显示计算 %d 次，后处理 %d 次（与搜索预算分列）。',outcome.displayEvaluationAttempts,outcome.postProcessingEvaluations)];
            end
        end
    end
catch ex
    text=['后台结果未发布：',ex.identifier,' ',ex.message];
end
latest=getState(app); state.closeAfterStop=latest.closeAfterStop;
if ~strcmp(status,'finished') && state.previewed
    if ~restorePreview(app,state), text=[text,'；自动恢复失败，完整备份：',state.backupFile]; end
end
app.Busy=false; app.StopRequested=state.beforeStopRequested; app.refreshControls();
if ~strcmp(status,'finished'), app.Status.Text=text; end
app.message(text);
state.status=status; state.rendering=false; state.summary=struct('message',text,'postProcessingEvaluations',0,'displayEvaluationAttempts',0,'previewPackets',state.lastSequence, ...
    'resultFile',resultFile,'resultSaved',~isempty(resultFile) && isfile(resultFile),'executor',state.executor);
if ~isempty(outcome)
    state.summary.postProcessingEvaluations=outcome.postProcessingEvaluations;
    state.summary.displayEvaluationAttempts=outcome.displayEvaluationAttempts;
    if ~state.summary.resultSaved, state.unpublishedOutcome=outcome; end
end
cam_app_async_registry('remove',state.runId); cam_app_async_registry('remove',sprintf('future:%g',future.ID));
state.future=[]; state.completion=[]; state.control=[]; state.queue=[]; state.deferredTerminal=[]; state.before=[]; setState(app,state); install(app);
if state.closeAfterStop
    backup=app.snapshotModelSwitchState(); backup.reason='background-close'; %#ok<NASGU>
    [parent,name]=fileparts(state.backupFile); save(fullfile(parent,[name '-closed.mat']),'backup','-v7');
    app.closeRequested();
end
end
function restored=restorePreview(app,state)
% Retain new raw edits/tab selections, but restore confirmed model/history
% and its graphics. This is also used for errors after a partial publication.
backup=state.before; current=app.snapshotModelSwitchState();
backup.inputs=current.inputs; backup.controlsTab=current.controlsTab; backup.resultsTab=current.resultsTab;
[folder,name]=fileparts(state.backupFile); file=fullfile(folder,[name '-rollback.mat']); save(file,'backup','-v7');
app.Busy=false; restored=app.restoreModelSwitch(file);
app.ModelSwitchBackupPath=state.priorModelBackup;
app.ModelSwitchBackupInfo.Text=state.priorBackupText; app.ModelSwitchBackupInfo.Tooltip=state.priorBackupTooltip;
app.AutoTuneSeed.Text=state.priorSeedText;
end
function publish(app,outcome)
switch outcome.kind
    case {'calculate','optimize'}
        app.Project=outcome.project; app.Result=outcome.result;
        if strcmp(outcome.kind,'optimize')
            app.History=outcome.history; app.HistoryProject=outcome.project;
            app.OptimizationInfo=outcome.info; app.OptimizationDirection=[];
            app.syncInputs();
        end
        app.render(); app.syncTrainingInputs();
        if strcmp(outcome.kind,'optimize'), app.finishOptimizationDisplay(outcome.info,outcome.refinedInspection); end
    case 'actual-closure', publishClosure(app,outcome);
end
end
function publishClosure(app,outcome)
app.presentActualClosure(outcome.project,outcome.result,outcome.report,outcome.simulation);
end
function requestStop(app,state,closeAfter)
state.stopRequested=true; state.closeAfterStop=state.closeAfterStop || closeAfter; state.status='stopping';
app.StopRequested=true; if ~isempty(state.control), send(state.control,true); end
setState(app,state); app.Status.Text='已请求停止后台任务；完成当前数值调用后回收结果。可在计算执行方式菜单强制取消。';
end
function equal=sameEngineeringInputs(a,b)
% ScoreBasis and the read-only actual-weight column are display state, not
% project input. updateDiagnostics legitimately changes these in previews.
if isfield(a,'ScoreBasis'), a=rmfield(a,'ScoreBasis'); end
if isfield(b,'ScoreBasis'), b=rmfield(b,'ScoreBasis'); end
if isfield(a,'WeightsTable'), a.WeightsTable=a.WeightsTable(:,1:2); end
if isfield(b,'WeightsTable'), b.WeightsTable=b.WeightsTable(:,1:2); end
equal=isequaln(a,b);
end
function install(app)
setappdata(app.Figure,'camAsyncInstalled',true);
root=findall(app.Figure,'Type','uimenu','Tag','cam-execution-menu');
assert(numel(root)<=1,'cam:BackgroundMenu','执行方式菜单身份不唯一。');
if isempty(root)
    root=uimenu(app.Figure,'Text','计算执行方式','Tag','cam-execution-menu');
    definitions={'后台计算（界面可操作）','cam-execution-background','execution-background'; ...
        '前台兼容（可能等待）','cam-execution-foreground','execution-foreground'; ...
        '强制取消本次后台任务','cam-execution-force-cancel','execution-force-cancel'};
    for k=1:size(definitions,1)
        uimenu(root,'Text',definitions{k,1},'Tag',definitions{k,2},'MenuSelectedFcn',cam_app_ui_callback(app,definitions{k,3}));
    end
end
state=getState(app); active=~isempty(state) && ismember(state.status,{'queued','running','stopping'});
for item=root.Children'
    if strcmp(item.Tag,'cam-execution-force-cancel'), item.Enable=active;
    else
        item.Enable=~app.Busy;
        expected=['cam-execution-' mode(app)]; item.Checked=strcmp(item.Tag,expected);
    end
end
end
function value=mode(app)
value='background'; if isappdata(app.Figure,'camExecutionMode'), value=getappdata(app.Figure,'camExecutionMode'); end
end
function state=getState(app)
state=[]; if isappdata(app.Figure,'camBackgroundJob'), state=getappdata(app.Figure,'camBackgroundJob'); end
end
function setState(app,state), setappdata(app.Figure,'camBackgroundJob',state); end
function text=kindText(kind)
switch kind, case 'calculate', text='计算'; case 'optimize', text='训练'; otherwise, text='闭环检查'; end
end
function assertPlain(value)
if isstruct(value)
    names=fieldnames(value); for index=1:numel(value), for k=1:numel(names), assertPlain(value(index).(names{k})); end, end
elseif iscell(value), for k=1:numel(value), assertPlain(value{k}); end
else
    assert(isnumeric(value) || islogical(value) || ischar(value) || isstring(value),'cam:BackgroundData','后台只接收普通项目数据，不能传入App、图形对象或回调。');
end
end
