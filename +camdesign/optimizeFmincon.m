function [best,history,info]=optimizeFmincon(project,callback,options)
% Experimental fmincon backend. Nodes only; all parameters are preserved.
arguments
    project struct
    callback=[]
    options.Algorithm char {mustBeMember(options.Algorithm,{'sqp','interior-point'})}='interior-point'
    options.DifferenceStepMM (1,1) double {mustBeReal}=NaN
    options.DifferenceType char {mustBeMember(options.DifferenceType,{'forward','central'})}='forward'
    options.MaxSeconds (1,1) double {mustBeFinite,mustBePositive}=90
    options.MaxFunctionEvaluations (1,1) double {mustBeReal}=NaN
    options.RefinementFactor (1,1) double {mustBeInteger,mustBeFinite}=4
end
validateattributes(options.RefinementFactor,{'double'},{'scalar','integer','>=',2,'<=',8});
assert(exist('fmincon','file')==2 && license('test','Optimization_Toolbox'), ...
    'cam:FminconUnavailable','实验约束后端需要 Optimization Toolbox 的 fmincon。');
if isempty(callback), callback=@(~,~,~)false; end
timer=tic; camdesign.validateProject(project); best=project; n=size(project.nodes,1);
free=[(2:n)';(n+2:2*n)']; scale=1000; x0=zeros(numel(free),1);
if isnan(options.MaxFunctionEvaluations)
    maxFunctions=max(2000,4*(numel(free)+1)*(project.params.iterations+1));
    functionBudgetSource='derived_from_variables_and_iterations';
else
    validateattributes(options.MaxFunctionEvaluations,{'double'},{'scalar','finite','integer','positive'});
    maxFunctions=options.MaxFunctionEvaluations; functionBudgetSource='explicit';
end
if isnan(options.DifferenceStepMM)
    fdStep=max(1e-6,min(1e-3,project.params.gradientProbeMM/scale));
    differenceStepSource='project_gradient_probe';
else
    validateattributes(options.DifferenceStepMM,{'double'},{'scalar','finite','positive'});
    fdStep=options.DifferenceStepMM/scale; differenceStepSource='explicit';
end
lowerNodes=repmat([project.params.bounds(1),project.params.bounds(3)],n,1);
upperNodes=repmat([project.params.bounds(2),project.params.bounds(4)],n,1);
assert(all(project.nodes>=lowerNodes & project.nodes<=upperNodes,'all'), ...
    'cam:FminconInitialBounds','初始节点超出场地边界；约束后端不会移动固定起点或静默裁剪输入。');
lb=(lowerNodes(free)-project.nodes(free))/scale;
ub=(upperNodes(free)-project.nodes(free))/scale;
evaluations=0; objectiveCalls=0; constraintCalls=0; invalidEvaluations=0; cacheHits=0;
cache=containers.Map('KeyType','char','ValueType','any');
initial=modelAt(x0);
assert(initial.valid,'cam:FminconInitialGeometry','初始路线无法计算：%s',initial.errorMessage);
incumbent=initial; current=initial; maxIteration=0; reason='iteration_limit'; stopRequested=false;
history=entry(0,'initial',false,0);
exitflag=NaN; output=struct('iterations',0,'funcCount',0,'message','Stopped before solver.');
solverObjective=initial.objective; solverViolation=initial.maxViolation; solverElapsed=0;
terminal=initial;
if callback(0,best,history)
    reason='user_stop'; stopRequested=true;
