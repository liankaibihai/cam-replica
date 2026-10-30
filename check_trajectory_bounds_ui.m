function report=check_trajectory_bounds_ui()
% Own batch app only. One-iteration runs test status wiring, not solve quality.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:BoundsBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','trajectory_bounds_20261029');
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
assert(strcmp(app.AlgorithmSelector.Value,'peak-gradient-v2'));
positive=camdesign.defaultProject(); positive.params.mechanism='flat';
positive.params.sensorX=0; positive.params.sensorY=0; positive.params.bounds=[0 1000 0 1000];
positive.nodes=[200 200;200 450;200 700]; positive.targets=positive.nodes;
app.Project=positive; app.syncInputs(); app.calculate();
assert(thresholdsPassed(app) && contains(app.Status.Text,'五点中心出界 0 mm'));
assert(isequal(app.Status.FontColor,[.12 .20 .30]));
checks{end+1}='in-bounds analytic route reports zero sampled-center excursion';

source=fullfile(root,'outputs','route_refinement_20261029','convergence_300', ...
    'refined_twice_fmincon-interior-point-experimental-v1.mat');
saved=load(source,'q'); candidate=saved.q;
candidate.params.iterations=1;
% Keep the existing threshold-passing candidate close during this UI-only
% peak integration run. These are fixture settings, not production changes.
candidate.params.stepMM=1e-6; candidate.params.gradientProbeMM=1e-6;
app.Project=candidate; app.syncInputs(); app.calculate();
assert(thresholdsPassed(app));
[~,initial]=camdesign.trajectoryBounds(app.Result.route,app.Project.params.bounds);
assert(initial.maximumOutsideMM>100 && contains(app.Status.Text,'有指标超限'));
assert(isequal(app.Status.FontColor,[.65 .28 .08]));
capture(app,folder,'historical34_render.png');
checks{end+1}='render flags center excursion even when historical metric thresholds pass';

app.runOptimization();
assert(thresholdsPassed(app) && strcmp(app.OptimizationInfo.algorithm,'peak-gradient-v2'));
assert(contains(app.Status.Text,'未达标候选') && contains(app.Status.Text,'五点中心出界'));
assert(~contains(app.Status.Text,'本模型检查通过') && isequal(app.Status.FontColor,[.65 .28 .08]));
[~,peak]=camdesign.trajectoryBounds(app.Result.route,app.Project.params.bounds);
assert(peak.maximumOutsideMM>100 && app.OptimizationInfo.requestedIterations==1);
assert(any(cellfun(@(text)contains(text,'不含车宽与整车外廓'),app.Log.Value)));
peakStatus=app.Status.Text; capture(app,folder,'historical34_peak_end.png');
checks{end+1}='default peak ending rejects center violation without changing its objective or movement policy';

candidate=saved.q; candidate.params.iterations=1;
app.Project=candidate; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1'; app.runOptimization();
assert(contains(app.Status.Text,'五点中心出界'));
assert(isfield(app.OptimizationInfo.verification.refinedGrid,'maxTrajectoryOutsideMM'));
if ~app.OptimizationInfo.verifiedFeasible
    assert(contains(app.Status.Text,'未达标候选') && isequal(app.Status.FontColor,[.65 .28 .08]));
end
constrainedStatus=app.Status.Text; capture(app,folder,'historical34_constrained_end.png');
checks{end+1}='constrained ending displays the refined-grid center excursion and honors the new final gate';

report=struct('release',version('-release'),'checks',{checks}, ...
    'initialOutsideMM',initial.maximumOutsideMM,'peakOutsideMM',peak.maximumOutsideMM, ...
    'peakStatus',peakStatus,'constrainedStatus',constrainedStatus, ...
    'constrainedVerifiedFeasible',app.OptimizationInfo.verifiedFeasible, ...
    'constrainedRefinedOutsideMM',app.OptimizationInfo.verification.refinedGrid.maxTrajectoryOutsideMM, ...
    'scope','Status/callback integration with one requested iteration only; no optimization-quality conclusion or complete-body certification.');
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('TRAJECTORY_BOUNDS_UI_CASE_PASS %s\n',checks{k}); end
fprintf('TRAJECTORY_BOUNDS_UI_PASS cases=%d peakOutsideMM=%.9f\n',numel(checks),peak.maximumOutsideMM);
end
function passed=thresholdsPassed(app)
m=app.Result.metrics; p=app.Project.params;
passed=m.maxHitError<=p.hitTolerance && m.maxPressureDeg<=p.maxPressureDeg ...
    && m.maxSteeringDeg<=p.maxSteeringDeg && m.minUndercutMargin>0 && m.intersectionCount==0;
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow;
exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if isgraphics(app.Figure), delete(app.Figure); end
end
