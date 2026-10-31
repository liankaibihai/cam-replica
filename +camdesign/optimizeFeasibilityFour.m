function [best,history,info]=optimizeFeasibilityFour(project,callback,options)
% Independent four-direction search with full checks BEFORE every acceptance.
% Old video-four-direction-v1 remains a separate unchanged comparison path.
arguments
    project struct
    callback=[]
    options.MaxPhysicalEvaluations (1,1) double {mustBePositive}=Inf
    options.Budget=[]
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive}=project.params.iterations
    options.FinalAssessment (1,1) logical=true
    options.CandidateWorkers (1,1) double {mustBeInteger,mustBeNonnegative}=0
end
if isempty(callback), callback=@(~,~,~)false; end
camdesign.validateProject(project);
assert(~strcmp(camdesign.routeModel(project.params),'bspline-v1'),'cam:BSplineBackend','可行性优先四方向目前支持cubic/独立贝塞尔；B样条仍仅支持内点法。');
dynamic=camdesign.dynamicWeightSettings(project.params);
assert(~dynamic.enabled,'cam:FeasibilityDynamicWeights','可行性优先四方向使用独立约束排序，不支持动态权重；请先明确关闭开关。六项固定分仅作参照/辅助提案。');
timer=tic; best=project; evals=0; fullEvals=0; invalidEvals=0; rejectedFull=0;
budget=options.Budget; if isempty(budget), budget=camdesign.PhysicalEvaluationBudget(options.MaxPhysicalEvaluations); end
assert(isa(budget,'camdesign.PhysicalEvaluationBudget'),'cam:PhysicalBudget','Budget须为共享物理评价计数器。');
if isfinite(options.MaxPhysicalEvaluations), validateattributes(options.MaxPhysicalEvaluations,{'double'},{'integer'}); end
budgetStart=budget.Used; stopAt=min(budget.Limit,budgetStart+options.MaxPhysicalEvaluations);
fullStart=budget.FullChecks; invalidStart=budget.Invalid;
current=assess(best,true); assert(current.valid,'cam:FeasibilityInitial','初始路线无法评价；请先调整合法初值。');
probe=project.params.gradientProbeMM; initialProbe=probe; step=project.params.stepMM;
controls=camdesign.searchSchedule(project.params,1); refinements=0; expansions=0; reason='iteration_limit';
direction=zeros(size(best.nodes)); grad=direction; probeScores=inf(size(best.nodes,1),4);
referenceDirection=direction; referenceGrad=direction; referenceProbeScores=probeScores;
baseNodes=best.nodes; acceptedStep=0; smoothingAttempts=0; smoothingAlpha=0;
history=entry(0,false,'initial');
free=[(2:size(best.nodes,1))';(size(best.nodes,1)+2:2*size(best.nodes,1))'];
try
for iteration=1:options.MaxIterations
    controls=camdesign.searchSchedule(project.params,iteration);
    if notify(iteration-1), reason='user_stop'; break; end
    baseNodes=best.nodes; grad=zeros(size(baseNodes)); probeScores=inf(size(baseNodes,1),4);
    referenceGrad=grad; referenceProbeScores=probeScores; referenceAnchor=current.metrics.score;
    candidates=cell(numel(free)*2,1); states=candidates; costs=inf(numel(candidates),1); slot=0;
    fullProbes=~current.feasible && current.partialViolationSquared<1e-8 && current.violations(9)>0;
    anchor=proxy(current); before=current;
    batch={};
    if options.CandidateWorkers>0
        frozen=cell(1,2*numel(free));
        for j=1:numel(free)
            for directionIndex=1:2
                trial=best; trial.nodes(free(j))=baseNodes(free(j))+(3-2*directionIndex)*probe;
                frozen{2*j-2+directionIndex}=trial;
            end
        end
        batch=budget.evaluateBatch(frozen,fullProbes,stopAt,options.CandidateWorkers);
    end
    for k=1:numel(free)
        idx=free(k); values=[Inf Inf]; referenceValues=values;
        for sign=[1 -1]
            trial=best; trial.nodes(idx)=baseNodes(idx)+sign*probe;
            if options.CandidateWorkers>0
                index=slot+1;
                if index>numel(batch), budget.check(stopAt); end
                state=assess(trial,fullProbes,batch{index});
            else, state=assess(trial,fullProbes); end
            cost=proxy(state); slot=slot+1;
            candidates{slot}=trial; states{slot}=state; costs(slot)=cost;
            values(1+(sign<0))=cost;
            if state.valid, referenceValues(1+(sign<0))=state.metrics.score; end
        end
        if all(isfinite(values)), grad(idx)=(values(1)-values(2))/(2*probe);
        elseif isfinite(values(1)), grad(idx)=(values(1)-anchor)/probe;
        elseif isfinite(values(2)), grad(idx)=(anchor-values(2))/probe; end
        [row,col]=ind2sub(size(baseNodes),idx); probeScores(row,2*col-1:2*col)=values;
        referenceProbeScores(row,2*col-1:2*col)=referenceValues;
        if all(isfinite(referenceValues)), referenceGrad(idx)=(referenceValues(1)-referenceValues(2))/(2*probe);
        elseif isfinite(referenceValues(1)), referenceGrad(idx)=(referenceValues(1)-referenceAnchor)/probe;
        elseif isfinite(referenceValues(2)), referenceGrad(idx)=(referenceAnchor-referenceValues(2))/probe; end
    end
    weighted=camdesign.weightedCandidatePosition(baseNodes,probeScores,probe,anchor);
    direction=weighted-baseNodes;
    if sum(direction.*grad,'all')>=0 || norm(direction(:))<1e-12, direction=-grad; end
    magnitude=norm(direction(:)); if magnitude>1e-12, direction=direction/magnitude; else, direction(:)=0; end
    referenceWeighted=camdesign.weightedCandidatePosition(baseNodes,referenceProbeScores,probe,referenceAnchor);
    referenceDirection=referenceWeighted-baseNodes;
    if sum(referenceDirection.*referenceGrad,'all')>=0 || norm(referenceDirection(:))<1e-12, referenceDirection=-referenceGrad; end
    referenceMagnitude=norm(referenceDirection(:));
    if referenceMagnitude>1e-12, referenceDirection=referenceDirection/referenceMagnitude; else, referenceDirection(:)=0; end
    history(end).event='searching'; history(end).directionIteration=iteration;
    history(end).directionBaseNodes=baseNodes; history(end).descentDirection=direction;
    history(end).gradient=grad; history(end).probeScores=probeScores; history(end).evaluations=evals;
    history(end).referenceProbeScores=referenceProbeScores; history(end).referenceDescentDirection=referenceDirection;
    if notify(iteration-1), reason='user_stop'; break; end
    accepted=false; acceptedStep=0; method='no_step'; smoothingAttempts=0; smoothingAlpha=0;
    if ~current.feasible
        % Do not postpone a provably feasible transition behind an unrelated
        % aggregate quality improvement on a near-zero violation plateau.
        [~,promotionOrder]=sort(costs);
        for which=promotionOrder'
            state=states{which};
            if ~state.valid || ~state.numericFeasible || ~state.orderSatisfied, continue; end
            promotion=candidates{which};
            if controls.learningScale~=1
                promotion.nodes=baseNodes+(promotion.nodes-baseNodes)*controls.learningScale; state=assess(promotion,true);
            elseif ~state.fullChecked, state=assess(promotion,true); states{which}=state; end
            if state.valid && state.feasible
                best=promotion; current=state; accepted=true; acceptedStep=max(vecnorm(best.nodes-baseNodes,2,2));
                method='full-feasible-coordinate-promotion'; break;
            end
        end
    end
    proposals={direction,referenceDirection}; labels={'violation-aggregate','reference-aggregate'};
    for proposal=1:2
        if strcmp(method,'full-feasible-coordinate-promotion'), break; end
        proposed=proposals{proposal};
        if norm(proposed(:))<=1e-12 || (proposal==2 && norm(proposed(:)-proposals{1}(:))<1e-10), continue; end
        trialStep=step*controls.learningScale;
        for backtrack=1:12
            trial=best; trial.nodes=baseNodes+trialStep*proposed;
            if consider(trial,[]), accepted=true; acceptedStep=trialStep; method=labels{proposal}; break; end
            trialStep=trialStep/2;
        end
    end
    % Full rejection of the best proxy MUST NOT hide a valid second choice.
    if ~accepted
        [~,order]=sort(costs);
        for which=order'
            if ~isfinite(costs(which)), continue; end
            trial=candidates{which}; cached=states{which};
            if controls.learningScale~=1
                trial.nodes=baseNodes+(trial.nodes-baseNodes)*controls.learningScale; cached=[];
            end
            if consider(trial,cached)
                accepted=true; acceptedStep=max(vecnorm(best.nodes-baseNodes,2,2)); method='coordinate_rescue'; break;
            end
        end
    end
    smoothingBase=best.nodes; rates=smoothingPlan();
    for alpha=rates
        smoothingAttempts=smoothingAttempts+1; trial=best; middle=2:size(baseNodes,1)-1;
        trial.nodes(middle,:)=(1-alpha)*smoothingBase(middle,:)+alpha*(smoothingBase(middle-1,:)+smoothingBase(middle+1,:))/2;
        if consider(trial,[])
            accepted=true; acceptedStep=max(vecnorm(best.nodes-baseNodes,2,2)); smoothingAlpha=alpha; method=[method '+neighbor_smoothing']; break;
        end
    end
    if accepted
        actual=best.nodes-baseNodes; actualNorm=norm(actual(:)); if actualNorm>0, direction=actual/actualNorm; end
    end
    history(end+1)=entry(iteration,accepted,method); %#ok<AGROW>
    if accepted
        step=min(max(acceptedStep*1.5,probe),4*project.params.stepMM); refinements=0;
    elseif refinements<3
        probe=probe/2; step=max(probe,project.params.stepMM/2); refinements=refinements+1; history(end).event='probe_refinement';
    elseif expansions<2
        expansions=expansions+1; probe=initialProbe*4^expansions; step=max(probe,project.params.stepMM);
        refinements=0; history(end).event='probe_expansion';
    else
        reason='no_improving_step'; break;
    end
    assert(isequaln(best.params,project.params) && isequaln(best.targets,project.targets) && isequal(best.nodes(1,:),project.nodes(1,:)), ...
        'cam:FeasibilityMutation','搜索改变了锁定参数、目标顺序或起点。');
