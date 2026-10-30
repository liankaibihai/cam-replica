function report=check_fixed_ratio_convergence()
% Long-budget solar flat-car diagnostic under user-fixed i=35.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','fixed_ratio_results_20261030','convergence_300');
assert(~isfile(fullfile(folder,'verification.json')),'cam:PreserveEvidence','Existing evidence must not be overwritten.');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject(); project=camdesign.refineRoute(camdesign.refineRoute(project));
project.params.iterations=300; before=camdesign.evaluate(project,true);
[q,h,info]=camdesign.optimizeFmincon(project,@observe,MaxSeconds=1200,RefinementFactor=4);
after=camdesign.evaluate(q,true); fine8=camdesign.verifyConstrained(q,8);
assert(isequaln(q.params,project.params) && q.params.gearRatio==35);
assert(info.initialEffectiveRatio==35 && info.finalEffectiveRatio==35);
assert(fine8.optimizationGrid.effectiveRatio==35 && fine8.refinedGrid.effectiveRatio==35);
save(fullfile(folder,'solar_fixed35_candidate.mat'),'project','q','before','after','h','info','fine8');
report=struct('release',version('-release'),'requestedRatio',35,'nodeCount',size(q.nodes,1), ...
    'before',before.metrics,'after',after.metrics,'history',h,'info',info,'verification8',fine8, ...
    'scope','Fixed-ratio current-model solar preliminary fixture; other dimensions unmeasured, not original-app or physical validation.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FIXED35_CONVERGENCE iter=%d/%d reason=%s evals=%d fine8=%d pressure=%.6f hit=%.6f return=%.6f crossing=%d\n', ...
    info.iterations,info.requestedIterations,info.reason,info.evaluations,fine8.verifiedFeasible, ...
    fine8.refinedGrid.metrics.maxPressureDeg,fine8.refinedGrid.metrics.maxHitError, ...
    fine8.refinedGrid.metrics.actualReturnDeg,fine8.refinedGrid.metrics.intersectionCount);
end
function stop=observe(iteration,project,history)
assert(project.params.gearRatio==35 && ~project.params.autoRatio);
if mod(iteration,25)==0
    fprintf('FIXED35_PROGRESS iteration=%d violation=%.6g score=%.6g\n', ...
        iteration,history(end).maxConstraintViolation,history(end).score);
end
stop=false;
end
