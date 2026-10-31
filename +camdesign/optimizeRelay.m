function [best,history,info]=optimizeRelay(project,callback,options)
arguments
    project struct
    callback=[]
    options.Mode char {mustBeMember(options.Mode,{'relay-sqp-v1','multistart-relay-sqp-v1'})}='relay-sqp-v1'
    options.MaxPhysicalEvaluations (1,1) double {mustBeInteger,mustBePositive}=200000
    options.Starts (1,1) double {mustBeInteger,mustBePositive}=5
    options.RandomSeed (1,1) double {mustBeInteger,mustBeNonnegative}=20261031
    options.PerturbationMM (1,1) double {mustBeFinite,mustBePositive}=8
    options.FourFraction (1,1) double {mustBeFinite,mustBePositive}=.25
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive}=project.params.iterations
    options.MaxSeconds (1,1) double {mustBePositive}=3600
    options.DifferenceStepMM (1,1) double {mustBeFinite,mustBePositive}=.0005
    options.FinalAssessment (1,1) logical=true
    options.StageCompleteFcn=[]
    options.StartFcn=[]
    options.CandidateWorkers (1,1) double {mustBeInteger,mustBeNonnegative}=0
    options.Budget=[]
end
if isempty(callback), callback=@(~,~,~)false; end
camdesign.validateProject(project);
assert(exist('fmincon','file')==2 && license('test','Optimization_Toolbox'),'cam:FminconUnavailable','接力精修需要Optimization Toolbox。');
assert(options.FourFraction<1,'cam:RelaySettings','四方向预算比例须小于1。');
assert(~camdesign.dynamicWeightSettings(project.params).enabled,'cam:RelayDynamicWeights','接力和多起点不支持动态权重，请先明确关闭。');
assert(~strcmp(camdesign.routeModel(project.params),'bspline-v1'),'cam:BSplineBackend','接力目前支持cubic/独立贝塞尔，不自动切换画法。');
budget=options.Budget;
if isempty(budget), budget=camdesign.PhysicalEvaluationBudget(options.MaxPhysicalEvaluations,options.MaxSeconds); end
timer=tic;
best=project; bestResult=budget.evaluate(best,true); bestState=camdesign.feasibilityFourState(best,bestResult);
assert(bestState.valid,'cam:RelayInitial','初始路线无法评价。');
requestedStarts=options.Starts; if strcmp(options.Mode,'relay-sqp-v1'), requestedStarts=1; end
starts=min(requestedStarts,max(0,budget.Limit-budget.Used));
stages=struct([]); seeds=cell(starts,1); history=struct([]); totalIterations=0; stopped=false;
activeStart=0; activePhase='initial'; phaseOffset=0; allocation=0; reason='starts_complete';
append(0,project,bestState,'initial');
if notify(), stopped=true; reason='user_stop'; end
for startIndex=1:starts
    if stopped || budget.Used>=budget.Limit, break; end
    activeStart=startIndex; remainingStarts=starts-startIndex+1;
    allocation=floor((budget.Limit-budget.Used)/remainingStarts); startAt=budget.Used;
    [seed,perturbation]=camdesign.relayPerturbation(project,startIndex,starts,options.RandomSeed,options.PerturbationMM);
    seeds{startIndex}=struct('project',seed,'perturbation',perturbation,'allocatedEvaluations',allocation,'startAt',startAt);
    if ~isempty(options.StartFcn), options.StartFcn(startIndex,seeds{startIndex}); end
    activePhase='four'; phaseOffset=totalIterations; fourLease=max(1,floor(allocation*options.FourFraction));
    try
        [candidate,trace,fourInfo]=camdesign.optimizeFeasibilityFour(seed,@stageProgress, ...
            Budget=budget,MaxPhysicalEvaluations=fourLease,MaxIterations=options.MaxIterations,FinalAssessment=false,CandidateWorkers=options.CandidateWorkers);
        archive(candidate,trace,fourInfo,fourLease); totalIterations=phaseOffset+fourInfo.iterations;
        stopped=stopped || strcmp(fourInfo.reason,'user_stop');
        left=min(budget.Limit-budget.Used,allocation-(budget.Used-startAt));
        if ~stopped && left>=3 && camdesign.controlBounds(candidate).gatePassed
            activePhase='sqp'; phaseOffset=totalIterations;
            [candidate,trace,sqpInfo]=camdesign.optimizeQualitySqp(candidate,@stageProgress, ...
                Budget=budget,MaxPhysicalEvaluations=left,MaxIterations=options.MaxIterations,DifferenceStepMM=options.DifferenceStepMM);
            archive(candidate,trace,sqpInfo,left); totalIterations=phaseOffset+sqpInfo.iterations;
            stopped=stopped || strcmp(sqpInfo.reason,'user_stop');
        end
    catch ex
        if strcmp(ex.identifier,'cam:PhysicalTimeBudget'), reason='time_limit'; break;
        elseif ismember(ex.identifier,{'cam:FeasibilityInitial','cam:FminconInitialGeometry','cam:FminconInitialBounds'})
            seeds{startIndex}.errorIdentifier=ex.identifier; seeds{startIndex}.errorMessage=ex.message;
        else, rethrow(ex); end
    end
    seeds{startIndex}.actualEvaluations=budget.Used-startAt;
    if stopped, reason='user_stop'; break; end
    if toc(timer)>=options.MaxSeconds, reason='time_limit'; break; end
