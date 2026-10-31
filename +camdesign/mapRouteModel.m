function [mapped,fitInfo]=mapRouteModel(source,mode,count,degree,options)
% Convert the REAL front curve in its unchanged parameter, never rename XY.
% Exact polynomial-space embeddings are distinguished from bounded fits.
% Numerical acceptance is independent-grid evidence, not a continuous proof.
arguments
    source struct
    mode char
    count (1,1) double {mustBeInteger,mustBePositive}
    degree (1,1) double {mustBeInteger}=3
    options.MaxControlPoints (1,1) double {mustBeInteger,mustBePositive}=250
    options.PositionMaxToleranceMM (1,1) double {mustBeFinite,mustBePositive}=.05
    options.PositionRMSToleranceMM (1,1) double {mustBeFinite,mustBePositive}=.01
    options.TangentMaxToleranceDeg (1,1) double {mustBeFinite,mustBePositive}=.05
    options.AllowApproximate (1,1) logical=false
end
camdesign.validateProject(source);
assert(options.PositionMaxToleranceMM<=.05 && options.PositionRMSToleranceMM<=.01 ...
    && options.TangentMaxToleranceDeg<=.05,'cam:RouteMappingToleranceSettings', ...
    '映射门限只能收紧，不能放宽默认0.05mm最大、0.01mm RMS及0.05°全程切向误差。');
assert(ismember(mode,{'cubic','bezier-blend-independent-v1','bspline-v1'}),'cam:RouteModel','未知目标路线模型。');
assert(options.MaxControlPoints<=250 && count<=options.MaxControlPoints,'cam:RouteMappingCount','控制点映射上限为250。');
sourceMode=camdesign.routeModel(source.params); oldCount=size(source.nodes,1); requestedCount=count;
sourceDegree=3;
if strcmp(sourceMode,'bezier-blend-independent-v1'), sourceDegree=source.params.bezier.degree;
elseif strcmp(sourceMode,'bspline-v1'), sourceDegree=source.params.bspline.degree; end
if strcmp(mode,'cubic'), degree=3; minimum=2;
elseif strcmp(mode,'bspline-v1')
    assert(ismember(degree,[3 5]),'cam:BSplineDegree','标准B样条仅支持三次或五次。'); minimum=degree+1;
else
    assert(degree>=3 && degree<=49,'cam:BezierDegree','独立贝塞尔阶数范围为3至49。'); minimum=degree+1;
end
count=max(count,minimum);
assert(count<=options.MaxControlPoints,'cam:RouteMappingCount','控制点上限小于目标次数所需数量。');
[T,sourceBreaks,sourceKnots]=domain(source);
[ends,endD]=camdesign.routeGeometry(source.nodes,source.params,[0;T]);
desired=[cosd(source.params.headingDeg+source.params.startSteeringDeg),sind(source.params.headingDeg+source.params.startSteeringDeg)];
assert(norm(endD(1,:)-desired)<1e-7,'cam:RouteMappingEndpoint','源路线初始参数导数不符合当前初始姿态。');
attempts=struct('count',{},'positionMaxMM',{},'positionRMSMM',{});
stations=linspace(0,T,count)'; exact=false; method='constrained-fit';
exactKnots=[];
if strcmp(mode,sourceMode) && count==oldCount && degree==sourceDegree
    candidate=source; exact=true; method='identity';
elseif strcmp(mode,'bspline-v1') && ~isempty(sourceKnots) && degree>=sourceDegree
    % Degree elevation increases each internal knot multiplicity by the
    % degree difference; a C2 cubic stays C2 when elevated to degree five.
    inner=sourceKnots(sourceKnots>0 & sourceKnots<T);
    if degree>sourceDegree
        inner=sort([inner,repelem(unique(inner),degree-sourceDegree)]);
    end
    exactKnots=[zeros(1,degree+1),inner,T*ones(1,degree+1)];
    exactCount=numel(exactKnots)-degree-1;
    if exactCount<=options.MaxControlPoints
        exactKnots=insertKnots(exactKnots,max(count,exactCount),degree);
        count=numel(exactKnots)-degree-1; exact=true; method='polynomial-space-embedding';
        candidate=fitCandidate(source,mode,degree,count,T,exactKnots,ends,endD);
    else, exactKnots=[]; end
