function report=check_auto_model_lock(action)
% Contracts by default. Explicit quality actions use real solar fixed35 runs.
if nargin<1, action='contracts'; end
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:AutoModelBatch','Use independent MATLAB batch.');
folder=fullfile(root,'outputs','model_mapping_20261031'); if ~isfolder(folder), mkdir(folder); end
assert(ismember(action,{'contracts','quality-cubic','quality-bezier','continue-cubic','trends'}),'cam:AutoModelAction','Unknown action.');
if strcmp(action,'trends'), report=trends(folder); return; end
if strcmp(action,'continue-cubic'), report=continuation(folder); return; end
if startsWith(action,'quality-')
    model='cubic'; if strcmp(action,'quality-bezier'), model='bezier-blend-independent-v1'; end
    report=quality(root,folder,model); return;
end

function report=continuation(folder)
% One additional budget for the still-improving primary cubic polish. This
% is a continuation diagnostic, not another paired initialization experiment.
source=load(fullfile(folder,'quality_cubic','result.mat'),'q','info');
destination=fullfile(folder,'quality_cubic_continuation');
if ~isfolder(destination), mkdir(destination); end
for name={'initial.mat','checkpoint.mat','result.mat','summary.json'}
    assert(~isfile(fullfile(destination,name{1})),'cam:QualityEvidenceExists','已有续算证据，拒绝覆盖：%s',destination);
end
p=source.q; referenceWeights=p.params.weights; p.params.weights=source.info.finalActiveWeights;
p.params.iterations=300; p.params.dynamicWeights=struct('enabled',false);
save(fullfile(destination,'initial.mat'),'p','source','-v7'); timer=tic;
[q,h,info]=camdesign.optimizeFmincon(p,@checkpoint,Algorithm='interior-point',DifferenceStepMM=.01, ...
    MaxSeconds=3600,RefinementFactor=4);
assert(strcmp(camdesign.routeModel(q.params),'cubic') && q.params.gearRatio==35 && info.parametersUnchanged ...
    && isequal(q.nodes(1,:),p.nodes(1,:)));
q.params.weights=referenceWeights; assessment=camdesign.autoTuneAssessment(q,[601 721]);
report=struct('stage','cubic additional polish continuation','requestedIterations',300,'iterations',info.iterations, ...
    'reason',info.reason,'evaluations',info.evaluations+assessment.physicalEvaluationAttempts,'elapsedSeconds',toc(timer), ...
    'modelLocked',true,'physicalParametersUnchanged',info.parametersUnchanged,'ratio',q.params.gearRatio, ...
    'verifiedFeasible',assessment.verifiedFeasible,'convergencePassed',assessment.convergencePassed,'assessment',assessment, ...
    'objectivePolicy','Selected primary weights retained; existing backend uses continuation-input nodes as move-regularizer reference. New local solve, not exact internal solver-state resume.', ...
    'scope','Additional same-model local budget because primary cubic polish was still improving; no global feasibility or convergence proof.');
