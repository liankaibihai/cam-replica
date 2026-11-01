function [report,simulation]=verifyActualClosure(project,result,options)
% Freeze ONE actual polygon; refine only the direct-contact RK4 phase grid.
% Design front/sensor references do not provide the recovered motion law.
arguments
    project struct
    result struct
    options.Samples (1,1) double {mustBeReal}=NaN
    options.ClosureToleranceMM (1,1) double {mustBeFinite,mustBePositive}=2
    options.IntegrationToleranceMM (1,1) double {mustBeFinite,mustBePositive}=.05
    options.ContactToleranceMM (1,1) double {mustBeFinite,mustBePositive}=1e-7
    options.RotationConvention char='clockwise-cam-fixed-positive-x-v1'
end
p=project.params; simulation=[];
tolerances=struct('closureMM',options.ClosureToleranceMM,'integrationMM',options.IntegrationToleranceMM, ...
    'contactResidualMM',options.ContactToleranceMM,'maxPressureDeg',p.maxPressureDeg, ...
    'maxSteeringDeg',p.maxSteeringDeg,'maxHitErrorMM',p.hitTolerance,'minimumReturnDeg',p.returnAngleDeg, ...
    'source','Closure 2mm default follows existing theoretical inverse numerical check; integration 0.05mm and contact 1e-7mm are explicit internal numerical diagnostics, not measured vehicle/manufacturing tolerances. Physical gates use user input unchanged.');
report=struct('valid',false,'passed',false,'contactValid',false,'closurePassed',false,'integrationConverged',false, ...
    'geometryFeasible',false,'maxSensorDeviationMM',Inf,'rmsSensorDeviationMM',Inf,'maxFrontDeviationMM',Inf, ...
    'maxSteeringDeviationDeg',Inf,'integrationMaxSensorDifferenceMM',Inf,'integrationMaxFrontDifferenceMM',Inf, ...
    'maxContactResidualMM',Inf,'maxPenetrationMM',Inf,'maxHitErrorMM',Inf, ...
    'visitOrderSatisfied',false,'trajectoryBoundsSatisfied',false,'maxTrajectoryOutsideMM',Inf, ...
    'maxPressureDeg',Inf,'maxWorkPressureDeg',Inf,'maxSteeringDeg',Inf,'maxFullCycleSteeringDeg',Inf, ...
    'pressureSatisfied',false,'steeringSatisfied',false,'hitSatisfied',false,'returnAngleSatisfied',false, ...
    'actualReturnDeg',NaN,'phaseCoverageSatisfied',false,'designGateAvailable',false,'designGeometryFeasible',false, ...
    'designMinUndercutMargin',NaN,'designIntersectionCount',NaN,'tolerances',tolerances, ...
    'integrationSamples',[NaN NaN],'outlineVertexCount',NaN,'outlineUnchanged',true, ...
    'physicalGearRatio',p.gearRatio,'contact',[],'fullCycleContact',[],'hits',[],'visitOrder',[],'trajectoryBounds',[], ...
    'errorIdentifier','','errorMessage','','rotationConvention',options.RotationConvention, ...
    'scope','Frozen actual polygon, radial rigid disk and no-slip car. Full-cycle sampled contact pressure, working-phase car/steering gates; phase integration convergence does not certify outline discretization, continuous extrema, friction, machining or real-car accuracy.');
