function report=check_feasibility_four()
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','feasibility_four_20261031','contracts');
if ~isfolder(folder), mkdir(folder); end
fixtures=jsondecode(fileread(fullfile(root,'data','feasibility_four_fixtures_20261031.json')));
p=fixture(); result=camdesign.evaluate(p,true); good=camdesign.feasibilityFourState(p,result);
assert(good.feasible && good.fullChecked && all(good.violations==0));
curve=p; curve.nodes(2,1)=curve.nodes(2,1)+20; curved=camdesign.evaluate(curve,true);
curve.params.maxPressureDeg=curved.metrics.maxPressureDeg-1e-9;
bad=camdesign.feasibilityFourState(curve,curved); bad.qualityObjective=good.qualityObjective/2;
assert(~bad.feasible && bad.violations(2)>0 && ~camdesign.feasibilityFourBetter(bad,good));
fake=result; fake.metrics.minUndercutMargin=0;
assert(~camdesign.feasibilityFourState(p,fake).feasible);
fake=result; fake.metrics.intersectionCount=1; crossing=camdesign.feasibilityFourState(p,fake);
crossing.qualityObjective=0; assert(~crossing.feasible && ~camdesign.feasibilityFourBetter(crossing,good));
fake=result; fake.visitOrder=camdesign.visitOrderAudit([result.route.sensor;flipud(result.route.sensor)],p.targets,p.params.hitTolerance);
wrong=camdesign.feasibilityFourState(p,fake); wrong.qualityObjective=0;
assert(~wrong.feasible && wrong.violations(8)>0 && ~camdesign.feasibilityFourBetter(wrong,good));
fast=camdesign.feasibilityFourState(p,camdesign.evaluate(p,false)); fast.qualityObjective=0;
assert(~fast.fullChecked && ~camdesign.feasibilityFourBetter(fast,good));
checks={'exact hard thresholds, zero undercut and discrete topology/order failures cannot be hidden by ranking tolerance or lower length-quality cost; fast probes cannot accept'};

infeasible=bad; infeasible.violationSquared=1; infeasible.maxNormalizedViolation=1;
less=infeasible; less.violationSquared=.5; less.maxNormalizedViolation=.5;
less.qualityObjective=1e6; assert(camdesign.feasibilityFourBetter(less,infeasible));
short=good; short.qualityObjective=good.qualityObjective*.99; assert(camdesign.feasibilityFourBetter(short,good));
assert(camdesign.feasibilityFourBetter(good,bad));
checks{end+1}='infeasible comparison prioritizes violation over reference/quality; fully feasible incumbent only improves within feasible set';

original=p; observations={};
[q,h,info]=camdesign.optimize(p,@observe,'feasibility-four-direction-v1');
assert(isequaln(q.params,p.params) && isequal(q.targets,p.targets) && isequal(q.nodes(1,:),p.nodes(1,:)));
assert(info.iterations==p.params.iterations && all([h.fullGeometryChecked]) && all([h.trainingFeasible]));
assert(all(diff([h.qualityObjective])<=1e-9));
for k=1:numel(h)
    candidate=p; candidate.nodes=h(k).nodes; full=camdesign.evaluate(candidate,true);
    assert(camdesign.feasibilityFourState(candidate,full).feasible);
end
assert(info.fullGeometryEvaluations>=nnz([h.accepted])+1 && info.verifiedFeasible && info.convergencePassed);
assert(~isempty(observations) && all(isfield(h,{'feasibilityStage','violationSquared','qualityObjective','score'})));
checks{end+1}='every accepted feasible-shortening step independently full checked; parameter/start/model locks and final 4x/8x assessment retained';

dynamic=p; dynamic.params.dynamicWeights=struct('enabled',true);
expect(@()camdesign.optimize(dynamic,[],'feasibility-four-direction-v1'),'cam:FeasibilityDynamicWeights');
[stopped,stopHistory,stopInfo]=camdesign.optimize(p,@(~,~,~)true,'feasibility-four-direction-v1');
assert(isequaln(stopped,p) && stopInfo.iterations==0 && strcmp(stopInfo.reason,'user_stop') && stopHistory(end).stopped);
assert(isequaln(p,original));
checks{end+1}='dynamic weights explicitly reject, callback stop works, and inputs never mutate';

% Real team new-Bezier seed exercises infeasible restoration, with unchanged
% physical parameters and no claim from a short functionality test.
team=fixtureProject(fixtures.teamSeed);
team.params.iterations=2; [candidate,trace,teamInfo]=camdesign.optimize(team,[],'feasibility-four-direction-v1');
assert(isequaln(candidate.params,team.params) && all([trace.fullGeometryChecked]));
assert(trace(end).violationSquared<trace(1).violationSquared);
checks{end+1}='fixed team Bezier restoration accepts only fully audited lower-violation candidates; short test is not a quality verdict';

