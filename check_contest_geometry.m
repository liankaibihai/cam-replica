function report=check_contest_geometry()
assert(batchStartupOptionUsed,'cam:BatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','contest_geometry_20261031','core');
if ~isfolder(folder), mkdir(folder); end
cfg=configuration(); p=struct('contestGeometry',cfg); bounds=[0 1000 0 1000];
r=struct('front',[(300:400)',300*ones(101,1)],'heading',zeros(101,1),'steering',99*ones(101,1));
targets=[240 300;340 300]; result=camdesign.contestGeometry(r,targets,bounds,p);
assert(result.sampledGeometryPassed && result.boundary.minimumMarginMM==140 && result.coverage.orderSatisfied);
assert(all([result.coverage.visits.bestMarginMM]>0));
polygon=camdesign.contestBodyPolygon([300 300],pi/2,cfg);
assert(max(abs(polygon-[250 140;350 140;350 340;250 340;250 140]),[],'all')<1e-10);
rotated=camdesign.contestGeometry(struct('front',[300 300],'heading',pi/2),[300 240],bounds,p);
assert(rotated.sampledGeometryPassed && abs(rotated.boundary.minimumMarginMM-140)<1e-10);
checks={'analytic straight and 90deg body transforms; steering/tangent are not substituted for body heading'};

center=struct('front',[170 20],'heading',0);
crossed=camdesign.contestGeometry(center,[110 20],bounds,p);
assert(all(center.front>0) && ~crossed.boundary.satisfied && crossed.boundary.minimumMarginMM==-30);
touch=camdesign.contestGeometry(struct('front',[170 50],'heading',0),[110 50],bounds,p);
assert(~touch.boundary.satisfied && touch.boundary.minimumMarginMM==0);
buffered=cfg; buffered.boundaryMarginMM=2;
t=camdesign.contestGeometry(struct('front',[170 52],'heading',0),[110 52],bounds,struct('contestGeometry',buffered));
assert(~t.boundary.satisfied && t.boundary.minimumMarginMM==0);
checks{end+1}='centers inside do not excuse body crossing; exact contact and configured safety-buffer contact fail';

pose=struct('front',[300 300],'heading',0);
half=camdesign.contestGeometry(pose,[240 280],bounds,p); exact=camdesign.contestGeometry(pose,[240 285],bounds,p);
inside=camdesign.contestGeometry(pose,[240 285.001],bounds,p);
assert(half.coverage.worstBestMarginMM==-5 && ~half.coverage.satisfied);
assert(exact.coverage.worstBestMarginMM==0 && ~exact.coverage.satisfied && inside.coverage.satisfied);
assert(~half.sampledGeometryPassed && inside.sampledGeometryPassed);
checks{end+1}='whole UID disk required; half-exposed and numerical boundary-touch coverage conservatively reject';

path=[(300:500)';(499:-1:300)']; loop=struct('front',[path,300*ones(numel(path),1)],'heading',zeros(size(path)));
repeat=camdesign.contestGeometry(loop,[240 300;440 300;240 300],bounds,p);
assert(repeat.sampledGeometryPassed && isequal(repeat.coverage.expectedLocationIDs,[1 2 1]) && isequal(repeat.coverage.observedLocationIDs,[1 2 1]));
assert(repeat.coverage.visits(3).bestSampleIndex>repeat.coverage.visits(1).bestSampleIndex);
dwell=camdesign.contestGeometry(struct('front',repmat([300 300],5,1),'heading',zeros(5,1)),[240 300;240 300],bounds,p);
extra=camdesign.contestGeometry(loop,targets,bounds,p);
ambiguous=camdesign.contestGeometry(pose,[240 300;250 300],bounds,p);
assert(~dwell.coverage.satisfied && numel(dwell.coverage.observedLocationIDs)==1 && isequal(dwell.coverage.problemVisitIndices,2));
assert(~extra.coverage.satisfied && ~isempty(extra.coverage.extraEventIndices));
assert(ambiguous.coverage.ambiguousSimultaneousEntries && ~ambiguous.coverage.orderSatisfied);
checks{end+1}='repeated start/end require separate reentry; continuous dwell, extra events and simultaneous entries cannot fake order';

unconfirmed=cfg; unconfirmed.measurementsConfirmed=false;
diagnostic=camdesign.contestGeometry(pose,[240 300],bounds,struct('contestGeometry',unconfirmed));
assert(diagnostic.boundary.satisfied && diagnostic.coverage.satisfied && ~diagnostic.sampledGeometryPassed && contains(diagnostic.verdict,'无法验收'));
noFootprint=cfg; noFootprint.coverageRectangleConfirmed=false;
assert(~camdesign.contestGeometry(pose,[240 300],bounds,struct('contestGeometry',noFootprint)).sampledGeometryPassed);
old=struct('gearRatio',35); before=old; missing=camdesign.contestGeometry(struct(),targets,bounds,old);
assert(~missing.configured && ~missing.sampledGeometryPassed && isequal(old,before));
for name={'leftMM','tagDiameterMM'}
    bad=cfg; bad.(name{1})=-1; expect(@()camdesign.contestGeometrySettings(struct('contestGeometry',bad)));
end
for value=[NaN Inf]
    bad=cfg; bad.leftMM=value; expect(@()camdesign.contestGeometrySettings(struct('contestGeometry',bad)));
end
bad=cfg; bad.coverXMinMM=26; expect(@()camdesign.contestGeometrySettings(struct('contestGeometry',bad)));
bad=cfg; bad.coverXMaxMM=100; expect(@()camdesign.contestGeometrySettings(struct('contestGeometry',bad)));
bad=cfg; bad.measurementsConfirmed=2; expect(@()camdesign.contestGeometrySettings(struct('contestGeometry',bad)));
checks{end+1}='missing/unmeasured assumptions cannot pass; negative/nonfinite/malformed values reject; old settings remain unchanged';

project=fixture(); original=project;
expect(@()camdesign.evaluate(project,true)); % Valid route, too little cam phase distance for this test wheel.
[independent,bodyRoute]=camdesign.verifyContestGeometry(project);
assert(independent.sampledGeometryPassed && independent.resolutionSatisfied && independent.eventSequenceStable && ~isempty(bodyRoute));
assert(isequaln(project,original) && independent.gearRatio==35 && all(independent.sampleCounts==[101 1001]));
unresolved=camdesign.verifyContestGeometry(project,MaxSamples=101);
assert(~unresolved.resolutionSatisfied && ~unresolved.sampledGeometryPassed);
short=project; short.nodes=[300 300;350 300;400 300]; short.targets=short.nodes-[60 0];
sameGrid=camdesign.verifyContestGeometry(short,MaxSamples=101);
assert(sameGrid.resolutionSatisfied && ~sameGrid.independentRefinement && ~sameGrid.sampledGeometryPassed);
file=fullfile(folder,'configured_project.mat'); camdesign.saveProject(project,file); loaded=camdesign.importProject(file);
assert(isequaln(loaded,project));
checks{end+1}='route audit independent of cam failure; dual-grid resolution gates, immutable physical inputs and saved setting roundtrip';

exportProject=project; exportProject.params.wheelDiameter=130; validResult=camdesign.evaluate(exportProject,true);
exportProject.params.contestGeometry.rightMM=1000;
paths=camdesign.exportResult(exportProject,validResult,fullfile(folder,'export_current'));
exported=jsondecode(fileread(paths.report));
assert(~exported.contestGeometry.boundary.satisfied && exported.contestGeometry.settings.rightMM==1000);
assert(~exported.contestGeometry.sampledGeometryPassed && ~exported.validation.manufacturingApproved);
oldProject=rmfield(exportProject.params,'contestGeometry'); noConfig=exportProject; noConfig.params=oldProject;
paths=camdesign.exportResult(noConfig,validResult,fullfile(folder,'export_old'));
exportedOld=jsondecode(fileread(paths.report)); assert(~exportedOld.contestGeometry.configured && ~exportedOld.contestGeometry.sampledGeometryPassed);
checks{end+1}='candidate export recomputes new current geometry report and explicitly records unconfigured legacy projects';

team=camdesign.teamSolarProject(); team.params.contestGeometry=cfg; team.params.contestGeometry.measurementsConfirmed=false;
teamBefore=team; teamReport=camdesign.verifyContestGeometry(team);
assert(teamReport.valid && teamReport.configured && ~teamReport.sampledGeometryPassed && isequaln(team,teamBefore));
assert(numel(teamReport.coverage.visits)==10 && teamReport.coverage.expectedLocationIDs(1)==teamReport.coverage.expectedLocationIDs(end));
assert(teamReport.gearRatio==35 && ~teamReport.competitionCertified && ~teamReport.rfidCertified);
checks{end+1}='confirmed team solar preliminary design values retained; ten visits including repeated Earth audited only as unmeasured diagnostic geometry';

report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks}, ...
    'analyticStraight',result,'rotated',rotated,'crossed',crossed,'halfExposed',half,'repeat',repeat, ...
    'routeIndependent',independent,'teamSolar',teamReport,'scope','Numerical analytic/sampled geometry tests only. Configured rectangles are test assumptions, not measured team dimensions.');
