function report=check_training_actual_crossings()
% Render a preserved, genuinely failing dense cam candidate; no optimization.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:TrainingBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','training_controls_20261030');
source=fullfile(folder,'sensitivity_300','cold_degree7_forward005.mat');
assert(isfile(source),'The preserved sensitivity candidate is required.');
stored=load(source,'q','info'); project=stored.q;
project.params.samples=4313; project.params.camSamples=5761;
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app));
app.Project=project; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1'; app.refreshTrainingControls();
tabs=app.TrainingModel.Parent.Parent.Parent; tabs.SelectedTab=app.TrainingModel.Parent.Parent;
marker=findobj(app.CamAxes,'Tag','cam-self-intersections');
assert(app.Result.metrics.intersectionCount==8 && isscalar(marker) && numel(marker.XData)==8);
assert(isequal([marker.XData(:),marker.YData(:)],app.Result.intersectionPoints));
assert(app.Result.metrics.minUndercutMargin<0 && contains(app.Status.Text,'有指标超限'));
assert(isequal(app.Status.FontColor,[.65 .28 .08]));
[~,bounds]=camdesign.trajectoryBounds(app.Result.route,project.params.bounds);
app.Status.Text=['真实加密失败示例 · ',app.Status.Text];
app.message('真实失败示例：独立贝塞尔7阶，实际凸轮8个自交，欠切未通过；非工程可用候选。');
drawnow; exportapp(app.Figure,fullfile(folder,'actual_cam_crossings.png')); pause(.15); drawnow;
exportapp(app.Figure,fullfile(folder,'actual_cam_crossings.png'));
report=struct('release',version('-release'),'source',source,'historicalSourceReadOnly',true, ...
    'routeSamples',4313,'camSamples',5761,'metrics',app.Result.metrics, ...
    'intersectionPairs',app.Result.intersectionPairs,'intersectionPoints',app.Result.intersectionPoints, ...
    'renderedMarkerCount',numel(marker.XData),'sampledCentersOutsideMM',bounds.maximumOutsideMM, ...
    'failedCandidate',true,'scope','Actual dense failed cam display only, no optimizer run or manufacturing/vehicle approval.');
if isfield(stored,'info') && isfield(stored.info,'nominalDifferenceStepMM')
    report.originalNominalDifferenceStepMM=stored.info.nominalDifferenceStepMM;
end
fid=fopen(fullfile(folder,'actual_cam_crossings_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('ACTUAL_CAM_CROSSINGS_PASS markers=8 pressure=%.6f hit=%.6f undercut=%.6g outsideMM=%.6g failedCandidate=true\n', ...
    app.Result.metrics.maxPressureDeg,app.Result.metrics.maxHitError,app.Result.metrics.minUndercutMargin,bounds.maximumOutsideMM);
end
function closeOwn(app)
if isgraphics(app.Figure), delete(app.Figure); end
end
