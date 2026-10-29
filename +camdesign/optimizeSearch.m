function [best,history,info]=optimizeSearch(project,callback,algorithm)
% Video-inspired mode implements visible structures with explicit independent rules.
if isempty(callback), callback=@(~,~,~)false; end
assert(ismember(algorithm,{'peak-gradient-v2','video-four-direction-v1'}),'cam:Optimizer','未知优化路径。');
timer=tic; camdesign.validateProject(project); best=project;
current=camdesign.evaluate(best,false); value=current.metrics.score; evals=1;
history=entry(0,false,'initial',0,[],[]);
step=project.params.stepMM; probe=project.params.gradientProbeMM;
free=[(2:size(best.nodes,1))';(size(best.nodes,1)+2:2*size(best.nodes,1))'];
reason='iteration_limit'; refinements=0;
for iteration=1:project.params.iterations
    if callback(iteration-1,best,history), reason='user_stop'; break; end
    baseNodes=best.nodes; grad=zeros(size(baseNodes));
    probeScores=inf(size(baseNodes,1),4); bestProbe=best; bestProbeScore=value;
    % Per-node +X, -X, +Y, -Y probes. Launch node remains fixed.
    for k=1:numel(free)
        idx=free(k); trial=best; trial.nodes(idx)=baseNodes(idx)+probe;
        plus=safeScore(trial);
        if plus<bestProbeScore, bestProbe=trial; bestProbeScore=plus; end
        trial.nodes(idx)=baseNodes(idx)-probe; minus=safeScore(trial);
        if minus<bestProbeScore, bestProbe=trial; bestProbeScore=minus; end
        if isfinite(plus) && isfinite(minus), grad(idx)=(plus-minus)/(2*probe);
        elseif isfinite(plus), grad(idx)=(plus-value)/probe;
        elseif isfinite(minus), grad(idx)=(value-minus)/probe; end
        [row,col]=ind2sub(size(baseNodes),idx);
        probeScores(row,2*col-1:2*col)=[plus minus];
    end
    if strcmp(algorithm,'video-four-direction-v1')
        weightedCandidate=camdesign.weightedCandidatePosition(baseNodes,probeScores,probe,value);
        direction=weightedCandidate-baseNodes;
        % Protect the sign using the measured local objective gradient.
        if sum(direction.*grad,'all')>=0, direction=-grad; end
    else
        direction=-grad;
    end
    magnitude=norm(direction(:));
    if magnitude>1e-12, direction=direction/magnitude; else, direction=zeros(size(baseNodes)); end
    history(end).event='searching'; history(end).directionIteration=iteration;
    history(end).directionBaseNodes=baseNodes; history(end).descentDirection=direction;
    history(end).gradient=grad; history(end).probeScores=probeScores; history(end).evaluations=evals;
    if callback(iteration-1,best,history), reason='user_stop'; break; end
    accepted=false; acceptedStep=0; method='no_step'; smoothingAttempts=0; smoothingAlpha=0;
    if magnitude>1e-12
        trialStep=step;
        for line=1:12
            trial=best; trial.nodes=baseNodes+trialStep*direction;
            trialScore=safeScore(trial);
            if improves(trialScore)
                best=trial; value=trialScore; accepted=true; acceptedStep=trialStep; method='descent'; break;
            end
            trialStep=trialStep/2;
        end
    end
    % Retain an improving individual probe if aggregate search cannot advance.
    if ~accepted && improves(bestProbeScore)
        best=bestProbe; value=bestProbeScore; accepted=true; acceptedStep=probe; method='coordinate_rescue';
    end
    if strcmp(algorithm,'video-four-direction-v1')
        % Test the visible board formula after each search step. Our trigger and
        % objective-based acceptance/backtracking are explicitly independent.
        smoothingBase=best.nodes;
        for alpha=[0.1 0.05 0.025]
            smoothingAttempts=smoothingAttempts+1;
            trial=best; middle=2:size(baseNodes,1)-1;
            trial.nodes(middle,:)=(1-alpha)*smoothingBase(middle,:)+alpha*(smoothingBase(middle-1,:)+smoothingBase(middle+1,:))/2;
            trialScore=safeScore(trial);
            if improves(trialScore)
                acceptedStep=max(vecnorm(trial.nodes-baseNodes,2,2));
                best=trial; value=trialScore; accepted=true; smoothingAlpha=alpha; method=[method,'+neighbor_smoothing']; break;
            end
        end
    end
    current=camdesign.evaluate(best,false); evals=evals+1;
    history(end+1)=entry(iteration,accepted,method,acceptedStep,baseNodes,direction); %#ok<AGROW>
    history(end).smoothingAttempts=smoothingAttempts; history(end).smoothingAlpha=smoothingAlpha;
    if accepted
        step=min(max(acceptedStep*1.5,probe),4*project.params.stepMM); refinements=0;
    elseif refinements<3
        probe=probe/2; step=max(probe,project.params.stepMM/2); refinements=refinements+1;
        history(end).event='probe_refinement';
    else
        if magnitude<=1e-12, reason='gradient_tolerance'; else, reason='no_improving_step'; end
        break;
    end
end
current=camdesign.evaluate(best,true); evals=evals+1;
history(end).stopped=strcmp(reason,'user_stop'); history(end).event='finished'; history(end).evaluations=evals;
info=struct('algorithm',algorithm,'objectiveVersion','peak-v2','reason',reason, ...
    'iterations',history(end).iteration,'requestedIterations',project.params.iterations, ...
    'evaluations',evals,'elapsedSeconds',toc(timer),'remainingConstraints',{current.warnings}, ...
    'finalMetrics',current.metrics);
callback(history(end).iteration,best,history);
    function yes=improves(v)
        yes=isfinite(v) && v<value-1e-10*max(1,abs(value));
    end
    function v=safeScore(t)
        evals=evals+1;
        try
            rr=camdesign.evaluate(t,false); v=rr.metrics.score;
        catch ex
            if startsWith(ex.identifier,'cam:') || startsWith(ex.identifier,'MATLAB:expected'), v=inf;
            else, rethrow(ex); end
        end
    end
    function item=entry(iteration,accepted,event,stepUsed,base,directionUsed)
        item=struct('iteration',iteration,'score',current.metrics.score,'maxHitError',current.metrics.maxHitError, ...
            'evaluations',evals,'stopped',false,'accepted',accepted,'event',event,'stepType',event,'stepMM',stepUsed, ...
            'directionIteration',iteration,'directionBaseNodes',base,'descentDirection',directionUsed, ...
            'gradient',[],'probeScores',[],'metrics',current.metrics,'smoothingAttempts',0,'smoothingAlpha',0);
    end
end
