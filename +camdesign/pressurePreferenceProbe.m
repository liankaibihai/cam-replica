function probe=pressurePreferenceProbe(c,p)
% Extra same-law pressure samples for a SOFT design preference, not hard gates.
% No actual-contact or continuous-extremum claim. Native metrics stay intact.
if isfield(c,'workPP'), pp=c.workPP; else, pp=spline(c.workPhi,c.workRadius); end
first=camdesign.ppDerivative(pp,1);
phase=unique([linspace(0,2*pi,4*(numel(c.phi)-1)+1)';c.workPhi(:)]);
working=phase<=c.workEnd; q=zeros(size(phase)); d=q;
q(working)=ppval(pp,phase(working)); d(working)=ppval(first,phase(working));
gap=2*pi-c.workEnd; t=(phase(~working)-c.workEnd)/gap; coefficients=c.returnCoefficients(:)';
q(~working)=polyval(fliplr(coefficients),t);
d(~working)=polyval(fliplr((1:5).*coefficients(2:6)),t)/gap;
assert(all(isfinite([q;d])) && isreal(q) && isreal(d),'cam:ConstraintNonfinite','压力偏好采样出现非有限值。');
margin=min(.5,.1*p.maxPressureDeg);
probe=struct('maxPressureDeg',rad2deg(max(atan2(abs(d),q))),'sampleCount',numel(phase), ...
    'preferredMaximumDeg',p.maxPressureDeg-margin,'preferredMarginDeg',margin, ...
    'scope','4x cam phase grid plus every work-law breakpoint; soft preference only. User maxPressureDeg and exact native feasibility are unchanged; dense final checks still required.');
end
