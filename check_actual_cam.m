function report=check_actual_cam(folder)
% Independent contracts for frozen-polygon contact and actual-driven car.
root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','actual_cam_20261031'); end
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject(); p=project.params;
groups={};

% These rays hit the interior of a long edge: vertex-only disks miss them.
rectangle=[-10 -20;10 -20;10 20;-10 20;-10 -20];
ph=[0;.2;.5;pi/2]; expected=[13./cos(ph(1:3));23];
[q,c]=camdesign.contactFromOutline(rectangle,3,ph);
edgeError=max(abs(q-expected));
assert(edgeError<1e-10 && all(c.featureType==2));
assert(norm(c.point(1,:)-[10 0])<1e-10);
assert(max(abs(c.pressure-[0;.2;.5;0]))<1e-10);
groups{end+1}='analytic segment-interior contact and pressure';

% A second algorithm uses unrotated XY, distance-to-polygon and bisection.
% It never forms offset segments, circle/ray intersections or pitch data.
b=linspace(0,2*pi,722)'; radius=45+3*sin(3*b)+2*cos(2*b);
outline=radius.*[cos(b),sin(b)]; outline(end,:)=outline(1,:);
probe=linspace(.017,2*pi-.031,37)'; roller=2.7;
[q,c]=camdesign.contactFromOutline(outline,roller,probe);
oracle=zeros(size(probe));
for j=1:numel(probe), oracle(j)=bisectContact(outline,roller,probe(j)); end
oracleError=max(abs(q-oracle)); assert(oracleError<1e-9);
[reverse,rc]=camdesign.contactFromOutline(flipud(outline),roller,probe);
windingError=max(abs(q-reverse)); pressureWindingError=max(abs(c.pressure-rc.pressure));
assert(windingError<1e-10 && pressureWindingError<1e-9);
step=1e-6;
qp=camdesign.contactFromOutline(outline,roller,probe+step);
qm=camdesign.contactFromOutline(outline,roller,probe-step);
pressureDerivativeError=max(abs(c.pressure-atan2(abs((qp-qm)/(2*step)),q)));
assert(pressureDerivativeError<1e-7);
groups{end+1}='noncircle independent bisection oracle and winding invariance';

% Known constant steering determines an analytic circle trajectory. Changing
% outline sampling changes only the polygon; there is no theoretical cam.
angles=[0 .1 -.1]; counts=[721 5761]; circleErrors=zeros(3,2);
circleRadiusErrors=circleErrors; circleHeadingErrors=circleErrors;
for j=1:numel(angles)
    delta=angles(j); q0=p.referenceDiameter/2+p.lever*tan(delta);
    for k=1:numel(counts)
        c=struct('actual',circle(q0-p.rollerRadius,counts(k)),'workEnd',.8);
        sim=camdesign.simulateActual(c,p,[0 0],0,Samples=401);
        [front,sensor,heading]=constantTurn(sim.driveDistance,delta,p);
        circleErrors(j,k)=max([vecnorm(sim.front-front,2,2);vecnorm(sim.sensor-sensor,2,2)]);
        circleHeadingErrors(j,k)=max(abs(sim.heading-heading));
        circleRadiusErrors(j,k)=max(abs(sim.contactRadius-q0));
        sagitta=(q0-p.rollerRadius)*(1-cos(pi/(counts(k)-1)));
        assert(circleRadiusErrors(j,k)<=sagitta+1e-9);
    end
end
assert(max(circleErrors(:,2))<.03 && all(circleErrors(:,2)<circleErrors(:,1)/20));
groups{end+1}='analytic straight and signed constant-turn car with polygon refinement';

% Simulation must depend on actual geometry, phase, physical dimensions and
% explicit input ratio only. Deleted or corrupted pitch data cannot drive it.
minimal=struct('actual',circle(48,1441),'workEnd',.8);
base=camdesign.simulateActual(minimal,p,[0 0],0,Samples=201);
poison=minimal; poison.pitch=NaN; poison.radius=1e100;
poison.workRadius='forbidden'; poison.effectiveRatio=1e6;
poison.workPhi=linspace(0,.8,13)';
isolated=camdesign.simulateActual(poison,p,[0 0],0,Samples=201);
assert(isequal(base.front,isolated.front) && isequal(base.sensor,isolated.sensor));
mutated=minimal; mutated.actual=circle(49,1441);
changed=camdesign.simulateActual(mutated,p,[0 0],0,Samples=201);
mutationDifference=max(vecnorm(changed.sensor-base.sensor,2,2)); assert(mutationDifference>100);
reverseCam=minimal; reverseCam.actual=flipud(minimal.actual);
reverseSim=camdesign.simulateActual(reverseCam,p,[0 0],0,Samples=201);
assert(max(vecnorm(base.sensor-reverseSim.sensor,2,2))<1e-8);
ratioSim=camdesign.simulateActual(minimal,p,[0 0],0,Samples=201,GearRatio=36);
assert(ratioSim.physicalGearRatio==36 && p.gearRatio==35);
assert(abs(ratioSim.driveDistance(end)/base.driveDistance(end)-36/35)<1e-12);
groups{end+1}='actual mutation, poisoned/deleted theoretical fields and physical ratio';

