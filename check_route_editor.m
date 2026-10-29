function check_route_editor()
% Callback/method regression; this does not simulate native mouse hit testing.
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','route_editor'); if ~isfolder(folder), mkdir(folder); end
fprintf('ROUTE_EDITOR_CHECK_START\n');
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeFigure(app));
checks={}; baseline=app.Project; baselineResult=app.Result;
axesHandle=app.RouteAxes; k=5; point=baseline.nodes(k,:);
driven=findobj(axesHandle,'Tag','route-driven');
assert(isequal(driven.XData(:),baselineResult.route.driven(:,1)));
assert(isequal(driven.YData(:),baselineResult.route.driven(:,2)) && strcmp(driven.LineStyle,'--'));
front=findobj(axesHandle,'Tag','route-front'); drive=findobj(axesHandle,'Tag','route-drive');
assert(isequal(front.Color,[0 0 0]) && strcmp(front.LineStyle,'-'));
assert(isequal(drive.Color,[0 0 1]) && strcmp(drive.LineStyle,'-'));
assert(numel(axesHandle.Legend.String)==7);
checks{end+1}='four component trajectories and explicit legend';

% Enter through the actual button callback, then test the state-machine inputs.
callback=app.MapEditButton.ButtonPushedFcn; callback(app.MapEditButton,[]);
assert(app.MapEditMode && app.MapEditSelection==0);
assert(all(arrayfun(@(b)strcmp(b.Enable,'off'),app.Buttons)));
assert(~any(app.NodesTable.ColumnEditable) && ~any(app.ParamsTable.ColumnEditable));
assert(strcmp(axesHandle.Toolbar.Visible,'off'));
for name={'import','save','seed','calculate','optimize','stop','simulate','export'}
    app.action(name{1});
end
app.runOptimization(); app.toggleSimulation(); app.modifyPoints('node',1);
assert(isequaln(app.Project,baseline) && isequaln(app.Result,baselineResult));
assert(isequal(app.NodesTable.Data,baseline.nodes) && ~app.Busy && ~app.SimulationMode);
checks{end+1}='entry and conflicting actions are blocked';

