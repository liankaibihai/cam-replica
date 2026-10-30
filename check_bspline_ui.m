function report=check_bspline_ui()
% Owned hidden MATLAB app. Real callback/action paths, no user windows.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:BSplineBatchOnly','请用独立batch运行。');
folder=fullfile(root,'outputs','bspline_20261031','ui_map_bounds'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
p=fixture(); app.Project=p; app.syncInputs(); invoke(app.Buttons(4),'ButtonPushedFcn');
assert(numel(app.TrainingModel.Items)==4 && ~isempty(app.Result));
app.TrainingModel.Value='bspline-3'; invoke(app.TrainingModel,'ValueChangedFcn');
assert(strcmp(app.AlgorithmSelector.Value,'fmincon-interior-point-experimental-v1') && app.TrainingDirty);
setField(app,'controlPointCount',8); setField(app,'iterations',1); setField(app,'interpolationPerSegment',15);
invoke(app.TrainingApplyButton,'ButtonPushedFcn');
assert(~app.TrainingDirty && strcmp(camdesign.routeModel(app.Project.params),'bspline-v1') && app.Project.params.bspline.degree==3);
assert(isequal(app.NodesTable.Data,app.Project.nodes) && size(app.Project.nodes,1)==8);
assert(contains(app.NodeInfo.Text,'系数控制点') && contains(app.TrainingInfo.Text,'标准3次B样条'));
assert(numel(app.Result.route.u)==106 && app.Project.params.gearRatio==35);
checks{end+1}='real model/apply/calculate callbacks convert B3, select inner-point and display actual coefficient controls';

app.TrainingModel.Value='bspline-5'; invoke(app.TrainingModel,'ValueChangedFcn'); invoke(app.TrainingApplyButton,'ButtonPushedFcn');
assert(~app.TrainingDirty && app.Project.params.bspline.degree==5 && size(app.Project.nodes,1)==8);
assert(strcmp(app.TrainingModel.Value,'bspline-5') && strcmp(app.TrainingFields(4).Enable,'off'));
invoke(app.Buttons(5),'ButtonPushedFcn');
assert(~app.Busy && isstruct(app.OptimizationInfo) && app.OptimizationInfo.effectiveDOF==10);
assert(strcmp(app.OptimizationInfo.algorithm,'fmincon-interior-point-experimental-v1'));
assert(app.OptimizationInfo.requestedIterations==1 && app.OptimizationInfo.parametersUnchanged && ~isempty(app.History));
checks{end+1}='B5 model callback and actual optimize button run the endpoint-constrained backend without changing ratio or parameters';

before=app.Project; invoke(app.PointButtons(3),'ButtonPushedFcn');
assert(size(app.Project.nodes,1)==9 && app.Project.params.samples==121 && app.TrainingFields(2).Value==9);
invoke(app.PointButtons(4),'ButtonPushedFcn');
assert(size(app.Project.nodes,1)==8 && app.Project.params.samples==106);
assert(isequal(app.Project.targets,before.targets) && norm(app.Project.params.bspline.endDerivative-before.params.bspline.endDerivative)<1e-9);
% Free control movement uses the actual map-edit confirm path.
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(4,:),app.RouteAxes);
assert(app.MapEditMode && app.MapEditSelection==4);
app.previewRouteNode(app.Project.nodes(4,:)+[.001 0],app.RouteAxes); app.confirmRouteNode();
assert(~app.MapEditMode && abs(app.Project.nodes(4,1)-before.nodes(4,1)-.001)<1e-7);
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(2,:)+[1 0],app.RouteAxes); app.confirmRouteNode();
assert(app.MapEditMode && contains(app.Status.Text,'导数')); app.cancelRouteEditing();
checks{end+1}='actual add/delete controls refit, synchronize density and preserve derivatives; map editing accepts free controls and rejects endpoint violations';

