function report=check_original_comparison_candidates()
% Match original 3.1.2 inputs; compare design quality, not identical routes.
assert(batchStartupOptionUsed,'cam:ComparisonBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'outputs','original_comparison_20261029');
assert(~isfile(fullfile(folder,'replica_candidates.json')),'cam:ComparisonArchiveExists','Refusing to overwrite evidence.');
if ~isfolder(folder), mkdir(folder); end
cases={};
for kind={'flat','rack'}
    input=fullfile(root,'local','reference_app',['codex_compare_',kind{1},'_300_20261029.mat']);
    source=load(input,'pathway_points','control_points');
    project=camdesign.importProject(input,TypeScheme='3.1.2');
    project.params.autoRatio=false;
    project.params.iterations=300;
    initial=camdesign.evaluate(project);
    [q,h,info]=camdesign.optimizeFmincon(project,[],DifferenceStepMM=.05, ...
        MaxFunctionEvaluations=30000,MaxSeconds=180);
    assert(isequal(project.params,q.params));
    assert(q.params.gearRatio==20 && ~q.params.autoRatio);
    final=camdesign.evaluate(q);
    cases{end+1}=struct('mechanism',kind{1},'params',project.params, ...
        'targets',project.targets,'sourceControlPointCount',size(source.control_points,1), ...
        'replicaNodeCount',size(project.nodes,1),'initialMetrics',initial.metrics, ...
        'finalMetrics',final.metrics,'maxLeftDeg',max(rad2deg(final.route.steering)), ...
        'maxRightDeg',-min(rad2deg(final.route.steering)), ...
        'info',info,'originalResultAvailable',false);
    save(fullfile(folder,[kind{1},'_replica.mat']),'project','q','h','info','initial','final');
    fprintf('FIXED_RATIO_COMPARISON %s actual=%d/%d drive=%.8f left=%.8f right=%.8f pressure=%.8f refinedPressure=%.8f verified=%d\n', ...
        kind{1},info.iterations,info.requestedIterations,final.metrics.driveLength, ...
        cases{end}.maxLeftDeg,cases{end}.maxRightDeg,final.metrics.maxPressureDeg, ...
        info.verification.refinedGrid.metrics.maxPressureDeg,info.verifiedFeasible);
end
report=struct('release',version('-release'),'cases',{cases}, ...
    'scope','Same physical parameters, targets and fixed ratio 20. Different route basis, initial route, objective and solver; this is design-quality comparison, not pointwise numerical accuracy. Original UI measurements must be recorded separately.');
fid=fopen(fullfile(folder,'replica_candidates.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
end
