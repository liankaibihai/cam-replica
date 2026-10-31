function simulation = simulate(c,p,frontStart,headingStart,options)
% Independently integrate from THEORETICAL working cam q(phi), not actual contact.
% GearRatio overrides the physical wheel/cam ratio for fixed-cam tuning.
arguments
    c struct
    p struct
    frontStart (1,2) double {mustBeFinite,mustBeReal}
    headingStart (1,1) double {mustBeFinite,mustBeReal}
    options.GearRatio (1,1) double = NaN
end
phi=c.workPhi; q=c.workRadius; L=-p.driveY;
useWorkPP=isfield(c,'workPP');
if useWorkPP
    [breaks,coefficients,~,~,dimension]=unmkpp(c.workPP);
    assert(dimension==1 && all(isfinite(coefficients),'all') && all(diff(breaks)>0) ...
        && abs(breaks(1)-phi(1))<1e-12 && abs(breaks(end)-phi(end))<1e-12, ...
        'cam:SimulationCamLaw','保存的工作段多项式无效或与工作相位不一致。');
    q=ppval(c.workPP,phi);
end
ratio=options.GearRatio;
if isnan(ratio), ratio=c.effectiveRatio; end
validateattributes(ratio,{'double'},{'scalar','real','finite','positive'});
assert(p.wheelDiameter>0 && L>0 && abs(p.driveY-p.drivenY)<1e-6,'cam:SimulationGeometry','反推要求正轮径、正轴距及后轮共轴。');
steering=camdesign.steeringFromLift(q-p.referenceDiameter/2,p);
assert(all(isfinite(steering)) && max(abs(steering))<deg2rad(85), ...
    'cam:SimulationSteering','试调参数导致转向达到或超过 85 度，超出本模型范围。');
s=phi*p.wheelDiameter*ratio/2;
if ~useWorkPP, pp=pchip(s,q); end
y=zeros(numel(s),3);
y(1,:)=[frontStart-L*[cos(headingStart),sin(headingStart)],headingStart];
for j=1:numel(s)-1
    h=s(j+1)-s(j); a=y(j,:);
    k1=rhs(s(j),a); k2=rhs(s(j)+h/2,a+h*k1/2);
    k3=rhs(s(j)+h/2,a+h*k2/2); k4=rhs(s(j+1),a+h*k3);
    y(j+1,:)=a+h*(k1+2*k2+2*k3+k4)/6;
end
fw=[cos(y(:,3)),sin(y(:,3))]; right=[sin(y(:,3)),-cos(y(:,3))];
front=y(:,1:2)+L*fw;
simulation=struct('front',front,'sensor',front+p.sensorX*right+p.sensorY*fw, ...
    'heading',y(:,3),'driveDistance',s,'phase',phi, ...
    'steering',steering, ...
    'physicalGearRatio',ratio);
if useWorkPP, simulation.numericalMethod='saved-work-pp-physical-phase-rk4-v1'; end
    function out=rhs(distance,state)
        if useWorkPP
            phase=max(phi(1),min(phi(end),2*distance/(p.wheelDiameter*ratio)));
            radius=ppval(c.workPP,phase);
        else, radius=ppval(pp,distance); end
        delta=camdesign.steeringFromLift(radius-p.referenceDiameter/2,p);
        if useWorkPP
            assert(isfinite(delta) && abs(delta)<deg2rad(85),'cam:SimulationSteering','工作段多项式导致转角接近或超过85度。');
        end
        kappa=tan(delta)/L; denom=1+p.driveX*kappa;
        assert(denom>1e-8,'cam:InverseSingularity','反推过程中主动轮速度奇异。');
        out=[cos(state(3)),sin(state(3)),kappa]/denom;
    end
end
