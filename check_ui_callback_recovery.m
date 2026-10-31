function report=check_ui_callback_recovery(folder)
% No course data, calculate/apply/optimization, or existing desktop windows.
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','ui_callback_recovery_20261031','basic'); end
assert(~isfile(fullfile(folder,'verification.json')),'cam:EvidenceExists','已有检查结果，请使用新目录。');
if ~isfolder(folder), mkdir(folder); end
profile clear; profile on;
project=fixture(); app=CamReplicaApp('off',project,false); cleaner=onCleanup(@()closeOwn(app));
assert(iscell(app.TrainingApplyButton.ButtonPushedFcn) && iscell(app.TrainingResetButton.ButtonPushedFcn));
assert(strcmp(func2str(app.TrainingApplyButton.ButtonPushedFcn{1}),'cam_app_ui_dispatch'));
assert(strcmp(app.TrainingApplyButton.ButtonPushedFcn{3},'applyTraining'));
assert(strcmp(app.TrainingResetButton.ButtonPushedFcn{3},'syncTrainingInputs'));
% Install legacy-style handles without executing either button. These are
% deliberately replaced without reading or invoking the old handles.
app.TrainingApplyButton.ButtonPushedFcn=@(~,~)app.applyTraining();
app.TrainingResetButton.ButtonPushedFcn=@(~,~)app.syncTrainingInputs();
app.ParamsTable.Data{1,2}=123.45; app.TargetsTable.Data(2,2)=471; app.NodesTable.Data(2,1)=207;
app.WeightsTable.Data{1,2}=9; app.TrainingFields(6).Value=.7; app.TrainingModel.Value='bezier-blend-independent-v1';
app.DynamicWeightsEnabled.Value=true; app.DynamicWeightFields(2).Value=2.3;
app.AutoTuneFields(1).Value=3; app.TrainingDirty=true; app.Status.Text='synthetic pending input';
before=app.snapshotModelSwitchState(); figure=app.Figure; seedText=app.AutoTuneSeed.Text;
repair=repair_cam_app_callbacks(app,OutputFolder=fullfile(folder,'backups'));
assert(repair.stateUnchanged && isgraphics(figure) && isequal(figure,app.Figure));
assert(isequaln(before,app.snapshotModelSwitchState()) && isequaln(seedText,app.AutoTuneSeed.Text));
saved=load(repair.backupFile,'backup','metadata');
assert(isequaln(saved.backup,before) && isequaln(saved.metadata.AutoTuneSeedText,seedText));
second=repair_cam_app_callbacks(app,Backup=false); assert(second.alreadyBound && second.stateUnchanged);
% Startup must preserve an existing session instead of initializing defaults.
assignin('base','camReplicaApp',app); baseCleaner=onCleanup(@()evalin('base','clear camReplicaApp'));
lastwarn(''); retained=launch_cam_app(); [~,warningId]=lastwarn;
assert(isequal(retained,app) && strcmp(warningId,'cam:AppAlreadyOpen') && isequaln(before,app.snapshotModelSwitchState()));
clear baseCleaner;
% Only reset is invoked. Apply's callback is inspected above, never executed.
eventEngine=''; eventEngineError='';
try
    app.openTraining(); drawnow;
    tc=matlab.uitest.TestCase.forInteractiveUse;
    tc.press(app.TrainingResetButton); drawnow; eventEngine='matlab.uitest press';
catch ex
    eventEngineError=[ex.identifier ': ' ex.message];
    invoke(app.TrainingResetButton); eventEngine='direct real-control callback (UI test gesture unavailable)';
