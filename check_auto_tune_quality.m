function report=check_auto_tune_quality()
% Full budget on the official solar flat-car course, with fixed ratio 35.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','auto_tune_20261030','quality_v2');
assert(~isfile(fullfile(folder,'verification.json')),'cam:PreserveEvidence','Existing quality result must not be overwritten.');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject(); project.params.autoTune=camdesign.autoTuneSettings(project.params);
before=camdesign.autoTuneAssessment(project);
[q,h,info]=camdesign.optimize(project,@(i,q,h)progress(i,q,h,folder),'auto-tune-v1');
save(fullfile(folder,'candidate.mat'),'project','q','h','info','before','-v7.3');
report=struct('release',version('-release'),'input','solarTestProject: official preliminary visits, flat, ratio35', ...
    'iterations',info.iterations,'requestedIterations',info.requestedIterations,'reason',info.reason, ...
    'evaluations',info.evaluations,'elapsedSeconds',info.elapsedSeconds,'selectedTrial',info.selectedTrial, ...
    'before',before.eight.refinedGrid,'after',info.verification.refinedGrid, ...
    'convergencePassed',info.convergencePassed,'verifiedFeasible',info.verifiedFeasible, ...
    'convergenceDelta',info.assessment.delta,'numericalChecks',info.assessment.numericalChecks,'referenceWeights',info.referenceWeights, ...
    'actualWeights',info.finalActiveWeights,'trials',info.trials, ...
    'physicalParametersUnchanged',info.physicalParametersUnchanged,'fixedRatio',q.params.gearRatio);
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('AUTO_QUALITY_DONE iterations=%d requested=%d feasible=%d stable=%d elapsed=%.3f\n', ...
    info.iterations,info.requestedIterations,info.verifiedFeasible,info.convergencePassed,info.elapsedSeconds);
end
function stop=progress(~,q,h,folder)
persistent lastStage lastTrial lastRound
r=h(end);
interval=50; if strcmp(r.autoStage,'polish'), interval=10; end
if isempty(lastStage) || ~strcmp(lastStage,r.autoStage) || lastTrial~=r.autoTrial || r.trialIteration-lastRound>=interval
    fprintf('AUTO_PROGRESS stage=%s trial=%d local=%d/%d cumulative=%d score=%.5f pressure=%.5f hit=%.5f return=%.5f nodes=%d samples=%d\n', ...
        r.autoStage,r.autoTrial,r.trialIteration,r.trialBudget,r.iteration,r.score,r.metrics.maxPressureDeg, ...
        r.metrics.maxHitError,r.metrics.actualReturnDeg,size(q.nodes,1),r.trainingSamples);
    lastStage=r.autoStage; lastTrial=r.autoTrial; lastRound=r.trialIteration;
    save(fullfile(folder,'checkpoint.mat'),'q','h','-v7.3');
end
stop=false;
end