elseif strcmp(mode,'cubic') && (strcmp(sourceMode,'cubic') || ...
        (strcmp(sourceMode,'bspline-v1') && sourceDegree==3 && numel(unique(sourceKnots))==numel(sourceKnots)-6)) ...
        && count>=numel(sourceBreaks)
    stations=insertStations(sourceBreaks,count); exact=true; method='clamped-cubic-refinement';
    candidate=cubicCandidate(source,stations,T,endD);
end
if ~exist('candidate','var')
    candidate=fitCandidate(source,mode,degree,count,T,[],ends,endD,stations);
end
while true
    fitInfo=inspect(source,candidate,T,sourceBreaks,options,exact,method);
    attempts(end+1)=struct('count',size(candidate.nodes,1),'positionMaxMM',fitInfo.positionMaxMM, ...
        'positionRMSMM',fitInfo.positionRMSMM); %#ok<AGROW>
    if fitInfo.withinTolerance, break; end
    if exact || size(candidate.nodes,1)>=options.MaxControlPoints
        if options.AllowApproximate
            assert(fitInfo.finiteGeometry,'cam:RouteMappingNonfinite','强制切换仍要求有限曲线、导数和非退化切向；原方案保留。');
            assert(fitInfo.endpointConstraintsSatisfied,'cam:RouteMappingEndpoint','强制切换不能放宽首末位置和参数导数约束；原方案保留。');
            break;
        end
        error('cam:RouteMappingTolerance', ...
            '路线映射被拒绝：%s → %s，%d控制点，最大误差 %.6g mm / 容差 %.6g，RMS %.6g mm / 容差 %.6g，全程切向 %.6g° / 容差 %.6g°；原方案保留。', ...
            sourceMode,mode,size(candidate.nodes,1),fitInfo.positionMaxMM,options.PositionMaxToleranceMM, ...
            fitInfo.positionRMSMM,options.PositionRMSToleranceMM,fitInfo.maxTangentErrorDeg,options.TangentMaxToleranceDeg);
    end
    next=min(options.MaxControlPoints,max(count+4,ceil(1.5*count)));
    if strcmp(mode,sourceMode) && degree==sourceDegree && count<oldCount && next>=oldCount
        next=oldCount; candidate=source; exact=true; method='existing-exact-representation';
    elseif strcmp(mode,'cubic')
        if strcmp(sourceMode,'cubic') && next>=oldCount
            next=max(next,oldCount); stations=insertStations(sourceBreaks,next);
            exact=true; method='clamped-cubic-refinement';
        else
            stations=refineStations(stations,fitInfo.validationU,fitInfo.validationErrors,next);
        end
        candidate=cubicCandidate(source,stations,T,endD);
    else
        candidate=fitCandidate(source,mode,degree,next,T,[],ends,endD);
    end
    count=next;
end
mapped=candidate; fitInfo=rmfield(fitInfo,{'validationU','validationErrors'});
fitInfo.version='route-geometry-mapping-v1'; fitInfo.sourceModel=sourceMode; fitInfo.targetModel=mode;
fitInfo.sourceDegree=sourceDegree; fitInfo.targetDegree=degree;
fitInfo.oldControlPointCount=oldCount; fitInfo.requestedControlPointCount=requestedCount;
fitInfo.actualControlPointCount=size(mapped.nodes,1); fitInfo.controlPointCount=size(mapped.nodes,1);
fitInfo.automaticallyIncreasedCount=fitInfo.actualControlPointCount>fitInfo.requestedControlPointCount;
fitInfo.attempts=attempts; fitInfo.parameterLength=T;
fitInfo.targetOrderUnchanged=isequaln(source.targets,mapped.targets);
fitInfo.allowApproximate=options.AllowApproximate;
fitInfo.forced=options.AllowApproximate && ~fitInfo.withinTolerance;
if fitInfo.forced, fitInfo.shapePreservationGuaranteed=false; end
fitInfo.approximate=~fitInfo.shapePreservationGuaranteed;
fitInfo.acceptance='within-tolerance';
if fitInfo.shapePreservationGuaranteed, fitInfo.acceptance='exact'; end
if fitInfo.forced, fitInfo.acceptance='forced-approximate'; end
end