end
assert(~app.TrainingDirty && app.TrainingFields(6).Value==1 && strcmp(app.TrainingModel.Value,'cubic'));
assert(isequaln(app.Project,project) && app.ParamsTable.Data{1,2}==123.45 && app.TargetsTable.Data(2,2)==471);
assert(app.NodesTable.Data(2,1)==207 && app.WeightsTable.Data{1,2}==9);
profile off; data=profile('info');
names={data.FunctionTable.CompleteName}; counts=[data.FunctionTable.NumCalls];
evaluateCalls=sum(counts(contains(names,[filesep '+camdesign' filesep 'evaluate.m'])));
defaultCalls=sum(counts(contains(names,[filesep '+camdesign' filesep 'defaultProject.m']) | contains(names,[filesep '+camdesign' filesep 'teamSolarProject.m'])));
applyCalls=sum(counts(contains(names,'CamReplicaApp.applyTraining') | contains(names,'CamReplicaApp>CamReplicaApp.applyTraining')));
assert(evaluateCalls==0 && defaultCalls==0 && applyCalls==0);
drift=driftProbe(folder);
report=struct('release',version('-release'),'checksPassed',4,'repair',repair,'resetEventEngine',eventEngine, ...
    'resetEventEngineError',eventEngineError,'physicalEvaluateCalls',evaluateCalls,'defaultCourseFactoryCalls',defaultCalls, ...
    'realAppApplyCalls',applyCalls,'stateBeforeRepair',before,'autoTuneSeedText',seedText,'driftProbe',drift, ...
    'scope','Synthetic three-point input and UI state only. No actual course data, route calculation, apply action or optimization. User desktop window untouched.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('UI_CALLBACK_RECOVERY_PASS checks=4 evaluate=%d defaultCourse=%d apply=%d resetEngine=%s driftReproduced=%d\n', ...
    evaluateCalls,defaultCalls,applyCalls,eventEngine,drift.failureReproduced);
end
function project=fixture()
p=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
project=struct('schema','cam-replica-1','name','Synthetic UI-only fixture','params',p, ...
    'targets',[200 200;200 450;200 700],'nodes',[200 200;200 450;200 700],'provenance','Synthetic three-point input; never evaluated.');
end
function result=driftProbe(folder)
% Controlled source-lifecycle probe, no real app or model data. Absence of
% a failure is reported honestly; the user's old window is separate evidence.
probe=fullfile(folder,'drift_fixture'); mkdir(probe);
counterText=sprintf('classdef CallbackCounter016 < handle\n properties\n applied=0\n reset=0\n end\n methods\n function applyTraining(app), app.applied=app.applied+1; end\n function syncTrainingInputs(app), app.reset=app.reset+1; end\n end\nend\n');
write(fullfile(probe,'CallbackCounter016.m'),counterText);
factory=fullfile(probe,'legacy_training_callback016.m');
before=sprintf('function callback=legacy_training_callback016(app)\ncallback=@(~,~)app.applyTraining();\nend\n');
after=sprintf('function callback=legacy_training_callback016(app)\ncallback=@(~,~)app.syncTrainingInputs();\nend\n');
write(factory,before); write(fullfile(probe,'factory_before.txt'),before); addpath(probe); cleanup=onCleanup(@()rmpath(probe)); rehash;
counter=CallbackCounter016(); old=legacy_training_callback016(counter); save(fullfile(probe,'old_callback.mat'),'old','-v7');
write(factory,after); write(fullfile(probe,'factory_after.txt'),after); rehash;
identifier=''; message='';
try, old([],[]); catch ex, identifier=ex.identifier; message=ex.message; end
loadIdentifier=''; loadMessage='';
try
    loaded=load(fullfile(probe,'old_callback.mat'),'old'); loaded.old([],[]);
catch ex, loadIdentifier=ex.identifier; loadMessage=ex.message; end
cam_app_ui_dispatch([],[],counter,'syncTrainingInputs');
assert(counter.reset>=1);
result=struct('failureReproduced',~isempty(identifier) || ~isempty(loadIdentifier), ...
    'liveIdentifier',identifier,'liveMessage',message,'serializedIdentifier',loadIdentifier,'serializedMessage',loadMessage, ...
    'namedDispatchPassed',true,'scope','Temporary callback factory source replaced while old handle exists, plus saved-handle reload; no clear all/classes and no course/model calculations.');
end
function write(file,text), fid=fopen(file,'w','n','UTF-8'); assert(fid>=0); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text); end
function invoke(control), cb=control.ButtonPushedFcn; feval(cb{1},control,[],cb{2:end}); end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
