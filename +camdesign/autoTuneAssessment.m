function assessment=autoTuneAssessment(project,grid)
% Numerical stability AND unchanged physical gates. No softened limits.
if nargin<2, grid=[601 721]; end
common=project; common.params.samples=grid(1); common.params.camSamples=grid(2);
four=camdesign.verifyConstrained(common,4);
eight=camdesign.verifyConstrained(common,8);
native=camdesign.verifyConstrained(project,2);
tolerance=struct('pressureDeg',.25,'hitMM',.5,'steeringDeg',.1,'returnDeg',.05,'lengthMM',2);
delta=struct('pressureDeg',Inf,'hitMM',Inf,'steeringDeg',Inf,'returnDeg',Inf,'lengthMM',Inf);
if four.refinedGrid.valid && eight.refinedGrid.valid
    a=four.refinedGrid.metrics; b=eight.refinedGrid.metrics;
    delta.pressureDeg=abs(a.maxPressureDeg-b.maxPressureDeg);
    delta.hitMM=abs(a.maxHitError-b.maxHitError);
    delta.steeringDeg=abs(a.maxSteeringDeg-b.maxSteeringDeg);
    delta.returnDeg=abs(four.refinedGrid.workEndDeg-eight.refinedGrid.workEndDeg);
    delta.lengthMM=abs(a.routeLength-b.routeLength);
end
numerical=camdesign.autoTuneNumericalChecks(project,grid);
stable=all(struct2array(delta)<=struct2array(tolerance)) && numerical.passed;
assessment=struct('four',four,'eight',eight,'native',native,'delta',delta,'tolerance',tolerance, ...
    'numericalChecks',numerical,'physicalEvaluationAttempts',6+numerical.physicalEvaluationAttempts, ...
    'convergencePassed',stable,'verifiedFeasible',stable && four.verifiedFeasible && eight.verifiedFeasible && native.verifiedFeasible, ...
    'scope','Discrete model on native, 4x and 8x common grids; not original-software or real-car accuracy.');
end
