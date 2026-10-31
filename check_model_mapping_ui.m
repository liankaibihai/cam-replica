function report=check_model_mapping_ui(folder)
% Real apply callbacks, truthful errors, model lock messaging, persistence.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
if nargin<1, folder=fullfile(fileparts(mfilename('fullpath')),'outputs','review_fixes_20261031','mapping_ui'); end
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); c=onCleanup(@()closeOwn(app));
p=camdesign.solarTestProject(); app.Project=p; app.syncInputs(); app.calculate();
source=geometry(p); original=p;
app.TrainingModel.Value='bspline-3'; invoke(app.TrainingModel);
assert(app.applyTraining());
assert(strcmp(camdesign.routeModel(app.Project.params),'bspline-v1') && app.Project.params.bspline.degree==3);
assert(max(vecnorm(geometry(app.Project)-source,2,2))<1e-7);
assert(any(contains(string(app.FullLog),'映射独立检查')));
mapped=app.Project; file=fullfile(folder,'mapped_project.mat'); app.action('save',file);
reload=camdesign.importProject(file); assert(isequaln(reload,mapped));
app.TrainingModel.Value='bspline-5'; invoke(app.TrainingModel); assert(app.applyTraining());
assert(app.Project.params.bspline.degree==5 && max(vecnorm(geometry(app.Project)-source,2,2))<1e-7);
assert(app.TrainingFields(2).Value==size(app.Project.nodes,1));
checks={'solar cubic maps to B3/B5 without sampled geometry change; actual count and fit evidence visible; project reload preserves mapping'};
% Invalid pending input must retain the complete published state.
saved=app.Project; savedResult=app.Result; savedNodes=app.NodesTable.Data;
app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel);
row=find(contains(string(app.ParamsTable.Data(:,1)),'主动轮直径')); assert(isscalar(row)); app.ParamsTable.Data{row,2}=-1;
assert(~app.applyTraining());
assert(isequaln(app.Project,saved) && isequaln(app.Result,savedResult) && isequaln(app.NodesTable.Data,savedNodes));
assert(app.TrainingDirty && contains(app.Status.Text,'未应用'));
assert(app.ParamsTable.Data{row,2}==-1); % Preserve uncommitted user input too.
app.syncInputs();
checks{end+1}='failed apply retains full published project, result and coefficient table with pending input explicit';
app.Project=original; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='auto-tune-v1'; invoke(app.AlgorithmSelector);
assert(contains(app.TrainingInfo.Text,'锁定') && contains(app.TrainingInfo.Text,'不切换'));
app.Figure.Position=[50 50 1320 860]; app.resizeLayout();
drawnow; exportapp(app.Figure,fullfile(folder,'locked_model.png'));
checks{end+1}='automatic mode UI states fixed applied model and degree';
report=struct('release',version('-release'),'checks',{checks},'passed',numel(checks));
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); fprintf('MODEL_MAPPING_UI_PASS %d\n',numel(checks));
end
function invoke(control)
cb=control.ValueChangedFcn; cam_invoke_ui_callback(cb,control,[]);
end
function xy=geometry(p)
mode=camdesign.routeModel(p.params);
if strcmp(mode,'cubic'), [~,~,s]=camdesign.routeSpline(p.nodes,p.params); T=s(end);
elseif strcmp(mode,'bspline-v1'), T=p.params.bspline.parameterLength;
else, T=p.params.bezier.parameterLength; end
xy=camdesign.routeGeometry(p.nodes,p.params,linspace(0,T,4001)');
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
