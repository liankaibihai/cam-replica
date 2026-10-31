function report=check_actual_cam_ui(folder)
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:ActualUIBatch','Run in independent batch.');
if nargin<1, folder=fullfile(root,'outputs','actual_cam_20261031','ui'); end
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
p=camdesign.solarTestProject(); p.params.headingDeg=0; p.params.startSteeringDeg=0;
p.params.samples=301; p.params.camSamples=1441;
p.nodes=[1000 1000;1500 1000;2000 1000]; p.targets=p.nodes+[-20 0];
app.Project=p; app.syncInputs(); app.calculate(); frozen=app.Result.cam; saved=app.Project;
assert(strcmp(app.SimulationSource.Value,'actual'));
app.action('simulate'); assert(app.SimulationMode && ~isempty(app.SimulationResult));
assert(contains(app.Status.Text,'实际轮廓接触') && strcmp(app.SimulationSource.Enable,'off'));
assert(isequaln(frozen,app.SimulationReference.result.cam));
assert(size(app.ParamsTable.Data,1)==11);
checks{end+1}='default actual mode enters through toolbar and freezes actual geometry with editable contact radius';
baseline=app.SimulationResult.sensor;
row=find(contains(app.ParamsTable.Data(:,1),'接触半径'));
app.ParamsTable.Data{row,2}=app.ParamsTable.Data{row,2}+.2; app.invalidate(); app.calculate();
assert(max(vecnorm(app.SimulationResult.sensor-baseline,2,2))>1);
assert(isequaln(frozen,app.SimulationReference.result.cam));
app.action('simulate'); assert(~app.SimulationMode && isequaln(saved,app.Project));
checks{end+1}='contact radius changes trajectory without changing cam, exit restores design';
cb=app.ActualClosureButton.ButtonPushedFcn; cam_invoke_ui_callback(cb,app.ActualClosureButton,[]);
assert(~app.Busy && ~isempty(app.ActualClosureReport) && app.ActualClosureReport.closurePassed);
assert(app.ActualClosureReport.contactValid && ~isempty(app.ActualClosureTable.Data));
assert(numel(findobj(app.RouteAxes,'Tag','actual-closure-route'))==1);
assert(isequaln(frozen,app.Result.cam) && app.Project.params.gearRatio==35);
app.Figure.Position=[50 50 1320 860]; app.resizeLayout(); drawnow;
exportapp(app.Figure,fullfile(folder,'actual_closure.png'));
checks{end+1}='actual closure button reports independent contact/integration metrics and overlays route';
app.ParamsTable.Data{1,2}=131; app.invalidate();
assert(isempty(app.ActualClosureReport) && isempty(app.ActualClosureTable.Data));
app.Project=saved; app.syncInputs(); app.calculate();
% Direct input rejection uses a source-invalid outline without changing any design fields.
reference=struct('project',app.Project,'result',app.Result);
reference.result.cam.actual=[0 0;1 1;0 1;1 0;0 0];
rejected=false;
try, app.computeFixedSimulation(reference,app.Project.params); catch, rejected=true; end
assert(rejected && ~app.SimulationMode);
checks{end+1}='edits invalidate closure evidence and self-crossing outline cannot enter normal actual simulation';
source=load(fullfile(root,'outputs','model_mapping_20261031','quality_cubic','result.mat'),'q');
app.Project=source.q; app.Project.params.samples=4801; app.Project.params.camSamples=5761;
app.syncInputs(); app.calculate(); before=app.Project;
assert(app.Result.metrics.intersectionCount>0);
cam_invoke_ui_callback(cb,app.ActualClosureButton,[]);
assert(~app.Busy && ~app.ActualClosureReport.valid && ~app.ActualClosureReport.closurePassed);
assert(contains(app.ActualClosureStatus.Text,'未通过') && contains(app.ActualClosureReport.errorIdentifier,'SelfIntersection'));
assert(isequaln(before,app.Project) && isempty(findobj(app.RouteAxes,'Tag','actual-closure-route')));
checks{end+1}='real closure button rejects crossing solar outline with clear reason and intact project';
app.Project=saved; app.syncInputs(); app.calculate();
app.SimulationSource.Value='theoretical'; app.action('simulate');
assert(app.SimulationMode && contains(app.Status.Text,'理论对照')); app.action('simulate');
checks{end+1}='theoretical reference remains explicitly selectable';
source=load(fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'),'q');
app.Project=source.q; app.Project.params.samples=4801; app.Project.params.camSamples=5761;
app.SimulationSource.Value='actual'; app.syncInputs(); app.calculate(); cam_invoke_ui_callback(cb,app.ActualClosureButton,[]);
assert(~app.Busy && app.ActualClosureReport.valid && app.ActualClosureReport.contactValid);
assert(~app.ActualClosureReport.geometryFeasible && app.Project.params.gearRatio==35);
drawnow; exportapp(app.Figure,fullfile(folder,'solar_actual_closure.png'));
checks{end+1}='solar flat fixed35 actual closure displayed separately from failed physical gates';
report=struct('release',version('-release'),'checks',{checks},'passed',numel(checks));
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fprintf('ACTUAL_CAM_UI_PASS %d\n',numel(checks));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
