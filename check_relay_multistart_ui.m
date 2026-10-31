function report=check_relay_multistart_ui(folder)
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','relay_multistart_20261031','ui'); end
assert(~isfile(fullfile(folder,'verification.json')),'cam:EvidenceExists','已有界面合同结果，拒绝覆盖；请指定新的输出目录。');
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app));
assert(strcmp(app.AlgorithmSelector.Value,'peak-gradient-v2'));
assert(all(ismember({'video-four-direction-v1','feasibility-four-direction-v1','relay-sqp-v1','multistart-relay-sqp-v1'},app.AlgorithmSelector.ItemsData)));
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=2; p.params.sensorX=0; p.params.sensorY=0;
p.params.samples=101; p.params.camSamples=181; p.params.bounds=[0 1000 0 1000]; p.params.iterations=1;
p.nodes=[200 200;199 450;200 700]; p.targets=[200 200;200 450;200 700];
app.Project=p; app.syncInputs(); app.calculate();
app.DynamicWeightsEnabled.Value=true; invoke(app.DynamicWeightsEnabled);
app.AlgorithmSelector.Value='multistart-relay-sqp-v1'; invoke(app.AlgorithmSelector); app.openTraining();
assert(strcmp(app.Buttons(5).Enable,'off') && app.DynamicWeightsEnabled.Value && contains(app.Buttons(5).Tooltip,'关闭'));
assert(contains(app.TrainingInfo.Text,'200000') && contains(app.TrainingInfo.Text,'5起点') && contains(app.TrainingInfo.Text,'训练轮数'));
assert(contains(app.TrainingInfo.Text,'SQP') && contains(app.TrainingInfo.Text,'0.0005mm'));
drawnow; exportapp(app.Figure,fullfile(folder,'dynamic_conflict.png'));
app.DynamicWeightsEnabled.Value=false; invoke(app.DynamicWeightsEnabled); app.calculate(); initial=app.Project;
profile clear; profile on; app.runOptimization(); profile off;
data=profile('info'); paths={data.FunctionTable.CompleteName}; use=contains(paths,[filesep '+camdesign' filesep 'evaluate.m']);
actualCalls=sum([data.FunctionTable(use).NumCalls]); info=app.OptimizationInfo;
assert(strcmp(info.algorithm,'multistart-relay-sqp-v1') && info.requestedStarts==5 && numel(info.starts)==5);
assert(info.physicalEvaluations<200000 && info.requestedIterations==1 && strcmp(info.reason,'starts_complete'));
assert(actualCalls==info.physicalEvaluations+info.assessmentEvaluationAttempts);
assert(all([app.History.trainingFeasible]) && all([app.History.fullGeometryChecked]));
assert(isequaln(app.Project.params,initial.params) && isequaln(app.Project.targets,initial.targets) && isequal(app.Project.nodes(1,:),initial.nodes(1,:)));
assert(contains(app.Status.Text,'实际调用') && contains(app.Status.Text,'终止') && contains(app.Status.Text,'4/8倍'));
assert(contains(app.TrainingRuntime.Text,'complete') && contains(app.TrainingRuntime.Text,'物理调用') && startsWith(app.TrainingRuntime.Text,'本次'));
assert(isempty(app.ContestGeometryReport));
app.openTraining(); drawnow; exportapp(app.Figure,fullfile(folder,'completed.png'));
runtime=app.TrainingRuntime.Text; app.TrainingFields(1).Value=2; invoke(app.TrainingFields(1));
assert(app.TrainingDirty && startsWith(app.TrainingRuntime.Text,'上次'));
drawnow; exportapp(app.Figure,fullfile(folder,'historical_input.png'));
report=struct('release',version('-release'),'checksPassed',3,'physicalEvaluateProfilerCalls',actualCalls, ...
    'searchEvaluations',info.physicalEvaluations,'independentAssessmentEvaluations',info.assessmentEvaluationAttempts, ...
    'info',info,'completedRuntime',runtime,'historicalRuntime',app.TrainingRuntime.Text, ...
    'scope','Owned hidden UI and call-accounting contract; one iteration per stage is not an optimizer-quality result.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('RELAY_MULTISTART_UI_PASS checks=3 search=%d independent=%d profiler=%d\n',info.physicalEvaluations,info.assessmentEvaluationAttempts,actualCalls);
end
function invoke(control), callback=control.ValueChangedFcn; cam_invoke_ui_callback(callback,control,[]); end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
