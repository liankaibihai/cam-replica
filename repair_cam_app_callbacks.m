function report=repair_cam_app_callbacks(app,options)
% Atomic repair of this App's known persistent UI slots; never runs them.
arguments
    app
    options.Backup (1,1) logical=true
    options.OutputFolder char=''
    options.DryRun (1,1) logical=false
end
assert(isa(app,'CamReplicaApp') && isvalid(app) && isgraphics(app.Figure),'cam:CallbackApp','请传入仍打开的CamReplicaApp对象。');
assert(~app.Busy && ~app.SimulationMode && ~app.MapEditMode,'cam:CallbackActiveMode', ...
    '请先完成或停止训练/反推/地图编辑；未改变窗口或输入。');
before=cam_app_ui_value_snapshot(app); backupFile=''; reportFile='';
if options.Backup
    folder=options.OutputFolder;
    if isempty(folder), folder=fullfile(fileparts(mfilename('fullpath')),'local','ui_all_callback_backups'); end
    if ~isfolder(folder), mkdir(folder); end
    backup=before.model; metadata=rmfield(before,'model'); %#ok<NASGU>
    stem=tempname(folder); backupFile=[stem '.mat']; reportFile=[stem '_repair.json'];
    save(backupFile,'backup','metadata','-v7'); saved=load(backupFile,'backup','metadata');
    assert(isequaln(saved.backup,before.model) && isequaln(saved.metadata,metadata), ...
        'cam:CallbackBackup','备份回读不一致，未改变回调。');
end
try
    [plan,audit]=cam_app_ui_binding_plan(app);
catch ex
    report=struct('version','cam-all-callback-repair-1','applied',false,'stateUnchanged',true,'backupFile',backupFile, ...
        'errorIdentifier',ex.identifier,'errorMessage',ex.message,'calculationsPerformed',0);
    writeReport(reportFile,report); rethrow(ex);
end
bindings=struct('identity',{},'property',{},'key',{},'method',{},'mode',{},'function',{}); needs=false(1,numel(plan));
for k=1:numel(plan)
    spec=cam_app_ui_spec(plan(k).key);
    bindings(k)=struct('identity',plan(k).identity,'property',plan(k).property,'key',plan(k).key, ...
        'method',spec.method,'mode',spec.mode,'function','cam_app_ui_dispatch');
    needs(k)=~cam_app_ui_callback_matches(plan(k).oldCallback,app,plan(k).key);
end
report=struct('version','cam-all-callback-repair-1','backupFile',backupFile,'reportFile',reportFile, ...
    'bindings',bindings,'audit',audit,'plannedCount',numel(plan),'reboundCount',nnz(needs),'alreadyBound',~any(needs), ...
    'applied',false,'dryRun',options.DryRun,'stateUnchanged',true,'calculationsPerformed',0,'oldWindowRetained',true, ...
    'scope','Main and existing owned detail figures only; all unknown non-framework callback slots cause atomic refusal. No callback/business operation is invoked.');
if ~isempty(audit.unknown)
    report.errorIdentifier='cam:CallbackUnknown'; writeReport(reportFile,report);
    if options.DryRun, return; end
    error('cam:CallbackUnknown','有%d个未知回调，未修改任何绑定。备份：%s；报告：%s',numel(audit.unknown),backupFile,reportFile);
end
if options.DryRun, writeReport(reportFile,report); return; end
changed=plan(needs);
try
    cam_app_apply_ui_bindings(changed);
    assert(isequaln(before,cam_app_ui_value_snapshot(app)),'cam:CallbackStateChanged','状态检查未通过，恢复原绑定。');
catch ex
    rollback=changed;
    for k=1:numel(rollback)
        rollback(k).newCallback=changed(k).oldCallback;
        rollback(k).oldCallback=changed(k).control.(changed(k).property);
    end
    cam_app_apply_ui_bindings(rollback);
    report.errorIdentifier=ex.identifier; report.errorMessage=ex.message;
    report.stateUnchanged=isequaln(before,cam_app_ui_value_snapshot(app)); writeReport(reportFile,report);
    rethrow(ex);
end
report.applied=true; writeReport(reportFile,report);
end
function writeReport(file,report)
if isempty(file), return; end
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'cam:CallbackReport','无法写入回调报告。');
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
