function report=check_visit_export_fixes
% Review G1/R5 regressions, independent polyline audit and physical reports.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
folder=fullfile(fileparts(mfilename('fullpath')),'outputs','review_fixes_20261031','gates');
if ~isfolder(folder), mkdir(folder); end
targets=[0 0;100 0;100 100];
paths={targets,[0 0;100 100;100 0;100 100],[targets;100 0], ...
    [0 0;0 0;10 0;100 0;100 100]}; expected=[true false false true];
checks={};
for k=1:numel(paths)
    xy=paths{k}; v=camdesign.visitOrderAudit(xy,targets,8.5);
    r=struct('front',xy,'rear',xy,'drive',xy,'driven',xy,'sensor',xy);
    old=camdesign.auditSolarRoute(r,targets,[-200 200 -200 200],8.5);
    assert(v.matchesRequiredOrderAndVisitCount==expected(k));
    assert(isequal(v.observedLocationIDs,old.recognitionScenarios{1}.observedLocationIDs));
end
checks{end+1}='continuous segment entries agree with independent audit; early/repeated visits fail, dwell counted once';
closed=[targets;targets(1,:)]; a=camdesign.visitOrderAudit(closed,closed,8.5);
assert(a.matchesRequiredOrderAndVisitCount && isequal(a.observedLocationIDs,[1 2 3 1]));
miss=camdesign.visitOrderAudit(targets,closed,8.5); assert(~miss.matchesRequiredOrderAndVisitCount);
amb=camdesign.visitOrderAudit([-100 0;100 0],[0 -1;0 1],10);
assert(amb.ambiguousSimultaneousEntries && ~amb.matchesRequiredOrderAndVisitCount);
checks{end+1}='closing target requires a separate visit; simultaneous ambiguous entries rejected';
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35;
p.params.sensorX=0; p.params.sensorY=0; p.params.samples=101; p.params.camSamples=181;
p.params.bounds=[0 1000 0 1000]; p.nodes=[60 200;60 450;60 700]; p.targets=p.nodes;
r=camdesign.evaluate(p,true); fast=camdesign.evaluate(p,false);
assert(~fast.metrics.visitOrderChecked && isempty(fast.visitOrder));
assert(r.metrics.visitOrderSatisfied && ~r.metrics.trajectoryBoundsSatisfied);
assert(abs(r.metrics.maxTrajectoryOutsideMM-19.85)<1e-8);
files=camdesign.exportResult(p,r,fullfile(folder,'outside_candidate'));
d=jsondecode(fileread(files.report));
assert(~d.trajectoryBounds.satisfied && abs(d.metrics.maxTrajectoryOutsideMM-19.85)<1e-8);
assert(any(contains(string(d.warnings),'出界')) && d.visitOrder.matchesRequiredOrderAndVisitCount);
assert(strcmp(d.validation.independentRefinement,'not_run_by_export') && ~d.validation.manufacturingApproved);
checks{end+1}='export recomputes and records boundary violation, visit order, grid and unperformed refinement';
p.nodes(:,1)=200; p.targets=p.nodes; r=camdesign.evaluate(p,true);
v=camdesign.verifyConstrained(p,4);
assert(v.verifiedFeasible && v.visitOrderSatisfied && v.optimizationGrid.visitOrderSatisfied && v.refinedGrid.visitOrderSatisfied);
% Smooth two-lap geometric route exposes the difference between finding a
% subsequence of target projections and requiring the complete event order.
q=p; theta=linspace(0,4*pi,101)'; q.nodes=[1000+500*cos(theta),1000+500*sin(theta)];
q.nodes(end,:)=q.nodes(1,:);
q.params.startSteeringDeg=asind(-q.params.driveY/500); q.params.headingDeg=90-q.params.startSteeringDeg;
q=camdesign.refineRoute(q,[]); q.params.routeSpline.endDerivative=[0 1];
q.params.bounds=[0 2000 0 2000]; q.params.samples=1201; q.params.camSamples=1441;
q.targets=q.nodes([1 26 14 101],:); rr=camdesign.evaluate(q,true); vv=camdesign.verifyConstrained(q,2);
assert(~rr.metrics.visitOrderSatisfied && ~vv.visitOrderSatisfied && ~vv.verifiedFeasible);
assert(~isempty(vv.refinedGrid.visitOrder.observedLocationIDs));
checks{end+1}='both-grid verifier gates visit order, retaining valid straight pass and rejecting repeated circuit';
report=struct('release',version('-release'),'checks',{checks},'passed',numel(checks), ...
    'outsideMM',d.metrics.maxTrajectoryOutsideMM,'repeatedCircuitVisitOrder',rr.visitOrder, ...
    'radiusPolicy','uses existing hitTolerance as explicit geometric radius, not RFID measurement');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); fprintf('VISIT_EXPORT_FIXES_PASS %d\n',numel(checks));
end