try
    camdesign.validateProject(project);
    assert(isfield(result,'cam') && isfield(result.cam,'actual'),'cam:ActualOutlineInvalid','结果缺少actual实际轮廓。');
    % Copy ONLY actual coordinates and explicit phase metadata. Forbidden
    % theoretical geometry fields never reach the actual-contact simulator.
    c=struct('actual',result.cam.actual);
    if isfield(result.cam,'workEnd'), c.workEnd=result.cam.workEnd;
    elseif isfield(result.cam,'workPhi'), c.workPhi=result.cam.workPhi;
    else, error('cam:ActualPhase','结果缺少显式工作相位。'); end
    count=options.Samples; if isnan(count), count=p.samples; end
    validateattributes(count,{'double'},{'scalar','integer','>=',2,'<=',20001});
    fineCount=2*(count-1)+1; report.integrationSamples=[count fineCount];
    reference=camdesign.route(project.nodes,p);
    coarse=camdesign.simulateActual(c,p,reference.front(1,:),deg2rad(p.headingDeg),Samples=count, ...
        ContactToleranceMM=options.ContactToleranceMM,RotationConvention=options.RotationConvention);
    simulation=camdesign.simulateActual(c,p,reference.front(1,:),deg2rad(p.headingDeg),Samples=fineCount, ...
        ContactToleranceMM=options.ContactToleranceMM,RotationConvention=options.RotationConvention);
    report.integrationMaxSensorDifferenceMM=max(vecnorm(coarse.sensor-simulation.sensor(1:2:end,:),2,2));
    report.integrationMaxFrontDifferenceMM=max(vecnorm(coarse.front-simulation.front(1:2:end,:),2,2));
    report.integrationConverged=max(report.integrationMaxSensorDifferenceMM,report.integrationMaxFrontDifferenceMM)<=options.IntegrationToleranceMM;
    designPhase=2*reference.driveDistance/(p.wheelDiameter*p.gearRatio);
    report.phaseCoverageSatisfied=abs(designPhase(1)-simulation.phase(1))<=1e-10 ...
        && abs(designPhase(end)-simulation.phase(end))<=1e-8;
    if report.phaseCoverageSatisfied
        query=max(designPhase(1),min(designPhase(end),simulation.phase));
        expectedSensor=interp1(designPhase,reference.sensor,query,'pchip');
        expectedFront=interp1(designPhase,reference.front,query,'pchip');
        expectedSteering=interp1(designPhase,reference.steering,query,'pchip');
        sensorError=vecnorm(simulation.sensor-expectedSensor,2,2);
        report.maxSensorDeviationMM=max(sensorError); report.rmsSensorDeviationMM=sqrt(mean(sensorError.^2));
        report.maxFrontDeviationMM=max(vecnorm(simulation.front-expectedFront,2,2));
        report.maxSteeringDeviationDeg=rad2deg(max(abs(simulation.steering-expectedSteering)));
    else
        report.errorMessage='实际轮廓工作相位与当前项目路线不匹配；未外推参考路线来制造闭环通过。';
    end
    % Include work endpoints/midpoints plus an independent full-cycle phase
    % grid. The physical pressure limit retains its existing whole-cam scope.
    fullPhase=unique([linspace(0,2*pi,fineCount)';simulation.contact.phase]);
    [fullRadius,fullContact]=camdesign.contactFromOutline(c.actual,p.rollerRadius,fullPhase, ...
        ContactToleranceMM=options.ContactToleranceMM,RotationConvention=options.RotationConvention);
    report.contact=simulation.contact; report.fullCycleContact=fullContact;
    report.contactValid=coarse.contact.valid && simulation.contact.valid && fullContact.valid;
    report.maxContactResidualMM=max([coarse.contact.maxContactResidualMM,simulation.contact.maxContactResidualMM,fullContact.maxContactResidualMM]);
    report.maxPenetrationMM=max([coarse.contact.maxPenetrationMM,simulation.contact.maxPenetrationMM,fullContact.maxPenetrationMM]);
    report.maxPressureDeg=fullContact.maxPressureDeg; report.maxWorkPressureDeg=simulation.maxPressureDeg;
    report.maxSteeringDeg=simulation.maxSteeringDeg;
    report.maxFullCycleSteeringDeg=rad2deg(max(abs(camdesign.steeringFromLift(fullRadius-p.referenceDiameter/2,p))));
    report.pressureSatisfied=report.maxPressureDeg<=p.maxPressureDeg;
    report.steeringSatisfied=report.maxSteeringDeg<=p.maxSteeringDeg;
    report.actualReturnDeg=rad2deg(2*pi-simulation.phase(end)); report.returnAngleSatisfied=report.actualReturnDeg>=p.returnAngleDeg;
    report.hits=camdesign.orderedHits(simulation.sensor,project.targets); report.maxHitErrorMM=max(report.hits.errors);
    report.hitSatisfied=report.maxHitErrorMM<=p.hitTolerance;
    report.visitOrder=camdesign.visitOrderAudit(simulation.sensor,project.targets,p.hitTolerance);
    report.visitOrderSatisfied=report.visitOrder.matchesRequiredOrderAndVisitCount;
    [~,report.trajectoryBounds]=camdesign.trajectoryBounds(simulation,p.bounds);
    report.trajectoryBoundsSatisfied=report.trajectoryBounds.satisfied;
    report.maxTrajectoryOutsideMM=report.trajectoryBounds.maximumOutsideMM;
    % Retain known design-gate failures as separately identified metadata.
    % These values never recover a contact radius or drive the integration.
    if isfield(result,'metrics') && all(isfield(result.metrics,{'geometryChecked','minUndercutMargin','intersectionCount', ...
            'maxPressureDeg','maxSteeringDeg','maxHitError','returnAngleSatisfied','visitOrderSatisfied'}))
        m=result.metrics; report.designGateAvailable=isequal(m.geometryChecked,true);
        report.designMinUndercutMargin=m.minUndercutMargin; report.designIntersectionCount=m.intersectionCount;
        [~,designBounds]=camdesign.trajectoryBounds(reference,p.bounds);
        report.designGeometryFeasible=report.designGateAvailable && m.minUndercutMargin>0 && m.intersectionCount==0 ...
            && m.maxPressureDeg<=p.maxPressureDeg && m.maxSteeringDeg<=p.maxSteeringDeg && m.maxHitError<=p.hitTolerance ...
            && m.returnAngleSatisfied && m.visitOrderSatisfied && designBounds.satisfied;
    end
    report.geometryFeasible=report.contactValid && report.pressureSatisfied && report.steeringSatisfied && report.hitSatisfied ...
        && report.returnAngleSatisfied && report.visitOrderSatisfied && report.trajectoryBoundsSatisfied ...
        && (~report.designGateAvailable || report.designGeometryFeasible);
    report.closurePassed=report.contactValid && report.phaseCoverageSatisfied && report.integrationConverged ...
        && max(report.maxFrontDeviationMM,report.maxSensorDeviationMM)<=options.ClosureToleranceMM;
    report.passed=report.closurePassed && report.geometryFeasible;
    report.outlineVertexCount=size(c.actual,1); report.valid=true;
catch ex
    expected={'cam:ActualOutlineInvalid','cam:ActualOutlineOpen','cam:ActualOutlineDegenerate', ...
        'cam:ActualOutlineSelfIntersection','cam:ActualOutlineOrigin','cam:ActualContactRadius', ...
        'cam:ActualRotationConvention','cam:ActualContactFailure','cam:ActualPhase','cam:ActualParameters', ...
        'cam:SimulationSteering','cam:InverseSingularity','cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel','cam:ExtremeSteering'};
    if ~ismember(ex.identifier,expected), rethrow(ex); end
    report.errorIdentifier=ex.identifier; report.errorMessage=ex.message;
end
end
