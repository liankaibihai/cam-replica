function report=check_ui_all_callbacks(folder)
% Synthetic UI and dispatch spies only. No course/physics/business actions.
assert(batchStartupOptionUsed); root=fileparts(mfilename('fullpath'));
if nargin<1, folder=fullfile(root,'outputs','ui_all_callbacks_20261031','check_1'); end
assert(~isfolder(folder),'cam:EvidenceExists','检查目录已存在，请另选新目录。'); mkdir(folder);
profile clear; profile on;
project=fixture(); app=CamReplicaApp('off',project,false); cleaner=onCleanup(@()closeOwn(app)); checks={};
% Real graphics framework objects expose private properties to isprop.
% Create them without calculating a route/cam or using a project factory.
for axesHandle=[app.RouteAxes app.CamAxes app.SteeringAxes]
    hold(axesHandle,'on');
    fixtureLine=plot(axesHandle,[0 1],[0 1],'HitTest','off','PickableParts','none');
    hold(axesHandle,'off'); legend(axesHandle,fixtureLine,{'Synthetic fixture'},'AutoUpdate','off');
    axtoolbar(axesHandle,'default');
end
drawnow;
[plan,audit]=cam_app_ui_binding_plan(app);
writelines(jsonencode(audit,PrettyPrint=true),fullfile(folder,'framework_fixture.json'));
assert(isempty(audit.unknown) && numel(plan)==67 && numel(audit.framework)>0);
frameworkCallbacks=frameworkSlots(app,plan);
cam_app_ui_value_snapshot(app); % Must read real ToolbarPushButton/legend.
for k=1:numel(plan), assert(cam_app_ui_callback_matches(plan(k).control.(plan(k).property),app,plan(k).key)); end
source=fileread(fullfile(root,'CamReplicaApp.m'));
persistentAnon=regexp(source,'(?:Fcn|Callback)\s*[''\w]*\s*[,=]\s*@\(','match'); assert(isempty(persistentAnon));
assert(~contains(source,'@(source,~)app.routeMapClick') && ~contains(source,'@(~,~)app.action(actionName)'));
checks{end+1}='67 real main-window slots use named cells; actual axes toolbar/legend public-value snapshot succeeds; persistent registration has no App anonymous callback';

spyFolder=fullfile(folder,'spy'); mkdir(spyFolder); makeSpy(spyFolder); addpath(spyFolder); pathCleaner=onCleanup(@()rmpath(spyFolder));
spy=CamAllCallbackSpy017; event=struct('Key','escape','Indices',[2 1]);
for k=1:numel(plan)
    callback=plan(k).control.(plan(k).property); callback{2}=spy;
    cam_invoke_ui_callback(callback,plan(k).control,event);
    assert(strcmp(spy.Calls{end}.method,cam_app_ui_spec(plan(k).key).method));
end
actions={'import','save','seed','calculate','optimize','stop','simulate','export'};
for k=1:8
    callback=app.Buttons(k).ButtonPushedFcn; callback{2}=spy; cam_invoke_ui_callback(callback,app.Buttons(k),event);
    assert(strcmp(spy.Calls{end}.method,'action') && isequal(spy.Calls{end}.args,{actions{k}}));
end
keys=cam_app_ui_spec();
for k=1:numel(keys)
    spec=keys(k); object=struct('Value','refined','CurrentPoint',[7 8 0;1 2 0]);
    cam_invoke_ui_callback(cam_app_ui_callback(spy,spec.key),object,event);
    args=spy.Calls{end}.args;
    switch spec.mode
        case 'fixed', assert(isequaln(args,spec.fixedArguments));
        case 'event', assert(isequaln(args,[spec.fixedArguments {event}]));
        case 'value', assert(isequaln(args,{'refined'}));
        case 'route-point', assert(isequaln(args,{[7 8],object,'alternate'}));
    end
