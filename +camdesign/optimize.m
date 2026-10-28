function [best,history] = optimize(project,callback)
% Independent normalized finite-difference descent; no proprietary weights.
if nargin<2, callback=@(~,~,~)false; end
camdesign.validateProject(project); best=project;
current=camdesign.evaluate(best,false); value=current.metrics.score;
history=struct('iteration',0,'score',value,'maxHitError',current.metrics.maxHitError, ...
    'evaluations',1,'stopped',false); evals=1;
step=project.params.stepMM; probe=project.params.gradientProbeMM;
% Fix launch position. Every later front-wheel node may move in X/Y.
free=[(2:size(best.nodes,1))';(size(best.nodes,1)+2:2*size(best.nodes,1))'];
for iteration=1:project.params.iterations
    if callback(iteration-1,best,history), history(end).stopped=true; break; end
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
    magnitude=norm(grad(:)); if magnitude<1e-10, break; end
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
    if ~accepted || step<1e-4, break; end
end
callback(history(end).iteration,best,history);
    function v=safeScore(t)
        try
            rr=camdesign.evaluate(t,false); v=rr.metrics.score;
        catch ex
            if startsWith(ex.identifier,'cam:') || startsWith(ex.identifier,'MATLAB:expected'), v=inf;
            else, rethrow(ex); end
        end
    end
end