end
catch ex
    if strcmp(ex.identifier,'cam:PhysicalEvaluationBudget'), reason='physical_evaluation_limit';
    elseif strcmp(ex.identifier,'cam:PhysicalTimeBudget'), reason='time_limit';
    else, rethrow(ex); end
    if ~isequal(history(end).nodes,best.nodes), history(end+1)=entry(iteration,true,'budget_terminal_selection'); end
end
trainingState=current;
if options.CandidateWorkers>0
    evals=budget.Used-budgetStart; fullEvals=budget.FullChecks-fullStart; invalidEvals=budget.Invalid-invalidStart;
end
assessment=[]; verified=false; converged=false; verification=[]; assessmentAttempts=0;
if options.FinalAssessment
    assessment=camdesign.autoTuneAssessment(best,[project.params.samples project.params.camSamples]);
    verified=assessment.verifiedFeasible; converged=assessment.convergencePassed;
    verification=assessment.eight; assessmentAttempts=assessment.physicalEvaluationAttempts;
end
history(end).stopped=strcmp(reason,'user_stop'); history(end).event='finished'; history(end).evaluations=evals;
info=struct('algorithm','feasibility-four-direction-v1','objectiveVersion',current.rankingVersion, ...
    'reason',reason,'iterations',history(end).iteration,'requestedIterations',options.MaxIterations, ...
    'evaluations',evals,'fullGeometryEvaluations',fullEvals,'invalidEvaluations',invalidEvals,'rejectedFullCandidates',rejectedFull, ...
    'elapsedSeconds',toc(timer),'finalMetrics',current.metrics,'trainingFeasible',current.feasible, ...
    'rankingState',trainingState,'verifiedFeasible',verified,'convergencePassed',converged, ...
    'assessment',assessment,'verification',verification,'remainingConstraints',{{}}, ...
    'dynamicWeights',dynamic,'referenceWeights',project.params.weights,'finalActiveWeights',project.params.weights, ...
    'finalDynamicScore',current.metrics.score,'probeExpansions',expansions);
