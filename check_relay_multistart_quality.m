function record=check_relay_multistart_quality(action,arm)
% Owned unified experiment. No unbudgeted evaluate calls in search callbacks.
if nargin<1, action='prepare'; end
if nargin<2, arm='four'; end
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
base=fullfile(root,'outputs','relay_multistart_20261031'); if ~isfolder(base), mkdir(base); end
smoke=startsWith(action,'smoke-'); revised=startsWith(action,'revised-');
if smoke, base=fullfile(base,'smoke'); if ~isfolder(base), mkdir(base); end; action=extractAfter(action,'smoke-'); end
if revised, base=fullfile(base,'revised'); if ~isfolder(base), mkdir(base); end; action=extractAfter(action,'revised-'); end
if strcmp(action,'prepare'), record=prepare(root,base,smoke,revised); return; end
assert(strcmp(action,'run') && ismember(arm,{'four','relay','multistart'}),'cam:RelayExperiment','未知实验动作/组。');
assert(~revised || ~strcmp(arm,'four'),'cam:RelayBaselineReused','修订组复用已完成且依赖/配置不变的四方向基线，不重复运行。');
assert(isfile(fullfile(base,'common_initial.mat')),'cam:RelayPrepare','先执行prepare并冻结源码。');
saved=load(fullfile(base,'common_initial.mat')); project=saved.project; protocol=saved.protocol;
assert(isequaln(camdesign.projectJSON('read',fullfile(base,'common_initial.json')),project));
for k=1:numel(protocol.sourceManifest)
    item=protocol.sourceManifest(k); assert(strcmp(fileSHA256(fullfile(root,item.relativePath)),item.sha256),'cam:RelaySourceChanged','冻结后源码变化：%s',item.relativePath);
end
folder=fullfile(base,arm); if ~isfolder(folder), mkdir(folder); end
resultPath=fullfile(folder,'solver_result.mat'); assert(~isfile(resultPath),'cam:EvidenceExists','已有实验结果，拒绝覆盖。');
lockPath=fullfile(folder,'run.lock'); lock=java.io.File(lockPath); assert(lock.createNewFile(),'cam:ExperimentRunning','实验目录已有运行锁。');
lockCleanup=onCleanup(@()releaseLock(lockPath)); assert(~isfile(resultPath),'cam:EvidenceExists','取得锁后发现已有结果。');
fid=fopen(lockPath,'w'); fprintf(fid,'pid=%d\narm=%s\nstarted=%s\n',feature('getpid'),arm,char(datetime('now'))); fclose(fid);
protocol.arm=arm; writeJSON(fullfile(folder,'protocol.json'),protocol);
lastEval=-Inf; lastPhase=''; lastStart=-1; checkpoints=0;
options=struct('MaxPhysicalEvaluations',protocol.physicalBudget,'MaxIterations',protocol.maxIterationsPerStage,'FinalAssessment',false);
if strcmp(arm,'four')
    options.Budget=camdesign.PhysicalEvaluationBudget(protocol.physicalBudget,protocol.maxSecondsPerArm);
    algorithm='feasibility-four-direction-v1';
else
    algorithm='relay-sqp-v1'; if strcmp(arm,'multistart'), algorithm='multistart-relay-sqp-v1'; end
    options.Starts=protocol.starts; options.RandomSeed=protocol.randomSeed; options.PerturbationMM=protocol.perturbationMM;
    options.MaxSeconds=protocol.maxSecondsPerArm; options.FourFraction=protocol.fourFraction; options.DifferenceStepMM=protocol.sqpDifferenceStepMM;
    options.StageCompleteFcn=@persistStage; options.StartFcn=@persistStart;
end
[proposed,h,info]=camdesign.optimize(project,@progress,algorithm,options);
assertLocked(project,proposed); save(resultPath,'project','proposed','h','info','protocol','-v7');
camdesign.saveProject(proposed,fullfile(folder,'proposed_project.mat'));
proposedAssessment=camdesign.autoTuneAssessment(proposed,protocol.grid); validationCalls=proposedAssessment.physicalEvaluationAttempts;
writeJSON(fullfile(folder,'proposed_assessment.json'),proposedAssessment);
q=proposed; selectedAssessment=proposedAssessment; reverted=false;
if ~proposedAssessment.verifiedFeasible
    assert(saved.initialAssessment.verifiedFeasible,'cam:RelayFallback','共同初值不是已验证方案。');
    q=project; selectedAssessment=saved.initialAssessment; reverted=true;
