function [best,history,info]=optimizeQualitySqp(project,callback,options)
% SQP with the explicit four-direction quality and exact full-acceptance gate.
% The legacy optimizeFmincon default objective/selection stays independent.
arguments
    project struct
    callback=[]
    options.Budget=[]
    options.MaxPhysicalEvaluations (1,1) double {mustBePositive}=200000
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive}=10000
    options.DifferenceStepMM (1,1) double {mustBeFinite,mustBePositive}=.0005
end
if isempty(callback), callback=@(~,~,~)false; end
camdesign.validateProject(project);
assert(exist('fmincon','file')==2 && license('test','Optimization_Toolbox'),'cam:FminconUnavailable','接力精修需要Optimization Toolbox。');
assert(~camdesign.dynamicWeightSettings(project.params).enabled,'cam:RelayDynamicWeights','接力精修不支持动态权重，请先明确关闭。');
assert(~strcmp(camdesign.routeModel(project.params),'bspline-v1'),'cam:BSplineBackend','接力SQP目前支持cubic/独立贝塞尔。');
assert(camdesign.controlBounds(project).gatePassed,'cam:FminconInitialBounds','SQP初始控制点须满足启用的场界；不会静默裁剪输入。');
budget=options.Budget; if isempty(budget), budget=camdesign.PhysicalEvaluationBudget(options.MaxPhysicalEvaluations,3600); end
start=budget.Used; stopAt=min(budget.Limit,start+options.MaxPhysicalEvaluations); timer=tic;
map=camdesign.optimizationVariables(project); Z=map.basis; n=size(project.nodes,1); scale=1000;
M=blkdiag(Z,Z); x0=zeros(2*size(Z,2),1); free=[(2:n)';(n+2:2*n)'];
low=repmat(project.params.bounds([1 3]),n,1); high=repmat(project.params.bounds([2 4]),n,1);
lb=[]; ub=[]; if camdesign.controlBounds(project).enforced
    lb=(low(free)-project.nodes(free))/scale; ub=(high(free)-project.nodes(free))/scale;
end
cache=containers.Map('KeyType','char','ValueType','any'); cacheHits=0; objectiveCalls=0; constraintCalls=0;
best=project; currentResult=budget.evaluate(project,true,stopAt); current=camdesign.feasibilityFourState(best,currentResult);
initial=camdesign.fminconModel(project,project.nodes,currentResult,0,'feasibility-quality-v1');
assert(initial.valid,'cam:FminconInitialGeometry','SQP初始路线无法计算。'); cache(sprintf('%.17g,',x0))=initial;
history=entry(0,'initial',false); iteration=0; reason='iteration_limit'; exitflag=NaN;
output=struct('iterations',0,'funcCount',0,'message','Stopped before solver.'); terminal=initial;
if notify(0), reason='user_stop';
else
    settings=optimoptions('fmincon','Algorithm','sqp','Display','none', ...
        'MaxIterations',options.MaxIterations,'MaxFunctionEvaluations',max(1000,6*ceil(stopAt-start)), ...
        'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-7,'StepTolerance',1e-10, ...
        'FiniteDifferenceType','forward','FiniteDifferenceStepSize',options.DifferenceStepMM/scale, ...
        'TypicalX',ones(size(x0)),'OutputFcn',@progress);
    try
        [x,~,exitflag,output]=fmincon(@objective,x0,[],[],[],[],lb,ub,@constraints,settings);
        iteration=max(iteration,output.iterations);
        if ~strcmp(reason,'user_stop'), terminal=modelAt(x); consider(x,terminal); end
        if ~strcmp(reason,'user_stop')
            if exitflag==1, reason='constrained_converged';
            elseif exitflag==2, reason='constrained_step_tolerance';
            elseif exitflag==-2, reason='constrained_infeasible';
            elseif exitflag<0, reason='solver_stopped'; end
        end
    catch ex
        budgetReason=budgetStopReason(ex);
        if isempty(budgetReason), rethrow(ex); else, reason=budgetReason; end
        output.message=['Strict stop: ',ex.identifier];
    end
end
function reason=budgetStopReason(ex)
reason='';
if strcmp(ex.identifier,'cam:PhysicalEvaluationBudget'), reason='physical_evaluation_limit';
elseif strcmp(ex.identifier,'cam:PhysicalTimeBudget'), reason='time_limit';
else
    for k=1:numel(ex.cause)
        reason=budgetStopReason(ex.cause{k}); if ~isempty(reason), return; end
    end
