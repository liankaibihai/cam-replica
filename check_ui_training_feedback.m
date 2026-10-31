function report=check_ui_training_feedback(folder)
% Handwritten geometry and real synthetic UI only; no course or optimization.
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','ui_training_feedback_20261031','check_1'); end
assert(~isfolder(folder),'cam:EvidenceExists','检查目录已存在，请另选新目录。'); mkdir(folder);
profile clear; profile on; checks={}; project=fixture(); original=project;

% Preserve ordinary/default automatic-growth semantics, including the old
% AllowApproximate API. Only the explicit fixed-count policy changes it.
[ordinary,fit]=camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3);
[explicit,explicitFit]=camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3,AllowControlPointIncrease=true);
[legacyForce,legacyFit]=camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3,AllowApproximate=true);
assert(isequaln(ordinary,explicit) && isequaln(fit,explicitFit) && isequaln(ordinary,legacyForce));
assert(size(ordinary.nodes,1)==12 && fit.requestedControlPointCount==6 && fit.actualControlPointCount==12);
assert(strcmp(fit.method,'existing-exact-representation') && fit.withinTolerance && legacyFit.allowControlPointIncrease);
assert(isequaln(project,original));
checks{end+1}='ordinary strict and legacy approximate defaults still grow back to the original exact representation without changing the source';

[fixed,fixedFit]=camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3, ...
    AllowApproximate=true,AllowControlPointIncrease=false);
assert(size(fixed.nodes,1)==6 && numel(fixedFit.attempts)==1 && ~fixedFit.automaticallyIncreasedCount);
assert(fixedFit.forced && ~fixedFit.withinTolerance && ~fixedFit.allowControlPointIncrease);
assert(fixedFit.finiteGeometry && fixedFit.endpointConstraintsSatisfied);
assert(isequaln(locked(fixed),locked(project)) && isequaln(fixed.targets,project.targets));
T=project.params.bezier.parameterLength; [ends,velocity]=camdesign.routeGeometry(project.nodes,project.params,[0;T]);
[newEnds,newVelocity]=camdesign.routeGeometry(fixed.nodes,fixed.params,[0;T]);
assert(max(abs(ends-newEnds),[],'all')<1e-7 && max(abs(velocity-newVelocity),[],'all')<1e-7);
u=linspace(0,T,3003)'; F=camdesign.routeGeometry(project.nodes,project.params,u); Q=camdesign.routeGeometry(fixed.nodes,fixed.params,u);
independentMax=max(vecnorm(F-Q,2,2)); assert(independentMax>.05);
checks{end+1}='explicit same-model fixed-count reshape returns exactly six controls on the first fit, with truthful errors and unchanged endpoint/physical constraints';

cubic=fixture('cubic');
[different,df]=camdesign.mapRouteModel(cubic,'bezier-blend-independent-v1',6,3,AllowApproximate=true,AllowControlPointIncrease=false);
assert(size(different.nodes,1)==6 && strcmp(camdesign.routeModel(different.params),'bezier-blend-independent-v1') && numel(df.attempts)==1);
[bsDefault,bsDefaultFit]=camdesign.mapRouteModel(cubic,'bspline-v1',4,3);
[bsFixed,bsFixedFit]=camdesign.mapRouteModel(cubic,'bspline-v1',4,3,AllowApproximate=true,AllowControlPointIncrease=false);
assert(size(bsDefault.nodes,1)>4 && bsDefaultFit.shapePreservationGuaranteed);
assert(size(bsFixed.nodes,1)==4 && numel(bsFixedFit.attempts)==1 && ~bsFixedFit.automaticallyIncreasedCount);
assert(bsFixedFit.endpointConstraintsSatisfied && isequaln(locked(bsFixed),locked(cubic)));
checks{end+1}='cross-model force honors requested count; B-spline exact embedding cannot bypass the fixed-count policy while the strict default still embeds exactly';

