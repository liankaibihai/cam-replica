function smoke_test()
% Small hand-written fixture: no competition-route optimization.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
p=camdesign.defaultProject();
p.nodes=[0 0;500 0;1000 0]; p.targets=p.nodes;
p.params.headingDeg=0; p.params.sensorX=0; p.params.sensorY=0;
r=camdesign.evaluate(p);
assert(max(abs(r.route.steering))<1e-10);
assert(abs(r.route.driveDistance(end)-1000)<1e-8);
assert(r.metrics.maxHitError<1e-8);
assert(all(isfinite(r.cam.actual),'all'));
% Confirm distributed data resolve, without evaluating the competition case.
example=camdesign.teamSolarProject();
assert(example.params.gearRatio==35 && strcmp(example.params.mechanism,'flat'));
% Exercise the packaged UI and default thread configuration on the tiny case.
app=CamReplicaApp('off',p,false);
cleanup=onCleanup(@()delete(app.Figure));
app.calculate(); migrate_foreground_execution(app);
assert(getappdata(app.Figure,'camCandidateEnabled'));
assert(getappdata(app.Figure,'camCandidateWorkers')==4);
assert(~isempty(app.Result));
fprintf('PUBLIC_SMOKE_PASS: analytical straight route, data resolution, GUI, default4\n');
end