end
end
history(end+1)=entry(iteration,'finished',~isequal(history(end).nodes,best.nodes));
history(end).stopped=strcmp(reason,'user_stop');
info=struct('algorithm','quality-sqp-v1','objectiveMode','feasibility-quality-v1', ...
    'reason',reason,'iterations',iteration,'requestedIterations',options.MaxIterations, ...
    'physicalEvaluations',budget.Used-start,'evaluations',budget.Used-start,'physicalEvaluationStopAt',stopAt, ...
    'physicalBudget',budget.snapshot(),'objectiveCalls',objectiveCalls,'constraintCalls',constraintCalls,'cacheHits',cacheHits, ...
    'differenceStepMM',options.DifferenceStepMM,'elapsedSeconds',toc(timer),'solverExitflag',exitflag,'solverOutput',output, ...
    'trainingFeasible',current.feasible,'rankingState',current,'finalMetrics',current.metrics, ...
    'terminalObjective',terminal.objective,'terminalViolation',terminal.maxViolation, ...
    'selectionPolicy','Only full-checked exact native gate/quality improvements replace the incumbent; raw solver iterates/probes never bypass acceptance.', ...
    'assessmentPerformed',false,'assessmentEvaluationAttempts',0,'cachedFinalResult',currentResult, ...
    'parametersUnchanged',isequaln(best.params,project.params));
notify(iteration);
    function trial=unpack(x)
        trial=project; trial.nodes=project.nodes+reshape(scale*(M*x),n,2);
    end
    function model=modelAt(x)
        key=sprintf('%.17g,',x);
        if isKey(cache,key), cacheHits=cacheHits+1; model=cache(key); return; end
        trial=unpack(x);
        try
            result=budget.evaluate(trial,false,stopAt);
            model=camdesign.fminconModel(trial,project.nodes,result,0,'feasibility-quality-v1');
        catch ex
            if ~ismember(ex.identifier,{'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel','cam:ExtremeSteering', ...
                    'cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite','cam:EndpointConstraint'}), rethrow(ex); end
            count=size(project.targets,1)+5*project.params.samples+2*project.params.camSamples+1;
            model=struct('valid',false,'objective',1e6+min(norm(x)^2,1e6), ...
                'constraints',ones(count,1)*(1e3+min(norm(x),1e3)),'maxViolation',1e3,'result',[],'errorIdentifier',ex.identifier);
        end
        if cache.Count>=2*numel(x0)+16, remove(cache,keys(cache)); end
        cache(key)=model;
    end
    function value=objective(x)
        objectiveCalls=objectiveCalls+1; model=modelAt(x); value=model.objective;
    end
    function [c,ceq]=constraints(x)
        constraintCalls=constraintCalls+1; model=modelAt(x); c=model.constraints; ceq=[];
    end
    function changed=consider(x,model)
        changed=false; if ~model.valid, return; end
        trial=unpack(x); fast=camdesign.feasibilityFourState(trial,model.result);
        if current.feasible && (~fast.numericFeasible || ~fast.orderSatisfied || fast.qualityObjective>=current.qualityObjective-1e-10*max(1,abs(current.qualityObjective))), return; end
        full=model.result; if ~full.metrics.geometryChecked, full=budget.evaluate(trial,true,stopAt); end
        state=camdesign.feasibilityFourState(trial,full);
        if camdesign.feasibilityFourBetter(state,current), best=trial; current=state; currentResult=full; changed=true; end
    end
    function stop=progress(x,values,state)
        stop=false; if ~strcmp(state,'iter'), return; end
        iteration=max(iteration,values.iteration); raw=modelAt(x); changed=consider(x,raw); terminal=raw;
        history(end+1)=entry(iteration,'sqp_iteration',changed);
        stop=notify(iteration); if stop, reason='user_stop'; end
    end
    function item=entry(iter,event,accepted)
        item=struct('iteration',iter,'score',current.metrics.score,'maxHitError',current.metrics.maxHitError, ...
            'evaluations',budget.Used-start,'accepted',accepted,'event',event,'stepType',event,'stopped',false, ...
            'metrics',current.metrics,'nodes',best.nodes,'qualityObjective',current.qualityObjective, ...
            'violationSquared',current.violationSquared,'maxNormalizedViolation',current.maxNormalizedViolation, ...
            'trainingFeasible',current.feasible,'fullGeometryChecked',true,'nominalDifferenceStepMM',options.DifferenceStepMM);
    end
    function stop=notify(iter)
        shown=history; shown(end).displayResult=currentResult;
        shown(end).physicalEvaluations=budget.Used-start; shown(end).physicalEvaluationLimit=stopAt-start;
        stop=callback(iter,best,shown);
    end
end