for algorithm={'peak-gradient-v2','video-four-direction-v1','auto-tune-v1'}
    app.AlgorithmSelector.Value=algorithm{1}; invoke(app.AlgorithmSelector,'ValueChangedFcn');
    assert(strcmp(app.Buttons(5).Enable,'off') && contains(app.Buttons(5).Tooltip,'仅支持'));
    project=app.Project; app.action('optimize');
    assert(~app.Busy && isequaln(project,app.Project) && contains(app.Log.Value{end},'仅支持'));
end
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1'; invoke(app.AlgorithmSelector,'ValueChangedFcn');
assert(strcmp(app.Buttons(5).Enable,'on'));
checks{end+1}='unsupported peak/four-direction/auto modes disable optimize and explicit action rejects them without model replacement';

filename=fullfile(folder,'ui_roundtrip.mat'); app.action('save',filename); saved=app.Project;
assert(isfile(filename)); app.Project=p; app.syncInputs(); app.action('import',filename);
assert(isequaln(app.Project,saved) && strcmp(app.TrainingModel.Value,'bspline-5') && ~isempty(app.Result));
assert(isequal(app.NodesTable.Data,saved.nodes) && strcmp(app.AlgorithmSelector.Value,'fmincon-interior-point-experimental-v1'));
checks{end+1}='same save/import action branches as toolbar preserve knots, controls, constraints, settings and route model';

design=app.Project; invoke(app.Buttons(7),'ButtonPushedFcn');
assert(app.SimulationMode && ~isempty(app.SimulationResult));
row=find(contains(app.ParamsTable.Data(:,1),'发车车身方向'));
assert(isscalar(row)); app.ParamsTable.Data{row,2}=89.5;
invoke(app.Buttons(4),'ButtonPushedFcn');
assert(abs(rad2deg(app.SimulationResult.heading(1))-89.5)<1e-9);
invoke(app.Buttons(7),'ButtonPushedFcn');
assert(~app.SimulationMode && isequaln(app.Project,design) && ~isempty(app.Result));
checks{end+1}='fixed-cam simulation accepts trial heading and restores the complete constrained B-spline design on exit';

app.action('seed');
assert(strcmp(camdesign.routeModel(app.Project.params),'bspline-v1') && app.Project.params.bspline.degree==5 ...
    && size(app.Project.nodes,1)==8 && ~isempty(app.Result));
% Exit a coefficient representation by sampling its true curve, never use
% spline coefficients as cubic interpolation points.
app.TrainingModel.Value='cubic'; invoke(app.TrainingModel,'ValueChangedFcn'); invoke(app.TrainingApplyButton,'ButtonPushedFcn');
assert(~app.TrainingDirty && strcmp(camdesign.routeModel(app.Project.params),'cubic') && ~isfield(app.Project.params,'bspline'));
app.TrainingModel.Value='bspline-5'; invoke(app.TrainingModel,'ValueChangedFcn'); invoke(app.TrainingApplyButton,'ButtonPushedFcn');
assert(~app.TrainingDirty && strcmp(camdesign.routeModel(app.Project.params),'bspline-v1'));
checks{end+1}='rebuild retains explicit B5/count and switching back to cubic samples the real curve';

