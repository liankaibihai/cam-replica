function report=check_background_ui(folder)
% Independent small synthetic integration checks, never a course benchmark.
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','parallel_ui_20261031','check_1'); end
assert(~isfolder(folder),'cam:EvidenceExists','已有检查目录，拒绝覆盖。'); mkdir(folder);
checks={}; p=fixture(); app=CamReplicaApp('off',p,false); cleaner=onCleanup(@()evidenceAndClose(app,folder));
app.calculate(); addHistory(app); app.openDiagnostics('crossings'); cam_app_async('install',app);
[plan,audit]=cam_app_ui_binding_plan(app); assert(numel(plan)==75 && isempty(audit.unknown));
menu=findall(app.Figure,'Tag','cam-execution-background'); assert(isscalar(menu) && strcmp(menu.Checked,'on'));
assert(strcmp(cam_app_async('status',app).mode,'background'));
checks{end+1}='existing App and owned detail callbacks plus three named execution-menu actions are complete and repair-auditable';

retained=CamReplicaApp('off',p,false); retainedCleaner=onCleanup(@()closeOwn(retained));
assert(~evalin('base','exist(''camReplicaApp'',''var'')')); assignin('base','camReplicaApp',retained);
baseCleaner=onCleanup(@()evalin('base','clear camReplicaApp'));
retained.Busy=true; found=launch_cam_app();
assert(isequal(found,retained) && isempty(findall(retained.Figure,'Tag','cam-execution-menu')));
retained.Busy=false; found=launch_cam_app();
assert(isequal(found,retained) && isscalar(findall(retained.Figure,'Tag','cam-execution-menu'))); clear baseCleaner;
checks{end+1}='launch reuse installs mode menu only for an idle existing App and leaves an already-busy synchronous session untouched';

baseline=app.snapshotModelSwitchState(); serial=camdesign.evaluate(p,true);
profile clear; profile on; t=tic; push(app.Buttons(4)); submitSeconds=toc(t);
state=getappdata(app.Figure,'camBackgroundJob'); runId=state.runId;
% Defer a terminal callback as if it arrived during a graphics operation.
if cam_app_async('status',app).active
    state.rendering=true; setappdata(app.Figure,'camBackgroundJob',state);
    waitCondition(@()~isempty(getappdata(app.Figure,'camBackgroundJob').deferredTerminal),15);
    assert(app.Busy && isequaln(app.Result,baseline.state.Result));
    state=getappdata(app.Figure,'camBackgroundJob'); state.rendering=false; setappdata(app.Figure,'camBackgroundJob',state);
    cam_app_async('complete',app,state.deferredTerminal);
end
waitDone(app,20); profile off; profileData=profile('info');
names={profileData.FunctionTable.CompleteName}; calls=[profileData.FunctionTable.NumCalls];
mainEvaluations=sum(calls(contains(names,[filesep '+camdesign' filesep 'evaluate.m']))); assert(mainEvaluations==0);
assert(isequaln(app.Result,serial) && isequaln(app.History,baseline.state.History) && ~app.Busy);
assert(isempty(cam_app_async_registry('get',runId)));
unchanged=app.snapshotModelSwitchState(); cam_app_async_receive(struct('runId',runId,'type','progress','iteration',999));
assert(isequaln(unchanged,app.snapshotModelSwitchState()));
checks{end+1}='background calculate equals synchronous result, submission returns, main-thread evaluate count is zero, terminal deferral and retired-token rejection work';

[expected,expectedHistory,expectedInfo]=camdesign.optimize(p,[],'peak-gradient-v2');
app.AlgorithmSelector.Value='peak-gradient-v2'; app.refreshTrainingControls(); profile clear; profile on; push(app.Buttons(5));
% ScoreBasis changes are viewing operations and may not invalidate a job.
choices=app.ScoreBasis.ItemsData; app.ScoreBasis.Value=choices{2}; invokeValue(app.ScoreBasis);
push(app.TrainingShortcut); app.openDiagnostics('score'); waitDone(app,30); profile off;
optimizationProfile=profile('info'); n={optimizationProfile.FunctionTable.CompleteName}; c=[optimizationProfile.FunctionTable.NumCalls];
mainOptimizationEvaluations=sum(c(contains(n,[filesep '+camdesign' filesep 'evaluate.m']))); assert(mainOptimizationEvaluations==0);
assert(strcmp(cam_app_async('status',app).status,'finished'),'%s',jsonencode(cam_app_async('status',app)));
assert(cam_app_async('status',app).summary.resultSaved && isfile(cam_app_async('status',app).summary.resultFile));
assert(isequaln(app.Project.nodes,expected.nodes) && isequaln([app.History.score],[expectedHistory.score]));
assert(strcmp(app.OptimizationInfo.reason,expectedInfo.reason) && app.OptimizationInfo.evaluations==expectedInfo.evaluations);
assert(contains(app.Status.Text,'优化结束') && any(contains(string(app.FullLog),'场界检查覆盖')));
checks{end+1}='one-iteration serial/background search decisions and evaluation ledger agree with zero main-thread evaluate; score-basis/detail navigation remains usable and original completion logs/verdict are retained';

