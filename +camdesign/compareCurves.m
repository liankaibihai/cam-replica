function report = compareCurves(reference,candidate,options)
%COMPARECURVES Coordinate-preserving comparison; never auto-fit/rotate/scale.
% Nearest-distance measures shape, while arc-paired errors retain phase/start.
arguments
    reference (:,2) double {mustBeFinite,mustBeReal}
    candidate (:,2) double {mustBeFinite,mustBeReal}
    options.Closed (1,1) logical = false
    options.Samples (1,1) double {mustBeInteger,mustBePositive} = 1001
end
assert(options.Samples>=2 && options.Samples<=20001,'cam:ComparisonSamples','比对采样数须为 2 到 20001。');
[ref,sref]=prepare(reference,options.Closed);
[test,stest]=prepare(candidate,options.Closed);
t=linspace(0,1,options.Samples)';
R=interp1(sref/sref(end),ref,t,'linear'); C=interp1(stest/stest(end),test,t,'linear');
paired=vecnorm(R-C,2,2);
refToCandidate=distanceToSegments(R,test); candidateToRef=distanceToSegments(C,ref);
report=struct('units','mm','alignment','none; original coordinates, orientation and starting phase retained', ...
    'closed',options.Closed,'samples',options.Samples, ...
    'referencePointCount',size(reference,1),'candidatePointCount',size(candidate,1), ...
    'referenceLengthMM',sref(end),'candidateLengthMM',stest(end), ...
    'lengthDifferenceMM',stest(end)-sref(end), ...
    'startDifferenceMM',norm(ref(1,:)-test(1,:)), ...
    'endDifferenceMM',norm(ref(end,:)-test(end,:)), ...
    'arcPairedRmsMM',sqrt(mean(paired.^2)),'arcPairedMaxMM',max(paired), ...
    'referenceToCandidateMaxMM',max(refToCandidate), ...
    'candidateToReferenceMaxMM',max(candidateToRef), ...
    'sampledSymmetricMaxMM',max([refToCandidate;candidateToRef]), ...
    'symmetricRmsMM',sqrt(mean([refToCandidate;candidateToRef].^2)), ...
    'referenceClosureGapMM',norm(reference(1,:)-reference(end,:)), ...
    'candidateClosureGapMM',norm(candidate(1,:)-candidate(end,:)), ...
    'interpretation','Arc pairing compares equal normalized arc positions. Shape distance alone does not validate phase, scale, transmission ratio or kinematics.');
end

function [points,s]=prepare(points,closed)
assert(size(points,1)>=2,'cam:ComparisonPoints','比对曲线至少需要两个点。');
points=points([true;vecnorm(diff(points),2,2)>1e-12],:);
assert(size(points,1)>=2,'cam:ComparisonDegenerate','曲线长度为零。');
if closed && norm(points(end,:)-points(1,:))>1e-12, points=[points;points(1,:)]; end
s=[0;cumsum(vecnorm(diff(points),2,2))];
end

function d=distanceToSegments(query,curve)
A=curve(1:end-1,:); V=diff(curve); den=sum(V.^2,2); d=zeros(size(query,1),1);
for i=1:size(query,1)
    t=max(0,min(1,sum((query(i,:)-A).*V,2)./den));
    d(i)=min(vecnorm(A+t.*V-query(i,:),2,2));
end
end
