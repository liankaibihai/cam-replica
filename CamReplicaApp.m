classdef CamReplicaApp < handle
    % Readable programmatic MATLAB app; no App Designer binary dependency.
    properties
        Figure
        Project
        Result
        History = []
        RouteAxes
        SteeringAxes
        CamAxes
        ParamsTable
        TargetsTable
        NodesTable
        WeightsTable
        WeightsTab
        DynamicWeightsEnabled
        DynamicWeightFields
        DynamicWeightInfo
        DynamicWeightSource
        ScoreBasis
        ScoreViewStatus
        Mechanism
        AutoRatio
        RatioNotice
        Log
        Buttons
        Status
        DirectionStatus
        StopRequested = false
        Busy = false
        CloseAfterStop = false
        SelectedTargetRow = 1
        SelectedNodeRow = 1
        PointButtons
        RefineRouteButton
        NodeInfo
        TrainingFields
        TrainingModel
        TrainingApplyButton
        TrainingResetButton
        TrainingInfo
        TrainingDirty = false
        TrainingFieldNames = {'iterations','controlPointCount','interpolationPerSegment','bezierDegree', ...
            'gradientForce','learningRate','smoothingRate','adjustInterval','adjustExponent'}
        SimulationMode = false
        SimulationReference = []
        SimulationResult = []
        MapEditMode = false
        MapEditSelection = 0
        MapEditButton
        ConfirmNodeButton
        CancelNodeButton
        MapEditHelp
        AlgorithmSelector
        OptimizationInfo = []
        OptimizationDirection = []
        RootLayout
        ControlsTabs
        TrainingTab
        TrainingShortcut
        MethodSummary
        ResultsTabs
        ScoreSummary
        LengthSummary
        ScoreTable
        ScoreTrendAxes
        ObjectiveTrendAxes
        CrossTable
        CrossSource
        CamSourceLabel
        CrossZoomButton
        CrossResetButton
        CrossDetailsButton
        CamInspectionRecord = []
        ScoreDisplayData = []
        HistoryProject = []
        DiagnosticsFigure = []
        FullLog = {}
        TrainingRuntime
        ScoreDetailsButton
        LogDetailsButton
    end
    properties (Access=private)
        MapEditReference = []
        MapEditNodes = []
        NodeLine = []
        SelectedNodeMarker = []
        NodeMoveGuide = []
        RouteLines = []
        ScoreViews = {}
        CrossingViews = {}
        DetailTabs = []
        DetailLog = []
        DetailCamAxes = []
        LastDisplayProject = []
        LastDisplayResult = []
        CamBaseProject = []
        CamBaseResult = []
        CamFullLimits = []
        SelectedCrossing = 0
        ScoreTab
        LogTab
        CrossingTab
        LegacyRatioNotice = ''
        DisplayedParameterFields = {}
        ParameterFields = {'wheelDiameter','gearRatio','lever','rollerRadius','referenceDiameter', ...
            'thickness','driveX','driveY','drivenX','drivenY','sensorX','sensorY','headingDeg', ...
            'startSteeringDeg','returnAngleDeg','maxSteeringDeg','maxPressureDeg','hitTolerance', ...
            'iterations','stepMM','gradientProbeMM','samples','camSamples'}
        ParameterLabels = {'主动轮直径 / mm','传动比（用户设定，轮/凸轮）','转向偏距 c / mm', ...
            '推杆接触半径 r / mm','零位中心距 ×2 / mm','凸轮厚度（仅记录）/ mm', ...
            '主动轮局部 X / mm','主动轮局部 Y / mm','从动轮局部 X / mm','从动轮局部 Y / mm', ...
            '传感器局部 X / mm','传感器局部 Y / mm','发车车身方向 / deg','初始前轮转角 / deg', ...
            '回程保留角 / deg','转角上限 / deg','压力角上限 / deg','打卡几何容差 / mm', ...
            '优化迭代次数','初始优化步幅 / mm','梯度差分步长 / mm','路线采样数','凸轮采样数'}
    end
    methods
        function app=CamReplicaApp(visibility)
            if nargin<1, visibility='on'; end
            app.Project=camdesign.defaultProject();
            app.Figure=uifigure('Name','工创赛凸轮设计 · MATLAB 复现 v0.2', ...
                'Position',[70 60 1320 860],'Visible',visibility,'Color',[.95 .96 .98],'AutoResizeChildren','off');
            app.Figure.CloseRequestFcn=@(~,~)app.closeRequested();
            app.Figure.WindowKeyPressFcn=@(~,event)app.routeEditorKey(event);
            root=uigridlayout(app.Figure,[5 2],'RowHeight',{34,36,52,'1x',262}, ...
                'ColumnWidth',{320,'1x'},'Padding',[12 8 12 8], ...
                'RowSpacing',6,'ColumnSpacing',10);
            app.RootLayout=root;
            titleBar=uigridlayout(root,[1 1],'Padding',[0 0 0 0]);
            titleBar.Layout.Row=1; titleBar.Layout.Column=[1 2];
            uilabel(titleBar,'Text','工创赛凸轮设计  /  路线、机构与几何校验', ...
                'FontSize',20,'FontWeight','bold','FontColor',[.12 .20 .30]);
            bar=uigridlayout(root,[1 8],'Padding',[0 0 0 0],'ColumnSpacing',8);
            bar.Layout.Row=2; bar.Layout.Column=[1 2];
            labels={'导入 MAT','保存项目','重建路线','计算凸轮','迭代优化','停止','固定凸轮反推','导出候选'};
            actions={'import','save','seed','calculate','optimize','stop','simulate','export'};
            app.Buttons=gobjects(1,8);
            for k=1:8
                actionName=actions{k};
                app.Buttons(k)=uibutton(bar,'Text',labels{k},'FontSize',13, ...
                    'ButtonPushedFcn',@(~,~)app.action(actionName));
            end
            app.Buttons(4).BackgroundColor=[.18 .40 .66]; app.Buttons(4).FontColor=[1 1 1];
            app.Buttons(5).BackgroundColor=[.14 .48 .39]; app.Buttons(5).FontColor=[1 1 1];
            app.Buttons(6).Enable='off';
            methods=uigridlayout(root,[2 4],'ColumnWidth',{72,'1x',78,'1x'},'RowHeight',{28,20}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',6,'RowSpacing',2);
            methods.Layout.Row=3; methods.Layout.Column=[1 2];
            uilabel(methods,'Text','路线画法','FontWeight','bold');
            app.TrainingModel=uidropdown(methods,'Items',{'三次样条（通过节点）','贝塞尔曲线（控制点调形）'}, ...
                'ItemsData',{'cubic','bezier-blend-independent-v1'},'ValueChangedFcn',@(~,~)app.markTrainingDirty(), ...
                'Tooltip','路线画法决定控制点怎样变成曲线。三次样条穿过节点；独立贝塞尔通常不穿控制点，是本版实验融合。');
            app.TrainingModel.Layout.Row=1; app.TrainingModel.Layout.Column=2;
            label=uilabel(methods,'Text','优化方法','FontWeight','bold'); label.Layout.Row=1; label.Layout.Column=3;
            app.AlgorithmSelector=uidropdown(methods, ...
                'Items',{'梯度搜索（峰值评分）','四方向试探（加权）','约束优化（内点法）'}, ...
                'ItemsData',{'peak-gradient-v2','video-four-direction-v1','fmincon-interior-point-experimental-v1'}, ...
                'Value','peak-gradient-v2','ValueChangedFcn',@(~,~)app.refreshTrainingControls(), ...
                'Tooltip','优化方法只决定怎样移动控制点，不决定路线画法。前两种按评分搜索；内点法使用独立目标和约束。');
            app.AlgorithmSelector.Layout.Row=1; app.AlgorithmSelector.Layout.Column=4;
            app.MethodSummary=uilabel(methods,'Text','','FontSize',11);
            app.MethodSummary.Layout.Row=2; app.MethodSummary.Layout.Column=[1 3];
            app.DirectionStatus=uilabel(methods,'Text','AI方向：无有效数据','FontSize',10,'FontColor',[.4 .4 .4]);
            app.DirectionStatus.Layout.Row=2; app.DirectionStatus.Layout.Column=4;
            side=uigridlayout(root,[4 1],'RowHeight',{28,26,30,'1x'},'Padding',[0 0 0 0],'RowSpacing',4);
            side.Layout.Row=4; side.Layout.Column=1;
            app.Mechanism=uidropdown(side,'Items',{'齿条：h = cδ','平推：h = c tanδ'}, ...
                'ItemsData',{'rack','flat'},'Value','rack','ValueChangedFcn',@(~,~)app.invalidate());
            ratioRow=uigridlayout(side,[1 1],'Padding',[0 0 0 0]);
            app.AutoRatio=uicheckbox(ratioRow,'Text','','Value',false,'Enable','off','Visible','off', ...
                'Tooltip','只由用户在车体参数手动改变gearRatio。旧文件autoRatio=true也不会自动增比。');
            app.RatioNotice=uilabel(ratioRow,'Text','传动比：固定使用用户输入','FontSize',11);
            app.AutoRatio.Layout.Row=1; app.AutoRatio.Layout.Column=1;
            app.RatioNotice.Layout.Row=1; app.RatioNotice.Layout.Column=1; ratioRow.RowHeight={'1x'};
            app.TrainingShortcut=uibutton(side,'Text','打开训练设置（九项）','FontWeight','bold', ...
                'ButtonPushedFcn',@(~,~)app.openTraining());
            tabs=uitabgroup(side);
            app.ControlsTabs=tabs;
            t=uitab(tabs,'Title','车体'); g=uigridlayout(t,[1 1],'Padding',[0 0 0 0]);
            app.ParamsTable=uitable(g,'ColumnName',{'参数','数值'},'ColumnEditable',[false true], ...
                'ColumnWidth',{185,65},'ColumnFormat',{'char','numeric'},'RowName',{},'FontSize',11,'CellEditCallback',@(~,~)app.invalidate());
            app.PointButtons=gobjects(1,4);
            t=uitab(tabs,'Title','目标'); g=uigridlayout(t,[2 1],'RowHeight',{30,'1x'},'Padding',[0 0 0 0]);
            controls=uigridlayout(g,[1 2],'Padding',[0 0 0 0]);
            app.PointButtons(1)=uibutton(controls,'Text','选中行后插入','ButtonPushedFcn',@(~,~)app.modifyPoints('target',1));
            app.PointButtons(2)=uibutton(controls,'Text','删除选中行','ButtonPushedFcn',@(~,~)app.modifyPoints('target',-1));
            app.TargetsTable=uitable(g,'ColumnName',{'X / mm','Y / mm'},'ColumnEditable',[true true], ...
                'ColumnWidth',{120,120},'CellEditCallback',@(~,~)app.invalidate(), ...
                'CellSelectionCallback',@(~,event)app.selectPoint('target',event));
            t=uitab(tabs,'Title','节点'); g=uigridlayout(t,[3 1],'RowHeight',{30,44,'1x'},'Padding',[0 0 0 0]);
            controls=uigridlayout(g,[1 3],'Padding',[0 0 0 0],'ColumnSpacing',4);
            app.PointButtons(3)=uibutton(controls,'Text','段中插点','FontSize',11,'ButtonPushedFcn',@(~,~)app.modifyPoints('node',1));
            app.PointButtons(4)=uibutton(controls,'Text','删除节点','FontSize',11,'ButtonPushedFcn',@(~,~)app.modifyPoints('node',-1));
            app.RefineRouteButton=uibutton(controls,'Text','全段细化','FontSize',11,'ButtonPushedFcn',@(~,~)app.refineRoute());
            app.NodeInfo=uilabel(g,'Text','','FontSize',11,'WordWrap','on');
            app.NodesTable=uitable(g,'ColumnName',{'前轮 X / mm','前轮 Y / mm'},'ColumnEditable',[true true], ...
                'ColumnWidth',{105,105},'CellEditCallback',@(~,~)app.invalidate(), ...
                'CellSelectionCallback',@(~,event)app.selectPoint('node',event));
            t=uitab(tabs,'Title','权重'); app.WeightsTab=t;
            g=uigridlayout(t,[3 1],'RowHeight',{104,156,58},'Padding',[0 0 0 0],'RowSpacing',3,'Scrollable','on');
            settings=uigridlayout(g,[4 4],'RowHeight',{26,16,26,26},'ColumnWidth',{'1x',48,'1x',48}, ...
                'Padding',[2 0 2 0],'ColumnSpacing',3,'RowSpacing',2);
            app.DynamicWeightsEnabled=uicheckbox(settings,'Text','按违规自动调权重','Value',false, ...
                'ValueChangedFcn',@(~,~)app.dynamicWeightsChanged(), ...
                'Tooltip','基础权重不变；在轮次边界根据物理违规调整搜索权重。只支持梯度搜索和四方向试探。');
            app.DynamicWeightsEnabled.Layout.Row=1; app.DynamicWeightsEnabled.Layout.Column=[1 4];
            app.DynamicWeightSource=uilabel(settings,'Text','实际权重未记录','FontSize',10);
            app.DynamicWeightSource.Layout.Row=2; app.DynamicWeightSource.Layout.Column=[1 4];
            names={'更新间隔','调节增益','倍率上限','响应率'};
            tips={'每隔多少轮更新一次实际权重，正整数。','违规对权重倍率的影响强度。', ...
                '实际权重相对基础权重的倍率上限。','实际倍率向目标倍率靠近的比例。'};
            app.DynamicWeightFields=gobjects(1,4);
            for k=1:4
                row=3+floor((k-1)/2); column=1+2*mod(k-1,2);
                label=uilabel(settings,'Text',names{k},'FontSize',10,'Tooltip',tips{k});
                label.Layout.Row=row; label.Layout.Column=column;
                app.DynamicWeightFields(k)=uieditfield(settings,'numeric','Value',1,'FontSize',10, ...
                    'Tooltip',tips{k},'ValueChangedFcn',@(~,~)app.dynamicWeightsChanged());
                app.DynamicWeightFields(k).Layout.Row=row; app.DynamicWeightFields(k).Layout.Column=column+1;
            end
            app.WeightsTable=uitable(g,'ColumnName',{'评分项','基础','实际'},'ColumnEditable',[false true false], ...
                'ColumnWidth',{130,60,60},'ColumnFormat',{'char','numeric','char'},'RowName',{},'FontSize',11, ...
                'CellEditCallback',@(~,~)app.invalidate());
            app.DynamicWeightInfo=uilabel(g,'Text','','FontSize',10,'WordWrap','on','VerticalAlignment','top');
            t=uitab(tabs,'Title','训练'); app.TrainingTab=t;
            trainingRoot=uigridlayout(t,[3 1],'RowHeight',{64,'1x',32},'Padding',[0 0 0 0],'RowSpacing',3);
            app.TrainingRuntime=uilabel(trainingRoot,'Text','本轮有效参数：尚无训练记录','FontSize',10,'WordWrap','on','VerticalAlignment','top');
            training=uigridlayout(trainingRoot,[10 2],'RowHeight',[repmat({24},1,9),{92}], ...
                'ColumnWidth',{168,'1x'},'Padding',[4 2 4 2],'ColumnSpacing',2,'RowSpacing',2,'Scrollable','on');
            training.Layout.Row=2;
            labels={'训练次数','控制点数量','插值数量（名义/段）','贝塞尔阶数','梯度力 /mm（本版）', ...
                '学习率（本版）','平滑率（本版）','调节间隔 /轮','调节指数（本版）'};
            tips={'请求迭代次数，连接 iterations。','真实节点/控制点数；减点和贝塞尔重建可能改变曲线。', ...
                '名义密度；全局samples=(N-1)×m+1，具体区间采样数随参数长度变化；加密验收尊重新samples。', ...
                '仅独立贝塞尔模式生效，3至min(49,N-1)。', ...
                '本版差分距离；搜索直接用±X/Y mm。内点默认名义步长限0.001～1 mm（6→1、0.0005→0.001），再按1000mm归一化及TypicalX规则缩放；非原版力权重。', ...
                '搜索步幅倍率；不适用于内点法。','邻点平均平滑候选率，仅接受目标改善的候选。', ...
                '每J轮更新阶梯衰减。','衰减=(1+floor((k-1)/J))^(-指数)。'};
            app.TrainingFields=gobjects(1,9);
            for k=1:9
                label=uilabel(training,'Text',labels{k},'FontSize',11,'Tooltip',tips{k});
                label.Layout.Row=k; label.Layout.Column=1;
                app.TrainingFields(k)=uieditfield(training,'numeric','Value',1,'FontSize',11, ...
                    'Tooltip',tips{k},'ValueChangedFcn',@(~,~)app.markTrainingDirty());
                app.TrainingFields(k).Layout.Row=k; app.TrainingFields(k).Layout.Column=2;
            end
            app.TrainingInfo=uilabel(training,'Text','','FontSize',11,'WordWrap','on','VerticalAlignment','top');
            app.TrainingInfo.Layout.Row=10; app.TrainingInfo.Layout.Column=[1 2];
            trainingActions=uigridlayout(trainingRoot,[1 2],'ColumnWidth',{'1x',70},'Padding',[2 0 2 0]);
            trainingActions.Layout.Row=3;
            app.TrainingApplyButton=uibutton(trainingActions,'Text','应用训练设置','FontSize',11,'ButtonPushedFcn',@(~,~)app.applyTraining());
            app.TrainingResetButton=uibutton(trainingActions,'Text','还原','FontSize',11,'ButtonPushedFcn',@(~,~)app.syncTrainingInputs());
            charts=uigridlayout(root,[2 2],'ColumnWidth',{'1.35x','1x'},'RowHeight',{'1x','2.7x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',12,'RowSpacing',10);
            charts.Layout.Row=4; charts.Layout.Column=2;
            routePanel=uigridlayout(charts,[2 1],'RowHeight',{32,'1x'},'Padding',[0 0 0 0]);
            routePanel.Layout.Row=2; routePanel.Layout.Column=1;
            editorBar=uigridlayout(routePanel,[1 4],'ColumnWidth',{76,76,80,'1x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',5);
            app.MapEditButton=uibutton(editorBar,'Text','地图编辑','ButtonPushedFcn',@(~,~)app.beginRouteEditing());
            app.ConfirmNodeButton=uibutton(editorBar,'Text','确认落点','Enable','off','ButtonPushedFcn',@(~,~)app.confirmRouteNode());
            app.CancelNodeButton=uibutton(editorBar,'Text','取消 / Esc','Enable','off','ButtonPushedFcn',@(~,~)app.cancelRouteEditing());
            app.MapEditHelp=uilabel(editorBar,'Text','独立三次样条路线节点','FontSize',11);
            app.RouteAxes=uiaxes(routePanel);
            app.RouteAxes.ButtonDownFcn=@(source,~)app.routeMapClick(source.CurrentPoint(1,1:2),source,app.Figure.SelectionType);
            app.SteeringAxes=uiaxes(charts); app.SteeringAxes.Layout.Row=1; app.SteeringAxes.Layout.Column=1;
            app.CamAxes=uiaxes(charts); app.CamAxes.Layout.Row=[1 2]; app.CamAxes.Layout.Column=2;
            bottom=uigridlayout(root,[3 1],'RowHeight',{38,28,'1x'},'Padding',[0 0 0 0],'RowSpacing',3);
            bottom.Layout.Row=5; bottom.Layout.Column=[1 2];
            statusRow=uigridlayout(bottom,[1 5],'ColumnWidth',{'1x',220,165,90,90},'Padding',[0 0 0 0],'ColumnSpacing',5);
            app.Status=uilabel(statusRow,'Text','准备就绪','FontSize',11,'FontWeight','bold','WordWrap','on');
            app.ScoreSummary=uilabel(statusRow,'Text','通用评分：待计算','FontSize',11,'FontWeight','bold','WordWrap','on');
            scoreChoice=uigridlayout(statusRow,[2 1],'RowHeight',{22,16},'Padding',[0 0 0 0],'RowSpacing',0);
            app.ScoreBasis=uidropdown(scoreChoice,'Items',{'自动显示实际','固定参照评分','本轮动态评分'},'ItemsData',{'auto','reference','dynamic'}, ...
                'Value','auto','ValueChangedFcn',@(~,~)app.updateDiagnostics(), ...
                'Tooltip','自动模式优先显示匹配记录的实际权重；手动选择会保留。固定参照趋势不变。');
            app.ScoreViewStatus=uilabel(scoreChoice,'Text','固定参照 / 待记录','FontSize',10);
            app.ScoreDetailsButton=uibutton(statusRow,'Text','评分详情','ButtonPushedFcn',@(~,~)app.openDiagnostics('score'));
            app.LogDetailsButton=uibutton(statusRow,'Text','日志大窗','ButtonPushedFcn',@(~,~)app.openDiagnostics('log'));
            app.LengthSummary=uilabel(bottom,'Text','总路程（前轮轨迹）：待计算    主动轮行程：待计算', ...
                'FontSize',12,'FontWeight','bold','FontColor',[.12 .25 .38],'BackgroundColor',[.9 .94 .98], ...
                'WordWrap','on','Tooltip','真实长度取自当前显示结果的 routeLength / driveLength，单位 mm；m=mm/1000。不是评分表中归一化的路线长度项。');
            app.ResultsTabs=uitabgroup(bottom);
            app.ScoreTab=uitab(app.ResultsTabs,'Title','评分与趋势'); view=app.createScoreView(app.ScoreTab);
            app.ScoreViews={view}; app.ScoreTable=view.table; app.ScoreTrendAxes=view.scoreAxes; app.ObjectiveTrendAxes=view.objectiveAxes;
            app.LogTab=uitab(app.ResultsTabs,'Title','日志'); logLayout=uigridlayout(app.LogTab,[1 1],'Padding',[0 0 0 0]);
            app.Log=uitextarea(logLayout,'Editable','off','FontSize',11);
            app.CrossingTab=uitab(app.ResultsTabs,'Title','交点定位'); crossing=app.createCrossingView(app.CrossingTab,false);
            app.CrossingViews={crossing}; app.CrossTable=crossing.table; app.CrossSource=crossing.source; app.CamSourceLabel=crossing.label;
            app.CrossZoomButton=crossing.zoom; app.CrossResetButton=crossing.reset; app.CrossDetailsButton=crossing.details;
            app.syncInputs(); app.calculate();
            app.message('v0.2：齿条/平推、固定凸轮调参；独立样条与数值优化。尚未完成原版点集或实车对照。');
            app.Figure.SizeChangedFcn=@(~,~)app.resizeLayout(); app.resizeLayout();
        end
        function syncInputs(app)
            p=app.Project.params;
            indices=1:numel(app.ParameterFields);
            if app.SimulationMode, indices=[1 2 3 5 7 8 10 11 12 13]; end
            app.DisplayedParameterFields=app.ParameterFields(indices);
            labels=app.ParameterLabels(indices);
            if app.SimulationMode, labels{2}='传动比（用户试调，轮/凸轮）'; end
            values=cellfun(@(k)p.(k),app.DisplayedParameterFields,'UniformOutput',false);
            app.ParamsTable.Data=[labels(:),values(:)];
            app.TargetsTable.Data=app.Project.targets; app.NodesTable.Data=app.Project.nodes;
            app.updateNodeInfo();
            app.Mechanism.Value=p.mechanism; app.AutoRatio.Value=false;
            app.RatioNotice.Text=sprintf('传动比：固定使用用户输入 %.6g（车体页可改）',p.gearRatio);
            if p.autoRatio
                notice=sprintf('旧项目%s记录了自动增比；本次固定执行用户传动比 %.6g，原数值未改。',app.Project.name,p.gearRatio);
                if ~strcmp(app.LegacyRatioNotice,notice), app.LegacyRatioNotice=notice; app.message(notice); end
            end
            labels={'有序打卡偏差','前轮路线长度','转向变化率','压力角超限','前轮转角超限','包络欠切风险'};
            app.WeightsTable.Data=[labels(:),num2cell(p.weights(:)),repmat({'未记录'},6,1)];
            settings=camdesign.dynamicWeightSettings(p); app.DynamicWeightsEnabled.Value=settings.enabled;
            names={'interval','gain','maxMultiplier','response'};
            for k=1:4, app.DynamicWeightFields(k).Value=settings.(names{k}); end
            app.syncTrainingInputs();
        end
        function readInputs(app)
            assert(~app.MapEditMode,'cam:MapEditActive','请先确认或取消地图编辑。');
            app.Project=app.inputProject();
        end
        function candidate=inputProject(app,allowPendingTraining)
            if nargin<2, allowPendingTraining=false; end
            assert(~app.TrainingDirty || allowPendingTraining,'cam:TrainingPending','请先应用或还原训练设置，当前图像仍是上次结果。');
            p=app.Project.params;
            for k=1:numel(app.DisplayedParameterFields)
                value=app.ParamsTable.Data{k,2};
                if ischar(value) || isstring(value), value=str2double(value); end
                p.(app.DisplayedParameterFields{k})=double(value);
            end
            p.mechanism=app.Mechanism.Value; p.autoRatio=false;
            p.weights=cellfun(@double,app.WeightsTable.Data(:,2))';
            settings=struct('enabled',logical(app.DynamicWeightsEnabled.Value),'interval',app.DynamicWeightFields(1).Value, ...
                'gain',app.DynamicWeightFields(2).Value,'maxMultiplier',app.DynamicWeightFields(3).Value,'response',app.DynamicWeightFields(4).Value);
            if ~isequaln(settings,camdesign.dynamicWeightSettings(p))
                p.dynamicWeights=settings; camdesign.dynamicWeightSettings(p);
            end
            candidate=app.Project; candidate.params=p; candidate.targets=double(app.TargetsTable.Data);
            candidate.nodes=double(app.NodesTable.Data);
            camdesign.validateProject(candidate);
        end
        function calculate(app)
            if app.MapEditMode, app.message('请先确认或取消地图编辑。'); return; end
            if app.SimulationMode, app.runFixedCamSimulation(); return; end
            try
                candidate=app.inputProject(); result=camdesign.evaluate(candidate,true);
            catch ex
                app.Result=[];
                app.Status.Text='计算未完成；表格输入保留，当前图像为上次结果。';
                app.updateDiagnostics();
                rethrow(ex);
            end
            app.Project=candidate; app.Result=result; app.render();
            app.syncTrainingInputs();
            app.message(sprintf('完成几何计算；实际传动比 %.6g，工作段 %.1f°。', ...
                app.Result.cam.effectiveRatio,rad2deg(app.Result.cam.workEnd)));
            for k=1:numel(app.Result.warnings), app.message(app.Result.warnings{k}); end
        end
        function render(app)
            if isempty(app.Result), return; end
            r=app.Result.route; c=app.Result.cam; p=app.Project.params; a=app.RouteAxes;
            sourceProject=app.Project;
            if app.SimulationMode, sourceProject=app.SimulationReference.project; end
            app.LastDisplayProject=sourceProject; app.LastDisplayResult=app.Result;
            if isempty(app.CamBaseResult) || ~isequaln(app.CamBaseProject,sourceProject) || ~isequaln(app.CamBaseResult,app.Result)
                app.CamBaseProject=sourceProject; app.CamBaseResult=app.Result;
                app.CamInspectionRecord=camdesign.camInspectionData(sourceProject,app.Result,[],'current');
                app.SelectedCrossing=0;
            end
            cla(a); hold(a,'on');
            rectangle(a,'Position',[p.bounds(1) p.bounds(3) diff(p.bounds(1:2)) diff(p.bounds(3:4))], ...
                'EdgeColor',[.4 .4 .4],'LineStyle','--','LineWidth',.8, ...
                'HitTest','off','PickableParts','none','Tag','course-boundary');
            lines=gobjects(1,7);
            lines(1)=plot(a,r.front(:,1),r.front(:,2),'k-','LineWidth',1.5,'Tag','route-front');
            lines(2)=plot(a,r.sensor(:,1),r.sensor(:,2),'r-','LineWidth',1.6,'Tag','route-sensor');
            lines(3)=plot(a,r.drive(:,1),r.drive(:,2),'b-','LineWidth',1.1,'Tag','route-drive');
            lines(4)=plot(a,r.driven(:,1),r.driven(:,2),'b--','LineWidth',1.1,'Tag','route-driven');
            lines(5)=plot(a,app.Project.nodes(:,1),app.Project.nodes(:,2),'o-','Color',[.2 .6 .42],'MarkerSize',4,'Tag','route-nodes');
            app.NodeLine=lines(5);
            lines(6)=scatter(a,app.Project.targets(:,1),app.Project.targets(:,2),45,'k','o');
            lines(7)=quiver(a,NaN,NaN,NaN,NaN,0,'Color',[.85 .15 .65],'LineWidth',1.4,'Tag','optimization-direction');
            directionLegend=plot(a,NaN,NaN,'->','Color',[.85 .15 .65], ...
                'HitTest','off','PickableParts','none','Tag','optimization-direction-legend');
            app.RouteLines=[lines(1:6) directionLegend];
            set(lines,'HitTest','off','PickableParts','none');
            for k=1:size(app.Project.targets,1)
                text(a,app.Project.targets(k,1),app.Project.targets(k,2),sprintf('  %d',k),'FontSize',10, ...
                    'HitTest','off','PickableParts','none','Tag','route-target-label');
            end
            hold(a,'off'); axis(a,'equal'); grid(a,'on');
            app.fitRouteView();
            xlabel(a,'场地 X / mm'); ylabel(a,'场地 Y / mm');
            direction=app.OptimizationDirection;
            if app.Busy && ~app.SimulationMode && ~isempty(direction) && strcmp(direction.event,'searching') ...
                    && isequaln(direction.directionBaseNodes,app.Project.nodes) && any(direction.descentDirection(:))
                vectors=direction.descentDirection; origins=direction.directionBaseNodes;
                visible=vecnorm(vectors,2,2)>1e-12;
                scale=.035*hypot(diff(p.bounds(1:2)),diff(p.bounds(3:4)))/max(vecnorm(vectors,2,2));
                set(lines(7),'XData',origins(visible,1),'YData',origins(visible,2), ...
                    'UData',scale*vectors(visible,1),'VData',scale*vectors(visible,2));
                app.DirectionStatus.Text=sprintf('AI方向：第 %d 轮；箭头统一放大',direction.directionIteration);
            else
                app.DirectionStatus.Text='AI方向：无有效数据';
            end
            title(a,'路线与有序打卡点');
            legendColumns=1; legendCorner='northeast';
            if diff(p.bounds(1:2))>=1.5*diff(p.bounds(3:4)), legendColumns=7; legendCorner='northwest'; end
            legend(a,app.RouteLines,{'前轮','传感器','主动轮','从动轮','节点','目标','AI'}, ...
                'Location',legendCorner,'NumColumns',legendColumns,'FontSize',9,'IconColumnWidth',10,'AutoUpdate','off');
            a=app.SteeringAxes; legend(a,'off'); cla(a); plot(a,r.frontDistance,rad2deg(r.steering),'Color',[.15 .40 .70],'LineWidth',1.4);
            yline(a,p.maxSteeringDeg,'--'); yline(a,-p.maxSteeringDeg,'--'); grid(a,'on');
            title(a,'前轮转角（左转为正）'); xlabel(a,'前轮行程 / mm'); ylabel(a,'转角 / deg');
            app.drawCamRecord();
            app.updateInspectionStatus(); app.updateDiagnostics();
        end
        function updateInspectionStatus(app)
            if isempty(app.CamInspectionRecord), return; end
            data=app.CamInspectionRecord; m=data.result.metrics; p=data.project.params;
            [~,trajectory]=camdesign.trajectoryBounds(data.result.route,p.bounds);
            crossText=sprintf('%g',m.intersectionCount);
            if ~m.geometryChecked, crossText='未完整检查'; end
            app.Status.Text=sprintf('%s · 打卡偏差 %.2f mm；压力角 %.2f°；轮廓自交 %s\n五点中心出界 %.6g mm；欠切余量 %.4g', ...
                data.shortLabel,m.maxHitError,m.maxPressureDeg,crossText,trajectory.maximumOutsideMM,m.minUndercutMargin);
            returnOK=isfield(m,'returnAngleSatisfied') && m.returnAngleSatisfied;
            if isfield(m,'actualReturnDeg'), app.Status.Text=[app.Status.Text,sprintf('    回程 %.2f° / 预留 %.2f°',m.actualReturnDeg,p.returnAngleDeg)]; end
            if m.maxPressureDeg>p.maxPressureDeg || m.minUndercutMargin<=0 || m.maxHitError>p.hitTolerance || m.intersectionCount>0 || ~trajectory.satisfied || ~returnOK
                app.Status.Text=[app.Status.Text,'    有指标超限，需改进'];
                app.Status.FontColor=[.65 .28 .08];
            else
                app.Status.FontColor=[.12 .20 .30];
            end
        end
        function invalidate(app)
            if app.MapEditMode, app.message('请先确认或取消地图编辑。'); return; end
            if app.SimulationMode
                app.SimulationResult=[];
                app.Status.Text='反推参数已修改，凸轮保持固定；点击“更新反推”查看路线变化。';
                return;
            end
            app.OptimizationDirection=[]; app.OptimizationInfo=[];
            app.DirectionStatus.Text='AI方向：无有效数据';
            app.Result=[]; app.Status.Text='输入已修改，请重新计算；当前图像为上次结果。';
            app.updateDiagnostics();
        end
        function drawCamRecord(app)
            if isempty(app.CamInspectionRecord), return; end
            data=app.CamInspectionRecord; c=data.result.cam; p=data.project.params;
            a=app.CamAxes; legend(a,'off'); cla(a); hold(a,'on');
            camLines=gobjects(1,4);
            camLines(1)=plot(a,c.pitch(:,1),c.pitch(:,2),'Color',[.2 .4 .75],'LineWidth',1.2);
            camLines(2)=plot(a,c.actual(:,1),c.actual(:,2),'Color',[.85 .25 .20],'LineWidth',1.5);
            camLines(3)=plot(a,NaN,NaN,'--','Color',[.5 .5 .5],'LineWidth',1.5);
            returnPoints=c.actual(~c.workingMask,:);
            if ~isempty(returnPoints), set(camLines(3),'XData',returnPoints(:,1),'YData',returnPoints(:,2)); end
            set(camLines(2),'Tag','inspected-cam-actual');
            reference=p.referenceDiameter/2;
            if app.SimulationMode, reference=app.SimulationReference.project.params.referenceDiameter/2; end
            angle=linspace(0,2*pi,257);
            camLines(4)=plot(a,reference*cos(angle),reference*sin(angle),':','Color',[.2 .2 .2],'LineWidth',1.1,'Tag','zero-reference-circle');
            camLabels={'理论','实际','回程','零位圆 d/2'};
            if isfield(data.result,'intersectionPoints') && ~isempty(data.result.intersectionPoints)
                points=data.result.intersectionPoints;
                camLines(5)=plot(a,points(:,1),points(:,2),'ro','LineStyle','none','MarkerSize',8,'LineWidth',1.6, ...
                    'HitTest','off','PickableParts','none','Tag','cam-self-intersections');
                camLabels{5}='实际自交';
            end
            plot(a,0,0,'k+','MarkerSize',7,'Tag','cam-center');
            hold(a,'off'); axis(a,'equal'); grid(a,'on'); xlabel(a,'X / mm'); ylabel(a,'Y / mm');
            extent=1.25*max([vecnorm(c.pitch,2,2);vecnorm(c.actual,2,2);reference]);
            xlim(a,[-extent extent]); ylim(a,[-extent extent]);
            title(a,['凸轮 · ',data.shortLabel]);
            legend(a,camLines,camLabels, ...
                'Location','north','NumColumns',numel(camLines),'FontSize',9,'IconColumnWidth',10,'AutoUpdate','off');
            app.CamFullLimits=[a.XLim a.YLim];
            app.refreshDetailCam();
        end
        function fitRouteView(app,extraPoints)
            r=app.Result.route; bounds=app.Project.params.bounds;
            points=[r.front;r.sensor;r.drive;r.driven;app.Project.nodes;app.Project.targets];
            if nargin>1, points=[points;extraPoints]; end
            lower=min([points;bounds([1 3])],[],1);
            upper=max([points;bounds([2 4])],[],1);
            padding=.04*[diff(bounds(1:2)) diff(bounds(3:4))];
            horizontal=[lower(1)-padding(1) upper(1)+padding(1)];
            vertical=[lower(2)-padding(2) upper(2)+padding(2)];
            if diff(bounds(3:4))>1.5*diff(bounds(1:2))
                % Keep equal millimetre scales while leaving room beside a
                % portrait field for its vertical legend.
                span=max(diff(horizontal),.8*diff(vertical)); horizontal=mean(horizontal)+[-span span]/2;
            end
            xlim(app.RouteAxes,horizontal); ylim(app.RouteAxes,vertical);
        end
        function toggleSimulation(app)
            if app.Busy || app.MapEditMode, return; end
            if app.SimulationMode
                ref=app.SimulationReference;
                app.SimulationMode=false; app.Project=ref.project; app.Result=ref.result;
                app.SimulationReference=[]; app.SimulationResult=[];
                app.syncInputs(); app.setSimulationControls(); app.render();
                app.message('已退出反推并恢复设计参数；试调没有改写原凸轮或设计方案。');
                return;
            end
            app.calculate();
            app.SimulationReference=struct('project',app.Project,'result',app.Result);
            app.SimulationMode=true;
            app.syncInputs(); app.setSimulationControls(); app.runFixedCamSimulation();
            app.message('已固定当前理论凸轮。可修改轮径、传动比、轴距、c、中心距、传感器坐标或发车方向，再点“更新反推”。');
        end
        function setSimulationControls(app)
            if app.SimulationMode
                app.Buttons(4).Text='更新反推'; app.Buttons(7).Text='退出反推';
            else
                app.Buttons(4).Text='计算凸轮'; app.Buttons(7).Text='固定凸轮反推';
            end
            app.refreshControls();
        end
        function runFixedCamSimulation(app)
            app.readInputs(); ref=app.SimulationReference; p=app.Project.params;
            assert(strcmp(p.mechanism,ref.project.params.mechanism),'cam:SimulationMechanism','固定凸轮试调期间不能切换转向机构。');
            sim=camdesign.simulate(ref.result.cam,p,ref.result.route.front(1,:), ...
                deg2rad(p.headingDeg),GearRatio=p.gearRatio);
            sim.hits=camdesign.orderedHits(sim.sensor,ref.project.targets);
            sim.maxPhaseDeviation=max(vecnorm(sim.sensor-ref.result.route.sensor,2,2));
            app.SimulationResult=sim; app.Result=ref.result; app.render();
            hold(app.RouteAxes,'on');
            trial=plot(app.RouteAxes,sim.sensor(:,1),sim.sensor(:,2),'k--','LineWidth',1.5,'DisplayName','固定凸轮试调');
            hold(app.RouteAxes,'off');
            app.fitRouteView(sim.sensor);
            legendColumns=1; legendCorner='northeast';
            if diff(p.bounds(1:2))>=1.5*diff(p.bounds(3:4)), legendColumns=8; legendCorner='northwest'; end
            legend(app.RouteAxes,[app.RouteLines trial],{'前轮','传感器','主动轮','从动轮','节点','目标','AI','试调'}, ...
                'Location',legendCorner,'NumColumns',legendColumns,'FontSize',9,'IconColumnWidth',10,'AutoUpdate','off');
            a=app.SteeringAxes; cla(a);
            plot(a,rad2deg(sim.phase),rad2deg(ref.result.route.steering),'b-', ...
                rad2deg(sim.phase),rad2deg(sim.steering),'r--'); grid(a,'on');
            xlabel(a,'凸轮相位 / deg'); ylabel(a,'转角 / deg');
            title(a,'固定凸轮：设计与试调转角'); legend(a,{'设计','试调'},'Location','best');
            app.Status.Text=sprintf('固定凸轮反推：同相位最大传感器偏差 %.3f mm；最大打卡偏差 %.3f mm', ...
                sim.maxPhaseDeviation,max(sim.hits.errors));
            app.Status.FontColor=[.12 .20 .30];
            app.message(sprintf('固定凸轮反推完成，实际试调传动比 %.6g，主动轮行程 %.3f mm。这是理想运动学预测。',p.gearRatio,sim.driveDistance(end)));
        end
        function beginRouteEditing(app)
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            try
                candidate=app.inputProject();
                assert(~isempty(app.Result) && isequaln(candidate,app.Project), ...
                    'cam:StaleRoute','请先计算凸轮，使地图与当前表格输入一致，再进入地图编辑。');
            catch ex
                app.message(['无法进入地图编辑：',ex.message]); return;
            end
            % End toolbar modes before assigning the temporary motion callback.
            zoom(app.Figure,'off'); pan(app.Figure,'off');
            ref=struct('project',app.Project,'result',app.Result, ...
                'selectedRow',app.SelectedNodeRow,'status',app.Status.Text, ...
                'statusColor',app.Status.FontColor,'xlim',app.RouteAxes.XLim,'ylim',app.RouteAxes.YLim, ...
                'pointer',app.Figure.Pointer,'toolbarVisible','off');
            ref.motionFcn=app.Figure.WindowButtonMotionFcn;
            if ~isempty(app.RouteAxes.Toolbar)
                ref.toolbarVisible=app.RouteAxes.Toolbar.Visible;
                app.RouteAxes.Toolbar.Visible='off';
            end
            disableDefaultInteractivity(app.RouteAxes);
            app.MapEditReference=ref; app.MapEditNodes=app.Project.nodes;
            app.MapEditMode=true; app.MapEditSelection=0;
            app.Figure.Pointer='crosshair';
            app.Figure.WindowButtonMotionFcn=@(~,~)app.routePointerMove();
            app.refreshControls();
            app.MapEditHelp.Text='点击地图选最近节点；Esc 取消';
            app.Status.Text='地图编辑：先点击选择路线节点，再移动预览；确认后重算，取消恢复。';
            app.message('地图编辑已开启，缩放/平移暂时停用；移动节点不会自动保存 MAT。');
        end
        function routeMapClick(app,point,source,selectionType)
            if nargin<4, selectionType='normal'; end
            if ~app.MapEditMode || app.Busy || app.SimulationMode || ~strcmp(selectionType,'normal') ...
                    || ~app.isRoutePoint(point,source), return; end
            if app.MapEditSelection==0
                [~,k]=min(sum((app.MapEditNodes-point).^2,2));
                app.MapEditSelection=k; app.SelectedNodeRow=k;
                app.refreshControls(); app.drawNodePreview();
            else
                app.previewRouteNode(point,source);
                app.confirmRouteNode();
            end
        end
        function valid=isRoutePoint(app,point,source)
            valid=false;
            if ~isnumeric(point) || ~isreal(point) || ~isequal(size(point),[1 2]) || any(~isfinite(point)) ...
                    || ~isscalar(source) || ~isgraphics(source), return; end
            if ~isequal(source,app.RouteAxes) && ~isequal(ancestor(source,'axes'),app.RouteAxes), return; end
            bounds=app.Project.params.bounds;
            valid=point(1)>=max(app.RouteAxes.XLim(1),bounds(1)) && point(1)<=min(app.RouteAxes.XLim(2),bounds(2)) ...
                && point(2)>=max(app.RouteAxes.YLim(1),bounds(3)) && point(2)<=min(app.RouteAxes.YLim(2),bounds(4));
        end
        function routePointerMove(app)
            if ~app.MapEditMode || app.MapEditSelection==0 || app.Busy || app.SimulationMode, return; end
            source=hittest(app.Figure);
            app.previewRouteNode(app.RouteAxes.CurrentPoint(1,1:2),source);
        end
        function previewRouteNode(app,point,source)
            if ~app.MapEditMode || app.MapEditSelection==0 || app.Busy || app.SimulationMode ...
                    || ~app.isRoutePoint(point,source), return; end
            app.MapEditNodes(app.MapEditSelection,:)=point;
            app.drawNodePreview();
        end
        function drawNodePreview(app)
            k=app.MapEditSelection; point=app.MapEditNodes(k,:);
            app.NodesTable.Data=app.MapEditNodes;
            app.NodeLine.XData=app.MapEditNodes(:,1); app.NodeLine.YData=app.MapEditNodes(:,2);
            if isempty(app.SelectedNodeMarker) || ~isgraphics(app.SelectedNodeMarker)
                hold(app.RouteAxes,'on');
                app.NodeMoveGuide=plot(app.RouteAxes,NaN,NaN,'--','Color',[.85 .45 .05], ...
                    'HandleVisibility','off','HitTest','off','PickableParts','none','Tag','node-move-guide');
                app.SelectedNodeMarker=plot(app.RouteAxes,NaN,NaN,'o','MarkerSize',11, ...
                    'LineWidth',2,'Color',[.85 .45 .05],'HandleVisibility','off','HitTest','off', ...
                    'PickableParts','none','Tag','node-edit-selection');
                hold(app.RouteAxes,'off');
            end
            start=app.MapEditReference.project.nodes(k,:);
            app.NodeMoveGuide.XData=[start(1) point(1)]; app.NodeMoveGuide.YData=[start(2) point(2)];
            app.SelectedNodeMarker.XData=point(1); app.SelectedNodeMarker.YData=point(2);
            app.MapEditHelp.Text='移动预览 → 再点地图或确认；Esc 取消';
            app.Status.Text=sprintf('预览节点 %d：(%.3f, %.3f) mm；轨迹与凸轮仍为编辑前结果，确认后重算。',k,point);
            app.Status.FontColor=[.65 .28 .08];
        end
        function confirmRouteNode(app)
            if ~app.MapEditMode || app.MapEditSelection==0 || app.Busy || app.SimulationMode, return; end
            candidate=app.MapEditReference.project; candidate.nodes=app.MapEditNodes;
            try
                % Never publish a candidate Project before all geometry checks finish.
                result=camdesign.evaluate(candidate,true);
            catch ex
                app.Status.Text=['候选不可用：',ex.message,'  轨迹与凸轮仍为编辑前结果；请移动节点重试或取消。'];
                app.Status.FontColor=[.65 .15 .10];
                app.message(['节点未确认：',ex.message]); return;
            end
            k=app.MapEditSelection;
            app.Project=candidate; app.Result=result; app.History=[];
            app.syncInputs(); app.render(); app.finishRouteEditing();
            app.message(sprintf('节点 %d 已确认并重算轨迹/凸轮；项目尚未保存。',k));
        end
        function cancelRouteEditing(app)
            if ~app.MapEditMode, return; end
            ref=app.MapEditReference;
            app.Project=ref.project; app.Result=ref.result; app.SelectedNodeRow=ref.selectedRow;
            app.syncInputs(); app.render(); app.finishRouteEditing();
            app.Status.Text=ref.status; app.Status.FontColor=ref.statusColor;
            app.message('地图编辑已取消，节点表、轨迹和凸轮已恢复编辑前状态。');
        end
        function finishRouteEditing(app)
            ref=app.MapEditReference;
            if isgraphics(app.SelectedNodeMarker), delete(app.SelectedNodeMarker); end
            if isgraphics(app.NodeMoveGuide), delete(app.NodeMoveGuide); end
            app.SelectedNodeMarker=[]; app.NodeMoveGuide=[];
            app.Figure.Pointer=ref.pointer; app.Figure.WindowButtonMotionFcn=ref.motionFcn;
            enableDefaultInteractivity(app.RouteAxes);
            if ~isempty(app.RouteAxes.Toolbar), app.RouteAxes.Toolbar.Visible=ref.toolbarVisible; end
            app.RouteAxes.XLim=ref.xlim; app.RouteAxes.YLim=ref.ylim;
            app.MapEditMode=false; app.MapEditSelection=0; app.MapEditNodes=[]; app.MapEditReference=[];
            app.MapEditHelp.Text='独立三次样条路线节点'; app.updateNodeInfo(); app.refreshControls();
        end
        function routeEditorKey(app,event)
            if ~app.MapEditMode, return; end
            if strcmp(event.Key,'escape'), app.cancelRouteEditing();
            elseif ismember(event.Key,{'return','enter'}), app.confirmRouteNode(); end
        end
        function selectPoint(app,kind,event)
            if isempty(event.Indices), return; end
            if strcmp(kind,'target'), app.SelectedTargetRow=event.Indices(1,1);
            else, app.SelectedNodeRow=event.Indices(1,1); end
        end
        function modifyPoints(app,kind,operation)
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            if strcmp(kind,'target'), table=app.TargetsTable; selected=app.SelectedTargetRow;
            else, table=app.NodesTable; selected=app.SelectedNodeRow; end
            data=table.Data; selected=max(1,min(size(data,1),selected));
            if strcmp(kind,'node')
                if operation>0
                    app.refineRoute(min(selected,size(data,1)-1)); return;
                elseif size(data,1)>2
                    if strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1') && size(data,1)-1<=app.Project.params.bezier.degree
                        app.Status.Text='无法删点：控制点数量必须大于贝塞尔阶数。'; app.message(app.Status.Text); return;
                    end
                    candidate=app.inputProject(); candidate.nodes(selected,:)=[];
                    if isfield(candidate.params,'routeSpline')
                        stations=candidate.params.routeSpline.stations;
                        stations(selected)=[]; stations=stations-stations(1);
                        candidate.params.routeSpline.stations=stations;
                    end
                    if strcmp(camdesign.routeModel(candidate.params),'bezier-blend-independent-v1')
                        assert(size(candidate.nodes,1)>candidate.params.bezier.degree,'cam:BezierCount','删点后数量必须大于贝塞尔阶数。');
                    end
                    candidate=camdesign.updateTrainingSampling(candidate); camdesign.validateProject(candidate);
                    app.Project=candidate; app.History=[]; app.SelectedNodeRow=min(selected,size(candidate.nodes,1));
                    app.syncInputs(); app.invalidate();
                    app.message('路线节点已删除；此操作可能改变路线，请重新计算。'); return;
                else
                    app.message('至少保留两个路线节点。'); return;
                end
            end
            if operation>0
                if selected<size(data,1), point=(data(selected,:)+data(selected+1,:))/2;
                else, point=data(end,:)+(data(end,:)-data(end-1,:))/2; end
                table.Data=[data(1:selected,:);point;data(selected+1:end,:)];
            elseif size(data,1)>2
                data(selected,:)=[]; table.Data=data;
            else
                app.message('至少保留两个点。'); return;
            end
            app.invalidate();
            app.updateNodeInfo();
            if strcmp(kind,'target'), app.message('打卡点已修改；点击“重建路线”可重新生成路线节点。'); end
        end
        function applied=refineRoute(app,segments)
            applied=false;
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            try
                candidate=app.inputProject();
                assert(~isempty(app.Result) && isequaln(candidate,app.Project), ...
                    'cam:StaleRoute','请先计算凸轮，使当前路线与表格输入一致，再保形插点。');
                bezier=strcmp(camdesign.routeModel(candidate.params),'bezier-blend-independent-v1');
                oldCount=size(candidate.nodes,1);
                if bezier
                    if nargin<2
                        candidate=camdesign.setControlPointCount(candidate,2*oldCount-1);
                        inserted=2;
                    else
                        segment=max(1,min(oldCount-1,segments(1)));
                        middle=(candidate.nodes(segment,:)+candidate.nodes(segment+1,:))/2;
                        candidate.nodes=[candidate.nodes(1:segment,:);middle;candidate.nodes(segment+1:end,:)];
                        assert(size(candidate.nodes,1)<=250,'cam:BezierCount','控制点数量上限为250。');
                        inserted=segment+1;
                    end
                    info=struct('originalNodeCount',oldCount,'newNodeCount',size(candidate.nodes,1), ...
                        'addedCoordinateDOF',2*(size(candidate.nodes,1)-oldCount),'skippedSegments',[],'insertedIndices',inserted);
                else
                    if nargin<2, segments=(1:oldCount-1)'; end
                    [candidate,info]=camdesign.refineRoute(candidate,segments);
                end
                candidate=camdesign.updateTrainingSampling(candidate);
                result=camdesign.evaluate(candidate,true);
            catch ex
                app.Status.Text=['路线未细化：',ex.message]; app.message(app.Status.Text); return;
            end
            app.Project=candidate; app.Result=result; app.History=[];
            app.OptimizationDirection=[]; app.OptimizationInfo=[];
            if ~isempty(info.insertedIndices), app.SelectedNodeRow=info.insertedIndices(1); end
            app.syncInputs(); app.render(); applied=true;
            if bezier
                app.message(sprintf('独立贝塞尔控制点 %d → %d；增点已重建，曲线可能改变，目标访问顺序不变。',oldCount,info.newNodeCount));
            else
                app.message(sprintf('保形细化：%d → %d 个前轮插值节点，新增 %d 个坐标自由度；场外拟插点跳过 %d 个。目标访问顺序不变。', ...
                    info.originalNodeCount,info.newNodeCount,info.addedCoordinateDOF,numel(info.skippedSegments)));
            end
        end
        function updateNodeInfo(app)
            if strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1')
                app.NodeInfo.Text=sprintf('控制点 %d · 目标访问 %d · 独立贝塞尔\n路线不必穿点；增减或改阶会改变曲线。',size(app.NodesTable.Data,1),size(app.TargetsTable.Data,1));
                app.RefineRouteButton.Text='重建增点'; app.PointButtons(3).Text='插控制点';
                if ~app.MapEditMode, app.MapEditHelp.Text='独立贝塞尔控制点（不必穿过）'; end
                return;
            end
            mode='弦长站位';
            if isfield(app.Project.params,'routeSpline'), mode='固定站位'; end
            app.NodeInfo.Text=sprintf('路线节点 %d · 目标访问 %d · %s\n插点保留曲线；移动节点后改变路线。', ...
                size(app.NodesTable.Data,1),size(app.TargetsTable.Data,1),mode);
            app.RefineRouteButton.Text='全段细化'; app.PointButtons(3).Text='段中插点';
            if ~app.MapEditMode, app.MapEditHelp.Text='独立三次样条路线节点'; end
        end
        function syncTrainingInputs(app)
            settings=camdesign.trainingSettings(app.Project);
            for k=1:numel(app.TrainingFieldNames), app.TrainingFields(k).Value=settings.(app.TrainingFieldNames{k}); end
            app.TrainingModel.Value=camdesign.routeModel(app.Project.params); app.TrainingDirty=false;
            app.refreshTrainingControls();
        end
        function markTrainingDirty(app)
            app.TrainingDirty=true; app.refreshTrainingControls();
        end
        function dynamicWeightsChanged(app)
            app.refreshDynamicWeightControls(); app.invalidate();
        end
        function refreshDynamicWeightControls(app)
            if isempty(app.DynamicWeightsEnabled), return; end
            editable=~app.Busy && ~app.SimulationMode && ~app.MapEditMode;
            constrained=startsWith(app.AlgorithmSelector.Value,'fmincon'); enabled=app.DynamicWeightsEnabled.Value;
            app.DynamicWeightsEnabled.Enable=editable && (~constrained || enabled);
            for k=1:4, app.DynamicWeightFields(k).Enable=editable && enabled && ~constrained; end
            app.Buttons(5).Enable=editable && ~(constrained && enabled);
            app.Buttons(5).Tooltip='使用当前画法和优化方法训练';
            if constrained
                app.DynamicWeightInfo.Text='内点法本次目标必须固定，暂不支持动态权重。已开启时请先取消勾选；基础权重仍可在训练前修改。';
                if enabled, app.Buttons(5).Tooltip='内点法暂不支持动态权重；请先在权重页关闭动态开关。'; end
            elseif enabled
                app.DynamicWeightInfo.Text='只调打卡、压力角、转角及欠切惩罚；长度与转向变化保留基础。实际值只读，跨轮改善请看固定参照分。小窗口可滚动。';
            else
                app.DynamicWeightInfo.Text='静态评分：使用基础权重。训练实际权重有记录后才显示；缺记录不从当前输入推测。';
            end
        end
        function refreshTrainingControls(app)
            if isempty(app.TrainingFields), return; end
            editable=~app.Busy && ~app.SimulationMode && ~app.MapEditMode;
            for k=1:9, app.TrainingFields(k).Enable=editable; end
            app.TrainingModel.Enable=editable; app.TrainingApplyButton.Enable=editable; app.TrainingResetButton.Enable=editable;
            bezier=strcmp(app.TrainingModel.Value,'bezier-blend-independent-v1');
            app.TrainingFields(4).Enable=editable && bezier;
            constrained=startsWith(app.AlgorithmSelector.Value,'fmincon');
            if constrained, for k=6:9, app.TrainingFields(k).Enable='off'; end, end
            model='三次插值样条'; if strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1'), model='独立贝塞尔融合'; end
            pending='已应用';
            if ~isfield(app.Project.params,'training'), pending='旧模式；本版默认未启用'; end
            if app.TrainingDirty, pending='待应用；旧图保留'; end
            description='本版独立规则，非原版融合/调度。减点或切换模型会重建。';
            if constrained
                inputMM=app.TrainingFields(5).Value;
                nominalMM=max(.001,min(1,inputMM));
                description=[description,newline,sprintf('内点默认差分：输入 %.6g → 名义 %.6g mm（限0.001～1 mm，之后按TypicalX缩放）。学习、平滑与调节项禁用。',inputMM,nominalMM)];
            else, description=[description,newline,'梯度力=差分距离；步幅×学习率×阶梯衰减；平滑仅接受改善。']; end
            app.TrainingInfo.Text=sprintf('实际：%d 控制点 / %d 路线采样\n当前：%s；%s\n%s', ...
                size(app.Project.nodes,1),app.Project.params.samples,model,pending,description);
            if ~isempty(app.MethodSummary)
                app.MethodSummary.Text=sprintf('画法决定连线，优化方法负责改点；传动比 %.6g 固定执行，只能用户手改。',app.Project.params.gearRatio);
            end
            app.refreshTrainingRuntime();
            app.refreshDynamicWeightControls();
        end
        function applied=applyTraining(app)
            applied=false;
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            app.TrainingDirty=true;
            try
                candidate=app.inputProject(true); changes=struct('routeModel',app.TrainingModel.Value);
                for k=1:numel(app.TrainingFieldNames), changes.(app.TrainingFieldNames{k})=app.TrainingFields(k).Value; end
                [candidate,info]=camdesign.applyTrainingSettings(candidate,changes,app.AlgorithmSelector.Value);
                result=camdesign.evaluate(candidate,true);
            catch ex
                app.Status.Text=['训练设置未应用：',ex.message,' 当前图像为上次结果。'];
                app.message(app.Status.Text); app.refreshTrainingControls(); return;
            end
            app.Project=candidate; app.Result=result; app.History=[]; app.OptimizationDirection=[]; app.OptimizationInfo=[];
            app.syncInputs(); app.render(); applied=true;
            app.message(sprintf('本版训练设置已应用：实际 %d 个控制点，%d 个路线采样；保形保证=%d，目标访问顺序保持。', ...
                size(candidate.nodes,1),info.actualSamples,info.shapePreservationGuaranteed));
        end
        function action(app,name)
            try
                if app.MapEditMode
                    app.message('请先确认或取消地图编辑，再执行其它操作。'); return;
                end
                if app.Busy && ~strcmp(name,'stop'), return; end
                if app.SimulationMode && ismember(name,{'import','save','seed','optimize','export'})
                    app.message('请先退出反推，恢复设计模式。'); return;
                end
                switch name
                    case 'calculate', app.calculate();
                    case 'seed'
                        app.readInputs();
                        wasBezier=strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1');
                        trained=isfield(app.Project.params,'training'); settings=camdesign.trainingSettings(app.Project);
                        mode=camdesign.routeModel(app.Project.params);
                        if isfield(app.Project.params,'routeSpline'), app.Project.params=rmfield(app.Project.params,'routeSpline'); end
                        if wasBezier, app.Project.params=rmfield(app.Project.params,'bezier'); app.Project.params.routeModel='cubic'; end
                        app.Project.nodes=camdesign.seedNodes(app.Project.targets,app.Project.params);
                        if trained || wasBezier
                            app.Project=camdesign.applyTrainingSettings(app.Project,struct('routeModel',mode, ...
                                'controlPointCount',settings.controlPointCount,'bezierDegree',settings.bezierDegree),app.AlgorithmSelector.Value);
                        end
                        app.syncInputs(); app.calculate();
                    case 'import'
                        [f,d]=uigetfile('*.mat','导入本项目或原软件 MAT'); if isequal(f,0), return; end
                        try
                            [next,notes]=camdesign.importProject(fullfile(d,f));
                        catch importError
                            if ~strcmp(importError.identifier,'cam:UnsupportedMechanism'), rethrow(importError); end
                            choice=uiconfirm(app.Figure, ...
                                [importError.message,newline,'是否沿用点位和车体参数另建方案？原文件保持不变。'], ...
                                '原文件转向机构尚未实现','Options',{'另建齿条方案','另建平推方案','取消'}, ...
                                'DefaultOption',3,'CancelOption',3);
                            if strcmp(choice,'取消'), return; end
                            if strcmp(choice,'另建齿条方案'), mechanism='rack'; else, mechanism='flat'; end
                            [next,notes]=camdesign.importProject(fullfile(d,f),MechanismOverride=mechanism);
                        end
                        app.Project=next; app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.OptimizationDirection=[];
                        app.syncInputs(); app.calculate(); for k=1:numel(notes), app.message(notes{k}); end
                    case 'save'
                        app.readInputs(); [f,d]=uiputfile('*.mat','保存复现项目','cam_project.mat');
                        if ~isequal(f,0), camdesign.saveProject(app.Project,fullfile(d,f)); app.message('项目已保存。'); end
                    case 'optimize', app.runOptimization();
                    case 'stop', app.StopRequested=true; app.message('已请求停止，将在求解器下次回调时停止。');
                    case 'simulate', app.toggleSimulation();
                    case 'export'
                        app.calculate(); folder=uigetdir(pwd,'选择输出父目录'); if isequal(folder,0), return; end
                        destination=fullfile(folder,['cam_candidate_',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
                        camdesign.exportResult(app.Project,app.Result,destination);
                        app.message(['候选点集与参数报告已导出：',destination]);
                end
            catch ex
                app.message(['错误：',ex.message]);
                if isvalid(app.Figure) && strcmp(app.Figure.Visible,'on'), uialert(app.Figure,ex.message,'操作未完成'); end
            end
        end
        function runOptimization(app)
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            app.readInputs(); app.Busy=true; app.StopRequested=false; app.setBusy(true);
            cleanup=onCleanup(@()app.finishBusy());
            app.OptimizationDirection=[]; app.OptimizationInfo=[];
            app.History=[]; app.HistoryProject=[]; app.updateDiagnostics();
            [project,history,info]=camdesign.optimize(app.Project,@app.optimizationUpdate,app.AlgorithmSelector.Value);
            app.Project=project; app.History=history; app.HistoryProject=project; app.OptimizationDirection=[]; app.OptimizationInfo=info;
            app.syncInputs(); app.calculate();
            reasons=struct('iteration_limit','达到请求轮数','user_stop','用户停止', ...
                'gradient_tolerance','梯度与候选均无改善','no_improving_step','多尺度搜索无改善', ...
                'constrained_converged','约束求解器一阶停止条件满足','constrained_step_tolerance','约束求解器步长停止', ...
                'constrained_infeasible','约束求解器未找到可行点','function_evaluation_limit','达到函数调用预算', ...
                'time_limit','达到求解时间预算','solver_stopped','求解器停止');
            if isfield(reasons,info.reason), text=reasons.(info.reason); else, text=info.reason; end
            m=app.Result.metrics; p=app.Project.params;
            [~,trajectory]=camdesign.trajectoryBounds(app.Result.route,p.bounds);
            verdict='本模型检查通过，仍待外部验证';
            if m.maxHitError>p.hitTolerance || m.maxPressureDeg>p.maxPressureDeg || m.maxSteeringDeg>p.maxSteeringDeg ...
                    || m.minUndercutMargin<=0 || m.intersectionCount>0 || ~trajectory.satisfied ...
                    || ~isfield(m,'returnAngleSatisfied') || ~m.returnAngleSatisfied, verdict='未达标候选'; end
            if isfield(info,'verifiedFeasible')
                if info.verifiedFeasible, verdict='加密离散模型检查通过，仍待外部验证';
                else, verdict='加密验收未通过或未完成；未达标候选'; end
            end
            if ~trajectory.satisfied || (isfield(info,'verifiedFeasible') && ~info.verifiedFeasible)
                app.Status.FontColor=[.65 .28 .08];
            end
            app.Status.Text=sprintf('优化结束 %d/%d 轮：%s · %s\n工作/回程压力角 %.1f°/%.1f°，阈值 %.1f°；最大打卡偏差 %.2f mm；五点中心出界 %.6g mm', ...
                info.iterations,info.requestedIterations,text,verdict,app.Result.metrics.maxWorkPressureDeg, ...
                app.Result.metrics.maxReturnPressureDeg,app.Project.params.maxPressureDeg,app.Result.metrics.maxHitError,trajectory.maximumOutsideMM);
            app.message('场界检查覆盖前轮、后轴中点、主从动轮中心和传感器的采样位置，不含车宽与整车外廓。');
            app.message(sprintf('%s，%d/%d 轮，原因：%s；%.3f 秒，%d 次评价；固定参照评分 %.6g → %.6g。', ...
                info.algorithm,info.iterations,info.requestedIterations,text,info.elapsedSeconds,info.evaluations,history(1).score,history(end).score));
            if isfield(info,'dynamicWeights') && info.dynamicWeights.enabled
                app.message(sprintf('结束时动态搜索分 %.6g；该值使用末轮实际权重，不作为固定尺度的跨轮下降比较。',info.finalDynamicScore));
            end
            if isfield(info,'returnedObjective')
                app.message(sprintf('函数调用预算 %d，软时间限 %.1f 秒；最终加密验收另计。', ...
                    info.maxFunctionEvaluations,info.maxSeconds));
                app.message(sprintf('实验约束目标 %.6g → %.6g；以上历史评分仅供对照。最大归一化违规 %.6g；加密可行=%d。', ...
                    history(1).objective,info.returnedObjective,info.returnedMaxViolation,info.verifiedFeasible));
                fine=info.verification.refinedGrid;
                if fine.valid
                    fm=fine.metrics;
                    detail=sprintf('加密压力角 %.3f°/%.3f°（限 %.1f°）；打卡 %.3f mm；转角 %.3f°；欠切 %.6g；自交 %d；五点中心出界 %.6g mm。', ...
                        fm.maxWorkPressureDeg,fm.maxReturnPressureDeg,p.maxPressureDeg, ...
                        fm.maxHitError,fm.maxSteeringDeg,fm.minUndercutMargin,fm.intersectionCount,fine.maxTrajectoryOutsideMM);
                else
                    detail=['加密计算未完成：',fine.errorIdentifier,' ',fine.errorMessage];
                end
                app.Status.Text=sprintf('实验约束结束 %d/%d 轮：%s · %s\n%s', ...
                    info.iterations,info.requestedIterations,text,verdict,detail);
                app.message(detail);
                for k=1:numel(info.remainingConstraints), app.message(['约束验收：',info.remainingConstraints{k}]); end
            end
            for k=1:numel(app.Result.warnings), app.message(['结束时仍需处理：',app.Result.warnings{k}]); end
            app.updateDiagnostics();
            if isfield(info,'verification') && isfield(info.verification,'refinedGrid')
                fine=info.verification.refinedGrid;
                if fine.valid && ~isempty(fine.metrics) && fine.metrics.intersectionCount>0
                    app.changeCamSource('refined'); app.ResultsTabs.SelectedTab=app.CrossingTab;
                end
            end
        end
        function stop=optimizationUpdate(app,iteration,project,history)
            app.Project=project; app.History=history; app.HistoryProject=project; app.NodesTable.Data=project.nodes;
            app.OptimizationDirection=history(end);
            app.Result=camdesign.evaluate(project,false); app.render();
            if strcmp(history(end).event,'searching')
                app.Status.Text=sprintf('搜索第 %d/%d 轮（已完成 %d 轮）    固定参照 %.5f    最大偏差 %.2f mm', ...
                    history(end).directionIteration,project.params.iterations,iteration,history(end).score,history(end).maxHitError);
            else
                app.Status.Text=sprintf('已完成 %d/%d 轮    固定参照 %.5f    最大偏差 %.2f mm', ...
                    iteration,project.params.iterations,history(end).score,history(end).maxHitError);
            end
            if isfield(history,'objective')
                app.Status.Text=sprintf('实验约束 %d/%d 轮    求解目标 %.5g    最大归一化违规 %.5g；尚待加密验收', ...
                    iteration,project.params.iterations,history(end).objective,history(end).maxConstraintViolation);
            end
            if isfield(history,'weightMode') && strcmp(history(end).weightMode,'violation-adaptive-v1')
                app.Status.Text=[app.Status.Text,sprintf('；本轮动态 %.5f（权重会变）',history(end).dynamicScore)];
            end
            drawnow; stop=app.StopRequested;
        end
        function openTraining(app)
            app.ControlsTabs.SelectedTab=app.TrainingTab;
            app.refreshTrainingControls();
        end
        function resizeLayout(app)
            if isempty(app.RootLayout) || ~isvalid(app.RootLayout), return; end
            dimensions=app.Figure.Position(3:4); width=320; footer=262;
            if dimensions(1)<1220, width=260; end
            app.RootLayout.ColumnWidth={width,'1x'};
            app.RootLayout.RowHeight={34,36,52,'1x',footer};
            app.ParamsTable.ColumnWidth={width-100,75};
            sideColumn=floor((width-65)/2);
            app.TargetsTable.ColumnWidth={sideColumn,sideColumn}; app.NodesTable.ColumnWidth={sideColumn,sideColumn};
            app.WeightsTable.ColumnWidth={width-168,60,60};
        end
        function view=createScoreView(app,parent)
            grid=uigridlayout(parent,[1 3],'ColumnWidth',{370,'1x','1x'},'Padding',[2 0 2 0],'ColumnSpacing',8);
            table=uitable(grid,'ColumnName',{'本版评分项','基础项','权重','加权贡献'}, ...
                'ColumnWidth',{125,70,50,95},'RowName',{},'FontSize',10,'ColumnEditable',false);
            scoreAxes=uiaxes(grid,'FontSize',9); objectiveAxes=uiaxes(grid,'FontSize',9);
            view=struct('table',table,'scoreAxes',scoreAxes,'objectiveAxes',objectiveAxes);
        end
        function view=createCrossingView(app,parent,large)
            grid=uigridlayout(parent,[2 2],'RowHeight',{50,'1x'},'ColumnWidth',{360,'1x'},'Padding',[2 0 2 0],'RowSpacing',2);
            bar=uigridlayout(grid,[2 4],'RowHeight',{28,18},'ColumnWidth',{'1x',110,90,100},'Padding',[0 0 0 0],'RowSpacing',2);
            bar.Layout.Row=1; bar.Layout.Column=[1 2];
            source=uidropdown(bar,'Items',{'当前网格轮廓','加密复查轮廓'},'ItemsData',{'current','refined'}, ...
                'ValueChangedFcn',@(object,~)app.changeCamSource(object.Value));
            zoom=uibutton(bar,'Text','放大选中交点','ButtonPushedFcn',@(~,~)app.zoomCamCrossing());
            reset=uibutton(bar,'Text','返回全凸轮','ButtonPushedFcn',@(~,~)app.resetCamView());
            details=uibutton(bar,'Text','交点大窗','ButtonPushedFcn',@(~,~)app.openDiagnostics('crossings'));
            label=uilabel(bar,'Text','尚无已计算轮廓','FontSize',10); label.Layout.Row=2; label.Layout.Column=[1 4];
            table=uitable(grid,'ColumnName',{'交点','段 A','段 B','X / mm','Y / mm'}, ...
                'ColumnWidth',{45,55,55,90,90},'RowName',{},'FontSize',10,'ColumnEditable',false, ...
                'CellSelectionCallback',@(~,event)app.selectCamCrossing(event));
            table.Layout.Row=2; table.Layout.Column=1;
            if large
                axesHandle=uiaxes(grid); axesHandle.Layout.Row=2; axesHandle.Layout.Column=2;
                app.DetailCamAxes=axesHandle;
            else
                text=uilabel(grid,'Text',['点选列表即可局部放大，也可点击“放大选中交点”。',newline, ...
                    '交点坐标、段对和凸轮来自同一个网格；加密复查会同时切换轮廓。',newline, ...
                    '未完整检查不显示旧交点；加密显示不会改写用户参数或历史文件。'], ...
                    'WordWrap','on','FontSize',11,'VerticalAlignment','top');
                text.Layout.Row=2; text.Layout.Column=2;
            end
            view=struct('source',source,'label',label,'table',table,'zoom',zoom,'reset',reset,'details',details);
        end
        function openDiagnostics(app,kind)
            if isempty(app.DiagnosticsFigure) || ~isgraphics(app.DiagnosticsFigure)
                app.DiagnosticsFigure=uifigure('Name','结果详情 · 评分、日志与交点','Position',[100 80 1260 760], ...
                    'Visible',app.Figure.Visible);
                layout=uigridlayout(app.DiagnosticsFigure,[1 1],'Padding',[8 8 8 8]);
                tabs=uitabgroup(layout); app.DetailTabs=struct();
                app.DetailTabs.score=uitab(tabs,'Title','通用评分与独立目标');
                app.ScoreViews{2}=app.createScoreView(app.DetailTabs.score);
                app.DetailTabs.log=uitab(tabs,'Title','完整日志');
                logGrid=uigridlayout(app.DetailTabs.log,[1 1]);
                app.DetailLog=uitextarea(logGrid,'Editable','off','FontSize',13);
                app.DetailTabs.crossings=uitab(tabs,'Title','交点与对应轮廓');
                app.CrossingViews{2}=app.createCrossingView(app.DetailTabs.crossings,true);
            end
            app.DetailTabs.(kind).Parent.SelectedTab=app.DetailTabs.(kind);
            if strcmp(kind,'log'), app.ResultsTabs.SelectedTab=app.LogTab;
            elseif strcmp(kind,'crossings'), app.ResultsTabs.SelectedTab=app.CrossingTab;
            else, app.ResultsTabs.SelectedTab=app.ScoreTab; end
            app.DiagnosticsFigure.Visible=app.Figure.Visible;
            if isempty(app.FullLog), app.DetailLog.Value={''}; else, app.DetailLog.Value=app.FullLog; end
            app.updateDiagnostics(); app.refreshDetailCam();
        end
        function updateDiagnostics(app)
            if isempty(app.ScoreSummary) || ~isvalid(app.ScoreSummary), return; end
            current=app.diagnosticsAreCurrent();
            project=app.LastDisplayProject; result=app.LastDisplayResult; state='暂无当前计算';
            if ~isempty(app.CamInspectionRecord)
                project=app.CamInspectionRecord.project; result=app.CamInspectionRecord.result;
                state='当前计算';
                if strcmp(app.CamInspectionRecord.source,'refined'), state='加密复查'; end
            end
            if ~current && ~isempty(result), state='历史 / 待重算'; end
            if app.SimulationMode, state='设计参考分（固定凸轮试调中）'; end
            historyState='本次训练（优化网格）';
            if ~current || isempty(app.HistoryProject) || ~isequaln(app.HistoryProject,app.CamBaseProject)
                historyState='历史记录（非当前输入）';
            end
            weightsMatch=~isempty(app.HistoryProject) && isequaln(app.HistoryProject,app.CamBaseProject);
            data=camdesign.resultDisplayData(project,result,app.History,app.OptimizationInfo,state,historyState,weightsMatch);
            app.ScoreDisplayData=data;
            lengths={'待计算','待计算'}; values=[data.routeLengthMM,data.driveLengthMM];
            for k=1:2
                if isfinite(values(k)), lengths{k}=sprintf('%.3f m（%.2f mm）',values(k)/1000,values(k)); end
            end
            lengthState=strrep(data.state,'设计参考分','设计参考');
            app.LengthSummary.Text=sprintf('%s · 总路程（前轮轨迹）：%s    主动轮行程：%s',lengthState,lengths{:});
            if isfinite(data.total)
                dynamicText='未记录';
                if data.dynamicAvailable, dynamicText=sprintf('%.5g',data.dynamicTotal);
                elseif strcmp(data.weightMode,'fixed'), dynamicText='未启用'; end
                app.ScoreSummary.Text=sprintf('固定参照 %.5g · 动态 %s\n%s · %d/%d',data.total,dynamicText,data.state,data.grid);
            else, app.ScoreSummary.Text=sprintf('固定参照：暂无\n请先计算'); end
            app.ScoreSummary.Tooltip=['固定参照分使用基础权重；动态分使用匹配记录的实际权重。',data.weightSource,'。动态分不可按固定尺度判断跨轮改善。'];
            app.ScoreBasis.Enable='on';
            app.ScoreBasis.Tooltip=[data.state,' · ',data.weightSource,'；固定参照趋势不随动态权重改变。'];
            actual=repmat({'未记录'},6,1);
            if ~isempty(data.activeWeights), actual=arrayfun(@(value)sprintf('%.5g',value),data.activeWeights(:),'UniformOutput',false); end
            app.WeightsTable.Data(:,3)=actual; app.WeightsTable.Tooltip=[data.state,' · ',data.weightSource];
            weightState='当前'; actualHeading='实际';
            if startsWith(data.state,'历史'), weightState='历史'; actualHeading='历史';
            elseif startsWith(data.state,'加密'), weightState='加密重评';
            elseif startsWith(data.state,'设计参考'), weightState='设计参考'; actualHeading='参考'; end
            source='实际权重未记录';
            if ~isempty(data.activeWeights)
                source='固定权重记录';
                if data.dynamicAvailable
                    source='已记录实际权重，更新轮次未记录';
                    if data.weightUpdateIteration>0, source=sprintf('使用第%d轮起的搜索权重',data.weightUpdateIteration);
                    elseif data.weightUpdateIteration==0, source='初始搜索权重，尚未更新'; end
                end
            end
            app.DynamicWeightSource.Text=[weightState,' · ',source];
            app.WeightsTable.ColumnName={'评分项','基础',actualHeading};
            tableRows=data.rows; weightHeading='基础'; contributionHeading='固定贡献'; viewStatus='固定参照';
            if strcmp(app.ScoreBasis.Value,'auto')
                if ~isempty(data.activeRows)
                    tableRows=data.activeRows; weightHeading='实际'; viewStatus='实际固定权重';
                    if data.dynamicAvailable, contributionHeading='动态贡献'; viewStatus='实际动态权重'; end
                else
                    viewStatus='固定参照 / 待记录';
                end
            elseif strcmp(app.ScoreBasis.Value,'dynamic')
                tableRows=data.activeRows; weightHeading='实际'; contributionHeading='动态贡献'; viewStatus='实际动态权重';
                if ~data.dynamicAvailable
                    tableRows=cell(0,4); contributionHeading='待记录'; viewStatus='动态待记录';
                    if strcmp(data.weightMode,'fixed'), viewStatus='动态未启用'; end
                end
            end
            if ~isfinite(data.total), viewStatus='待计算 / 未记录'; end
            app.ScoreViewStatus.Text=[weightState,' · ',viewStatus];
            for k=1:numel(app.ScoreViews)
                view=app.ScoreViews{k}; if ~isvalid(view.table), continue; end
                view.table.Data=tableRows;
                view.table.ColumnName={'本版评分项','基础项',weightHeading,contributionHeading};
                view.table.Tooltip=sprintf('%s 视图：%s；来源：%s，网格%d/%d，版本%s。%s。', ...
                    data.description,viewStatus,data.state,data.grid,data.scoreVersion,data.weightSource);
                app.plotDiagnosticSeries(view.scoreAxes,data.scoreX,data.scoreY, ...
                    ['固定参照分 · ',data.historyState],data.xLabel,'固定参照分','尚无迭代记录');
                objectiveTitle='内点目标（独立尺度）';
                if startsWith(data.historyState,'历史'), objectiveTitle=['历史 · ',objectiveTitle]; end
                if ~isempty(data.objectiveY)
                    app.plotDiagnosticSeries(view.objectiveAxes,data.objectiveX,data.objectiveY, ...
                        objectiveTitle,data.xLabel,'独立目标值','尚无记录');
                else
                    app.plotDiagnosticSeries(view.objectiveAxes,data.dynamicX,data.dynamicY, ...
                        ['动态搜索分（权重会变）· ',data.historyState],data.xLabel,'动态分（非固定尺度）','未启用动态搜索 / 缺少记录');
                end
            end
            app.updateCrossingViews(); app.refreshTrainingRuntime();
        end
        function plotDiagnosticSeries(app,a,x,y,heading,xLabel,yLabel,emptyText)
            cla(a); title(a,heading,'FontSize',10);
            if isempty(x)
                axis(a,'off'); text(a,.5,.5,emptyText,'Units','normalized','HorizontalAlignment','center','FontSize',10);
            else
                axis(a,'on'); plot(a,x,y,'-','Color',[.18 .4 .65],'LineWidth',1.2); grid(a,'on');
                xlabel(a,xLabel); ylabel(a,yLabel);
            end
        end
        function changeCamSource(app,source)
            if isempty(app.CamBaseResult), return; end
            info=[];
            if ~isempty(app.HistoryProject) && isequaln(app.HistoryProject,app.CamBaseProject), info=app.OptimizationInfo; end
            try
                data=camdesign.camInspectionData(app.CamBaseProject,app.CamBaseResult,info,source);
            catch ex
                app.message(['凸轮复查未完成：',ex.message]);
                for k=1:numel(app.CrossingViews)
                    view=app.CrossingViews{k}; if ~isvalid(view.source), continue; end
                    view.source.Value=app.CamInspectionRecord.source;
                    view.label.Text=['复查未完成，保持原轮廓：',ex.message];
                end
                return;
            end
            app.CamInspectionRecord=data; app.SelectedCrossing=0;
            app.drawCamRecord(); app.updateInspectionStatus(); app.updateDiagnostics();
            app.message(['凸轮显示来源：',data.label,'。坐标与轮廓使用同一结果。']);
        end
        function updateCrossingViews(app)
            if isempty(app.CamInspectionRecord), return; end
            data=app.CamInspectionRecord; locations=data.result.intersectionPoints; pairs=data.result.intersectionPairs;
            tableData=[(1:size(locations,1))',pairs,locations];
            prefix='';
            fresh=app.diagnosticsAreCurrent();
            if ~fresh, prefix='历史 / 编辑前 · '; end
            if app.SimulationMode, prefix='设计参考 · '; end
            for k=1:numel(app.CrossingViews)
                view=app.CrossingViews{k}; if ~isvalid(view.table), continue; end
                view.table.Data=tableData; view.label.Text=[prefix,data.label]; view.source.Value=data.source;
                view.source.Enable=~app.Busy && fresh;
                view.zoom.Enable=~isempty(locations);
            end
        end
        function current=diagnosticsAreCurrent(app)
            current=~isempty(app.Result) && ~app.TrainingDirty && ~app.MapEditMode && ~app.SimulationMode;
            try, current=current && isequaln(app.inputProject(true),app.CamBaseProject); catch, current=false; end
        end
        function selectCamCrossing(app,event)
            if isempty(event.Indices), return; end
            app.SelectedCrossing=event.Indices(1,1); app.zoomCamCrossing();
        end
        function zoomCamCrossing(app)
            if isempty(app.CamInspectionRecord) || isempty(app.CamInspectionRecord.result.intersectionPoints), return; end
            data=app.CamInspectionRecord; count=size(data.result.intersectionPoints,1);
            index=max(1,min(count,app.SelectedCrossing)); app.SelectedCrossing=index;
            point=data.result.intersectionPoints(index,:); pairs=data.result.intersectionPairs(index,:);
            curve=data.result.cam.actual;
            if norm(curve(1,:)-curve(end,:))>1e-8, curve=[curve;curve(1,:)]; end
            vertices=curve([pairs(1),pairs(1)+1,pairs(2),pairs(2)+1],:);
            fullSpan=max(diff(app.CamFullLimits(1:2)),diff(app.CamFullLimits(3:4)));
            radius=max(.05,min(.12*fullSpan,4*max(vecnorm(vertices-point,2,2))));
            limits=[point(1)+[-radius radius],point(2)+[-radius radius]];
            app.applyCamLimits(limits);
        end
        function resetCamView(app)
            if ~isempty(app.CamFullLimits), app.applyCamLimits(app.CamFullLimits); end
        end
        function applyCamLimits(app,limits)
            app.CamAxes.XLim=limits(1:2); app.CamAxes.YLim=limits(3:4);
            if ~isempty(app.DetailCamAxes) && isgraphics(app.DetailCamAxes)
                app.DetailCamAxes.XLim=limits(1:2); app.DetailCamAxes.YLim=limits(3:4);
            end
        end
        function refreshDetailCam(app)
            if isempty(app.DetailCamAxes) || ~isgraphics(app.DetailCamAxes) || isempty(app.CamInspectionRecord), return; end
            data=app.CamInspectionRecord; a=app.DetailCamAxes; c=data.result.cam;
            cla(a); hold(a,'on'); plot(a,c.pitch(:,1),c.pitch(:,2),'Color',[.2 .4 .75]);
            plot(a,c.actual(:,1),c.actual(:,2),'Color',[.85 .25 .2],'Tag','detail-cam-actual');
            if ~isempty(data.result.intersectionPoints)
                points=data.result.intersectionPoints;
                plot(a,points(:,1),points(:,2),'ro','LineStyle','none','MarkerSize',8,'LineWidth',1.6);
            end
            hold(a,'off'); axis(a,'equal'); grid(a,'on'); xlabel(a,'X / mm'); ylabel(a,'Y / mm');
            title(a,data.shortLabel); if ~isempty(app.CamFullLimits), app.applyCamLimits(app.CamFullLimits); end
        end
        function refreshTrainingRuntime(app)
            if isempty(app.TrainingRuntime) || ~isvalid(app.TrainingRuntime), return; end
            if isempty(app.History)
                app.TrainingRuntime.Text='尚未开始训练；编辑初始设置后点击“应用训练设置”。'; return;
            end
            h=app.History(end); state='本次'; iteration='未记录';
            if isfield(h,'iteration'), iteration=sprintf('%d',h.iteration); end
            if ~app.diagnosticsAreCurrent() || isempty(app.HistoryProject) || ~isequaln(app.HistoryProject,app.Project), state='上次'; end
            constrained=isfield(h,'objective');
            if constrained
                nominal='未记录';
                if isfield(h,'nominalDifferenceStepMM')
                    nominal=sprintf('%.6g mm（历史记录）',h.nominalDifferenceStepMM);
                elseif isstruct(app.OptimizationInfo) && isfield(app.OptimizationInfo,'nominalDifferenceStepMM')
                    nominal=sprintf('%.6g mm（求解器记录）',app.OptimizationInfo.nominalDifferenceStepMM);
                end
                violation='未记录';
                if isfield(h,'maxConstraintViolation'), violation=sprintf('%.6g',h.maxConstraintViolation); end
                app.TrainingRuntime.Text=sprintf('%s内点第%s轮：名义差分 %s\n独立目标 %.6g；归一化违规 %s。\n本法不使用学习率/平滑调度。', ...
                    state,iteration,nominal,h.objective,violation);
            elseif all(isfield(h,{'probeMM','learningScale','scheduleScale','scheduledStepMM','stepMM','smoothingAlpha'}))
                requested='未记录';
                if isfield(h,'plannedSmoothingRates')
                    if isempty(h.plannedSmoothingRates), requested='无';
                    else, requested=mat2str(h.plannedSmoothingRates,3); end
                end
                app.TrainingRuntime.Text=sprintf('%s第%s轮：探测 %.5g mm；学习倍率 %.5g；衰减 %.5g\n计划步 %.5g mm；采纳位移 %.5g mm\n计划平滑 %s；采纳平滑 %.5g', ...
                    state,iteration,h.probeMM,h.learningScale,h.scheduleScale,h.scheduledStepMM,h.stepMM,requested,h.smoothingAlpha);
            else, app.TrainingRuntime.Text='历史记录缺少有效参数字段，不能从初始设置反推实际值。'; end
        end
        function setBusy(app,busy)
            app.Busy=logical(busy); app.refreshControls();
        end
        function refreshControls(app)
            editable=~app.Busy && ~app.SimulationMode && ~app.MapEditMode;
            for k=[1 2 3 5 8], app.Buttons(k).Enable=editable; end
            app.Buttons(4).Enable=~app.Busy && ~app.MapEditMode;
            app.Buttons(6).Enable=app.Busy;
            app.Buttons(7).Enable=~app.Busy && ~app.MapEditMode;
            app.Mechanism.Enable=editable; app.AutoRatio.Enable='off'; app.TrainingShortcut.Enable=~app.MapEditMode;
            app.AlgorithmSelector.Enable=editable;
            for k=1:numel(app.PointButtons), app.PointButtons(k).Enable=editable; end
            app.RefineRouteButton.Enable=editable;
            app.ParamsTable.ColumnEditable=[false ~app.Busy && ~app.MapEditMode];
            app.TargetsTable.ColumnEditable=[editable editable];
            app.NodesTable.ColumnEditable=[editable editable]; app.WeightsTable.ColumnEditable=[false editable false];
            app.MapEditButton.Enable=editable;
            app.ConfirmNodeButton.Enable=app.MapEditMode && app.MapEditSelection>0 && ~app.Busy && ~app.SimulationMode;
            app.CancelNodeButton.Enable=app.MapEditMode && ~app.Busy && ~app.SimulationMode;
            app.refreshTrainingControls();
        end
        function finishBusy(app)
            app.Busy=false;
            if isvalid(app.Figure), app.setBusy(false); end
            if app.CloseAfterStop && isvalid(app.Figure), app.closeRequested(); end
        end
        function closeRequested(app)
            if app.Busy, app.StopRequested=true; app.CloseAfterStop=true;
            else
                if app.MapEditMode, app.cancelRouteEditing(); end
                if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
                delete(app.Figure);
            end
        end
        function message(app,text)
            app.FullLog(end+1,1)={char(text)};
            app.Log.Value=app.FullLog(max(1,end-199):end);
            if ~isempty(app.DetailLog) && isvalid(app.DetailLog), app.DetailLog.Value=app.FullLog; end
        end
    end
end
