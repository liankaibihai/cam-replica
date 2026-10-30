function report=check_fixed_ratio()
% Hardware ratio invariance; short solver checks are contracts, not quality.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','fixed_ratio_results_20261030');
if ~isfolder(folder), mkdir(folder); end
checks={}; project=straightCase(295); project.params.autoRatio=true;
r=camdesign.evaluate(project,true);
assert(r.cam.effectiveRatio==35 && r.cam.requestedRatio==35);
assert(abs(rad2deg(r.cam.workEnd)-295)<1e-8 && r.metrics.returnAngleSatisfied);
checks{end+1}='legacy auto flag cannot change user ratio; analytic work phase is 295 degrees';
manual=project; manual.params.gearRatio=40;
changed=camdesign.evaluate(manual,true);
assert(changed.cam.effectiveRatio==40 && abs(changed.cam.workEnd/r.cam.workEnd-35/40)<1e-12);
checks{end+1}='user manual change to 40 is honored with inverse proportional phase';

shortReturn=straightCase(330); shortReturn.params.autoRatio=true;
model=camdesign.fminconModel(shortReturn,shortReturn.nodes);
v=camdesign.verifyConstrained(shortReturn,4);
assert(model.valid && abs(model.constraints(end)-.1)<1e-10);
assert(abs(model.result.metrics.actualReturnDeg-30)<1e-8 && ~model.result.metrics.returnAngleSatisfied);
assert(~v.verifiedFeasible && ~v.optimizationGrid.thresholdsSatisfied && ~v.refinedGrid.thresholdsSatisfied);
assert(v.optimizationGrid.effectiveRatio==35 && v.refinedGrid.effectiveRatio==35);
checks{end+1}='30-degree return remains evaluable but violates requested 60-degree return on both grids';

overflow=straightCase(356); overflow.params.autoRatio=true; caught=false;
try, camdesign.evaluate(overflow,true); catch ex, caught=strcmp(ex.identifier,'cam:GearRatio'); end
assert(caught); checks{end+1}='less than 5 degrees return is rejected instead of auto-increasing ratio';

solar=camdesign.solarTestProject(); legacy=camdesign.defaultProject();
assert(solar.params.gearRatio==35 && ~solar.params.autoRatio);
assert(legacy.params.gearRatio==20 && ~legacy.params.autoRatio);
save(fullfile(folder,'legacy_auto_fixture.mat'),'project');
[imported,notes]=camdesign.importProject(fullfile(folder,'legacy_auto_fixture.mat'));
assert(imported.params.gearRatio==35 && ~imported.params.autoRatio && ~isempty(notes));
checks{end+1}='team/default fixtures are distinct; legacy import disables flag and preserves numeric ratio';

for algorithm={'peak-gradient-v2','fmincon-interior-point-experimental-v1'}
    test=straightCase(295); test.params.iterations=3;
    [q,h,info]=camdesign.optimize(test,@observe,algorithm{1});
    assert(isequaln(q.params,test.params) && ~isempty(h) && info.iterations<=3);
    final=camdesign.evaluate(q,true); assert(final.cam.effectiveRatio==35);
end
checks{end+1}='both optimizer callbacks and returned projects retain fixed ratio';
paths=camdesign.exportResult(imported,r,fullfile(folder,'export_fixture'));
exported=jsondecode(fileread(paths.report));
assert(exported.effectiveGearRatio==35 && exported.requestedGearRatio==35);
assert(strcmp(exported.ratioPolicy,'fixed-user-input-v1'));
checks{end+1}='export recomputation and report retain the input ratio';
report=struct('release',version('-release'),'checks',{checks},'passed',numel(checks), ...
    'shortReturnVerification',v,'scope','Ratio/return contracts, not convergence or physical accuracy.');
fid=fopen(fullfile(folder,'contracts.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FIXED_RATIO_PASS %d checks\n',numel(checks));
end
function stop=observe(~,project,~)
result=camdesign.evaluate(project,false);
assert(result.cam.effectiveRatio==35 && result.cam.requestedRatio==35); stop=false;
end
function project=straightCase(workDegrees)
project=camdesign.defaultProject(); p=project.params;
p.mechanism='flat'; p.wheelDiameter=100; p.gearRatio=35; p.autoRatio=false;
p.headingDeg=0; p.startSteeringDeg=0; p.sensorX=0; p.sensorY=0;
p.samples=101; p.camSamples=181; p.bounds=[-100 20000 -1000 1000];
distance=deg2rad(workDegrees)*p.wheelDiameter*p.gearRatio/2;
project.params=p; project.nodes=[0 0;distance/2 0;distance 0]; project.targets=project.nodes;
end
