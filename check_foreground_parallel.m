function report=check_foreground_parallel(folder)
assert(batchStartupOptionUsed);
if nargin<1, folder=fullfile(pwd,'outputs','foreground_parallel_20261031','check_1'); end
assert(~isfolder(folder)); mkdir(folder); p=fixture(); checks={};
for cap=[4 11 100]
    [a,h,ia]=camdesign.optimizeFeasibilityFour(p,[],MaxIterations=1,FinalAssessment=false,MaxPhysicalEvaluations=cap,CandidateWorkers=0);
    [b,j,ib]=camdesign.optimizeFeasibilityFour(p,[],MaxIterations=1,FinalAssessment=false,MaxPhysicalEvaluations=cap);
    assert(isequaln(a,b) && isequaln([h.score],[j.score]) && ia.physicalEvaluations==ib.physicalEvaluations);
end
[a,~,ia]=camdesign.optimizeRelay(p,[],MaxPhysicalEvaluations=60,Starts=1,MaxIterations=1,FinalAssessment=false,CandidateWorkers=0);
[b,~,ib]=camdesign.optimizeRelay(p,[],MaxPhysicalEvaluations=60,Starts=1,MaxIterations=1,FinalAssessment=false);
assert(isequaln(a,b) && ia.physicalEvaluations==ib.physicalEvaluations);
checks{end+1}='direct default4 feasibility and relay equal explicit serial at the same physical budgets';
[~,~,stopped]=camdesign.optimizeFeasibilityFour(p,[],MaxIterations=2,FinalAssessment=false,StopCheck=@stopNow);
assert(strcmp(stopped.reason,'user_stop') && stopped.physicalEvaluations==5 && stopped.physicalBudget.reserved==0);
checks{end+1}='foreground batch StopCheck stops after first four-candidate window; initial plus four attempts settled exactly';
app=CamReplicaApp('off',p,false); cleaner=onCleanup(@()closeOwn(app)); app.calculate();
app.ParamsTable.Data{1,2}=111; app.TrainingFields(2).Value=8; app.TrainingDirty=true;
before=app.snapshotModelSwitchState(); old=uimenu(app.Figure,'Text','计算执行方式','Tag','cam-execution-menu');
uimenu(old,'Text','后台计算','MenuSelectedFcn',{@cam_app_ui_dispatch,app,'execution-background'});
setappdata(app.Figure,'camExecutionMode','background'); setappdata(app.Figure,'camBackgroundJob',struct('status','finished'));
migration=migrate_foreground_execution(app); after=app.snapshotModelSwitchState();
assert(isequaln(before,after) && migration.stateUnchanged && isempty(findall(app.Figure,'Tag','cam-execution-menu')));
assert(~isappdata(app.Figure,'camExecutionMode') && ~isappdata(app.Figure,'camBackgroundJob'));
assert(getappdata(app.Figure,'camCandidateEnabled') && getappdata(app.Figure,'camCandidateWorkers')==4);
[plan,audit]=cam_app_ui_binding_plan(app); assert(numel(plan)==71 && isempty(audit.unknown));
checks{end+1}='idle legacy menu migration backs up and preserves full project/results/history/pending values, removes execution mode and defaults to4';
app.Busy=true; id=''; try, migrate_foreground_execution(app); catch ex, id=ex.identifier; end; app.Busy=false;
assert(strcmp(id,'cam:ForegroundBusy')); checks{end+1}='active synchronous session migration refuses';
app.Project=p; app.syncInputs(); app.calculate(); app.History=struct('iteration',0,'score',app.Result.metrics.score); app.HistoryProject=app.Project;
before=app.snapshotModelSwitchState(); setappdata(app.Figure,'camCandidateWorkers',8);
app.AlgorithmSelector.Value='feasibility-four-direction-v1'; before=app.snapshotModelSwitchState();
push(app.Buttons(5)); after=app.snapshotModelSwitchState();
assert(isequaln(before.state,after.state) && isequaln(before.inputs,after.inputs)); setappdata(app.Figure,'camCandidateWorkers',4);
checks{end+1}='candidate resource/settings preflight refuses before clearing original result/history';
t=tic; push(app.Buttons(5)); elapsed=toc(t);
assert(~app.Busy && ~isempty(app.History) && app.Result.metrics.geometryChecked && ~isempty(app.OptimizationInfo.physicalBudget.parallelIntervals));
assert(~isappdata(app.Figure,'camBackgroundJob'));
checks{end+1}='real optimize callback is synchronous and complete on return with genuine candidate intervals and no detached job';
app.Project=p; app.syncInputs(); app.AlgorithmSelector.Value='peak-gradient-v2'; app.refreshTrainingControls();
push(app.Buttons(5)); assert(~app.Busy && strcmp(app.OptimizationInfo.algorithm,'peak-gradient-v2'));
assert(getappdata(app.Figure,'camCandidateEnabled') && any(contains(string(app.FullLog),'未接入候选并行')));
checks{end+1}='default enabled switch does not reject unsupported peak backend or change user switch; scope logged explicitly';
app.Project=p; app.Project.params.iterations=100; app.syncInputs(); app.AlgorithmSelector.Value='feasibility-four-direction-v1'; app.refreshTrainingControls();
timerObject=timer('StartDelay',.05,'TimerFcn',@stopUI,'UserData',app); timerCleanup=onCleanup(@()delete(timerObject)); start(timerObject);
push(app.Buttons(5)); assert(~app.Busy && strcmp(app.OptimizationInfo.reason,'user_stop'));
checks{end+1}='UI Stop event is processed by foreground drawnow, callback completes with checked best';
report=struct('checks',{checks},'checksPassed',numel(checks),'foregroundCallbackSeconds',elapsed,'lastLedger',ib.physicalBudget, ...
    'migration',migration,'scope','Handwritten3-point only; synchronous foreground callback and internal candidate threads. Timer only injects a UI Stop event, never performs model work. No user window/course data.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FOREGROUND_PARALLEL_PASS checks=%d defaults=4 callback=synchronous\n',numel(checks));
end
function yes=stopNow(), yes=true; end
function stopUI(timerObject,~)
app=timerObject.UserData; if isvalid(app) && isgraphics(app.Figure) && app.Busy, push(app.Buttons(6)); end
end
function push(control), cam_invoke_ui_callback(control.ButtonPushedFcn,control,[]); end
function p=fixture()
v=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
p=struct('schema','cam-replica-1','name','Handwritten foreground test','params',v,'nodes',[200 200;210 350;200 500], ...
    'targets',[200 200;210 350;200 500],'provenance','Handwritten synthetic only.');
end
function closeOwn(app)
if isgraphics(app.Figure), if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end; delete(app.Figure); end
end
