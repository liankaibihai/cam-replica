function report=check_route_refinement_ui()
% Exercise only this batch's own app. No native input or user-window changes.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:RefinementBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','route_refinement_20261029');
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
app.SimulationSource.Value='theoretical'; % Preserve legacy theoretical-mode UI regression.
assert(isequaln(app.Project,camdesign.defaultProject()) && ~isfield(app.Project.params,'routeSpline'));
checks{end+1}='historical default constructor retains legacy parameterization';
solar=camdesign.solarTestProject(); app.Project=solar; app.syncInputs(); app.calculate();
tabs=app.NodesTable.Parent.Parent.Parent; tabs.SelectedTab=app.NodesTable.Parent.Parent;
initialResult=app.Result; capture(app,folder,'solar_before_nodes.png');

callback=app.RefineRouteButton.ButtonPushedFcn; callback(app.RefineRouteButton,[]);
[expectedOnce,onceInfo]=camdesign.refineRoute(solar);
assert(isequaln(app.Project,expectedOnce) && isequal(app.TargetsTable.Data,solar.targets));
assert(contains(app.NodeInfo.Text,'固定站位') && contains(app.NodeInfo.Text,sprintf('节点 %d',onceInfo.newNodeCount)));
assert(max(vecnorm(app.Result.route.front-initialResult.route.front,2,2))<1e-8);
assert(isempty(app.History) && isempty(app.OptimizationDirection) && isempty(app.OptimizationInfo));
capture(app,folder,'solar_refined_once.png');
checks{end+1}='whole-route button inserts exact transition nodes without changing targets or computed curve';

callback(app.RefineRouteButton,[]);
[expectedTwice,twiceInfo]=camdesign.refineRoute(expectedOnce);
assert(isequaln(app.Project,expectedTwice));
assert(max(vecnorm(app.Result.route.front-initialResult.route.front,2,2))<1e-8);
capture(app,folder,'solar_refined_twice.png');
checks{end+1}='second refinement synchronizes node table and fixed stations';

% Selecting the terminal row inserts within the final existing interval.
before=app.Project; beforeResult=app.Result; app.SelectedNodeRow=size(before.nodes,1);
[expectedTail,tailInfo]=camdesign.refineRoute(before,size(before.nodes,1)-1);
callback=app.PointButtons(3).ButtonPushedFcn; callback(app.PointButtons(3),[]);
assert(isequaln(app.Project,expectedTail) && numel(tailInfo.insertedIndices)==1);
assert(isequal(app.Project.nodes(end,:),before.nodes(end,:)));
checks{end+1}='selected last-row insertion subdivides the final interval without extrapolating';

app.SelectedNodeRow=tailInfo.insertedIndices(1);
callback=app.PointButtons(4).ButtonPushedFcn; callback(app.PointButtons(4),[]);
assert(isempty(app.Result) && isequaln(app.Project,before));
assert(isequal(app.NodesTable.Data,before.nodes)); app.calculate();
assert(max(vecnorm(app.Result.route.front-beforeResult.route.front,2,2))<1e-8);
checks{end+1}='deleting an untouched inserted node restores stations and curve';

for selected=[1 size(before.nodes,1)]
    app.SelectedNodeRow=selected; app.modifyPoints('node',-1);
    candidate=app.inputProject();
    assert(size(candidate.nodes,1)==size(before.nodes,1)-1);
    assert(numel(candidate.params.routeSpline.stations)==size(candidate.nodes,1));
    assert(candidate.params.routeSpline.stations(1)==0);
    assert(isequal(candidate.params.routeSpline.endDerivative,before.params.routeSpline.endDerivative));
    app.Project=before; app.syncInputs(); app.calculate();
end
checks{end+1}='first/last deletion maintains station length, origin and explicit terminal derivative';

