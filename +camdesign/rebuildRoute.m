function [project,info]=rebuildRoute(source,changes,algorithm)
% Explicit reshape from targets. No fit or tolerance test against OLD route.
if nargin<2, changes=struct(); end
if nargin<3, algorithm='peak-gradient-v2'; end
settings=camdesign.trainingSettings(source); current=settings;
mode=camdesign.routeModel(source.params); degree=3;
if strcmp(mode,'bspline-v1'), degree=source.params.bspline.degree; end
for name=fieldnames(changes)'
    key=name{1};
    if strcmp(key,'routeModel'), mode=changes.(key);
    elseif strcmp(key,'bsplineDegree'), degree=changes.(key);
    else
        assert(isfield(settings,key),'cam:TrainingField','未知训练参数：%s',key); settings.(key)=changes.(key);
    end
end
if strcmp(mode,'bspline-3'), mode='bspline-v1'; degree=3;
elseif strcmp(mode,'bspline-5'), mode='bspline-v1'; degree=5; end
assert(ismember(mode,{'cubic','bezier-blend-independent-v1','bspline-v1'}),'cam:RouteModel','未知重建模型。');
assert(~strcmp(mode,'bspline-v1') || strcmp(algorithm,'fmincon-interior-point-experimental-v1'), ...
    'cam:BSplineBackend','标准B样条目前仅支持约束优化（内点法）。');
for name={'iterations','controlPointCount','interpolationPerSegment','bezierDegree','adjustInterval'}
    validateattributes(settings.(name{1}),{'double'},{'scalar','integer','real','finite','positive'});
end
validateattributes(settings.controlPointCount,{'double'},{'<=',250});
validateattributes(settings.bezierDegree,{'double'},{'>=',3,'<=',49});
validateattributes(settings.learningRate,{'double'},{'scalar','real','finite','positive','<=',100});
validateattributes(settings.gradientForce,{'double'},{'scalar','real','finite','positive'});
validateattributes(settings.smoothingRate,{'double'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(settings.adjustExponent,{'double'},{'scalar','real','finite','>=',0,'<=',10});
if startsWith(algorithm,'fmincon')
    for name={'learningRate','smoothingRate','adjustInterval','adjustExponent'}
        assert(isequal(settings.(name{1}),current.(name{1})),'cam:TrainingBackend','内点法不使用本版搜索参数，不能修改%s。',name{1});
    end
end
if strcmp(algorithm,'auto-tune-v1')
    assert(strcmp(mode,camdesign.routeModel(source.params)),'cam:AutoModelLocked','全自动模式重建不能切换已应用画法。');
    if strcmp(mode,'bezier-blend-independent-v1')
        assert(settings.bezierDegree==source.params.bezier.degree,'cam:AutoModelLocked','全自动模式重建不能切换已应用阶数。');
    end
end
validateattributes(source.nodes,{'double'},{'2d','ncols',2,'real','finite'});
assert(~isempty(source.nodes),'cam:Points','重建需要明确的原始起点。');
project=source; p=source.params;
for name={'routeSpline','bezier','bspline'}
    if isfield(p,name{1}), p=rmfield(p,name{1}); end
end
% Validate physical/pending inputs with a minimal fresh cubic representation,
% so discarded old coefficient/heading constraints cannot block a rebuild.
validation=source; validation.params=p; validation.params.routeModel='cubic';
validation.nodes=[source.nodes(1,:);source.nodes(1,:)+[1 0]];
camdesign.validateProject(validation);
seed=camdesign.seedNodes(source.targets,p); seed(1,:)=source.nodes(1,:);
stations=[0;cumsum(vecnorm(diff(seed),2,2))];
assert(all(diff(stations)>1e-5),'cam:Duplicate','目标生成的相邻路线种子重合，不能重建。');
T=stations(end); count=settings.controlPointCount;
if strcmp(mode,'bezier-blend-independent-v1'), degree=settings.bezierDegree; count=max(count,degree+1);
elseif strcmp(mode,'bspline-v1')
    assert(ismember(degree,[3 5]),'cam:BSplineDegree','标准B样条仅支持三次或五次。'); count=max(count,degree+1);
else, degree=3; count=max(count,2); end
project.nodes=interp1(stations,seed,linspace(0,T,count)','linear');
project.nodes(1,:)=source.nodes(1,:); project.nodes(end,:)=seed(end,:);
p.routeModel=mode;
if strcmp(mode,'cubic') && count>=size(seed,1)
    % Preserve all newly generated target seeds. Extra controls refine THIS
    % new cubic exactly; no mapping of the discarded route is involved.
    project.nodes=seed;
    if count>size(seed,1)
        [~,~,seedStations,endD]=camdesign.routeSpline(seed,p); newStations=seedStations;
        while numel(newStations)<count
            [~,longest]=max(diff(newStations)); newStations=sort([newStations;(newStations(longest)+newStations(longest+1))/2]);
        end
        project.nodes=camdesign.routeGeometry(seed,p,newStations);
        project.nodes(1,:)=source.nodes(1,:); project.nodes(end,:)=seed(end,:);
        p.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',newStations,'endDerivative',endD);
    end
elseif strcmp(mode,'bezier-blend-independent-v1')
    p.bezier=struct('type','overlap-bernstein-v1','degree',degree,'parameterLength',T);
elseif strcmp(mode,'bspline-v1')
    inner=linspace(0,T,count-degree+1); knots=[zeros(1,degree+1),inner(2:end-1),T*ones(1,degree+1)];
    endD=(seed(end,:)-seed(end-1,:))/norm(seed(end,:)-seed(end-1,:));
    startD=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
    project.nodes(2,:)=project.nodes(1,:)+inner(2)/degree*startD;
    project.nodes(end-1,:)=project.nodes(end,:)-(T-inner(end-1))/degree*endD;
    p.bspline=struct('type','fixed-clamped-bspline-v1','degree',degree,'knots',knots,'parameterLength',T,'endDerivative',endD);
end
managed=isfield(changes,'interpolationPerSegment');
if isfield(p,'training'), managed=managed || p.training.densityManaged; end
p.training=struct('version','independent-training-v1','interpolationPerSegment',settings.interpolationPerSegment, ...
    'densityManaged',logical(managed),'bezierDegree',settings.bezierDegree,'learningRate',settings.learningRate, ...
    'smoothingRate',settings.smoothingRate,'adjustInterval',settings.adjustInterval,'adjustExponent',settings.adjustExponent);
p.iterations=settings.iterations; p.gradientProbeMM=settings.gradientForce; project.params=p;
project=camdesign.updateTrainingSampling(project); camdesign.validateProject(project);
if isfield(project,'routeMapping'), project=rmfield(project,'routeMapping'); end
info=struct('version','target-route-rebuild-v1','rebuiltFromTargets',true,'shapePreservationGuaranteed',false, ...
    'targetModel',mode,'targetDegree',degree,'requestedControlPointCount',settings.controlPointCount, ...
    'actualControlPointCount',count,'actualSamples',project.params.samples, ...
    'startPointUnchanged',isequal(project.nodes(1,:),source.nodes(1,:)), ...
    'targetOrderUnchanged',isequaln(project.targets,source.targets), ...
    'semantics','New target-seeded controls with the existing start; explicit reshape, no old-curve mapping or physical-feasibility claim.');
project.routeRebuild=info;
end
