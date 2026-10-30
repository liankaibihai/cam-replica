function c = camProfile(r,p)
% Radial translating roller. q is roller-center radius, not surface radius.
ratio=p.gearRatio; workLimit=2*pi-deg2rad(p.returnAngleDeg);
% Transmission is user-owned hardware. Legacy autoRatio metadata cannot
% change it, including during search, verification or export.
phi=2*r.driveDistance/(p.wheelDiameter*ratio);
assert(phi(end)<2*pi-deg2rad(5),'cam:GearRatio', ...
    '固定传动比 %.6g 下工作段 %.3f°，整圈至少需留5°回程。请缩短路线或由用户重新设定机构参数；程序不会调整传动比。',ratio,rad2deg(phi(end)));
q0=p.referenceDiameter/2;
qWork=q0+camdesign.lift(r.steering,p);
pp=spline(phi,qWork); pp1=camdesign.ppDerivative(pp,1); pp2=camdesign.ppDerivative(pp,2);
gap=2*pi-phi(end);
qa=ppval(pp,phi(end)); qb=ppval(pp,0);
da=ppval(pp1,phi(end)); db=ppval(pp1,0);
dda=ppval(pp2,phi(end)); ddb=ppval(pp2,0);
coeff=[qa;gap*da;gap^2*dda/2;zeros(3,1)];
coeff(4:6)=[1 1 1;3 4 5;6 12 20]\ ...
    [qb-sum(coeff(1:3));gap*db-coeff(2)-2*coeff(3);gap^2*ddb-2*coeff(3)];
a=linspace(0,2*pi,p.camSamples)'; working=a<=phi(end);
q=zeros(size(a)); d=q; dd=q;
q(working)=ppval(pp,a(working)); d(working)=ppval(pp1,a(working)); dd(working)=ppval(pp2,a(working));
t=(a(~working)-phi(end))/gap;
q(~working)=polyval(flipud(coeff),t);
d(~working)=polyval(flipud((1:5)'.*coeff(2:6)),t)/gap;
dd(~working)=polyval(flipud((2:5)'.*(1:4)'.*coeff(3:6)),t)/gap^2;
assert(all(q>p.rollerRadius+1e-6),'cam:NegativeRadius','凸轮中心距不足，回程或工作段侵入滚子半径。');
pitch=[q.*cos(a),q.*sin(a)];
tangent=[d.*cos(a)-q.*sin(a),d.*sin(a)+q.*cos(a)];
normals=[tangent(:,2),-tangent(:,1)]./vecnorm(tangent,2,2);
actual=pitch-p.rollerRadius*normals;
curvature=(q.^2+2*d.^2-q.*dd)./(q.^2+d.^2).^(3/2);
c=struct('phi',a,'radius',q,'pitch',pitch,'actual',actual, ...
    'pressure',atan2(abs(d),q),'curvature',curvature, ...
    'undercutMargin',1-p.rollerRadius*curvature,'workingMask',working, ...
    'workPhi',phi,'workRadius',qWork,'workEnd',phi(end), ...
    'effectiveRatio',ratio,'requestedRatio',p.gearRatio,'returnCoefficients',coeff, ...
    'actualReturnDeg',rad2deg(gap),'returnAngleSatisfied',phi(end)<=workLimit, ...
    'ratioPolicy','fixed-user-input-v1');
end
