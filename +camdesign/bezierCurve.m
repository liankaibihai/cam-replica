function [points,t,coefficients]=bezierCurve(controlPoints,segments)
%BEZIERCURVE Single Bernstein curve matching the supplied Bezier_Curve.m.
% N+1 controls define degree N. segments yields segments+1 points including
% both endpoints. This is NOT Bezier_superposition or an optimizer.
% Source/provenance: docs/ADDITIONAL_SOURCE_PACKAGES.md.
arguments
    controlPoints (:,:) double {mustBeReal,mustBeFinite,mustBeNonempty}
    segments (1,1) double {mustBeReal,mustBeFinite,mustBePositive,mustBeInteger}=1000
end
degree=size(controlPoints,1)-1;
coefficients=[1;zeros(degree,1)];
for k=1:degree
    coefficients(2:k+1)=coefficients(1:k)+coefficients(2:k+1);
end
assert(all(isfinite(coefficients)),'cam:BezierCoefficientOverflow', ...
    '当前阶数使原式的杨辉系数溢出；请降低阶数。');
t=(0:1/segments:1)'; reverse=1-t;
points=zeros(segments+1,size(controlPoints,2));
for k=1:degree+1
    points=points+coefficients(k)*t.^(k-1).*reverse.^(degree+1-k).*controlPoints(k,:);
end
end
