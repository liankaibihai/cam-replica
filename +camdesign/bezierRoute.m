function [position,velocity,acceleration]=bezierRoute(nodes,p,u)
% Independent blend plus compact initial-tangent correction; not original code.
u=u(:); n=size(nodes,1); degree=p.bezier.degree; lengthMM=p.bezier.parameterLength;
assert(all(isfinite(u)) && all(u>=0 & u<=lengthMM),'cam:BezierDomain','贝塞尔参数超出定义域。');
scale=(n-1)/lengthMM;
[B,D,DD]=camdesign.independentBezierBasis(double(n),degree,max(0,min(n-1,u*scale)));
desired=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
correction=desired-scale*(nodes(2,:)-nodes(1,:));
span=lengthMM*degree/(n-1); t=u/span; support=t<=1;
h=zeros(size(t)); dh=h; ddh=h; v=t(support);
h(support)=span*v.*(1-v).^4;
dh(support)=(1-v).^3.*(1-5*v);
ddh(support)=4*(1-v).^2.*(5*v-2)/span;
position=B*nodes+h*correction;
velocity=scale*(D*nodes)+dh*correction;
if nargout>2, acceleration=scale^2*(DD*nodes)+ddh*correction; end
end
