function validateProject(project)
p=project.params;
assert(strcmp(project.schema,'cam-replica-1'),'cam:Schema','不支持的项目版本。');
validateattributes(project.targets,{'double'},{'2d','ncols',2,'real','finite'});
validateattributes(project.nodes,{'double'},{'2d','ncols',2,'real','finite'});
assert(size(project.targets,1)>=2 && size(project.nodes,1)>=2,'cam:Points','至少需要两个点。');
mode=camdesign.routeModel(p);
assert(ismember(mode,{'cubic','bezier-blend-independent-v1','bspline-v1'}),'cam:RouteModel','未知路线模型。');
if ~strcmp(mode,'bspline-v1')
    assert(all(vecnorm(diff(project.nodes),2,2)>1e-5),'cam:Duplicate','相邻路线节点不能重合。');
else
    assert(isfield(p,'bspline') && isstruct(p.bspline) && isscalar(p.bspline) ...
        && all(isfield(p.bspline,{'type','degree','knots','parameterLength','endDerivative'})) ...
        && strcmp(p.bspline.type,'fixed-clamped-bspline-v1'),'cam:BSplineModel','B样条记录不完整。');
    b=p.bspline; n=size(project.nodes,1);
    assert(ismember(b.degree,[3 5]) && n>b.degree,'cam:BSplineDegree','B样条须为三次或五次且控制点数量大于次数。');
    validateattributes(b.parameterLength,{'double'},{'scalar','finite','positive'});
    validateattributes(b.knots,{'double'},{'vector','numel',n+b.degree+1,'real','finite'});
    k=b.knots(:); d=b.degree;
    assert(all(diff(k)>=0) && all(k(1:d+1)==0) && all(k(end-d:end)==b.parameterLength) ...
        && all(k(d+2:end-d-1)>0 & k(d+2:end-d-1)<b.parameterLength), ...
        'cam:BSplineKnots','须使用从0到parameterLength的固定clamped节点向量。');
    validateattributes(b.endDerivative,{'double'},{'size',[1 2],'real','finite'});
    assert(norm(b.endDerivative)>1e-12,'cam:EndDerivative','末端导数不能为零。');
    assert(~isfield(p,'routeSpline') && ~isfield(p,'bezier'),'cam:RouteModel','B样条不能沿用其他模型的元数据。');
    [~,D]=camdesign.bsplineBasis(b.knots,b.degree,[0;b.parameterLength]);
    desired=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg);b.endDerivative];
    assert(max(abs(D*project.nodes-desired),[],'all')<1e-7,'cam:EndpointConstraint', ...
        'B样条首末参数导数受约束；请调整自由控制点或重新受约束拟合，不能独立移动首两点/末两点。');
end
if isfield(p,'controlBoundsPolicy')
    assert(ismember(p.controlBoundsPolicy,{'legacy-node-bounds-v1','trajectory-only-v1'}), ...
        'cam:ControlBoundsPolicy','未知节点/系数场界策略。');
end
if strcmp(mode,'bezier-blend-independent-v1')
    assert(isfield(p,'bezier') && isstruct(p.bezier) && isscalar(p.bezier) ...
        && all(isfield(p.bezier,{'type','degree','parameterLength'})) ...
        && strcmp(p.bezier.type,'overlap-bernstein-v1'),'cam:BezierModel','独立贝塞尔记录不完整。');
    validateattributes(p.bezier.degree,{'double'},{'scalar','integer','>=',3,'<=',49,'<',size(project.nodes,1)});
    validateattributes(p.bezier.parameterLength,{'double'},{'scalar','real','finite','positive'});
    assert(~isfield(p,'routeSpline'),'cam:RouteModel','贝塞尔模式不能沿用三次样条站位。');
