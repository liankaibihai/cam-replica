function report=check_conversion_chain()
% Independent finite-point disk-envelope recovery from ACTUAL cam outline.
% No pitch normals or stored workRadius used by the recovery algorithm.
root=fileparts(mfilename('fullpath')); p=camdesign.solarTestProject(); p=p.params;
phi=linspace(0,5,2401)'; angle=deg2rad(12)*sin(phi);
r=struct('driveDistance',phi*p.wheelDiameter*p.gearRatio/2,'steering',angle);
counts=[721 1441 2881 5761]; errors=zeros(size(counts));
for k=1:numel(counts)
    p.camSamples=counts(k); c=camdesign.camProfile(r,p);
    assert(min(c.undercutMargin)>0 && isempty(camdesign.selfIntersections(c.actual)));
    probe=linspace(.013,4.987,241)';
    recovered=fromOutline(c.actual,p.rollerRadius,probe);
    truth=p.referenceDiameter/2+p.lever*tan(deg2rad(12)*sin(probe));
    errors(k)=max(abs(recovered-truth));
end
fprintf('Actual-outline recovery grid errors: %s mm\n',mat2str(errors,12));
assert(errors(end)<.01 && errors(end)<errors(1)/20,'Actual-outline recovery must converge.');
% Circle is independently known to have surface radius q0-r and recover q0.
r.steering=zeros(size(phi)); c=camdesign.camProfile(r,p);
circleSurfaceError=max(abs(vecnorm(c.actual,2,2)-(p.referenceDiameter/2-p.rollerRadius)));
circleError=max(abs(fromOutline(c.actual,p.rollerRadius,probe)-p.referenceDiameter/2));
assert(circleSurfaceError<1e-10 && circleError<.001);
% Actual solar long-run candidate: verify working outline recovery separately
% from the existing theoretical-cam inversion. Still not a machining release.
saved=load(fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'),'q');
solar=saved.q; solar.params.samples=4801; solar.params.camSamples=5761;
result=camdesign.evaluate(solar,true); c=result.cam;
assert(min(c.undercutMargin)>0 && result.metrics.intersectionCount==0);
probe=linspace(.001,c.workEnd-.001,401)';
recovered=fromOutline(c.actual,solar.params.rollerRadius,probe);
if isfield(c,'workPP'), law=c.workPP; else, law=spline(c.workPhi,c.workRadius); end
truth=ppval(law,probe);
solarError=max(abs(recovered-truth));
assert(solarError<.01);
sim=camdesign.simulate(c,solar.params,result.route.front(1,:),result.route.heading(1));
roundtrip=max(vecnorm(sim.sensor-result.route.sensor,2,2));
report=struct('release',version('-release'),'sampleCounts',counts, ...
    'syntheticActualOutlineRecoveryMaxMM',errors,'circleRecoveryMaxMM',circleError,'circleSurfaceErrorMM',circleSurfaceError, ...
    'solarActualOutlineRecoveryMaxMM',solarError,'solarTheoreticalRoundtripMaxMM',roundtrip, ...
    'solarPhysicalMetrics',result.metrics,'ratio',solar.params.gearRatio, ...
    'method','For each follower ray, intersect disks centered on actual contour vertices; select the outermost center. Dense vertex approximation to configuration-space obstacle, independent of pitch normals.', ...
    'scope','Regular radial translating roller only; finite outline vertices and sampled phases, no continuous contact certification, no actual-contact vehicle integration, no original-software equivalence or hardware validation.');
folder=fullfile(root,'outputs','conversion_chain_20261031'); if ~isfolder(folder), mkdir(folder); end
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONVERSION_CHAIN_PASS outline synthetic=%.9g mm solar=%.9g mm theoretical roundtrip=%.9g mm\n',errors(end),solarError,roundtrip);
end

function q=fromOutline(points,radius,phase)
q=zeros(size(phase));
for j=1:numel(phase)
    e=[cos(phase(j));sin(phase(j))]; n=[-e(2);e(1)];
    along=points*e; across=points*n; keep=abs(across)<=radius;
    assert(any(keep),'No contact disk intersects follower ray.');
    q(j)=max(along(keep)+sqrt(max(0,radius^2-across(keep).^2)));
end
end