info.remainingConstraints=current.result.warnings;
info.assessmentEvaluationAttempts=assessmentAttempts; info.totalEvaluationAttempts=evals+assessmentAttempts;
info.physicalBudget=budget.snapshot(); info.physicalEvaluations=budget.Used-budgetStart; info.physicalEvaluationStopAt=stopAt;
info.assessmentPerformed=options.FinalAssessment;
info.cachedFinalResult=current.result;
info.rankingSemantics='Infeasible: lexicographic sum(normalized gate violations^2), max violation, quality. Feasible: fully feasible candidates only. Quality=L/direct + .2[(RMS/tol)^2+(maxHit/tol)^2] + .03(pressureProbe/limit)^2 + .02 soft excess over preferred pressure margin min(0.5deg,0.1*limit). Pressure preference uses extra same-law samples. User gates never change.';
info.trainingSemantics='Four-direction probes and whole-set improvement weighting, full-check line search, next-best coordinate rescue, same learning/smoothing schedule; adaptive probe halving and two logged expansions. Independent algorithm, not recovered original code.';
info.proposalVersion='dual-proposal-small-error-pressure-margin-v3';
info.weightSemantics='Original six fixed weights/peak-v2 score guide a SECOND proposal only; neither reference score nor dynamic weights decide acceptance. Independent feasibility/quality ranking remains unchanged.';
notify(history(end).iteration);
    function state=assess(candidate,full,record)
        if nargin<3, budget.check(stopAt); end
        evals=evals+1; if full, fullEvals=fullEvals+1; end
        try
            if nargin<3, result=budget.evaluate(candidate,full,stopAt);
            else
                if ~isempty(record.identifier), error(record.identifier,'%s',record.message); end
                result=record.result;
            end
            state=camdesign.feasibilityFourState(candidate,result); state.result=result;
        catch ex
            if ismember(ex.identifier,{'cam:PhysicalEvaluationBudget','cam:PhysicalTimeBudget'}), rethrow(ex); end
            if startsWith(ex.identifier,'cam:') || startsWith(ex.identifier,'MATLAB:expected')
                invalidEvals=invalidEvals+1;
                state=struct('valid',false,'fullChecked',full,'feasible',false,'numericFeasible',false,'orderSatisfied',false, ...
                    'partialViolationSquared',Inf,'violationSquared',Inf,'maxNormalizedViolation',Inf,'qualityObjective',Inf,'violations',Inf(1,9));
            else, rethrow(ex); end
        end
    end
    function stop=notify(iter)
        shown=history; shown(end).displayResult=current.result;
        shown(end).physicalEvaluations=budget.Used-budgetStart; shown(end).physicalEvaluationLimit=stopAt-budgetStart;
        stop=callback(iter,best,shown);
    end
    function value=proxy(state)
        value=Inf; if ~state.valid, return; end
        if current.feasible
            if state.numericFeasible && state.orderSatisfied, value=state.qualityObjective; end
        else
            value=state.partialViolationSquared;
            if fullProbesSafe(), value=state.violationSquared; end
            anchorValue=current.partialViolationSquared; if fullProbesSafe(), anchorValue=current.violationSquared; end
            if abs(value-anchorValue)<=1e-10*max(1,abs(anchorValue)), value=value+1e-6*(state.qualityObjective-current.qualityObjective); end
        end
    end
    function yes=fullProbesSafe()
        yes=~current.feasible && current.partialViolationSquared<1e-8 && current.violations(9)>0;
    end
    function accepted=consider(candidate,cached)
        accepted=false; if isempty(cached), cached=assess(candidate,false); end
        if ~cached.valid, return; end
        if current.feasible && (~cached.numericFeasible || ~cached.orderSatisfied), return; end
        if ~current.feasible && cached.partialViolationSquared>current.violationSquared+1e-10*max(1,current.violationSquared), return; end
        if ~cached.fullChecked, cached=assess(candidate,true); end
        if camdesign.feasibilityFourBetter(cached,current), best=candidate; current=cached; accepted=true;
        else, rejectedFull=rejectedFull+1; end
    end
    function rates=smoothingPlan()
        rates=[.1 .05 .025]; if controls.custom, rates=controls.smoothingRates; end
    end
    function item=entry(iteration,accepted,event)
        stage='restore-feasibility'; if current.feasible, stage='shorten-feasible'; end
        item=struct('iteration',iteration,'score',current.metrics.score,'maxHitError',current.metrics.maxHitError, ...
            'evaluations',evals,'stopped',false,'accepted',accepted,'event',event,'stepType',event,'stepMM',acceptedStep, ...
            'directionIteration',iteration,'directionBaseNodes',baseNodes,'descentDirection',direction,'gradient',grad,'probeScores',probeScores, ...
            'metrics',current.metrics,'nodes',best.nodes,'smoothingAttempts',smoothingAttempts,'smoothingAlpha',smoothingAlpha, ...
            'probeMM',probe,'learningScale',controls.learningScale,'scheduleScale',controls.decay,'scheduledStepMM',step*controls.learningScale, ...
            'plannedSmoothingRates',smoothingPlan(),'referenceWeights',project.params.weights,'activeWeights',project.params.weights, ...
            'dynamicScore',current.metrics.score,'weightMode','fixed','weightUpdateIteration',0,'weightChanged',false, ...
            'feasibilityStage',stage,'fullGeometryChecked',current.fullChecked,'trainingFeasible',current.feasible, ...
            'violationSquared',current.violationSquared,'maxNormalizedViolation',current.maxNormalizedViolation, ...
            'violationComponents',current.violations,'qualityObjective',current.qualityObjective,'rankingVersion',current.rankingVersion, ...
            'preferencePressureDeg',current.pressurePreference.maxPressureDeg,'preferredPressureMarginDeg',current.pressurePreference.preferredMarginDeg, ...
            'referenceProbeScores',referenceProbeScores,'referenceDescentDirection',referenceDirection,'proposalVersion','dual-proposal-small-error-pressure-margin-v3');
    end
end