end
plain=@(s,e)spy.record('plain',s,e); cam_invoke_ui_callback(plain,11,event);
assert(strcmp(spy.Calls{end}.method,'plain') && isequaln(spy.Calls{end}.args,{11,event}));
checks{end+1}='all manifest actions and actual slots dispatch to spy; eight loop actions, booleans, strings, event, Value and distinct source.CurrentPoint are correct; invocation supports handle/cell';

% Safe, non-computing view creation must bind new child controls immediately.
app.openDiagnostics('crossings'); [withDetails,detailAudit]=cam_app_ui_binding_plan(app);
assert(numel(withDetails)==72 && isempty(detailAudit.unknown));
for k=1:numel(withDetails), assert(cam_app_ui_callback_matches(withDetails(k).control.(withDetails(k).property),app,withDetails(k).key)); end
details=app.DiagnosticsFigure; descendants=findall(details);
for object=descendants', if startsWith(object.Tag,'cam-cross-'), object.Tag=''; end, end
[legacyDetails,legacyAudit]=cam_app_ui_binding_plan(app); assert(numel(legacyDetails)==72 && isempty(legacyAudit.unknown));
checks{end+1}='dynamically created cross/score/log detail controls are named; tagless old detail identities resolve by type and scoped parent/text; MATLAB closereq preserved';

% Real callback invocation is restricted to safe selection/layout/reset.
cam_invoke_ui_callback(app.TrainingShortcut.ButtonPushedFcn,app.TrainingShortcut,[]);
assert(app.ControlsTabs.SelectedTab==app.TrainingTab);
cam_invoke_ui_callback(app.TargetsTable.CellSelectionCallback,app.TargetsTable,event); assert(app.SelectedTargetRow==2);
cam_invoke_ui_callback(app.Figure.WindowKeyPressFcn,app.Figure,event);
cam_invoke_ui_callback(app.Figure.SizeChangedFcn,app.Figure,[]);
app.TrainingFields(6).Value=.7; cam_invoke_ui_callback(app.TrainingFields(6).ValueChangedFcn,app.TrainingFields(6),[]);
assert(app.TrainingDirty); cam_invoke_ui_callback(app.TrainingResetButton.ButtonPushedFcn,app.TrainingResetButton,[]); assert(~app.TrainingDirty);
checks{end+1}='safe view, table event, keyboard/layout and reset callbacks execute on real synthetic controls without compute';

app.ParamsTable.Data{1,2}=123.45; app.NodesTable.Data(2,1)=207; app.TargetsTable.Data(2,2)=471;
app.WeightsTable.Data{1,2}=9; app.TrainingFields(6).Value=.7; app.TrainingDirty=true;
app.History=struct('sentinel',NaN); app.Result=struct('sentinel','uncomputed retained result'); app.Status.Text='pending synthetic state';
[emptyPlan,~]=cam_app_ui_binding_plan(app);
for k=1:numel(emptyPlan), emptyPlan(k).control.(emptyPlan(k).property)=[]; end
before=cam_app_ui_value_snapshot(app);
repair=repair_cam_app_callbacks(app,OutputFolder=fullfile(folder,'backups'));
assert(repair.applied && repair.reboundCount==72 && isequaln(before,cam_app_ui_value_snapshot(app)));
for k=1:numel(frameworkCallbacks)
    slot=frameworkCallbacks(k); assert(isequal(slot.oldCallback,slot.control.(slot.property)));
end
backup=load(repair.backupFile); assert(isequaln(backup.backup,before.model) && isequaln(backup.metadata,rmfield(before,'model')));
again=repair_cam_app_callbacks(app,Backup=false); assert(again.alreadyBound && again.reboundCount==0);
for flag={'Busy','SimulationMode','MapEditMode'}
    app.(flag{1})=true; expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackActiveMode'); app.(flag{1})=false;
end
checks{end+1}='empty old slots repair atomically; full model/results/pending main+detail values round-trip and remain equal; repeated repair and active-mode guards work';

