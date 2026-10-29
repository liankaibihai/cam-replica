function report=check_route_refinement()
% Geometry and integration checks; the one-iteration search checks DOF wiring,
% not optimizer quality. Long-budget comparisons are run separately.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:RefinementBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','route_refinement_20261029');
if ~isfolder(folder), mkdir(folder); end
checks={}; solar=camdesign.solarTestProject();
for project={camdesign.defaultProject(),solar}
    item=project{1}; nodes=item.nodes; p=item.params;
    knots=[0;cumsum(vecnorm(diff(nodes),2,2))];
    start=[cosd(p.headingDeg+p.startSteeringDeg),sind(p.headingDeg+p.startSteeringDeg)];
    finish=nodes(end,:)-nodes(end-1,:); finish=finish/norm(finish);
    oldX=spline(knots,[start(1);nodes(:,1);finish(1)]);
    oldY=spline(knots,[start(2);nodes(:,2);finish(2)]);
    [px,py]=camdesign.routeSpline(nodes,p);
    assert(isequaln(px,oldX) && isequaln(py,oldY));
end
checks{end+1}='legacy solar/default spline coefficients unchanged';

% Independent exact cubic: initial derivative (1,0), known endpoint derivative.
analytic=solar; t=[0;1;2;4]; cx=[.02 0 1 0]; cy=[-.005 .03 0 0];
analytic.params.headingDeg=0; analytic.params.startSteeringDeg=0;
analytic.params.bounds=[-10 20 -10 20];
analytic.nodes=[polyval(cx,t),polyval(cy,t)]; analytic.targets=analytic.nodes;
analytic.params.routeSpline=struct('type','fixed-clamped-cubic-v1','stations',t, ...
    'endDerivative',[polyval(polyder(cx),t(end)),polyval(polyder(cy),t(end))]);
[analyticRefined,analyticInfo]=camdesign.refineRoute(analytic);
assert(analyticInfo.newNodeCount==7 && analyticInfo.addedCoordinateDOF==6);
[ax,ay]=camdesign.routeSpline(analyticRefined.nodes,analyticRefined.params);
sample=linspace(0,4,1001)'; analyticErrors=zeros(1,4);
for order=0:3
    if order>0, cx=polyder(cx); cy=polyder(cy); end
    expected=[polyval(cx,sample),polyval(cy,sample)];
    actual=[ppval(camdesign.ppDerivative(ax,order),sample),ppval(camdesign.ppDerivative(ay,order),sample)];
    analyticErrors(order+1)=max(abs(actual-expected),[],'all');
end
assert(all(analyticErrors<1e-11));
checks{end+1}='analytic cubic position and first/second/third derivatives preserved';

[frozen,freezeInfo]=camdesign.refineRoute(solar,[]);
assert(isequal(frozen.nodes,solar.nodes) && freezeInfo.addedCoordinateDOF==0);
[once,onceInfo]=camdesign.refineRoute(solar);
[twice,twiceInfo]=camdesign.refineRoute(once);
assert(onceInfo.newNodeCount>size(solar.nodes,1) && twiceInfo.newNodeCount>size(once.nodes,1));
assert(isequal(once.targets,solar.targets) && isequal(twice.targets,solar.targets));
assert(size(once.targets,1)==10 && isequal(once.targets(1,:),once.targets(end,:)));
assert(isequal(solar.params,rmfield(once.params,'routeSpline')));
assert(isequal(once.nodes(onceInfo.oldToNewIndices,:),solar.nodes));
assert(isequal(twice.nodes(twiceInfo.oldToNewIndices,:),once.nodes));
freezeErrors=splineErrors(solar,frozen); onceErrors=splineErrors(solar,once); twiceErrors=splineErrors(solar,twice);
assert(all(max([freezeErrors;onceErrors;twiceErrors],[],1)<[1e-8 1e-10 1e-11 1e-12]));
checks{end+1}='solar freeze/one-pass/two-pass preserve the same parameterized cubic';
checks{end+1}='target order and repeated Earth retained; no sample-count or physical-parameter changes';

