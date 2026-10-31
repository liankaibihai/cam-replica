function report=check_foreground_cleanup(folder)
assert(batchStartupOptionUsed); if nargin<1, folder=fullfile(pwd,'outputs','foreground_parallel_20261031','cleanup_3'); end
assert(~isfolder(folder)); mkdir(folder); p=fixture(); pool=cam_candidate_pool(4);
unrelated=parfeval(pool,@delayed,1); budget=camdesign.PhysicalEvaluationBudget(8);
lastwarn(''); id=''; try, budget.evaluateBatch({p,p,p,p,p,p},false,8,4,@injected); catch ex, id=ex.identifier; end
[message,~]=lastwarn; assert(isempty(message),'Cleanup warning: %s',message);
assert(strcmp(id,'cam:InjectedCleanup') && budget.Used==4 && budget.Reserved==0);
assert(fetchOutputs(unrelated)==42 && isempty(unrelated.Error));
assert(isempty(pool.FevalQueue.RunningFutures) && isempty(pool.FevalQueue.QueuedFutures));
app=CamReplicaApp('off',p,false); cleaner=onCleanup(@()delete(app.Figure)); migrate_foreground_execution(app);
app.AlgorithmSelector.Value='feasibility-four-direction-v1'; app.refreshTrainingControls();
cam_invoke_ui_callback(app.Buttons(5).ButtonPushedFcn,app.Buttons(5),[]);
assert(~app.Busy && ~isempty(app.Result) && app.Result.metrics.geometryChecked);
assert(isempty(findall(app.Figure,'Tag','cam-execution-menu')) && getappdata(app.Figure,'camCandidateEnabled') && getappdata(app.Figure,'camCandidateWorkers')==4);
assert(~isfile('cam_app_async.m') && ~isfile('cam_app_async_worker.m'));
drawnow; exportapp(app.Figure,fullfile(folder,'foreground_default4.png'));
report=struct('injectedIdentifier',id,'settledAttempts',budget.Used,'reserved',budget.Reserved,'unrelatedFuturePreserved',true, ...
    'ownedTasksRemaining',0,'synchronousResultComplete',true,'defaultThreads',4,'backgroundModeRemoved',true, ...
    'scope','Controlled exception at drained batch boundary; no literal Ctrl+C or forced worker crash injected. Small handwritten input only.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FOREGROUND_CLEANUP_PASS attempts=4 reserved=0 unrelated=preserved sync=complete\n');
end
function yes=injected(), error('cam:InjectedCleanup','Controlled caller failure.'); yes=false; end %#ok<UNRCH>
function value=delayed(), pause(.5); value=42; end
function p=fixture()
v=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
p=struct('schema','cam-replica-1','name','Handwritten foreground cleanup','params',v,'nodes',[200 200;210 350;200 500], ...
    'targets',[200 200;210 350;200 500],'provenance','Handwritten synthetic only.');
end
