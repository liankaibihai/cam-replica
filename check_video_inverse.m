function report = check_video_inverse()
% Independent checks of the visible lecture's theoretical-cam inverse chain.
% Uses this project's left-positive coordinates, not a literal legacy port.
root=fileparts(mfilename('fullpath')); project=camdesign.defaultProject(); p=project.params;
p.mechanism='flat'; p.wheelDiameter=150; p.gearRatio=40;
p.lever=20; p.referenceDiameter=100;
p.driveX=20; p.driveY=-120; p.drivenY=-120;
% Recover phase through every coordinate axis without sign(y)/abs(y).
a=linspace(0,2*pi,721)'; delta=deg2rad(12)*sin(a);
q=p.referenceDiameter/2+camdesign.lift(delta,p);
points=q.*[cos(a),sin(a)]; phase=unwrap(atan2(points(:,2),points(:,1)));
recoveredQ=hypot(points(:,1),points(:,2));
recoveredDelta=camdesign.steeringFromLift(recoveredQ-p.referenceDiameter/2,p);
assert(max(abs(phase-a))<1e-12 && all(isfinite(phase)));
assert(max(abs(recoveredDelta-delta))<1e-12);
s=phase*p.wheelDiameter*p.gearRatio/2;
assert(abs(s(end)-pi*p.wheelDiameter*p.gearRatio)<1e-8);
% Test the circular-step update on straight, left and right constant turns.
constantErrors=zeros(3,1); angles=deg2rad([0,10,-10]);
for k=1:3
    distance=linspace(0,2000,801)'; steering=angles(k)*ones(size(distance));
    c=makeCam(distance,steering,p);
    rk=camdesign.simulate(c,p,[0,0],0);
    discrete=circularSteps(distance,steering,p);
    constantErrors(k)=max(vecnorm(discrete-rk.front,2,2));
end
assert(max(constantErrors)<1e-5);
% Variable steering: arithmetic mean of endpoint angles per circular step.
counts=[51;201;801]; maxErrors=zeros(size(counts)); rmsErrors=maxErrors;
for k=1:numel(counts)
    distance=linspace(0,2000,counts(k))';
    steering=deg2rad(12)*sin(2*pi*distance/2000);
    c=makeCam(distance,steering,p); rk=camdesign.simulate(c,p,[0,0],0);
    discrete=circularSteps(distance,steering,p);
    errors=vecnorm(discrete-rk.front,2,2);
    maxErrors(k)=max(errors); rmsErrors(k)=sqrt(mean(errors.^2));
end
assert(all(diff(maxErrors)<0),'Midpoint circular steps should converge on this smooth example.');
assert(maxErrors(end)<0.01);
% A zero leading matrix entry does not imply a singular linear system.
% This checks the mathematics discussed in the lecture, not an unseen helper.
matrix=[0,1;1,0]; rhs=[2;3]; solution=matrix\rhs;
linearResidual=norm(matrix*solution-rhs);
assert(linearResidual<1e-14 && isequal(solution,[3;2]));
report=struct('scope','Lecture inverse formulas, analytic examples and independent midpoint/RK4 comparison; not 2.5.1 or 3.1.2 EXE equivalence.', ...
    'phaseMaxErrorRAD',max(abs(phase-a)), ...
    'steeringMaxErrorRAD',max(abs(recoveredDelta-delta)), ...
    'wheelDistancePerRevolutionMM',s(end), ...
    'constantTurnMaxDifferencesMM',constantErrors, ...
    'sampleCounts',counts,'variableTurnMaxDifferencesMM',maxErrors, ...
    'variableTurnRMSDifferencesMM',rmsErrors, ...
    'zeroLeadingEntryLinearSolveResidual',linearResidual);
out=fullfile(root,'outputs','video_inverse'); if ~isfolder(out), mkdir(out); end
writetable(table(counts,maxErrors,rmsErrors,'VariableNames', ...
    {'SampleCount','MaxPairedDifference_mm','RMSPairedDifference_mm'}),fullfile(out,'step_convergence.csv'));
fid=fopen(fullfile(out,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fprintf('VIDEO_INVERSE_PASS: polar recovery, flat inverse, straight/left/right and circular-step convergence checked.\n');
disp(report);
end

function c=makeCam(distance,steering,p)
c=struct('workPhi',2*distance/(p.wheelDiameter*p.gearRatio), ...
    'workRadius',p.referenceDiameter/2+camdesign.lift(steering,p), ...
    'effectiveRatio',p.gearRatio);
end

function front=circularSteps(distance,steering,p)
L=-p.driveY; rear=[-L,0]; heading=0; front=zeros(numel(distance),2);
for j=2:numel(distance)
    step=distance(j)-distance(j-1); angle=(steering(j)+steering(j-1))/2;
    if abs(angle)<1e-9
        rear=rear+step*[cos(heading),sin(heading)];
    else
        radius=L/tan(angle); rotation=step/(radius+p.driveX);
        center=rear+radius*[-sin(heading),cos(heading)];
        matrix=[cos(rotation),sin(rotation);-sin(rotation),cos(rotation)];
        rear=center+(rear-center)*matrix;
        heading=heading+rotation;
    end
    front(j,:)=rear+L*[cos(heading),sin(heading)];
end
end