% The final clamped derivative cannot be recomputed from a new last chord.
[tail,tailInfo]=camdesign.refineRoute(solar,size(solar.nodes,1)-1);
assert(numel(tailInfo.insertedIndices)==1);
[tx,ty,stations,oldEnd]=camdesign.routeSpline(tail.nodes,tail.params);
actualEnd=[ppval(camdesign.ppDerivative(tx,1),stations(end)),ppval(camdesign.ppDerivative(ty,1),stations(end))];
assert(norm(actualEnd-oldEnd)<1e-11);
newChord=tail.nodes(end,:)-tail.nodes(end-1,:); newChord=newChord/norm(newChord);
assert(norm(newChord-oldEnd)>1e-4,'Fixture does not expose the endpoint-derivative pitfall.');
checks{end+1}='last-segment insertion retains explicit endpoint derivative';

% New XY coordinates are true interpolation DOFs at fixed independent stations.
changed=once; movedIndex=onceInfo.insertedIndices(ceil(end/2));
changed.nodes(movedIndex,:)=changed.nodes(movedIndex,:)+[.25 -.125];
[dx,dy,changedStations]=camdesign.routeSpline(changed.nodes,changed.params);
atNodes=[ppval(dx,changedStations),ppval(dy,changedStations)];
assert(max(abs(atNodes-changed.nodes),[],'all')<1e-8);
assert(norm(atNodes(movedIndex,:)-once.nodes(movedIndex,:))>.27);
assert(isequal(changed.params.routeSpline.stations,once.params.routeSpline.stations));
checks{end+1}='moving an inserted node changes the curve and preserves other interpolation constraints';

% A narrow field exposes an outside exact insertion: it must be skipped, not clipped.
outside=solar; outside.nodes=[0 0;10 0]; outside.targets=outside.nodes;
outside.params.bounds=[0 10 -.1 .1]; outside.params.headingDeg=90;
[skipped,skipInfo]=camdesign.refineRoute(outside);
assert(isequal(skipInfo.skippedSegments,1) && skipInfo.addedCoordinateDOF==0);
assert(skipInfo.skippedPoints(2)>.1 && isequal(skipped.nodes,outside.nodes));
assert(all(splineErrors(outside,skipped)<1e-11));
checks{end+1}='outside insertion skipped and reported without clipping or changing bounds';

bad=once; bad.params.routeSpline.stations(end)=bad.params.routeSpline.stations(end-1); mustReject(bad);
bad=once; bad.params.routeSpline.stations(end)=[]; mustReject(bad);
bad=once; bad.params.routeSpline.endDerivative=[0 0]; mustReject(bad);
bad=once; bad.params.routeSpline=rmfield(bad.params.routeSpline,'endDerivative'); mustReject(bad);
checks{end+1}='invalid station count/order and endpoint metadata rejected';

% Changing the physical initial direction must still take effect after freezing.
direction=once; direction.params.headingDeg=31; direction.params.startSteeringDeg=-7;
[hx,hy,hs]=camdesign.routeSpline(direction.nodes,direction.params);
initial=[ppval(camdesign.ppDerivative(hx,1),hs(1)),ppval(camdesign.ppDerivative(hy,1),hs(1))];
assert(norm(initial-[cosd(24),sind(24)])<1e-10);
checks{end+1}='current heading and initial steering still control the start derivative';

camdesign.saveProject(frozen,fullfile(folder,'solar_fixed_stations.mat'));
camdesign.saveProject(once,fullfile(folder,'solar_refined_once.mat'));
camdesign.saveProject(twice,fullfile(folder,'solar_refined_twice.mat'));
[loaded,notes]=camdesign.importProject(fullfile(folder,'solar_refined_twice.mat'));
assert(isequaln(loaded,twice) && isempty(notes));
checks{end+1}='MAT project round trip retains stations, endpoint derivative and ordered targets';

