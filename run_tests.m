function summary = run_tests()
% Analytical and integration checks for the independent mechanics model.
root=fileparts(mfilename('fullpath')); addpath(root);
tests={@testStraight,@testCircle,@testMechanisms,@testClosedCam, ...
    @testRoundTrip,@testOptimize,@testSaveImport,@testImportTypeSchemes,@testExport,@testReject,@testIntersections};
names=cellfun(@func2str,tests,'UniformOutput',false); passed=false(size(tests));
for i=1:numel(tests)
    tests{i}(); passed(i)=true; fprintf('PASS %s\n',names{i});
end
summary=struct('release',version('-release'),'passed',sum(passed),'total',numel(tests),'tests',{names});
fprintf('RESULT %s\n',jsonencode(summary));
if ~isfolder(fullfile(root,'outputs')), mkdir(fullfile(root,'outputs')); end
fid=fopen(fullfile(root,'outputs','test_results.json'),'w');
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true));
end

function p=straightProject()
p=camdesign.defaultProject(); p.params.headingDeg=0; p.params.sensorX=0; p.params.sensorY=0;
p.nodes=[0 0;500 0;1000 0]; p.targets=p.nodes;
end

function testStraight()
p=straightProject(); r=camdesign.evaluate(p);
assert(max(abs(r.route.steering))<1e-10);
assert(abs(r.route.driveDistance(end)-1000)<1e-8);
assert(r.metrics.maxHitError<1e-8);
assert(max(abs(vecnorm(r.cam.actual,2,2)-(p.params.referenceDiameter/2-p.params.rollerRadius)))<1e-8);
end

function testCircle()
project=camdesign.defaultProject(); p=project.params; R=1000; L=-p.driveY;
p.headingDeg=0; p.startSteeringDeg=atan2d(L,R); p.samples=2401;
theta=linspace(0,1.2,101)'; rear=[R*sin(theta),R*(1-cos(theta))];
front=rear+L*[cos(theta),sin(theta)];
r=camdesign.route(front,p);
% Exclude the final end-slope interval (end tangent estimated by a chord).
use=r.u<0.97*r.u(end);
assert(max(abs(r.steering(use)-atan2(L,R)))<3e-4);
assert(abs(r.driveDistance(end)-(R+p.driveX)*1.2)<0.1);
end

function testMechanisms()
p=camdesign.defaultProject(); a=linspace(-0.7,0.7,101)';
for kind={'rack','flat'}
    p.params.mechanism=kind{1};
    for signValue=[-1,1]
        p.params.lever=signValue*25;
        assert(max(abs(camdesign.steeringFromLift(camdesign.lift(a,p.params),p.params)-a))<1e-12);
    end
end
end

function testClosedCam()
p=camdesign.defaultProject(); r=camdesign.evaluate(p);
assert(norm(r.cam.actual(1,:)-r.cam.actual(end,:))<1e-7);
assert(abs(r.cam.radius(1)-r.cam.radius(end))<1e-8);
assert(r.cam.workEnd<=2*pi-deg2rad(p.params.returnAngleDeg)+1e-7);
end

function testRoundTrip()
p=camdesign.defaultProject(); p.params.samples=2401;
r=camdesign.evaluate(p); sim=camdesign.simulate(r.cam,p.params,r.route.front(1,:),r.route.heading(1));
err=max(vecnorm(sim.sensor-r.route.sensor,2,2));
fprintf('  route/cam inverse max sensor discrepancy %.6f mm\n',err);
assert(err<0.15,'Round-trip discrepancy too large.');
end

function testOptimize()
p=camdesign.defaultProject(); p.params.samples=201; p.params.camSamples=241; p.params.iterations=3;
before=camdesign.evaluate(p); [q,h]=camdesign.optimize(p); after=camdesign.evaluate(q);
assert(after.metrics.score<before.metrics.score);
assert(all(diff([h.score])<=1e-9)); assert(isequal(q.nodes(1,:),p.nodes(1,:)));
fprintf('  objective %.6f -> %.6f\n',before.metrics.score,after.metrics.score);
end

function testSaveImport()
p=camdesign.defaultProject(); filename=[tempname,'.mat']; cleanup=onCleanup(@()delete(filename));
camdesign.saveProject(p,filename); q=camdesign.importProject(filename); assert(isequaln(p,q));
original=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'2027生物质能初赛_直播.mat');
if isfile(original)
    rejected=false;
    try, camdesign.importProject(original); catch ex, rejected=strcmp(ex.identifier,'cam:UnsupportedMechanism'); end
    assert(rejected,'3.1.2 type 4 must not silently become rack.');
    q=camdesign.importProject(original,MechanismOverride='rack');
    assert(strcmp(q.params.mechanism,'rack') && q.params.referenceDiameter==100);
    assert(strcmp(q.legacy.sourceMechanism,'顶球'));
    assert(size(q.targets,1)==13 && ~isfield(q.legacy,'key'));
end
end

function testImportTypeSchemes()
filename=[tempname,'.mat']; cleanup=onCleanup(@()delete(filename));
pathway_points=[0 0;0 500;100 1000]; car_type=2; version='3.1.2'; key=123;
save(filename,'pathway_points','car_type','version','key');
p=camdesign.importProject(filename);
assert(strcmp(p.params.mechanism,'rack') && ~isfield(p.legacy,'key'));
car_type=1; save(filename,'pathway_points','car_type','version');
p=camdesign.importProject(filename); assert(strcmp(p.params.mechanism,'flat'));
car_type=4; version='unknown'; save(filename,'pathway_points','car_type','version');
rejected=false;
try, camdesign.importProject(filename); catch ex, rejected=strcmp(ex.identifier,'cam:TypeScheme'); end
assert(rejected,'Ambiguous version must not silently select a mechanism.');
p=camdesign.importProject(filename,TypeScheme='legacy-manual');
assert(strcmp(p.params.mechanism,'rack'));
end

function testExport()
p=straightProject(); r=camdesign.evaluate(p);
folder=fullfile(fileparts(mfilename('fullpath')),'outputs','test_export');
paths=camdesign.exportResult(p,r,folder);
xyz=readmatrix(paths.xyz); assert(size(xyz,2)==3);
assert(max(abs(xyz(:,1:2)-r.cam.actual),[],'all')<1e-10);
report=jsondecode(fileread(paths.report)); assert(report.effectiveGearRatio==r.cam.effectiveRatio);
end

function testReject()
p=camdesign.defaultProject(); p.params.lever=0; failed=false;
try, camdesign.evaluate(p); catch ex, failed=strcmp(ex.identifier,'cam:Lever'); end
assert(failed);
p=camdesign.defaultProject(); p.params.autoRatio=false; p.params.gearRatio=1; failed=false;
try, camdesign.evaluate(p); catch ex, failed=strcmp(ex.identifier,'cam:GearRatio'); end
assert(failed);
end

function testIntersections()
assert(~isempty(camdesign.selfIntersections([0 0;1 1;0 1;1 0;0 0])));
assert(isempty(camdesign.selfIntersections([0 0;1 0;1 1;0 1;0 0])));
end