original=app.TrainingApplyButton.ButtonPushedFcn;
app.TrainingApplyButton.ButtonPushedFcn=@(~,~)disp('foreign callback must never execute');
before=cam_app_ui_value_snapshot(app); expect(@()repair_cam_app_callbacks(app,OutputFolder=fullfile(folder,'unknown_backups')),'cam:CallbackUnknown');
assert(isequaln(before,cam_app_ui_value_snapshot(app)) && isa(app.TrainingApplyButton.ButtonPushedFcn,'function_handle'));
app.TrainingApplyButton.ButtonPushedFcn=original;
original=app.Figure.CloseRequestFcn; app.Figure.CloseRequestFcn='closereq';
[unsafe,ua]=cam_app_ui_binding_plan(app); closeSlot=strcmp({unsafe.key},'closeRequested');
assert(~unsafe(closeSlot).safe && any(strcmp({ua.unknown.property},'CloseRequestFcn')));
before=cam_app_ui_value_snapshot(app);
expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackUnknown');
assert(isequaln(before,cam_app_ui_value_snapshot(app)) && strcmp(app.Figure.CloseRequestFcn,'closereq'));
app.Figure.CloseRequestFcn=original;
app.Figure.WindowButtonMotionFcn=@(~,~)disp('unknown motion must never execute');
expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackUnknown'); app.Figure.WindowButtonMotionFcn=[];
unknown=uibutton(app.Figure,'Text','Unregistered old control','ButtonPushedFcn',@(~,~)disp('never execute'));
expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackUnknown'); delete(unknown);
line=plot(app.RouteAxes,[0 1],[0 1],'Tag','route-front','ButtonDownFcn',@(~,~)disp('unknown plot'));
expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackUnknown'); delete(line);
checks{end+1}='foreign callback in a known slot (including main closereq), unknown motion/control/plot are reported and refused before any binding changes';

[p,~]=cam_app_ui_binding_plan(app); one=find(strcmp({p.key},'action/import')); two=find(strcmp({p.key},'action/save'));
poison=p([one two]); poison(1).newCallback=cam_app_ui_callback(app,'syncTrainingInputs'); poison(2).newCallback=42;
failed=false; try, cam_app_apply_ui_bindings(poison); catch, failed=true; end
assert(failed && cam_app_ui_callback_matches(app.Buttons(1).ButtonPushedFcn,app,'action/import') ...
    && cam_app_ui_callback_matches(app.Buttons(2).ButtonPushedFcn,app,'action/save'));
checks{end+1}='actual UI setter failure after one assignment rolls back prior callback';

zoom=findall(details,'Type','uibutton','Text','放大选中交点'); assert(isscalar(zoom));
duplicate=uibutton(zoom.Parent,'Text','放大选中交点','ButtonPushedFcn',cam_app_ui_callback(app,'zoomCamCrossing'));
expect(@()repair_cam_app_callbacks(app,Backup=false),'cam:CallbackAmbiguous'); delete(duplicate);
other=uifigure('Visible','off','Name','Foreign App'); otherCleaner=onCleanup(@()delete(other));
foreign=uibutton(other,'Text','Unregistered external','ButtonPushedFcn',@(~,~)disp('never execute')); old=foreign.ButtonPushedFcn;
repair_cam_app_callbacks(app,Backup=false); assert(isequal(old,foreign.ButtonPushedFcn));
app.Figure.WindowButtonMotionFcn=cam_app_ui_callback(app,'routePointerMove'); [motion,ma]=cam_app_ui_binding_plan(app);
assert(isempty(ma.unknown) && nnz(strcmp({motion.key},'routePointerMove'))==1); app.Figure.WindowButtonMotionFcn=[];
checks{end+1}='ambiguous tagless detail identities refuse; unrelated App is untouched; named dynamic motion is covered';

