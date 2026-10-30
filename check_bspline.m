function report=check_bspline()
% Analytic geometry and endpoint/optimizer contracts; no quality comparison.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:BSplineBatchOnly','请用独立batch运行。');
folder=fullfile(root,'outputs','bspline_20261031','contracts'); if ~isfolder(folder), mkdir(folder); end
checks={};
for d=[3 5]
    n=12; T=500; breaks=linspace(0,T,n-d+1); knots=[zeros(1,d+1),breaks(2:end-1),T*ones(1,d+1)];
    u=linspace(0,T,501)'; [B,D,A,J]=camdesign.bsplineBasis(knots,d,u);
    assert(max(abs(sum(B,2)-1))<1e-13 && min(B,[],'all')>=-1e-14);
    assert(max(abs(sum(D,2)))<1e-14 && max(abs(sum(A,2)))<1e-14 && max(abs(sum(J,2)))<1e-14);
    assert(B(1,1)==1 && B(end,end)==1);
    for index=[1 143 501]
        [b,v,a,j]=camdesign.bsplineBasis(knots,d,u(index));
        assert(isequal(b,B(index,:)) && isequal(v,D(index,:)) && isequal(a,A(index,:)) && isequal(j,J(index,:)));
    end
    query=[17.31;135.27;463.19]; h=1e-3;
    [~,v,a,j]=camdesign.bsplineBasis(knots,d,query);
    [bP,vP,aP]=camdesign.bsplineBasis(knots,d,query+h);
    [bM,vM,aM]=camdesign.bsplineBasis(knots,d,query-h);
    assert(max(abs(v-(bP-bM)/(2*h)),[],'all')<2e-10);
    assert(max(abs(a-(vP-vM)/(2*h)),[],'all')<2e-11);
    assert(max(abs(j-(aP-aM)/(2*h)),[],'all')<2e-12);
    for knot=breaks(2:end-1)
        [bl,vl,al,jl]=camdesign.bsplineBasis(knots,d,knot-1e-7);
        [br,vr,ar,jr]=camdesign.bsplineBasis(knots,d,knot+1e-7);
        assert(max(abs(bl-br))<1e-7 && max(abs(vl-vr))<1e-8 && max(abs(al-ar))<1e-9);
        if d==5, assert(max(abs(jl-jr))<1e-10); end
    end
end
% Independent Bernstein polynomial oracle on one clamped span, D0...D3.
for d=[3 5]
    t=linspace(0,1,101)'; T=7; knots=[zeros(1,d+1),T*ones(1,d+1)];
    [B,D,A,J]=camdesign.bsplineBasis(knots,d,T*t);
    for k=0:3
        oracle=zeros(numel(t),d+1);
        for i=0:d
            for a=0:k
                j=i-a;
                if j>=0 && j<=d-k
                    oracle(:,i+1)=oracle(:,i+1)+(-1)^(k-a)*nchoosek(k,a)* ...
                        factorial(d)/factorial(d-k)/T^k*nchoosek(d-k,j).*t.^j.*(1-t).^(d-k-j);
                end
            end
        end
        actual={B,D,A,J}; assert(max(abs(actual{k+1}-oracle),[],'all')<2e-13);
    end
end
checks{end+1}='partition of unity, analytic D1-D3, scalar/endpoints, Bernstein oracle and knot joins';

p=fixture(); source=p; T=500; s=[0;250;500];
source.nodes=[200+1e-5*s.^2,200+s-1e-7*s.^3];
source.params.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',s,'endDerivative',[.01,.925]);
fits=cell(1,2);
for index=1:2
    d=[3 5]; [b,fit]=camdesign.toBSpline(source,10,d(index)); fits{index}=fit;
    assert(fit.positionMaxMM<2e-9 && max(fit.endpointDerivativeError)<1e-10 && fit.effectiveDOF==14);
    u=linspace(0,T,301)'; [F,V,A,J]=camdesign.bsplineRoute(b.nodes,b.params,u);
    assert(max(vecnorm(F-[200+1e-5*u.^2,200+u-1e-7*u.^3],2,2))<2e-9);
    assert(max(vecnorm(V-[2e-5*u,1-3e-7*u.^2],2,2))<2e-10);
    assert(max(vecnorm(A-[repmat(2e-5,size(u)),-6e-7*u],2,2))<2e-10);
    assert(max(vecnorm(J-[zeros(size(u)),repmat(-6e-7,size(u))],2,2))<2e-10);
    rb=camdesign.route(b.nodes,b.params); rs=camdesign.route(source.nodes,source.params);
    assert(max(vecnorm(rb.front-rs.front,2,2))<2e-9 && max(abs(rb.steering-rs.steering))<1e-10);
    [resized,resizeInfo]=camdesign.setControlPointCount(b,12);
    assert(size(resized.nodes,1)==12 && ~resizeInfo.shapePreservationGuaranteed);
    [resized,~]=camdesign.setControlPointCount(resized,8); camdesign.validateProject(resized);
end
checks{end+1}='exact quadratic/cubic polynomial conversion, derivatives, route integration and explicit count refit';

