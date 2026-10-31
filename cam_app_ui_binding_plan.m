function [plan,audit]=cam_app_ui_binding_plan(app)
% Identity-based plan, never evaluates/parses an old callback expression.
roots=app.Figure;
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), roots(end+1)=app.DiagnosticsFigure; end
plan=struct('control',{},'property',{},'key',{},'oldCallback',{},'newCallback',{},'identity',{},'safe',{},'reason',{});
add(app.Figure,'CloseRequestFcn','closeRequested','Figure',app.Figure);
add(app.Figure,'SizeChangedFcn','resizeLayout','Figure',app.Figure);
add(app.Figure,'WindowKeyPressFcn','routeEditorKey','Figure',app.Figure);
if ~isempty(app.Figure.WindowButtonMotionFcn) && knownMotion(app.Figure.WindowButtonMotionFcn,app)
    add(app.Figure,'WindowButtonMotionFcn','routePointerMove','Figure motion',app.Figure);
end
actions={'import','save','seed','calculate','optimize','stop','simulate','export'};
labels={'导入 MAT','保存项目','重建路线','计算凸轮','迭代优化','停止','固定凸轮反推','导出候选'};
assert(numel(app.Buttons)==8,'cam:CallbackIdentity','主按钮数量不匹配。');
for k=1:8
    assert(strcmp(app.Buttons(k).Text,labels{k}),'cam:CallbackIdentity','主按钮顺序/身份不匹配：%d',k);
    add(app.Buttons(k),'ButtonPushedFcn',['action/' actions{k}],['Buttons(' num2str(k) ')'],app.Figure);
end
main={ ...
 'TrainingModel','ValueChangedFcn','routeModelChanged';
 'AlgorithmSelector','ValueChangedFcn','algorithmChanged';
 'Mechanism','ValueChangedFcn','invalidate';
 'TrainingShortcut','ButtonPushedFcn','openTraining';
 'ContestGeometryShortcut','ButtonPushedFcn','openContestGeometry';
 'ParamsTable','CellEditCallback','invalidate';
 'TargetsTable','CellEditCallback','invalidate';
 'TargetsTable','CellSelectionCallback','target-select';
 'NodesTable','CellEditCallback','invalidate';
 'NodesTable','CellSelectionCallback','node-select';
 'RefineRouteButton','ButtonPushedFcn','refineRoute';
 'DynamicWeightsEnabled','ValueChangedFcn','dynamicWeightsChanged';
 'WeightsTable','CellEditCallback','invalidate';
 'TrainingApplyButton','ButtonPushedFcn','applyTraining';
 'TrainingResetButton','ButtonPushedFcn','syncTrainingInputs';
 'ForceModelSwitchButton','ButtonPushedFcn','force-model-switch';
 'RestoreModelSwitchButton','ButtonPushedFcn','restoreModelSwitch';
 'MapEditButton','ButtonPushedFcn','beginRouteEditing';
 'ConfirmNodeButton','ButtonPushedFcn','confirmRouteNode';
 'CancelNodeButton','ButtonPushedFcn','cancelRouteEditing';
 'RouteAxes','ButtonDownFcn','route-click';
 'ScoreBasis','ValueChangedFcn','updateDiagnostics';
 'ScoreDetailsButton','ButtonPushedFcn','details-score';
 'LogDetailsButton','ButtonPushedFcn','details-log';
 'ActualClosureButton','ButtonPushedFcn','checkActualClosure';
 'ContestGeometryParams','CellEditCallback','contestGeometryChanged';
 'ContestGeometryMeasured','ValueChangedFcn','contestGeometryChanged';
 'ContestGeometryCoverageConfirmed','ValueChangedFcn','contestGeometryChanged';
 'ContestGeometryCheckButton','ButtonPushedFcn','checkContestGeometry';
 'ContestGeometryBodyButton','ButtonPushedFcn','contest-body';
 'ContestGeometryTargetButton','ButtonPushedFcn','contest-target';
 'ContestGeometryTargetTable','CellSelectionCallback','selectContestGeometryTarget';
 'CrossSource','ValueChangedFcn','changeCamSource';
 'CrossTable','CellSelectionCallback','selectCamCrossing';
 'CrossZoomButton','ButtonPushedFcn','zoomCamCrossing';
 'CrossResetButton','ButtonPushedFcn','resetCamView';
 'CrossDetailsButton','ButtonPushedFcn','details-crossings'};
