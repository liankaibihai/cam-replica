function report=check_cam_intersections()
% Analytical geometry checks for the new display coordinates, not cam quality.
assert(batchStartupOptionUsed,'cam:IntersectionBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','training_controls_20261030');
if ~isfolder(folder), mkdir(folder); end
crossing=[0 0;2 2;0 2;2 0];
[pairs,points]=camdesign.selfIntersections(crossing);
assert(isequal(pairs,[1 3]) && norm(points-[1 1])<1e-12);
closed=[crossing;crossing(1,:)];
[closedPairs,closedPoints]=camdesign.selfIntersections(closed);
assert(isequal(pairs,closedPairs) && isequal(points,closedPoints));
rectangle=[0 0;4 0;4 2;0 2;0 0];
[plainPairs,plainPoints]=camdesign.selfIntersections(rectangle);
assert(isempty(plainPairs) && isequal(size(plainPoints),[0 2]));
angle=linspace(0,2*pi,361)';
[roundPairs,roundPoints]=camdesign.selfIntersections([cos(angle),sin(angle)]);
assert(isempty(roundPairs) && isempty(roundPoints));
overlap=[0 0;4 0;4 2;1 0;3 0;0 2];
[overlapPairs,overlapPoints]=camdesign.selfIntersections(overlap);
row=find(all(overlapPairs==[1 4],2));
assert(isscalar(row) && norm(overlapPoints(row,:)-[2 0])<1e-12);
touch=[0 0;2 0;2 2;1 0;0 2];
[touchPairs,touchPoints]=camdesign.selfIntersections(touch);
rows=find(all(touchPairs==[1 3],2) | all(touchPairs==[1 4],2));
assert(~isempty(rows) && max(vecnorm(touchPoints(rows,:)-[1 0],2,2))<1e-12);
for candidate={crossing,rectangle,overlap,touch}
    [detected,locations]=camdesign.selfIntersections(candidate{1});
    assert(size(detected,1)==size(locations,1) && all(isfinite(locations),'all'));
end
project=camdesign.solarTestProject();
partial=camdesign.evaluate(project,false); full=camdesign.evaluate(project,true);
assert(isnan(partial.metrics.intersectionCount) && isempty(partial.intersectionPoints));
assert(full.metrics.intersectionCount==size(full.intersectionPairs,1));
assert(size(full.intersectionPoints,1)==size(full.intersectionPairs,1));
report=struct('release',version('-release'),'analyticCases',6,'crossingPairs',pairs, ...
    'crossingCoordinates',points,'overlapPairs',overlapPairs,'overlapCoordinates',overlapPoints, ...
    'touchPairs',touchPairs,'touchCoordinates',touchPoints, ...
    'fullEvaluationIntersectionCount',full.metrics.intersectionCount, ...
    'scope','Existing nonadjacent segment detector/count unchanged. Coordinates are exact for analytical crossings and representative for overlapping/tolerance contacts; not a continuous cam guarantee.');
fid=fopen(fullfile(folder,'intersection_verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CAM_INTERSECTIONS_PASS analytic=6 bowtie=(1,1) overlap=(2,0) closureNotCrossing=true partialUnknown=true\n');
end
