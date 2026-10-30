function [refined,info] = refineRoute(project,segments)
% Insert front-wheel interpolation nodes at original parameter mid-stations.
% With fixed stations and BOTH endpoint derivatives retained, the unique C2
% clamped cubic through the enlarged node set is the same original curve.
% Moving an inserted node afterwards adds two genuine coordinate DOFs.
% Omit segments for all intervals; [] freezes parameterization without adding
% nodes, providing a fixed-station control for optimizer comparisons.
camdesign.validateProject(project);
assert(strcmp(camdesign.routeModel(project.params),'cubic'),'cam:RefineBezier','保形细化仅适用于三次样条；贝塞尔增点需要显式重建。');
[px,py,stations,endDerivative]=camdesign.routeSpline(project.nodes,project.params);
oldCount=size(project.nodes,1);
if nargin<2, segments=(1:oldCount-1)'; end
if ~isempty(segments)
    validateattributes(segments,{'double'},{'vector','integer','real','finite','>=',1,'<=',oldCount-1});
end
segments=unique(segments(:));
insertStations=(stations(segments)+stations(segments+1))/2;
insertPoints=[ppval(px,insertStations),ppval(py,insertStations)];
bounds=project.params.bounds; low=bounds([1 3]); high=bounds([2 4]);
inside=all(insertPoints>=low & insertPoints<=high,2);
% Clamping an outside point would change the curve. Skip it explicitly.
acceptedStations=insertStations(inside);
newStations=sort([stations;acceptedStations]);
[~,oldToNew]=ismember(stations,newStations);
[~,insertedIndices]=ismember(acceptedStations,newStations);
refined=project; refined.nodes=zeros(numel(newStations),2);
refined.nodes(oldToNew,:)=project.nodes;
refined.nodes(insertedIndices,:)=insertPoints(inside,:);
refined.params.routeSpline=struct('type','fixed-clamped-cubic-v1', ...
    'stations',newStations,'endDerivative',endDerivative);
camdesign.validateProject(refined);
info=struct('originalNodeCount',oldCount,'newNodeCount',size(refined.nodes,1), ...
    'requestedSegments',segments,'insertedSegments',segments(inside), ...
    'insertedIndices',insertedIndices,'insertedStations',acceptedStations, ...
    'skippedSegments',segments(~inside),'skippedPoints',insertPoints(~inside,:), ...
    'existingOutsideNodeIndices',find(any(project.nodes<low | project.nodes>high,2)), ...
    'oldToNewIndices',oldToNew,'addedCoordinateDOF',2*nnz(inside), ...
    'parameterizationInitialized',~isfield(project.params,'routeSpline'), ...
    'preservation','Same C2 clamped cubic in the same parameter; no point clamping or physical-model changes.');
end