% Geometry is rejected before vehicle integration, without theoretical fallback.
invalid=struct;
invalid.open=expect(@()camdesign.contactFromOutline(rectangle(1:end-1,:),3,0),'cam:ActualOutlineOpen');
bad=rectangle; bad(2,1)=NaN;
invalid.nonfinite=expect(@()camdesign.contactFromOutline(bad,3,0),'cam:ActualOutlineInvalid');
bad=[rectangle(1:2,:);rectangle(2:end,:)];
invalid.zeroEdge=expect(@()camdesign.contactFromOutline(bad,3,0),'cam:ActualOutlineDegenerate');
bad=[-1 0;0 0;1 0;-1 0];
invalid.zeroArea=expect(@()camdesign.contactFromOutline(bad,3,0),'cam:ActualOutlineDegenerate');
bad=[-2 -2;2 2;-2 2;2 -2;3 -3;-2 -2];
invalid.selfIntersection=expect(@()camdesign.contactFromOutline(bad,3,0),'cam:ActualOutlineSelfIntersection');
bad=[1 1;3 1;3 3;1 3;1 1];
invalid.originOutside=expect(@()camdesign.contactFromOutline(bad,3,0),'cam:ActualOutlineOrigin');
invalid.zeroRoller=expect(@()camdesign.contactFromOutline(rectangle,0,0),'cam:ActualContactRadius');
invalid.rotation=expect(@()camdesign.contactFromOutline(rectangle,3,0,RotationConvention='counterclockwise'),'cam:ActualRotationConvention');
invalid.missingPhase=expect(@()camdesign.simulateActual(rmfield(minimal,'workEnd'),p,[0 0],0),'cam:ActualPhase');
bad=minimal; bad.workPhi=[0;.9];
invalid.phaseConflict=expect(@()camdesign.simulateActual(bad,p,[0 0],0),'cam:ActualPhase');
groups{end+1}='explicit rejection of unsupported geometry, zero radius, phase and rotation';