% A transition node is movable through the existing map editor.
node=2; originalStations=app.Project.params.routeSpline.stations;
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(node,:),app.RouteAxes);
assert(app.MapEditMode && strcmp(app.RefineRouteButton.Enable,'off'));
assert(~app.refineRoute() && isequaln(app.Project,before));
app.previewRouteNode(app.Project.nodes(node,:)+[1 0],app.RouteAxes); app.confirmRouteNode();
assert(~app.MapEditMode && isequal(app.Project.params.routeSpline.stations,originalStations));
movedFrontDelta=max(vecnorm(app.Result.route.front-beforeResult.route.front,2,2));
assert(movedFrontDelta>.5 && isequal(app.Project.targets,solar.targets));
assert(strcmp(app.RefineRouteButton.Enable,'on'));
capture(app,folder,'solar_transition_moved.png');
checks{end+1}='moving an added node changes the curve while retaining stations and target order';

confirmed=app.Project; confirmedResult=app.Result;
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(node,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(node,:)+[2 1],app.RouteAxes); app.cancelRouteEditing();
assert(isequaln(app.Project,confirmed) && isequaln(app.Result,confirmedResult));
checks{end+1}='map-edit cancel restores the complete refined project';

app.setBusy(true); assert(strcmp(app.RefineRouteButton.Enable,'off') && ~app.refineRoute());
app.setBusy(false); app.toggleSimulation();
assert(strcmp(app.RefineRouteButton.Enable,'off') && ~app.refineRoute());
app.toggleSimulation(); assert(isequaln(app.Project,confirmed));
checks{end+1}='busy and fixed-cam modes block refinement and restore controls';

wheelRow=find(strcmp(app.ParamsTable.Data(:,1),'主动轮直径 / mm'));
app.ParamsTable.Data{wheelRow,2}=app.ParamsTable.Data{wheelRow,2}+1;
pending=app.ParamsTable.Data; app.invalidate();
assert(~app.refineRoute() && isequal(app.ParamsTable.Data,pending) && isequaln(app.Project,confirmed));
assert(contains(app.Status.Text,'先计算'));
app.syncInputs(); app.calculate();
app.NodesTable.Data(node,1)=app.NodesTable.Data(node,1)+.25;
pendingNodes=app.NodesTable.Data;
assert(~app.refineRoute() && isequal(app.NodesTable.Data,pendingNodes) && isequaln(app.Project,confirmed));
app.syncInputs(); app.calculate();
checks{end+1}='pending parameter/node edits are preserved and require calculation before shape-preserving insertion';

file=fullfile(folder,'ui_refined_project.mat');
camdesign.saveProject(app.inputProject(),file);
loaded=camdesign.importProject(file); assert(isequaln(loaded,confirmed));
app.Project=loaded; app.syncInputs(); app.calculate();
assert(isequaln(app.Project,confirmed) && contains(app.NodeInfo.Text,'固定站位'));
checks{end+1}='UI project read/save/import retains all refinement metadata';

app.action('seed');
assert(~isfield(app.Project.params,'routeSpline') && isequal(app.Project.nodes,solar.nodes));
assert(isequal(app.Project.targets,solar.targets) && contains(app.NodeInfo.Text,'弦长站位'));
capture(app,folder,'solar_rebuilt_legacy.png');
checks{end+1}='explicit rebuild clears fixed stations and regenerates the original ten seed nodes';

report=struct('release',version('-release'),'method','Owned hidden app callbacks and methods; no native input', ...
    'checks',{checks},'nodeCounts',[size(solar.nodes,1),onceInfo.newNodeCount,twiceInfo.newNodeCount], ...
    'movedTransitionMaxFrontDeltaMM',movedFrontDelta,'orderedVisits',size(solar.targets,1), ...
    'screenshots',{{'solar_before_nodes.png','solar_refined_once.png','solar_refined_twice.png', ...
    'solar_transition_moved.png','solar_rebuilt_legacy.png'}});
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for index=1:numel(checks), fprintf('ROUTE_REFINEMENT_UI_CASE_PASS %s\n',checks{index}); end
fprintf('ROUTE_REFINEMENT_UI_PASS cases=%d nodes=%d/%d/%d movedDeltaMM=%.6g\n',numel(checks),report.nodeCounts,movedFrontDelta);
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow;
exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if isgraphics(app.Figure), delete(app.Figure); end
end
