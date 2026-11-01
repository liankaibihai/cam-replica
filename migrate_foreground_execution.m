function report=migrate_foreground_execution(app)
% Explicit idle-window migration; never starts, cancels or resumes work.
assert(isa(app,'CamReplicaApp') && isvalid(app) && isgraphics(app.Figure),'cam:ForegroundApp','窗口无效。');
assert(~app.Busy && ~app.MapEditMode && ~app.SimulationMode,'cam:ForegroundBusy','请先完成当前任务或退出编辑/反推。');
if isappdata(app.Figure,'camBackgroundJob')
    old=getappdata(app.Figure,'camBackgroundJob');
    assert(isempty(old) || ismember(old.status,{'finished','error','canceled','stopped'}), ...
        'cam:ForegroundBusy','旧任务尚未结束，未迁移窗口。');
end
if isappdata(app.Figure,'camForegroundInstalled')
    cam_candidate_ui(app,'install'); report=struct('alreadyInstalled',true); return;
end
before=app.snapshotModelSwitchState(); backup=before; %#ok<NASGU>
folder=fullfile(fileparts(mfilename('fullpath')),'local','foreground_migration'); if ~isfolder(folder), mkdir(folder); end
file=[tempname(folder) '.mat']; save(file,'backup','-v7');
menu=findall(app.Figure,'Type','uimenu','Tag','cam-execution-menu');
assert(numel(menu)<=1,'cam:ForegroundIdentity','旧执行菜单不唯一。');
if ~isempty(menu)
    assert(isequal(menu.Parent,app.Figure) && strcmp(menu.Text,'计算执行方式'),'cam:ForegroundIdentity','旧菜单身份不匹配。');
    delete(menu);
end
for name={'camBackgroundJob','camExecutionMode','camAsyncInstalled'}
    if isappdata(app.Figure,name{1}), rmappdata(app.Figure,name{1}); end
end
setappdata(app.Figure,'camCandidateEnabled',true); setappdata(app.Figure,'camCandidateWorkers',4);
cam_candidate_ui(app,'install'); setappdata(app.Figure,'camForegroundInstalled',true);
after=app.snapshotModelSwitchState();
assert(isequaln(before,after),'cam:ForegroundState','迁移改变了工程状态；备份：%s',file);
report=struct('alreadyInstalled',false,'backupFile',file,'stateUnchanged',true,'candidateEnabled',true,'workers',4);
end