% Freeze the exact same fine solar polygon for both RK4 phase densities.
saved=load(fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'),'q');
solar=saved.q; solar.params.samples=4801; solar.params.camSamples=5761;
originalProject=solar; result=camdesign.evaluate(solar,true); frozen=result.cam.actual;
[solarReport,solarSimulation]=camdesign.verifyActualClosure(solar,result,Samples=1201);
assert(solarReport.valid && solarReport.contactValid && solarReport.integrationConverged && solarReport.closurePassed);
assert(~solarReport.geometryFeasible && ~solarReport.passed);
assert(~solarReport.pressureSatisfied && ~solarReport.returnAngleSatisfied);
assert(solarReport.maxPressureDeg>=solarReport.maxWorkPressureDeg-1e-10);
assert(isequal(frozen,result.cam.actual) && isequal(originalProject,solar) && solarReport.physicalGearRatio==35);
% Whole reporting pipeline must also ignore forbidden theoretical fields.
poisonedResult=result;
poisonedResult.cam=struct('actual',frozen,'workEnd',result.cam.workEnd, ...
    'pitch',NaN,'radius',NaN,'workRadius',NaN,'effectiveRatio',-1e10);
[isolatedReport,isolatedSimulation]=camdesign.verifyActualClosure(solar,poisonedResult,Samples=1201);
assert(isequal(solarSimulation.front,isolatedSimulation.front) && isequal(solarSimulation.sensor,isolatedSimulation.sensor));
assert(isequaln(solarReport,isolatedReport));
groups{end+1}='frozen solar fine outline, full-cycle physical gates and report isolation';

% Existing cubic candidate has an actual self-intersection. It must be an
% explicit invalid contact result, regardless of theoretical curve usability.
saved=load(fullfile(root,'outputs','model_mapping_20261031','quality_cubic','result.mat'),'q');
raw=saved.q; raw.params.samples=4801; raw.params.camSamples=5761;
rawResult=camdesign.evaluate(raw,true);
assert(rawResult.metrics.intersectionCount>0);
rawIdentifier=expect(@()camdesign.contactFromOutline(rawResult.cam.actual,raw.params.rollerRadius,0), ...
    'cam:ActualOutlineSelfIntersection');
rawReport=camdesign.verifyActualClosure(raw,rawResult,Samples=101);
assert(~rawReport.valid && ~rawReport.contactValid && ~rawReport.passed && strcmp(rawReport.errorIdentifier,rawIdentifier));
groups{end+1}='real solar self-intersecting actual outline rejected';

% A short explicit work phase isolates the return from the full-circle
% pressure diagnostic. The latter must still inspect the rest of the cam.
b=linspace(0,2*pi,1441)'; radius=48+4*exp(-((b-3.8)/.25).^2);
outline=radius.*[cos(b),sin(b)]; outline(end,:)=outline(1,:);
working=camdesign.simulateActual(struct('actual',outline,'workEnd',.2),p,[0 0],0,Samples=101);
[~,full]=camdesign.contactFromOutline(outline,p.rollerRadius,linspace(0,2*pi,2401)');
assert(full.maxPressureDeg>working.maxPressureDeg+10);
groups{end+1}='return-phase pressure is distinct from working-phase pressure';

report=struct('release',version('-release'),'groupsPassed',numel(groups),'groups',{groups}, ...
    'segmentInteriorMaxErrorMM',edgeError,'independentNoncircleOracleMaxErrorMM',oracleError, ...
    'windingMaxRadiusErrorMM',windingError,'windingMaxPressureErrorRad',pressureWindingError, ...
    'pressureDerivativeMaxErrorRad',pressureDerivativeError, ...
    'analyticCircleSteeringRad',angles,'analyticCircleVertexCounts',counts, ...
    'analyticCircleMaxPathErrorMM',circleErrors,'analyticCircleMaxRadiusErrorMM',circleRadiusErrors, ...
    'analyticCircleMaxHeadingErrorRad',circleHeadingErrors,'actualMutationMaxSensorDifferenceMM',mutationDifference, ...
    'theoreticalFieldsIsolationExact',true,'projectAndOutlineUnchanged',true,'invalidInputs',invalid, ...
    'solarActualClosure',compact(solarReport),'solarDesignMetrics',result.metrics, ...
    'rawCubicIntersectionCount',rawResult.metrics.intersectionCount,'rawCubicRejectedIdentifier',rawIdentifier, ...
    'separatePressureTestWorkDeg',working.maxPressureDeg,'separatePressureTestFullCycleDeg',full.maxPressureDeg, ...
    'scope','Frozen closed polygon plus rigid disk, sampled direct contact and no-slip vehicle only; not continuous-extrema, outline-discretization, original-software or hardware validation.');
save(fullfile(folder,'core_results.mat'),'report','solar','result','solarReport','solarSimulation','rawReport');
fid=fopen(fullfile(folder,'core_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closeFile=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('ACTUAL_CAM_PASS %d groups; oracle=%.12g mm, analytic fine path=%.12g mm\n', ...
    numel(groups),oracleError,max(circleErrors(:,2)));
fprintf('Solar contact residual=%.12g mm; sensor max/RMS=%.12g/%.12g mm; integration=%.12g mm\n', ...
    solarReport.maxContactResidualMM,solarReport.maxSensorDeviationMM,solarReport.rmsSensorDeviationMM,solarReport.integrationMaxSensorDifferenceMM);
fprintf('Solar pressure=%.12g deg return=%.12g deg; closure=%d feasible=%d; raw cubic rejects=%s\n', ...
    solarReport.maxPressureDeg,solarReport.actualReturnDeg,solarReport.closurePassed,solarReport.geometryFeasible,rawIdentifier);
end

function polygon=circle(radius,count)
b=linspace(0,2*pi,count)'; polygon=radius*[cos(b),sin(b)]; polygon(end,:)=polygon(1,:);
end

function [front,sensor,heading]=constantTurn(distance,delta,p)
L=-p.driveY; curvature=tan(delta)/L; heading=curvature*distance/(1+p.driveX*curvature);
if curvature==0, rear=[distance-L,zeros(size(distance))];
else, rear=[sin(heading)/curvature-L,(1-cos(heading))/curvature]; end
forward=[cos(heading),sin(heading)]; right=[sin(heading),-cos(heading)];
front=rear+L*forward; sensor=front+p.sensorX*right+p.sensorY*forward;
end

function q=bisectContact(polygon,r,phase)
direction=[cos(phase),sin(phase)]; lo=0; hi=max(vecnorm(polygon,2,2))+r+1;
A=polygon(1:end-1,:); V=diff(polygon); lengths=sum(V.^2,2);
for iteration=1:60
    mid=(lo+hi)/2; center=mid*direction;
    t=max(0,min(1,sum((center-A).*V,2)./lengths));
    distance=min(vecnorm(center-(A+t.*V),2,2));
    inside=inpolygon(center(1),center(2),polygon(:,1),polygon(:,2));
    if inside || distance<=r, lo=mid; else, hi=mid; end
end
q=(lo+hi)/2;
end

function identifier=expect(callback,expected)
identifier=''; try, callback(); catch ex, identifier=ex.identifier; end
assert(strcmp(identifier,expected),'Expected %s, received %s.',expected,identifier);
end

function value=compact(value)
value=rmfield(value,{'contact','fullCycleContact','hits','visitOrder','trajectoryBounds'});
end
