function r = route(nodes,p)
% Front-wheel path -> rigid-body heading via the rear no-slip constraint.
[px,py,knots]=camdesign.routeSpline(nodes,p);
dx=camdesign.ppDerivative(px,1); dy=camdesign.ppDerivative(py,1);
u=linspace(0,knots(end),p.samples)'; um=(u(1:end-1)+u(2:end))/2;
vx=ppval(dx,u); vy=ppval(dy,u); mx=ppval(dx,um); my=ppval(dy,um);
L=-p.driveY; heading=zeros(size(u)); heading(1)=deg2rad(p.headingDeg);
f=@(a,x,y) (-x*sin(a)+y*cos(a))/L;
for j=1:numel(u)-1
    step=u(j+1)-u(j); a=heading(j);
    k1=f(a,vx(j),vy(j)); k2=f(a+step*k1/2,mx(j),my(j));
    k3=f(a+step*k2/2,mx(j),my(j)); k4=f(a+step*k3,vx(j+1),vy(j+1));
    heading(j+1)=a+step*(k1+2*k2+2*k3+k4)/6;
end
F=[ppval(px,u),ppval(py,u)];
fw=[cos(heading),sin(heading)]; right=[sin(heading),-cos(heading)];
delta=atan2(sin(atan2(vy,vx)-heading),cos(atan2(vy,vx)-heading));
headingRate=(-vx.*sin(heading)+vy.*cos(heading))/L;
driveSpeed=vx.*cos(heading)+vy.*sin(heading)+p.driveX*headingRate;
r=struct('u',u,'front',F,'heading',heading,'steering',delta, ...
    'rear',F-L*fw,'drive',F-L*fw+p.driveX*right, ...
    'driven',F-L*fw+p.drivenX*right, ...
    'sensor',F+p.sensorX*right+p.sensorY*fw, ...
    'frontDistance',cumtrapz(u,hypot(vx,vy)), ...
    'driveDistance',cumtrapz(u,driveSpeed),'driveSpeed',driveSpeed, ...
    'speed',hypot(vx,vy));
assert(all(isfinite(r.steering)) && min(r.speed)>1e-7,'cam:RouteSingularity','路线含停滞或奇异切线。');
assert(min(driveSpeed)>1e-6,'cam:ReverseWheel','候选路线导致主动轮倒转；请调整节点或车体参数。');
assert(max(abs(delta))<deg2rad(85),'cam:ExtremeSteering','候选路线转角接近 90 度。');
end
