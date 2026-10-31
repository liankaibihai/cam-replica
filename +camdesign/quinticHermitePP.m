function [pp,info]=quinticHermitePP(x,value,first,second)
% Scalar C2 quintic Hermite law. Derivatives are with respect to x (rad).
x=x(:); value=value(:); first=first(:); second=second(:);
assert(numel(x)>=2 && numel(x)<=20001 && isequal(size(x),size(value),size(first),size(second)) ...
    && isreal([x;value;first;second]) && all(isfinite([x;value;first;second])), ...
    'cam:ConstraintNonfinite','Hermite工作段须有2至20001组有限实数相位及导数。');
minimumStep=max(1e-10,256*eps(max(1,max(abs(x)))));
h=diff(x);
assert(all(h>minimumStep),'cam:ConstraintNonfinite', ...
    '工作相位间隔须大于%.12g rad；过短区间无法可靠构造双精度Hermite多项式。',minimumStep);
c=[value(1:end-1),h.*first(1:end-1),h.^2.*second(1:end-1)/2,zeros(numel(h),3)];
rhs=[value(2:end)-sum(c(:,1:3),2),h.*first(2:end)-c(:,2)-2*c(:,3),h.^2.*second(2:end)-2*c(:,3)];
c(:,4:6)=rhs/[1 3 6;1 4 12;1 5 20];
coefficients=fliplr(c./h.^(0:5));
assert(all(isfinite(coefficients),'all'),'cam:ConstraintNonfinite','Hermite多项式系数非有限。');
pp=mkpp(x,coefficients);
info=struct('method','analytic-quintic-hermite-v1','sampleCap',20001, ...
    'minimumAllowedPhaseStepRad',minimumStep,'minimumPhaseStepRad',min(h));
end
