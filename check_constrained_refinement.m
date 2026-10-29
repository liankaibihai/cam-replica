function report=check_constrained_refinement()
% Regression: a coarse-grid pass must not hide a resolved pressure peak.
root=fileparts(mfilename('fullpath')); addpath(root);
project=camdesign.defaultProject(); project.params.mechanism='flat';
coarse=camdesign.evaluate(project,true);
fine=project;
fine.params.samples=4*(project.params.samples-1)+1;
fine.params.camSamples=4*(project.params.camSamples-1)+1;
refined=camdesign.evaluate(fine,true);
low=coarse.metrics.maxPressureDeg; high=refined.metrics.maxPressureDeg;
assert(high>low+0.01,'cam:RefinementFixture','此回归夹具需要已解析的粗细网格峰值差。');
% This midpoint is only a test fixture, never a production/default threshold.
fixture=project; fixture.params.maxPressureDeg=(low+high)/2; frozen=fixture;
verification=camdesign.verifyConstrained(fixture,4);
assert(verification.optimizationGrid.feasible,'cam:RefinementFixture','粗网格夹具应通过其专用阈值。');
assert(verification.refinedGrid.valid && ~verification.refinedGrid.thresholdsSatisfied);
assert(~verification.verifiedFeasible && verification.independentRefinement);
assert(isequaln(fixture,frozen) && project.params.maxPressureDeg==35);
report=struct('release',version('-release'),'coarsePeakDeg',low, ...
    'refinedPeakDeg',high,'fixtureThresholdDeg',fixture.params.maxPressureDeg, ...
    'productionThresholdUnchanged',project.params.maxPressureDeg, ...
    'verification',verification, ...
    'scope','Synthetic threshold regression for the refinement gate; no solver run or claim that the default design passes 35 degrees.');
folder=fullfile(root,'outputs','constrained_optimizer');
if ~isfolder(folder), mkdir(folder); end
fid=fopen(fullfile(folder,'refinement_gate.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONSTRAINED_REFINEMENT_PASS coarse=%.9f fixtureLimit=%.9f refined=%.9f; coarse pass rejected by refinement; production limit=35\n',low,fixture.params.maxPressureDeg,high);
end
