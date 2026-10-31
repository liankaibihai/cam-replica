function report=check_bezier_precision(options)
% Read-only diagnosis. Production algorithms and saved curve data unchanged.
arguments
    options.OutputFolder char=''
end
assert(batchStartupOptionUsed,'cam:PrecisionBatchOnly','Run this historical diagnosis in an independent batch.');
root=fileparts(mfilename('fullpath'));
baseline=fullfile(root,'local','bezier_precision_baseline');
assert(isfolder(fullfile(baseline,'+camdesign')),'cam:PrecisionBaseline','Missing frozen 100c44d package.');
savedPath=path; restorePath=onCleanup(@()path(savedPath)); addpath(baseline,'-begin');
savedFolder=pwd; restoreFolder=onCleanup(@()cd(savedFolder)); cd(baseline);
assert(startsWith(which('camdesign.route'),baseline),'cam:PrecisionBaseline','Historical diagnosis must use frozen baseline package.');
folder=options.OutputFolder;
if isempty(folder), folder=fullfile(root,'outputs','bezier_precision_20261031','baseline_diagnosis'); end
assert(~isfile(fullfile(folder,'diagnosis.json')),'cam:PrecisionEvidenceExists','Choose a fresh OutputFolder to preserve previous evidence.');
if ~isfolder(folder), mkdir(folder); end
files={fullfile(root,'outputs','model_mapping_20261031','quality_bezier','result.mat'), ...
    fullfile(root,'outputs','path_comparison_20261031','seed1_bezier5.mat')};
