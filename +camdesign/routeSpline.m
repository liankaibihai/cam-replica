function [px,py,stations,endDerivative] = routeSpline(nodes,p)
% Front-wheel interpolating cubic. Fixed stations support nested refinement.
% Legacy projects retain chord-length stations and the final chord tangent.
if isfield(p,'routeSpline')
    stations=p.routeSpline.stations(:);
    endDerivative=p.routeSpline.endDerivative;
else
    stations=[0;cumsum(vecnorm(diff(nodes),2,2))];
    endDerivative=nodes(end,:)-nodes(end-1,:);
    endDerivative=endDerivative/norm(endDerivative);
end
startDerivative=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
px=spline(stations,[startDerivative(1);nodes(:,1);endDerivative(1)]);
py=spline(stations,[startDerivative(2);nodes(:,2);endDerivative(2)]);
end
