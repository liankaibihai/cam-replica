function report=check_training_controls_ui(folder)
% Owned hidden app only. Short callback checks, not convergence/vehicle proof.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:TrainingBatchOnly','请使用独立 batch。');
if nargin<1, folder=fullfile(root,'outputs','results_panel_20261030','training_regression'); end
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
app.SimulationSource.Value='theoretical'; % Preserve legacy theoretical-mode UI regression.
assert(numel(app.TrainingFields)==9 && ~isfield(app.Project.params,'training'));
assert(strcmp(app.TrainingFields(4).Enable,'off') && strcmp(app.TrainingFields(5).Enable,'on'));
solar=camdesign.solarTestProject(); app.Project=solar; app.syncInputs(); app.calculate();
callback=app.TrainingShortcut.ButtonPushedFcn; callback(app.TrainingShortcut,[]); tabs=app.ControlsTabs;
assert(tabs.SelectedTab==app.TrainingTab);
setField(app,'iterations',3); setField(app,'controlPointCount',18); setField(app,'interpolationPerSegment',12);
setField(app,'gradientForce',.25); setField(app,'learningRate',.8); setField(app,'smoothingRate',.2);
setField(app,'adjustInterval',4); setField(app,'adjustExponent',.5);
assert(app.TrainingDirty && isequaln(app.Project,solar));
rejected=false;
try, app.inputProject(); catch ex, rejected=strcmp(ex.identifier,'cam:TrainingPending'); end
assert(rejected && app.applyTraining());
assert(size(app.Project.nodes,1)==18 && app.Project.params.samples==205 && app.Project.params.iterations==3);
settings=camdesign.trainingSettings(app.Project);
assert(settings.gradientForce==.25 && settings.learningRate==.8 && settings.smoothingRate==.2 ...
    && settings.adjustInterval==4 && settings.adjustExponent==.5);
assert(isequal(app.Project.targets,solar.targets) && ~app.TrainingDirty);
assert(contains(app.TrainingInfo.Text,'18 控制点 / 205 路线采样'));
capture(app,folder,'training_cubic.png');
checks{end+1}='nine-field panel applies actual node/sample counts and search settings; pending edits cannot be ignored';

before=app.Project; setField(app,'learningRate',-1);
assert(~app.applyTraining() && isequaln(app.Project,before) && app.TrainingDirty);
app.syncTrainingInputs(); assert(~app.TrainingDirty && app.TrainingFields(6).Value==.8);
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1';
callback=app.AlgorithmSelector.ValueChangedFcn; callback(app.AlgorithmSelector,[]);
assert(strcmp(app.TrainingFields(5).Enable,'on') && all(arrayfun(@(field)strcmp(field.Enable,'off'),app.TrainingFields(6:9))));
setField(app,'learningRate',1); assert(~app.applyTraining() && contains(app.Status.Text,'内点法'));
app.syncTrainingInputs();
setField(app,'gradientForce',1); assert(app.applyTraining() && app.Project.params.gradientProbeMM==1);
checks{end+1}='invalid settings stay pending; constrained backend disables and rejects unsupported search changes';

app.TrainingModel.Value='bezier-blend-independent-v1'; callback=app.TrainingModel.ValueChangedFcn; callback(app.TrainingModel,[]);
assert(strcmp(app.TrainingFields(4).Enable,'on'));
mappingSource=app.Project; requestedBezierCount=50; bezierDensity=11;
setField(app,'controlPointCount',requestedBezierCount); setField(app,'bezierDegree',15);
setField(app,'interpolationPerSegment',bezierDensity); setField(app,'iterations',1);
assert(app.applyTraining());
actualBezierCount=size(app.Project.nodes,1); actualBezierSamples=(actualBezierCount-1)*bezierDensity+1;
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') ...
    && actualBezierCount>=requestedBezierCount && app.Project.params.bezier.degree==15 ...
    && app.Project.params.samples==actualBezierSamples);
assert(contains(app.TrainingInfo.Text,'独立贝塞尔') && contains(app.MapEditHelp.Text,'不必穿过'));
assert(isequal(app.Project.targets,solar.targets) && numel(app.Result.route.u)==actualBezierSamples);
assertPanelSettings(app); assertOperationInvariants(mappingSource,app.Project);
mapping=app.Project.routeMapping;
assert(mapping.requestedControlPointCount==requestedBezierCount && mapping.actualControlPointCount==actualBezierCount);
mappingAudit=assertMappingWithinTolerance(mappingSource,app.Project,mapping);
bezier=app.Project; bezierResult=app.Result; capture(app,folder,'training_bezier_constrained.png');
checks{end+1}='strict degree-15 Bezier mapping may increase requested controls; actual count/density and all panel fields agree, with independent position/tangent checks';

