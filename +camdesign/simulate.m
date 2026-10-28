function simulation = simulate(c,p,frontStart,headingStart)
% Independently integrate from THEORETICAL working cam q(phi), not actual contact.
phi=c.workPhi; q=c.workRadius; L=-p.driveY;
s=phi*p.wheelDiameter*c.effectiveRatio/2;
pp=pchip(s,q); y=zeros(numel(s),3);
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
    'heading',y(:,3),'driveDistance',s);
    function out=rhs(distance,state)
        delta=camdesign.steeringFromLift(ppval(pp,distance)-p.referenceDiameter/2,p);
        kappa=tan(delta)/L; denom=1+p.driveX*kappa;
        assert(denom>1e-8,'cam:InverseSingularity','反推过程中主动轮速度奇异。');
        out=[cos(state(3)),sin(state(3)),kappa]/denom;
    end
end
