function report=check_auto_tune()
% Contract runs are deliberately short and do not judge optimizer quality.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
folder=fullfile(fileparts(mfilename('fullpath')),'outputs','auto_tune_20261030','contracts');
if ~isfolder(folder), mkdir(folder); end
p=camdesign.solarTestProject(); original=p; cfg=camdesign.autoTuneSettings(p.params);
assert(isequaln(p,original) && cfg.trials==8 && cfg.maxIterations==600);
bad=p.params; bad.autoTune=struct('trials',0); caught=false;
try, camdesign.autoTuneSettings(bad); catch, caught=true; end
assert(caught); checks={'optional settings are read-only and invalid budgets are rejected'};
p.params.autoTune=struct('trials',4,'maxIterations',2,'seed',2027,'polishCount',0);
p.params.dynamicWeights=struct('enabled',true);
state=rng; [q,h,info]=camdesign.optimize(p,@observe,'auto-tune-v1');
assert(isequaln(state,rng) && info.physicalParametersUnchanged);
assert(q.params.gearRatio==35 && isequal(q.params.weights,p.params.weights));
assert(isequal(q.params.dynamicWeights,p.params.dynamicWeights));
assert(isequal(q.params.autoTune.selectedWeights,info.finalActiveWeights));
assert(numel(info.trials)==5 && all([h.autoTotalBudget]==8) && all(diff([h.iteration])>=0));
assert(~isfield(h,'objective') && all(strcmp({h.weightMode},'auto-tuned-v1')));
assert(isequal(h(end).activeWeights,info.finalActiveWeights) && isequal(h(end).referenceWeights,p.params.weights));
assert(all(any(vertcat(info.trials.weights)~=p.params.weights,1)));
assert(info.verifiedFeasible==info.assessment.verifiedFeasible && ~info.verifiedFeasible);
checks{end+1}='six positive weights participate; fixed hardware/thresholds/reference weights and caller RNG stay unchanged';
[q2,h2,info2]=camdesign.optimize(p,[],'auto-tune-v1');
assert(isequaln(q,q2) && isequaln([h.score],[h2.score]) && isequaln(info.finalActiveWeights,info2.finalActiveWeights));
checks{end+1}='same seed/input reproduces candidate configurations and selected project';
[qs,hs,is]=camdesign.optimize(p,@(~,~,~)true,'auto-tune-v1');
assert(is.iterations==0 && strcmp(is.reason,'user_stop') && numel(is.trials)==1 && isequal(qs.nodes,p.nodes));
assert(isequal(hs(end).activeWeights,p.params.weights));
checks{end+1}='stop before search preserves geometry and starts no portfolio or polish trial';
camdesign.saveProject(q,fullfile(folder,'roundtrip.mat')); qr=camdesign.importProject(fullfile(folder,'roundtrip.mat'));
assert(isequaln(qr.params.autoTune,q.params.autoTune));
checks{end+1}='budget and learned weights persist through project save/import';
straight=straightCase(295); a=camdesign.autoTuneAssessment(straight);
assert(a.verifiedFeasible && a.convergencePassed && a.eight.refinedGrid.metrics.maxPressureDeg<1e-6);
fail=straightCase(330); b=camdesign.autoTuneAssessment(fail);
assert(b.convergencePassed && ~b.verifiedFeasible && ~b.eight.refinedGrid.metrics.returnAngleSatisfied);
checks{end+1}='analytical straight cam passes; stable numerics with insufficient return angle still fails strict gates';
assert(a.numericalChecks.passed && a.numericalChecks.camMaxDifferenceMM<1e-8 && a.numericalChecks.inverseFrontMaxErrorMM<1e-6);
straight.params.autoTune=struct('trials',2,'maxIterations',2,'seed',2027,'polishCount',1);
[~,hp,ip]=camdesign.optimize(straight,@(~,~,hh)strcmp(hh(end).autoStage,'polish'),'auto-tune-v1');
polish=hp(strcmp({hp.autoStage},'polish'));
assert(~isempty(polish) && strcmp(ip.reason,'user_stop') && polish(1).trainingSamples>=601);
assert(polish(1).nominalDifferenceStepMM==.01 && polish(1).trainingControls.gradientForce==.01);
checks{end+1}='polish records actual local difference scale, uses at least common sampling, and honors stop before solver steps';
changed=p; changed.params.weights=[0 2 1 1 1 1]; changed.params.autoTune.selectedWeights=ones(1,6)*100;
changed.params.autoTune.trials=2; changed.params.autoTune.maxIterations=1;
[~,hc,~]=camdesign.optimize(changed,@(~,~,hh)strcmp(hh(end).autoStage,'search'),'auto-tune-v1');
search=hc(strcmp({hc.autoStage},'search'));
assert(isequal(search(1).activeWeights,[0 8 4 4 4 4]));
checks{end+1}='reused learned weights obey newly edited base zeros and bounds';
failure=p; failure.params.autoTune.trials=2;
[~,hf,fi]=camdesign.optimize(failure,@injectNumericalFailure,'auto-tune-v1');
assert(strcmp(fi.trials(2).reason,'invalid_configuration') && fi.trials(2).iterations==1);
assert(fi.trials(2).evaluations>0 && all(diff([hf.iteration])>=0));
checks{end+1}='injected mid-trial geometry failure retains observed work and does not rewind cumulative progress';
save(fullfile(folder,'short_contract.mat'),'p','q','h','info','a','b');
report=struct('release',version('-release'),'checks',{checks},'scope','Short interface and analytic gate checks, not convergence-quality evidence.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fprintf('AUTO_TUNE_CONTRACT_PASS cases=%d\n',numel(checks));
end
function stop=observe(~,project,h)
assert(project.params.gearRatio==35 && project.params.maxPressureDeg==35 && project.params.returnAngleDeg==60);
assert(isequal(project.params.weights,[12 1 2 3 10 10]));
assert(abs(h(end).score-sum(h(end).referenceWeights.*h(end).metrics.terms))<1e-8);
assert(abs(h(end).dynamicScore-sum(h(end).activeWeights.*h(end).metrics.terms))<1e-8);
r=camdesign.evaluate(project,false);
assert(abs(r.metrics.score-h(end).score)<1e-8 && isequal([project.params.samples project.params.camSamples],h(end).comparisonGrid));
stop=false;
end
function stop=injectNumericalFailure(~,~,h)
if strcmp(h(end).autoStage,'search') && h(end).autoTrial==1 && h(end).trialIteration>=1
    error('cam:RouteSingularity','Injected numerical failure after a completed iteration.');
end
stop=false;
end
function p=straightCase(degrees)
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.wheelDiameter=100;
p.params.gearRatio=35; p.params.autoRatio=false; p.params.headingDeg=0;
p.params.startSteeringDeg=0; p.params.sensorX=0; p.params.sensorY=0;
p.params.samples=101; p.params.camSamples=181; p.params.bounds=[-1000 20000 -1000 1000];
distance=deg2rad(degrees)*100*35/2; p.nodes=[0 0;distance/2 0;distance 0]; p.targets=p.nodes;
end
