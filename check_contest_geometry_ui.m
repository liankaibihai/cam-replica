function report=check_contest_geometry_ui(action)
if nargin<1, action='all'; end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','contest_geometry_20261031','ui');
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleanup=onCleanup(@()closeOwn(app)); project=fixture();
if strcmp(action,'locations')
    app.Project=project; app.syncInputs(); app.calculate(); app.openContestGeometry();
    cfg=configuration(); cfg.rightMM=1000; enter(app,cfg); push(app.ContestGeometryCheckButton);
    assert(contains(app.ContestGeometryNotice.Text,'问题访问号 无'));
    app.fitRouteView(app.ContestGeometryReport.boundary.worstPolygonXY); drawnow;
    exportapp(app.Figure,fullfile(folder,'body_boundary_failure.png'));
    cfg=configuration(); cfg.coverXMinMM=-6; cfg.coverXMaxMM=6; enter(app,cfg); push(app.ContestGeometryCheckButton);
    app.selectContestGeometryTarget(struct('Indices',[2 1]));
    assert(contains(string(app.RouteAxes.Title.String{1}),'访问 2'));
    labels=findobj(app.RouteAxes,'Tag','contest-tag-label'); target=app.Project.targets(2,:);
    for k=1:numel(labels), if norm(labels(k).Position(1:2)-target)<1e-8, assert(strcmp(labels(k).Visible,'off')); end, end
    drawnow; exportapp(app.Figure,fullfile(folder,'uid_partial_coverage_location.png'));
    team=camdesign.teamSolarProject(); app.Project=team; app.syncInputs(); app.calculate(); app.openContestGeometry();
    cfg=configuration(); cfg.leftMM=110; cfg.rightMM=80; cfg.rearMM=180;
    cfg.measurementsConfirmed=false; cfg.coverageRectangleConfirmed=false; enter(app,cfg); push(app.ContestGeometryCheckButton);
    app.Figure.Position=[50 50 1320 860]; app.resizeLayout(); app.fitRouteView(app.ContestGeometryReport.boundary.worstPolygonXY); drawnow;
    exportapp(app.Figure,fullfile(folder,'team_solar_diagnostic.png'));
    app.Figure.Position=[50 50 1100 800]; app.resizeLayout(); drawnow;
    assert(sum([app.ContestGeometryParams.ColumnWidth{:}])<=220);
    assert(strcmp(app.ContestGeometryTargetTable.ColumnName{1},'序号'));
    exportapp(app.Figure,fullfile(folder,'team_solar_narrow.png'));
    report=struct('checksPassed',3,'release',version('-release'),'checks',{{'empty problem set displays 无','selected label hidden; detail moved to axes title','narrow numeric column stays visible; short table headers and team screenshots refreshed'}});
    fid=fopen(fullfile(folder,'location_verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
    fprintf('CONTEST_GEOMETRY_LOCATION_PASS checks=3\n'); return;
end
app.Project=project; app.syncInputs(); app.calculate(); app.openContestGeometry();
assert(~isfield(app.inputProject().params,'contestGeometry'));
push(app.ContestGeometryCheckButton);
assert(~app.ContestGeometryReport.configured && ~app.ContestGeometryReport.sampledGeometryPassed && contains(app.ContestGeometryNotice.Text,'无法验收'));
assert(strcmp(app.TrainingShortcut.Visible,'on') && strcmp(app.ContestGeometryShortcut.Visible,'on'));
checks={'old project stays unchanged and unconfigured; separate visible geometry shortcut leaves training entry available'};

cfg=configuration(); cfg.measurementsConfirmed=false; cfg.coverageRectangleConfirmed=false; enter(app,cfg);
push(app.ContestGeometryCheckButton);
assert(app.ContestGeometryReport.valid && app.ContestGeometryReport.boundary.satisfied && app.ContestGeometryReport.coverage.satisfied);
assert(~app.ContestGeometryReport.sampledGeometryPassed && contains(app.ContestGeometryNotice.Text,'无法验收'));
info=struct('fullAuto',true,'verifiedFeasible',true,'convergencePassed',true, ...
    'assessment',struct('numericalChecks',struct('passed',true,'camMaxDifferenceMM',0,'inverseFrontMaxErrorMM',0)));
[text,color,numerical]=app.autoTuneGrade(info); assert(numerical && contains(text,'比赛几何') && color(1)>color(2));
file=fullfile(folder,'diagnostic_project.mat'); app.action('save',file); loaded=camdesign.importProject(file);
assert(isequaln(loaded.params.contestGeometry,app.Project.params.contestGeometry));
cfg.measurementsConfirmed=true; cfg.coverageRectangleConfirmed=true; enter(app,cfg); push(app.ContestGeometryCheckButton);
assert(app.ContestGeometryReport.sampledGeometryPassed && ~app.ContestGeometryReport.competitionCertified);
assert(~isempty(findobj(app.RouteAxes,'Tag','contest-envelope')));
app.calculate(); assert(app.contestGeometryIsCurrent() && ~isempty(findobj(app.RouteAxes,'Tag','contest-envelope')));
checks{end+1}='unconfirmed geometry cannot pass or inherit green numerical verdict; confirmed test input can pass sampled scope; save/load and same-project redraw work';

cfg.rightMM=1000; enter(app,cfg);
assert(isempty(app.ContestGeometryReport) && isempty(findobj(app.RouteAxes,'Tag','contest-envelope')));
push(app.ContestGeometryCheckButton);
assert(~app.ContestGeometryReport.boundary.satisfied && ~app.ContestGeometryReport.sampledGeometryPassed);
assert(app.ContestGeometryReport.coverage.satisfied && app.ContestGeometryReport.boundary.minimumMarginMM<0);
push(app.ContestGeometryBodyButton); assert(~isempty(findobj(app.RouteAxes,'Tag','contest-envelope')));
app.fitRouteView(app.ContestGeometryReport.boundary.worstPolygonXY); drawnow;
exportapp(app.Figure,fullfile(folder,'body_boundary_failure.png'));
cfg=configuration(); cfg.coverXMinMM=-6; cfg.coverXMaxMM=6; enter(app,cfg); push(app.ContestGeometryCheckButton);
assert(~app.ContestGeometryReport.coverage.satisfied && numel(app.ContestGeometryReport.coverage.problemVisitIndices)==3);
app.selectContestGeometryTarget(struct('Indices',[2 1]));
assert(~isempty(findobj(app.RouteAxes,'Tag','contest-best-cover')) && ~isempty(findobj(app.RouteAxes,'Tag','contest-tag')));
drawnow; exportapp(app.Figure,fullfile(folder,'uid_partial_coverage_location.png'));
checks{end+1}='parameter edits invalidate old report/markers; shell contact failure and insufficient whole UID coverage locate true polygons/visit numbers independently';

% A failed cam still has an auditable, valid body route.
project=fixture(); project.params.wheelDiameter=1; project.params.contestGeometry=configuration();
app.Project=project; app.syncInputs(); app.Result=[]; app.renderUncomputedRoute(); app.openContestGeometry();
push(app.ContestGeometryCheckButton);
assert(app.ContestGeometryReport.sampledGeometryPassed && isempty(app.Result));
assert(~isempty(findobj(app.RouteAxes,'Tag','route-front-uncomputed')) && contains(app.Status.Text,'凸轮/机构数值尚未计算'));
app.SimulationMode=true; app.refreshControls();
assert(strcmp(app.ContestGeometryCheckButton.Enable,'off'));
app.checkContestGeometry(); assert(isempty(app.ContestGeometryReport) && contains(app.ContestGeometryNotice.Text,'退出反推'));
app.SimulationMode=false; app.refreshControls();
checks{end+1}='route-only audit works without cam; fixed-cam simulation mode refuses design-route auditing and explicitly asks to exit';

% Complete force-switch backups include both applied settings and raw edits.
project=fixture(); project.params.contestGeometry=configuration(); app.Project=project; app.syncInputs(); app.calculate();
push(app.ContestGeometryCheckButton);
app.ContestGeometryParams.Data{1,2}=55; app.contestGeometryChanged();
raw=app.ContestGeometryParams.Data;
app.TrainingModel.Value='bezier-blend-independent-v1'; invoke(app.TrainingModel);
app.TrainingFields(2).Value=6; app.TrainingFields(3).Value=20; app.TrainingFields(4).Value=3; app.markTrainingDirty();
assert(app.applyTraining(true)); backup=load(app.ModelSwitchBackupPath,'backup');
assert(isequaln(backup.backup.contestGeometryState.paramsData,raw));
assert(app.restoreModelSwitch() && isequaln(app.ContestGeometryParams.Data,raw) && app.TrainingDirty);
assert(app.Project.params.contestGeometry.leftMM==50);
% Previous backup versions with no geometry extension remain restorable.
legacy=backup.backup; legacy=rmfield(legacy,'contestGeometryState'); backup=legacy;
legacyPath=fullfile(folder,'legacy_backup_without_geometry_extension.mat'); save(legacyPath,'backup');
assert(app.restoreModelSwitch(legacyPath));
assert(app.ContestGeometryParams.Data{1,2}==50 && isempty(app.ContestGeometryReport));
checks{end+1}='force backup restores applied and pending geometry state; older full backup files without the extension remain compatible';

team=camdesign.teamSolarProject(); app.Project=team; app.syncInputs(); app.calculate(); app.openContestGeometry();
cfg=configuration(); cfg.leftMM=110; cfg.rightMM=80; cfg.rearMM=180;
cfg.measurementsConfirmed=false; cfg.coverageRectangleConfirmed=false; enter(app,cfg); push(app.ContestGeometryCheckButton);
teamReport=app.ContestGeometryReport;
assert(teamReport.valid && ~teamReport.sampledGeometryPassed && size(app.ContestGeometryTargetTable.Data,1)==10);
assert(app.Project.params.gearRatio==35 && app.Project.params.driveY==-110 && app.Project.params.wheelDiameter==135);
assert(teamReport.coverage.expectedLocationIDs(1)==teamReport.coverage.expectedLocationIDs(end));
app.Figure.Position=[50 50 1320 860]; app.resizeLayout(); app.fitRouteView(teamReport.boundary.worstPolygonXY); drawnow;
exportapp(app.Figure,fullfile(folder,'team_solar_diagnostic.png'));
app.Figure.Position=[50 50 1100 800]; app.resizeLayout(); drawnow;
exportapp(app.Figure,fullfile(folder,'team_solar_narrow.png'));
assert(app.TrainingShortcut.Position(3)>120 && app.ContestGeometryShortcut.Position(3)>=90);
assert(app.ContestGeometryParams.Position(4)>55 && size(app.ContestGeometryParams.Data,1)==11);
% New UI invalid values reject atomically and leave project/results intact.
before=app.Project; app.ContestGeometryParams.Data{1,2}=-1; app.contestGeometryChanged(); push(app.ContestGeometryCheckButton);
assert(isequaln(app.Project,before) && isempty(app.ContestGeometryReport) && contains(app.ContestGeometryNotice.Text,'失败'));
checks{end+1}='confirmed team design solar 10-visit case uses unmeasured rectangular assumptions only; narrow controls accessible and invalid settings reject atomically';

report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks}, ...
    'teamSolar',teamReport,'screenshots',{{'body_boundary_failure.png','uid_partial_coverage_location.png','team_solar_diagnostic.png','team_solar_narrow.png'}}, ...
    'scope','Owned hidden windows and synthetic rectangular dimensions; no as-built vehicle, continuous swept-volume or RFID certification.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fprintf('CONTEST_GEOMETRY_UI_PASS checks=%d\n',numel(checks));
end
function enter(app,cfg)
[~,state]=camdesign.contestGeometrySettings(struct());
for k=1:numel(state.fieldNames), app.ContestGeometryParams.Data{k,2}=cfg.(state.fieldNames{k}); end
app.ContestGeometryMeasured.Value=cfg.measurementsConfirmed; app.ContestGeometryCoverageConfirmed.Value=cfg.coverageRectangleConfirmed;
app.contestGeometryChanged();
end
function invoke(control), callback=control.ValueChangedFcn; callback(control,[]); end
function push(control), callback=control.ButtonPushedFcn; callback(control,[]); end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
function cfg=configuration()
cfg=struct('version','rectangle-contest-geometry-v1','leftMM',50,'rightMM',50,'frontMM',40,'rearMM',160, ...
    'coverXMinMM',-25,'coverXMaxMM',25,'coverYMinMM',-100,'coverYMaxMM',-20,'tagDiameterMM',20, ...
    'boundaryMarginMM',0,'coverageMarginMM',0,'measurementsConfirmed',true,'coverageRectangleConfirmed',true);
end
function project=fixture()
project=camdesign.defaultProject(); p=project.params; p.mechanism='flat'; p.gearRatio=35;
p.headingDeg=0; p.sensorX=0; p.sensorY=0; p.samples=101; p.camSamples=181; p.bounds=[0 1000 0 1000];
project.params=p; project.nodes=[300 300;600 300;900 300]; project.targets=project.nodes-[60 0];
end