else
    settings=optimoptions('fmincon','Algorithm',options.Algorithm,'Display','none', ...
        'MaxIterations',project.params.iterations,'MaxFunctionEvaluations',maxFunctions, ...
        'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-5,'StepTolerance',1e-8, ...
        'FiniteDifferenceType',options.DifferenceType,'FiniteDifferenceStepSize',fdStep, ...
        'TypicalX',ones(size(x0)),'OutputFcn',@progress);
    solverTimer=tic;
    [x,solverObjective,exitflag,output]=fmincon(@objective,x0,[],[],[],[],lb,ub,@constraints,settings);
    maxIteration=max(maxIteration,output.iterations);
    solverElapsed=toc(solverTimer); terminal=modelAt(x); solverViolation=terminal.maxViolation;
    consider(x,terminal);
    if ~stopRequested
        if exitflag==1, reason='constrained_converged';
        elseif exitflag==2, reason='constrained_step_tolerance';
        elseif exitflag==-2, reason='constrained_infeasible';
        elseif exitflag==0 && output.funcCount>=maxFunctions, reason='function_evaluation_limit';
        elseif exitflag<0, reason='solver_stopped'; end
    end
end
verification=camdesign.verifyConstrained(best,options.RefinementFactor);
evaluations=evaluations+verification.physicalEvaluationAttempts;
current=incumbent;
if history(end).iteration~=maxIteration || ~isequal(history(end).nodes,best.nodes)
    history(end+1)=entry(maxIteration,'terminal_selection',true,0);
end
history(end).event='finished'; history(end).evaluations=evaluations;
history(end).stopped=strcmp(reason,'user_stop');
history(end)=trace(history(end),terminal);
remaining=verification.optimizationGrid.warnings;
if verification.refinedGrid.valid && ~verification.refinedGrid.trajectoryBoundsSatisfied
    remaining{end+1}=sprintf('加密五点中心采样轨迹最大出界 %.6g mm；场界验收未通过。',verification.refinedGrid.maxTrajectoryOutsideMM);
end
if ~verification.refinedGrid.feasible, remaining{end+1}='加密采样或完整几何检查未通过，候选不能标为可行。'; end
if ~verification.independentRefinement, remaining{end+1}='采样上限使独立加密检查未完成。'; end
info=struct('algorithm',['fmincon-',options.Algorithm,'-experimental-v1'], ...
    'solverAlgorithm',options.Algorithm, ...
    'objectiveVersion','length-steering-move-v1','constraintVersion','sampled-five-centers-v1', ...
    'reason',reason,'iterations',maxIteration, ...
    'requestedIterations',project.params.iterations,'evaluations',evaluations, ...
    'objectiveCalls',objectiveCalls,'constraintCalls',constraintCalls,'cacheHits',cacheHits, ...
    'evaluationCountScope','Backend model attempts plus final verification; client callbacks may evaluate separately.', ...
    'invalidEvaluations',invalidEvaluations,'elapsedSeconds',toc(timer),'solverSeconds',solverElapsed, ...
    'solverExitflag',exitflag,'solverOutput',output,'solverTerminalObjective',solverObjective, ...
    'solverTerminalViolation',solverViolation,'returnedObjective',incumbent.objective, ...
    'solverTerminalValid',terminal.valid,'solverTerminalError',terminal.errorIdentifier, ...
    'returnedMaxViolation',incumbent.maxViolation,'constraintCount',numel(initial.constraints), ...
    'constraintTolerance',1e-6,'objectiveWeights',[project.params.weights(2:3),1e-4], ...
    'maxSeconds',options.MaxSeconds,'maxFunctionEvaluations',maxFunctions, ...
    'functionBudgetSource',functionBudgetSource,'freeVariables',numel(free), ...
    'differenceType',options.DifferenceType,'nominalDifferenceStepMM',fdStep*scale, ...
    'relativeDifferenceStep',fdStep,'differenceStepSource',differenceStepSource, ...
    'differenceStepScope','Nominal mm step at abs(normalized displacement)<=1; fmincon scales larger displacements by max(abs(x),TypicalX).', ...
    'timeBudgetScope','Soft elapsed limit checked in solver callbacks from backend entry; final verification excluded.', ...
    'coordinateScaleMM',scale,'requestedRatio',project.params.gearRatio, ...
    'initialEffectiveRatio',initial.result.cam.effectiveRatio, ...
    'finalEffectiveRatio',incumbent.result.cam.effectiveRatio,'autoRatio',logical(project.params.autoRatio), ...
    'parametersUnchanged',isequaln(project.params,best.params), ...
    'selectionPolicy','Strict zero-violation iterates preferred; otherwise reduce scaled violation; same-class feasible iterates compare constrained objective. Finite-difference probes not selected.', ...
    'verification',verification,'verifiedFeasible',verification.verifiedFeasible, ...
    'remainingConstraints',{remaining},'finalMetrics',verification.optimizationGrid.metrics, ...
    'limitations',{{'Ordered nearest-segment hits and moving work/return boundary are nonsmooth.', ...
    'autoRatio retains the existing derived rule; effective ratio is not a solver variable but can change with route.', ...
    'Self-intersection and independent refinement are final validation gates, not SQP constraints.', ...
    'Trajectory bounds constrain five sampled modeled centers, not wheel widths, the complete body or continuous collision.', ...
    'Local finite-difference optimization may stop infeasible; positive exitflag is not engineering acceptance.'}});