end
camdesign.saveProject(q,fullfile(folder,'candidate_project.mat'));
    function persistStage(stage)
        assertLocked(project,stage.candidate);
        stageFolder=fullfile(folder,'stages',sprintf('start_%02d_%s',stage.start,stage.phase)); mkdir(stageFolder);
        assert(~isfile(fullfile(stageFolder,'stage_result.mat')),'cam:EvidenceExists','阶段结果已存在，拒绝覆盖。');
        camdesign.saveProject(stage.candidate,fullfile(stageFolder,'candidate_project.mat')); save(fullfile(stageFolder,'stage_result.mat'),'stage','-v7');
        writeJSON(fullfile(stageFolder,'summary.json'),struct('start',stage.start,'phase',stage.phase,'allocation',stage.allocatedEvaluations, ...
            'actualEvaluations',stage.actualEvaluations,'reason',stage.info.reason,'iterations',stage.info.iterations,'nativeMetrics',stage.info.finalMetrics, ...
            'nativeFeasible',stage.info.trainingFeasible));
    end
    function persistStart(index,seedRecord)
        assertLocked(project,seedRecord.project); startFolder=fullfile(folder,'starts',sprintf('start_%02d',index)); mkdir(startFolder);
        assert(~isfile(fullfile(startFolder,'initial.mat')),'cam:EvidenceExists','启动初值已存在，拒绝覆盖。');
        save(fullfile(startFolder,'initial.mat'),'seedRecord','-v7');
        camdesign.saveProject(seedRecord.project,fullfile(startFolder,'initial_project.mat'));
    end
tail=h(max(1,end-50):end); baseline=saved.initialAssessment.eight.refinedGrid.metrics;
proposedFine=proposedAssessment.eight.refinedGrid.metrics; selectedFine=selectedAssessment.eight.refinedGrid.metrics;
record=struct('protocol',protocol,'algorithm',algorithm,'reason',info.reason,'iterations',info.iterations, ...
    'requestedPhysicalEvaluations',protocol.physicalBudget,'actualPhysicalEvaluations',info.physicalEvaluations, ...
    'physicalBudget',info.physicalBudget,'seconds',info.elapsedSeconds,'independentAssessmentEvaluations',validationCalls, ...
    'nativeMetrics',info.finalMetrics,'proposedAssessment',proposedAssessment,'selectedAssessment',selectedAssessment, ...
    'revertedToVerifiedInitial',reverted,'parametersUnchanged',true,'completeNonNodeInputUnchanged',true, ...
    'tailQuality',[tail(1).qualityObjective tail(end).qualityObjective], ...
    'tailMetrics',{{tail(1).metrics,tail(end).metrics}},'proposedComparison',comparison(baseline,proposedFine), ...
    'selectedComparison',comparison(baseline,selectedFine),'checkpointCount',checkpoints, ...
    'scope','Same complete already-qualified input, same native/4x/8x model and objective. Search physical calls include invalid attempts/full acceptance checks. Common preparation and independent assessment calls are separate. Native score is not a Pareto or contest result.');
if isfield(info,'stages')
    record.stages=arrayfun(@(s)struct('start',s.start,'phase',s.phase,'allocated',s.allocatedEvaluations,'used',s.actualEvaluations, ...
        'iterations',s.info.iterations,'reason',s.info.reason,'nativeMetrics',s.info.finalMetrics),info.stages);
    record.starts=info.starts;
