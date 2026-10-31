function record=check_relay_sqp_supplemental(action,stepMM)
% Separate diagnostics reuse one saved prefix; never merge them into main arm.
if nargin<1, action='prepare'; end
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
main=fullfile(root,'outputs','relay_multistart_20261031'); base=fullfile(main,'supplemental');
for arm={'four','relay','multistart'}
    assert(isfile(fullfile(main,arm{1},'verification.json')),'cam:MainExperimentRunning','主三组须先完成，补充诊断不能抢跑。');
end
if ~isfolder(base), mkdir(base); end
if strcmp(action,'prepare'), record=prepare(root,main,base); return; end
assert(strcmp(action,'run') && nargin==2 && ismember(stepMM,[.005 .0005]));
saved=load(fullfile(base,'prefix.mat')); prefix=saved.prefix; protocol=saved.protocol;
for k=1:numel(protocol.sourceManifest)
    item=protocol.sourceManifest(k); assert(strcmp(fileSHA256(fullfile(root,item.relativePath)),item.sha256),'cam:RelaySourceChanged','冻结源码已改变。');
end
label='fd_0p005'; if stepMM==.0005, label='fd_0p0005'; end
folder=fullfile(base,label); if ~isfolder(folder), mkdir(folder); end
resultPath=fullfile(folder,'solver_result.mat'); assert(~isfile(resultPath),'cam:EvidenceExists','已有补充诊断结果，拒绝覆盖。');
lockPath=fullfile(folder,'run.lock'); lock=java.io.File(lockPath); assert(lock.createNewFile(),'cam:ExperimentRunning','补充目录已有运行锁。');
cleanup=onCleanup(@()releaseLock(lockPath)); assert(~isfile(resultPath),'cam:EvidenceExists','取得锁后发现已有结果。');
fid=fopen(lockPath,'w'); fprintf(fid,'pid=%d\nstepMM=%.8g\nstarted=%s\n',feature('getpid'),stepMM,char(datetime('now'))); fclose(fid);
protocol.differenceStepMM=stepMM; writeJSON(fullfile(folder,'protocol.json'),protocol);
budget=camdesign.PhysicalEvaluationBudget(protocol.newPhysicalBudget,protocol.maxSeconds); lastCalls=-Inf;
[proposed,h,info]=camdesign.optimizeQualitySqp(prefix,@progress,Budget=budget, ...
    MaxPhysicalEvaluations=protocol.newPhysicalBudget,MaxIterations=protocol.maxIterations,DifferenceStepMM=stepMM);
assertLocked(prefix,proposed); save(resultPath,'proposed','h','info','protocol','-v7');
camdesign.saveProject(proposed,fullfile(folder,'proposed_project.mat'));
proposedAssessment=camdesign.autoTuneAssessment(proposed,protocol.grid);
q=proposed; selectedAssessment=proposedAssessment; fallback='none';
if ~proposedAssessment.verifiedFeasible
    if saved.prefixAssessment.verifiedFeasible
        q=prefix; selectedAssessment=saved.prefixAssessment; fallback='verified_relay_prefix';
    else
        q=saved.initial; selectedAssessment=saved.initialAssessment; fallback='verified_common_initial';
    end
end
assert(selectedAssessment.verifiedFeasible); assertLocked(prefix,q);
camdesign.saveProject(q,fullfile(folder,'candidate_project.mat'));
acceptedStepMM=zeros(max(0,numel(h)-1),1);
for k=2:numel(h), acceptedStepMM(k-1)=max(vecnorm(h(k).nodes-h(k-1).nodes,2,2)); end
tail=h(max(1,end-50):end);
record=struct('protocol',protocol,'reason',info.reason,'iterations',info.iterations,'seconds',info.elapsedSeconds, ...
    'newPhysicalEvaluations',info.physicalEvaluations,'physicalBudget',info.physicalBudget, ...
    'independentAssessmentEvaluations',proposedAssessment.physicalEvaluationAttempts, ...
    'solverExitflag',info.solverExitflag,'solverOutput',info.solverOutput, ...
    'nativeMetrics',info.finalMetrics,'proposedAssessment',proposedAssessment,'selectedAssessment',selectedAssessment, ...
    'fallback',fallback,'acceptedMaxControlDisplacementsMM',acceptedStepMM,'tailQuality',[tail(1).qualityObjective tail(end).qualityObjective], ...
    'tailMetrics',{{tail(1).metrics,tail(end).metrics}},'nonNodeInputUnchanged',true, ...
    'scope','Independent repeated-initial-state finite-difference diagnostic. The 50000-call prefix was not executed again. Each diagnostic owns a separate 150000-call allowance; neither is part of the original main relay arm or the other diagnostic.');
