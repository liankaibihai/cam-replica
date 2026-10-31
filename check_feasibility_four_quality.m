function record=check_feasibility_four_quality(action,algorithm,stage)
% Paired fixed seed; actual long runs, no model/hardware/weight search.
if nargin<1, action='prepare'; end
if nargin<2, algorithm='video-four-direction-v1'; end
if nargin<3, stage='primary'; end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
root=fileparts(mfilename('fullpath')); base=fullfile(root,'outputs','feasibility_four_20261031');
if ~isfolder(base), mkdir(base); end
initialFile=fullfile(base,'common_initial.mat');
if ~isfile(initialFile)
    team=camdesign.teamSolarProject();
    changes=struct('routeModel','bezier-blend-independent-v1','controlPointCount',34,'bezierDegree',5, ...
        'interpolationPerSegment',20,'iterations',600,'gradientForce',.5,'learningRate',1, ...
        'smoothingRate',.1,'adjustInterval',50,'adjustExponent',0);
    [project,initialization]=camdesign.rebuildRoute(team,changes,'video-four-direction-v1');
    project.params.samples=601; project.params.camSamples=721;
    initialResult=camdesign.evaluate(project,true);
    protocol=struct('baseline','dada6c638590ec7013e1d36050e1c25cd9c48f63', ...
        'initialization','New target-seeded 34-control degree5 independent Bezier route; explicit reshape, never old-curve preservation.', ...
        'teamFactory','camdesign.teamSolarProject','controlCount',34,'degree',5,'trainingGrid',[601 721], ...
        'iterationsPerStage',600,'gearRatio',35,'weights',project.params.weights, ...
        'scope','Fixed team design values, unmeasured physical car and body footprint. Same initial project for both primary runs; no global optimality claim.');
    save(initialFile,'project','initialization','initialResult','protocol');
    writeJSON(fullfile(base,'common_initial.json'),struct('protocol',protocol,'initialMetrics',initialResult.metrics,'initialization',initialization));
end
saved=load(initialFile); project=saved.project; protocol=saved.protocol;
if strcmp(action,'prepare'), record=struct('protocol',protocol,'metrics',saved.initialResult.metrics); return; end
assert(strcmp(action,'run') && ismember(algorithm,{'video-four-direction-v1','feasibility-four-direction-v1'}));
label='legacy'; if strcmp(algorithm,'feasibility-four-direction-v1'), label='feasibility'; end
folder=fullfile(base,label,stage); if ~isfolder(folder), mkdir(folder); end
assert(~isfile(fullfile(folder,'solver_result.mat')),'cam:EvidenceExists','已有实验结果，拒绝覆盖。');
lockPath=fullfile(folder,'run.lock'); lockFile=java.io.File(lockPath);
assert(lockFile.createNewFile(),'cam:ExperimentRunning','实验目录已有独占运行锁；请核对所有者，不能并发写入同一结果。');
lockCleanup=onCleanup(@()releaseLock(lockPath));
assert(~isfile(fullfile(folder,'solver_result.mat')),'cam:EvidenceExists','取得锁后发现已有结果，拒绝覆盖。');
fid=fopen(lockPath,'w'); assert(fid>=0); fprintf(fid,'pid=%d\nalgorithm=%s\nstage=%s\nstarted=%s\n',feature('getpid'),algorithm,stage,char(datetime('now'))); fclose(fid);
if ~startsWith(stage,'primary')
    prior='primary';
    if strcmp(stage,'continuation_2'), prior='continuation_1'; end
    if strcmp(stage,'continuation_v2_1'), prior='primary_v2'; end
    if strcmp(stage,'continuation_v2_2'), prior='continuation_v2_1'; end
    if strcmp(stage,'continuation_v3_1'), prior='primary_v3'; end
    if strcmp(stage,'continuation_v3_2'), prior='continuation_v3_1'; end
    source=load(fullfile(base,label,prior,'solver_result.mat'),'q'); project=source.q;
