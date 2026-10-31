function report=check_bezier_precision_core()
% Numerical contracts and fixed-curve comparison; no optimization or UI.
assert(batchStartupOptionUsed,'cam:PrecisionBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','bezier_precision_20261031','core');
assert(~isfile(fullfile(folder,'verification.json')),'cam:PrecisionEvidenceExists','Preserve previous core evidence.');
if ~isfolder(folder), mkdir(folder); end
baseline=fullfile(root,'local','bezier_precision_baseline'); savedPath=path;
restorePath=onCleanup(@()path(savedPath)); addpath(baseline,'-begin');
savedFolder=pwd; restoreFolder=onCleanup(@()cd(savedFolder)); cd(baseline);
assert(startsWith(which('camdesign.route'),baseline));
quality=load(fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'),'q');
paired=load(fullfile(root,'outputs','path_comparison_20261031','seed1_bezier5.mat'),'q');
projects={quality.q,paired.q}; labels={'quality_bezier','paired_seed1_bezier5'};
oldC=load(fullfile(root,'outputs','model_mapping_20261031','quality_cubic','result.mat'),'q');
legacyProjects={oldC.q};
oldB=load(fullfile(root,'outputs','path_comparison_20261031','seed1_bspline3.mat'),'q');
legacyProjects{2}=oldB.q; oldB=load(fullfile(root,'outputs','path_comparison_20261031','seed1_bspline5.mat'),'q');
legacyProjects{3}=oldB.q; legacy=cell(size(legacyProjects)); oldJets=cell(size(projects));
for k=1:numel(legacyProjects)
    p=legacyProjects{k}.params; p.samples=601; p.camSamples=721;
    r=camdesign.route(legacyProjects{k}.nodes,p); c=camdesign.camProfile(r,p);
    legacy{k}=struct('p',p,'route',r,'cam',c,'sim',camdesign.simulate(c,p,r.front(1,:),r.heading(1)));
end
for k=1:numel(projects)
    p=projects{k}.params; u=linspace(0,p.bezier.parameterLength,2053)';
    [F,V,A]=camdesign.bezierRoute(projects{k}.nodes,p,u); oldJets{k}=struct('u',u,'F',F,'V',V,'A',A);
end
cd(root); rmpath(baseline);
clear('camdesign.route','camdesign.camProfile','camdesign.simulate','camdesign.bezierRoute', ...
    'camdesign.routeGeometry','camdesign.independentBezierBasis');
assert(startsWith(which('camdesign.route'),fullfile(root,'+camdesign')));
groups={};
for k=1:numel(legacyProjects)
    p=legacy{k}.p; r=camdesign.route(legacyProjects{k}.nodes,p); c=camdesign.camProfile(r,p);
    s=camdesign.simulate(c,p,r.front(1,:),r.heading(1));
    assert(isequaln(r,legacy{k}.route) && isequaln(c,legacy{k}.cam) && isequaln(s,legacy{k}.sim));
end
groups{end+1}='cubic, B3 and B5 route/cam/theoretical simulation bitwise unchanged';

jetErrors=zeros(2,4);
for k=1:numel(projects)
    p=projects{k}.params; u=oldJets{k}.u;
    [F,V,A,J]=camdesign.bezierRoute(projects{k}.nodes,p,u);
    assert(isequal(F,oldJets{k}.F) && isequal(V,oldJets{k}.V) && isequal(A,oldJets{k}.A));
    [I0,I1,I2,I3]=independentJets(projects{k}.nodes,p,u);
    jetErrors(k,:)=[max(vecnorm(F-I0,2,2)),max(vecnorm(V-I1,2,2)), ...
        max(vecnorm(A-I2,2,2)),max(vecnorm(J-I3,2,2))];
    assert(jetErrors(k,1)<1e-8 && max(jetErrors(k,2:4))<1e-10);
end
groups{end+1}='saved Bezier D0-D2 bitwise preserved; D0-D3 independent de Casteljau jets';
for degree=[3 5 7 15 49]
    n=degree+6; u=unique([linspace(0,n-1,301)';(0:n-1)']);
    [B,D,A,J]=camdesign.independentBezierBasis(n,degree,u);
    assert(max(abs(sum(B,2)-1))<1e-12 && max(abs(sum(J,2)))<1e-8);
    assert(max(abs(J*(0:n-1)'))<1e-7);
    for point=[0 degree/2 n-1]
        [b,d,a,j]=camdesign.independentBezierBasis(n,degree,point);
        [bb,dd,aa,jj]=camdesign.independentBezierBasis(n,degree,[point;point]);
        assert(isequal(b,bb(1,:)) && isequal(d,dd(1,:)) && isequal(a,aa(1,:)) && isequal(j,jj(1,:)));
    end
end
groups{end+1}='D3 partition/linear reproduction, degree3-49, scalar/endpoints and cache';

x=[0;.13;.6;1.7;2.1]; coefficients=[.1 1 -4 3 2 50];
v=polyval(coefficients,x); d=polyval(polyder(coefficients),x); dd=polyval(polyder(polyder(coefficients)),x);
[pp,info]=camdesign.quinticHermitePP(x,v,d,dd); probe=linspace(0,x(end),501)';
hermiteError=max(abs(ppval(pp,probe)-polyval(coefficients,probe)));
assert(hermiteError<1e-10 && info.minimumAllowedPhaseStepRad>=1e-10);
invalid=struct('tinyPhase',expect(@()camdesign.quinticHermitePP([0;1e-12],[50;50],[0;0],[0;0]),'cam:ConstraintNonfinite'), ...
    'duplicatePhase',expect(@()camdesign.quinticHermitePP([0;0],[50;50],[0;0],[0;0]),'cam:ConstraintNonfinite'), ...
    'sampleCap',expect(@()camdesign.quinticHermitePP((0:20001)',zeros(20002,1),zeros(20002,1),zeros(20002,1)),'cam:ConstraintNonfinite'));
groups{end+1}='exact quintic Hermite polynomial and explicit unresolved phase/sample cap rejection';

p=projects{1}.params; u=linspace(0,1000,101)'; R=1500; beta=u/R; delta=asin(-p.driveY/R);
v=[cos(beta),sin(beta)]; a=[-sin(beta),cos(beta)]/R; j=-v/R^2;
for mechanism={'flat','rack'}
    p.mechanism=mechanism{1}; motion=camdesign.analyticCamMotion(v,a,j,beta-delta,p);
    expected=p.referenceDiameter/2+camdesign.lift(delta,p);
    assert(max(abs(motion.q-expected))<1e-11 && max(abs(motion.qPhi))<1e-9 && max(abs(motion.qPhiPhi))<1e-8);
end
groups{end+1}='flat and rack analytic constant steering chain rules';

diagnoses=cell(size(projects)); comparisons=cell(size(projects)); inverseErrors=cell(size(projects));
for candidate=1:numel(projects)
    source=load(fullfile(root,'outputs','bezier_precision_20261031',[labels{candidate} '_diagnosis.mat']), ...
        'ref','refCurve','commonPhi','adaptive','item','project');
    project=projects{candidate}; assert(isequaln(source.project,project));
    counts=[601 2401 4801 9601]; camCounts=[721 2881 5761 11521]; rows=struct([]); inverse=zeros(size(counts));
    for k=1:numel(counts)
        p=project.params; p.samples=counts(k); p.camSamples=camCounts(k);
        route=camdesign.route(project.nodes,p); cam=camdesign.camProfile(route,p);
        state=deval(source.adaptive,route.u)'; curve=camAt(cam,p,source.commonPhi);
        old=source.item.grids([source.item.grids.routeSamples]==counts(k));
        returning=source.commonPhi>source.ref.phi(end);
        row=struct('routeSamples',counts(k),'camSamples',camCounts(k), ...
            'oldDriveDistanceMaxErrorMM',old.driveDistanceMaxErrorMM, ...
            'newDriveDistanceMaxErrorMM',max(abs(route.driveDistance-state(:,2))), ...
            'oldReturnOutlineErrorMM',old.productionReturnOutlineErrorMM, ...
            'newReturnOutlineErrorMM',max(vecnorm(curve.actual(returning,:)-source.refCurve.actual(returning,:),2,2)), ...
            'newAllOutlineErrorMM',max(vecnorm(curve.actual-source.refCurve.actual,2,2)), ...
            'oldCommonMaxPressureDeg',old.productionCommonMaxPressureDeg,'newCommonMaxPressureDeg',max(curve.pressureDeg), ...
            'oldCommonMinUndercutMargin',old.productionCommonMinUndercutMargin,'newCommonMinUndercutMargin',min(curve.undercutMargin), ...
            'oldReturnDeg',old.productionReturnDeg,'newReturnDeg',cam.actualReturnDeg, ...
            'q1EndpointMaxError',max(abs(cam.workEndpointFirst-source.ref.q1([1 end]))), ...
            'q2EndpointMaxError',max(abs(cam.workEndpointSecond-source.ref.q2([1 end]))), ...
            'seamJetResidual',seam(cam),'numericalMethod',cam.numericalMethod);
        assert(strcmp(route.numericalMethod,'bezier-analytic-d3-coupled-rk4-v1') && isfield(cam,'workPP'));
        assert(row.newReturnOutlineErrorMM<row.oldReturnOutlineErrorMM/1000);
        assert(max(row.seamJetResidual)<1e-7);
        sim=camdesign.simulate(cam,p,route.front(1,:),route.heading(1));
        inverse(k)=max(vecnorm(sim.sensor-route.sensor,2,2));
        if k==1, rows=row; else, rows(k)=row; end
        fprintf('%s N=%d old/new returnXY %.9g/%.9g mm; new totalXY %.9g mm; inverse %.9g mm\n', ...
            labels{candidate},counts(k),row.oldReturnOutlineErrorMM,row.newReturnOutlineErrorMM,row.newAllOutlineErrorMM,inverse(k));
    end
    assert(rows(end).newAllOutlineErrorMM<5e-6 && rows(end).newDriveDistanceMaxErrorMM<1e-5);
    assert(rows(end).q2EndpointMaxError<1e-4 && inverse(end)<.01);
    comparisons{candidate}=struct('label',labels{candidate},'reference',source.item.reference,'grids',rows);
    inverseErrors{candidate}=inverse; diagnoses{candidate}=source;
end
groups{end+1}='two unchanged saved curves: native/4x/8x/16x, independent integration, work/return outline, C2 seam';

% Variable motion: finite differences in physical phase independently check
% q_phi and q_phiphi for each lift law using the adaptive saved reference.
source=diagnoses{1}; project=projects{1}; p=project.params; len=p.bezier.parameterLength;
query=len*[.173;.387;.623;.847]; state=deval(source.adaptive,query)';
[~,v,a,j]=independentJets(project.nodes,p,query); phi=2*state(:,2)/(p.wheelDiameter*p.gearRatio);
chainErrors=zeros(2,2); mechanismNames={'flat','rack'}; phaseStep=1e-4;
for k=1:2
    p.mechanism=mechanismNames{k}; motion=camdesign.analyticCamMotion(v,a,j,state(:,1),p);
    recovered=zeros(numel(query),5);
    for index=1:numel(query)
        for offset=-2:2
            target=phi(index)+offset*phaseStep;
            parameter=fzero(@(u)2*deval(source.adaptive,u,2)/(p.wheelDiameter*p.gearRatio)-target,[0 len],optimset('TolX',1e-11));
            theta=deval(source.adaptive,parameter,1); [~,velocity]=independentJets(project.nodes,p,parameter);
            angle=atan2(sin(atan2(velocity(2),velocity(1))-theta),cos(atan2(velocity(2),velocity(1))-theta));
            recovered(index,offset+3)=p.referenceDiameter/2+camdesign.lift(angle,p);
        end
    end
    fd1=(recovered(:,1)-8*recovered(:,2)+8*recovered(:,4)-recovered(:,5))/(12*phaseStep);
    fd2=(-recovered(:,5)+16*recovered(:,4)-30*recovered(:,3)+16*recovered(:,2)-recovered(:,1))/(12*phaseStep^2);
    chainErrors(k,:)=[max(abs(motion.qPhi-fd1)),max(abs(motion.qPhiPhi-fd2))];
    assert(chainErrors(k,1)<1e-5 && chainErrors(k,2)<.002);
end
groups{end+1}='flat and rack variable motion against independent physical-phase finite differences';

project=projects{1}; p=project.params; p.samples=2401; p.camSamples=2881;
r=camdesign.route(project.nodes,p); cam=camdesign.camProfile(r,p);
sim=camdesign.simulate(cam,p,r.front(1,:),r.heading(1));
poison=cam; poison.workRadius=NaN; poison.radius=NaN; poison.pitch='unused';
isolated=camdesign.simulate(poison,p,r.front(1,:),r.heading(1));
assert(isequaln(sim,isolated));
shifted=camdesign.simulate(cam,p,r.front(1,:),r.heading(1),GearRatio=36);
assert(abs(shifted.driveDistance(end)/sim.driveDistance(end)-36/35)<1e-12);
assert(max(vecnorm(shifted.sensor-sim.sensor,2,2))>1);
assert(p.gearRatio==35 && isequaln(project,projects{1}));
groups{end+1}='saved workPP controls theoretical simulation; legacy radius poisoning and explicit ratio scaling';
actual=camdesign.simulateActual(cam,p,r.front(1,:),r.heading(1),Samples=201);
poison.workPP='forbidden'; poison.workEndpointFirst=NaN; poison.workEndpointSecond=NaN;
actualPoison=camdesign.simulateActual(poison,p,r.front(1,:),r.heading(1),Samples=201);
assert(isequaln(actual,actualPoison));
groups{end+1}='actual-contact simulation ignores poisoned workPP and all theoretical radius fields';

report=struct('release',version('-release'),'baseline','100c44d','checksPassed',numel(groups),'checks',{groups}, ...
    'independentCurveJetErrors',jetErrors,'exactQuinticMaxErrorMM',hermiteError, ...
    'flatRackVariableChainErrors',chainErrors,'invalidCases',invalid,'fixedCurves',{comparisons}, ...
    'inverseSensorErrorsMM',{inverseErrors},'theoreticalPoisonIsolationExact',true,'actualPoisonIsolationExact',true, ...
    'trainingRuns',0,'scope','Independent finite tolerance numerical reference and sampled fixed curves only; no continuous global extrema, machining, vehicle or optimized-quality certification.');
save(fullfile(folder,'results.mat'),'report');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('BEZIER_PRECISION_CORE_PASS checks=%d chainQ1err=%.9g chainQ2err=%.9g\n',numel(groups),max(chainErrors(:,1)),max(chainErrors(:,2)));
end

function out=camAt(c,p,phi)
active=phi<=c.workEnd; q=zeros(size(phi)); d=q; dd=q;
q(active)=ppval(c.workPP,phi(active));
d(active)=ppval(camdesign.ppDerivative(c.workPP,1),phi(active));
dd(active)=ppval(camdesign.ppDerivative(c.workPP,2),phi(active));
gap=2*pi-c.workEnd; t=(phi(~active)-c.workEnd)/gap; coefficient=c.returnCoefficients(:)';
q(~active)=polyval(fliplr(coefficient),t);
d(~active)=polyval(fliplr((1:5).*coefficient(2:6)),t)/gap;
dd(~active)=polyval(fliplr((2:5).*(1:4).*coefficient(3:6)),t)/gap^2;
tangent=[d.*cos(phi)-q.*sin(phi),d.*sin(phi)+q.*cos(phi)];
normal=[tangent(:,2),-tangent(:,1)]./vecnorm(tangent,2,2);
curvature=(q.^2+2*d.^2-q.*dd)./(q.^2+d.^2).^(3/2);
out=struct('actual',q.*[cos(phi),sin(phi)]-p.rollerRadius*normal, ...
    'pressureDeg',rad2deg(atan2(abs(d),q)),'undercutMargin',1-p.rollerRadius*curvature);
end

function residual=seam(c)
gap=2*pi-c.workEnd; coefficient=c.returnCoefficients(:)';
start=[coefficient(1),coefficient(2)/gap,2*coefficient(3)/gap^2];
finish=[sum(coefficient),sum((1:5).*coefficient(2:6))/gap,sum((2:5).*(1:4).*coefficient(3:6))/gap^2];
workFirst=[ppval(c.workPP,0),ppval(camdesign.ppDerivative(c.workPP,1),0),ppval(camdesign.ppDerivative(c.workPP,2),0)];
workLast=[ppval(c.workPP,c.workEnd),ppval(camdesign.ppDerivative(c.workPP,1),c.workEnd),ppval(camdesign.ppDerivative(c.workPP,2),c.workEnd)];
residual=max(abs([start-workLast;finish-workFirst]),[],1);
end

function identifier=expect(callback,wanted)
identifier=''; try, callback(); catch ex, identifier=ex.identifier; end
assert(strcmp(identifier,wanted),'Expected %s, got %s.',wanted,identifier);
end

function [F,V,A,J]=independentJets(nodes,p,u)
% Independent polynomial weight jets, quotient rule, and de Casteljau curves.
u=u(:); n=size(nodes,1); degree=p.bezier.degree; scale=(n-1)/p.bezier.parameterLength;
z=u*scale; raw=zeros(numel(u),2,4); weight=zeros(numel(u),4); windows=n-degree;
for window=1:windows
    t=(z-window+1)/degree; active=t>=-1e-13 & t<=1+1e-13;
    if ~any(active), continue; end
    t=max(0,min(1,t(active))); controls=nodes(window:window+degree,:);
    if windows==1, polynomial=1;
    elseif window==1, polynomial=[1 -4 6 -4 1];
    elseif window==windows, polynomial=[1 0 0 0 0];
    else, polynomial=[1 -4 6 -4 1 0 0 0 0]; end
    w=zeros(numel(t),4); curves=zeros(numel(t),2,4); factor=1;
    for k=0:3
        w(:,k+1)=polyval(derive(polynomial,k),t)/degree^k;
        differences=controls; if k>0, differences=diff(controls,k,1); end
        curves(:,:,k+1)=factor*casteljau(differences,t)/degree^k; factor=factor*(degree-k);
    end
    for k=0:3
        for j=0:k, raw(active,:,k+1)=raw(active,:,k+1)+nchoosek(k,j)*w(:,j+1).*curves(:,:,k-j+1); end
        weight(active,k+1)=weight(active,k+1)+w(:,k+1);
    end
end
jets=zeros(size(raw));
for k=0:3
    value=raw(:,:,k+1);
    for j=1:k, value=value-nchoosek(k,j)*weight(:,j+1).*jets(:,:,k-j+1); end
    jets(:,:,k+1)=value./weight(:,1);
end
correction=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)]-scale*(nodes(2,:)-nodes(1,:));
span=degree/scale; t=u/span; active=t<=1;
for k=0:3
    jets(:,:,k+1)=scale^k*jets(:,:,k+1);
    if any(active), jets(active,:,k+1)=jets(active,:,k+1)+span^(1-k)*polyval(derive([1 -4 6 -4 1 0],k),t(active)).*correction; end
end
F=jets(:,:,1); V=jets(:,:,2); A=jets(:,:,3); J=jets(:,:,4);
end

function out=casteljau(controls,t)
out=zeros(numel(t),2);
for dimension=1:2
    values=repmat(controls(:,dimension)',numel(t),1);
    for left=size(controls,1)-1:-1:1, values=(1-t).*values(:,1:left)+t.*values(:,2:left+1); end
    out(:,dimension)=values;
end
end

function p=derive(p,count)
for k=1:count, p=p(1:end-1).*(numel(p)-1:-1:1); if isempty(p), p=0; end, end
end
