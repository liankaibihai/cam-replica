function [best,history,info]=optimizeLegacy(project,callback)
% a91d5e2 mean-only descent retained as a comparison path. Added reporting only.
if nargin<2 || isempty(callback), callback=@(~,~,~)false; end
timer=tic; camdesign.validateProject(project); best=project;
weightSettings=camdesign.dynamicWeightSettings(project.params);
assert(~weightSettings.enabled,'cam:DynamicWeightsBackend','历史算法不支持动态权重，请使用梯度或四方向搜索。');
current=camdesign.evaluate(best,false); value=current.metrics.legacyScore;
history=struct('iteration',0,'score',value,'maxHitError',current.metrics.maxHitError, ...
    'evaluations',1,'stopped',false); evals=1; reason='iteration_limit';
step=project.params.stepMM; probe=project.params.gradientProbeMM;
free=[(2:size(best.nodes,1))';(size(best.nodes,1)+2:2*size(best.nodes,1))'];
for iteration=1:project.params.iterations
    if callback(iteration-1,best,history), history(end).stopped=true; reason='user_stop'; break; end
    grad=zeros(size(best.nodes));
    for k=1:numel(free)
        idx=free(k); trial=best; trial.nodes(idx)=trial.nodes(idx)+probe;
        plus=safeScore(trial); trial.nodes(idx)=best.nodes(idx)-probe;
        minus=safeScore(trial); evals=evals+2;
        if isfinite(plus) && isfinite(minus), grad(idx)=(plus-minus)/(2*probe);
        elseif isfinite(plus), grad(idx)=(plus-value)/probe;
        elseif isfinite(minus), grad(idx)=(value-minus)/probe;
        end
    end
    magnitude=norm(grad(:));
    if magnitude<1e-10, reason='gradient_tolerance'; break; end
    direction=grad/magnitude; accepted=false;
    for line=1:9
        trial=best; trial.nodes=best.nodes-step*direction;
        trialScore=safeScore(trial); evals=evals+1;
        if trialScore<value-1e-10
            best=trial; value=trialScore; accepted=true; step=min(step*1.25,4*project.params.stepMM); break;
        end
        step=step/2;
    end
    current=camdesign.evaluate(best,false); evals=evals+1;
    history(end+1)=struct('iteration',iteration,'score',value, ...
        'maxHitError',current.metrics.maxHitError,'evaluations',evals,'stopped',false); %#ok<AGROW>
    if ~accepted, reason='line_search_failed'; break; end
    if step<1e-4, reason='step_tolerance'; break; end
end
callback(history(end).iteration,best,history);
info=struct('algorithm','legacy-v1','objectiveVersion','mean-v1','reason',reason, ...
    'iterations',history(end).iteration,'requestedIterations',project.params.iterations, ...
    'evaluations',evals,'elapsedSeconds',toc(timer));
    function v=safeScore(t)
        try
            rr=camdesign.evaluate(t,false); v=rr.metrics.legacyScore;
        catch ex
            if startsWith(ex.identifier,'cam:') || startsWith(ex.identifier,'MATLAB:expected'), v=inf;
            else, rethrow(ex); end
        end
    end
end
