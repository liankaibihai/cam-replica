function [position,velocity,acceleration]=routeGeometry(nodes,p,u)
% Common front-position evaluator for conversion; u is the source parameter.
mode=camdesign.routeModel(p); u=u(:);
if strcmp(mode,'bspline-v1')
    [position,velocity,acceleration]=camdesign.bsplineRoute(nodes,p,u);
elseif strcmp(mode,'bezier-blend-independent-v1')
    [position,velocity,acceleration]=camdesign.bezierRoute(nodes,p,u);
else
    [px,py]=camdesign.routeSpline(nodes,p);
    position=[ppval(px,u),ppval(py,u)];
    velocity=[ppval(camdesign.ppDerivative(px,1),u),ppval(camdesign.ppDerivative(py,1),u)];
    acceleration=[ppval(camdesign.ppDerivative(px,2),u),ppval(camdesign.ppDerivative(py,2),u)];
end
end