save(fullfile(folder,'results.mat'),'report'); fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONTEST_GEOMETRY_CORE_PASS checks=%d team worstBody=%.12g mm problemVisits=%s samples=%s\n', ...
    numel(checks),teamReport.boundary.minimumMarginMM,mat2str(teamReport.coverage.problemVisitIndices),mat2str(teamReport.sampleCounts));
end
function cfg=configuration()
cfg=struct('version','rectangle-contest-geometry-v1','leftMM',50,'rightMM',50,'frontMM',40,'rearMM',160, ...
    'coverXMinMM',-25,'coverXMaxMM',25,'coverYMinMM',-100,'coverYMaxMM',-20,'tagDiameterMM',20, ...
    'boundaryMarginMM',0,'coverageMarginMM',0,'measurementsConfirmed',true,'coverageRectangleConfirmed',true);
end
function project=fixture()
project=camdesign.defaultProject(); p=project.params; p.mechanism='flat'; p.gearRatio=35; p.wheelDiameter=1;
p.headingDeg=0; p.sensorX=0; p.sensorY=0; p.samples=101; p.camSamples=181; p.bounds=[0 1000 0 1000];
p.contestGeometry=configuration(); project.params=p; project.nodes=[300 300;600 300;900 300]; project.targets=project.nodes-[60 0];
end
function expect(callback)
failed=false; try, callback(); catch, failed=true; end; assert(failed,'Expected explicit rejection.');
end
