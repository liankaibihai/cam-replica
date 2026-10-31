function report=repair_cam_app_callbacks(app,options)
% Only rebind the two reported buttons; never calculate, close or reopen.
arguments
    app
    options.Backup (1,1) logical=true
    options.OutputFolder char=''
end
assert(isa(app,'CamReplicaApp') && isvalid(app) && isgraphics(app.Figure),'cam:CallbackApp','请传入仍打开的对象，例如camReplicaApp。');
assert(~app.Busy && ~app.SimulationMode && ~app.MapEditMode,'cam:CallbackActiveMode', ...
    '请先完成或停止训练/反推/地图编辑；本入口不会丢弃这些操作。');
before=app.snapshotModelSwitchState(); seedText=app.AutoTuneSeed.Text; backupFile='';
if options.Backup
    folder=options.OutputFolder;
    if isempty(folder), folder=fullfile(fileparts(mfilename('fullpath')),'local','ui_callback_recovery_backups'); end
    if ~isfolder(folder), mkdir(folder); end
    backup=before; metadata=struct('AutoTuneSeedText',seedText,'purpose','two-button in-place callback repair'); %#ok<NASGU>
    backupFile=[tempname(folder) '.mat']; save(backupFile,'backup','metadata','-v7');
    saved=load(backupFile,'backup','metadata');
    assert(isequaln(saved.backup,before) && isequaln(saved.metadata.AutoTuneSeedText,seedText), ...
        'cam:CallbackBackup','备份回读不一致，未修改回调。');
end
oldApply=app.TrainingApplyButton.ButtonPushedFcn; oldReset=app.TrainingResetButton.ButtonPushedFcn;
alreadyBound=isBound(oldApply,app,'applyTraining') && isBound(oldReset,app,'syncTrainingInputs');
newApply={@cam_app_ui_dispatch,app,'applyTraining'}; newReset={@cam_app_ui_dispatch,app,'syncTrainingInputs'};
try
    app.TrainingApplyButton.ButtonPushedFcn=newApply; app.TrainingResetButton.ButtonPushedFcn=newReset;
    assert(isequaln(before,app.snapshotModelSwitchState()) && isequaln(seedText,app.AutoTuneSeed.Text), ...
        'cam:CallbackStateChanged','重绑改变了状态；已尝试恢复原回调。');
catch ex
    app.TrainingApplyButton.ButtonPushedFcn=oldApply; app.TrainingResetButton.ButtonPushedFcn=oldReset;
    rethrow(ex);
end
bindings=struct('property',{'TrainingApplyButton.ButtonPushedFcn','TrainingResetButton.ButtonPushedFcn'}, ...
    'function',{'cam_app_ui_dispatch','cam_app_ui_dispatch'},'method',{'applyTraining','syncTrainingInputs'}, ...
    'file',{which('cam_app_ui_dispatch'),which('cam_app_ui_dispatch')});
report=struct('version','cam-two-button-callback-repair-1','backupFile',backupFile,'bindings',bindings, ...
    'stateUnchanged',true,'calculationsPerformed',0,'oldWindowRetained',true, ...
    'alreadyBound',alreadyBound, ...
    'scope','Only two training button callback properties changed. Other anonymous callbacks are not repaired; no general hot-reload guarantee. No apply/calculate/optimization action is executed.');
end
function yes=isBound(callback,app,method)
yes=false;
try
    yes=iscell(callback) && numel(callback)==3 && isa(callback{1},'function_handle') ...
        && strcmp(func2str(callback{1}),'cam_app_ui_dispatch') && callback{2}==app && strcmp(callback{3},method);
catch
    % Unreadable old handle metadata is not required for replacement.
end
end
