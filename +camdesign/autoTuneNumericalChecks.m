function result=autoTuneNumericalChecks(project,grid)
% Compare actual envelope coordinates at common phases, plus an independent
% theoretical-cam inverse integration. Neither proves real contact accuracy.
if nargin<2, grid=[601 721]; end
result=struct('camMaxDifferenceMM',Inf,'inverseFrontMaxErrorMM',Inf, ...
    'camToleranceMM',.05,'inverseToleranceMM',2,'passed',false, ...
    'physicalEvaluationAttempts',0,'errorIdentifier','','errorMessage','', ...
    'scope','Actual discrete envelope convergence and theoretical cam RK4 closure; no contact/slip/manufacturing validation.');
try
    a=project; b=project;
    a.params.samples=min(20001,4*(grid(1)-1)+1); a.params.camSamples=min(20001,4*(grid(2)-1)+1);
    b.params.samples=min(20001,8*(grid(1)-1)+1); b.params.camSamples=min(20001,8*(grid(2)-1)+1);
    result.physicalEvaluationAttempts=result.physicalEvaluationAttempts+1; ra=camdesign.evaluate(a,false);
    result.physicalEvaluationAttempts=result.physicalEvaluationAttempts+1; rb=camdesign.evaluate(b,false);
    % The two grids are nested until the sample cap; interp1 also handles cap.
    matched=interp1(rb.cam.phi,rb.cam.actual,ra.cam.phi,'linear');
    result.camMaxDifferenceMM=max(vecnorm(ra.cam.actual-matched,2,2));
    inverse=camdesign.simulate(rb.cam,b.params,rb.route.front(1,:),rb.route.heading(1));
    result.inverseFrontMaxErrorMM=max(vecnorm(inverse.front-rb.route.front,2,2));
    result.passed=result.camMaxDifferenceMM<=result.camToleranceMM ...
        && result.inverseFrontMaxErrorMM<=result.inverseToleranceMM;
catch ex
    if ismember(ex.identifier,{'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel', ...
            'cam:ExtremeSteering','cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite', ...
            'cam:SimulationSteering','cam:InverseSingularity'})
        result.errorIdentifier=ex.identifier; result.errorMessage=ex.message;
    else, rethrow(ex); end
end
end
