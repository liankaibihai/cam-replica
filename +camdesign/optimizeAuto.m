function [best,history,info]=optimizeAuto(project,callback)
% Bounded independent portfolio. Search weights never decide acceptance gates.
assert(~strcmp(camdesign.routeModel(project.params),'bspline-v1'),'cam:BSplineBackend','B样条目前仅支持内点法，不支持全自动组合。');
if nargin<2 || isempty(callback), callback=@(~,~,~)false; end
camdesign.validateProject(project); cfg=camdesign.autoTuneSettings(project.params);
timer=tic; stream=RandStream('mt19937ar','Seed',cfg.seed);
base=project.params.weights(:)'; signature=physical(project);
lockedModel=camdesign.routeModel(project.params); lockedDegree=[];
if strcmp(lockedModel,'bezier-blend-independent-v1'), lockedDegree=project.params.bezier.degree; end
activeMapping=[];
grid=[max(601,min(2001,project.params.samples)),max(721,min(1441,project.params.camSamples))];
history=[]; trials=[]; pool={}; total=0; evals=0; stopped=false;
stage='initial'; trialNumber=0; localBudget=0; active=base; offset=0;
observedIterations=0; observedEvaluations=0;
totalBudget=(cfg.trials+cfg.polishCount)*cfg.maxIterations;
best=project; initial=commonResult(project); evals=evals+1;
addCandidate(project,base,0,'initial','initial',0,0,0,[]);
relay(0,project,[]);
for t=1:cfg.trials
    if stopped, break; end
    stage='search'; trialNumber=t; offset=total; active=base;
    observedIterations=0; observedEvaluations=0; localBudget=cfg.maxIterations;
    activeMapping=[];
    candidate=project; startFrom='original';
    if t>2 && mod(t,2)==1, candidate=best; startFrom='incumbent'; end
    try
        if t==1
            localBudget=min(cfg.maxIterations,project.params.iterations);
            candidate.params.iterations=localBudget;
            if ~isempty(cfg.selectedWeights)
                active=min(4*base,max(.25*base,cfg.selectedWeights));
                active(base==0)=0; % A later user edit overrides the saved seed.
            end
        else
            [candidate,active,activeMapping]=configure(candidate,t); localBudget=candidate.params.iterations;
        end
        candidate.params.weights=active; candidate.params.dynamicWeights=struct('enabled',false);
        checkLock(candidate); startSettings=camdesign.trainingSettings(candidate);
        [candidate,~,run]=camdesign.optimizeSearch(candidate,@relay,'peak-gradient-v2');
        total=offset+run.iterations; evals=evals+run.evaluations;
        addCandidate(candidate,active,t,stage,run.reason,run.iterations,localBudget,run.evaluations,startSettings);
        trials(end).startFrom=startFrom;
        stopped=stopped || strcmp(run.reason,'user_stop');
    catch ex
        if ~expected(ex), rethrow(ex); end
        recordFailure(candidate,t,ex,startFrom);
    end
end
% Constrained polish freezes its objective during each solver call. It can
% reduce feasibility residuals that the weighted penalty search leaves behind.
for t=1:cfg.polishCount
    if stopped, break; end
    stage='polish'; trialNumber=cfg.trials+t; offset=total; localBudget=cfg.maxIterations;
    observedIterations=0; observedEvaluations=0;
    activeMapping=[];
    candidate=best; selected=pool{bestIndex()}; active=selected.weights;
    if t==1 && size(candidate.nodes,1)<34 && strcmp(camdesign.routeModel(candidate.params),'cubic')
        [candidate,pointInfo]=camdesign.setControlPointCount(candidate,34); activeMapping=pointInfo.fitInfo;
    end
    candidate.params.samples=max(candidate.params.samples,grid(1));
    % Large search probes are useful for exploration but poor local derivative
    % estimates for dense constraints. Two explicit local scales are tried.
    differences=[.01 .001]; candidate.params.gradientProbeMM=differences(t);
    candidate.params.iterations=localBudget; candidate.params.weights=active;
    candidate.params.dynamicWeights=struct('enabled',false);
    try
        checkLock(candidate); startSettings=camdesign.trainingSettings(candidate);
        [candidate,~,run]=camdesign.optimizeFmincon(candidate,@relay,Algorithm='interior-point', ...
            DifferenceStepMM=differences(t),MaxSeconds=3600);
        total=offset+run.iterations; evals=evals+run.evaluations;
        addCandidate(candidate,active,trialNumber,stage,run.reason,run.iterations,localBudget,run.evaluations,startSettings);
        stopped=stopped || strcmp(run.reason,'user_stop');
    catch ex
        if ~expected(ex), rethrow(ex); end
        recordFailure(candidate,trialNumber,ex,'incumbent');
    end