labels={'quality_bezier','paired_seed1_bezier5'}; items=cell(size(files));
for candidate=1:numel(files)
    loaded=load(files{candidate},'q'); project=loaded.q; original=project; p=project.params;
    assert(strcmp(camdesign.routeModel(p),'bezier-blend-independent-v1') && p.gearRatio==35 && strcmp(p.mechanism,'flat'));
    n=size(project.nodes,1); len=p.bezier.parameterLength; scale=(n-1)/len;
    query=unique([linspace(0,len,2053)';(0:n-1)'/scale]);
    [F,V,A,J]=independentJets(project.nodes,p,query);
    [PF,PV,PA]=camdesign.bezierRoute(project.nodes,p,query);
    derivativeAudit=struct('positionMaxMM',max(vecnorm(F-PF,2,2)), ...
        'velocityMax',max(vecnorm(V-PV,2,2)),'accelerationMax',max(vecnorm(A-PA,2,2)));
    h=len*1e-6; probe=linspace(3*h,len-3*h,103)';
    [~,~,a1]=camdesign.bezierRoute(project.nodes,p,probe-2*h);
    [~,~,a2]=camdesign.bezierRoute(project.nodes,p,probe-h);
    [~,~,a3]=camdesign.bezierRoute(project.nodes,p,probe+h);
    [~,~,a4]=camdesign.bezierRoute(project.nodes,p,probe+2*h);
    [~,~,~,jExact]=independentJets(project.nodes,p,probe);
    derivativeAudit.thirdDerivativeFiniteDifferenceMax=max(vecnorm(jExact-(a1-8*a2+8*a3-a4)/(12*h),2,2));
    assert(derivativeAudit.positionMaxMM<1e-8 && derivativeAudit.velocityMax<1e-10 && derivativeAudit.accelerationMax<1e-10);
    [ends,endV,endA]=camdesign.bezierRoute(project.nodes,p,[0;len]);
    desired=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
    endpointAudit=struct('startPositionErrorMM',norm(ends(1,:)-project.nodes(1,:)), ...
        'endPositionErrorMM',norm(ends(2,:)-project.nodes(end,:)), ...
        'startVelocityError',norm(endV(1,:)-desired), ...
        'endSavedChordVelocityError',norm(endV(2,:)-scale*(project.nodes(end,:)-project.nodes(end-1,:))), ...
        'endVelocity',endV,'endAcceleration',endA, ...
        'scope','Start position/tangent and end position/last-control-chord derivative; no extra terminal heading imposed.');
    assert(max([endpointAudit.startPositionErrorMM endpointAudit.endPositionErrorMM endpointAudit.startVelocityError endpointAudit.endSavedChordVelocityError])<1e-9);

    % Independent adaptive Adams integration, with de Casteljau curve jets.
    odeOptions=odeset('RelTol',2e-12,'AbsTol',[2e-13 2e-9 2e-9]);
    adaptiveCoarse=ode113(@(u,y)carRHS(u,y,project),[0 len],[deg2rad(p.headingDeg);0;0],odeOptions);
    odeOptions=odeset('RelTol',2e-13,'AbsTol',[2e-14 2e-10 2e-10],'MaxStep',len/200);
    adaptive=ode113(@(u,y)carRHS(u,y,project),[0 len],[deg2rad(p.headingDeg);0;0],odeOptions);
    refU=linspace(0,len,19201)'; adaptiveState=deval(adaptive,refU)';
    adaptiveDifference=max(abs(adaptiveState-deval(adaptiveCoarse,refU)'),[],1);
    assert(adaptiveDifference(1)<1e-8 && max(adaptiveDifference(2:3))<1e-5);
    [~,refV,refA,refJ]=independentJets(project.nodes,p,refU);
    ref=jetMotion(refU,adaptiveState(:,1),adaptiveState(:,2),refV,refA,refJ,p);
    ref.frontDistance=adaptiveState(:,3); refCurve=profile(ref,p,[],'analytic');
    commonPhi=linspace(0,2*pi,15361)'; refCurve=profile(ref,p,commonPhi,'analytic');
    work=commonPhi<=ref.phi(end); returning=~work;
    counts=[601 1201 2401 4801 9601 19201]; camCounts=[721 1441 2881 5761 11521 20001];
    rows=struct([]); profiles=cell(size(counts));
    for k=1:numel(counts)
        testP=p; testP.samples=counts(k); testP.camSamples=camCounts(k);
        route=camdesign.route(project.nodes,testP); cam=camdesign.camProfile(route,testP);
        improved=augmentedRK4(project.nodes,testP,counts(k));
        [~,iv,ia,ij]=independentJets(project.nodes,p,improved.u);
        motion=jetMotion(improved.u,improved.heading,improved.driveDistance,iv,ia,ij,p);
        rImproved=route; rImproved.driveDistance=improved.driveDistance;
        production=profile(route,testP,commonPhi,'spline');
        phaseOnly=profile(rImproved,testP,commonPhi,'spline');
        endsOnly=profile(motion,testP,commonPhi,'analytic-ends');
        fullyAnalytic=profile(motion,testP,commonPhi,'analytic');
        state=deval(adaptive,route.u)';
        [~,v,a,j]=independentJets(project.nodes,p,route.u);
        continuous=jetMotion(route.u,state(:,1),state(:,2),v,a,j,p);
        productionQ=cam.workRadius; splinePP=spline(cam.workPhi,productionQ);
        q1=ppval(camdesign.ppDerivative(splinePP,1),cam.workPhi([1 end]));
        q2=ppval(camdesign.ppDerivative(splinePP,2),cam.workPhi([1 end]));
        q1=q1(:); q2=q2(:);
        row=struct('routeSamples',counts(k),'camSamples',camCounts(k), ...
            'headingMaxErrorRad',max(abs(route.heading-state(:,1))), ...
            'driveDistanceMaxErrorMM',max(abs(route.driveDistance-state(:,2))), ...
            'driveDistanceEndErrorMM',route.driveDistance(end)-state(end,2), ...
            'frontDistanceEndErrorMM',route.frontDistance(end)-state(end,3), ...
            'augmentedHeadingMaxErrorRad',max(abs(improved.heading-state(:,1))), ...
            'augmentedDriveDistanceMaxErrorMM',max(abs(improved.driveDistance-state(:,2))), ...
            'augmentedFrontDistanceEndErrorMM',improved.frontDistance(end)-state(end,3), ...
            'splineEndpointQ1',q1,'analyticEndpointQ1',continuous.q1([1 end]), ...
            'splineEndpointQ2',q2,'analyticEndpointQ2',continuous.q2([1 end]), ...
            'endpointQ1MaxError',max(abs(q1-continuous.q1([1 end]))), ...
            'endpointQ2MaxError',max(abs(q2-continuous.q2([1 end]))), ...
            'productionMaxPressureDeg',rad2deg(max(cam.pressure)), ...
            'productionMinUndercutMargin',min(cam.undercutMargin), ...
            'productionReturnDeg',cam.actualReturnDeg,'returnSatisfied',cam.returnAngleSatisfied, ...
            'productionWorkOutlineErrorMM',max(vecnorm(production.actual(work,:)-refCurve.actual(work,:),2,2)), ...
            'productionReturnOutlineErrorMM',max(vecnorm(production.actual(returning,:)-refCurve.actual(returning,:),2,2)), ...
            'phaseOnlyReturnOutlineErrorMM',max(vecnorm(phaseOnly.actual(returning,:)-refCurve.actual(returning,:),2,2)), ...
            'analyticEndsReturnOutlineErrorMM',max(vecnorm(endsOnly.actual(returning,:)-refCurve.actual(returning,:),2,2)), ...
            'analyticAllOutlineErrorMM',max(vecnorm(fullyAnalytic.actual-refCurve.actual,2,2)), ...
            'productionCommonMaxPressureDeg',max(production.pressureDeg), ...
            'productionCommonMinUndercutMargin',min(production.undercutMargin), ...
            'analyticMaxPressureDeg',max(fullyAnalytic.pressureDeg), ...
            'analyticMinUndercutMargin',min(fullyAnalytic.undercutMargin), ...
            'productionSeamJetResidual',production.seamResidual, ...
            'analyticSeamJetResidual',fullyAnalytic.seamResidual, ...
            'productionIntersectionCount',NaN,'analyticIntersectionCount',NaN);
        if ismember(counts(k),[601 4801 9601])
            row.productionIntersectionCount=size(camdesign.selfIntersections(cam.actual),1);
            checkAnalytic=profile(motion,testP,cam.phi,'analytic');
            row.analyticIntersectionCount=size(camdesign.selfIntersections(checkAnalytic.actual),1);
        end
        if k==1, rows=row; else, rows(k)=row; end
        profiles{k}=struct('production',production,'phaseOnly',phaseOnly, ...
            'analyticEnds',endsOnly,'fullyAnalytic',fullyAnalytic);
        fprintf('%s N=%d drive %.9g -> %.9g mm; endpoint q2err %.9g; returnXY %.9g -> %.9g mm\n', ...
            labels{candidate},counts(k),row.driveDistanceMaxErrorMM,row.augmentedDriveDistanceMaxErrorMM, ...
            row.endpointQ2MaxError,row.productionReturnOutlineErrorMM,row.analyticEndsReturnOutlineErrorMM);
    end
    item=struct('label',labels{candidate},'source',files{candidate},'degree',p.bezier.degree, ...
        'controlCount',n,'parameterLengthMM',len,'gearRatio',p.gearRatio, ...
        'derivativeAudit',derivativeAudit,'endpointAudit',endpointAudit,'grids',rows, ...
        'reference',struct('integrator','ode113 independent de Casteljau curve, RelTol 2e-13, AbsTol theta2e-14/distance2e-10, MaxStep parameterLength/200', ...
        'toleranceRefinementMaxHeadingDifferenceRad',adaptiveDifference(1), ...
        'toleranceRefinementMaxDriveDistanceDifferenceMM',adaptiveDifference(2), ...
        'toleranceRefinementMaxFrontDistanceDifferenceMM',adaptiveDifference(3), ...
        'workEndDeg',rad2deg(ref.phi(end)),'returnDeg',rad2deg(2*pi-ref.phi(end)), ...
        'maxPressureDeg',max(refCurve.pressureDeg),'minUndercutMargin',min(refCurve.undercutMargin), ...
        'endpointQ1',ref.q1([1 end]),'endpointQ2',ref.q2([1 end]),'seamJetResidual',refCurve.seamResidual), ...
        'savedProjectUnchanged',isequaln(original,project));
    items{candidate}=item;
    save(fullfile(folder,[labels{candidate} '_diagnosis.mat']),'item','project','ref','commonPhi','refCurve','profiles','adaptive');
end
report=struct('baseline','100c44d','release',version('-release'),'candidates',{items}, ...
    'trainingRuns',0,'productionCodeChanged',false, ...
    'units','Position and distance: mm; q1: mm/rad; q2: mm/rad^2; curve derivatives use the saved parameterLength in mm.', ...
    'ablation','phaseOnly=RK4 drive integral plus old working spline/return jets; analyticEnds=RK4 drive plus old work spline and analytic return jets; analyticAll=RK4 drive plus quintic Hermite work and analytic return jets. All compared on the same physical phase grid.', ...
    'scope','Fixed saved Bezier curves and unchanged physical parameters; independent analytical D0-D3, adaptive integration and sampled cam diagnostics. No optimized candidate, real-car certification or continuous global extrema claim.');
fid=fopen(fullfile(folder,'diagnosis.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('BEZIER_PRECISION_DIAGNOSIS_COMPLETE candidates=%d training=0 productionChanged=0\n',numel(items));
end

function out=carRHS(u,y,project)
p=project.params; [~,v]=independentJets(project.nodes,p,u,1);
rate=(-v(1)*sin(y(1))+v(2)*cos(y(1)))/(-p.driveY);
out=[rate;v(1)*cos(y(1))+v(2)*sin(y(1))+p.driveX*rate;norm(v)];
end

function result=augmentedRK4(nodes,p,count)
len=p.bezier.parameterLength; u=linspace(0,len,count)'; mid=(u(1:end-1)+u(2:end))/2;
[~,v]=camdesign.bezierRoute(nodes,p,u); [~,vm]=camdesign.bezierRoute(nodes,p,mid);
y=zeros(count,3); y(1,1)=deg2rad(p.headingDeg);
for k=1:count-1
    h=u(k+1)-u(k); state=y(k,:);
    k1=rhs(state,v(k,:)); k2=rhs(state+h*k1/2,vm(k,:));
    k3=rhs(state+h*k2/2,vm(k,:)); k4=rhs(state+h*k3,v(k+1,:));
    y(k+1,:)=state+h*(k1+2*k2+2*k3+k4)/6;
end
result=struct('u',u,'heading',y(:,1),'driveDistance',y(:,2),'frontDistance',y(:,3));
    function value=rhs(state,velocity)
        rate=(-velocity(1)*sin(state(1))+velocity(2)*cos(state(1)))/(-p.driveY);
        value=[rate,velocity(1)*cos(state(1))+velocity(2)*sin(state(1))+p.driveX*rate,norm(velocity)];
    end
end

function r=jetMotion(u,heading,distance,v,a,j,p)
L=-p.driveY; co=cos(heading); si=sin(heading);
heading1=(-v(:,1).*si+v(:,2).*co)/L;
forward=v(:,1).*co+v(:,2).*si; lateral=-v(:,1).*si+v(:,2).*co;
heading2=(-a(:,1).*si+a(:,2).*co-forward.*heading1)/L;
speed2=sum(v.^2,2); cross=v(:,1).*a(:,2)-v(:,2).*a(:,1);
beta1=cross./speed2;
beta2=(v(:,1).*j(:,2)-v(:,2).*j(:,1))./speed2-2*cross.*sum(v.*a,2)./speed2.^2;
delta=atan2(sin(atan2(v(:,2),v(:,1))-heading),cos(atan2(v(:,2),v(:,1))-heading));
delta1=beta1-heading1; delta2=beta2-heading2;
speed=forward+p.driveX*heading1;
speed1=a(:,1).*co+a(:,2).*si+lateral.*heading1+p.driveX*heading2;
phi1=2*speed/(p.wheelDiameter*p.gearRatio); phi2=2*speed1/(p.wheelDiameter*p.gearRatio);
q=p.referenceDiameter/2+p.lever*tan(delta);
qu=p.lever*(1+tan(delta).^2).*delta1;
quu=p.lever*(1+tan(delta).^2).*(delta2+2*tan(delta).*delta1.^2);
r=struct('u',u,'heading',heading,'driveDistance',distance,'steering',delta, ...
    'phi',2*distance/(p.wheelDiameter*p.gearRatio),'q',q, ...
    'q1',qu./phi1,'q2',(quu.*phi1-qu.*phi2)./phi1.^3);
end

function out=profile(r,p,phase,mode)
analytic=isfield(r,'q');
if analytic, phi=r.phi; q=r.q; else, phi=2*r.driveDistance/(p.wheelDiameter*p.gearRatio); q=p.referenceDiameter/2+camdesign.lift(r.steering,p); end
if strcmp(mode,'analytic')
    h=diff(phi); coeff=quintic(q(1:end-1),q(2:end),r.q1(1:end-1),r.q1(2:end),r.q2(1:end-1),r.q2(2:end),h);
    powers=0:5; pp=mkpp(phi,fliplr(coeff./h.^powers));
else, pp=spline(phi,q); end
pp1=camdesign.ppDerivative(pp,1); pp2=camdesign.ppDerivative(pp,2);
if analytic
    e1=r.q1([1 end]); e2=r.q2([1 end]);
else
    e1=ppval(pp1,phi([1 end])); e2=ppval(pp2,phi([1 end]));
end
gap=2*pi-phi(end);
coeff=quintic(q(end),q(1),e1(end),e1(1),e2(end),e2(1),gap);
if isempty(phase), phase=linspace(0,2*pi,p.camSamples)'; end
active=phase<=phi(end); value=zeros(size(phase)); first=value; second=value;
value(active)=ppval(pp,phase(active)); first(active)=ppval(pp1,phase(active)); second(active)=ppval(pp2,phase(active));
t=(phase(~active)-phi(end))/gap;
value(~active)=polyval(fliplr(coeff),t);
first(~active)=polyval(fliplr((1:5).*coeff(2:6)),t)/gap;
second(~active)=polyval(fliplr((2:5).*(1:4).*coeff(3:6)),t)/gap^2;
tangent=[first.*cos(phase)-value.*sin(phase),first.*sin(phase)+value.*cos(phase)];
normal=[tangent(:,2),-tangent(:,1)]./vecnorm(tangent,2,2);
pitch=value.*[cos(phase),sin(phase)];
curvature=(value.^2+2*first.^2-value.*second)./(value.^2+first.^2).^(3/2);
returnEnd=[sum(coeff),sum((1:5).*coeff(2:6))/gap,sum((2:5).*(1:4).*coeff(3:6))/gap^2];
returnStart=[coeff(1),coeff(2)/gap,2*coeff(3)/gap^2];
seam=max(abs([returnStart-[q(end),e1(end),e2(end)];returnEnd-[q(1),e1(1),e2(1)]]),[],1);
out=struct('actual',pitch-p.rollerRadius*normal,'radius',value,'q1',first,'q2',second, ...
    'pressureDeg',rad2deg(atan2(abs(first),value)),'undercutMargin',1-p.rollerRadius*curvature, ...
    'workEnd',phi(end),'returnCoefficients',coeff,'seamResidual',seam);
end

function c=quintic(a,b,da,db,dda,ddb,h)
c=[a,h.*da,h.^2.*dda/2,zeros(numel(a),3)];
rhs=[b-sum(c(:,1:3),2),h.*db-c(:,2)-2*c(:,3),h.^2.*ddb-2*c(:,3)];
c(:,4:6)=rhs/[1 3 6;1 4 12;1 5 20];
end

function [F,V,A,J]=independentJets(nodes,p,u,order)
% De Casteljau curves plus polynomial weight jets; quotient product rule.
% Independent from production Bernstein basis and its derivative formulas.
if nargin<4, order=3; end
u=u(:); count=size(nodes,1); degree=p.bezier.degree; sigma=(count-1)/p.bezier.parameterLength;
z=u*sigma; raw=zeros(numel(u),2,order+1); weights=zeros(numel(u),order+1);
windows=count-degree;
for window=1:windows
    t=(z-window+1)/degree; active=t>=-1e-13 & t<=1+1e-13;
    if ~any(active), continue; end
    t=max(0,min(1,t(active))); controls=nodes(window:window+degree,:);
    if windows==1, polynomial=1;
    elseif window==1, polynomial=[1 -4 6 -4 1];
    elseif window==windows, polynomial=[1 0 0 0 0];
    else, polynomial=[1 -4 6 -4 1 0 0 0 0]; end
    w=zeros(numel(t),order+1); curves=zeros(numel(t),2,order+1); factor=1;
    for k=0:order
        w(:,k+1)=polyval(polyDerivative(polynomial,k),t)/degree^k;
        differences=controls; if k>0, differences=diff(controls,k,1); end
        curves(:,:,k+1)=factor*deCasteljau(differences,t)/degree^k;
        factor=factor*(degree-k);
    end
    for k=0:order
        for j=0:k
            raw(active,:,k+1)=raw(active,:,k+1)+nchoosek(k,j)*w(:,j+1).*curves(:,:,k-j+1);
        end
        weights(active,k+1)=weights(active,k+1)+w(:,k+1);
    end
end
jets=zeros(size(raw));
for k=0:order
    value=raw(:,:,k+1);
    for j=1:k, value=value-nchoosek(k,j)*weights(:,j+1).*jets(:,:,k-j+1); end
    jets(:,:,k+1)=value./weights(:,1);
end
correction=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)]-sigma*(nodes(2,:)-nodes(1,:));
span=degree/sigma; t=u/span; active=t<=1;
for k=0:order
    jets(:,:,k+1)=sigma^k*jets(:,:,k+1);
    polynomial=polyDerivative([1 -4 6 -4 1 0],k);
    if any(active)
        jets(active,:,k+1)=jets(active,:,k+1)+span^(1-k)*polyval(polynomial,t(active)).*correction;
    end
end
F=jets(:,:,1); V=jets(:,:,2); A=[]; J=[];
if order>=2, A=jets(:,:,3); end
if order>=3, J=jets(:,:,4); end
end

function out=deCasteljau(controls,t)
out=zeros(numel(t),size(controls,2));
for dimension=1:size(controls,2)
    values=repmat(controls(:,dimension)',numel(t),1);
    for remaining=size(controls,1)-1:-1:1
        values=(1-t).*values(:,1:remaining)+t.*values(:,2:remaining+1);
    end
    out(:,dimension)=values;
end
end

function polynomial=polyDerivative(polynomial,count)
for k=1:count
    polynomial=polynomial(1:end-1).*(numel(polynomial)-1:-1:1);
    if isempty(polynomial), polynomial=0; end
end
end
