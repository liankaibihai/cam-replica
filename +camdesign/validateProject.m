function validateProject(project)
p=project.params;
assert(strcmp(project.schema,'cam-replica-1'),'cam:Schema','不支持的项目版本。');
validateattributes(project.targets,{'double'},{'2d','ncols',2,'real','finite'});
validateattributes(project.nodes,{'double'},{'2d','ncols',2,'real','finite'});
assert(size(project.targets,1)>=2 && size(project.nodes,1)>=2,'cam:Points','至少需要两个点。');
assert(all(vecnorm(diff(project.nodes),2,2)>1e-5),'cam:Duplicate','相邻路线节点不能重合。');
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
validateattributes(p.bounds,{'double'},{'vector','numel',4,'finite'});
assert(p.bounds(1)<p.bounds(2) && p.bounds(3)<p.bounds(4),'cam:Bounds','场地坐标范围错误。');
assert(isscalar(p.autoRatio) && ismember(p.autoRatio,[0 1]),'cam:AutoRatio','自动传动比必须为开或关。');
end
