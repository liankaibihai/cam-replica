function report=check_relay_multistart(folder)
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','relay_multistart_20261031','contracts'); end
assert(~isfile(fullfile(folder,'verification.json')),'cam:EvidenceExists','已有核心合同结果，拒绝覆盖；请指定新的输出目录。');
if ~isfolder(folder), mkdir(folder); end
p=fixture(); original=p; checks={};
r=camdesign.evaluate(p,true); state=camdesign.feasibilityFourState(p,r); assert(state.feasible);
legacy=camdesign.fminconModel(p,p.nodes,r); shared=camdesign.fminconModel(p,p.nodes,r,0,'feasibility-quality-v1');
rate=diff(r.route.steering)./diff(r.route.frontDistance);
parts=[r.metrics.routeLength/max(1,sum(vecnorm(diff(p.targets),2,2))),mean((100*rate).^2),0];
assert(abs(legacy.objective-[p.params.weights(2:3) 1e-4]*parts')<1e-12);
assert(shared.objective==state.qualityObjective && isequal(shared.objectiveParts,state.qualityParts));
checks{end+1}='legacy fmincon objective unchanged; explicit quality mode exactly matches four-direction objective';

profile clear; profile on;
for limit=[1 2 7]
    [q,h,info]=camdesign.optimizeFeasibilityFour(p,[],MaxPhysicalEvaluations=limit,MaxIterations=20,FinalAssessment=false);
    assert(info.physicalEvaluations==limit && info.evaluations==limit && strcmp(info.reason,'physical_evaluation_limit'));
    assert(isequaln(q,p) && all([h.fullGeometryChecked]) && all([h.trainingFeasible]));
end
profile off; calls=physicalCalls(); assert(calls==10);
checks{end+1}='1/2/7-call four-direction stops mid-probe without overshoot or loss of fully qualified incumbent; profiler independently counts 10 evaluate calls';

seen=0; [q,~,info]=camdesign.optimizeFeasibilityFour(p,@stopInitial,MaxPhysicalEvaluations=100,FinalAssessment=false);
assert(isequaln(q,p) && strcmp(info.reason,'user_stop') && info.physicalEvaluations==1 && seen>=1);
checks{end+1}='four-direction callback stop performs no subsequent physical evaluations';

for limit=[1 2]
    [q,h,info]=camdesign.optimizeQualitySqp(p,[],MaxPhysicalEvaluations=limit,MaxIterations=20);
    assert(info.physicalEvaluations<=limit && strcmp(info.reason,'physical_evaluation_limit') && isequaln(q.params,p.params));
    assert(all([h.fullGeometryChecked]) && all([h.trainingFeasible]));
end
budget=camdesign.PhysicalEvaluationBudget(1000); stopUsed=NaN;
[q,stoppedHistory,info]=camdesign.optimizeQualitySqp(p,@stopSqp,Budget=budget,MaxIterations=20);
assert(strcmp(info.reason,'user_stop') && stoppedHistory(end).stopped && ~isnan(stopUsed) ...
    && budget.Used==stopUsed && camdesign.feasibilityFourState(q,info.cachedFinalResult).feasible);
checks{end+1}='SQP respects tiny hard budgets and never evaluates or accepts terminal iterates after callback stop';

profile clear; profile on;
[q,h,info]=camdesign.optimizeRelay(p,[],Mode='multistart-relay-sqp-v1',Starts=3,MaxPhysicalEvaluations=180,MaxIterations=2,FinalAssessment=false);
profile off; calls=physicalCalls(); assert(calls==info.physicalEvaluations && calls<=180);
assert(all([h.trainingFeasible]) && all([h.fullGeometryChecked]) && all(diff([h.qualityObjective])<=1e-9));
assert(~isempty(info.stages) && any(strcmp({info.stages.phase},'sqp')) && sum([info.stages.actualEvaluations])+1==calls);
assert(isequaln(q.params,p.params) && isequaln(q.targets,p.targets) && isequal(q.nodes(1,:),p.nodes(1,:)));
for limit=[1 2]
    [tiny,~,tinyInfo]=camdesign.optimizeRelay(p,[],Mode='multistart-relay-sqp-v1',Starts=5,MaxPhysicalEvaluations=limit,MaxIterations=2,FinalAssessment=false);
    assert(tinyInfo.physicalEvaluations<=limit && tinyInfo.allocatedStarts<=max(0,limit-1) && isequaln(tiny.params,p.params));
end
checks{end+1}='all starts/stages share one profiler-confirmed physical budget, carry unused quota, preserve feasible incumbent and immutable input; tiny budgets allocate only runnable starts';

file=fullfile(root,'data','feasibility_four_fixtures_20261031.json'); fixtures=jsondecode(fileread(file));
team=fixtures.missedPressurePeak.project; team.params.bounds=team.params.bounds(:)'; team.params.weights=team.params.weights(:)';
profile clear; profile on;
for limit=[10 67 137]
    [finiteDiff,~,finiteInfo]=camdesign.optimizeQualitySqp(team,[],MaxPhysicalEvaluations=limit,MaxIterations=10000);
    assert(finiteInfo.physicalEvaluations==limit && strcmp(finiteInfo.reason,'physical_evaluation_limit'));
    assert(finiteInfo.trainingFeasible && isequaln(finiteDiff.params,team.params));
end
profile off; assert(physicalCalls()==214);
checks{end+1}='66-variable SQP stops normally at exactly 10/67/137 physical attempts during finite differences; wrapped budget causes preserve the fully checked incumbent';
rngBefore=rng; [a,pa]=camdesign.relayPerturbation(team,3,5,20261031,8); [b,pb]=camdesign.relayPerturbation(team,3,5,20261031,8);
assert(isequaln(a,b) && isequaln(pa,pb) && isequaln(rng,rngBefore));
assert(pa.actualMaximumOffsetMM>0 && isequal(a.nodes(1:2,:),team.nodes(1:2,:)) && isequal(a.nodes(end-1:end,:),team.nodes(end-1:end,:)));
assert(isequaln(a.params,team.params) && isequaln(a.targets,team.targets));
checks{end+1}='private fixed random stream gives reproducible smooth/grouped nonzero perturbations without global RNG or hardware/model/endpoint mutation';

dynamic=p; dynamic.params.dynamicWeights=struct('enabled',true);
expect(@()camdesign.optimizeRelay(dynamic),'cam:RelayDynamicWeights');
file=fullfile(folder,'roundtrip_project.json'); camdesign.projectJSON('write',file,team); restored=camdesign.projectJSON('read',file);
assert(isequaln(restored,team) && isequaln(p,original));
checks{end+1}='unsupported dynamic weights explicitly reject and complete JSON project round-trip preserves numeric shapes/values';

[q,~,info]=camdesign.optimize(p,[],'relay-sqp-v1',struct('MaxPhysicalEvaluations',100,'MaxIterations',1));
assert(info.assessmentPerformed && info.assessmentEvaluationAttempts>=8 && info.verifiedFeasible ...
    && info.physicalEvaluations<=100 && camdesign.feasibilityFourState(q,info.cachedFinalResult).feasible);
checks{end+1}='dispatcher/final native-4x-8x verification use separate accounting and retain exact fully checked selection';
report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks},'relayInfo',info, ...
    'scope','Correctness and strict accounting only; short runs do not measure optimizer quality.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('RELAY_MULTISTART_CORE_PASS checks=%d\n',numel(checks));
    function stop=stopInitial(~,~,history)
        seen=seen+1; assert(~isempty(history(end).displayResult)); stop=true;
    end
    function stop=stopSqp(iter,~,history)
        stop=strcmp(history(end).event,'sqp_iteration') && iter>=1;
        if stop && isnan(stopUsed), stopUsed=budget.Used; end
    end
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=2;
p.params.samples=101; p.params.camSamples=181; p.params.sensorX=0; p.params.sensorY=0;
p.params.bounds=[0 1000 0 1000]; p.params.iterations=2;
p.nodes=[200 200;199 450;200 700]; p.targets=[200 200;200 450;200 700];
end
function count=physicalCalls()
data=profile('info'); names={data.FunctionTable.CompleteName};
use=contains(names,[filesep '+camdesign' filesep 'evaluate.m']); count=sum([data.FunctionTable(use).NumCalls]);
end
function expect(callback,id)
observed=''; try, callback(); catch ex, observed=ex.identifier; end
assert(strcmp(observed,id),'Expected %s, got %s',id,observed);
end