bspline=app.Project; app.Project=p; app.syncInputs();
app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel,'ValueChangedFcn');
setField(app,'controlPointCount',8); setField(app,'interpolationPerSegment',15); invoke(app.TrainingApplyButton,'ButtonPushedFcn');
assert(~app.TrainingDirty && strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1'));
assert(contains(app.NodeInfo.Text,'独立贝塞尔') && numel(app.Result.route.u)==106);
bezier=app.Project;
app.Project=bspline; app.syncInputs(); invoke(app.Buttons(4),'ButtonPushedFcn');
checks{end+1}='legacy independent Bezier model/apply path remains functional after B-spline integration';

% A real displayed coefficient lies left of the physical field. Only the
% editor domain changes; the unchanged five-center acceptance still rejects
% the out-of-field vehicle tracks in this deliberately infeasible fixture.
design=app.Project; outside=design; outside.params.bounds(1)=250;
outside.params.controlBoundsPolicy='trajectory-only-v1';
app.Project=outside; app.syncInputs(); invoke(app.Buttons(4),'ButtonPushedFcn');
point=app.Project.nodes(4,:); moved=point+[-.1 0];
polygon=findobj(app.RouteAxes,'Tag','route-nodes');
assert(isscalar(polygon) && abs(polygon.XData(4)-point(1))<1e-10);
assert(point(1)<outside.params.bounds(1) && app.isRoutePoint(point,app.RouteAxes) && app.isRoutePoint(moved,app.RouteAxes));
assert(~app.isRoutePoint([NaN point(2)],app.RouteAxes) && ~app.isRoutePoint([Inf point(2)],app.RouteAxes));
assert(~app.isRoutePoint([point(1)+1i point(2)],app.RouteAxes));
assert(~app.isRoutePoint([app.RouteAxes.XLim(1)-1 point(2)],app.RouteAxes) && ~app.isRoutePoint(point,app.CamAxes));
invoke(app.MapEditButton,'ButtonPushedFcn'); app.routeMapClick(point,app.RouteAxes);
assert(app.MapEditMode && app.MapEditSelection==4);
app.previewRouteNode(moved,app.RouteAxes);
assert(norm(app.NodesTable.Data(4,:)-moved)<1e-10);
invoke(app.ConfirmNodeButton,'ButtonPushedFcn');
assert(~app.MapEditMode && norm(app.Project.nodes(4,:)-moved)<1e-10 && app.Project.nodes(4,1)<outside.params.bounds(1));
physical=camdesign.verifyConstrained(app.Project,2);
assert(physical.controlBoundsGatePassed && ~physical.nodeBoundsSatisfied ...
    && ~physical.trajectoryBoundsSatisfied && ~physical.verifiedFeasible && physical.maxTrajectoryOutsideMM>0);
capture(app,fullfile(folder,'visible_outside_coefficient.png'));
checks{end+1}='visible out-of-field B-spline coefficient can be clicked, dragged and confirmed; finite/visible/source guards remain and physical bounds still fail';

% Explicit coefficient bounds and all older route models retain their old
% field-limited map domain, even with the same visible point.
app.Project.params.controlBoundsPolicy='legacy-node-bounds-v1';
assert(~app.isRoutePoint(moved,app.RouteAxes));
app.Project=p; app.Project.params.bounds(1)=250; app.Project.params.controlBoundsPolicy='trajectory-only-v1';
assert(~app.isRoutePoint(point,app.RouteAxes));
app.Project=bezier; app.Project.params.bounds(1)=250; app.Project.params.controlBoundsPolicy='trajectory-only-v1';
assert(~app.isRoutePoint(point,app.RouteAxes));
app.Project=design; app.syncInputs(); invoke(app.Buttons(4),'ButtonPushedFcn');
checks{end+1}='legacy-bound B-spline, cubic and independent Bezier retain field-limited map editing';

app.ControlsTabs.SelectedTab=app.TrainingTab;
app.Figure.Position=[50 50 1320 860]; app.resizeLayout(); capture(app,fullfile(folder,'bspline_1320x860.png'));
app.Figure.Position=[50 50 1120 760]; app.resizeLayout(); capture(app,fullfile(folder,'bspline_1120x760.png'));
report=struct('release',version('-release'),'checks',{checks},'model',camdesign.routeModel(app.Project.params), ...
    'degree',app.Project.params.bspline.degree,'controlPoints',size(app.Project.nodes,1), ...
    'scope','Owned hidden UI callbacks and file-path action branches; native pointer/file chooser and optimizer quality not tested.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('BSPLINE_UI_CASE_PASS %s\n',checks{k}); end
fprintf('BSPLINE_UI_PASS cases=%d\n',numel(checks));
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end
function setField(app,name,value)
index=find(strcmp(app.TrainingFieldNames,name)); app.TrainingFields(index).Value=value;
invoke(app.TrainingFields(index),'ValueChangedFcn');
end
function invoke(control,name)
callback=control.(name); callback(control,[]);
end
function closeOwn(app)
if isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
function capture(app,filename)
drawnow; exportapp(app.Figure,filename); pause(.25); drawnow; exportapp(app.Figure,filename);
end