end
if isfield(p,'training')
    t=p.training;
    assert(isstruct(t) && isscalar(t) && all(isfield(t,{'version','interpolationPerSegment','densityManaged', ...
        'bezierDegree','learningRate','smoothingRate','adjustInterval','adjustExponent'})) ...
        && strcmp(t.version,'independent-training-v1'),'cam:Training','训练设置记录不完整。');
    validateattributes(t.interpolationPerSegment,{'double'},{'scalar','integer','positive','<=',20000});
    validateattributes(t.bezierDegree,{'double'},{'scalar','integer','>=',3,'<=',49});
    validateattributes(t.learningRate,{'double'},{'scalar','real','finite','positive','<=',100});
    validateattributes(t.smoothingRate,{'double'},{'scalar','real','finite','>=',0,'<=',1});
    validateattributes(t.adjustInterval,{'double'},{'scalar','integer','positive','<=',10000});
    validateattributes(t.adjustExponent,{'double'},{'scalar','real','finite','>=',0,'<=',10});
    assert(isscalar(t.densityManaged) && ismember(t.densityManaged,[0 1]),'cam:Training','采样密度管理标志错误。');
    if strcmp(mode,'bezier-blend-independent-v1'), assert(t.bezierDegree==p.bezier.degree,'cam:BezierDegree','训练阶数与路线阶数不一致。'); end
end
if isfield(p,'routeSpline')
    geometry=p.routeSpline;
    assert(isstruct(geometry) && isscalar(geometry) ...
        && all(isfield(geometry,{'type','stations','endDerivative'})), ...
        'cam:RouteSpline','固定站位路线记录不完整。');
    assert(isequal(geometry.type,'fixed-clamped-cubic-v1'),'cam:RouteSpline','未知路线参数化。');
    validateattributes(geometry.stations,{'double'},{'vector','numel',size(project.nodes,1),'real','finite'});
    assert(geometry.stations(1)==0 && all(diff(geometry.stations(:))>1e-8), ...
        'cam:RouteStations','路线站位必须从零开始、严格递增，并与节点逐行对应。');
    validateattributes(geometry.endDerivative,{'double'},{'size',[1 2],'real','finite'});
    assert(norm(geometry.endDerivative)>1e-12,'cam:RouteEndDerivative','终点参数导数不能为零。');
end
assert(ismember(p.mechanism,{'rack','flat'}),'cam:Mechanism','当前只支持齿条和平推。');
names={'wheelDiameter','gearRatio','referenceDiameter','hitTolerance','stepMM','gradientProbeMM'};
for k=1:numel(names)
    validateattributes(p.(names{k}),{'double'},{'scalar','real','finite','positive'},'',names{k});
end
names={'lever','rollerRadius','thickness','driveX','driveY','drivenX','drivenY', ...
    'sensorX','sensorY','headingDeg','startSteeringDeg','returnAngleDeg','maxSteeringDeg','maxPressureDeg'};
for k=1:numel(names), validateattributes(p.(names{k}),{'double'},{'scalar','finite','real'},'',names{k}); end
assert(abs(p.lever)>1e-6,'cam:Lever','机构系数 c 不能为零。');
assert(p.rollerRadius>=0 && p.referenceDiameter/2>p.rollerRadius,'cam:Radius','零位中心距必须大于滚子半径。');
assert(p.driveY<0 && abs(p.driveY-p.drivenY)<1e-6,'cam:Axle','要求后轮共轴且局部 Y < 0。');
assert(p.maxSteeringDeg>0 && p.maxSteeringDeg<89,'cam:Steering','转角上限须在 0 到 89 度之间。');
assert(p.maxPressureDeg>0 && p.maxPressureDeg<89,'cam:Pressure','压力角上限须在 0 到 89 度之间。');
assert(p.returnAngleDeg>=10 && p.returnAngleDeg<180,'cam:Return','回程保留角须在 10 到 180 度之间。');
validateattributes(p.samples,{'double'},{'scalar','integer','>=',101,'<=',20001});
validateattributes(p.camSamples,{'double'},{'scalar','integer','>=',181,'<=',20001});
validateattributes(p.iterations,{'double'},{'scalar','integer','>=',1,'<=',10000});
validateattributes(p.weights,{'double'},{'vector','numel',6,'finite','nonnegative'});
camdesign.dynamicWeightSettings(p);
camdesign.autoTuneSettings(p);
validateattributes(p.bounds,{'double'},{'vector','numel',4,'finite'});
assert(p.bounds(1)<p.bounds(2) && p.bounds(3)<p.bounds(4),'cam:Bounds','场地坐标范围错误。');
assert(isscalar(p.autoRatio) && ismember(p.autoRatio,[0 1]),'cam:AutoRatio','自动传动比必须为开或关。');
end