v2=fixtureProject(fixtures.missedPressurePeak);
native=camdesign.evaluate(v2,true); preserved=native; probe=camdesign.pressurePreferenceProbe(native.cam,v2.params);
assert(probe.maxPressureDeg>native.metrics.maxPressureDeg+.05 && probe.sampleCount>numel(native.cam.phi));
poisoned=native.cam; poisoned.workRadius=NaN; poisoned.radius=NaN; poisoned.pitch='unused';
assert(isequaln(probe,camdesign.pressurePreferenceProbe(poisoned,v2.params)) && isequaln(native,preserved));
state=camdesign.feasibilityFourState(v2,native);
assert(state.feasible && probe.maxPressureDeg>v2.params.maxPressureDeg && state.pressurePreference.preferredMarginDeg==.5);
checks{end+1}='same saved workPP pressure probe finds native missed peak, ignores poisoned legacy samples, and keeps native gates/metrics unchanged';

near=fixtureProject(fixtures.nearControlBound); near.params.gradientProbeMM=.5;
assert(near.nodes(2,1)<0 && near.nodes(2,1)>-1e-10 && near.nodes(2,2)<0);
% Preserve the actual mapped X residual; remove only the other roundoff
% residual so a single coordinate probe can cross the exact boundary.
near.nodes(2,2)=0;
nearState=camdesign.feasibilityFourState(near,camdesign.evaluate(near,true));
assert(~nearState.feasible && nearState.fullChecked && nnz(nearState.violations)==1 && nearState.violations(7)>0);
[promoted,promotionHistory]=camdesign.optimize(near,[],'feasibility-four-direction-v1');
assert(promotionHistory(end).trainingFeasible && contains(promotionHistory(end).stepType,'promotion'));
assert(abs(promoted.nodes(2,1)-near.nodes(2,1)-.25)<1e-10);
checks{end+1}='tiny real control-bound violation stays infeasible; a full checked feasible coordinate transition is prioritized and honors learning scale';

lockFolder=fullfile(root,'outputs','feasibility_four_20261031','feasibility','primary_lock_contract'); if ~isfolder(lockFolder), mkdir(lockFolder); end
lockPath=fullfile(lockFolder,'run.lock'); lock=java.io.File(lockPath); assert(lock.createNewFile()); lockCleanup=onCleanup(@()delete(lockPath));
expect(@()check_feasibility_four_quality('run','feasibility-four-direction-v1','primary_lock_contract'),'cam:ExperimentRunning');
assert(isfile(lockPath) && ~isfile(fullfile(lockFolder,'solver_result.mat'))); clear lockCleanup;
checks{end+1}='atomic quality run lock rejects a second runner without deleting another owner lock or writing experiment results';

report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks}, ...
    'feasibleFixtureInitial',good,'feasibleFixtureFinal',info.finalMetrics,'feasibleInfo',info, ...
    'teamInitialViolation',trace(1).violationSquared,'teamFinalViolation',trace(end).violationSquared, ...
    'teamInfo',teamInfo,'pressurePreferenceProbe',probe,'nearControlBoundInitial',nearState, ...
    'fixtureFile','data/feasibility_four_fixtures_20261031.json', ...
    'scope','Functional sorting/gating and exact-constraint regressions; long paired quality evidence is stored separately.');
save(fullfile(folder,'results.mat'),'report','q','h','info');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FEASIBILITY_FOUR_CORE_PASS checks=%d teamViolation=%.9g -> %.9g fullFeasibleFixture=%d\n',numel(checks),trace(1).violationSquared,trace(end).violationSquared,info.verifiedFeasible);
    function stop=observe(~,~,history)
        stop=false; if strcmp(history(end).event,'searching'), observations{end+1}=history(end); end
    end
end
function project=fixtureProject(entry)
project=entry.project;
project.params.bounds=reshape(project.params.bounds,1,[]);
project.params.weights=reshape(project.params.weights,1,[]);
camdesign.validateProject(project);
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35; p.params.sensorX=0; p.params.sensorY=0;
p.params.samples=101; p.params.camSamples=181; p.params.bounds=[0 1000 0 1000]; p.params.iterations=4;
p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
end
function expect(callback,wanted)
id=''; try, callback(); catch ex, id=ex.identifier; end; assert(strcmp(id,wanted),'Expected %s, got %s',wanted,id);
end
