function report=check_force_model_switch_ui(folder)
% Owned hidden UI only. Real callbacks, complete recovery and failure states.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','force_model_switch_20261031','ui'); end
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleanup=onCleanup(@()closeOwn(app));
saved=load(fullfile(root,'outputs','model_mapping_20261031','quality_cubic','result.mat'),'q');
source=saved.q; app.Project=source; app.syncInputs(); app.calculate();
app.History=struct('iteration',0,'score',app.Result.metrics.score); app.HistoryProject=app.Project;
app.OptimizationInfo=struct('reason','saved-ui-fixture'); app.updateDiagnostics();
app.openTraining();
wheel=find(contains(string(app.ParamsTable.Data(:,1)),'主动轮直径')); assert(isscalar(wheel));
app.ParamsTable.Data{wheel,2}=131; app.WeightsTable.Data{1,2}=13;
app.TargetsTable.Data(2,:)=app.TargetsTable.Data(2,:)+[1 2];
app.NodesTable.Data(4,1)=app.NodesTable.Data(4,1)+.2;
app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel);
app.TrainingFields(2).Value=34; app.TrainingFields(3).Value=8; app.TrainingFields(4).Value=15; app.markTrainingDirty();
published=app.Project; publishedResult=app.Result; raw=app.snapshotModelSwitchState();
assert(~app.applyTraining());
assert(isequaln(app.Project,published) && isequaln(app.Result,publishedResult));
assert(isequaln(app.ParamsTable.Data,raw.inputs.ParamsTable) && app.TrainingDirty);
before=app.snapshotModelSwitchState(); push(app.ForceModelSwitchButton);
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') && app.Project.params.bezier.degree==15);
assert(app.Project.routeMapping.forced && ~app.Project.routeMapping.withinTolerance && app.Project.routeMapping.approximate);
fit=app.Project.routeMapping;
assert(contains(app.TrainingInfo.Text,'强制近似改形') && contains(app.TrainingInfo.Text,'RMS') && contains(app.Status.Text,'保形未通过'));
assert(app.Project.params.gearRatio==35 && app.Project.params.wheelDiameter==131 && app.Project.params.weights(1)==13);
assert(isequal(app.Project.targets,before.inputs.TargetsTable) && isequal(app.Project.nodes(1,:),before.inputs.NodesTable(1,:)));
assert(isempty(app.History) && isempty(app.HistoryProject) && isempty(app.OptimizationInfo) && isempty(app.ActualClosureReport));
backupPath=app.ModelSwitchBackupPath; stored=load(backupPath,'backup');
assert(isequaln(stored.backup.state,before.state) && isequaln(stored.backup.inputs,before.inputs));
assert(contains(app.ModelSwitchBackupInfo.Text,backupPath) && strcmp(app.RestoreModelSwitchButton.Enable,'on'));
copyfile(backupPath,fullfile(folder,'force_full_state_backup.mat'));
forcedProject=app.Project; file=fullfile(folder,'forced_project.mat'); app.action('save',file);
assert(isequaln(camdesign.importProject(file),forcedProject));
app.Figure.Position=[50 50 1320 860]; app.resizeLayout(); drawnow;
exportapp(app.Figure,fullfile(folder,'forced_bezier15.png'));
push(app.RestoreModelSwitchButton); restored=app.snapshotModelSwitchState();
assert(isequaln(restored.state,before.state) && isequaln(restored.inputs,before.inputs));
assert(isequal(restored.axesModes,before.axesModes));
assert(isequal(restored.status,before.status) && app.TrainingDirty);
assert(any(contains(string(app.FullLog),'强制近似切换')) && any(contains(string(app.FullLog),'已恢复完整')));
checks={'solar cubic strict reject -> real Bezier15 force -> saved metadata -> full project/result/history/pending inputs restored'};

% The pending rejected model must be independently rebuildable from targets.
assert(app.rebuildCurrentRoute());
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') && app.Project.params.bezier.degree==15);
assert(~app.TrainingDirty && ~isfield(app.Project,'routeMapping') && app.Project.routeRebuild.rebuiltFromTargets);
assert(isequal(app.Project.nodes(1,:),before.inputs.NodesTable(1,:)) && isequal(app.Project.targets,before.inputs.TargetsTable));
assert(app.Project.params.gearRatio==35 && app.Project.params.wheelDiameter==131);
drawnow; exportapp(app.Figure,fullfile(folder,'rebuilt_pending_model.png'));
checks{end+1}='pending failed model can rebuild directly from targets with start, hardware, order and legal settings preserved';