expect(@()camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,7,AllowApproximate=true,AllowControlPointIncrease=false),'cam:RouteMappingCount');
expect(@()camdesign.mapRouteModel(cubic,'bspline-v1',3,3,AllowApproximate=true,AllowControlPointIncrease=false),'cam:RouteMappingCount');
expect(@()camdesign.mapRouteModel(project,'cubic',251,3,AllowApproximate=true,AllowControlPointIncrease=false),'cam:RouteMappingCount');
expect(@()camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3,AllowControlPointIncrease=false),'cam:RouteMappingTolerance');
expect(@()camdesign.mapRouteModel(project,'bezier-blend-independent-v1',6,3,AllowApproximate=true,AllowControlPointIncrease=false,PositionMaxToleranceMM=1),'cam:RouteMappingToleranceSettings');
expect(@()camdesign.applyTrainingSettings(project,struct(),'auto-tune-v1',struct('AllowControlPointIncrease',false)),'cam:ForceManualOnly');
expect(@()camdesign.applyTrainingSettings(project,struct(),'auto-tune-v1',struct('AllowApproximate',true)),'cam:ForceManualOnly');
expect(@()camdesign.applyTrainingSettings(project,struct('controlPointCount',6,'interpolationPerSegment',1), ...
    'feasibility-four-direction-v1',struct('AllowApproximate',true,'AllowControlPointIncrease',false)),'cam:TrainingSamples');
[auto,autoInfo]=camdesign.applyTrainingSettings(project,struct(),'auto-tune-v1');
assert(strcmp(camdesign.routeModel(auto.params),camdesign.routeModel(project.params)) && auto.params.bezier.degree==project.params.bezier.degree);
assert(autoInfo.fitInfo.allowControlPointIncrease && isequaln(locked(auto),locked(project)) && isequaln(project,original));
bad=project; bad.nodes(3,1)=NaN; expectAny(@()camdesign.mapRouteModel(bad,'bezier-blend-independent-v1',6,3,AllowApproximate=true,AllowControlPointIncrease=false));
bad=bsDefault; bad.nodes(2,1)=bad.nodes(2,1)+1;
expect(@()camdesign.mapRouteModel(bad,'bezier-blend-independent-v1',6,3,AllowApproximate=true,AllowControlPointIncrease=false),'cam:EndpointConstraint');
checks{end+1}='illegal degree/count, count cap, density, endpoints, nonfinite data and relaxed thresholds refuse; automatic caller retains its model/degree and cannot use manual override';

app=CamReplicaApp('off',project,false); cleaner=onCleanup(@()closeOwn(app));
app.DynamicWeightsEnabled.Value=true; invokeValue(app.DynamicWeightsEnabled);
app.AlgorithmSelector.Value='feasibility-four-direction-v1'; invokeValue(app.AlgorithmSelector);
app.calculate(); app.openTraining(); addHistory(app);
before=app.snapshotModelSwitchState();
assert(strcmp(app.Buttons(5).Enable,'off') && app.DynamicWeightsEnabled.Value);
assert(contains(app.MethodSummary.Text,'动态权重') && contains(app.MethodSummary.Text,'权重') && contains(app.MethodSummary.Text,'取消勾选'));
assert(contains(app.TrainingInfo.Text,'优化不可用') && isequal(app.ControlsTabs.SelectedTab,app.TrainingTab));
expect(@()app.runOptimization(),'cam:OptimizationBlocked'); push(app.Buttons(5));
after=app.snapshotModelSwitchState(); assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs));
assert(contains(app.Status.Text,'动态权重') && app.DynamicWeightsEnabled.Value && ~app.Busy);
app.Figure.Position=[30 30 1120 860]; app.resizeLayout(); drawnow;
exportapp(app.Figure,fullfile(folder,'blocked_dynamic_weights.png'));
app.DynamicWeightsEnabled.Value=false; invokeValue(app.DynamicWeightsEnabled);
assert(strcmp(app.Buttons(5).Enable,'on') && ~contains(app.MethodSummary.Text,'优化不可用'));
for backend={'fmincon-interior-point-experimental-v1','relay-sqp-v1','multistart-relay-sqp-v1'}
    app.AlgorithmSelector.Value=backend{1}; app.DynamicWeightsEnabled.Value=true; app.refreshTrainingControls();
    assert(strcmp(app.Buttons(5).Enable,'off') && contains(app.MethodSummary.Text,'动态权重'));
    expect(@()app.runOptimization(),'cam:OptimizationBlocked');