prepared=camdesign.camInspectionData(app.Project,app.Result,[],'refined'); syntheticInfo=app.OptimizationInfo;
syntheticInfo.verification=struct('refinedGrid',struct('valid',true,'metrics',struct('intersectionCount',1)));
profile clear; profile on; app.finishOptimizationDisplay(syntheticInfo,prepared); profile off;
data=profile('info'); n={data.FunctionTable.CompleteName}; c=[data.FunctionTable.NumCalls];
assert(sum(c(contains(n,[filesep '+camdesign' filesep 'evaluate.m'])))==0 && strcmp(app.CamInspectionRecord.source,'refined'));
checks{end+1}='synthetic positive-intersection display trigger reuses a precomputed matching refined record and retains automatic crossing-tab navigation without main-thread evaluation';

app.ParamsTable.Data{1,2}=1; before=app.snapshotModelSwitchState(); picture=routePicture(app);
push(app.Buttons(4)); waitDone(app,20); after=app.snapshotModelSwitchState();
assert(strcmp(cam_app_async('status',app).status,'error') && isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs));
assert(isequaln(picture,routePicture(app)) && contains(app.Status.Text,'未自动重试'));
app.ParamsTable.Data{1,2}=p.params.wheelDiameter;
checks{end+1}='background numerical error retains complete confirmed state, raw invalid input and plotted route; no automatic retry';

before=app.snapshotModelSwitchState(); push(app.Buttons(4)); state=getappdata(app.Figure,'camBackgroundJob');
state.rendering=true; setappdata(app.Figure,'camBackgroundJob',state); app.ParamsTable.Data{1,2}=111;
waitCondition(@()~isempty(getappdata(app.Figure,'camBackgroundJob').deferredTerminal),15);
state=getappdata(app.Figure,'camBackgroundJob'); state.rendering=false; setappdata(app.Figure,'camBackgroundJob',state);
cam_app_async('complete',app,state.deferredTerminal); waitDone(app,20);
status=cam_app_async('status',app); assert(strcmp(status.status,'error') && status.summary.resultSaved);
saved=load(status.summary.resultFile,'outcome'); assert(strcmp(saved.outcome.status,'success') && ~isempty(saved.outcome.result));
assert(isequaln(app.Project,before.state.Project) && isequaln(app.Result,before.state.Result) && app.ParamsTable.Data{1,2}==111);
app.ParamsTable.Data{1,2}=p.params.wheelDiameter;
checks{end+1}='engineering input changed during job prevents overwrite while complete computed outcome is saved before the guard and raw user edit is retained';

% A longer small handwritten source permits real live preview and stop.
wavy=fixture(true); app.Project=wavy; app.syncInputs(); app.calculate(); addHistory(app);
app.AlgorithmSelector.Value='peak-gradient-v2'; app.refreshTrainingControls(); push(app.Buttons(5));
waitPreview(app,30); assert(contains(app.Status.Text,'后台训练预览') && contains(app.ScoreSummary.Text,'预览'));
assert(isgraphics(app.DiagnosticsFigure) && ~isempty(app.ScoreTable.Data));
push(app.TrainingShortcut);
state=getappdata(app.Figure,'camBackgroundJob'); state.rendering=true; setappdata(app.Figure,'camBackgroundJob',state);
stopObservation=struct('active',cam_app_async('status',app).active,'futureState',state.future.State);
fprintf('STOP_REQUEST active=%d futureState=%s\n',stopObservation.active,stopObservation.futureState);
push(app.Buttons(6)); drawnow; exportapp(app.Figure,fullfile(folder,'background_preview.png'));
state=getappdata(app.Figure,'camBackgroundJob'); state.rendering=false; setappdata(app.Figure,'camBackgroundJob',state);
if ~isempty(state.deferredTerminal), cam_app_async('complete',app,state.deferredTerminal); end
waitDone(app,30);
assert(strcmp(cam_app_async('status',app).status,'finished') && strcmp(app.OptimizationInfo.reason,'user_stop'));
assert(app.Result.metrics.geometryChecked && ~isempty(app.History) && app.History(end).stopped);
checks{end+1}='throttled cached preview shows routes/cam/scores and details, normal Stop recovers full-checked best and complete solver history';

