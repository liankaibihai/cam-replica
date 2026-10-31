function check_app(folder)
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:AppCheckBatchOnly','请使用独立 batch 运行界面检查。');
if nargin<1, folder=fullfile(root,'outputs','results_panel_20261030','app_regression'); end
if ~isfolder(folder), mkdir(folder); end
fprintf('APP_CHECK_START\n');
app=CamReplicaApp('off'); cleaner=onCleanup(@()delete(app.Figure));
fprintf('APP_CONSTRUCTED\n');
assert(~isempty(app.Result) && isfinite(app.Result.metrics.score));
original=app.TargetsTable.Data;
app.SelectedTargetRow=1; app.modifyPoints('target',1); assert(size(app.TargetsTable.Data,1)==size(original,1)+1);
app.SelectedTargetRow=2; app.modifyPoints('target',-1); assert(isequal(app.TargetsTable.Data,original));
app.Mechanism.Value='flat'; app.calculate();
assert(strcmp(app.Project.params.mechanism,'flat'));
app.Mechanism.Value='rack'; app.calculate();
app.SimulationSource.Value='theoretical'; % Legacy fixed-theory regression; actual contact has its own checks.
app.action('simulate');
assert(app.SimulationMode && ~isempty(app.SimulationResult));
fixedCam=app.SimulationReference.result.cam; originalProject=app.SimulationReference.project;
baseline=app.SimulationResult.sensor;
wheelRow=find(strcmp(app.ParamsTable.Data(:,1),'主动轮直径 / mm'));
app.ParamsTable.Data{wheelRow,2}=1.02*app.ParamsTable.Data{wheelRow,2};
app.invalidate(); app.calculate();
assert(max(vecnorm(app.SimulationResult.sensor-baseline,2,2))>1);
assert(isequaln(fixedCam,app.SimulationReference.result.cam));
assert(strcmp(app.Buttons(8).Enable,'off') && size(app.ParamsTable.Data,1)==10);
app.Figure.Visible='on'; drawnow;
exportapp(app.Figure,fullfile(folder,'fixed_cam_preview.png'));
app.action('simulate');
assert(~app.SimulationMode && isequaln(app.Project,originalProject));
assert(strcmp(app.Buttons(8).Enable,'on') && size(app.ParamsTable.Data,1)==23);
app.Project.params.iterations=2; app.syncInputs(); app.runOptimization();
assert(~app.Busy && ~isempty(app.History));
assert(app.OptimizationInfo.iterations==2 && app.OptimizationInfo.requestedIterations==2);
assert(contains(app.Status.Text,'2/2') && contains(app.Status.Text,'阈值'));
arrow=findobj(app.RouteAxes,'Tag','optimization-direction');
assert(all(isnan(arrow.XData)) && numel(findobj(app.CamAxes,'Tag','cam-center'))==1);
assert(strcmp(app.RouteAxes.Legend.Location,'northwest') && strcmp(app.CamAxes.Legend.Location,'north'));
assert(strcmp(app.RouteAxes.Title.String,'路线与有序打卡点') && contains(app.DirectionStatus.Text,'无有效数据'));
app.Figure.Visible='on'; drawnow;
exportapp(app.Figure,fullfile(folder,'app_preview.png'));
entry=launch_cam_app(); entryCleaner=onCleanup(@()delete(entry.Figure));
assert(isequaln(entry.Project,camdesign.solarTestProject()) && strcmp(entry.Project.params.mechanism,'flat'));
assert(~isempty(entry.Result) && isfinite(entry.Result.metrics.score));
drawnow; exportapp(entry.Figure,fullfile(folder,'launch_solar_flat.png'));
fprintf('SOLAR_LAUNCH_PASS flat=true visits=10 computed=true\n');
fprintf('APP_CHECK_PASS\n');
end
