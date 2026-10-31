function report=check_feasibility_actual_review(label,stage)
% Parent review: immutable hardware and actual-outline driven closure.
if nargin<2, stage='primary'; end
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent MATLAB batch.');
assert(ismember(label,{'legacy','feasibility'}));
base=fullfile('outputs','feasibility_four_20261031');
initial=load(fullfile(base,'common_initial.mat'),'project');
saved=load(fullfile(base,label,stage,'solver_result.mat'),'q'); q=saved.q;
assert(isequaln(initial.project.params,q.params) && isequaln(initial.project.targets,q.targets));
assert(isequal(initial.project.nodes(1,:),q.nodes(1,:)) && q.params.gearRatio==35);
folder=fullfile(base,'independent_review',[label '_' stage]);
assert(~isfile(fullfile(folder,'verification.json')),'cam:EvidenceExists','Preserve earlier review.');
if ~isfolder(folder), mkdir(folder); end
fine=q; fine.params.samples=8*(q.params.samples-1)+1;
fine.params.camSamples=8*(q.params.camSamples-1)+1;
result=camdesign.evaluate(fine,true);
% A phase/length identity independently recomputed from fixed hardware.
expectedReturn=360-360*result.metrics.driveLength/(pi*q.params.wheelDiameter*q.params.gearRatio);
assert(abs(expectedReturn-result.metrics.actualReturnDeg)<1e-10);
before=result.cam.actual;
[closure,simulation]=camdesign.verifyActualClosure(fine,result,Samples=1201);
assert(isequaln(before,result.cam.actual));
save(fullfile(folder,'actual_closure.mat'),'q','fine','result','closure','simulation');
% Keep the exact reviewed sampling density available for normal UI import.
camdesign.saveProject(fine,fullfile(folder,'review_grid_project.mat'));
fields={'valid','passed','contactValid','closurePassed','integrationConverged','geometryFeasible', ...
    'maxSensorDeviationMM','rmsSensorDeviationMM','maxFrontDeviationMM','maxSteeringDeviationDeg', ...
    'integrationMaxSensorDifferenceMM','integrationMaxFrontDifferenceMM','maxContactResidualMM', ...
    'maxPenetrationMM','maxHitErrorMM','maxPressureDeg','maxWorkPressureDeg','maxSteeringDeg', ...
    'actualReturnDeg','visitOrderSatisfied','trajectoryBoundsSatisfied','maxTrajectoryOutsideMM', ...
    'integrationSamples','outlineVertexCount','outlineUnchanged','physicalGearRatio', ...
    'errorIdentifier','errorMessage','scope'};
compact=struct(); for k=1:numel(fields), compact.(fields{k})=closure.(fields{k}); end
report=struct('release',version('-release'),'label',label,'stage',stage, ...
    'inputLocksPassed',true,'designGrid',[fine.params.samples fine.params.camSamples], ...
    'designMetrics',result.metrics,'returnAngleIdentityErrorDeg',abs(expectedReturn-result.metrics.actualReturnDeg), ...
    'actualClosure',compact,'scope','Fixed 8x actual contour, 1201/2401 contact-driven integration. Not measured vehicle accuracy or proof of optimization superiority.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FEASIBILITY_ACTUAL_REVIEW %s %s locks=1 contact=%d closure=%d passed=%d error=%.8g integration=%.8g %s\n', ...
    label,stage,closure.contactValid,closure.closurePassed,closure.passed,closure.maxSensorDeviationMM, ...
    closure.integrationMaxSensorDifferenceMM,closure.errorIdentifier);
end
