function report=verifyConstrained(project,refinementFactor)
% Independent grid refinement and full discrete self-intersection checks.
if nargin<2, refinementFactor=4; end
validateattributes(refinementFactor,{'double'},{'scalar','integer','>=',2,'<=',8});
coarse=inspect(project); fine=project;
fine.params.samples=min(20001,refinementFactor*(project.params.samples-1)+1);
fine.params.camSamples=min(20001,refinementFactor*(project.params.camSamples-1)+1);
refined=inspect(fine);
independent=fine.params.samples>project.params.samples && fine.params.camSamples>project.params.camSamples;
report=struct('optimizationGrid',coarse,'refinedGrid',refined, ...
    'refinementFactor',refinementFactor,'independentRefinement',independent, ...
    'nodeBoundsSatisfied',coarse.nodeBoundsSatisfied && refined.nodeBoundsSatisfied, ...
    'trajectoryBoundsSatisfied',coarse.trajectoryBoundsSatisfied && refined.trajectoryBoundsSatisfied, ...
    'maxTrajectoryOutsideMM',max(coarse.maxTrajectoryOutsideMM,refined.maxTrajectoryOutsideMM), ...
    'verifiedFeasible',coarse.feasible && refined.feasible && independent, ...
    'physicalEvaluationAttempts',2,'scope','Discrete model and five sampled centers on both grids; no wheel/body envelope, continuous-curve, original-software or vehicle equivalence.');
end

function item=inspect(project)
p=project.params;
item=struct('routeSamples',p.samples,'camSamples',p.camSamples, ...
    'valid',false,'feasible',false,'maxScaledViolation',Inf,'metrics',[], ...
    'nodeBoundsSatisfied',false,'thresholdsSatisfied',false,'intersectionFree',false, ...
    'trajectoryBoundsSatisfied',false,'maxTrajectoryOutsideMM',Inf,'trajectoryBounds',[], ...
    'requestedRatio',p.gearRatio,'effectiveRatio',NaN,'autoRatio',logical(p.autoRatio), ...
    'workEndDeg',NaN,'warnings',{{}},'errorIdentifier','','errorMessage','');
try
    result=camdesign.evaluate(project,true);
    model=camdesign.fminconModel(project,project.nodes,result);
    bounds=p.bounds;
    within=all(project.nodes(:,1)>=bounds(1) & project.nodes(:,1)<=bounds(2) ...
        & project.nodes(:,2)>=bounds(3) & project.nodes(:,2)<=bounds(4));
    m=result.metrics;
    % Exact user thresholds; solver tolerance is not added to engineering limits.
    threshold=m.maxHitError<=p.hitTolerance && m.maxSteeringDeg<=p.maxSteeringDeg ...
        && m.maxPressureDeg<=p.maxPressureDeg && m.minUndercutMargin>0;
    item.valid=model.valid; item.maxScaledViolation=model.maxViolation; item.metrics=m;
    item.errorIdentifier=model.errorIdentifier; item.errorMessage=model.errorMessage;
    item.nodeBoundsSatisfied=within; item.thresholdsSatisfied=threshold;
    item.trajectoryBoundsSatisfied=model.trajectoryBoundsSatisfied;
    item.maxTrajectoryOutsideMM=model.maxTrajectoryOutsideMM;
    item.trajectoryBounds=model.trajectoryBounds;
    item.intersectionFree=m.intersectionCount==0;
    item.feasible=model.valid && within && threshold && item.intersectionFree && item.trajectoryBoundsSatisfied;
    item.effectiveRatio=result.cam.effectiveRatio; item.workEndDeg=rad2deg(result.cam.workEnd);
    item.warnings=result.warnings;
    if model.valid && ~item.trajectoryBoundsSatisfied
        item.warnings{end+1}=sprintf('五个部件中心点的采样轨迹最大出界 %.6g mm（%s，%s）；不含车宽及整车外廓。', ...
            item.maxTrajectoryOutsideMM,item.trajectoryBounds.worstPoint,item.trajectoryBounds.worstSide);
    end
catch ex
    expected={'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel', ...
        'cam:ExtremeSteering','cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite'};
    if ismember(ex.identifier,expected)
        item.errorIdentifier=ex.identifier; item.errorMessage=ex.message;
    else, rethrow(ex); end
end
end
