function report=check_dynamic_weights_convergence(iterations)
if nargin<1, iterations=300; end
validateattributes(iterations,{'double'},{'scalar','integer','>=',300,'<=',10000});
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','dynamic_weights_20261030',sprintf('comparison_%d',iterations));
assert(~isfile(fullfile(folder,'verification.json')),'cam:PreserveEvidence','Existing evidence must not be overwritten.');
if ~isfolder(folder), mkdir(folder); end
seed=camdesign.solarTestProject(); seed=camdesign.refineRoute(camdesign.refineRoute(seed)); seed.params.iterations=iterations;
cases=cell(1,2);
for k=1:2
    project=seed; settings=camdesign.dynamicWeightSettings(project.params); settings.enabled=k==2;
    project.params.dynamicWeights=settings;
    [q,h,info]=camdesign.optimizeSearch(project,@progress,'peak-gradient-v2');
    fine8=camdesign.verifyConstrained(q,8);
    assert(isequaln(q.params,project.params) && fine8.refinedGrid.effectiveRatio==35);
    name='static'; if settings.enabled, name='dynamic'; end
    save(fullfile(folder,[name,'.mat']),'project','q','h','info','fine8');
    cases{k}=struct('mode',name,'requestedIterations',iterations,'actualIterations',info.iterations, ...
        'reason',info.reason,'evaluations',info.evaluations,'elapsedSeconds',info.elapsedSeconds, ...
        'finalReferenceScore',info.finalMetrics.score,'finalDynamicScore',info.finalDynamicScore, ...
        'finalActiveWeights',info.finalActiveWeights,'refinedGrid',fine8.refinedGrid, ...
        'verifiedFeasible',fine8.verifiedFeasible);
    fprintf('DYNAMIC_COMPARISON %s iter=%d/%d reason=%s reference=%.6g pressure=%.6f hit=%.6f feasible=%d\n', ...
        name,info.iterations,iterations,info.reason,info.finalMetrics.score,fine8.refinedGrid.metrics.maxPressureDeg, ...
        fine8.refinedGrid.metrics.maxHitError,fine8.verifiedFeasible);
end
report=struct('release',version('-release'),'cases',{cases},'scope', ...
    'Same 34-node solar flat-car seed and fixed ratio 35; one deterministic peak-search pair, not general optimizer superiority or original-app equivalence.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
function stop=progress(iteration,project,history)
assert(project.params.gearRatio==35);
if mod(iteration,50)==0 && ~strcmp(history(end).event,'searching')
    fprintf('DYNAMIC_PROGRESS iteration=%d reference=%.6g dynamic=%.6g\n',iteration,history(end).score,history(end).dynamicScore);
end
stop=false;
end
