function report=check_candidate_parallel(folder)
assert(batchStartupOptionUsed);
if nargin<1, folder=fullfile(pwd,'outputs','candidate_parallel_20261031','check_1'); end
assert(~isfolder(folder)); mkdir(folder);
pool=cam_candidate_pool(4); poolCleanup=onCleanup(@()delete(pool));
p=fixture(); f=parfeval(pool,@contracts,1,p); report=fetchOutputs(f);
assert(report.overlapSeconds>0 && report.budgetEqual && report.resultsEqual && report.invalidCount==1);
app=CamReplicaApp('off',p,false); cleaner=onCleanup(@()closeOwn(app)); app.calculate();
cam_app_async('install',app); cam_candidate_ui(app,'install');
assert(~isappdata(app.Figure,'camCandidateEnabled'));
for key={'candidate-toggle','candidate-four'}
    menu=findall(app.Figure,'Tag',['cam-' key{1}]); cam_invoke_ui_callback(menu.MenuSelectedFcn,menu,[]);
end
[plan,audit]=cam_app_ui_binding_plan(app); assert(numel(plan)==74 && isempty(audit.unknown));
app.AlgorithmSelector.Value='feasibility-four-direction-v1'; app.refreshTrainingControls();
cam_invoke_ui_callback(app.Buttons(5).ButtonPushedFcn,app.Buttons(5),[]);
t=tic; while cam_app_async('status',app).active && toc(t)<60, drawnow; pause(.02); end
s=cam_app_async('status',app); assert(strcmp(s.status,'finished'),'%s',jsonencode(s));
assert(app.OptimizationInfo.physicalBudget.reserved==0 && ~isempty(app.OptimizationInfo.physicalBudget.parallelIntervals));
report.ui=s; report.uiLedger=app.OptimizationInfo.physicalBudget;
before=app.snapshotModelSwitchState();
cam_invoke_ui_callback(app.Buttons(5).ButtonPushedFcn,app.Buttons(5),[]);
cam_app_async('cancel',app); t=tic;
while cam_app_async('status',app).active && toc(t)<60, drawnow; pause(.02); end
canceled=cam_app_async('status',app); assert(strcmp(canceled.status,'canceled') && canceled.summary.resultSaved);
after=app.snapshotModelSwitchState(); assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs));
saved=load(canceled.summary.resultFile,'outcome');
if isfield(saved.outcome,'candidateLedger'), assert(saved.outcome.candidateLedger.reserved==0); end
report.canceled=canceled;
cam_app_async('mode',app,'foreground');
cam_invoke_ui_callback(app.Buttons(5).ButtonPushedFcn,app.Buttons(5),[]);
assert(~app.Busy && contains(app.Status.Text,'未启动串行替代'));
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CANDIDATE_PARALLEL_PASS equal=1 budget=1 overlap=%.6g UI=finished\n',report.overlapSeconds);
end
function report=contracts(p)
for cap=[4 11 100]
    [a,h,ia]=camdesign.optimizeFeasibilityFour(p,[],MaxPhysicalEvaluations=cap,MaxIterations=1,FinalAssessment=false);
    [b,j,ib]=camdesign.optimizeFeasibilityFour(p,[],MaxPhysicalEvaluations=cap,MaxIterations=1,FinalAssessment=false,CandidateWorkers=4);
    assert(isequaln(a,b) && isequaln([h.score],[j.score]) && ia.physicalEvaluations==ib.physicalEvaluations);
end
[a,~,ia]=camdesign.optimizeRelay(p,[],MaxPhysicalEvaluations=60,Starts=1,MaxIterations=1,FinalAssessment=false);
[b,~,ib]=camdesign.optimizeRelay(p,[],MaxPhysicalEvaluations=60,Starts=1,MaxIterations=1,FinalAssessment=false,CandidateWorkers=4);
assert(isequaln(a,b) && ia.physicalEvaluations==ib.physicalEvaluations);
relayEvaluations=ib.physicalEvaluations;
budget=camdesign.PhysicalEvaluationBudget(3); bad=p; bad.nodes(2,:)=bad.nodes(1,:);
items=budget.evaluateBatch({p,bad,p},false,3,2); assert(budget.Used==3 && budget.Invalid==1 && budget.Reserved==0);
intervals=budget.ParallelIntervals;
overlap=max(0,min(intervals(1,2),intervals(2,2))-max(intervals(1,1),intervals(2,1)))*86400;
% Stop during search is cooperative after the complete probe sweep settles.
[~,~,stop]=camdesign.optimizeFeasibilityFour(p,@stopAfterProbe,MaxIterations=2,FinalAssessment=false,CandidateWorkers=4);
assert(strcmp(stop.reason,'user_stop') && stop.physicalBudget.reserved==0);
report=struct('resultsEqual',true,'budgetEqual',true,'invalidCount',budget.Invalid,'overlapSeconds',overlap, ...
    'intervals',intervals,'stop',stop.reason,'relayEvaluations',relayEvaluations,'scope','Handwritten small input only; real candidate overlap, no competition speed claim.');
end
function stop=stopAfterProbe(~,~,h), stop=strcmp(h(end).event,'searching'); end
function p=fixture()
v=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
p=struct('schema','cam-replica-1','name','Handwritten parallel probes','params',v,'nodes',[200 200;210 350;200 500], ...
    'targets',[200 200;210 350;200 500],'provenance','Handwritten synthetic only.');
end
function closeOwn(app)
if isgraphics(app.Figure)
    if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
    delete(app.Figure);
end
end
