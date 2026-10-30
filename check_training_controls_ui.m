function report=check_training_controls_ui()
% Owned hidden app only. Short callback checks, not convergence/vehicle proof.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:TrainingBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','results_panel_20261030','training_regression'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
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
setField(app,'controlPointCount',50); setField(app,'bezierDegree',15); setField(app,'interpolationPerSegment',11); setField(app,'iterations',1);
assert(app.applyTraining());
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') ...
    && size(app.Project.nodes,1)==50 && app.Project.params.bezier.degree==15 && app.Project.params.samples==540);
assert(contains(app.TrainingInfo.Text,'独立贝塞尔') && contains(app.MapEditHelp.Text,'不必穿过'));
assert(isequal(app.Project.targets,solar.targets) && numel(app.Result.route.u)==540);
bezier=app.Project; bezierResult=app.Result; capture(app,folder,'training_bezier_constrained.png');
checks{end+1}='switchable degree-15 independent Bezier initializes from the live panel with 50 real controls';

camdesign.saveProject(app.inputProject(),fullfile(folder,'ui_training_project.mat'));
loaded=camdesign.importProject(fullfile(folder,'ui_training_project.mat'));
assert(isequaln(loaded,app.Project) && isequaln(camdesign.trainingSettings(loaded),camdesign.trainingSettings(app.Project)));
app.Project=loaded; app.syncInputs(); app.calculate();
assert(strcmp(app.TrainingFields(5).Enable,'on') && all(arrayfun(@(field)strcmp(field.Enable,'off'),app.TrainingFields(6:9))));
checks{end+1}='all nine settings/model metadata survive project save/import and UI synchronization';

app.SelectedNodeRow=5; app.modifyPoints('node',1);
assert(size(app.Project.nodes,1)==51 && app.Project.params.samples==551 && app.TrainingFields(2).Value==51);
app.SelectedNodeRow=6; app.modifyPoints('node',-1); assert(isempty(app.Result)); app.calculate();
assert(isequaln(app.Project,bezier) && max(vecnorm(app.Result.route.front-bezierResult.route.front,2,2))<1e-8);
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
assert(app.MapEditMode && strcmp(app.TrainingApplyButton.Enable,'off') && ~app.applyTraining());
app.previewRouteNode(app.Project.nodes(2,:)+[1 0],app.RouteAxes); app.confirmRouteNode();
assert(~app.MapEditMode && contains(app.MapEditHelp.Text,'贝塞尔'));
[start,tangent]=camdesign.bezierRoute(app.Project.nodes,app.Project.params,0);
assert(norm(start-bezier.nodes(1,:))<1e-9 && norm(tangent-[0 1])<1e-10);
tabs.SelectedTab=app.NodesTable.Parent.Parent; capture(app,folder,'bezier_control_points.png');
checks{end+1}='Bezier controls can be inserted/deleted/moved with real count/density updates and a fixed initial tangent';

app.action('seed');
assert(strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') ...
    && size(app.Project.nodes,1)==50 && app.Project.params.bezier.degree==15 && app.Project.params.samples==540);
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
    'bezierControlCount',size(bezier.nodes,1),'bezierDegree',bezier.params.bezier.degree,'bezierSamples',bezier.params.samples, ...
    'markerCoordinates',analytic.intersectionPoints, ...
    'scope','Owned hidden UI callbacks, short search integration and analytic render fixture; not native pointer or optimizer-quality validation.');
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('TRAINING_UI_CASE_PASS %s\n',checks{k}); end
fprintf('TRAINING_UI_PASS cases=%d controls=50 degree=15 samples=540 markerCount=%d\n',numel(checks),size(analytic.intersectionPoints,1));
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