app.Project=wavy; app.syncInputs(); app.calculate(); addHistory(app); before=app.snapshotModelSwitchState(); picture=routePicture(app);
push(app.Buttons(5)); waitPreview(app,30);
unrelated=parfeval(backgroundPool,@pause,0,.3);
cancelMenu=findall(app.Figure,'Tag','cam-execution-force-cancel'); cam_invoke_ui_callback(cancelMenu.MenuSelectedFcn,cancelMenu,[]);
waitDone(app,30); wait(unrelated); assert(isempty(unrelated.Error));
after=app.snapshotModelSwitchState(); assert(strcmp(cam_app_async('status',app).status,'canceled'));
assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs) && isequaln(before.axesModes,after.axesModes));
assert(isequaln(picture,routePicture(app)) && contains(app.Status.Text,'没有最终验收'));
drawnow; exportapp(app.Figure,fullfile(folder,'canceled_preview_restored.png'));
checks{end+1}='force cancel after live preview restores model/results/history/raw inputs/graphics and does not cancel an unrelated future';

app.Project=p; app.syncInputs(); app.calculate(); original=app.Result;
push(app.ActualClosureButton); waitDone(app,45);
assert(strcmp(cam_app_async('status',app).status,'finished') && ~isempty(app.ActualClosureReport));
assert(isequaln(original,app.Result) && ~isempty(app.ActualClosureTable.Data));
foreground=findall(app.Figure,'Tag','cam-execution-foreground'); cam_invoke_ui_callback(foreground.MenuSelectedFcn,foreground,[]);
assert(strcmp(cam_app_async('status',app).mode,'foreground')); push(app.Buttons(4)); assert(~app.Busy && isequaln(app.Result,serial));
checks{end+1}='actual-outline closure runs in background and publishes through the existing display; explicit foreground compatibility remains synchronous';

other=CamReplicaApp('off',wavy,false); otherCleaner=onCleanup(@()closeOwn(other)); other.calculate();
cam_app_async('install',other); push(other.Buttons(5)); state=getappdata(other.Figure,'camBackgroundJob');
cam_invoke_ui_callback(other.Figure.CloseRequestFcn,other.Figure,[]);
waitCondition(@()~isgraphics(other.Figure),30);
[parent,name]=fileparts(state.backupFile); assert(isfile(fullfile(parent,[name '-closed.mat'])) && isempty(cam_app_async_registry('get',state.runId)));
destroyed=CamReplicaApp('off',wavy,false); destroyedCleaner=onCleanup(@()closeOwn(destroyed)); cam_app_async('install',destroyed);
push(destroyed.Buttons(5)); state=getappdata(destroyed.Figure,'camBackgroundJob'); delete(destroyed.Figure);
waitCondition(@()isempty(cam_app_async_registry('get',state.runId)),20);
assert(isempty(cam_app_async_registry('get',sprintf('future:%g',state.future.ID))));
checks{end+1}='close requests stop only their own job and save full final state; unexpectedly destroyed figure releases both registry references and its own future';

% Other backends execute one requested iteration only, using the same tiny
% handwritten source. This checks compatibility/return paths, not quality.
backends={'video-four-direction-v1','feasibility-four-direction-v1','fmincon-interior-point-experimental-v1', ...
    'relay-sqp-v1','multistart-relay-sqp-v1','auto-tune-v1'};
assert(isempty(gcp('nocreate'))); ownPool=parpool('Threads',2); ownPoolCleanup=onCleanup(@()delete(ownPool));
id=''; try, cam_app_async_pool('optimize','relay-sqp-v1'); catch ex, id=ex.identifier; end
assert(strcmp(id,'cam:BackgroundPoolConflict') && isvalid(ownPool) && isequal(gcp('nocreate'),ownPool)); clear ownPoolCleanup;
backendReports=struct('algorithm',{},'executor',{},'status',{},'reason',{},'evaluations',{},'displayEvaluationAttempts',{});
for k=1:numel(backends)
    queue=parallel.pool.DataQueue; afterEach(queue,@ignore);
    job=struct('runId',['compat-' num2str(k)],'kind','optimize','project',p,'algorithm',backends{k});
    [pool,executor]=cam_app_async_pool('optimize',backends{k});
    f=parfeval(pool,@cam_app_async_worker,1,job,queue); result=fetchOutputs(f);
    save(fullfile(folder,sprintf('backend_%d.mat',k)),'result','executor','-v7');
    assert(strcmp(result.status,'success'),'Backend %s: %s %s',backends{k},result.errorIdentifier,result.errorMessage);
    assert(result.result.metrics.geometryChecked && ~isempty(result.history));
    if isfield(result.info,'physicalBudget'), assert(result.info.physicalBudget.used<=result.info.physicalBudget.limit); end
    backendReports(end+1)=struct('algorithm',backends{k},'executor',executor,'status',result.status,'reason',result.info.reason, ...
        'evaluations',result.info.evaluations,'displayEvaluationAttempts',result.displayEvaluationAttempts); %#ok<AGROW>
end
checks{end+1}='six remaining backends use preselected thread/process execution with one requested iteration and intact budgets; an existing user Threads pool is refused and preserved';