grids=[601 721;2401 2881]; numerical=cell(2,1);
for index=1:2
    before=solar; after=twice;
    before.params.samples=grids(index,1); before.params.camSamples=grids(index,2);
    after.params.samples=grids(index,1); after.params.camSamples=grids(index,2);
    a=camdesign.evaluate(before,false); b=camdesign.evaluate(after,false);
    item=struct('samples',grids(index,1),'camSamples',grids(index,2), ...
        'maxFrontDifferenceMM',max(vecnorm(a.route.front-b.route.front,2,2)), ...
        'maxHeadingDifferenceRad',max(abs(a.route.heading-b.route.heading)), ...
        'maxSteeringDifferenceRad',max(abs(a.route.steering-b.route.steering)), ...
        'maxCamDifferenceMM',max(vecnorm(a.cam.actual-b.cam.actual,2,2)), ...
        'pressureDifferenceDeg',abs(a.metrics.maxPressureDeg-b.metrics.maxPressureDeg), ...
        'scoreRelativeDifference',abs(a.metrics.score-b.metrics.score)/max(1,abs(a.metrics.score)));
    assert(item.maxFrontDifferenceMM<1e-8 && item.maxHeadingDifferenceRad<1e-9 ...
        && item.maxSteeringDifferenceRad<1e-9 && item.maxCamDifferenceMM<1e-6 ...
        && item.pressureDifferenceDeg<1e-5 && item.scoreRelativeDifference<1e-7);
    numerical{index}=item;
end
checks{end+1}='same-grid kinematics/cam preserved at baseline and four-times denser sampling';

probe=once; probe.params.samples=101; probe.params.camSamples=181; probe.params.iterations=1;
searchShape=[];
[optimized,~,optimizerInfo]=camdesign.optimize(probe,@observe,'peak-gradient-v2');
assert(isequal(searchShape,[size(once.nodes,1) 2]) && optimizerInfo.requestedIterations==1);
assert(size(optimized.nodes,1)==size(once.nodes,1) && isequaln(optimized.params,probe.params));
checks{end+1}='one-iteration integration exposes every added node to existing optimizer without parameter mutation';

report=struct('release',version('-release'),'checks',{checks}, ...
    'analyticDerivativeErrors',analyticErrors,'freezeErrors',freezeErrors, ...
    'onceErrors',onceErrors,'twiceErrors',twiceErrors, ...
    'once',onceInfo,'twice',twiceInfo,'outsideSkip',skipInfo, ...
    'numerical',{numerical},'optimizerGradientShape',searchShape, ...
    'optimizerIntegrationIterations',optimizerInfo.iterations, ...
    'optimizerIntegrationReason',optimizerInfo.reason, ...
    'scope','Independent clamped-cubic refinement, not original Bezier_superposition. Geometry/DOF/UI integration only; no optimizer-quality or engineering-feasibility claim.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for index=1:numel(checks), fprintf('ROUTE_REFINEMENT_CASE_PASS %s\n',checks{index}); end
fprintf('ROUTE_REFINEMENT_PASS cases=%d nodes=%d/%d/%d addedDOF=%d positionMaxMM=%.3g\n', ...
    numel(checks),size(solar.nodes,1),size(once.nodes,1),size(twice.nodes,1), ...
    onceInfo.addedCoordinateDOF+twiceInfo.addedCoordinateDOF,max([onceErrors(1),twiceErrors(1)]));
    function stop=observe(~,project,history)
        stop=false;
        if strcmp(history(end).event,'searching')
            searchShape=size(history(end).gradient);
            assert(isequaln(project.params,probe.params));
        end
    end
end

function errors=splineErrors(a,b)
[ax,ay,stations]=camdesign.routeSpline(a.nodes,a.params);
[bx,by,other]=camdesign.routeSpline(b.nodes,b.params);
assert(stations(1)==other(1) && stations(end)==other(end));
sample=linspace(stations(1),stations(end),10001)'; errors=zeros(1,4);
for order=0:3
    first=[ppval(camdesign.ppDerivative(ax,order),sample),ppval(camdesign.ppDerivative(ay,order),sample)];
    second=[ppval(camdesign.ppDerivative(bx,order),sample),ppval(camdesign.ppDerivative(by,order),sample)];
    errors(order+1)=max(abs(first-second),[],'all');
end
end
function mustReject(project)
rejected=false;
try, camdesign.validateProject(project); catch, rejected=true; end
assert(rejected,'Malformed fixed-station project was accepted.');
end
