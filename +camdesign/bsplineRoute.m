function [position,velocity,acceleration,jerk]=bsplineRoute(nodes,p,u)
% Standard clamped B-spline coefficients; no additive tangent correction.
[B,D,A,J]=camdesign.bsplineBasis(p.bspline.knots,p.bspline.degree,u);
position=B*nodes; velocity=D*nodes;
if nargout>2, acceleration=A*nodes; end
if nargout>3, jerk=J*nodes; end
end