end
% Validate the leading candidates at two further resolutions. If a candidate
% fails convergence it cannot outrank one that truly passes every gate.
order=ranked(); shortlist=order(1:min(3,numel(order))); finalKeys=[]; assessments=cell(size(shortlist));
for k=1:numel(shortlist)
    item=pool{shortlist(k)};
    assessments{k}=camdesign.autoTuneAssessment(item.project,grid); evals=evals+assessments{k}.physicalEvaluationAttempts;
    finalKeys(k,:)=[~assessments{k}.verifiedFeasible,rankReport(assessments{k}.eight)]; %#ok<AGROW>
end
[~,orderFinal]=sortrows(finalKeys); chosen=orderFinal(1); selected=pool{shortlist(chosen)};
assessment=assessments{chosen}; best=selected.project;
best.params.autoTune=cfg; best.params.autoTune.selectedWeights=selected.weights;
checkLock(best); active=selected.weights; stage='complete'; trialNumber=selected.trial;
localBudget=0; offset=total; relay(0,best,[]);
final=commonResult(best); evals=evals+1;
reason='auto_budget_complete'; if stopped, reason='user_stop'; end
remaining=assessment.eight.refinedGrid.warnings;
if ~assessment.verifiedFeasible, remaining{end+1}='未通过全部原始阈值及采样收敛检查；不得作为已验证可用凸轮。'; end
info=struct('algorithm','auto-tune-v1','fullAuto',true,'iterations',total,'requestedIterations',totalBudget, ...
    'reason',reason,'referenceWeights',base,'finalActiveWeights',active, ...
    'finalDynamicScore',sum(active.*final.metrics.terms),'weightMode','auto-tuned-v1', ...
    'verification',assessment.eight,'convergencePassed',assessment.convergencePassed, ...
    'verifiedFeasible',assessment.verifiedFeasible,'assessment',assessment,'trials',trials, ...
    'selectedTrial',selected.trial,'selectedStage',selected.stage,'finalMetrics',final.metrics,'initialMetrics',initial.metrics, ...
    'evaluations',evals,'elapsedSeconds',toc(timer),'comparisonGrid',grid, ...
    'requestedRatio',project.params.gearRatio,'finalEffectiveRatio',final.cam.effectiveRatio, ...
    'physicalParametersUnchanged',isequaln(signature,physical(best)), ...
    'routeModelLocked',true,'fixedRouteModel',lockedModel,'fixedBezierDegree',lockedDegree, ...
    'mappingPolicy','Keep model and Bezier degree; count reconfiguration must pass strict independent geometry/tangent mapping. Automatic count cap=max(50,original count).', ...
    'remainingConstraints',{remaining},'settings',cfg, ...
    'selectionPolicy','Same common grid, unchanged physical thresholds first; then scaled violation and fixed-reference score. Top three receive native/4x/8x gates.', ...
    'evaluationCountScope','Completed backend attempts plus common-grid callbacks and acceptance checks; failed backends contribute only counts observed before the failure.', ...
    'limitations',{{'Independent bounded portfolio, not recovered original AI or a global convergence guarantee.', ...
    'Only modeled sampled centers and discrete cam geometry; body clearance, RFID, slip and machining need separate validation.'}});

    function [q,w,mapping]=configure(q,index)
        choices=unique([size(project.nodes,1),18,34,50]);
        count=choices(1+mod(index-2,numel(choices)));
        if index==2, count=max(18,min(34,max(choices))); end
        count=max(4,count); mode=lockedModel;
        budget=max(1,round(cfg.maxIterations*(.5+.5*rand(stream))));
        desired=[301 601 901 1201]; density=desired(1+mod(index-2,4));
        changes=struct('routeModel',mode,'controlPointCount',count, ...
            'interpolationPerSegment',max(1,ceil((density-1)/(count-1))), ...
            'iterations',budget,'gradientForce',logsample(.05,8), ...
            'learningRate',logsample(.15,2),'smoothingRate',.25*rand(stream), ...
            'adjustInterval',round(logsample(10,100)),'adjustExponent',1.5*rand(stream));
        if strcmp(mode,'bezier-blend-independent-v1')
            changes.bezierDegree=lockedDegree;
        end
        [q,mapped]=camdesign.applyTrainingSettings(q,changes,'peak-gradient-v2', ...
            struct('MaxControlPoints',max(50,size(project.nodes,1))));
        mapping=mapped.fitInfo;
        q.params.stepMM=min(100,max(.01,project.params.stepMM*logsample(.25,4)));
        % A zero base is retained: automatic tuning must not silently enable
        % an explicitly disabled score term. Nonzero six terms all participate.
        w=base.*exp(log(.25)+log(16)*rand(stream,1,6));
        if index==2
            w=base.*[2 .5 .5 4 2 2];
            q.params.iterations=cfg.maxIterations;
        end
    end
    function v=logsample(low,high)
        v=exp(log(low)+(log(high)-log(low))*rand(stream));
    end
    function stop=relay(iteration,q,h)
        if ~isempty(h)
            observedIterations=max(observedIterations,iteration);
            observedEvaluations=max(observedEvaluations,h(end).evaluations);
        end
        checkLock(q); public=restore(q); rr=commonResult(public); evals=evals+1;
        controls=camdesign.trainingSettings(q);
        rec=struct('iteration',offset+iteration,'score',rr.metrics.score,'maxHitError',rr.metrics.maxHitError, ...
            'evaluations',evals,'stopped',stopped,'accepted',false,'event',stage,'stepType',stage,'stepMM',0, ...
            'directionIteration',offset+iteration,'directionBaseNodes',[],'descentDirection',[], ...
            'gradient',[],'probeScores',[],'metrics',rr.metrics,'smoothingAttempts',0,'smoothingAlpha',0, ...
            'probeMM',q.params.gradientProbeMM,'learningScale',controls.learningRate,'scheduleScale',1, ...
            'scheduledStepMM',q.params.stepMM,'plannedSmoothingRates',[], ...
            'referenceWeights',base,'activeWeights',active,'dynamicScore',sum(active.*rr.metrics.terms), ...
            'weightUpdateIteration',offset+1,'weightMode','auto-tuned-v1','weightChanged',false, ...
            'autoStage',stage,'autoTrial',trialNumber,'autoTrialCount',cfg.trials+cfg.polishCount, ...
            'trialIteration',iteration,'trialBudget',localBudget,'autoTotalBudget',totalBudget, ...
            'trainingSamples',q.params.samples,'trainingCamSamples',q.params.camSamples,'trainingControls',controls,'comparisonGrid',grid, ...
            'nominalDifferenceStepMM',NaN);
        if ~isempty(h)
            source=h(end);
            for name={'accepted','stepMM','directionBaseNodes','descentDirection','gradient','probeScores', ...
                    'smoothingAttempts','smoothingAlpha','probeMM','learningScale','scheduleScale','scheduledStepMM','plannedSmoothingRates','nominalDifferenceStepMM'}
                if isfield(source,name{1}), rec.(name{1})=source.(name{1}); end
            end
        end
        rec.weightChanged=isempty(history) || ~isequal(history(end).activeWeights,active);
        if ~isempty(history) && history(end).autoTrial==trialNumber && strcmp(history(end).autoStage,stage) && history(end).iteration==rec.iteration
            rec.weightChanged=rec.weightChanged || history(end).weightChanged; history(end)=rec;
        else, history=[history rec]; end %#ok<AGROW>
        stop=stopped;
        % Every callback consumer sees the same project that produced score.
        % Actual backend density remains explicit in trainingSamples above.
        public.params.samples=grid(1); public.params.camSamples=grid(2);
        if ~stopped && ~strcmp(stage,'complete'), stop=logical(callback(rec.iteration,public,history));
        elseif strcmp(stage,'complete'), callback(rec.iteration,public,history); end
        stopped=stopped || stop;
    end
    function addCandidate(q,w,id,phase,why,iterations,budget,attempts,settings)
        public=restore(q); checkLock(public);
        common=public; common.params.samples=grid(1); common.params.camSamples=grid(2);
        report=camdesign.verifyConstrained(common,4); evals=evals+2;
        key=rankReport(report);
        item=struct('project',public,'weights',w,'trial',id,'stage',phase,'rank',key,'verification',report);
        pool{end+1}=item;
        record=struct('trial',id,'stage',phase,'startFrom','original','reason',why, ...
            'iterations',iterations,'requestedIterations',budget,'evaluations',attempts, ...
            'weights',w,'training',settings,'samples',q.params.samples,'routeModel',camdesign.routeModel(q.params), ...
            'rank',key,'verification',report,'errorIdentifier','','errorMessage','');
        record.mappingFitInfo=activeMapping;
        trials=[trials record]; %#ok<AGROW>
        best=pool{bestIndex()}.project;
    end
    function recordFailure(q,id,ex,origin)
        total=offset+observedIterations; evals=evals+observedEvaluations;
        record=struct('trial',id,'stage',stage,'startFrom',origin,'reason','invalid_configuration', ...
            'iterations',observedIterations,'requestedIterations',localBudget,'evaluations',observedEvaluations,'weights',active, ...
            'training',[],'samples',q.params.samples,'routeModel',camdesign.routeModel(q.params), ...
            'rank',[1 Inf Inf Inf],'verification',[],'errorIdentifier',ex.identifier,'errorMessage',ex.message);
        record.mappingFitInfo=activeMapping;
        trials=[trials record]; %#ok<AGROW>
    end
    function indices=ranked()
        keys=cellfun(@(x)x.rank,pool,'UniformOutput',false); [~,indices]=sortrows(vertcat(keys{:}));
    end
    function index=bestIndex()
        indices=ranked(); index=indices(1);
    end
    function rr=commonResult(q)
        q=restore(q); q.params.samples=grid(1); q.params.camSamples=grid(2); rr=camdesign.evaluate(q,false);
    end
    function q=restore(q)
        q.params.weights=base;
        if isfield(project.params,'dynamicWeights'), q.params.dynamicWeights=project.params.dynamicWeights;
        elseif isfield(q.params,'dynamicWeights'), q.params=rmfield(q.params,'dynamicWeights'); end
    end
    function checkLock(q)
        assert(isequaln(signature,physical(q)),'cam:AutoTunePhysicalMutation','全自动不得改变硬件、阈值、目标或固定起点。');
        assert(strcmp(camdesign.routeModel(q.params),lockedModel),'cam:AutoTuneModelMutation','全自动不得切换用户选定的路线模型。');
        if ~isempty(lockedDegree)
            assert(q.params.bezier.degree==lockedDegree,'cam:AutoTuneModelMutation','全自动不得切换用户选定的贝塞尔阶数。');
        end
    end
end
function signature=physical(q)
allowed={'weights','training','iterations','gradientProbeMM','stepMM','samples','routeModel','routeSpline','bezier','autoTune','dynamicWeights'};
signature=q; signature.nodes=q.nodes(1,:);
signature.params=rmfield(q.params,intersect(fieldnames(q.params),allowed));
end
function key=rankReport(report)
key=[1 Inf Inf Inf]; a=report.optimizationGrid; b=report.refinedGrid;
if a.valid && b.valid
    intersections=max(a.metrics.intersectionCount,b.metrics.intersectionCount);
    key=[~report.verifiedFeasible,max([a.maxScaledViolation b.maxScaledViolation double(intersections>0)]), ...
        intersections,b.metrics.score];
end
end
function yes=expected(ex)
yes=ismember(ex.identifier,{'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel', ...
    'cam:ExtremeSteering','cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite', ...
        'cam:FminconUnavailable','cam:FminconInitialBounds','cam:FminconInitialGeometry','cam:ControlCountUnavailable', ...
        'cam:RouteMappingTolerance','cam:RouteMappingCount','cam:RouteMappingEndpoint','cam:TrainingSamples'});
end