for k=1:size(main,1), add(app.(main{k,1}),main{k,2},main{k,3},main{k,1},app.Figure); end
pointKeys={'target-insert','target-delete','node-insert','node-delete'};
for k=1:4, add(app.PointButtons(k),'ButtonPushedFcn',pointKeys{k},['PointButtons(' num2str(k) ')'],app.Figure); end
arrays={'DynamicWeightFields','ValueChangedFcn','dynamicWeightsChanged'; ...
    'TrainingFields','ValueChangedFcn','markTrainingDirty';'AutoTuneFields','ValueChangedFcn','invalidate'};
for k=1:size(arrays,1)
    controls=app.(arrays{k,1});
    for n=1:numel(controls), add(controls(n),arrays{k,2},arrays{k,3},sprintf('%s(%d)',arrays{k,1},n),app.Figure); end
end
execution=findall(app.Figure,'Type','uimenu','Tag','cam-execution-menu');
assert(numel(execution)<=1,'cam:CallbackAmbiguous','执行方式菜单不唯一。');
if ~isempty(execution)
    assert(isequal(execution.Parent,app.Figure),'cam:CallbackOwnership','执行方式菜单不属于主窗口。');
    keys={'execution-background','execution-foreground','execution-force-cancel'};
    for k=1:numel(keys)
        menu=findall(execution,'Type','uimenu','Tag',['cam-' keys{k}]);
        assert(isscalar(menu) && isequal(menu.Parent,execution),'cam:CallbackAmbiguous','执行方式子菜单身份不唯一或父级不匹配。');
        add(menu,'MenuSelectedFcn',keys{k},['cam-' keys{k}],app.Figure);
    end
