function test_reference_comparison()
% Analytical fixtures only. Passing this is NOT an original-app comparison.
a=[(0:10:100)',zeros(11,1)]; b=[(0:2:100)',zeros(51,1)];
r=camdesign.compareCurves(a,b); assert(r.arcPairedMaxMM<1e-10 && r.sampledSymmetricMaxMM<1e-10);
b(:,2)=2; r=camdesign.compareCurves(a,b);
assert(abs(r.sampledSymmetricMaxMM-2)<1e-10 && abs(r.arcPairedRmsMM-2)<1e-10);
t=(0:359)'*pi/180; a=50*[cos(t),sin(t)]; b=circshift(a,90,1);
r=camdesign.compareCurves(a,b,Closed=true);
assert(r.sampledSymmetricMaxMM<1e-8 && r.arcPairedRmsMM>60);
fprintf('REFERENCE_COMPARISON_HELPER_PASS (synthetic checks; not original-software validation)\n');
end
