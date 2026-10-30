function report=check_trajectory_bounds()
% Analytic center-point geometry and constraint/gate contracts; no long solve.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:BoundsBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','fixed_ratio_results_20261030','boundary_regression');
if ~isfolder(folder), mkdir(folder); end
checks={}; project=verticalCase();
boundary=camdesign.fminconModel(project,project.nodes);
assert(boundary.valid && boundary.maxViolation==0 && boundary.trajectoryBoundsSatisfied);
assert(boundary.maxTrajectoryOutsideMM==0);
expected=size(project.targets,1)+5*project.params.samples+2*project.params.camSamples+1;
assert(numel(boundary.constraints)==expected);

% Heading=90 deg: rear midpoint=(20,y-20), driven center=(20-30,y-20).
% Front and every spline node are inside; only the driven center crosses xmin.
outside=project; outside.params.drivenX=-30;
model=camdesign.fminconModel(outside,outside.nodes);
assert(model.valid && model.maxNodeBoundViolation==0 && ~model.trajectoryBoundsSatisfied);
assert(abs(model.maxTrajectoryOutsideMM-10)<1e-10 && abs(model.maxTrajectoryBoundViolation-.1)<1e-12);
[residuals,diagnostic]=camdesign.trajectoryBounds(model.result.route,outside.params.bounds);
assert(numel(residuals)==4*outside.params.samples && all(abs(residuals(1:outside.params.samples)-.1)<1e-12));
assert(strcmp(diagnostic.worstPoint,'driven') && strcmp(diagnostic.worstSide,'xmin'));
assert(diagnostic.components.front.maximumOutsideMM==0 && diagnostic.components.rear.maximumOutsideMM==0);
assert(isequal(model.constraints(end-4*outside.params.samples:end-1),residuals));
checks{end+1}='analytic rigid offset detects 10 mm driven-center violation despite inside front/nodes';

% All five named points and all four sides must influence the fixed 4N vector.
names={'front','rear','drive','driven','sensor'}; unit=struct();
for k=1:numel(names), unit.(names{k})=repmat([.5 .5],3,1); end
for point=1:numel(names)
    for side=1:4
        trial=unit;
        if side==1, trial.(names{point})(2,1)=-.1;
        elseif side==2, trial.(names{point})(2,1)=1.1;
        elseif side==3, trial.(names{point})(2,2)=-.1;
        else, trial.(names{point})(2,2)=1.1; end
        [c,d]=camdesign.trajectoryBounds(trial,[0 1 0 1]);
        assert(numel(c)==12 && abs(c(3*(side-1)+2)-.1)<1e-12);
        assert(nnz(c>0)==1 && ~d.satisfied && abs(d.maximumOutsideMM-.1)<1e-12);
        assert(strcmp(d.worstPoint,names{point}));
    end
end
checks{end+1}='every modeled center and every field side affects the four fixed residual blocks';

atBoundary=unit;
atBoundary.front=[0 0;1 0;1 1]; atBoundary.sensor=[0 1;1 0;0 0];
[c,exact]=camdesign.trajectoryBounds(atBoundary,[0 1 0 1]);
assert(exact.satisfied && exact.maximumOutsideMM==0 && max(c)==0);
tiny=project; tiny.params.drivenX=-20-1e-7;
tinyVerification=camdesign.verifyConstrained(tiny,4);
assert(~tinyVerification.verifiedFeasible && ~tinyVerification.trajectoryBoundsSatisfied);
assert(tinyVerification.maxTrajectoryOutsideMM>0 && tinyVerification.maxTrajectoryOutsideMM<1e-6);
checks{end+1}='exact boundary is accepted; positive submicron overshoot is rejected without solver tolerance';

