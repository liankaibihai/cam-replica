function motion=analyticCamMotion(v,a,j,heading,p)
% Exact chain rule in saved curve parameter u, then physical cam phase phi.
assert(size(v,2)==2 && isequal(size(v),size(a),size(j)) && size(v,1)==numel(heading), ...
    'cam:ConstraintNonfinite','解析运动导数的数组尺寸不一致。');
heading=heading(:); L=-p.driveY; co=cos(heading); si=sin(heading);
forward=v(:,1).*co+v(:,2).*si; lateral=-v(:,1).*si+v(:,2).*co;
theta1=lateral/L;
theta2=(-a(:,1).*si+a(:,2).*co-forward.*theta1)/L;
speed2=sum(v.^2,2); turn=v(:,1).*a(:,2)-v(:,2).*a(:,1);
assert(L>0 && all(speed2>1e-14),'cam:RouteSingularity','解析凸轮导数不支持零轴距或停滞曲线。');
beta1=turn./speed2;
beta2=(v(:,1).*j(:,2)-v(:,2).*j(:,1))./speed2-2*turn.*sum(v.*a,2)./speed2.^2;
delta=atan2(sin(atan2(v(:,2),v(:,1))-heading),cos(atan2(v(:,2),v(:,1))-heading));
delta1=beta1-theta1; delta2=beta2-theta2;
driveSpeed=forward+p.driveX*theta1;
driveAcceleration=a(:,1).*co+a(:,2).*si+lateral.*theta1+p.driveX*theta2;
phi1=2*driveSpeed/(p.wheelDiameter*p.gearRatio);
phi2=2*driveAcceleration/(p.wheelDiameter*p.gearRatio);
assert(all(phi1>0),'cam:ReverseWheel','解析相位导数要求主动轮行程严格递增。');
switch p.mechanism
    case 'flat'
        qu=p.lever*(1+tan(delta).^2).*delta1;
        quu=p.lever*(1+tan(delta).^2).*(delta2+2*tan(delta).*delta1.^2);
    case 'rack'
        qu=p.lever*delta1; quu=p.lever*delta2;
    otherwise
        error('cam:Mechanism','解析凸轮运动仅支持平推或齿条。');
end
q=p.referenceDiameter/2+camdesign.lift(delta,p);
qPhi=qu./phi1; qPhiPhi=(quu.*phi1-qu.*phi2)./phi1.^3;
assert(all(isfinite([q;qPhi;qPhiPhi;phi1;phi2])), ...
    'cam:ConstraintNonfinite','解析凸轮运动导数非有限。');
motion=struct('q',q,'qPhi',qPhi,'qPhiPhi',qPhiPhi,'phaseRateU',phi1,'phaseAccelerationU',phi2, ...
    'steeringRateU',delta1,'steeringAccelerationU',delta2, ...
    'method','analytic-curve-chain-rule-v1','mechanism',p.mechanism);
end