% Valid representation, invalid physical trajectory: publish editable new
% geometry and clear every old cam/score instead of rolling back the model.
line=fixture(); app.Project=line; app.syncInputs(); app.calculate(); app.openTraining();
oldFront=findobj(app.RouteAxes,'Tag','route-front'); oldXY=[oldFront.XData(:),oldFront.YData(:)];
app.ParamsTable.Data{wheel,2}=1; app.invalidate();
app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel);
app.TrainingFields(2).Value=6; app.TrainingFields(3).Value=20; app.TrainingFields(4).Value=3; app.markTrainingDirty();
invalidated=app.snapshotModelSwitchState(); assert(isempty(app.Result) && ~isempty(invalidated.state.LastDisplayResult));
assert(app.applyTraining(true));
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') && isempty(app.Result) && ~app.TrainingDirty);
assert(isempty(app.CamInspectionRecord) && isempty(app.History) && isempty(app.ActualClosureReport));
assert(~isfinite(app.ScoreDisplayData.total) && isempty(app.CrossTable.Data));
assert(isempty(findobj(app.CamAxes,'Type','line')) && isempty(findobj(app.SteeringAxes,'Type','line')));
assert(~isempty(findobj(app.RouteAxes,'Tag','route-front-uncomputed')) && contains(app.Status.Text,'尚未计算'));
assert(all(app.NodesTable.ColumnEditable) && strcmp(app.Buttons(2).Enable,'on'));
file=fullfile(folder,'uncalculated_new_model.mat'); app.action('save',file);
reloaded=camdesign.importProject(file); assert(strcmp(camdesign.routeModel(reloaded.params),'bezier-blend-independent-v1') && reloaded.params.wheelDiameter==1);
drawnow; exportapp(app.Figure,fullfile(folder,'editable_after_physical_failure.png'));
assert(app.restoreModelSwitch()); current=app.snapshotModelSwitchState();
assert(isequaln(current.state,invalidated.state) && isequaln(current.inputs,invalidated.inputs));
assert(isempty(app.Result) && isempty(findobj(app.RouteAxes,'Tag','route-front-uncomputed')));
oldFront=findobj(app.RouteAxes,'Tag','route-front'); assert(isequal([oldFront.XData(:),oldFront.YData(:)],oldXY));
checks{end+1}='physical evaluation failure keeps new model editable/savable, clears stale results, and restores invalidated-result historical plot';

% Incomplete backup files reject before touching any published/raw state.
loaded=load(backupPath,'backup'); backup=loaded.backup; backup.inputs=rmfield(backup.inputs,'TargetsTable');
badFile=fullfile(folder,'incomplete_backup.mat'); save(badFile,'backup'); prior=app.snapshotModelSwitchState(); priorPath=app.ModelSwitchBackupPath;
assert(~app.restoreModelSwitch(badFile)); after=app.snapshotModelSwitchState();
assert(isequaln(prior.state,after.state) && isequaln(prior.inputs,after.inputs) && strcmp(app.ModelSwitchBackupPath,priorPath));
checks{end+1}='incomplete backup rejects atomically before modifying project, results or pending inputs';

% Invalid input cannot be forced, including broken endpoint coefficients.
app.Project=line; app.syncInputs(); app.calculate(); priorProject=app.Project; priorResult=app.Result;
app.ParamsTable.Data{wheel,2}=-1; pending=app.ParamsTable.Data;
assert(~app.applyTraining(true) && isequaln(app.Project,priorProject) && isequaln(app.Result,priorResult));
assert(isequaln(app.ParamsTable.Data,pending));
[bs,~]=camdesign.mapRouteModel(line,'bspline-v1',8,3); app.Project=bs; app.syncInputs(); app.calculate();
priorProject=app.Project; priorResult=app.Result; app.NodesTable.Data(2,1)=app.NodesTable.Data(2,1)+1;
pending=app.NodesTable.Data; app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel);
assert(~app.applyTraining(true) && isequaln(app.Project,priorProject) && isequaln(app.Result,priorResult));
assert(isequaln(app.NodesTable.Data,pending));
checks{end+1}='force refuses invalid hardware and broken source endpoint constraints while preserving raw input and old result';

app.Project=line; app.syncInputs(); app.calculate(); app.TrainingModel.Value='bspline-3'; invoke(app.TrainingModel);
assert(app.applyTraining() && app.Project.routeMapping.withinTolerance && ~app.Project.routeMapping.forced);
assert(strcmp(app.Project.routeMapping.acceptance,'exact'));
assert(contains(app.TrainingInfo.Text,'精确保形'));
assert(strcmp(app.SteeringAxes.XLimMode,'auto') && diff(app.SteeringAxes.XLim)<1000);
app.AlgorithmSelector.Value='auto-tune-v1'; invoke(app.AlgorithmSelector);
assert(strcmp(app.ForceModelSwitchButton.Enable,'off') && ~app.applyTraining(true));
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1'; invoke(app.AlgorithmSelector);
app.setBusy(true); assert(strcmp(app.ForceModelSwitchButton.Enable,'off') && strcmp(app.RestoreModelSwitchButton.Enable,'off')); app.setBusy(false);
app.openTraining(); app.Figure.Position=[50 50 1100 800]; app.resizeLayout(); drawnow;
exportapp(app.Figure,fullfile(folder,'training_actions_narrow.png'));
assert(app.ForceModelSwitchButton.Position(3)>140 && app.ForceModelSwitchButton.Position(4)>=24);
assert(app.RestoreModelSwitchButton.Position(4)>=24 && app.ForceModelSwitchButton.Layout.Row==2);
checks{end+1}='ordinary strict exact mapping remains available; automatic/busy modes disable force and recovery; narrow fixed action rows visible';

report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks}, ...
    'bezier15Fit',fit,'backupPath',backupPath,'screenshots',{{'forced_bezier15.png','rebuilt_pending_model.png','editable_after_physical_failure.png','training_actions_narrow.png'}}, ...
    'scope','Owned hidden UI; no user windows closed, no optimization, and no assertion of exact reproduction of unavailable user input.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fprintf('FORCE_MODEL_SWITCH_UI_PASS checks=%d\n',numel(checks));
end
function invoke(control), callback=control.ValueChangedFcn; callback(control,[]); end
function push(control), callback=control.ButtonPushedFcn; callback(control,[]); end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.bounds=[0 1000 0 1000];
p.params.samples=101; p.params.camSamples=181;
p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end