end
app.DynamicWeightsEnabled.Value=false; app.AlgorithmSelector.Value='feasibility-four-direction-v1'; app.refreshTrainingControls(); app.calculate(); addHistory(app);
checks{end+1}='real synthetic UI shows persistent actionable dynamic-weight conflict and preflight matches disabled optimization; only explicit user checkbox edit resolves it';

app.TrainingFields(2).Value=6; invokeValue(app.TrainingFields(2)); assert(app.TrainingDirty);
before=app.snapshotModelSwitchState(); push(app.Buttons(4)); push(app.Buttons(5));
after=app.snapshotModelSwitchState(); assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs));
assert(contains(app.Status.Text,'保形应用') && app.TrainingFields(2).Value==6 && ~isempty(app.Result) && ~isempty(app.History));
assert(contains(app.TrainingInfo.Text,'请求 6') && strcmp(app.Buttons(5).Enable,'off'));
push(app.TrainingResetButton); assert(~app.TrainingDirty);
app.TrainingFields(2).Value=6; assert(~app.TrainingDirty && app.hasPendingTrainingInputs());
before=app.snapshotModelSwitchState(); push(app.Buttons(4)); push(app.Buttons(5));
after=app.snapshotModelSwitchState(); assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs));
assert(~app.TrainingDirty && app.TrainingFields(2).Value==6 && ~isempty(app.Result) && ~isempty(app.History));
push(app.TrainingResetButton); app.TrainingModel.Value='cubic'; assert(~app.TrainingDirty && app.hasPendingTrainingInputs());
before=app.snapshotModelSwitchState(); push(app.Buttons(4));
after=app.snapshotModelSwitchState(); assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs)); push(app.TrainingResetButton);
checks{end+1}='calculate/optimize reject pending field or model input before clearing result/history; raw value changes without ValueChanged are caught and preserved';

app.TrainingFields(2).Value=6; invokeValue(app.TrainingFields(2)); push(app.TrainingApplyButton);
assert(~app.TrainingDirty && size(app.Project.nodes,1)==12 && app.Project.routeMapping.requestedControlPointCount==6);
assert(contains(app.TrainingInfo.Text,'请求 6 → 实际 12') && contains(app.TrainingInfo.Text,'未减点'));
assert(contains(app.Status.Text,'请求 6 → 实际 12') && contains(app.Status.Text,'未减点'));
assert(strcmp(app.TrainingApplyButton.Text,'保形应用') && strcmp(app.ForceModelSwitchButton.Text,'强制调整（允许改形）'));
drawnow; exportapp(app.Figure,fullfile(folder,'strict_count_retained.png'));
checks{end+1}='real ordinary apply retains strict preservation and visibly states requested six, actual twelve and why reduction was not achieved';

app.TrainingFields(2).Value=6; invokeValue(app.TrainingFields(2));
app.ParamsTable.Data{1,2}=111; app.WeightsTable.Data{1,2}=9; addHistory(app); app.updateDiagnostics();
expected=app.inputProject(true); before=app.snapshotModelSwitchState(); push(app.ForceModelSwitchButton);
assert(~app.TrainingDirty && size(app.Project.nodes,1)==6 && app.TrainingFields(2).Value==6);
uiFit=app.Project.routeMapping; assert(~uiFit.allowControlPointIncrease && uiFit.forced && numel(uiFit.attempts)==1);
assert(isequaln(locked(app.Project),locked(expected)) && isequaln(app.Project.targets,expected.targets));
assert(contains(app.TrainingInfo.Text,'请求 6 → 实际 6') && contains(app.TrainingInfo.Text,'强制近似改形'));
assert(contains(app.Status.Text,'请求 6 → 实际 6') && contains(app.Status.Text,'保形未通过'));
saved=load(app.ModelSwitchBackupPath,'backup'); assert(isequaln(saved.backup.state,before.state) && isequaln(saved.backup.inputs,before.inputs));
copyfile(app.ModelSwitchBackupPath,fullfile(folder,'synthetic_full_backup.mat'));
drawnow; exportapp(app.Figure,fullfile(folder,'forced_requested_count.png'));
push(app.RestoreModelSwitchButton); after=app.snapshotModelSwitchState();
assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs) && isequaln(before.axesModes,after.axesModes));
assert(app.TrainingFields(2).Value==6 && app.TrainingDirty && size(app.Project.nodes,1)==12);
checks{end+1}='real force button applies exactly requested six controls with truthful error report, backs up full pending state and restores project/result/history/raw inputs exactly';

