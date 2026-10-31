function records=check_bezier_quality(variant,caseIds,stage)
% Paired old/new numerical-chain experiment; identical saved Bezier starts.
% Run baseline from local/bezier_precision_baseline after adding repo path.
if nargin<2, caseIds=1:2; end
if nargin<3, stage='primary'; end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
assert(ismember(variant,{'baseline','improved'}));
assert(ismember(stage,{'primary','continuation'}));
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'outputs','bezier_precision_20261031','quality',variant);
primaryFolder=folder;
if strcmp(stage,'continuation'), folder=fullfile(folder,'continuation'); end
if ~isfolder(folder), mkdir(folder); end
sourceFiles={fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'), ...
    fullfile(root,'outputs','path_comparison_20261031','seed1_bezier5.mat')};
names={'quality34','paired35'}; records=cell(1,numel(caseIds));
for id=caseIds
    name=names{id}; destination=fullfile(folder,[name '.mat']);
    assert(~isfile(destination),'cam:EvidenceExists','Do not overwrite %s',destination);
    if strcmp(stage,'continuation'), sourceFiles{id}=fullfile(primaryFolder,[name '.mat']); end
    loaded=load(sourceFiles{id},'q'); project=loaded.q;
    assert(strcmp(camdesign.routeModel(project.params),'bezier-blend-independent-v1') && project.params.gearRatio==35);
    project.params.samples=601; project.params.camSamples=721; project.params.iterations=600;
    if strcmp(stage,'continuation'), project.params.samples=1201; project.params.camSamples=1441; end
    if isfield(project.params,'dynamicWeights'), project.params.dynamicWeights.enabled=false; end
    original=project; before=assess(project);
    protocol=struct('variant',variant,'stage',stage,'label',name,'sourceFile',sourceFiles{id}, ...
        'requestedIterations',600,'maxFunctionEvaluations',80000,'maxSeconds',3600, ...
        'differenceStepMM',.1,'regularizationWeight',0,'grid',[project.params.samples project.params.camSamples], ...
        'routeModel',camdesign.routeModel(project.params),'degree',project.params.bezier.degree, ...
        'nodes',size(project.nodes,1),'physicalGearRatio',35, ...
        'productionPath',which('camdesign.route'), ...
        'scope','Same initial saved Bezier geometry and physical parameters, only numerical-chain version differs; two local cases, not a general algorithm ranking.');
    save(fullfile(folder,[name '_initial.mat']),'project','before','protocol');
    [q,h,info]=camdesign.optimizeFmincon(project,@progress,Algorithm='interior-point', ...
        DifferenceStepMM=.1,MaxSeconds=3600,MaxFunctionEvaluations=80000, ...
        RefinementFactor=4,RegularizationWeight=0);
    assert(isequaln(q.params,original.params) && isequal(q.nodes(1,:),original.nodes(1,:)));
    save(fullfile(folder,[name '_solver.mat']),'project','q','h','info','protocol');
    after=assess(q);
    count=min(51,numel(h)); tail=h(end-count+1:end);
    record=struct('protocol',protocol,'iterations',info.iterations,'reason',info.reason, ...
        'modelAttempts',info.evaluations,'solverFunctions',info.solverOutput.funcCount, ...
        'solverSeconds',info.solverSeconds,'before',before,'after',after, ...
        'tailRetainedViolation',[tail(1).maxConstraintViolation tail(end).maxConstraintViolation], ...
        'tailRawViolation',[tail(1).solverMaxViolation tail(end).solverMaxViolation], ...
        'parametersUnchanged',isequaln(q.params,original.params));
    save(destination,'project','q','h','info','protocol','record');
    writeJSON(fullfile(folder,[name '.json']),record); records{id}=record;
    fprintf('BEZIER_QUALITY_DONE %s %s iter=%d eval=%d reason=%s pressure=%.9g hit=%.9g return=%.9g feasible=%d closure=%d\n', ...
        variant,name,info.iterations,info.evaluations,info.reason,after.metrics.maxPressureDeg, ...
        after.metrics.maxHitError,after.metrics.actualReturnDeg,after.assessmentPassed,after.actualClosure.closurePassed);
end
    function stop=progress(iter,q,h)
        stop=false;
        if mod(iter,25)~=0 && ~strcmp(h(end).event,'finished'), return; end
        fprintf('BEZIER_PROGRESS %s %s iter=%d eval=%d violation=%.8g pressure=%.6g hit=%.6g return=%.6g\n', ...
            variant,name,iter,h(end).evaluations,h(end).maxConstraintViolation, ...
            h(end).metrics.maxPressureDeg,h(end).metrics.maxHitError,h(end).metrics.actualReturnDeg);
        last=h(end); save(fullfile(folder,[name '_checkpoint.mat']),'q','last');
    end
end

function value=assess(q)
a=camdesign.autoTuneAssessment(q,[601 721]);
dense=q; dense.params.samples=4801; dense.params.camSamples=5761;
r=camdesign.evaluate(dense,true);
[closure,~]=camdesign.verifyActualClosure(dense,r);
closure=rmfield(closure,{'contact','fullCycleContact','hits','visitOrder','trajectoryBounds'});
value=struct('metrics',r.metrics,'assessmentPassed',a.verifiedFeasible, ...
    'convergencePassed',a.convergencePassed,'convergenceDelta',a.delta, ...
    'numericalChecks',a.numericalChecks,'actualClosure',closure);
end

function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