% Exact quadratic arch with both interpolation nodes inside a 100 mm upper
% boundary: y=(u/sqrt(2))*(1-u/1000), max y=1000/(4*sqrt(2)).
arch=camdesign.defaultProject(); arch.params.mechanism='flat';
arch.params.samples=101; arch.params.headingDeg=45; arch.params.startSteeringDeg=0;
arch.params.bounds=[-100 800 -300 100]; arch.nodes=[0 0;1000/sqrt(2) 0]; arch.targets=arch.nodes;
arch.params.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',[0;1000], ...
    'endDerivative',[1 -1]/sqrt(2));
camdesign.validateProject(arch); route=camdesign.route(arch.nodes,arch.params);
[~,overshoot]=camdesign.trajectoryBounds(route,arch.params.bounds);
assert(all(arch.nodes(:,2)<=100) && ~overshoot.satisfied);
assert(abs(overshoot.components.front.maximumOutsideMM-(1000/(4*sqrt(2))-100))<1e-9);
checks{end+1}='analytic clamped-cubic arch exposes interpolation overshoot between inside nodes';

invalid=project; invalid.nodes(2,:)=invalid.nodes(1,:);
bad=camdesign.fminconModel(invalid,project.nodes);
assert(~bad.valid && strcmp(bad.errorIdentifier,'cam:Duplicate'));
assert(numel(bad.constraints)==expected && all(isfinite(bad.constraints)) && all(bad.constraints>0));
assert(isfinite(bad.objective) && ~bad.trajectoryBoundsSatisfied);
nonfinite=boundary.result; nonfinite.route.sensor(1,1)=NaN;
badNonfinite=camdesign.fminconModel(project,project.nodes,nonfinite);
assert(~badNonfinite.valid && strcmp(badNonfinite.errorIdentifier,'cam:ConstraintNonfinite'));
assert(numel(badNonfinite.constraints)==expected && all(isfinite(badNonfinite.constraints)) && all(badNonfinite.constraints>0));
checks{end+1}='invalid/NaN geometry retains finite positive full-length failure vector';

missing=boundary.result; missing.route=rmfield(missing.route,'rear');
mustThrow(@()camdesign.fminconModel(project,project.nodes,missing),'MATLAB:');
dimension=boundary.result; dimension.route.rear(end,:)=[];
mustThrow(@()camdesign.fminconModel(project,project.nodes,dimension),'cam:ConstraintDimension');
mustThrow(@()camdesign.fminconModel(project,project.nodes,struct()),'MATLAB:');
checks{end+1}='missing fields and inconsistent route dimensions propagate as programming errors';

accepted=camdesign.verifyConstrained(project,4);
rejected=camdesign.verifyConstrained(outside,4);
assert(accepted.verifiedFeasible && accepted.nodeBoundsSatisfied && accepted.trajectoryBoundsSatisfied);
assert(accepted.optimizationGrid.maxTrajectoryOutsideMM==0 && accepted.refinedGrid.maxTrajectoryOutsideMM==0);
assert(~rejected.verifiedFeasible && rejected.nodeBoundsSatisfied && ~rejected.trajectoryBoundsSatisfied);
assert(rejected.optimizationGrid.thresholdsSatisfied && rejected.refinedGrid.thresholdsSatisfied);
assert(rejected.optimizationGrid.intersectionFree && rejected.refinedGrid.intersectionFree);
assert(rejected.refinedGrid.routeSamples==4*(project.params.samples-1)+1);
assert(abs(rejected.optimizationGrid.maxTrajectoryOutsideMM-10)<1e-10 ...
    && abs(rejected.refinedGrid.maxTrajectoryOutsideMM-10)<1e-10);
checks{end+1}='both original/refined grids independently gate sampled center bounds and preserve node gate';

source=fullfile(root,'outputs','route_refinement_20261029','convergence_300', ...
    'refined_twice_fmincon-interior-point-experimental-v1.mat');