save(fullfile(folder,'result.mat'),'record','q','proposed','h','info','protocol','-v7'); writeJSON(fullfile(folder,'verification.json'),record);
fm=selectedAssessment.eight.refinedGrid.metrics;
fprintf('RELAY_SQP_SUPPLEMENT_DONE step=%.8g calls=%d/%d iter=%d reason=%s proposedFine=%d fallback=%s front=%.9g hit=%.9g pressure=%.9g\n', ...
    stepMM,info.physicalEvaluations,protocol.newPhysicalBudget,info.iterations,info.reason,proposedAssessment.verifiedFeasible,fallback,fm.routeLength,fm.maxHitError,fm.maxPressureDeg);
    function stop=progress(iter,candidate,history)
        stop=false; last=history(end); calls=last.physicalEvaluations;
        if calls-lastCalls>=1000 || strcmp(last.event,'finished')
            assertLocked(prefix,candidate); if isfield(last,'displayResult'), last=rmfield(last,'displayResult'); end
            checkpoint=candidate; save(fullfile(folder,'checkpoint.mat'),'checkpoint','last','-v7'); lastCalls=calls;
            writeJSON(fullfile(folder,'progress.json'),struct('iteration',iter,'newPhysicalEvaluations',calls,'metrics',last.metrics,'quality',last.qualityObjective));
            fprintf('RELAY_SQP_SUPPLEMENT_PROGRESS step=%.8g iter=%d calls=%d front=%.9g hit=%.8g pressure=%.8g quality=%.10g\n', ...
                stepMM,iter,calls,last.metrics.routeLength,last.metrics.maxHitError,last.metrics.maxPressureDeg,last.qualityObjective);
        end
    end
end
function record=prepare(root,main,base)
file=fullfile(base,'prefix.mat'); assert(~isfile(file),'cam:EvidenceExists','补充共同前缀已存在。');
lockPath=fullfile(base,'prepare.lock'); lock=java.io.File(lockPath); assert(lock.createNewFile(),'cam:ExperimentRunning','补充准备已有锁。');
cleanup=onCleanup(@()releaseLock(lockPath)); assert(~isfile(file),'cam:EvidenceExists','取得锁后发现已有前缀。');
common=load(fullfile(main,'common_initial.mat')); initial=common.project; initialAssessment=common.initialAssessment;
source=fullfile(main,'relay','stages','start_01_four','candidate_project.mat'); prefix=camdesign.importProject(source);
stageData=load(fullfile(main,'relay','stages','start_01_four','stage_result.mat'),'stage');
prefixCalls=stageData.stage.info.physicalBudget.used; assert(prefixCalls==50000);
assertLocked(initial,prefix); prefixAssessment=camdesign.autoTuneAssessment(prefix,common.protocol.grid);
sourceManifest=common.protocol.sourceManifest;
sourceManifest(end+1)=struct('relativePath','check_relay_sqp_supplemental.m','sha256',fileSHA256(fullfile(root,'check_relay_sqp_supplemental.m')));
for k=1:numel(sourceManifest)
    item=sourceManifest(k); path=fullfile(root,item.relativePath);
    assert(strcmp(fileSHA256(path),item.sha256),'cam:RelaySourceChanged','补充诊断须保留冻结实现。');
    target=fullfile(base,'source_snapshot',item.relativePath); if ~isfolder(fileparts(target)), mkdir(fileparts(target)); end
    copyfile(path,target);
end
originalSqp=load(fullfile(main,'relay','stages','start_01_sqp','stage_result.mat'),'stage');
protocol=struct('baseline','58f73fd','sourcePrefix',source,'sourcePrefixSHA256',fileSHA256(source), ...
    'sourceManifest',sourceManifest,'sharedPrefixPhysicalEvaluations',prefixCalls,'newPhysicalBudget',150000, ...
    'maxIterations',10000,'maxSeconds',3600,'grid',common.protocol.grid, ...
    'prefixAssessmentEvaluationAttempts',prefixAssessment.physicalEvaluationAttempts, ...
    'frozenAt',char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyy-MM-dd HH:mm:ss XXX')), ...
    'originalDifferenceStepMM',originalSqp.stage.info.differenceStepMM,'originalSqpActualCalls',originalSqp.stage.actualEvaluations, ...
    'originalSqpIterations',originalSqp.stage.info.iterations,'originalSqpReason',originalSqp.stage.info.reason, ...
    'originalSqpOutput',originalSqp.stage.info.solverOutput, ...
    'semantics','Two independent diagnostics from one unchanged saved 50000-call prefix. Each gets 150000 new calls; do not add the two runs into a single relay arm.');
camdesign.projectJSON('write',fullfile(base,'prefix_project.json'),prefix);
camdesign.saveProject(prefix,fullfile(base,'prefix_project.mat'));
save(file,'prefix','initial','prefixAssessment','initialAssessment','protocol','-v7');
record=struct('protocol',protocol,'prefixAssessment',prefixAssessment); writeJSON(fullfile(base,'prefix_protocol.json'),record);
fprintf('RELAY_SQP_SUPPLEMENT_PREPARED prefixCalls=%d originalSQP=%d calls/%d iter reason=%s\n', ...
    prefixCalls,originalSqp.stage.actualEvaluations,originalSqp.stage.info.iterations,originalSqp.stage.info.reason);
end
function assertLocked(initial,candidate)
assert(isequaln(rmfield(initial,'nodes'),rmfield(candidate,'nodes')) && isequal(initial.nodes(1,:),candidate.nodes(1,:)),'cam:RelayMutation','完整输入或起点改变。');
end
function hash=fileSHA256(file)
fid=fopen(file,'rb'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
function releaseLock(file), if isfile(file), delete(file); end, end