end
save(fullfile(folder,'result.mat'),'record','q','proposed','h','info','protocol','-v7'); writeJSON(fullfile(folder,'verification.json'),record);
fprintf('RELAY_QUALITY_DONE arm=%s calls=%d/%d iterations=%d reason=%s proposedFine=%d fallback=%d front=%.9g hit=%.9g pressure=%.9g\n', ...
    arm,info.physicalEvaluations,protocol.physicalBudget,info.iterations,info.reason,proposedAssessment.verifiedFeasible,reverted, ...
    selectedFine.routeLength,selectedFine.maxHitError,selectedFine.maxPressureDeg);
    function stop=progress(iter,candidate,history)
        stop=false; last=history(end); phase='four'; start=1; evals=last.evaluations;
        if isfield(last,'relayStage'), phase=last.relayStage; start=last.relayStart; evals=last.physicalEvaluations; end
        if evals-lastEval>=1500 || ~strcmp(phase,lastPhase) || start~=lastStart || strcmp(last.event,'finished')
            assertLocked(project,candidate); if isfield(last,'displayResult'), last=rmfield(last,'displayResult'); end
            qCheckpoint=candidate; exploration=candidate;
            if isfield(last,'explorationNodes'), exploration.nodes=last.explorationNodes; end
            save(fullfile(folder,'checkpoint.mat'),'qCheckpoint','exploration','last','-v7');
            checkpoints=checkpoints+1; lastEval=evals; lastPhase=phase; lastStart=start;
            phaseFolder=fullfile(folder,'checkpoints',sprintf('start_%02d_%s',start,phase)); if ~isfolder(phaseFolder), mkdir(phaseFolder); end
            save(fullfile(phaseFolder,'latest.mat'),'qCheckpoint','exploration','last','-v7');
            m=last.metrics; writeJSON(fullfile(folder,'progress.json'),struct('iteration',iter,'phase',phase,'start',start, ...
                'physicalEvaluations',evals,'metrics',m,'quality',last.qualityObjective));
            fprintf('RELAY_PROGRESS arm=%s phase=%s start=%d iter=%d calls=%d hit=%.8g pressure=%.8g front=%.9g quality=%.10g\n', ...
                arm,phase,start,iter,evals,m.maxHitError,m.maxPressureDeg,m.routeLength,last.qualityObjective);
        end
    end
end
function record=prepare(root,base,smoke,revised)
initialFile=fullfile(base,'common_initial.mat'); assert(~isfile(initialFile),'cam:EvidenceExists','共同初值已冻结，拒绝覆盖。');
lockPath=fullfile(base,'prepare.lock'); lock=java.io.File(lockPath); assert(lock.createNewFile(),'cam:ExperimentRunning','准备过程已有运行锁。');
cleanup=onCleanup(@()releaseLock(lockPath)); assert(~isfile(initialFile),'cam:EvidenceExists','共同初值已存在。');
source=fullfile(root,'outputs','feasibility_four_20261031','feasibility','continuation_v3_1','candidate_project.mat');
if isfile(source), project=camdesign.importProject(source);
else, source=fullfile(root,'data','relay_multistart_initial_20261031.json'); project=camdesign.projectJSON('read',source); end
assert(size(project.nodes,1)==34 && strcmp(camdesign.routeModel(project.params),'bezier-blend-independent-v1') ...
    && project.params.bezier.degree==5 && project.params.gearRatio==35 && project.params.samples==601 && project.params.camSamples==721);
camdesign.projectJSON('write',fullfile(base,'common_initial.json'),project);
initialResult=camdesign.evaluate(project,true); initialAssessment=camdesign.autoTuneAssessment(project,[601 721]); assert(initialAssessment.verifiedFeasible);
files=dir(fullfile(root,'+camdesign','*.m')); relative=arrayfun(@(f)fullfile('+camdesign',f.name),files,'UniformOutput',false); relative=relative(:)';
relative=[relative,{'CamReplicaApp.m','check_relay_multistart.m','check_relay_multistart_ui.m','check_relay_multistart_quality.m'}];
sourceFolder=fullfile(base,'source_snapshot'); if ~isfolder(sourceFolder), mkdir(sourceFolder); end
manifest=struct('relativePath',{},'sha256',{});
for k=1:numel(relative)
    path=fullfile(root,relative{k}); target=fullfile(sourceFolder,relative{k}); if ~isfolder(fileparts(target)), mkdir(fileparts(target)); end
    copyfile(path,target); manifest(k)=struct('relativePath',relative{k},'sha256',fileSHA256(path));
end
protocol=struct('baseline','58f73fd','sourceProject',source,'sourceProjectSHA256',fileSHA256(source), ...
    'commonProjectJSONSHA256',fileSHA256(fullfile(base,'common_initial.json')),'sourceManifest',manifest, ...
    'grid',[601 721],'controlCount',34,'degree',5,'ratio',35,'physicalBudget',200000,'maxIterationsPerStage',10000, ...
    'maxSecondsPerArm',3600,'starts',5,'randomSeed',20261031,'perturbationMM',8,'fourFraction',.25,'sqpDifferenceStepMM',.05, ...
    'objective','feasibilityFourState unchanged length + small hit-error + pressure-margin quality; exact native physical gates unchanged', ...
    'allocation','One shared arm budget; initial full call included. Each remaining start receives remaining / remainingStarts; four uses 25%, SQP receives its remaining share. Local stopping leaves unused allowance for subsequent starts.', ...
    'commonPreparationEvaluationAttempts',1+initialAssessment.physicalEvaluationAttempts, ...
    'scope','Continuation from the complete already-verified CHG-014 final project. No model/order/degree/hardware/threshold/weight/initial-point change. Not search from arbitrary infeasible seeds.');