profile off; data=profile('info'); names={data.FunctionTable.CompleteName}; calls=[data.FunctionTable.NumCalls];
forbidden={'defaultProject','teamSolarProject','solarTestProject','optimize','optimizeSearch','optimizeFeasibilityFour','optimizeRelay','optimizeMultistartRelay','optimizeFmincon','optimizeAuto'};
counts=struct();
for k=1:numel(forbidden)
    counts.(forbidden{k})=sum(calls(contains(names,[filesep '+camdesign' filesep forbidden{k} '.m']))); assert(counts.(forbidden{k})==0);
end
counts.evaluate=sum(calls(contains(names,[filesep '+camdesign' filesep 'evaluate.m']))); assert(counts.evaluate>0);
report=struct('release',version('-release'),'baseline','9d96c0664d9b50cda36f8659c3134a2d37534cab','checksPassed',numel(checks), ...
    'checks',{checks},'strictFit',fit,'fixedFit',fixedFit,'differentModelFit',df,'bsplineDefaultFit',bsDefaultFit, ...
    'bsplineFixedFit',bsFixedFit,'uiFit',uiFit,'independentPositionMaxMM',independentMax,'profilerCounts',counts, ...
    'scope','Handwritten small synthetic inputs, geometry mapping and real UI application/restore. All optimization and course factories have zero calls. No competition data, user window, quality comparison or native mouse gesture claim.');
save(fullfile(folder,'synthetic_results.mat'),'report','project','fixed','different','bsFixed');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('UI_TRAINING_FEEDBACK_PASS checks=%d strict=6->%d fixed=%d ui=%d optimizerCalls=0 courseFactories=0 syntheticEvaluateCalls=%d\n', ...
    numel(checks),fit.actualControlPointCount,fixedFit.actualControlPointCount,uiFit.actualControlPointCount,counts.evaluate);
end
function invokeValue(control), cam_invoke_ui_callback(control.ValueChangedFcn,control,[]); end
function push(control), cam_invoke_ui_callback(control.ButtonPushedFcn,control,[]); end
function expect(callback,wanted)
id=''; try, callback(); catch ex, id=ex.identifier; end; assert(strcmp(id,wanted),'Expected %s, got %s',wanted,id);
end
function expectAny(callback), failed=false; try, callback(); catch, failed=true; end; assert(failed); end
function p=locked(project)
p=project.params; allowed={'routeModel','routeSpline','bezier','bspline','training','samples','iterations','gradientProbeMM'};
p=rmfield(p,intersect(fieldnames(p),allowed));
end
function addHistory(app)
app.History=struct('iteration',0,'score',app.Result.metrics.score); app.HistoryProject=app.Project;
app.OptimizationInfo=struct('reason','synthetic retained history'); app.updateDiagnostics();
end
function project=fixture(mode)
if nargin<1, mode='bezier-blend-independent-v1'; end
p=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',221,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
p.routeModel=mode;
if strcmp(mode,'cubic'), nodes=[200 200;225 350;200 500];
else
    t=linspace(0,1,12)'; nodes=[200+18*sin(2*pi*t)+8*sin(6*pi*t),200+300*t];
    p.bezier=struct('type','overlap-bernstein-v1','degree',3,'parameterLength',320);
    p.training=struct('version','independent-training-v1','interpolationPerSegment',20,'densityManaged',true, ...
        'bezierDegree',3,'learningRate',1,'smoothingRate',0,'adjustInterval',10,'adjustExponent',0);
end
project=struct('schema','cam-replica-1','name','Handwritten feedback fixture','params',p, ...
    'targets',[200 200;210 350;200 500],'nodes',nodes,'provenance','Handwritten synthetic input only.');
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
