function r = route(nodes,p)
% Front-wheel path -> rigid-body heading via the rear no-slip constraint.
mode=camdesign.routeModel(p); parametric=~strcmp(mode,'cubic');
accurateBezier=strcmp(mode,'bezier-blend-independent-v1');
if strcmp(mode,'bspline-v1')
    knots=[0;p.bspline.parameterLength];
elseif parametric
    knots=[0;p.bezier.parameterLength];
else
    [px,py,knots]=camdesign.routeSpline(nodes,p);
end
if ~parametric, dx=camdesign.ppDerivative(px,1); dy=camdesign.ppDerivative(py,1); end
u=linspace(0,knots(end),p.samples)'; um=(u(1:end-1)+u(2:end))/2;
if parametric
    if accurateBezier, [F,v,acceleration,jerk]=camdesign.routeGeometry(nodes,p,u);
    else, [F,v]=camdesign.routeGeometry(nodes,p,u); end
    [~,middle]=camdesign.routeGeometry(nodes,p,um);
    vx=v(:,1); vy=v(:,2); mx=middle(:,1); my=middle(:,2);
else
    vx=ppval(dx,u); vy=ppval(dy,u); mx=ppval(dx,um); my=ppval(dy,um);
end
L=-p.driveY; heading=zeros(size(u)); heading(1)=deg2rad(p.headingDeg);
if accurateBezier, driveIntegral=zeros(size(u)); frontIntegral=driveIntegral; end
f=@(a,x,y) (-x*sin(a)+y*cos(a))/L;
for j=1:numel(u)-1
    step=u(j+1)-u(j); a=heading(j);
    k1=f(a,vx(j),vy(j)); k2=f(a+step*k1/2,mx(j),my(j));
    k3=f(a+step*k2/2,mx(j),my(j)); k4=f(a+step*k3,vx(j+1),vy(j+1));
    heading(j+1)=a+step*(k1+2*k2+2*k3+k4)/6;
    if accurateBezier
        angles=[a,a+step*k1/2,a+step*k2/2,a+step*k3];
        speeds=[vx(j),mx(j),mx(j),vx(j+1)].*cos(angles) ...
            +[vy(j),my(j),my(j),vy(j+1)].*sin(angles)+p.driveX*[k1,k2,k3,k4];
        driveIntegral(j+1)=driveIntegral(j)+step*(speeds(1)+2*speeds(2)+2*speeds(3)+speeds(4))/6;
        frontIntegral(j+1)=frontIntegral(j)+step*(hypot(vx(j),vy(j))+4*hypot(mx(j),my(j))+hypot(vx(j+1),vy(j+1)))/6;
    end
end
if ~parametric, F=[ppval(px,u),ppval(py,u)]; end
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
if accurateBezier
    r.driveDistance=driveIntegral; r.frontDistance=frontIntegral;
    r.camMotion=camdesign.analyticCamMotion(v,acceleration,jerk,heading,p);
    r.numericalMethod='bezier-analytic-d3-coupled-rk4-v1';
end
end
