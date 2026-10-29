function model=fminconModel(project,referenceNodes,result)
% Fixed-size constraints over the existing route/cam model; no geometry tuning.
% score remains the historical peak-v2 score, NOT the constrained objective.
p=project.params; count=size(project.targets,1)+p.samples+2*p.camSamples;
model=struct('valid',false,'objective',1e6,'objectiveParts',[NaN NaN NaN], ...
    'constraints',1e3*ones(count,1),'maxViolation',1e3,'result',[], ...
    'maxNonlinearViolation',1e3,'maxNodeBoundViolation',1e3, ...
    'errorIdentifier','','errorMessage','');
low=[p.bounds(1),p.bounds(3)]; high=[p.bounds(2),p.bounds(4)];
boundResiduals=[(low-project.nodes)./(high-low);(project.nodes-high)./(high-low)];
model.maxNodeBoundViolation=max([0;boundResiduals(:)]);
try
    if nargin<3, result=camdesign.evaluate(project,false); end
    rate=diff(result.route.steering)./max(diff(result.route.frontDistance),1e-9);
    directLength=max(1,sum(vecnorm(diff(project.targets),2,2)));
    parts=[result.route.frontDistance(end)/directLength,mean((100*rate).^2), ...
        mean(((project.nodes-referenceNodes)/1000).^2,'all')];
    objective=[p.weights(2),p.weights(3),1e-4]*parts';
    % Every sample is retained. The number of work/return samples may change.
    constraints=[(result.hits.errors/p.hitTolerance).^2-1; ...
        (result.route.steering/deg2rad(p.maxSteeringDeg)).^2-1; ...
        (result.cam.pressure/deg2rad(p.maxPressureDeg)).^2-1; ...
        1e-6-result.cam.undercutMargin];
    assert(numel(constraints)==count,'cam:ConstraintDimension','约束维数发生变化。');
    assert(isreal(objective) && isfinite(objective) && isreal(constraints) ...
        && all(isfinite(constraints)) && isfinite(result.metrics.score), ...
        'cam:ConstraintNonfinite','候选计算出现非有限或复数结果。');
    model.valid=true; model.objective=objective; model.objectiveParts=parts;
    model.constraints=constraints; model.maxNonlinearViolation=max([0;constraints]);
    model.maxViolation=max(model.maxNonlinearViolation,model.maxNodeBoundViolation); model.result=result;
catch ex
    expected={'cam:Duplicate','cam:RouteSingularity','cam:ReverseWheel', ...
        'cam:ExtremeSteering','cam:GearRatio','cam:NegativeRadius','cam:ConstraintNonfinite'};
    if ismember(ex.identifier,expected)
        % Invalid candidates never appear feasible and never change dimension.
        model.errorIdentifier=ex.identifier; model.errorMessage=ex.message;
        displacement=norm((project.nodes-referenceNodes)/1000,'fro');
        if isfinite(displacement)
            model.objective=1e6+min(displacement^2,1e6);
            model.constraints(:)=1e3+min(displacement,1e3);
            model.maxViolation=max(model.constraints);
            model.maxNonlinearViolation=model.maxViolation;
        end
    else
        rethrow(ex);
    end
end
end