end
if numel(roots)>1
    detail=roots(2);
    assert(strcmp(detail.Tag,'cam-app-details') || strcmp(detail.Name,'结果详情 · 评分、日志与交点'), ...
        'cam:CallbackOwnership','详情窗口身份无法确认。');
    definitions={ ...
      'cam-cross-source','matlab.ui.control.DropDown','', 'ValueChangedFcn','changeCamSource';
      'cam-cross-table','matlab.ui.control.Table','', 'CellSelectionCallback','selectCamCrossing';
      'cam-cross-zoom','matlab.ui.control.Button','放大选中交点','ButtonPushedFcn','zoomCamCrossing';
      'cam-cross-reset','matlab.ui.control.Button','返回全凸轮','ButtonPushedFcn','resetCamView';
      'cam-cross-details','matlab.ui.control.Button','交点大窗','ButtonPushedFcn','details-crossings'};
    children=findall(detail);
    for k=1:size(definitions,1)
        matches=gobjects(0);
        for n=1:numel(children)
            control=children(n); if ~isa(control,definitions{k,2}), continue; end
            tab=ancestor(control,'uitab');
            if isempty(tab) || ~strcmp(tab.Title,'交点与对应轮廓'), continue; end
            identity=strcmp(control.Tag,definitions{k,1});
            if ~identity && isempty(control.Tag)
                if isa(control,'matlab.ui.control.Button'), identity=strcmp(control.Text,definitions{k,3});
                elseif isa(control,'matlab.ui.control.DropDown'), identity=isequal(control.ItemsData,{'current','refined'});
                else, identity=isequal(control.ColumnName(:)',{'交点','段 A','段 B','X / mm','Y / mm'}); end
            end
            if identity, matches(end+1)=control; end %#ok<AGROW>
        end
        assert(numel(matches)==1,'cam:CallbackAmbiguous','详情控件%s匹配到%d个，未修改任何回调。',definitions{k,1},numel(matches));
        add(matches,definitions{k,4},definitions{k,5},definitions{k,1},detail);
    end
end
% Current plot objects are passive (no App callback); only RouteAxes has the
% route click action. A nonempty unknown plot callback is refused below.
inventory=struct('class',{},'tag',{},'property',{},'classification',{},'identity',{},'callback',{});
unknown=inventory; framework=inventory;
for figure=roots
    for object=findall(figure)'
        names=properties(object); names=names(endsWith(names,'Fcn') | endsWith(names,'Callback'));
        for n=1:numel(names)
            property=names{n}; callback=object.(property); if isempty(callback), continue; end
            matched=find(arrayfun(@(p)isequal(p.control,object) && strcmp(p.property,property),plan));
            item=struct('class',class(object),'tag',object.Tag,'property',property,'classification','', ...
                'identity','','callback',callbackText(callback));
            if numel(matched)==1 && plan(matched).safe
                item.classification='app'; item.identity=plan(matched).identity;
            elseif isempty(matched) && isFramework(object,property,callback)
                item.classification='matlab-framework'; framework(end+1)=item; %#ok<AGROW>
            else
                item.classification='unknown';
                if numel(matched)==1, item.identity=[plan(matched).identity ': ' plan(matched).reason]; end
                unknown(end+1)=item; %#ok<AGROW>
            end
            inventory(end+1)=item; %#ok<AGROW>
        end
    end
end
audit=struct('inventory',inventory,'unknown',unknown,'framework',framework,'plannedBindings',numel(plan), ...
    'ownedFigureCount',numel(roots),'scope','Only app.Figure and confirmed app.DiagnosticsFigure descendants; no global graphics search.');
    function add(control,property,key,identity,root)
        assert(isscalar(control) && isgraphics(control) && isprop(control,property),'cam:CallbackIdentity','控件或回调属性无效：%s',identity);
        assert(isequal(control,root) || isequal(ancestor(control,'figure'),root),'cam:CallbackOwnership','控件不属于本App：%s',identity);
        for index=1:numel(plan)
            assert(~(isequal(control,plan(index).control) && strcmp(property,plan(index).property)), ...
                'cam:CallbackAmbiguous','同一回调属性存在多个绑定：%s',identity);
        end
        [safe,reason]=cam_app_ui_legacy_compatible(control.(property),app,key);
        plan(end+1)=struct('control',control,'property',property,'key',key, ...
            'oldCallback',{control.(property)},'newCallback',{cam_app_ui_callback(app,key)},'identity',identity,'safe',safe,'reason',reason);
    end
end
function yes=isFramework(object,property,callback)
yes=false; text=callbackText(callback);
if isa(object,'matlab.ui.Figure') && strcmp(property,'CloseRequestFcn') && strcmp(text,'closereq')
    yes=true; return; % Existing MATLAB default detail-window close.
end
try
    if iscell(callback), fn=callback{1}; else, fn=callback; end
    if ~isa(fn,'function_handle'), return; end
    info=functions(fn); if isempty(info.file) || ~startsWith(lower(info.file),lower([matlabroot filesep])), return; end
    if isa(object,'matlab.ui.container.ContextMenu')
        yes=strcmp(object.Tag,'defaultlegendcontextmenu') && strcmp(property,'ContextMenuOpeningFcn') && strcmp(text,'defaultContextMenuCB');
    elseif isa(object,'matlab.graphics.illustration.Legend')
        yes=(strcmp(property,'ItemHitFcn') && strcmp(text,'defaultItemHitCallback')) ...
            || (strcmp(property,'ButtonDownFcn') && strcmp(text,'bdowncb'));
    elseif ismember(class(object),{'matlab.ui.controls.ToolbarPushButton','matlab.ui.controls.ToolbarStateButton'})
        tags={'overflow','brush','datacursor','rotate','pan','zoomin','zoomout','restoreview','saveas','copyimage','copyvector'};
        yes=ismember(object.Tag,tags) && (contains(text,'matlab.graphics.') || contains(text,'obj.overflowCallback'));
    end
catch
    yes=false; % Unreadable/unrecognized callbacks must be reported.
end
end
function yes=knownMotion(callback,app)
[yes,~]=cam_app_ui_legacy_compatible(callback,app,'routePointerMove');
end
function text=callbackText(callback)
text='<unreadable>';
try
    if iscell(callback) && ~isempty(callback), callback=callback{1}; end
    if isa(callback,'function_handle'), text=func2str(callback);
    elseif ischar(callback) || isstring(callback), text=char(callback); end
catch
end
end