save(fullfile(destination,'result.mat'),'p','q','h','info','report','source','-v7');
fid=fopen(fullfile(destination,'summary.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('AUTO_MODEL_CONTINUATION_DONE actual=%d requested=300 reason=%s feasible=%d convergence=%d\n', ...
    info.iterations,info.reason,assessment.verifiedFeasible,assessment.convergencePassed);
    function stop=checkpoint(iter,q,h)
        stop=false; assert(strcmp(camdesign.routeModel(q.params),'cubic') && q.params.gearRatio==35);
        if mod(iter,25)==0 || strcmp(h(end).event,'finished')
            hEnd=h(end); save(fullfile(destination,'checkpoint.mat'),'q','hEnd','-v7');
            fprintf('AUTO_MODEL_CONTINUATION iter=%d pressure=%.5g hit=%.5g violation=%.5g\n', ...
                iter,hEnd.metrics.maxPressureDeg,hEnd.metrics.maxHitError,hEnd.maxConstraintViolation);
        end
    end
end

function report=trends(folder)
names={'quality_cubic','quality_bezier','quality_cubic_continuation'}; rows={};
for k=1:numel(names)
    file=fullfile(folder,names{k},'result.mat'); if ~isfile(file), continue; end
    saved=load(file,'h','info','report'); h=saved.h;
    if isfield(h,'autoStage')
        h=h(strcmp({h.autoStage},'polish')); x=[h.trialIteration];
    else, x=[h.iteration]; end
    last=x(end); first=find(x>=last-50,1); a=h(first).metrics; b=h(end).metrics;
    row=struct('stage',names{k},'firstIteration',x(first),'lastIteration',last, ...
        'pressureStartDeg',a.maxPressureDeg,'pressureEndDeg',b.maxPressureDeg, ...
        'hitStartMM',a.maxHitError,'hitEndMM',b.maxHitError, ...
        'reason',saved.report.reason,'iterations',saved.report.iterations, ...
        'requestedIterations',saved.report.requestedIterations, ...
        'scope','Last up-to-50 solver iterations of retained candidates, not raw finite-difference probes or a convergence proof.');
    if isfield(h,'solverMaxViolation')
        row.rawSolverViolationStart=h(first).solverMaxViolation; row.rawSolverViolationEnd=h(end).solverMaxViolation;
        row.retainedViolationStart=h(first).maxConstraintViolation; row.retainedViolationEnd=h(end).maxConstraintViolation;
        row.objectiveWeights=saved.info.objectiveWeights;
        row.objectivePolicy='New local solve with selected primary weights; move regularizer references continuation-input nodes, not exact internal solver-state resume.';
    end
    rows{end+1}=row; %#ok<AGROW>
    fprintf('AUTO_MODEL_TREND %s [%d,%d] pressure=%.9g->%.9g hit=%.9g->%.9g reason=%s\n', ...
        row.stage,row.firstIteration,row.lastIteration,row.pressureStartDeg,row.pressureEndDeg,row.hitStartMM,row.hitEndMM,row.reason);
    if isfield(row,'rawSolverViolationStart')
        fprintf('AUTO_MODEL_TREND_RAW solverViolation=%.9g->%.9g retainedViolation=%.9g->%.9g\n', ...
            row.rawSolverViolationStart,row.rawSolverViolationEnd,row.retainedViolationStart,row.retainedViolationEnd);
    end
end
report=struct('stages',{rows});
fid=fopen(fullfile(folder,'quality_trends.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
assert(strcmp(action,'contracts'));
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
p.params.iterations=1; p.params.autoTune=struct('trials',4,'maxIterations',1,'seed',2027,'polishCount',0);
checks={}; saved={}; activeModel=''; activeDegree=[]; callbackCount=0;
for model={'cubic','bezier-blend-independent-v1'}
    q=p;
    if ~strcmp(model{1},'cubic'), q=camdesign.mapRouteModel(q,model{1},8,5); end
    activeModel=model{1}; activeDegree=[]; if ~strcmp(activeModel,'cubic'), activeDegree=5; end
    callbackCount=0;
    [best,h,info]=camdesign.optimizeAuto(q,@observe);
    assert(info.routeModelLocked && strcmp(info.fixedRouteModel,activeModel) && callbackCount>0);
    assert(all(strcmp({info.trials.routeModel},activeModel)) && strcmp(camdesign.routeModel(best.params),activeModel));
    assert(info.physicalParametersUnchanged && best.params.gearRatio==35 && isequal(best.nodes(1,:),q.nodes(1,:)));
    if ~isempty(activeDegree), assert(best.params.bezier.degree==activeDegree && info.fixedBezierDegree==activeDegree); end
    assert(any([info.trials.trial]==4));
    saved{end+1}=struct('best',best,'history',h,'info',info); %#ok<AGROW>
    checks{end+1}=['All four configurations and final callback retain user model and Bezier degree: ',activeModel]; %#ok<AGROW>
end
b=camdesign.mapRouteModel(p,'bspline-v1',8,5); rejected=false;
try, camdesign.optimizeAuto(b); catch ex, rejected=strcmp(ex.identifier,'cam:BSplineBackend'); end
assert(rejected); checks{end+1}='Unsupported B-spline automatic mode explicitly rejects before any callback/model change';
report=struct('release',version('-release'),'checks',{checks},'scope','Short model-lock contracts only, not optimizer quality.');
contracts=fullfile(folder,'contracts'); if ~isfolder(contracts), mkdir(contracts); end
save(fullfile(contracts,'auto_model_lock.mat'),'report','saved','-v7');
fid=fopen(fullfile(contracts,'auto_model_lock.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('AUTO_MODEL_LOCK_CASE_PASS %s\n',checks{k}); end
fprintf('AUTO_MODEL_LOCK_PASS cases=%d\n',numel(checks));
    function stop=observe(~,q,~)
        stop=false; callbackCount=callbackCount+1;
        assert(strcmp(camdesign.routeModel(q.params),activeModel));
        if ~isempty(activeDegree), assert(q.params.bezier.degree==activeDegree); end
    end
end

function report=quality(~,folder,model)
label='quality_cubic'; if ~strcmp(model,'cubic'), label='quality_bezier'; end
destination=fullfile(folder,label); if ~isfolder(destination), mkdir(destination); end
evidence={'initial.mat','checkpoint.mat','result.mat','summary.json'};
for k=1:numel(evidence)
    assert(~isfile(fullfile(destination,evidence{k})),'cam:QualityEvidenceExists', ...
        '已有质量运行证据，拒绝覆盖：%s。复跑请另建独立阶段目录。',destination);
end
p=camdesign.solarTestProject(); p=camdesign.refineRoute(camdesign.refineRoute(p));
if ~strcmp(model,'cubic')
    % A valid historical independent-Bezier solar representation, with its
    % own genuine curve. This quality case is NOT an equal-geometry ranking.
    [~,~,s]=camdesign.routeSpline(p.nodes,p.params);
    p.params=rmfield(p.params,'routeSpline'); p.params.routeModel=model;
    p.params.bezier=struct('type','overlap-bernstein-v1','degree',5,'parameterLength',s(end));
end
p.params.samples=601; p.params.camSamples=721; p.params.iterations=300;
p.params.autoTune=struct('trials',2,'maxIterations',300,'seed',2027,'polishCount',1);
p.params.dynamicWeights=struct('enabled',false);
camdesign.validateProject(p); before=camdesign.evaluate(p,true);
save(fullfile(destination,'initial.mat'),'p','before','-v7');
started=tic; [q,h,info]=camdesign.optimizeAuto(p,@checkpoint);
assert(info.routeModelLocked && strcmp(camdesign.routeModel(q.params),model));
assert(info.physicalParametersUnchanged && q.params.gearRatio==35 && isequal(q.nodes(1,:),p.nodes(1,:)));
assert(all(strcmp({info.trials.routeModel},model)));
report=struct('model',model,'iterations',info.iterations,'requestedIterations',info.requestedIterations, ...
    'reason',info.reason,'evaluations',info.evaluations,'elapsedSeconds',toc(started), ...
    'verifiedFeasible',info.verifiedFeasible,'convergencePassed',info.convergencePassed, ...
    'physicalParametersUnchanged',info.physicalParametersUnchanged,'ratio',q.params.gearRatio, ...
    'initialMetrics',before.metrics,'finalMetrics',info.finalMetrics,'assessment',info.assessment,'trials',info.trials, ...
    'scope','Real solar fixed35 model-locked automatic run; separate initial representations, not a model performance ranking or vehicle validation.');
save(fullfile(destination,'result.mat'),'p','q','h','info','report','-v7');
fid=fopen(fullfile(destination,'summary.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('AUTO_MODEL_QUALITY_DONE %s actual=%d requested=%d reason=%s feasible=%d convergence=%d\n', ...
    model,info.iterations,info.requestedIterations,info.reason,info.verifiedFeasible,info.convergencePassed);
    function stop=checkpoint(iter,q,h)
        stop=false; assert(strcmp(camdesign.routeModel(q.params),model) && q.params.gearRatio==35);
        if mod(iter,25)==0 || strcmp(h(end).autoStage,'complete')
            hEnd=h(end); save(fullfile(destination,'checkpoint.mat'),'q','hEnd','-v7');
            fprintf('AUTO_MODEL_PROGRESS %s stage=%s trial=%d iter=%d eval=%d pressure=%.5g hit=%.5g\n', ...
                model,hEnd.autoStage,hEnd.autoTrial,iter,hEnd.evaluations,hEnd.metrics.maxPressureDeg,hEnd.metrics.maxHitError);
        end
    end
end