solar=camdesign.solarTestProject(); solar=camdesign.refineRoute(solar); solar=camdesign.refineRoute(solar);
solarFits=cell(1,2);
for index=1:2
    degrees=[3 5]; [b,solarFits{index}]=camdesign.toBSpline(solar,36,degrees(index));
    map=camdesign.optimizationVariables(b); assert(map.effectiveDOF==66 && map.constraintRank==6);
    assert(norm(b.nodes(1,:)-solar.nodes(1,:))<1e-8);
end
checks{end+1}='formal solar geometry converts with measured fit error and 66 effective variables';

% Legacy objective and explicit regularizer switch leave physical constraints identical.
ref=p.nodes; ref(2,1)=ref(2,1)+2;
m=camdesign.fminconModel(p,ref); zero=camdesign.fminconModel(p,ref,[],0);
assert(m.valid && zero.valid && isequal(m.constraints,zero.constraints));
assert(abs(m.objective-zero.objective-1e-4*m.objectiveParts(3))<1e-12);
assert(camdesign.controlBounds(p).enforced);
outside=p; outside.params.bounds=[205 1000 0 1000];
a=camdesign.fminconModel(outside,outside.nodes); assert(a.maxNodeBoundViolation>0);
outside.params.controlBoundsPolicy='trajectory-only-v1';
b=camdesign.fminconModel(outside,outside.nodes);
assert(b.maxNodeBoundViolation==0 && ~b.controlBounds.satisfied && ~b.controlBounds.enforced);
v=camdesign.verifyConstrained(outside,2);
assert(~v.nodeBoundsSatisfied && v.controlBoundsGatePassed && ~v.verifiedFeasible && ~v.trajectoryBoundsSatisfied);
checks{end+1}='legacy objective/bounds default retained; explicit regularizer and trajectory-only policy keep physical constraints';

% Actual solver probes and callbacks cannot release endpoint coordinates.
for d=[3 5]
    [b,~]=camdesign.toBSpline(p,8,d); b.params.iterations=2;
    reference=b; count=0;
    [best,h,info]=camdesign.optimizeFmincon(b,@inspect,MaxFunctionEvaluations=100,MaxSeconds=20, ...
        RefinementFactor=2,RegularizationWeight=0,EndDerivative=[0 1]);
    assert(count>=2 && info.endpointConstraintRank==6 && info.effectiveDOF==10 && info.regularizationWeight==0);
    assert(isequal(best.nodes(1,:),b.nodes(1,:)) && ~isempty(h) && info.parametersUnchanged);
end
% Legacy Bezier's exact final derivative gets two fewer independent variables.
z=camdesign.applyTrainingSettings(p,struct('routeModel','bezier-blend-independent-v1','controlPointCount',8,'bezierDegree',3));
z.nodes(end-1,:)=z.nodes(end,:)-[0 1]*z.params.bezier.parameterLength/7;
map=camdesign.optimizationVariables(z,[0 1]); assert(map.effectiveDOF==12 && map.constraintRank==4);
reference=z; count=0; z.params.iterations=1; reference=z;
[~,~,info]=camdesign.optimizeFmincon(z,@inspect,MaxFunctionEvaluations=40,MaxSeconds=20,RefinementFactor=2,EndDerivative=[0 1]);
assert(count>=2 && info.effectiveDOF==12);
checks{end+1}='real short inner-point solves and callbacks preserve B3/B5/Bezier endpoint equalities and effective DOF';

for algorithm={'peak-gradient-v2','video-four-direction-v1','auto-tune-v1','fmincon-sqp-experimental-v1'}
    expect(@()camdesign.optimize(best,[],algorithm{1}),'cam:BSplineBackend');
end
old=p; old.params.iterations=1; old.params.controlBoundsPolicy='trajectory-only-v1';
before=camdesign.evaluate(old); [q,h]=camdesign.optimize(old); after=camdesign.evaluate(q);
assert(after.metrics.score<=before.metrics.score+1e-9 && isequal(q.nodes(1,:),old.nodes(1,:)) && ~isempty(h));
camdesign.saveProject(best,fullfile(folder,'roundtrip.mat'));
loaded=camdesign.importProject(fullfile(folder,'roundtrip.mat')); assert(isequaln(best,loaded));
checks{end+1}='unsupported backends rejected, old peak-search path retained and B-spline MAT roundtrip exact';

report=struct('release',version('-release'),'checks',{checks},'polynomialFits',{fits},'solarFits',{solarFits}, ...
    'scope','Analytic and short contract tests only; no converged quality comparison or vehicle claim.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('BSPLINE_CASE_PASS %s\n',checks{k}); end
fprintf('BSPLINE_PASS cases=%d\n',numel(checks));
    function stop=inspect(~,candidate,~)
        count=count+1; stop=false;
        assert(norm(candidate.nodes(1,:)-reference.nodes(1,:))<1e-10);
        if strcmp(camdesign.routeModel(candidate.params),'bspline-v1')
            [~,der]=camdesign.bsplineRoute(candidate.nodes,candidate.params,[0;candidate.params.bspline.parameterLength]);
        else
            [~,der]=camdesign.bezierRoute(candidate.nodes,candidate.params,[0;candidate.params.bezier.parameterLength]);
        end
        assert(max(abs(der-[0 1;0 1]),[],'all')<1e-9);
    end
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end
function expect(callback,id)
try, callback(); catch ex, assert(strcmp(ex.identifier,id),'Unexpected error: %s',ex.message); return; end
error('cam:ExpectedFailure','Expected %s',id);
end