end
if budget.Used>=budget.Limit, reason='physical_evaluation_limit'; end
proposed=best; proposedState=bestState; assessment=[]; proposedAssessment=[]; fallbackAssessment=[]; validationCalls=0; reverted=false;
if options.FinalAssessment
    assessment=camdesign.autoTuneAssessment(best,[project.params.samples project.params.camSamples]);
    proposedAssessment=assessment;
    validationCalls=validationCalls+assessment.physicalEvaluationAttempts;
    if ~assessment.verifiedFeasible && ~isequaln(best,project)
        fallbackAssessment=camdesign.autoTuneAssessment(project,[project.params.samples project.params.camSamples]);
        validationCalls=validationCalls+fallbackAssessment.physicalEvaluationAttempts;
        if fallbackAssessment.verifiedFeasible
            best=project; assessment=fallbackAssessment; reverted=true;
            bestResult=camdesign.evaluate(best,true); validationCalls=validationCalls+1;
            bestState=camdesign.feasibilityFourState(best,bestResult);
        end
    end
end
activePhase='complete'; append(totalIterations,best,bestState,'finished'); history(end).stopped=stopped;
verified=false; converged=false; verification=[];
if options.FinalAssessment, verified=assessment.verifiedFeasible; converged=assessment.convergencePassed; verification=assessment.eight; end
info=struct('algorithm',options.Mode,'reason',reason,'iterations',totalIterations,'requestedIterations',options.MaxIterations, ...
    'evaluations',budget.Used,'physicalEvaluations',budget.Used,'physicalBudget',budget.snapshot(), ...
    'elapsedSeconds',toc(timer),'stages',stages,'starts',{seeds},'requestedStarts',requestedStarts,'allocatedStarts',starts, ...
    'randomSeed',options.RandomSeed,'perturbationMM',options.PerturbationMM,'fourFraction',options.FourFraction, ...
    'trainingFeasible',bestState.feasible,'rankingState',bestState,'finalMetrics',bestState.metrics, ...
    'assessment',assessment,'verification',verification,'assessmentPerformed',options.FinalAssessment, ...
    'assessmentEvaluationAttempts',validationCalls,'verifiedFeasible',verified,'convergencePassed',converged, ...
    'proposedProject',proposed,'proposedState',proposedState,'proposedAssessment',proposedAssessment, ...
    'revertedToVerifiedInitial',reverted,'fallbackAssessment',fallbackAssessment,'cachedFinalResult',bestResult, ...
    'objectiveVersion',bestState.rankingVersion,'objectiveMode','feasibility-quality-v1', ...
    'parametersUnchanged',isequaln(best.params,project.params),'remainingConstraints',{bestResult.warnings}, ...
    'rankingSemantics','Same feasibilityFourState objective in four-direction and SQP; full exact gates before incumbent replacement. Native improvements can trade individual physical metrics.', ...
    'trainingSemantics','Shared strict physical-call budget across starts and stages. Stage local termination can leave budget unused; remaining starts share leftover. Original project retained for final dense fallback.');
notify();
    function stop=stageProgress(iter,candidate,trace)
        last=trace(end); result=last.displayResult; state=camdesign.feasibilityFourState(candidate,result);
        if camdesign.feasibilityFourBetter(state,bestState), best=candidate; bestState=state; bestResult=result; end
        append(phaseOffset+iter,candidate,state,last.event);
        stop=notify(); stopped=stopped || stop;
    end
    function append(iter,candidate,state,event)
        item=struct('iteration',iter,'stageIteration',iter-phaseOffset,'relayStage',activePhase,'relayStart',activeStart, ...
            'relayStarts',starts,'physicalEvaluations',budget.Used,'physicalEvaluationLimit',budget.Limit,'evaluations',budget.Used, ...
            'score',bestState.metrics.score,'maxHitError',bestState.metrics.maxHitError,'metrics',bestState.metrics,'nodes',best.nodes, ...
            'event',event,'stepType',activePhase,'accepted',~isempty(history) && ~isequal(history(end).nodes,best.nodes),'stopped',false, ...
            'trainingFeasible',bestState.feasible,'fullGeometryChecked',true,'qualityObjective',bestState.qualityObjective, ...
            'violationSquared',bestState.violationSquared,'maxNormalizedViolation',bestState.maxNormalizedViolation, ...
            'explorationNodes',candidate.nodes,'explorationMetrics',state.metrics,'explorationFeasible',state.feasible,'stageAllocation',allocation);
        if isempty(history), history=item; else, history(end+1)=item; end
    end
    function stop=notify()
        shown=history; shown(end).displayResult=bestResult;
        stop=callback(history(end).iteration,best,shown);
    end
    function archive(candidate,trace,stageInfo,lease)
        if isfield(trace,'displayResult'), trace=rmfield(trace,'displayResult'); end
        item=struct('start',activeStart,'phase',activePhase,'allocatedEvaluations',lease, ...
            'actualEvaluations',stageInfo.physicalEvaluations,'candidate',candidate,'history',trace,'info',stageInfo);
        if isempty(stages), stages=item; else, stages(end+1)=item; end
        if ~isempty(options.StageCompleteFcn), options.StageCompleteFcn(item); end
    end
end