assert(isfile(source),'Historical CHG014 candidate is required for this regression.');
historical=load(source,'q','verification','rules');
assert(historical.verification.verifiedFeasible,'Expected preserved pre-boundary gate result.');
% Preserve this old boundary regression's physical cam, explicitly selecting
% its archived ratio in the fixture only. Production never selects a ratio.
historical.q.params.gearRatio=historical.verification.optimizationGrid.effectiveRatio;
historical.q.params.autoRatio=false;
corrected=camdesign.verifyConstrained(historical.q,4);
assert(~corrected.verifiedFeasible && corrected.nodeBoundsSatisfied && ~corrected.trajectoryBoundsSatisfied);
% The archived coarse effective ratio used to be increased again on the fine
% grid. With hardware fixed, its fine return is 59.991 degrees, below 60.
assert(corrected.optimizationGrid.thresholdsSatisfied && ~corrected.refinedGrid.thresholdsSatisfied);
hm=corrected.refinedGrid.metrics;
assert(~hm.returnAngleSatisfied && hm.actualReturnDeg>59.9 && hm.actualReturnDeg<60);
assert(hm.maxPressureDeg<=historical.q.params.maxPressureDeg && hm.maxHitError<=historical.q.params.hitTolerance);
assert(corrected.optimizationGrid.intersectionFree && corrected.refinedGrid.intersectionFree);
assert(corrected.refinedGrid.maxTrajectoryOutsideMM>100 && corrected.refinedGrid.maxTrajectoryOutsideMM<130);
previousOutside=max(structfun(@(x)x.maximumOutsideMM,historical.rules.modeledPointBounds));
assert(abs(corrected.refinedGrid.maxTrajectoryOutsideMM-previousOutside)<1e-8);
historicalAudit=struct('source',source,'originalVerifiedFeasible',historical.verification.verifiedFeasible, ...
    'newVerification',corrected,'preservedHistoricalOutsideMM',previousOutside, ...
    'note','Historical MAT is read only; new gate result is saved separately.');
save(fullfile(folder,'historical_34_new_gate.mat'),'historicalAudit');
checks{end+1}='preserved old 34-node threshold-passing candidate is rejected for sampled center excursion';

report=struct('release',version('-release'),'checks',{checks}, ...
    'constraintCount',expected,'analyticDrivenOutsideMM',model.maxTrajectoryOutsideMM, ...
    'analyticArchFrontOutsideMM',overshoot.components.front.maximumOutsideMM, ...
    'exactBoundary',exact,'submicronVerification',tinyVerification, ...
    'acceptedFixture',accepted,'rejectedFixture',rejected,'historical34',historicalAudit, ...
    'scope','Five modeled centers at route samples on both grids; no wheel/body outline or continuous collision certification.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('TRAJECTORY_BOUNDS_CASE_PASS %s\n',checks{k}); end
fprintf('TRAJECTORY_BOUNDS_PASS cases=%d count=%d oldVerified=%d newVerified=%d old34OutsideMM=%.9f\n', ...
    numel(checks),expected,historical.verification.verifiedFeasible,corrected.verifiedFeasible,corrected.refinedGrid.maxTrajectoryOutsideMM);
end

function project=verticalCase()
project=camdesign.defaultProject(); project.name='analytic straight five-center fixture';
project.params.mechanism='flat'; project.params.samples=101; project.params.camSamples=181;
project.params.headingDeg=90; project.params.startSteeringDeg=0;
project.params.driveY=-20; project.params.drivenY=-20;
project.params.driveX=10; project.params.drivenX=-20;
project.params.sensorX=0; project.params.sensorY=0;
project.params.autoRatio=false; project.params.gearRatio=2;
project.params.bounds=[0 100 20 120];
project.nodes=[20 40;20 80;20 120]; project.targets=project.nodes;
end
function mustThrow(callback,prefix)
propagated=false;
try, callback(); catch ex, propagated=startsWith(ex.identifier,prefix); end
assert(propagated,'Expected programming error %s did not propagate.',prefix);
end