function [T,breaks,knots]=domain(project)
mode=camdesign.routeModel(project.params); knots=[];
if strcmp(mode,'cubic')
    [~,~,breaks]=camdesign.routeSpline(project.nodes,project.params); T=breaks(end);
    knots=[zeros(1,4),breaks(2:end-1)',T*ones(1,4)];
elseif strcmp(mode,'bspline-v1')
    T=project.params.bspline.parameterLength; knots=project.params.bspline.knots(:)'; breaks=unique(knots(:));
else
    T=project.params.bezier.parameterLength; breaks=linspace(0,T,size(project.nodes,1))';
end
breaks=breaks(:);
end

function q=fitCandidate(source,mode,degree,count,T,knots,ends,endD,stations)
if strcmp(mode,'cubic')
    if nargin<9, stations=linspace(0,T,count)'; end
    q=cubicCandidate(source,stations,T,endD); return;
end
q=source; q.params=removeGeometry(q.params); q.params.routeModel=mode;
if strcmp(mode,'bspline-v1')
    if isempty(knots)
        interior=linspace(0,T,count-degree+1);
        knots=[zeros(1,degree+1),interior(2:end-1),T*ones(1,degree+1)];
    end
    q.params.bspline=struct('type','fixed-clamped-bspline-v1','degree',degree, ...
        'knots',knots,'parameterLength',T,'endDerivative',endD(2,:));
else
    q.params.bezier=struct('type','overlap-bernstein-v1','degree',degree,'parameterLength',T);
    if isfield(q.params,'training'), q.params.training.bezierDegree=degree; end
end
u=linspace(0,T,max(2001,16*count))';
F=camdesign.routeGeometry(source.nodes,source.params,u);
[A,~,offset]=linearBasis(q.params,count,u);
[E,D,offsetEnd,velocityEnd]=linearBasis(q.params,count,[0;T]);
E=[E;D]; rhs=[ends-offsetEnd;endD-velocityEnd];
nonzero=vecnorm(E,2,2)>1e-14;
assert(all(vecnorm(rhs(~nonzero,:),2,2)<1e-7),'cam:RouteMappingEndpoint','端点导数不兼容。');
E=E(nonzero,:); rhs=rhs(nonzero,:); norms=vecnorm(E,2,2); E=E./norms; rhs=rhs./norms;
Z=null(E); particular=E'*((E*E')\rhs);
q.nodes=particular+Z*lsqminnorm(A*Z,F-offset-A*particular);
% These are exact clamped endpoint coefficient constraints, not a change to
% the evaluated curve formula. Keep the user-owned launch point bitwise.
q.nodes(1,:)=source.nodes(1,:); q.nodes(end,:)=source.nodes(end,:);
camdesign.validateProject(q);
end

function q=cubicCandidate(source,stations,~,endD)
q=source; q.nodes=camdesign.routeGeometry(source.nodes,source.params,stations);
q.nodes(1,:)=source.nodes(1,:); q.nodes(end,:)=source.nodes(end,:);
q.params=removeGeometry(q.params); q.params.routeModel='cubic';
q.params.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',stations(:),'endDerivative',endD(2,:));
camdesign.validateProject(q);
end

function [A,D,offset,velocityOffset]=linearBasis(p,n,u)
u=u(:); offset=zeros(numel(u),2); velocityOffset=offset;
if strcmp(camdesign.routeModel(p),'bspline-v1')
    [A,D]=camdesign.bsplineBasis(p.bspline.knots,p.bspline.degree,u); return;
end
scale=(n-1)/p.bezier.parameterLength; degree=p.bezier.degree;
[A,D]=camdesign.independentBezierBasis(double(n),degree,max(0,min(n-1,u*scale))); D=D*scale;
span=p.bezier.parameterLength*degree/(n-1); t=u/span; active=t<=1;
h=zeros(size(u)); dh=h; v=t(active);
h(active)=span*v.*(1-v).^4; dh(active)=(1-v).^3.*(1-5*v);
A(:,1)=A(:,1)+h*scale; A(:,2)=A(:,2)-h*scale;
D(:,1)=D(:,1)+dh*scale; D(:,2)=D(:,2)-dh*scale;
desired=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
offset=h*desired; velocityOffset=dh*desired;
end