callback(maxIteration,best,history);

    function trial=unpack(x)
        trial=project; trial.nodes(free)=project.nodes(free)+scale*x;
    end
    function model=modelAt(x)
        key=sprintf('%.17g,',x);
        if isKey(cache,key), model=cache(key); cacheHits=cacheHits+1; return; end
        model=camdesign.fminconModel(unpack(x),project.nodes); evaluations=evaluations+1;
        invalidEvaluations=invalidEvaluations+~model.valid;
        if cache.Count>=2*numel(x0)+16, remove(cache,keys(cache)); end
        cache(key)=model;
    end
    function value=objective(x)
        objectiveCalls=objectiveCalls+1; model=modelAt(x); value=model.objective;
    end
    function [c,ceq]=constraints(x)
        constraintCalls=constraintCalls+1; model=modelAt(x); c=model.constraints; ceq=[];
    end
    function consider(x,model)
        if ~model.valid, return; end
        oldViolation=incumbent.maxViolation; newViolation=model.maxViolation;
        if (newViolation==0 && oldViolation>0) ...
                || (newViolation==0 && oldViolation==0 && model.objective<incumbent.objective) ...
                || (oldViolation>0 && newViolation>0 && newViolation<oldViolation-1e-10)
            best=unpack(x); incumbent=model;
        end
    end
    function stop=progress(x,values,state)
        stop=false;
        if ~strcmp(state,'iter'), return; end
        before=best.nodes; raw=modelAt(x); consider(x,raw); current=incumbent;
        maxIteration=max(maxIteration,values.iteration);
        history(end+1)=entry(maxIteration,'constrained_iteration',~isequal(best.nodes,before),max(vecnorm(best.nodes-before,2,2)));
        history(end)=trace(history(end),raw);
        if callback(maxIteration,best,history), reason='user_stop'; stopRequested=true; stop=true;
        elseif toc(timer)>=options.MaxSeconds, reason='time_limit'; stopRequested=true; stop=true; end
    end
    function item=entry(iteration,event,accepted,step)
        item=struct('iteration',iteration,'score',current.result.metrics.score, ...
            'objective',current.objective,'maxConstraintViolation',current.maxViolation, ...
            'maxHitError',current.result.metrics.maxHitError,'evaluations',evaluations, ...
            'stopped',false,'accepted',accepted,'event',event,'stepType',event,'stepMM',step, ...
            'directionIteration',iteration,'directionBaseNodes',best.nodes,'descentDirection',zeros(size(best.nodes)), ...
            'gradient',[],'probeScores',[],'metrics',current.result.metrics,'nodes',best.nodes);
        item=trace(item,current);
    end
    function item=trace(item,raw)
        item.solverObjective=raw.objective; item.solverMaxViolation=raw.maxViolation;
        item.solverValid=raw.valid; item.solverMetrics=[]; item.solverErrorIdentifier=raw.errorIdentifier;
        if raw.valid, item.solverMetrics=raw.result.metrics; end
    end
end
