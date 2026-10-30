function settings=trainingSettings(project)
% Read only: legacy projects do not acquire settings or behavior on read.
p=project.params; n=size(project.nodes,1);
settings=struct('iterations',p.iterations,'controlPointCount',n, ...
    'interpolationPerSegment',max(1,ceil((p.samples-1)/(n-1))), ...
    'bezierDegree',3,'gradientForce',p.gradientProbeMM,'learningRate',1, ...
    'smoothingRate',0,'adjustInterval',10,'adjustExponent',0);
if isfield(p,'training')
    for name={'interpolationPerSegment','bezierDegree','learningRate','smoothingRate','adjustInterval','adjustExponent'}
        settings.(name{1})=p.training.(name{1});
    end
end
if strcmp(camdesign.routeModel(p),'bezier-blend-independent-v1'), settings.bezierDegree=p.bezier.degree; end
end