cam_app_async('mode',app,'background'); app.Project=wavy; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='relay-sqp-v1'; app.refreshTrainingControls(); push(app.Buttons(5));
state=getappdata(app.Figure,'camBackgroundJob'); assert(strcmp(state.executor,'process'));
push(app.Buttons(6)); waitDone(app,45); processStatus=cam_app_async('status',app);
assert(strcmp(processStatus.status,'finished') && strcmp(app.OptimizationInfo.reason,'user_stop') && processStatus.summary.resultSaved);
assert(app.Result.metrics.geometryChecked && app.OptimizationInfo.physicalBudget.used<=app.OptimizationInfo.physicalBudget.limit);
checks{end+1}='process-backed relay accepts cooperative UI stop, returns full checked best, preserves a single bounded ledger and saves its complete outcome';

report=struct('release',version('-release'),'baseline','02489ec4d0b7f2951da6686bc340d22c16c2ae59','checksPassed',numel(checks), ...
    'checks',{checks},'submissionSeconds',submitSeconds,'mainThreadEvaluateCalls',mainEvaluations,'mainThreadOptimizationEvaluateCalls',mainOptimizationEvaluations,'backendReports',backendReports, ...
    'callbackAudit',audit,'stopObservation',stopObservation,'processStop',processStatus,'lastState',cam_app_async('status',app), ...
    'scope','Only handwritten3/6-point inputs and short functional optimization. No course factory/data/MAT, quality/performance comparison or user window. UI+one thread/process job run concurrently; candidates remain serial.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('BACKGROUND_UI_PASS checks=%d mainEvaluate=0 backends=%d\n',numel(checks),numel(backendReports)+1);
end
function ignore(~), end
function invokeValue(control), cam_invoke_ui_callback(control.ValueChangedFcn,control,[]); end
function push(control), cam_invoke_ui_callback(control.ButtonPushedFcn,control,[]); end
function waitDone(app,seconds), waitCondition(@()~cam_app_async('status',app).active,seconds); end
function waitPreview(app,seconds)
waitCondition(@()getappdata(app.Figure,'camBackgroundJob').previewed || ~cam_app_async('status',app).active,seconds);
assert(cam_app_async('status',app).active,'Short synthetic search ended before preview check.');
end
function waitCondition(test,seconds)
t=tic; while ~test() && toc(t)<seconds, drawnow; pause(.02); end; assert(test(),'Timed out waiting for asynchronous state.');
end
function addHistory(app)
app.History=struct('iteration',0,'score',app.Result.metrics.score); app.HistoryProject=app.Project;
app.OptimizationInfo=struct('reason','prior confirmed synthetic history'); app.updateDiagnostics();
end
function picture=routePicture(app)
line=findobj(app.RouteAxes,'Tag','route-front'); picture=struct('x',line.XData,'y',line.YData,'limits',[app.RouteAxes.XLim app.RouteAxes.YLim]);
end
function project=fixture(wavy)
if nargin<1, wavy=false; end
p=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10], ...
    'autoTune',struct('trials',2,'maxIterations',1,'seed',2027,'polishCount',0));
nodes=[200 200;210 350;200 500];
if wavy
    t=linspace(0,1,6)'; nodes=[200+12*sin(2*pi*t),200+300*t]; p.iterations=300;
    p.routeModel='bezier-blend-independent-v1'; p.bezier=struct('type','overlap-bernstein-v1','degree',3,'parameterLength',320);
end
project=struct('schema','cam-replica-1','name','Handwritten background UI fixture','params',p, ...
    'targets',[200 200;210 350;200 500],'nodes',nodes,'provenance','Handwritten synthetic input; no course source.');
end
function closeOwn(app)
if isgraphics(app.Figure)
    state=cam_app_async('status',app); if state.active, cam_app_async('cancel',app); drawnow; end
    if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
    delete(app.Figure);
end
end
function evidenceAndClose(app,folder)
if isgraphics(app.Figure)
    try
        status=cam_app_async('status',app); snapshot=app.snapshotModelSwitchState(); log=app.FullLog; %#ok<NASGU>
        state=[];
        if isappdata(app.Figure,'camBackgroundJob')
            state=getappdata(app.Figure,'camBackgroundJob');
            fields=intersect(fieldnames(state),{'future','completion','queue','control','deferredTerminal'}); state=rmfield(state,fields);
        end
        save(fullfile(folder,'last_session.mat'),'status','snapshot','log','state','-v7');
        fid=fopen(fullfile(folder,'last_session.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid));
        fprintf(fid,'%s\n',jsonencode(struct('status',status,'log',{log}),PrettyPrint=true));
    catch ex, fprintf('EVIDENCE_CAPTURE_ERROR %s\n',ex.message); end
end
closeOwn(app);
end