end
original=project; initial=camdesign.evaluate(project,true); protocol.algorithm=algorithm; protocol.stage=stage;
protocol.sourceAlgorithmPath=which('camdesign.optimizeSearch'); protocol.actualRequestedIterations=project.params.iterations;
if strcmp(algorithm,'feasibility-four-direction-v1'), protocol.sourceAlgorithmPath=which('camdesign.optimizeFeasibilityFour'); end
protocol.sourceAlgorithmSHA256=fileSHA256(protocol.sourceAlgorithmPath);
protocol.dispatcherPath=which('camdesign.optimize'); protocol.dispatcherSHA256=fileSHA256(protocol.dispatcherPath);
sourceFolder=fullfile(folder,'source'); if ~isfolder(sourceFolder), mkdir(sourceFolder); end
functions={'camdesign.optimize','camdesign.optimizeSearch'};
if strcmp(algorithm,'feasibility-four-direction-v1'), functions={'camdesign.optimize','camdesign.optimizeFeasibilityFour','camdesign.feasibilityFourState','camdesign.feasibilityFourBetter','camdesign.pressurePreferenceProbe'}; end
sourceManifest=struct([]);
for index=1:numel(functions)
    path=which(functions{index}); [~,name,ext]=fileparts(path); copyfile(path,fullfile(sourceFolder,[name ext]));
    entry=struct('function',functions{index},'path',path,'sha256',fileSHA256(path));
    if index==1, sourceManifest=entry; else, sourceManifest(index)=entry; end
end
protocol.sourceManifest=sourceManifest;
save(fullfile(folder,'initial.mat'),'project','initial','protocol');
lastLogged=-1; lastPhase='';
[q,h,info]=camdesign.optimize(project,@progress,algorithm);
assert(isequaln(q.params,original.params) && isequaln(q.targets,original.targets) && isequal(q.nodes(1,:),original.nodes(1,:)));
save(fullfile(folder,'solver_result.mat'),'project','q','h','info','protocol');
camdesign.saveProject(q,fullfile(folder,'candidate_project.mat'));
native=camdesign.evaluate(q,true); assessment=camdesign.autoTuneAssessment(q,[601 721]);
count=min(51,numel(h)); tail=h(end-count+1:end);
tailRank=[]; if isfield(h,'violationSquared'), tailRank=[tail(1).violationSquared tail(end).violationSquared]; end
record=struct('protocol',protocol,'requestedIterations',project.params.iterations,'actualIterations',info.iterations, ...
    'reason',info.reason,'evaluations',info.evaluations,'seconds',info.elapsedSeconds, ...
    'initialMetrics',initial.metrics,'nativeMetrics',native.metrics,'nativeTrajectory',native.trajectoryBounds, ...
    'nativeControlBounds',native.controlBounds,'nativeVisitOrder',native.visitOrder, ...
    'assessment',assessment,'tailReferenceScore',[tail(1).score tail(end).score],'tailViolationSquared',tailRank, ...
    'parametersUnchanged',isequaln(q.params,original.params),'modelAndDegreeUnchanged',true);
save(fullfile(folder,'result.mat'),'record','q','h','info','protocol'); writeJSON(fullfile(folder,'verification.json'),record);
fprintf('FOUR_QUALITY_DONE %s %s iter=%d/%d eval=%d reason=%s front=%.6g drive=%.6g hit=%.6g pressure=%.6g/%.6g return=%.6g fineFeasible=%d\n', ...
    label,stage,info.iterations,project.params.iterations,info.evaluations,info.reason,native.metrics.routeLength,native.metrics.driveLength, ...
    native.metrics.maxHitError,native.metrics.maxWorkPressureDeg,native.metrics.maxReturnPressureDeg,native.metrics.actualReturnDeg,assessment.verifiedFeasible);
    function stop=progress(iter,candidate,history)
        stop=false; last=history(end); phase='weighted-score';
        if isfield(last,'feasibilityStage'), phase=last.feasibilityStage; end
        phaseChanged=~strcmp(phase,lastPhase);
        if (mod(iter,25)==0 && iter~=lastLogged) || phaseChanged || strcmp(last.event,'finished')
            m=last.metrics; fprintf('FOUR_PROGRESS %s %s iter=%d eval=%d phase=%s hit=%.6g pressure=%.6g/%.6g return=%.6g front=%.6g\n', ...
                label,stage,iter,last.evaluations,phase,m.maxHitError,m.maxWorkPressureDeg,m.maxReturnPressureDeg,m.actualReturnDeg,m.routeLength);
            qCheckpoint=candidate; save(fullfile(folder,'checkpoint.mat'),'qCheckpoint','last');
            if phaseChanged, save(fullfile(folder,['phase_' phase '.mat']),'candidate','last'); end
            writeJSON(fullfile(folder,'progress.json'),struct('iteration',iter,'phase',phase,'evaluations',last.evaluations,'metrics',m));
            lastLogged=iter; lastPhase=phase;
        end
    end
end
function hash=fileSHA256(file)
fid=fopen(file,'rb'); assert(fid>=0); closer=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
function releaseLock(file)
if isfile(file), delete(file); end
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
