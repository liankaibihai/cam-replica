function [project,info]=setControlPointCount(project,count)
% Count changes use true geometry with exact refinement or bounded mapping.
camdesign.validateProject(project);
validateattributes(count,{'double'},{'scalar','integer','finite','>=',2,'<=',250});
oldCount=size(project.nodes,1); mode=camdesign.routeModel(project.params); degree=3;
if strcmp(mode,'bspline-v1'), degree=project.params.bspline.degree;
elseif strcmp(mode,'bezier-blend-independent-v1'), degree=project.params.bezier.degree; end
[project,fitInfo]=camdesign.mapRouteModel(project,mode,count,degree);
info=struct('oldCount',oldCount,'actualCount',size(project.nodes,1), ...
    'shapePreservationGuaranteed',fitInfo.shapePreservationGuaranteed,'outsideSegmentsSkipped',0,'targetOrderUnchanged',true,'fitInfo',fitInfo);
end