protocol.frozenAt=char(datetime('now','TimeZone','Asia/Shanghai','Format','yyyy-MM-dd HH:mm:ss XXX'));
protocol.experimentKind='main-quality-comparison';
if smoke
    protocol.physicalBudget=700; protocol.maxIterationsPerStage=2; protocol.starts=2;
    protocol.experimentKind='pipeline-smoke-only-not-quality';
end
if revised
    main=fileparts(base); previous=load(fullfile(main,'common_initial.mat'),'project','protocol');
    assert(isequaln(project,previous.project),'cam:RelayMutation','修订对照须使用完全相同的共同初值。');
    unchanged=struct('relativePath',{},'primarySHA256',{},'currentSHA256',{},'unchanged',{});
    excluded={fullfile('+camdesign','optimizeRelay.m'),fullfile('+camdesign','optimizeQualitySqp.m')};
    for k=1:numel(previous.protocol.sourceManifest)
        item=previous.protocol.sourceManifest(k);
        if ~startsWith(item.relativePath,'+camdesign') || ismember(item.relativePath,excluded), continue; end
        currentHash=fileSHA256(fullfile(root,item.relativePath));
        assert(strcmp(currentHash,item.sha256),'cam:FourBaselineChanged','四方向物理依赖改变，不能复用原基线。');
        unchanged(end+1)=struct('relativePath',item.relativePath,'primarySHA256',item.sha256,'currentSHA256',currentHash,'unchanged',true);
    end
    config={'grid','controlCount','degree','ratio','physicalBudget','maxIterationsPerStage','maxSecondsPerArm'};
    for k=1:numel(config), assert(isequaln(protocol.(config{k}),previous.protocol.(config{k}))); end
    protocol.sqpDifferenceStepMM=.0005; protocol.experimentKind='revised-fine-difference-comparison';
    protocol.reusedFourArm=fullfile(main,'four');
    protocol.reusedFourResultSHA256=fileSHA256(fullfile(main,'four','verification.json'));
    protocol.reusedFourCandidateSHA256=fileSHA256(fullfile(main,'four','candidate_project.mat'));
    protocol.reusedFourProtocolSHA256=fileSHA256(fullfile(main,'four','protocol.json'));
    protocol.reusedFourUnchangedDependencies=unchanged;
    protocol.reusedFourSemantics='Original completed 200000-call four-direction arm reused. Complete initial project/configuration and all +camdesign dependencies except the two unused relay/SQP backends have matching hashes. No additional four-direction run.';
end
save(initialFile,'project','initialResult','initialAssessment','protocol','-v7');
writeJSON(fullfile(base,'source_manifest.json'),struct('frozenAt',protocol.frozenAt,'files',manifest));
record=struct('protocol',protocol,'initialMetrics',initialResult.metrics,'initialAssessment',initialAssessment);
writeJSON(fullfile(base,'common_protocol.json'),record); fprintf('RELAY_QUALITY_PREPARED sourceSHA=%s\n',protocol.sourceProjectSHA256);
end
function assertLocked(initial,candidate)
assert(isequaln(rmfield(initial,'nodes'),rmfield(candidate,'nodes')) && isequal(candidate.nodes(1,:),initial.nodes(1,:)), ...
    'cam:RelayMutation','完整非nodes输入或固定起点被修改。');
end
function value=comparison(before,after)
value=struct('valid',~isempty(after)); if isempty(after), return; end
names={'routeLength','driveLength','maxHitError','rmsHitError','maxPressureDeg','maxWorkPressureDeg','maxReturnPressureDeg'};
for k=1:numel(names), value.(names{k})=after.(names{k})-before.(names{k}); end
vector=[value.routeLength value.maxHitError value.maxPressureDeg];
value.paretoImprovesLengthHitPressure=all(vector<=1e-9) && any(vector< -1e-9);
value.semantics='Signed changes: negative is smaller. Pareto flag uses front length, max hit and whole-cycle max pressure only; quality ranking is separate.';
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