profile off; data=profile('info'); names={data.FunctionTable.CompleteName}; calls=[data.FunctionTable.NumCalls];
forbidden={'evaluate.m','defaultProject.m','teamSolarProject.m','solarTestProject.m','optimize.m'};
counts=struct();
for k=1:numel(forbidden)
    [~,field]=fileparts(forbidden{k}); counts.(field)=sum(calls(contains(names,[filesep '+camdesign' filesep forbidden{k}]))); assert(counts.(field)==0);
end
business={'applyTraining','calculate','runOptimization','rebuildCurrentRoute','restoreModelSwitch'};
for k=1:numel(business), counts.(business{k})=sum(calls(contains(names,['CamReplicaApp.' business{k}]))); assert(counts.(business{k})==0); end
report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks},'profilerCounts',counts, ...
    'mainBindings',audit,'detailsBindings',detailAudit,'legacyDetails',legacyAudit,'repair',repair, ...
    'frameworkCallbacksPreserved',numel(frameworkCallbacks), ...
    'spyDispatchCount',numel(spy.Calls),'sourcePersistentAnonymousMatches',{persistentAnon}, ...
    'scope','Synthetic UI only; all computing/import/export/optimization/force actions dispatched to spy, not real business. User window and old016 evidence untouched. No native mouse-gesture claim.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('UI_ALL_CALLBACKS_PASS checks=%d main=%d details=%d spy=%d allForbiddenCalls=0\n',numel(checks),numel(plan),numel(withDetails),numel(spy.Calls));
end
function slots=frameworkSlots(app,plan)
slots=struct('control',{},'property',{},'oldCallback',{});
for object=findall(app.Figure)'
    names=properties(object); names=names(endsWith(names,'Fcn') | endsWith(names,'Callback'));
    for k=1:numel(names)
        property=names{k}; value=object.(property); if isempty(value), continue; end
        if any(arrayfun(@(p)isequal(p.control,object) && strcmp(p.property,property),plan)), continue; end
        slots(end+1)=struct('control',object,'property',property,'oldCallback',{value}); %#ok<AGROW>
    end
end
end
function expect(callback,wanted)
id=''; try, callback(); catch ex, id=ex.identifier; end; assert(strcmp(id,wanted),'Expected %s, got %s',wanted,id);
end
function makeSpy(folder)
spec=cam_app_ui_spec(); methods=unique({spec.method});
text=sprintf('classdef CamAllCallbackSpy017 < handle\nproperties\nCalls={}\nFigure=struct(''SelectionType'',''alternate'')\nRouteAxes=struct(''CurrentPoint'',[99 98 0;0 0 0])\nend\nmethods\nfunction record(app,method,varargin), app.Calls{end+1}=struct(''method'',method,''args'',{varargin}); end\n');
for k=1:numel(methods), text=[text sprintf('function %s(app,varargin), app.record(''%s'',varargin{:}); end\n',methods{k},methods{k})]; end %#ok<AGROW>
text=[text sprintf('end\nend\n')]; fid=fopen(fullfile(folder,'CamAllCallbackSpy017.m'),'w'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text);
end
function project=fixture()
p=struct('mechanism','flat','wheelDiameter',100,'gearRatio',2,'lever',20,'rollerRadius',2,'referenceDiameter',150,'thickness',5, ...
    'driveX',50,'driveY',-100,'drivenX',-50,'drivenY',-100,'sensorX',0,'sensorY',0,'headingDeg',90,'startSteeringDeg',0, ...
    'samples',101,'camSamples',181,'autoRatio',false,'returnAngleDeg',60,'maxSteeringDeg',65,'maxPressureDeg',35,'hitTolerance',30, ...
    'iterations',1,'stepMM',1,'gradientProbeMM',.5,'bounds',[0 1000 0 1000],'weights',[12 1 2 3 10 10]);
project=struct('schema','cam-replica-1','name','UI-only synthetic','params',p,'targets',[200 200;200 450;200 700], ...
    'nodes',[200 200;200 450;200 700],'provenance','Handwritten synthetic UI input; never evaluated.');
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
