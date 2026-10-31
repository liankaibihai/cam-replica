function report=check_review_ui_fixes(folder)
% Regression of review R2/R4 using an owned hidden application only.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
if nargin<1, folder=fullfile(fileparts(mfilename('fullpath')),'outputs','review_fixes_20261031','ui'); end
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); clean=onCleanup(@()closeOwn(app));
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
app.Project=p; app.syncInputs(); app.calculate();
app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(2,:)+[.001 0],app.RouteAxes); app.confirmRouteNode();
assert(~app.MapEditMode && app.diagnosticsAreCurrent());
assert(~contains(app.ScoreDisplayData.state,'历史') && strcmp(app.CrossSource.Enable,'on'));
confirmed=app.Project; app.beginRouteEditing(); app.routeMapClick(app.Project.nodes(2,:),app.RouteAxes);
app.previewRouteNode(app.Project.nodes(2,:)+[.1 0],app.RouteAxes); app.cancelRouteEditing();
assert(isequaln(app.Project,confirmed) && app.diagnosticsAreCurrent());
assert(~contains(app.ScoreDisplayData.state,'历史') && strcmp(app.CrossSource.Enable,'on'));
checks={'map confirmation refreshes diagnostics and enables refinement','map cancellation restores project and diagnostics'};
[bs,~]=camdesign.toBSpline(p,8,5); app.Project=bs; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='auto-tune-v1'; cb=app.AlgorithmSelector.ValueChangedFcn; cb(app.AlgorithmSelector,[]);
before=app.Project; oldResult=app.Result; oldNodes=app.NodesTable.Data; oldParams=app.ParamsTable.Data;
app.action('seed');
assert(isequaln(app.Project,before) && isequaln(app.Result,oldResult));
assert(isequaln(app.NodesTable.Data,oldNodes) && isequaln(app.ParamsTable.Data,oldParams));
assert(strcmp(app.TrainingModel.Value,'bspline-5'));
filename=fullfile(folder,'failed_seed_preserved.mat'); app.action('save',filename);
saved=camdesign.importProject(filename);
assert(strcmp(camdesign.routeModel(saved.params),'bspline-v1') && isequal(saved.nodes,before.nodes));
assert(isequaln(saved.params.bspline,before.params.bspline));
checks{end+1}='failed rebuild preserves model, coefficients, result, tables and save/import semantics';
app.Project=p; app.syncInputs(); app.calculate(); app.action('seed');
assert(isequal(app.Project.nodes,camdesign.seedNodes(p.targets,p.params)) && app.diagnosticsAreCurrent());
assert(~isempty(app.Result) && isempty(app.OptimizationInfo));
checks{end+1}='successful rebuild publishes one matching project/result and clears previous optimization';
report=struct('release',version('-release'),'checks',{checks},'passed',numel(checks));
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); fprintf('REVIEW_UI_FIXES_PASS %d\n',numel(checks));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