camdesign.saveProject(app.inputProject(),fullfile(folder,'ui_training_project.mat'));
loaded=camdesign.importProject(fullfile(folder,'ui_training_project.mat'));
assert(isequaln(loaded,app.Project) && isequaln(camdesign.trainingSettings(loaded),camdesign.trainingSettings(app.Project)));
app.Project=loaded; app.syncInputs(); app.calculate();
assert(strcmp(app.TrainingFields(5).Enable,'on') && all(arrayfun(@(field)strcmp(field.Enable,'off'),app.TrainingFields(6:9))));
assertPanelSettings(app);
checks{end+1}='all nine settings/model metadata survive project save/import and UI synchronization';

% A strict mapping may already use the maximum count. Delete one interior
% control first, then exercise a real insert/delete round trip with capacity.
app.SelectedNodeRow=6; app.modifyPoints('node',-1);
assert(isempty(app.Result) && size(app.Project.nodes,1)==actualBezierCount-1);
assert(isequal(app.Project.nodes,bezier.nodes([1:5 7:end],:)));
assertPanelSettings(app); assertOperationInvariants(bezier,app.Project); app.calculate();
editableBezier=app.Project; editableResult=app.Result; editableCount=size(editableBezier.nodes,1);
app.SelectedNodeRow=5; app.modifyPoints('node',1);
assert(size(app.Project.nodes,1)==editableCount+1 && app.Project.params.samples==editableCount*bezierDensity+1);
midpoint=(editableBezier.nodes(5,:)+editableBezier.nodes(6,:))/2;
assert(isequal(app.Project.nodes,[editableBezier.nodes(1:5,:);midpoint;editableBezier.nodes(6:end,:)]));
assertPanelSettings(app); assertOperationInvariants(editableBezier,app.Project);
app.SelectedNodeRow=6; app.modifyPoints('node',-1); assert(isempty(app.Result)); app.calculate();
assert(isequaln(app.Project,editableBezier) && max(vecnorm(app.Result.route.front-editableResult.route.front,2,2))<1e-8);
assertPanelSettings(app);
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
assert(app.MapEditMode && strcmp(app.TrainingApplyButton.Enable,'off') && ~app.applyTraining());
app.previewRouteNode(app.Project.nodes(2,:)+[1 0],app.RouteAxes); app.confirmRouteNode();
assert(~app.MapEditMode && contains(app.MapEditHelp.Text,'贝塞尔'));
[start,tangent]=camdesign.bezierRoute(app.Project.nodes,app.Project.params,0);
assert(norm(start-bezier.nodes(1,:))<1e-9 && norm(tangent-[0 1])<1e-10);
tabs.SelectedTab=app.NodesTable.Parent.Parent; capture(app,folder,'bezier_control_points.png');
checks{end+1}='Bezier controls can be inserted/deleted/moved with real count/density updates and a fixed initial tangent';

rebuildSource=app.Project; rebuildSettings=camdesign.trainingSettings(app.inputProject());
app.action('seed');
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') ...
    && size(app.Project.nodes,1)==rebuildSettings.controlPointCount && app.Project.params.bezier.degree==15 ...
    && app.Project.params.samples==(rebuildSettings.controlPointCount-1)*rebuildSettings.interpolationPerSegment+1);
assert(isequaln(camdesign.trainingSettings(app.Project),rebuildSettings));
assert(app.Project.routeRebuild.rebuiltFromTargets && app.Project.routeRebuild.startPointUnchanged ...
    && app.Project.routeRebuild.targetOrderUnchanged && ~app.Project.routeRebuild.shapePreservationGuaranteed ...
    && app.Project.routeRebuild.requestedControlPointCount==rebuildSettings.controlPointCount ...
    && app.Project.routeRebuild.actualControlPointCount==size(app.Project.nodes,1));
assertPanelSettings(app); assertOperationInvariants(rebuildSource,app.Project);
rebuildCalculationAvailable=~isempty(app.Result); rebuildCalculationError=''; rebuildStatus=app.Status.Text;
if ~rebuildCalculationAvailable
    % A target-seeded reshape does not promise a physically valid cam. This
    % fixture can trigger the unchanged reverse-wheel gate; prove rejection
    % rather than treating the previous cam as a result for the new route.
    camdesign.validateProject(app.Project);
    try, camdesign.evaluate(app.Project,true); catch ex, rebuildCalculationError=ex.identifier; end
    assert(strcmp(rebuildCalculationError,'cam:ReverseWheel') && contains(rebuildStatus,'新路线已应用') ...
        && contains(rebuildStatus,'凸轮尚未计算'));