for badPoint={point',[NaN 1],[1 Inf],[1 2i],[-6001 100],[0 2001]}
    app.routeMapClick(badPoint{1},axesHandle);
end
app.routeMapClick(point,app.CamAxes); app.routeMapClick(point,app.ParamsTable);
app.routeMapClick(point,axesHandle,'alt');
assert(app.MapEditSelection==0 && isequal(app.NodesTable.Data,baseline.nodes));
checks{end+1}='nonfinite, out-of-range, other-axis and non-left clicks ignored';

app.routeMapClick(point,axesHandle); assert(app.MapEditSelection==k);
app.previewRouteNode(point+[5 2],axesHandle);
assert(isequal(app.NodesTable.Data(k,:),point+[5 2]));
nodeLine=findobj(axesHandle,'Tag','route-nodes'); marker=findall(axesHandle,'Tag','node-edit-selection');
assert(isequal([nodeLine.XData(k) nodeLine.YData(k)],point+[5 2]));
assert(isequal([marker.XData marker.YData],point+[5 2]));
assert(isequaln(app.Project,baseline) && isequaln(app.Result,baselineResult));
assert(contains(app.Status.Text,'编辑前结果') && numel(axesHandle.Legend.String)==7);
app.previewRouteNode(point+[10 10],app.SteeringAxes);
app.routeMapClick([1 2001],axesHandle);
assert(isequal(app.NodesTable.Data(k,:),point+[5 2]) && app.MapEditMode);
app.Figure.Visible='on'; drawnow;
exportapp(app.Figure,fullfile(folder,'node_preview.png'));
callback=app.Figure.WindowKeyPressFcn; callback(app.Figure,struct('Key','escape'));
assert(~app.MapEditMode && isequaln(app.Project,baseline) && isequaln(app.Result,baselineResult));
assert(isequal(app.NodesTable.Data,baseline.nodes) && isempty(findall(axesHandle,'Tag','node-edit-selection')));
assert(strcmp(app.MapEditButton.Enable,'on') && strcmp(app.ConfirmNodeButton.Enable,'off'));
assert(isempty(app.Figure.WindowButtonMotionFcn));
checks{end+1}='preview table/markers synchronized; Escape restores complete design';

% A submillimetre second click must confirm without a distance threshold.
app.beginRouteEditing(); app.routeMapClick(point,axesHandle);
app.routeMapClick(point+[.01 .01],axesHandle);
assert(~app.MapEditMode && isequal(app.Project.nodes(k,:),point+[.01 .01]));
assert(isequal(app.NodesTable.Data,app.Project.nodes));
assert(numel(findall(axesHandle,'Tag','route-target-label'))==size(app.Project.targets,1));
assert(~isequaln(app.Result.route.front,baselineResult.route.front));
assert(~isequaln(app.Result.cam.pitch,baselineResult.cam.pitch));
shortMoveMaxFrontDelta=max(vecnorm(app.Result.route.front-baselineResult.route.front,2,2));
checks{end+1}='short-distance confirmation recalculates route and cam';

confirmed=app.Project; confirmedResult=app.Result;
app.beginRouteEditing(); app.routeMapClick(confirmed.nodes(k,:),axesHandle);
app.previewRouteNode(confirmed.nodes(k-1,:),axesHandle); app.confirmRouteNode();
assert(app.MapEditMode && isequaln(app.Project,confirmed) && isequaln(app.Result,confirmedResult));
assert(contains(app.Status.Text,'候选不可用') && contains(app.Status.Text,'重合'));
exportapp(app.Figure,fullfile(folder,'invalid_candidate.png'));
app.previewRouteNode(confirmed.nodes(k,:)+[2 1],axesHandle);
callback=app.ConfirmNodeButton.ButtonPushedFcn; callback(app.ConfirmNodeButton,[]);
assert(~app.MapEditMode && isequal(app.Project.nodes(k,:),confirmed.nodes(k,:)+[2 1]));
checks{end+1}='duplicate candidate rejected atomically; same session recovers and confirms';

% A large displacement violates the forward-driving geometry, not just input format.
confirmed=app.Project; confirmedResult=app.Result;
app.beginRouteEditing(); app.routeMapClick(confirmed.nodes(2,:),axesHandle);
app.previewRouteNode([-100 1900],axesHandle); app.confirmRouteNode();
assert(app.MapEditMode && contains(app.Status.Text,'候选不可用'));
assert(isequaln(app.Project,confirmed) && isequaln(app.Result,confirmedResult));
geometryRejection=app.Log.Value{end};
callback=app.CancelNodeButton.ButtonPushedFcn; callback(app.CancelNodeButton,[]);
assert(~app.MapEditMode && isequaln(app.Project,confirmed) && isequaln(app.Result,confirmedResult));
checks{end+1}='invalid geometry rejected; Cancel button restores design';

% Pending and invalid table input must not be discarded by entering map editing.
wheelRow=find(strcmp(app.ParamsTable.Data(:,1),'主动轮直径 / mm'));
app.ParamsTable.Data{wheelRow,2}=app.ParamsTable.Data{wheelRow,2}+1;
pending=app.ParamsTable.Data;
app.beginRouteEditing(); % Also catches edits for which a CellEditCallback did not fire.
assert(~app.MapEditMode && isequal(app.ParamsTable.Data,pending) && isequaln(app.Project,confirmed));
callback=app.ParamsTable.CellEditCallback; callback(app.ParamsTable,[]);
assert(isempty(app.Result)); app.beginRouteEditing();
assert(~app.MapEditMode && isequal(app.ParamsTable.Data,pending));
app.calculate(); assert(app.Project.params.wheelDiameter==pending{wheelRow,2});
confirmed=app.Project; confirmedResult=app.Result;
leverRow=find(strcmp(app.ParamsTable.Data(:,1),'转向偏距 c / mm'));
app.ParamsTable.Data{leverRow,2}=0; app.beginRouteEditing();
assert(~app.MapEditMode && app.ParamsTable.Data{leverRow,2}==0 && isequaln(app.Project,confirmed));
failed=false;
try, app.calculate(); catch ex, failed=strcmp(ex.identifier,'cam:Lever'); end
assert(failed && isempty(app.Result) && isequaln(app.Project,confirmed));
app.ParamsTable.Data{leverRow,2}=confirmed.params.lever; app.calculate();
assert(isequaln(app.Project,confirmed) && isequaln(app.Result,confirmedResult));
checks{end+1}='pending/invalid table input preserved and calculation commits atomically';

app.setBusy(true); app.beginRouteEditing(); app.routeMapClick(point,axesHandle);
assert(~app.MapEditMode && strcmp(app.MapEditButton.Enable,'off'));
app.setBusy(false); app.toggleSimulation();
fixedProject=app.SimulationReference.project; fixedCam=app.SimulationReference.result.cam;
app.beginRouteEditing(); app.routeMapClick(point,axesHandle);
assert(~app.MapEditMode && strcmp(app.MapEditButton.Enable,'off'));
assert(isequaln(app.SimulationReference.result.cam,fixedCam));
app.toggleSimulation();
assert(~app.SimulationMode && isequaln(app.Project,fixedProject) && strcmp(app.MapEditButton.Enable,'on'));
assert(isempty(app.SteeringAxes.Legend));
checks{end+1}='Busy and fixed-cam modes reject editing; design controls recover';

% Cancel preserves a zoomed view; entering editing has paused its interactions.
axesHandle.XLim=[-4000 -500]; axesHandle.YLim=[200 1800];
viewLimits=[axesHandle.XLim axesHandle.YLim];
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(5,:),axesHandle);
app.previewRouteNode(app.Project.nodes(5,:)+[3 1],axesHandle); app.cancelRouteEditing();
assert(isequal([axesHandle.XLim axesHandle.YLim],viewLimits));
axesHandle.XLim=app.Project.params.bounds(1:2); axesHandle.YLim=app.Project.params.bounds(3:4);
checks{end+1}='Cancel preserves the pre-edit map view';
exportapp(app.Figure,fullfile(folder,'confirmed_routes.png'));

app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(5,:),axesHandle);
app.previewRouteNode(app.Project.nodes(5,:)+[1 1],axesHandle); app.closeRequested();
assert(~isgraphics(app.Figure) && ~app.MapEditMode);
checks{end+1}='closing during editing cancels safely';
report=struct('matlab',version,'release',version('-release'), ...
    'method','UI callbacks and state-machine methods; no native mouse/keyboard injection', ...
    'checks',{checks},'shortMoveMaxFrontDeltaMM',shortMoveMaxFrontDelta, ...
    'geometryRejection',geometryRejection,'screenshots',{{'node_preview.png','invalid_candidate.png','confirmed_routes.png'}});
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8');
assert(fid>=0); fileCleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for j=1:numel(checks), fprintf('ROUTE_EDITOR_CASE_PASS %s\n',checks{j}); end
fprintf('ROUTE_EDITOR_CHECK_PASS %d cases\n',numel(checks));
end

function closeFigure(app)
if isgraphics(app.Figure), delete(app.Figure); end
end
