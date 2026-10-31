function report=check_relay_actual_review(label,candidateFile,referenceFile)
% Independent final review; never starts or resumes any optimization run.
arguments
    label char
    candidateFile char
    referenceFile char
end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use an independent MATLAB batch.');
assert(~isempty(regexp(label,'^[a-zA-Z0-9_-]+$','once')),'cam:ReviewLabel','Use a simple unique review label.');
reference=load(referenceFile,'project'); candidate=load(candidateFile,'project');
assert(isfield(reference,'project') && isfield(candidate,'project'),'cam:ReviewProject','Standard saved project is required.');
initial=reference.project; q=candidate.project;
assert(isequaln(rmfield(initial,'nodes'),rmfield(q,'nodes')),'cam:ReviewLocks','A non-node input changed.');
assert(isequal(size(initial.nodes),size(q.nodes)) && isequal(initial.nodes(1,:),q.nodes(1,:)),'cam:ReviewLocks','Control count or fixed start changed.');
assert(q.params.gearRatio==35 && strcmp(q.params.mechanism,'flat'),'cam:ReviewTeam','Expected the confirmed flat-push team car, ratio 35.');
folder=fullfile('outputs','relay_multistart_20261031','independent_review',label);
if ~isfolder(folder), mkdir(folder); end
lock=java.io.File(fullfile(pwd,folder,'review.lock'));
assert(lock.createNewFile(),'cam:ReviewLocked','This review is already owned by another process.');
unlock=onCleanup(@()lock.delete());
assert(~isfile(fullfile(folder,'verification.json')) && ~isfile(fullfile(folder,'actual_closure.mat')), ...
    'cam:EvidenceExists','Preserve earlier review results.');
assessment=camdesign.autoTuneAssessment(q,[q.params.samples q.params.camSamples]);
fine=q; fine.params.samples=8*(q.params.samples-1)+1;
fine.params.camSamples=8*(q.params.camSamples-1)+1;
assert(max([fine.params.samples fine.params.camSamples])<=20001,'cam:ReviewGrid','Independent 8x grid exceeds model limit.');
result=camdesign.evaluate(fine,true);
referenceFine=initial; referenceFine.params.samples=fine.params.samples;
referenceFine.params.camSamples=fine.params.camSamples;
referenceResult=camdesign.evaluate(referenceFine,true);
expectedReturn=360-360*result.metrics.driveLength/(pi*q.params.wheelDiameter*q.params.gearRatio);
assert(abs(expectedReturn-result.metrics.actualReturnDeg)<1e-10,'cam:ReviewPhase','Fixed-ratio phase/length identity failed.');
outlineBefore=result.cam.actual;
[closure,simulation]=camdesign.verifyActualClosure(fine,result,Samples=1201);
assert(isequaln(outlineBefore,result.cam.actual),'cam:ReviewOutline','The contact check changed its input outline.');
save(fullfile(folder,'actual_closure.mat'),'initial','q','fine','result','assessment','closure','simulation','referenceResult');
camdesign.saveProject(fine,fullfile(folder,'review_grid_project.mat'));
restored=camdesign.importProject(fullfile(folder,'review_grid_project.mat'));
assert(isequaln(restored,fine),'cam:ReviewRoundtrip','The reviewed project did not round-trip exactly.');
metrics={'routeLength','driveLength','maxHitError','rmsHitError','maxPressureDeg','maxWorkPressureDeg','maxReturnPressureDeg'};
delta=struct(); for k=1:numel(metrics), name=metrics{k}; delta.(name)=result.metrics.(name)-referenceResult.metrics.(name); end
keys={'valid','passed','contactValid','closurePassed','integrationConverged','geometryFeasible', ...
    'maxSensorDeviationMM','rmsSensorDeviationMM','maxFrontDeviationMM','maxSteeringDeviationDeg', ...
    'integrationMaxSensorDifferenceMM','integrationMaxFrontDifferenceMM','maxContactResidualMM','maxPenetrationMM', ...
    'maxHitErrorMM','maxPressureDeg','maxWorkPressureDeg','maxSteeringDeg','actualReturnDeg', ...
    'visitOrderSatisfied','trajectoryBoundsSatisfied','maxTrajectoryOutsideMM','integrationSamples', ...
    'outlineVertexCount','outlineUnchanged','physicalGearRatio','errorIdentifier','errorMessage','scope'};
compact=struct(); for k=1:numel(keys), compact.(keys{k})=closure.(keys{k}); end
report=struct('release',version('-release'),'label',label,'candidateFile',candidateFile,'referenceFile',referenceFile, ...
    'inputLocksPassed',true,'nativeGrid',[q.params.samples q.params.camSamples], ...
    'designGrid',[fine.params.samples fine.params.camSamples],'designMetrics',result.metrics, ...
    'referenceMetrics',referenceResult.metrics,'deltaFromCommonStart',delta, ...
    'nativeFeasible',assessment.native.verifiedFeasible,'fourFeasible',assessment.four.verifiedFeasible, ...
    'eightFeasible',assessment.eight.verifiedFeasible,'convergencePassed',assessment.convergencePassed, ...
    'verifiedFeasible',assessment.verifiedFeasible,'convergenceDelta',assessment.delta, ...
    'convergenceTolerance',assessment.tolerance,'actualClosure',compact, ...
    'returnIdentityErrorDeg',abs(expectedReturn-result.metrics.actualReturnDeg), ...
    'allThreeStrictlyImproved',all([delta.routeLength delta.maxHitError delta.maxPressureDeg]<0), ...
    'scope','Independent 8x design and frozen actual contour with 1201/2401 contact integration. Improvements are measured from the common feasible seed, not a physical car or original app.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('RELAY_ACTUAL_REVIEW %s dense=%d contact=%d closure=%d passed=%d L=%.9f hit=%.9f pressure=%.9f\n', ...
    label,assessment.verifiedFeasible,closure.contactValid,closure.closurePassed,closure.passed, ...
    result.metrics.routeLength,result.metrics.maxHitError,result.metrics.maxPressureDeg);
end