end
% Exercise simulation controls with the independently checked, computable
% strict mapping, regardless of the explicit reshape's physical outcome.
app.Project=bezier; app.Result=bezierResult; app.syncInputs(); app.calculate();
assert(isequaln(app.Project,bezier) && ~isempty(app.Result)); assertPanelSettings(app);
app.setBusy(true); assert(all(arrayfun(@(field)strcmp(field.Enable,'off'),app.TrainingFields)) && ~app.applyTraining());
app.setBusy(false); app.toggleSimulation(); assert(strcmp(app.TrainingApplyButton.Enable,'off') && ~app.applyTraining());
app.toggleSimulation();
checks{end+1}='rebuild retains explicit trained count/model; busy and simulation modes disable training changes';

fixture=camdesign.defaultProject(); fixture.params.mechanism='flat'; fixture.params.samples=101;
fixture.params.camSamples=181; fixture.params.gearRatio=2; fixture.params.autoRatio=false;
fixture.params.sensorX=0; fixture.params.sensorY=0; fixture.params.bounds=[0 1000 0 1000];
fixture.nodes=[200 200;195 450;200 700]; fixture.targets=[200 200;200 450;200 700];
app.Project=fixture; app.syncInputs(); app.calculate(); app.AlgorithmSelector.Value='peak-gradient-v2'; app.refreshTrainingControls();
setField(app,'iterations',1); setField(app,'interpolationPerSegment',50); setField(app,'gradientForce',.25);
setField(app,'learningRate',.8); setField(app,'smoothingRate',.2); setField(app,'adjustInterval',4); setField(app,'adjustExponent',.5);
assert(app.applyTraining()); app.runOptimization();
assert(app.OptimizationInfo.requestedIterations==1 && app.History(end).learningScale==.8);
assert(app.History(end).smoothingAttempts>0 && contains(app.OptimizationInfo.trainingSemantics,'gradientForce'));
checks{end+1}='actual optimize button path consumes live learning/smoothing/schedule settings';

% Render-only analytic bow-tie fixture; detection coordinates come from the
% actual polyline API, never theoretical/actual line-line overlap.
ordinary=app.Result; analytic=ordinary; xy=[-40 -30;40 30;-40 30;40 -30;-40 -30];
analytic.cam.actual=xy; analytic.cam.pitch=xy; analytic.cam.workingMask=[true(4,1);false];
[analytic.intersectionPairs,analytic.intersectionPoints]=camdesign.selfIntersections(xy);
analytic.metrics.intersectionCount=size(analytic.intersectionPairs,1); analytic.metrics.geometryChecked=true;
app.Result=analytic; app.render(); marker=findobj(app.CamAxes,'Tag','cam-self-intersections');
assert(isscalar(marker) && isequal(marker.Color,[1 0 0]) && strcmp(marker.Marker,'o'));
assert(isequal([marker.XData(:),marker.YData(:)],analytic.intersectionPoints));
assert(any(strcmp(app.CamAxes.Legend.String,'实际自交')));
app.render(); assert(numel(findobj(app.CamAxes,'Tag','cam-self-intersections'))==1);
capture(app,folder,'actual_cam_intersection_marker.png');
analytic.cam.workingMask=true(5,1); app.Result=analytic; app.render();
assert(numel(findobj(app.CamAxes,'Tag','cam-self-intersections'))==1 && any(strcmp(app.CamAxes.Legend.String,'回程')));
app.Result=ordinary; app.Result.cam.pitch=ordinary.cam.actual; app.render();
assert(isempty(findobj(app.CamAxes,'Tag','cam-self-intersections')) && ~any(strcmp(app.CamAxes.Legend.String,'实际自交')));
app.Result=analytic; app.render();
partial=ordinary; partial.metrics.geometryChecked=false; partial.metrics.intersectionCount=NaN;
partial.intersectionPoints=zeros(0,2); partial.intersectionPairs=zeros(0,2); app.Result=partial; app.render();
assert(isempty(findobj(app.CamAxes,'Tag','cam-self-intersections')) && contains(app.Status.Text,'未完整检查'));
checks{end+1}='actual red rings show correct positions, survive empty return, do not accumulate, and clear on no-crossing/unchecked results';