function info=inspect(source,target,T,sourceBreaks,options,exact,method)
[~,targetBreaks]=domain(target); allBreaks=unique([sourceBreaks;targetBreaks]);
% Half-offset grid is independent of the endpoint-inclusive fitting rows.
u=sort(unique([0;T;((0:12000)'+.5)/12001*T;allBreaks; ...
    max(0,allBreaks-T*1e-10);min(T,allBreaks+T*1e-10)]));
[F,V]=camdesign.routeGeometry(source.nodes,source.params,u); [Q,W]=camdesign.routeGeometry(target.nodes,target.params,u);
errors=vecnorm(Q-F,2,2);
allAngles=rad2deg(atan2(abs(W(:,1).*V(:,2)-W(:,2).*V(:,1)),sum(W.*V,2)));
allAngles(vecnorm(V,2,2)<1e-10 | vecnorm(W,2,2)<1e-10)=Inf;
maxAngle=max(allAngles);
[F0,V0]=camdesign.routeGeometry(source.nodes,source.params,[0;T]);
[Q0,W0]=camdesign.routeGeometry(target.nodes,target.params,[0;T]);
pointError=vecnorm(Q0-F0,2,2)'; derivativeError=vecnorm(W0-V0,2,2)';
angle=rad2deg(atan2(abs(W0(:,1).*V0(:,2)-W0(:,2).*V0(:,1)),sum(W0.*V0,2)))';
maximum=max(errors); rms=sqrt(mean(errors.^2));
finiteGeometry=all(isfinite([F(:);V(:);Q(:);W(:);errors;allAngles;pointError(:);derivativeError(:);angle(:)]));
endpointPassed=max(pointError)<=1e-7 && max(derivativeError)<=1e-7 && max(angle)<=1e-5;
passed=maximum<=options.PositionMaxToleranceMM && rms<=options.PositionRMSToleranceMM && maxAngle<=options.TangentMaxToleranceDeg ...
    && max(pointError)<=1e-7 && max(derivativeError)<=1e-7 && max(angle)<=1e-5;
info=struct('positionMaxMM',maximum,'positionRMSMM',rms,'maxTangentErrorDeg',maxAngle,'firstPointErrorMM',pointError(1), ...
    'endpointPositionErrorMM',pointError,'endpointDerivativeError',derivativeError,'endpointTangentErrorDeg',angle, ...
    'withinTolerance',passed,'shapePreservationGuaranteed',exact && maximum<1e-7, ...
    'finiteGeometry',finiteGeometry,'endpointConstraintsSatisfied',endpointPassed, ...
    'mathematicallyExactSpace',exact,'method',method,'validationSamples',numel(u), ...
    'tolerances',struct('positionMaxMM',options.PositionMaxToleranceMM,'positionRMSMM',options.PositionRMSToleranceMM, ...
        'maxTangentDeg',options.TangentMaxToleranceDeg,'endpointPositionMM',1e-7,'endpointDerivative',1e-7,'endpointTangentDeg',1e-5), ...
    'scope','Same-parameter front geometry on independent offset grid and span boundaries; fitted mappings are not exact identities or cam/vehicle acceptance.', ...
    'validationU',u,'validationErrors',errors);
end

function p=removeGeometry(p)
for name={'routeSpline','bezier','bspline'}
    if isfield(p,name{1}), p=rmfield(p,name{1}); end
end
end

function knots=insertKnots(knots,count,degree)
while numel(knots)-degree-1<count
    spans=diff(knots); [~,k]=max(spans); knots=sort([knots,(knots(k)+knots(k+1))/2]);
end
end
function stations=insertStations(stations,count)
while numel(stations)<count
    [~,k]=max(diff(stations)); stations=sort([stations;(stations(k)+stations(k+1))/2]);
end
end
function stations=refineStations(stations,u,errorMM,count)
importance=zeros(numel(stations)-1,1);
for k=1:numel(importance)
    selected=u>=stations(k) & u<=stations(k+1); importance(k)=max(errorMM(selected));
end
[~,order]=sort(importance,'descend'); add=min(count-numel(stations),numel(order));
indices=order(1:add); stations=sort([stations;(stations(indices)+stations(indices+1))/2]);
stations=insertStations(stations,count);
end
