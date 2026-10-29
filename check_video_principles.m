function report = check_video_principles()
% Validate selected visible formulas against independent analytic examples.
% Sources: 790980181 (15:00), 1058835426 (19:00). Not EXE equivalence.
root=fileparts(mfilename('fullpath'));
out=fullfile(root,'outputs','video_principles');
if ~isfolder(out), mkdir(out); end
counts=[73;361;1441]; errors=zeros(size(counts)); circleErrors=errors;
for k=1:numel(counts)
    a=linspace(0,2*pi,counts(k))';
    circle=50*[cos(a),sin(a)]; circle(end,:)=circle(1,:);
    actual=videoOffset(circle,5);
    circleErrors(k)=max(abs(vecnorm(actual,2,2)-45));
    % A smooth noncircular curve supplies an independent exact tangent.
    q=50+8*sin(3*a)+2*cos(5*a); dq=24*cos(3*a)-10*sin(5*a);
    pitch=[q.*cos(a),q.*sin(a)]; pitch(end,:)=pitch(1,:);
    tangent=[dq.*cos(a)-q.*sin(a),dq.*sin(a)+q.*cos(a)];
    left=[-tangent(:,2),tangent(:,1)]./vecnorm(tangent,2,2);
    analytic=pitch+5*left;
    discrete=videoOffset(pitch,5);
    errors(k)=max(vecnorm(discrete-analytic,2,2));
end
assert(max(circleErrors)<1e-10,'Circle must offset from 50 to 45 mm.');
assert(all(diff(errors)<0),'Finite-difference error should converge with denser samples.');
assert(errors(end)<0.005,'Finest analytic comparison exceeded 0.005 mm.');
% The final tutorial also compares two 5 mm offsets with one 10 mm offset.
% A discrete chord normal only approximates the continuous regular-offset law.
twoOffsets=videoOffset(videoOffset(pitch,5),5);
oneOffset=videoOffset(pitch,10);
compositionError=max(vecnorm(twoOffsets-oneOffset,2,2));
assert(compositionError<0.005,'Smooth example offset composition exceeded 0.005 mm.');
reverse=videoOffset(flipud(circle),5);
assert(max(abs(vecnorm(reverse,2,2)-55))<1e-10,'Left normal changes side with winding.');
% Visible tutorial uses row vectors and an inverse basis matrix.
theta=deg2rad(30); e1=[cos(-theta),sin(-theta)]; e2=[-e1(2),e1(1)];
basis=[e1',e2']; p=[pi/100,sin(pi/100)]; rotated=p/basis;
expected=[p(1)*cos(theta)+p(2)*sin(theta),-p(1)*sin(theta)+p(2)*cos(theta)];
assert(norm(rotated-expected)<1e-14);
assert(max(abs(rotated-[0.0429,0.0115]))<5e-5,'Must match rounded tutorial table.');
% Compare only envelope discretization on this project's existing candidate.
project=camdesign.defaultProject(); candidate=camdesign.evaluate(project);
pitch=candidate.cam.pitch; pitch(end,:)=pitch(1,:);
paired=vecnorm(videoOffset(pitch,project.params.rollerRadius)-candidate.cam.actual,2,2);
report=struct('scope','Visible tutorial formulas and synthetic curves; not original EXE output equivalence.', ...
    'sampleCounts',counts,'circleMaxRadiusErrorsMM',circleErrors, ...
    'noncircularMaxPairedErrorsMM',errors,'rotationExampleXY',rotated, ...
    'wheelDistancePerCamTurnExampleMM',pi*150*46, ...
    'candidateEnvelopeMaxPairedDifferenceMM',max(paired), ...
    'candidateEnvelopeRMSPairedDifferenceMM',sqrt(mean(paired.^2)), ...
    'two5MMVersusOne10MMOffsetMaxDifferenceMM',compositionError, ...
    'positiveLeftOffsetRequiresCounterclockwiseForInward',true);
writetable(table(counts,circleErrors,errors,'VariableNames', ...
    {'SampleCountIncludingClosure','CircleRadiusError_mm','NoncircularMaxError_mm'}), ...
    fullfile(out,'envelope_convergence.csv'));
fid=fopen(fullfile(out,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fprintf('VIDEO_PRINCIPLES_PASS: circle, winding, rotation and envelope convergence checked.\n');
disp(report);
end

function actual=videoOffset(closed,radius)
% Equivalent to the tutorial's centered chord, left normal and closure loop.
assert(norm(closed(1,:)-closed(end,:))<1e-8,'Input must be a closed point sequence.');
uniquePoints=closed(1:end-1,:);
tangent=circshift(uniquePoints,-1,1)-circshift(uniquePoints,1,1);
lengths=vecnorm(tangent,2,2); assert(all(lengths>1e-12),'Undefined centered tangent.');
actual=uniquePoints+radius*[-tangent(:,2),tangent(:,1)]./lengths;
actual=[actual;actual(1,:)];
end