report=struct('release',version('-release'),'checks',{checks},'settings',settings, ...
    'requestedBezierCount',requestedBezierCount,'mapping',mapping,'mappingAudit',mappingAudit, ...
    'bezierControlCount',size(bezier.nodes,1),'bezierDegree',bezier.params.bezier.degree,'bezierSamples',bezier.params.samples, ...
    'editableControlCount',editableCount,'rebuildSettings',rebuildSettings, ...
    'rebuildCalculationAvailable',rebuildCalculationAvailable,'rebuildCalculationError',rebuildCalculationError,'rebuildStatus',rebuildStatus, ...
    'markerCoordinates',analytic.intersectionPoints, ...
    'scope','Owned hidden UI callbacks, short search integration and analytic render fixture; not native pointer or optimizer-quality validation.');
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('TRAINING_UI_CASE_PASS %s\n',checks{k}); end
fprintf('TRAINING_UI_PASS cases=%d requested=%d controls=%d degree=%d samples=%d editControls=%d rebuildControls=%d markerCount=%d\n', ...
    numel(checks),requestedBezierCount,size(bezier.nodes,1),bezier.params.bezier.degree,bezier.params.samples, ...
    editableCount,rebuildSettings.controlPointCount,size(analytic.intersectionPoints,1));
end
function assertPanelSettings(app)
settings=camdesign.trainingSettings(app.Project);
for k=1:numel(app.TrainingFieldNames)
    assert(app.TrainingFields(k).Value==settings.(app.TrainingFieldNames{k}));
end
assert(settings.controlPointCount==size(app.NodesTable.Data,1) && ~app.TrainingDirty);
if isfield(app.Project.params,'training') && app.Project.params.training.densityManaged
    assert(app.Project.params.samples==(settings.controlPointCount-1)*settings.interpolationPerSegment+1);
end
assert(contains(app.TrainingInfo.Text,sprintf('%d 控制点 / %d 路线采样',settings.controlPointCount,app.Project.params.samples)));
end
function assertOperationInvariants(before,after)
assert(isequaln(before.targets,after.targets) && isequaln(before.nodes(1,:),after.nodes(1,:)));
mutable={'routeModel','routeSpline','bezier','bspline','training','iterations','samples','gradientProbeMM'};
left=before.params; right=after.params;
for k=1:numel(mutable)
    if isfield(left,mutable{k}), left=rmfield(left,mutable{k}); end
    if isfield(right,mutable{k}), right=rmfield(right,mutable{k}); end
end
assert(isequaln(left,right));
end
function audit=assertMappingWithinTolerance(source,mapped,fit)
assert(fit.withinTolerance && fit.finiteGeometry && fit.endpointConstraintsSatisfied && ~fit.forced && ~fit.allowApproximate);
assert(fit.tolerances.positionMaxMM<=.05 && fit.tolerances.positionRMSMM<=.01 && fit.tolerances.maxTangentDeg<=.05);
% Endpoint-inclusive rows differ from the mapper's half-offset validation.
u=linspace(0,fit.parameterLength,4097)';
[original,originalD]=camdesign.routeGeometry(source.nodes,source.params,u);
[converted,convertedD]=camdesign.routeGeometry(mapped.nodes,mapped.params,u);
errors=vecnorm(converted-original,2,2);
angles=rad2deg(atan2(abs(convertedD(:,1).*originalD(:,2)-convertedD(:,2).*originalD(:,1)),sum(convertedD.*originalD,2)));
assert(all(isfinite([errors;angles])) && all(vecnorm(originalD,2,2)>1e-10) && all(vecnorm(convertedD,2,2)>1e-10));
audit=struct('samples',numel(u),'positionMaxMM',max(errors),'positionRMSMM',sqrt(mean(errors.^2)), ...
    'maxTangentErrorDeg',max(angles),'endpointPositionMM',max(errors([1 end])), ...
    'endpointDerivative',max(vecnorm(convertedD([1 end],:)-originalD([1 end],:),2,2)));
assert(audit.positionMaxMM<=fit.tolerances.positionMaxMM && audit.positionRMSMM<=fit.tolerances.positionRMSMM ...
    && audit.maxTangentErrorDeg<=fit.tolerances.maxTangentDeg ...
    && audit.endpointPositionMM<=fit.tolerances.endpointPositionMM && audit.endpointDerivative<=fit.tolerances.endpointDerivative);
end
function setField(app,name,value)
index=find(strcmp(app.TrainingFieldNames,name)); app.TrainingFields(index).Value=value;
callback=app.TrainingFields(index).ValueChangedFcn; callback(app.TrainingFields(index),[]);
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow; exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if isgraphics(app.Figure), delete(app.Figure); end
end
