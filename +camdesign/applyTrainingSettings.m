function [project,info]=applyTrainingSettings(project,changes,algorithm)
% Explicit application only. Evaluation never re-derives p.samples, so the
% independently refined verification grid always takes precedence.
if nargin<3, algorithm='peak-gradient-v2'; end
camdesign.validateProject(project); original=project;
settings=camdesign.trainingSettings(project); current=settings;
mode=camdesign.routeModel(project.params); names=fieldnames(changes);
for k=1:numel(names)
    name=names{k};
    if strcmp(name,'routeModel'), mode=changes.(name);
    else
        assert(isfield(settings,name),'cam:TrainingField','未知训练参数：%s',name); settings.(name)=changes.(name);
    end
end
assert(ismember(mode,{'cubic','bezier-blend-independent-v1'}),'cam:RouteModel','未知路线模型。');
for name={'iterations','controlPointCount','interpolationPerSegment','bezierDegree','adjustInterval'}
    validateattributes(settings.(name{1}),{'double'},{'scalar','integer','real','finite','positive'});
end
validateattributes(settings.learningRate,{'double'},{'scalar','real','finite','positive','<=',100});
validateattributes(settings.gradientForce,{'double'},{'scalar','real','finite','positive'});
validateattributes(settings.smoothingRate,{'double'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(settings.adjustExponent,{'double'},{'scalar','real','finite','>=',0,'<=',10});
assert(settings.bezierDegree>=3 && settings.bezierDegree<=49,'cam:BezierDegree','独立贝塞尔阶数范围为3至49。');
if strcmp(mode,'cubic') && isfield(changes,'bezierDegree')
    assert(settings.bezierDegree==current.bezierDegree,'cam:TrainingRouteParameter','贝塞尔阶数只在独立贝塞尔模式生效。');
end
if startsWith(algorithm,'fmincon')
    for name={'learningRate','smoothingRate','adjustInterval','adjustExponent'}
        assert(isequal(settings.(name{1}),current.(name{1})),'cam:TrainingBackend','内点法不使用本版搜索参数，不能修改%s。',name{1});
    end
end
oldMode=camdesign.routeModel(project.params);
if strcmp(mode,'cubic') && ~strcmp(oldMode,mode)
    project.params=rmfield(project.params,'bezier'); project.params.routeModel='cubic';
elseif strcmp(oldMode,'bezier-blend-independent-v1')
    project.params.bezier.degree=min(project.params.bezier.degree,settings.bezierDegree);
    if isfield(project.params,'training'), project.params.training.bezierDegree=project.params.bezier.degree; end
end
[project,countInfo]=camdesign.setControlPointCount(project,settings.controlPointCount);
if strcmp(mode,'bezier-blend-independent-v1')
    assert(settings.controlPointCount>settings.bezierDegree,'cam:BezierCount','控制点数量须大于贝塞尔阶数。');
    if ~strcmp(oldMode,mode)
        [~,~,stations]=camdesign.routeSpline(project.nodes,project.params);
        project.params.bezier=struct('type','overlap-bernstein-v1','degree',settings.bezierDegree,'parameterLength',stations(end));
        if isfield(project.params,'routeSpline'), project.params=rmfield(project.params,'routeSpline'); end
    else, project.params.bezier.degree=settings.bezierDegree;
    end
end
project.params.routeModel=mode;
managed=isfield(changes,'interpolationPerSegment');
if isfield(original.params,'training'), managed=managed || original.params.training.densityManaged; end
project.params.training=struct('version','independent-training-v1', ...
    'interpolationPerSegment',settings.interpolationPerSegment,'densityManaged',logical(managed), ...
    'bezierDegree',settings.bezierDegree,'learningRate',settings.learningRate, ...
    'smoothingRate',settings.smoothingRate,'adjustInterval',settings.adjustInterval,'adjustExponent',settings.adjustExponent);
project.params.iterations=settings.iterations; project.params.gradientProbeMM=settings.gradientForce;
project=camdesign.updateTrainingSampling(project);
camdesign.validateProject(project);
info=struct('controlPoints',countInfo,'actualSamples',project.params.samples, ...
    'modelChanged',~strcmp(oldMode,mode),'shapePreservationGuaranteed',countInfo.shapePreservationGuaranteed && strcmp(oldMode,mode), ...
    'semantics','Independent controls and Bernstein blend, not recovered original rules.');
end
