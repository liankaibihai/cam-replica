function result = evaluate(project,fullCheck)
if nargin<2, fullCheck=true; end
camdesign.validateProject(project); p=project.params;
r=camdesign.route(project.nodes,p); c=camdesign.camProfile(r,p);
hits=camdesign.orderedHits(r.sensor,project.targets);
straightLength=sum(vecnorm(diff(project.targets),2,2));
steeringRate=diff(r.steering)./max(diff(r.frontDistance),1e-9);
pressureExcess=max(0,c.pressure-deg2rad(p.maxPressureDeg));
steeringExcess=max(0,abs(r.steering)-deg2rad(p.maxSteeringDeg));
legacyTerms=[mean((hits.errors/p.hitTolerance).^2), ...
    r.frontDistance(end)/max(1,straightLength), ...
    mean((100*steeringRate).^2),mean((pressureExcess/deg2rad(10)).^2), ...
    mean((steeringExcess/deg2rad(10)).^2),mean(max(0,0.1-c.undercutMargin).^2)];
% Independent peak-aware objective. Geometry and user thresholds are unchanged.
terms=legacyTerms;
terms(1)=terms(1)+max((hits.errors/p.hitTolerance).^2);
terms(3)=terms(3)+max((100*steeringRate).^2);
terms(4)=terms(4)+max((pressureExcess(c.workingMask)/deg2rad(10)).^2) ...
    +max((pressureExcess(~c.workingMask)/deg2rad(10)).^2);
terms(5)=terms(5)+max((steeringExcess/deg2rad(10)).^2);
terms(6)=terms(6)+max(max(0,0.1-c.undercutMargin).^2);
metrics=struct('maxHitError',max(hits.errors),'rmsHitError',sqrt(mean(hits.errors.^2)), ...
    'routeLength',r.frontDistance(end),'driveLength',r.driveDistance(end), ...
    'maxSteeringDeg',rad2deg(max(abs(r.steering))), ...
    'maxPressureDeg',rad2deg(max(c.pressure)), ...
    'maxWorkPressureDeg',rad2deg(max(c.pressure(c.workingMask))), ...
    'maxReturnPressureDeg',rad2deg(max(c.pressure(~c.workingMask))), ...
    'minUndercutMargin',min(c.undercutMargin),'intersectionCount',NaN, ...
    'actualReturnDeg',c.actualReturnDeg,'returnAngleSatisfied',c.returnAngleSatisfied, ...
    'score',sum(p.weights.*terms),'terms',terms,'objectiveVersion','peak-v2', ...
    'legacyScore',sum(p.weights.*legacyTerms),'legacyTerms',legacyTerms,'geometryChecked',logical(fullCheck));
visitAudit=[]; trajectory=[]; control=[];
metrics.visitOrderChecked=logical(fullCheck); metrics.visitOrderSatisfied=false;
metrics.trajectoryBoundsChecked=logical(fullCheck); metrics.trajectoryBoundsSatisfied=false;
metrics.maxTrajectoryOutsideMM=NaN;
if fullCheck
    [pairs,intersectionPoints]=camdesign.selfIntersections(c.actual);
    metrics.intersectionCount=size(pairs,1);
    visitAudit=camdesign.visitOrderAudit(r.sensor,project.targets,p.hitTolerance);
    visitAudit.radiusSource='params.hitTolerance (geometric tolerance, not measured RFID range)';
    metrics.visitOrderSatisfied=visitAudit.matchesRequiredOrderAndVisitCount;
    [~,trajectory]=camdesign.trajectoryBounds(r,p.bounds);
    control=camdesign.controlBounds(project);
    metrics.trajectoryBoundsSatisfied=trajectory.satisfied;
    metrics.maxTrajectoryOutsideMM=trajectory.maximumOutsideMM;
else
    pairs=zeros(0,2); intersectionPoints=zeros(0,2);
end
messages={};
if metrics.maxHitError>p.hitTolerance, messages{end+1}='部分打卡点超出设定的几何容差。'; end
if metrics.maxSteeringDeg>p.maxSteeringDeg, messages{end+1}='前轮转角超过设定上限。'; end
if metrics.maxPressureDeg>p.maxPressureDeg, messages{end+1}='凸轮压力角超过设定上限（含回程）。'; end
if metrics.minUndercutMargin<=0, messages{end+1}='滚子包络存在局部欠切风险。'; end
if fullCheck && metrics.intersectionCount>0, messages{end+1}='离散凸轮轮廓存在自交或非相邻接触。'; end
if fullCheck && ~metrics.visitOrderSatisfied
    messages{end+1}=sprintf('几何访问顺序/次数未通过（检查半径 %.6g mm，沿用打卡几何容差，非实测RFID范围）：要求 %s，实际 %s。', ...
        p.hitTolerance,mat2str(visitAudit.expectedLocationIDs),mat2str(visitAudit.observedLocationIDs));
end
if fullCheck && ~trajectory.satisfied
    messages{end+1}=sprintf('五个部件中心的采样轨迹最大出界 %.6g mm（%s，%s）；不含车宽及整车外廓。', ...
        trajectory.maximumOutsideMM,trajectory.worstPoint,trajectory.worstSide);
end
if fullCheck && ~control.gatePassed, messages{end+1}='路线控制量违反当前启用的控制点场界约束。'; end
if ~c.returnAngleSatisfied
    messages{end+1}=sprintf('固定传动比 %.6g：实际回程 %.3f°，小于设定的 %.3f°。需缩短路线或由用户调整参数，程序不增比。',p.gearRatio,c.actualReturnDeg,p.returnAngleDeg);
end
result=struct('route',r,'cam',c,'hits',hits,'metrics',metrics,'warnings',{messages}, ...
    'intersectionPairs',pairs,'intersectionPoints',intersectionPoints, ...
    'visitOrder',visitAudit,'trajectoryBounds',trajectory,'controlBounds',control);
end
