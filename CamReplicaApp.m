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
        ForceModelSwitchButton
        RestoreModelSwitchButton
        ModelSwitchBackupInfo
        ModelSwitchBackupPath = ''
        TrainingInfo
        TrainingDirty = false
        TrainingFieldNames = {'iterations','controlPointCount','interpolationPerSegment','bezierDegree', ...
            'gradientForce','learningRate','smoothingRate','adjustInterval','adjustExponent'}
        SimulationMode = false
        SimulationReference = []
        SimulationResult = []
        SimulationSource
        ActualClosureTab
        ActualClosureButton
        ActualClosureStatus
        ActualClosureTable
        ActualClosureReport = []
        ActualClosureProject = []
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
        AutoTuneTab
        AutoTuneFields
        AutoTuneSeed
        AutoTuneProgress
        AutoTuneVerdict
        AutoTuneParameters
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
            titleBar=uigridlayout(root,[1 3],'ColumnWidth',{'1x',65,210},'Padding',[0 0 0 0]);
            titleBar.Layout.Row=1; titleBar.Layout.Column=[1 2];
            uilabel(titleBar,'Text','工创赛凸轮设计  /  路线、机构与几何校验', ...
                'FontSize',20,'FontWeight','bold','FontColor',[.12 .20 .30]);
            uilabel(titleBar,'Text','反推来源','FontSize',11);
            app.SimulationSource=uidropdown(titleBar,'Items',{'实际轮廓接触（默认）','理论凸轮（对照）'}, ...
                'ItemsData',{'actual','theoretical'},'Value','actual', ...
                'Tooltip','实际模式由冻结的轮廓线段求接触；理论模式直接读取滚子中心运动。试调中退出后才能切换。');
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
            app.TrainingModel=uidropdown(methods,'Items',{'三次样条（通过节点）','贝塞尔曲线（控制点调形）','标准三次B样条（内点法）','标准五次B样条（内点法）'}, ...
                'ItemsData',{'cubic','bezier-blend-independent-v1','bspline-3','bspline-5'},'ValueChangedFcn',@(~,~)app.routeModelChanged(), ...
                'Tooltip','B样条是系数控制多边形，通常不穿控制点。切换优先精确保形，否则独立误差门禁拟合，超限拒绝；仅支持内点法。');
            app.TrainingModel.Layout.Row=1; app.TrainingModel.Layout.Column=2;
            label=uilabel(methods,'Text','优化方法','FontWeight','bold'); label.Layout.Row=1; label.Layout.Column=3;
            app.AlgorithmSelector=uidropdown(methods, ...
                'Items',{'梯度搜索（峰值评分）','四方向试探（加权）','约束优化（内点法）','全自动调优（权重＋训练）'}, ...
                'ItemsData',{'peak-gradient-v2','video-four-direction-v1','fmincon-interior-point-experimental-v1','auto-tune-v1'}, ...
                'Value','peak-gradient-v2','ValueChangedFcn',@(~,~)app.algorithmChanged(), ...
                'Tooltip','全自动锁定当前路线模型及阶数，只比较权重和适用训练设置。物理参数和阈值不自动改变。');
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
            trainingRoot=uigridlayout(t,[4 1],'RowHeight',{64,'1x',62,40},'Padding',[0 0 0 0],'RowSpacing',3);
            app.TrainingRuntime=uilabel(trainingRoot,'Text','本轮有效参数：尚无训练记录','FontSize',10,'WordWrap','on','VerticalAlignment','top');
            training=uigridlayout(trainingRoot,[10 2],'RowHeight',[repmat({24},1,9),{166}], ...
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
            trainingActions=uigridlayout(trainingRoot,[2 2],'RowHeight',{28,28},'ColumnWidth',{'1x',84},'Padding',[2 0 2 0],'RowSpacing',3,'ColumnSpacing',4);
            trainingActions.Layout.Row=3;
            app.TrainingApplyButton=uibutton(trainingActions,'Text','应用训练设置','FontSize',11,'ButtonPushedFcn',@(~,~)app.applyTraining());
            app.TrainingResetButton=uibutton(trainingActions,'Text','还原','FontSize',11,'ButtonPushedFcn',@(~,~)app.syncTrainingInputs());
            app.TrainingApplyButton.Tooltip='严格保形映射；最大位置、RMS及切向超限则拒绝，原方案和待应用输入保留。';
            app.ForceModelSwitchButton=uibutton(trainingActions,'Text','强制切换（允许改形）','FontSize',10, ...
                'Tooltip','仅手动使用：先备份完整项目、结果与所有待应用输入，再接受端点约束合格的有限真实曲线拟合。超出保形门限会明确标示；物理计算失败仍保留新路线供编辑。', ...
                'ButtonPushedFcn',@(~,~)app.applyTraining(true));
            app.ForceModelSwitchButton.Layout.Row=2; app.ForceModelSwitchButton.Layout.Column=1;
            app.RestoreModelSwitchButton=uibutton(trainingActions,'Text','恢复备份','FontSize',10, ...
                'Tooltip','恢复最近一次手动改形前的完整项目、原结果、历史与全部待应用表格输入；备份文件保留。', ...
                'ButtonPushedFcn',@(~,~)app.restoreModelSwitch());
            app.RestoreModelSwitchButton.Layout.Row=2; app.RestoreModelSwitchButton.Layout.Column=2;
            app.ModelSwitchBackupInfo=uilabel(trainingRoot,'Text','手动改形前自动备份；备份后可恢复完整状态。','WordWrap','on','FontSize',9,'VerticalAlignment','top');
            app.ModelSwitchBackupInfo.Layout.Row=4;
            app.Buttons(3).Tooltip='从目标按所选画法及合法训练设置重新生成路线；显式改形，保留起点和物理输入，不映射旧路线。';
            t=uitab(tabs,'Title','全自动'); app.AutoTuneTab=t;
            autoRoot=uigridlayout(t,[5 1],'RowHeight',{78,62,60,240,90},'Padding',[2 0 2 0],'RowSpacing',3,'Scrollable','on');
            budget=uigridlayout(autoRoot,[3 2],'RowHeight',{24,24,24},'ColumnWidth',{'1x',80},'Padding',[0 0 0 0],'RowSpacing',2);
            labels={'搜索配置组数','单组最大轮数'}; app.AutoTuneFields=gobjects(1,2);
            for k=1:2
                uilabel(budget,'Text',labels{k},'FontSize',11);
                app.AutoTuneFields(k)=uieditfield(budget,'numeric','Value',1,'FontSize',11, ...
                    'ValueChangedFcn',@(~,~)app.invalidate());
            end
            app.AutoTuneFields(1).Tooltip='搜索配置数量；另有约束精修组，合计以运行记录为准。';
            app.AutoTuneFields(2).Tooltip='每组轮数上限；实际轮数可因收敛、无改善或停止而减少。';
            app.AutoTuneSeed=uilabel(budget,'Text','','FontSize',10); app.AutoTuneSeed.Layout.Row=3; app.AutoTuneSeed.Layout.Column=[1 2];
            app.AutoTuneProgress=uilabel(autoRoot,'Text','全自动尚未启动','FontSize',11,'FontWeight','bold','WordWrap','on','VerticalAlignment','top');
            app.AutoTuneVerdict=uilabel(autoRoot,'Text','验收待记录；评分下降不代表通过。','FontSize',11,'FontWeight','bold', ...
                'FontColor',[.65 .28 .08],'WordWrap','on','VerticalAlignment','top');
            app.AutoTuneParameters=uitable(autoRoot,'ColumnName',{'本组运行记录','实际值'},'RowName',{},'ColumnEditable',false, ...
                'ColumnWidth',{150,105},'FontSize',10);
            uilabel(autoRoot,'Text','自动比较六项权重及训练设置，可能多组长时间运行。可点“停止”，下一次回调生效，加密检验可能需等待。调优期间车体、传动比、阈值、目标点锁定。最终须通过几何与4/8倍收敛检验；不保证找到可行解。', ...
                'FontSize',10,'WordWrap','on','VerticalAlignment','top');
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
            app.ActualClosureTab=uitab(app.ResultsTabs,'Title','轮廓闭环');
            closureLayout=uigridlayout(app.ActualClosureTab,[2 1],'RowHeight',{36,'1x'},'Padding',[4 2 4 2]);
            closureBar=uigridlayout(closureLayout,[1 2],'ColumnWidth',{165,'1x'},'Padding',[0 0 0 0]);
            app.ActualClosureButton=uibutton(closureBar,'Text','检查当前实际轮廓','ButtonPushedFcn',@(~,~)app.checkActualClosure());
            app.ActualClosureStatus=uilabel(closureBar,'Text','尚未检查；固定实际轮廓进行接触与车辆反推，再加密积分比较。','WordWrap','on','FontSize',11);
            app.ActualClosureTable=uitable(closureLayout,'ColumnName',{'闭环检查项','计算值／状态'},'ColumnWidth',{280,'auto'},'ColumnEditable',false,'RowName',{});
            app.syncInputs(); app.calculate();
            app.message('v0.2：齿条/平推、固定凸轮调参；独立样条与数值优化。尚未完成原版点集或实车对照。');
            app.Figure.SizeChangedFcn=@(~,~)app.resizeLayout(); app.resizeLayout();
        end
        function syncInputs(app)
            p=app.Project.params;
            indices=1:numel(app.ParameterFields);
            if app.SimulationMode, indices=[1 2 3 5 7 8 10 11 12 13]; end
            if app.SimulationMode && strcmp(app.SimulationSource.Value,'actual'), indices=[1 2 3 4 5 7 8 10 11 12 13]; end
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
            settings=camdesign.autoTuneSettings(p);
            app.AutoTuneFields(1).Value=settings.trials; app.AutoTuneFields(2).Value=settings.maxIterations;
            app.AutoTuneSeed.Text=sprintf('随机种子 %g · 另精修 %g 组（随项目保存）',settings.seed,settings.polishCount);
            app.syncTrainingInputs();
        end
        function readInputs(app)
            assert(~app.MapEditMode,'cam:MapEditActive','请先确认或取消地图编辑。');
            app.Project=app.inputProject();
        end
        function candidate=inputProject(app,allowPendingTraining,forRebuild)
            if nargin<2, allowPendingTraining=false; end
            if nargin<3, forRebuild=false; end
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
            auto=camdesign.autoTuneSettings(p); edited=auto;
            edited.trials=app.AutoTuneFields(1).Value; edited.maxIterations=app.AutoTuneFields(2).Value;
            if ~isequaln(auto,edited)
                p.autoTune=edited; camdesign.autoTuneSettings(p);
            end
            candidate=app.Project; candidate.params=p; candidate.targets=double(app.TargetsTable.Data);
            candidate.nodes=double(app.NodesTable.Data);
            % Rebuilding validates fresh target-seeded geometry, independently
            % of the discarded model's endpoint/coefficient constraints.
            if forRebuild, return; end
            validationCandidate=candidate;
            if app.SimulationMode && strcmp(camdesign.routeModel(p),'bspline-v1')
                % Fixed-cam tuning does not evaluate the design spline with
                % the trial heading. Validate its frozen design derivatives
                % and all trial mechanical parameters independently.
                validationCandidate.params.headingDeg=app.SimulationReference.project.params.headingDeg;
                validationCandidate.params.startSteeringDeg=app.SimulationReference.project.params.startSteeringDeg;
            end
            camdesign.validateProject(validationCandidate);
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
            if ~isempty(app.ActualClosureProject) && ~isequaln(app.Project,app.ActualClosureProject)
                app.clearActualClosure();
            end
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
            nodeLabel='节点'; if strcmp(camdesign.routeModel(p),'bspline-v1'), nodeLabel='系数'; end
            legend(a,app.RouteLines,{'前轮','传感器','主动轮','从动轮',nodeLabel,'目标','AI'}, ...
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
            orderOK=isfield(m,'visitOrderSatisfied') && m.visitOrderSatisfied;
            if orderOK, orderText='通过'; else, orderText='未通过/未检查'; end
            app.Status.Text=[app.Status.Text,'；几何访问顺序 ',orderText];
            if isfield(m,'actualReturnDeg'), app.Status.Text=[app.Status.Text,sprintf('    回程 %.2f° / 预留 %.2f°',m.actualReturnDeg,p.returnAngleDeg)]; end
            if m.maxPressureDeg>p.maxPressureDeg || m.minUndercutMargin<=0 || m.maxHitError>p.hitTolerance || m.intersectionCount>0 || ~trajectory.satisfied || ~returnOK || ~orderOK
                app.Status.Text=[app.Status.Text,'    有指标超限，需改进'];
                app.Status.FontColor=[.65 .28 .08];
            else
                app.Status.FontColor=[.12 .20 .30];
            end
        end
        function invalidate(app)
            if app.MapEditMode, app.message('请先确认或取消地图编辑。'); return; end
            app.clearActualClosure();
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
            bounds=app.Project.params.bounds; points=[app.Project.nodes;app.Project.targets];
            if ~isempty(app.Result)
                r=app.Result.route; points=[r.front;r.sensor;r.drive;r.driven;points];
            end
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
            reference=struct('project',app.Project,'result',app.Result);
            sim=app.computeFixedSimulation(reference,app.Project.params);
            app.SimulationReference=reference; app.SimulationMode=true;
            app.syncInputs(); app.setSimulationControls(); app.presentFixedSimulation(sim);
            app.message(['已固定凸轮；来源：',app.SimulationSource.Items{strcmp(app.SimulationSource.ItemsData,app.SimulationSource.Value)}, ...
                '。可修改车体参数再更新反推，退出会恢复设计。实际接触模式也可试调接触半径。']);
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
            candidate=app.inputProject(); sim=app.computeFixedSimulation(app.SimulationReference,candidate.params);
            app.Project=candidate; app.presentFixedSimulation(sim);
        end
        function sim=computeFixedSimulation(app,ref,p)
            assert(strcmp(p.mechanism,ref.project.params.mechanism),'cam:SimulationMechanism','固定凸轮试调期间不能切换转向机构。');
            if strcmp(app.SimulationSource.Value,'actual')
                sim=camdesign.simulateActual(ref.result.cam,p,ref.result.route.front(1,:),deg2rad(p.headingDeg),GearRatio=p.gearRatio);
            else
                sim=camdesign.simulate(ref.result.cam,p,ref.result.route.front(1,:),deg2rad(p.headingDeg),GearRatio=p.gearRatio);
            end
            sim.hits=camdesign.orderedHits(sim.sensor,ref.project.targets);
            design=interp1(ref.result.cam.workPhi,ref.result.route.sensor,sim.phase,'pchip');
            sim.maxPhaseDeviation=max(vecnorm(sim.sensor-design,2,2));
        end
        function presentFixedSimulation(app,sim)
            ref=app.SimulationReference; p=app.Project.params;
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
            plot(a,rad2deg(ref.result.cam.workPhi),rad2deg(ref.result.route.steering),'b-', ...
                rad2deg(sim.phase),rad2deg(sim.steering),'r--'); grid(a,'on');
            xlabel(a,'凸轮相位 / deg'); ylabel(a,'转角 / deg');
            title(a,'固定凸轮：设计与试调转角'); legend(a,{'设计','试调'},'Location','best');
            source='理论对照'; if strcmp(app.SimulationSource.Value,'actual'), source='实际轮廓接触'; end
            app.Status.Text=sprintf('%s反推：同相位最大传感器偏差 %.3f mm；最大打卡偏差 %.3f mm',source, ...
                sim.maxPhaseDeviation,max(sim.hits.errors));
            app.Status.FontColor=[.12 .20 .30];
            app.message(sprintf('固定凸轮反推完成，实际试调传动比 %.6g，主动轮行程 %.3f mm。这是理想运动学预测。',p.gearRatio,sim.driveDistance(end)));
        end
        function clearActualClosure(app)
            app.ActualClosureReport=[]; app.ActualClosureProject=[];
            if ~isempty(app.RouteAxes) && isgraphics(app.RouteAxes), delete(findobj(app.RouteAxes,'Tag','actual-closure-route')); end
            if isempty(app.ActualClosureStatus), return; end
            app.ActualClosureStatus.Text='当前输入尚未检查；闭环检查不等于实车或加工许可。';
            app.ActualClosureTable.Data=cell(0,2);
        end
        function checkActualClosure(app)
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            if app.TrainingDirty
                app.message('请先应用或还原待处理训练设置，再检查当前实际轮廓。'); return;
            end
            app.ResultsTabs.SelectedTab=app.ActualClosureTab; app.clearActualClosure();
            app.Busy=true; app.refreshControls(); cleanup=onCleanup(@()app.finishBusy());
            app.ActualClosureStatus.Text='正在求实际轮廓接触、积分及加密复核…'; drawnow;
            try
                candidate=app.inputProject(); result=camdesign.evaluate(candidate,true);
                [report,sim]=camdesign.verifyActualClosure(candidate,result);
                if ~report.valid || isempty(sim)
                    app.ActualClosureReport=report; app.ActualClosureProject=candidate;
                    app.ActualClosureStatus.Text=['检查未通过：',report.errorMessage];
                    app.ActualClosureTable.Data={'接触／反推可用',false;'错误标识',report.errorIdentifier;'原因',report.errorMessage};
                    app.message(['实际轮廓闭环拒绝：',report.errorIdentifier,' ',report.errorMessage]); return;
                end
                app.Project=candidate; app.Result=result;
                app.ActualClosureProject=candidate; app.ActualClosureReport=report;
                app.render(); app.syncTrainingInputs();
                hold(app.RouteAxes,'on');
                closureLine=plot(app.RouteAxes,sim.sensor(:,1),sim.sensor(:,2),'m--','LineWidth',1.5, ...
                    'DisplayName','实际轮廓反推','Tag','actual-closure-route');
                hold(app.RouteAxes,'off'); app.fitRouteView(sim.sensor);
                legend(app.RouteAxes,[app.RouteLines closureLine],{'前轮','传感器','主动轮','从动轮','节点','目标','AI','实际轮廓反推'}, ...
                    'Location','northwest','NumColumns',4,'FontSize',9,'IconColumnWidth',10,'AutoUpdate','off');
                app.ActualClosureTable.Data={ ...
                    '传感器路线最大偏差 / mm',report.maxSensorDeviationMM; ...
                    '传感器路线RMS偏差 / mm',report.rmsSensorDeviationMM; ...
                    '前轮路线最大偏差 / mm',report.maxFrontDeviationMM; ...
                    '转角最大偏差 / deg',report.maxSteeringDeviationDeg; ...
                    '积分加密最大路线差 / mm',report.integrationMaxSensorDifferenceMM; ...
                    '接触距离残差 / mm',report.maxContactResidualMM; ...
                    '轮廓最大穿透 / mm',report.maxPenetrationMM; ...
                    '反推最大打卡偏差 / mm',report.maxHitErrorMM; ...
                    '接触法线最大压力角 / deg',report.maxPressureDeg; ...
                    '接触合法',report.contactValid; '积分稳定',report.integrationConverged; ...
                    '几何访问顺序',report.visitOrderSatisfied; '部件中心场界',report.trajectoryBoundsSatisfied; ...
                    '闭环数值检查',report.closurePassed; '几何门禁',report.geometryFeasible};
                app.ActualClosureTable.Data=[app.ActualClosureTable.Data; ...
                    {'闭环位置门限 / mm（非实车公差）',report.tolerances.closureMM; ...
                     '积分加密门限 / mm',report.tolerances.integrationMM; ...
                     '接触残差门限 / mm',report.tolerances.contactResidualMM; ...
                     '实际回程角 / deg',report.actualReturnDeg; ...
                     '回程要求 / deg',report.tolerances.minimumReturnDeg; ...
                     '轮廓顶点数量',report.outlineVertexCount; ...
                     '相位积分点数（原 / 加密）',mat2str(report.integrationSamples)}];
                tableData=app.ActualClosureTable.Data;
                for row=1:size(tableData,1)
                    if islogical(tableData{row,2}), tableData{row,2}=app.passText(tableData{row,2});
                    elseif isnumeric(tableData{row,2}), tableData{row,2}=sprintf('%.8g',tableData{row,2}); end
                end
                app.ActualClosureTable.Data=tableData;
                app.ActualClosureStatus.Text=sprintf('闭环数值检查 %s（位置门限 %.4g mm）；几何门禁 %s。非加工或实车许可。', ...
                    app.passText(report.closurePassed),report.tolerances.closureMM,app.passText(report.geometryFeasible));
                app.message(sprintf('实际轮廓完整反推：最大传感器差 %.6g mm，加密差 %.6g mm。%s', ...
                    report.maxSensorDeviationMM,report.integrationMaxSensorDifferenceMM,app.ActualClosureStatus.Text));
            catch ex
                app.ActualClosureStatus.Text=['检查未通过：',ex.message];
                app.message(['实际轮廓闭环未完成：',ex.identifier,' ',ex.message]);
            end
        end
        function value=passText(~,passed)
            value='未通过'; if passed, value='通过'; end
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
            horizontal=app.RouteAxes.XLim; vertical=app.RouteAxes.YLim;
            visibleCoefficients=false;
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1')
                control=camdesign.controlBounds(app.Project);
                visibleCoefficients=strcmp(control.policy,'trajectory-only-v1');
            end
            if ~visibleCoefficients
                bounds=app.Project.params.bounds;
                horizontal=[max(horizontal(1),bounds(1)),min(horizontal(2),bounds(2))];
                vertical=[max(vertical(1),bounds(3)),min(vertical(2),bounds(4))];
            end
            valid=point(1)>=horizontal(1) && point(1)<=horizontal(2) ...
                && point(2)>=vertical(1) && point(2)<=vertical(2);
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
            app.Project=candidate; app.Result=result; app.History=[]; app.HistoryProject=[];
            app.OptimizationInfo=[]; app.OptimizationDirection=[];
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
            app.updateDiagnostics();
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
                if operation<0 && strcmp(camdesign.routeModel(app.Project.params),'bspline-v1')
                    try
                        candidate=app.inputProject();
                        candidate=camdesign.setControlPointCount(candidate,size(data,1)-1);
                        candidate=camdesign.updateTrainingSampling(candidate); result=camdesign.evaluate(candidate,true);
                        app.Project=candidate; app.Result=result; app.History=[]; app.syncInputs(); app.render();
                        if size(candidate.nodes,1)>=size(data,1)
                            app.message('减少控制点无法同时满足保形要求，本次保留原数量；实际数量已同步。');
                        else
                            app.message(sprintf('B样条控制点 %d → %d；几何映射检查通过，首末位置及切向保持。',size(data,1),size(candidate.nodes,1)));
                        end
                    catch ex, app.Status.Text=['B样条未减点：',ex.message]; app.message(app.Status.Text); end
                    return;
                end
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
                bspline=strcmp(camdesign.routeModel(candidate.params),'bspline-v1');
                oldCount=size(candidate.nodes,1);
                if bspline
                    count=oldCount+1; if nargin<2, count=2*oldCount-1; end
                    candidate=camdesign.setControlPointCount(candidate,count);
                    info=struct('newNodeCount',size(candidate.nodes,1),'insertedIndices',[]);
                elseif bezier
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
            if bspline
                app.message(sprintf('标准B样条控制点 %d → %d；几何映射检查通过，首末位置及切向保持。',oldCount,info.newNodeCount));
            elseif bezier
                app.message(sprintf('独立贝塞尔控制点 %d → %d；增点已重建，曲线可能改变，目标访问顺序不变。',oldCount,info.newNodeCount));
            else
                app.message(sprintf('保形细化：%d → %d 个前轮插值节点，新增 %d 个坐标自由度；场外拟插点跳过 %d 个。目标访问顺序不变。', ...
                    info.originalNodeCount,info.newNodeCount,info.addedCoordinateDOF,numel(info.skippedSegments)));
            end
        end
        function updateNodeInfo(app)
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1')
                boundary='多边形可出界；真实轨迹仍检查场界。';
                control=camdesign.controlBounds(app.Project);
                if control.enforced, boundary='系数多边形及真实轨迹均检查场界。'; end
                app.NodeInfo.Text=sprintf('%d次B样条 · %d 系数控制点\n%s',app.Project.params.bspline.degree,size(app.NodesTable.Data,1),boundary);
                app.RefineRouteButton.Text='拟合增点'; app.PointButtons(3).Text='增控制点';
                if ~app.MapEditMode, app.MapEditHelp.Text='B样条系数（不必穿过）；首两点、末两点受导数约束'; end
                return;
            end
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
            app.TrainingModel.Value=app.trainingModelValue(app.Project.params); app.TrainingDirty=false;
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1')
                app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1';
            end
            app.refreshTrainingControls();
        end
        function value=trainingModelValue(~,p)
            value=camdesign.routeModel(p);
            if strcmp(value,'bspline-v1'), value=sprintf('bspline-%d',p.bspline.degree); end
        end
        function routeModelChanged(app)
            if startsWith(app.TrainingModel.Value,'bspline-')
                app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1';
                app.message('标准B样条已选内点法；请应用训练设置进行受约束拟合。');
            end
            app.markTrainingDirty();
        end
        function markTrainingDirty(app)
            app.TrainingDirty=true; app.refreshTrainingControls();
        end
        function dynamicWeightsChanged(app)
            app.refreshDynamicWeightControls(); app.invalidate();
        end
        function algorithmChanged(app)
            app.refreshTrainingControls();
            if strcmp(app.AlgorithmSelector.Value,'auto-tune-v1'), app.openTraining(); end
            app.updateDiagnostics();
        end
        function refreshDynamicWeightControls(app)
            if isempty(app.DynamicWeightsEnabled), return; end
            editable=~app.Busy && ~app.SimulationMode && ~app.MapEditMode;
            constrained=startsWith(app.AlgorithmSelector.Value,'fmincon'); enabled=app.DynamicWeightsEnabled.Value;
            automatic=strcmp(app.AlgorithmSelector.Value,'auto-tune-v1');
            app.DynamicWeightsEnabled.Enable=editable && ~automatic && (~constrained || enabled);
            for k=1:4, app.DynamicWeightFields(k).Enable=editable && enabled && ~constrained && ~automatic; end
            app.Buttons(5).Enable=editable && ~(constrained && enabled) && ~(automatic && app.TrainingDirty);
            app.Buttons(5).Tooltip='使用当前画法和优化方法训练';
            if automatic
                app.DynamicWeightInfo.Text='全自动调优独立选择六项权重，此按违规调权开关不叠加，原配置保留。实际获选值与验收结论见全自动页。';
                app.Buttons(5).Tooltip='运行多组权重与训练设置比较；可能耗时较长，可停止，最终按几何与收敛门禁验收。';
                if app.TrainingDirty, app.Buttons(5).Tooltip='请先还原待应用手动训练输入，或切回原方法应用后再启动全自动。'; end
            elseif constrained
                app.DynamicWeightInfo.Text='内点法本次目标必须固定，暂不支持动态权重。已开启时请先取消勾选；基础权重仍可在训练前修改。';
                if enabled, app.Buttons(5).Tooltip='内点法暂不支持动态权重；请先在权重页关闭动态开关。'; end
            elseif enabled
                app.DynamicWeightInfo.Text='只调打卡、压力角、转角及欠切惩罚；长度与转向变化保留基础。实际值只读，跨轮改善请看固定参照分。小窗口可滚动。';
            else
                app.DynamicWeightInfo.Text='静态评分：使用基础权重。训练实际权重有记录后才显示；缺记录不从当前输入推测。';
            end
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1') && ~strcmp(app.AlgorithmSelector.Value,'fmincon-interior-point-experimental-v1')
                app.Buttons(5).Enable='off'; app.Buttons(5).Tooltip='标准B样条目前仅支持约束优化（内点法），请切换优化方法。';
            end
        end
        function refreshTrainingControls(app)
            if isempty(app.TrainingFields), return; end
            editable=~app.Busy && ~app.SimulationMode && ~app.MapEditMode;
            automatic=strcmp(app.AlgorithmSelector.Value,'auto-tune-v1'); manual=editable && ~automatic;
            for k=1:9, app.TrainingFields(k).Enable=manual; end
            app.TrainingModel.Enable=manual; app.TrainingApplyButton.Enable=manual; app.TrainingResetButton.Enable=manual;
            app.ForceModelSwitchButton.Enable=manual;
            app.RestoreModelSwitchButton.Enable=editable && isfile(app.ModelSwitchBackupPath);
            if ~isempty(app.ModelSwitchBackupPath)
                app.ModelSwitchBackupInfo.Text=['完整备份：',app.ModelSwitchBackupPath];
                app.ModelSwitchBackupInfo.Tooltip=app.ModelSwitchBackupPath;
            end
            bezier=strcmp(app.TrainingModel.Value,'bezier-blend-independent-v1');
            app.TrainingFields(4).Enable=manual && bezier;
            constrained=startsWith(app.AlgorithmSelector.Value,'fmincon');
            if constrained, for k=6:9, app.TrainingFields(k).Enable='off'; end, end
            model='三次插值样条'; if strcmp(camdesign.routeModel(app.Project.params),'bezier-blend-independent-v1'), model='独立贝塞尔融合'; end
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1'), model=sprintf('标准%d次B样条（系数控制点）',app.Project.params.bspline.degree); end
            pending='已应用';
            if ~isfield(app.Project.params,'training'), pending='旧模式；本版默认未启用'; end
            if app.TrainingDirty, pending='待应用；旧图保留'; end
            description='切换画法/阶数会映射现有曲线，必要时自动增点；超出误差门限则保留原方案。';
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1')
                description=sprintf('标准B样条仅支持内点法；有效自由度%d。模型映射保留首末位置及切向，区分精确转换与容差内拟合。',2*size(app.Project.nodes,1)-6);
            end
            if constrained
                inputMM=app.TrainingFields(5).Value;
                nominalMM=max(.001,min(1,inputMM));
                description=[description,newline,sprintf('内点默认差分：输入 %.6g → 名义 %.6g mm（限0.001～1 mm，之后按TypicalX缩放）。学习、平滑与调节项禁用。',inputMM,nominalMM)];
            else, description=[description,newline,'梯度力=差分距离；步幅×学习率×阶梯衰减；平滑仅接受改善。']; end
            app.TrainingInfo.Text=sprintf('实际：%d 控制点 / %d 路线采样\n当前：%s；%s\n%s', ...
                size(app.Project.nodes,1),app.Project.params.samples,model,pending,description);
            if isfield(app.Project,'routeMapping')
                fit=app.Project.routeMapping;
                if all(isfield(fit,{'forced','withinTolerance','positionMaxMM','positionRMSMM','maxTangentErrorDeg'}))
                    label='容差内映射';
                    if fit.shapePreservationGuaranteed, label='精确保形'; end
                    if fit.forced, label='强制近似改形；保形未通过'; end
                    app.TrainingInfo.Text=[app.TrainingInfo.Text,newline,sprintf('上次映射：%s\n最大 %.6g mm；RMS %.6g mm；切向 %.6g°', ...
                        label,fit.positionMaxMM,fit.positionRMSMM,fit.maxTangentErrorDeg)];
                end
            elseif isfield(app.Project,'routeRebuild')
                app.TrainingInfo.Text=[app.TrainingInfo.Text,newline,'上次操作：按目标重建（显式改形，不是保形映射）。'];
            end
            app.TrainingShortcut.Text='打开训练设置（九项）';
            for k=1:2, app.AutoTuneFields(k).Enable=editable && automatic; end
            if automatic
                app.TrainingShortcut.Text='打开全自动设置（预算）';
                app.TrainingInfo.Text=['全自动锁定已应用画法：',model,'，不切换模型或阶数；只比较权重与适用训练配置。未应用输入须先处理。'];
                if app.TrainingDirty
                    app.TrainingShortcut.Text='处理待应用训练设置';
                    app.TrainingResetButton.Enable=editable;
                    app.TrainingInfo.Text='尚有待应用手动训练输入。请明确还原，或切回原方法应用后再启动全自动；这些输入不会自动丢弃。';
                end
            end
            if ~isempty(app.MethodSummary)
                app.MethodSummary.Text=sprintf('画法决定连线，优化方法负责改点；传动比 %.6g 固定执行，只能用户手改。',app.Project.params.gearRatio);
                if automatic, app.MethodSummary.Text='全自动锁定当前画法及阶数；只调六项权重与适用训练设置，车体、传动比、阈值及目标不变。'; end
            end
            app.refreshTrainingRuntime();
            app.refreshDynamicWeightControls();
            if strcmp(camdesign.routeModel(app.Project.params),'bspline-v1') && ~strcmp(app.AlgorithmSelector.Value,'fmincon-interior-point-experimental-v1')
                app.Buttons(5).Enable='off'; app.Buttons(5).Tooltip='标准B样条目前仅支持约束优化（内点法），请切换优化方法。';
            end
        end
        function applied=applyTraining(app,allowApproximate)
            if nargin<2, allowApproximate=false; end
            applied=false;
            if app.Busy || app.SimulationMode || app.MapEditMode || strcmp(app.AlgorithmSelector.Value,'auto-tune-v1'), return; end
            try
                if allowApproximate, app.backupModelSwitch('force'); end
                app.TrainingDirty=true;
                candidate=app.inputProject(true); changes=app.pendingTrainingChanges();
                [candidate,info]=camdesign.applyTrainingSettings(candidate,changes,app.AlgorithmSelector.Value,struct('AllowApproximate',logical(allowApproximate)));
                if isfield(candidate,'routeRebuild'), candidate=rmfield(candidate,'routeRebuild'); end
                candidate.routeMapping=info.fitInfo;
                if allowApproximate
                    try, result=camdesign.evaluate(candidate,true); calculationError='';
                    catch ex, result=[]; calculationError=[ex.identifier,' ',ex.message]; end
                else
                    result=camdesign.evaluate(candidate,true); calculationError='';
                end
            catch ex
                app.Status.Text=['训练设置未应用：',ex.message,' 当前图像为上次结果。'];
                app.message(app.Status.Text); app.refreshTrainingControls(); app.updateDiagnostics(); return;
            end
            app.publishManualRoute(candidate,result,calculationError); applied=true;
            if info.shapePreservationGuaranteed, mappingText='精确保形转换'; else, mappingText='几何容差内映射（非数学完全相同）'; end
            if info.forced, mappingText='强制近似切换（允许改形；保形门禁未通过）'; end
            app.message(sprintf('训练设置已应用：%s；实际 %d 个控制点，%d 个路线采样；目标列表及顺序未改。', ...
                mappingText,size(candidate.nodes,1),info.actualSamples));
            if isfield(info,'fitInfo')
                fit=info.fitInfo;
                app.message(sprintf('映射独立检查：最大位置误差 %.6g mm，RMS %.6g mm，全程切向差 %.6g°；控制点请求 %d → 实际 %d。这不是凸轮/实车精度验收。', ...
                    fit.positionMaxMM,fit.positionRMSMM,fit.maxTangentErrorDeg,fit.requestedControlPointCount,fit.actualControlPointCount));
            end
            if info.forced
                app.Status.Text=[app.Status.Text,newline,sprintf('强制近似改形：最大 %.6g mm / RMS %.6g mm / 切向 %.6g°；保形未通过，可从训练栏恢复备份。', ...
                    info.fitInfo.positionMaxMM,info.fitInfo.positionRMSMM,info.fitInfo.maxTangentErrorDeg)];
            end
        end
        function changes=pendingTrainingChanges(app)
            changes=struct('routeModel',app.TrainingModel.Value);
            for k=1:numel(app.TrainingFieldNames), changes.(app.TrainingFieldNames{k})=app.TrainingFields(k).Value; end
        end
        function rebuilt=rebuildCurrentRoute(app)
            rebuilt=false;
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            try
                assert(~strcmp(app.AlgorithmSelector.Value,'auto-tune-v1') || ~app.TrainingDirty, ...
                    'cam:TrainingPending','全自动锁定已应用画法；请先还原待应用输入或切回手动方法。');
                candidate=app.inputProject(true,true);
                [candidate,~]=camdesign.rebuildRoute(candidate,app.pendingTrainingChanges(),app.AlgorithmSelector.Value);
                app.backupModelSwitch('rebuild');
                try, result=camdesign.evaluate(candidate,true); calculationError='';
                catch ex, result=[]; calculationError=[ex.identifier,' ',ex.message]; end
            catch ex
                app.message(['重建未完成：',ex.identifier,' ',ex.message]); return;
            end
            app.publishManualRoute(candidate,result,calculationError); rebuilt=true;
            app.message('路线已从目标按所选画法重建（显式改形）；保留起点、目标顺序和物理输入，未经过旧路线保形映射。原状态已备份，项目尚未保存。');
        end
        function publishManualRoute(app,candidate,result,calculationError)
            app.clearPublishedAnalysis(); app.Project=candidate; app.Result=result;
            app.syncInputs();
            if isempty(result)
                app.renderUncomputedRoute();
                app.Status.Text=['新路线已应用；凸轮尚未计算：',calculationError,' 可编辑节点表、保存或重建后重算。'];
                app.Status.FontColor=[.65 .28 .08]; app.message(app.Status.Text);
            else, app.render(); end
            app.refreshControls();
        end
        function clearPublishedAnalysis(app)
            app.Result=[]; app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.OptimizationDirection=[];
            app.LastDisplayProject=[]; app.LastDisplayResult=[]; app.CamBaseProject=[]; app.CamBaseResult=[];
            app.CamInspectionRecord=[]; app.SelectedCrossing=0; app.CamFullLimits=[];
            app.SimulationReference=[]; app.SimulationResult=[]; app.clearActualClosure();
            app.DirectionStatus.Text='AI方向：无有效数据';
            for k=1:numel(app.CrossingViews)
                view=app.CrossingViews{k}; if ~isvalid(view.table), continue; end
                view.table.Data=zeros(0,5); view.label.Text='新路线尚未计算凸轮'; view.source.Enable='off'; view.zoom.Enable='off';
            end
            for axesHandle=[app.CamAxes,app.SteeringAxes]
                legend(axesHandle,'off'); cla(axesHandle); axesHandle.XLimMode='auto'; axesHandle.YLimMode='auto'; title(axesHandle,'新路线尚未计算');
            end
            if ~isempty(app.DetailCamAxes) && isgraphics(app.DetailCamAxes), cla(app.DetailCamAxes); end
        end
        function renderUncomputedRoute(app)
            p=app.Project.params; mode=camdesign.routeModel(p);
            if strcmp(mode,'cubic'), [~,~,station]=camdesign.routeSpline(app.Project.nodes,p); T=station(end);
            elseif strcmp(mode,'bspline-v1'), T=p.bspline.parameterLength;
            else, T=p.bezier.parameterLength; end
            curve=camdesign.routeGeometry(app.Project.nodes,p,linspace(0,T,min(4001,p.samples))');
            a=app.RouteAxes; legend(a,'off'); cla(a); hold(a,'on');
            rectangle(a,'Position',[p.bounds(1) p.bounds(3) diff(p.bounds(1:2)) diff(p.bounds(3:4))], ...
                'EdgeColor',[.4 .4 .4],'LineStyle','--','Tag','course-boundary');
            front=plot(a,curve(:,1),curve(:,2),'k-','LineWidth',1.5,'Tag','route-front-uncomputed');
            app.NodeLine=plot(a,app.Project.nodes(:,1),app.Project.nodes(:,2),'o-','Color',[.2 .6 .42],'MarkerSize',4,'Tag','route-nodes');
            targets=scatter(a,app.Project.targets(:,1),app.Project.targets(:,2),45,'k','o');
            hold(a,'off'); axis(a,'equal'); grid(a,'on'); app.fitRouteView(curve);
            title(a,'当前新路线 · 凸轮未计算'); xlabel(a,'场地 X / mm'); ylabel(a,'场地 Y / mm');
            app.RouteLines=[front app.NodeLine targets];
            legend(a,app.RouteLines,{'新前轮几何','节点/控制点','目标'},'Location','northwest','FontSize',9,'AutoUpdate','off');
            app.updateDiagnostics();
        end
        function backup=snapshotModelSwitchState(app)
            backup=struct('version','cam-app-model-switch-backup-v1','state',struct(),'inputs',struct());
            names={'Project','Result','History','HistoryProject','OptimizationInfo','OptimizationDirection', ...
                'SelectedTargetRow','SelectedNodeRow','TrainingDirty','ActualClosureReport','ActualClosureProject', ...
                'CamInspectionRecord','ScoreDisplayData','LastDisplayProject','LastDisplayResult','CamBaseProject','CamBaseResult', ...
                'CamFullLimits','SelectedCrossing','LegacyRatioNotice','DisplayedParameterFields'};
            for k=1:numel(names), backup.state.(names{k})=app.(names{k}); end
            for name={'ParamsTable','TargetsTable','NodesTable','WeightsTable'}
                backup.inputs.(name{1})=app.(name{1}).Data;
            end
            for name={'Mechanism','AutoRatio','DynamicWeightsEnabled','AlgorithmSelector','ScoreBasis','SimulationSource','TrainingModel'}
                backup.inputs.(name{1})=app.(name{1}).Value;
            end
            backup.inputs.TrainingFields=[app.TrainingFields.Value];
            backup.inputs.DynamicWeightFields=[app.DynamicWeightFields.Value]; backup.inputs.AutoTuneFields=[app.AutoTuneFields.Value];
            backup.status=app.Status.Text; backup.statusColor=app.Status.FontColor; backup.directionStatus=app.DirectionStatus.Text;
            backup.closureStatus=app.ActualClosureStatus.Text; backup.closureTable=app.ActualClosureTable.Data;
            backup.controlsTab=app.ControlsTabs.SelectedTab.Title; backup.resultsTab=app.ResultsTabs.SelectedTab.Title;
            backup.log=app.FullLog; backup.axesLimits=[app.RouteAxes.XLim app.RouteAxes.YLim;app.CamAxes.XLim app.CamAxes.YLim;app.SteeringAxes.XLim app.SteeringAxes.YLim];
            backup.axesModes={app.RouteAxes.XLimMode,app.RouteAxes.YLimMode;app.CamAxes.XLimMode,app.CamAxes.YLimMode;app.SteeringAxes.XLimMode,app.SteeringAxes.YLimMode};
            line=findobj(app.RouteAxes,'Tag','actual-closure-route'); backup.closureLine=[];
            if ~isempty(line), backup.closureLine=[line(1).XData(:),line(1).YData(:)]; end
        end
        function filename=backupModelSwitch(app,reason)
            app.updateDiagnostics();
            backup=app.snapshotModelSwitchState(); backup.reason=reason;
            folder=fullfile(fileparts(mfilename('fullpath')),'local','model_switch_backups');
            if ~isfolder(folder), mkdir(folder); end
            filename=[tempname(folder),'.mat']; save(filename,'backup','-v7');
            app.ModelSwitchBackupPath=filename;
            app.message(['完整状态已自动备份（项目、原结果、历史及待应用输入）：',filename]);
            app.refreshTrainingControls();
        end
        function restored=restoreModelSwitch(app,filename)
            restored=false;
            if app.Busy || app.SimulationMode || app.MapEditMode, return; end
            if nargin<2, filename=app.ModelSwitchBackupPath; end
            try
                loaded=load(filename,'backup'); backup=loaded.backup;
                app.validateModelSwitchBackup(backup);
                names=fieldnames(backup.state);
                for k=1:numel(names), app.(names{k})=backup.state.(names{k}); end
                app.syncInputs();
                if isempty(app.Result) && ~isempty(backup.state.LastDisplayResult)
                    % Pending edits may have invalidated Result while the
                    % last published plot and reference were still visible.
                    app.Project=backup.state.LastDisplayProject; app.Result=backup.state.LastDisplayResult; app.render();
                elseif isempty(app.Result), app.renderUncomputedRoute();
                else, app.render(); end
                for k=1:numel(names), app.(names{k})=backup.state.(names{k}); end
                if ~isempty(app.CamInspectionRecord), app.drawCamRecord(); end
                if ~isempty(backup.closureLine)
                    hold(app.RouteAxes,'on'); plot(app.RouteAxes,backup.closureLine(:,1),backup.closureLine(:,2),'m--','LineWidth',1.5,'Tag','actual-closure-route'); hold(app.RouteAxes,'off');
                end
                for name={'ParamsTable','TargetsTable','NodesTable','WeightsTable'}, app.(name{1}).Data=backup.inputs.(name{1}); end
                for name={'Mechanism','AutoRatio','DynamicWeightsEnabled','AlgorithmSelector','ScoreBasis','SimulationSource','TrainingModel'}
                    app.(name{1}).Value=backup.inputs.(name{1});
                end
                for k=1:9, app.TrainingFields(k).Value=backup.inputs.TrainingFields(k); end
                for k=1:4, app.DynamicWeightFields(k).Value=backup.inputs.DynamicWeightFields(k); end
                for k=1:2, app.AutoTuneFields(k).Value=backup.inputs.AutoTuneFields(k); end
                for k=1:numel(names), app.(names{k})=backup.state.(names{k}); end
                app.updateDiagnostics();
                app.TrainingDirty=backup.state.TrainingDirty; app.Status.Text=backup.status; app.Status.FontColor=backup.statusColor;
                app.DirectionStatus.Text=backup.directionStatus; app.ActualClosureStatus.Text=backup.closureStatus; app.ActualClosureTable.Data=backup.closureTable;
                for tab=app.ControlsTabs.Children', if strcmp(tab.Title,backup.controlsTab), app.ControlsTabs.SelectedTab=tab; break; end, end
                for tab=app.ResultsTabs.Children', if strcmp(tab.Title,backup.resultsTab), app.ResultsTabs.SelectedTab=tab; break; end, end
                app.RouteAxes.XLim=backup.axesLimits(1,1:2); app.RouteAxes.YLim=backup.axesLimits(1,3:4);
                app.CamAxes.XLim=backup.axesLimits(2,1:2); app.CamAxes.YLim=backup.axesLimits(2,3:4);
                app.SteeringAxes.XLim=backup.axesLimits(3,1:2); app.SteeringAxes.YLim=backup.axesLimits(3,3:4);
                axesList=[app.RouteAxes,app.CamAxes,app.SteeringAxes];
                for k=1:3, axesList(k).XLimMode=backup.axesModes{k,1}; axesList(k).YLimMode=backup.axesModes{k,2}; end
                app.ModelSwitchBackupPath=filename; app.refreshControls();
                if numel(app.FullLog)<numel(backup.log) || ~isequal(app.FullLog(1:numel(backup.log)),backup.log)
                    app.FullLog=[backup.log;app.FullLog];
                end
                app.message(['已恢复完整切换前状态（含待应用输入）；切换/恢复日志保留。备份：',filename]); restored=true;
            catch ex, app.message(['恢复未完成：',ex.identifier,' ',ex.message]); end
        end
        function validateModelSwitchBackup(app,backup)
            template=app.snapshotModelSwitchState(); required=fieldnames(template);
            assert(isstruct(backup) && isscalar(backup) && all(isfield(backup,required)) ...
                && strcmp(backup.version,'cam-app-model-switch-backup-v1'), ...
                'cam:ModelSwitchBackup','备份缺少完整状态字段或版本不受支持；当前状态保留。');
            assert(isstruct(backup.state) && isscalar(backup.state) && isequal(sort(fieldnames(backup.state)),sort(fieldnames(template.state))) ...
                && isstruct(backup.inputs) && isscalar(backup.inputs) && isequal(sort(fieldnames(backup.inputs)),sort(fieldnames(template.inputs))), ...
                'cam:ModelSwitchBackup','备份缺少项目、结果或待应用输入字段；当前状态保留。');
            camdesign.validateProject(backup.state.Project);
            if ~isempty(backup.state.LastDisplayProject), camdesign.validateProject(backup.state.LastDisplayProject); end
            for name={'Result','LastDisplayResult','CamBaseResult'}
                value=backup.state.(name{1});
                assert(isempty(value) || (isstruct(value) && isscalar(value) && all(isfield(value,{'route','cam','metrics'}))), ...
                    'cam:ModelSwitchBackup','备份中的原计算结果不完整；当前状态保留。');
            end
            for name={'ParamsTable','TargetsTable','NodesTable','WeightsTable'}
                value=backup.inputs.(name{1}); columns=2; if strcmp(name{1},'WeightsTable'), columns=3; end
                assert((isnumeric(value) || iscell(value)) && ismatrix(value) && size(value,2)==columns, ...
                    'cam:ModelSwitchBackup','备份表格结构无效；当前状态保留。');
            end
            for name={'Mechanism','AlgorithmSelector','ScoreBasis','SimulationSource','TrainingModel'}
                assert(ismember(backup.inputs.(name{1}),app.(name{1}).ItemsData), ...
                    'cam:ModelSwitchBackup','备份选择值无效；当前状态保留。');
            end
            for name={'TrainingFields','DynamicWeightFields','AutoTuneFields'}
                value=backup.inputs.(name{1}); count=numel(app.(name{1}));
                assert(isnumeric(value) && isreal(value) && numel(value)==count && all(isfinite(value)), ...
                    'cam:ModelSwitchBackup','备份训练输入结构无效；当前状态保留。');
            end
            assert(isnumeric(backup.axesLimits) && isequal(size(backup.axesLimits),[3 4]) ...
                && all(isfinite(backup.axesLimits),'all') && all(backup.axesLimits(:,2)>backup.axesLimits(:,1)) ...
                && all(backup.axesLimits(:,4)>backup.axesLimits(:,3)) && iscell(backup.log), ...
                'cam:ModelSwitchBackup','备份视图或日志结构无效；当前状态保留。');
            assert(iscell(backup.axesModes) && isequal(size(backup.axesModes),[3 2]) ...
                && all(ismember(backup.axesModes,{'auto','manual'}),'all'), ...
                'cam:ModelSwitchBackup','备份坐标轴模式无效；当前状态保留。');
        end
        function action(app,name,filename)
            % Optional explicit path uses the same import/save action as the
            % buttons, allowing batch contracts without native file dialogs.
            if nargin<3, filename=''; end
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
                        app.rebuildCurrentRoute();
                    case 'import'
                        if isempty(filename)
                            [f,d]=uigetfile('*.mat','导入本项目或原软件 MAT'); if isequal(f,0), return; end
                            filename=fullfile(d,f);
                        end
                        try
                            [next,notes]=camdesign.importProject(filename);
                        catch importError
                            if ~strcmp(importError.identifier,'cam:UnsupportedMechanism'), rethrow(importError); end
                            choice=uiconfirm(app.Figure, ...
                                [importError.message,newline,'是否沿用点位和车体参数另建方案？原文件保持不变。'], ...
                                '原文件转向机构尚未实现','Options',{'另建齿条方案','另建平推方案','取消'}, ...
                                'DefaultOption',3,'CancelOption',3);
                            if strcmp(choice,'取消'), return; end
                            if strcmp(choice,'另建齿条方案'), mechanism='rack'; else, mechanism='flat'; end
                            [next,notes]=camdesign.importProject(filename,MechanismOverride=mechanism);
                        end
                        app.Project=next; app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.OptimizationDirection=[];
                        app.syncInputs(); app.calculate(); for k=1:numel(notes), app.message(notes{k}); end
                    case 'save'
                        app.readInputs();
                        if isempty(filename)
                            [f,d]=uiputfile('*.mat','保存复现项目','cam_project.mat'); if isequal(f,0), return; end
                            filename=fullfile(d,f);
                        end
                        camdesign.saveProject(app.Project,filename); app.message('项目已保存。');
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
            if strcmp(app.AlgorithmSelector.Value,'auto-tune-v1'), app.ControlsTabs.SelectedTab=app.AutoTuneTab; end
            cleanup=onCleanup(@()app.finishBusy());
            app.OptimizationDirection=[]; app.OptimizationInfo=[];
            app.History=[]; app.HistoryProject=[]; app.updateDiagnostics();
            [project,history,info]=camdesign.optimize(app.Project,@app.optimizationUpdate,app.AlgorithmSelector.Value);
            app.Project=project; app.History=history; app.HistoryProject=project; app.OptimizationDirection=[]; app.OptimizationInfo=info;
            app.syncInputs(); app.calculate();
            if isfield(info,'fullAuto') && info.fullAuto
                app.finishAutoTune(info); return;
            end
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
                    || ~isfield(m,'returnAngleSatisfied') || ~m.returnAngleSatisfied ...
                    || ~isfield(m,'visitOrderSatisfied') || ~m.visitOrderSatisfied, verdict='未达标候选'; end
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
            automatic=~isempty(history) && isfield(history,'autoStage');
            if automatic && isfield(history,'comparisonGrid')
                grid=history(end).comparisonGrid; project.params.samples=grid(1); project.params.camSamples=grid(2);
            end
            app.Project=project; app.History=history; app.HistoryProject=project; app.NodesTable.Data=project.nodes;
            if automatic
                p=project.params;
                values=cellfun(@(name)p.(name),app.DisplayedParameterFields,'UniformOutput',false);
                app.ParamsTable.Data(:,2)=values(:); app.TrainingModel.Value=app.trainingModelValue(p);
            end
            app.OptimizationDirection=history(end);
            app.Result=camdesign.evaluate(project,false); app.render();
            if automatic
                app.Status.Text=[strrep(app.autoProgressText(history(end)),newline,'；'),sprintf('\n统一网格固定参照 %.5g；本组实际分 %.5g；验收待最终记录。',history(end).score,history(end).dynamicScore)];
                drawnow; stop=app.StopRequested; return;
            end
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
        function text=autoProgressText(app,h)
            stages=struct('initial','准备配置','search','配置搜索','polish','约束精修','complete','搜索结束');
            stage=char(h.autoStage); if isfield(stages,stage), stage=stages.(stage); end
            if strcmp(h.autoStage,'initial')
                text=sprintf('准备配置，尚未开始分组\n累计%d轮；预算上限%d轮',h.iteration,h.autoTotalBudget);
            elseif strcmp(h.autoStage,'complete')
                selected='保留初始配置'; if h.autoTrial>0, selected=sprintf('获选配置组%d',h.autoTrial); end
                text=sprintf('%s · %s\n累计%d轮；预算上限%d轮',stage,selected,h.iteration,h.autoTotalBudget);
            else
                text=sprintf('%s · 组%d/%d\n本组%d/%d轮；累计%d轮（上限%d）',stage,h.autoTrial,h.autoTrialCount, ...
                    h.trialIteration,h.trialBudget,h.iteration,h.autoTotalBudget);
            end
        end
        function text=recordNumber(app,record,name)
            text='未记录';
            if isstruct(record) && isfield(record,name) && isnumeric(record.(name)) && isscalar(record.(name)) && isfinite(record.(name))
                text=sprintf('%.6g',record.(name));
            end
        end
        function [text,color,passed]=autoTuneGrade(app,info)
            color=[.65 .28 .08]; passed=false;
            if ~isstruct(info) || ~all(isfield(info,{'fullAuto','verifiedFeasible','convergencePassed'})) || ~info.fullAuto
                text='全自动验收未记录；评分下降不代表通过。'; return;
            end
            passed=isequal(info.verifiedFeasible,true) && isequal(info.convergencePassed,true);
            verdict='验收未通过'; if passed, verdict='记录的验收标志通过'; end
            errors=sprintf('轮廓差：未记录\n理论回推：未记录');
            if isfield(info,'assessment') && isfield(info.assessment,'numericalChecks')
                numeric=info.assessment.numericalChecks;
                errors=sprintf('轮廓差 %s mm\n理论回推 %s mm',app.recordNumber(numeric,'camMaxDifferenceMM'),app.recordNumber(numeric,'inverseFrontMaxErrorMM'));
                if ~isfield(numeric,'passed') || ~isequal(numeric.passed,true), passed=false; verdict='数值精度检查未通过或缺少记录'; end
                if passed, verdict='数值模型验收通过'; color=[.14 .40 .28]; end
            elseif passed
                passed=false; verdict='旧记录标志通过，新增精度未验证';
            end
            text=sprintf('%s\n%s\n仅数值模型；实车/加工待复核。',verdict,errors);
        end
        function refreshAutoTuneDisplay(app)
            if isempty(app.AutoTuneProgress), return; end
            matched=~isempty(app.HistoryProject) && isequaln(app.HistoryProject,app.CamBaseProject);
            info=[]; if matched, info=app.OptimizationInfo; end
            prefix=''; if ~matched || ~app.diagnosticsAreCurrent(), prefix='历史 · '; end
            app.AutoTuneParameters.Data=cell(0,2);
            if ~isempty(app.History) && isfield(app.History,'autoStage')
                h=app.History(end); app.AutoTuneProgress.Text=[prefix,app.autoProgressText(h)];
                rows={'真实训练采样',app.recordNumber(h,'trainingSamples');'真实凸轮训练采样',app.recordNumber(h,'trainingCamSamples')};
                if isfield(h,'comparisonGrid'), rows(end+1,:)={'统一展示网格',mat2str(h.comparisonGrid)}; end
                if ~isempty(app.HistoryProject)
                    model='三次样条'; if strcmp(camdesign.routeModel(app.HistoryProject.params),'bezier-blend-independent-v1'), model='独立贝塞尔'; end
                    rows(end+1,:)={'记录路线模型',model};
                end
                if isfield(h,'trainingControls') && isstruct(h.trainingControls)
                    labels={'组内轮数设置','控制点数','名义插值/段','贝塞尔阶数','差分设置/mm','学习率设置','平滑设置','调节间隔','调节指数'};
                    for k=1:numel(app.TrainingFieldNames)
                        rows(end+1,:)={labels{k},app.recordNumber(h.trainingControls,app.TrainingFieldNames{k})};
                    end
                end
                if strcmp(h.autoStage,'polish')
                    rows(end+1,:)={'内点名义差分/mm',app.recordNumber(h,'nominalDifferenceStepMM')};
                elseif strcmp(h.autoStage,'search')
                    rows(end+1,:)={'记录探测距离/mm',app.recordNumber(h,'probeMM')};
                end
                stepLabel='配置步幅/mm';
                if strcmp(h.autoStage,'search'), stepLabel='本轮计划步幅/mm';
                elseif strcmp(h.autoStage,'polish'), stepLabel='搜索步幅/精修不用'; end
                rows(end+1,:)={stepLabel,app.recordNumber(h,'scheduledStepMM')};
                app.AutoTuneParameters.Data=rows;
                app.AutoTuneParameters.ColumnName={[prefix,'本组运行记录'],'实际值'};
            else
                app.AutoTuneProgress.Text='全自动尚未启动；设置预算后点击“迭代优化”。';
                if isstruct(info) && isfield(info,'fullAuto') && info.fullAuto
                    app.AutoTuneProgress.Text=sprintf('%s全自动已有结束记录\n累计%d轮；预算上限%d轮；本组历史明细未记录。',prefix,info.iterations,info.requestedIterations);
                end
                if app.TrainingDirty, app.AutoTuneProgress.Text='尚有待应用手动训练输入；请先还原或切回原方法应用。'; end
            end
            [grade,color]=app.autoTuneGrade(info); app.AutoTuneVerdict.Text=[prefix,grade]; app.AutoTuneVerdict.FontColor=color;
            settings=camdesign.autoTuneSettings(app.Project.params);
            if isempty(info) && ~isempty(settings.selectedWeights)
                app.AutoTuneVerdict.Text=['已保存获选权重 ',mat2str(settings.selectedWeights,4),newline,'本会话无匹配验收记录，不能确认通过。'];
            end
        end
        function finishAutoTune(app,info)
            [grade,color,passed]=app.autoTuneGrade(info); app.Status.FontColor=color;
            verdict='未通过全部验收'; if passed, verdict='记录验收通过，仍待外部验证'; end
            reason='配置比较结束'; if strcmp(info.reason,'user_stop'), reason='用户停止，保留当前候选'; end
            app.Status.Text=sprintf('全自动：%s · %s\n累计%d轮（预算上限%d）；精度误差与最终门禁见全自动页。', ...
                reason,verdict,info.iterations,info.requestedIterations);
            app.message(sprintf('全自动 %s；累计%d轮，预算上限%d；%d次评价，%.3f秒。',reason,info.iterations,info.requestedIterations,info.evaluations,info.elapsedSeconds));
            app.message(['全自动验收：',strrep(grade,newline,'；')]);
            app.message(sprintf('统一网格固定参照分 %.6g；获选权重实际分 %.6g。评分下降不能代替几何或收敛验收。',info.finalMetrics.score,info.finalDynamicScore));
            for k=1:numel(info.trials)
                trial=info.trials(k);
                app.message(sprintf('配置组%d [%s]：实际%d轮 / 请求上限%d轮；原因 %s。', ...
                    trial.trial,trial.stage,trial.iterations,trial.requestedIterations,trial.reason));
                if strcmp(trial.reason,'invalid_configuration') && ~isempty(trial.errorMessage)
                    app.message(['配置未执行/失败：',trial.errorMessage]);
                end
            end
            for k=1:numel(info.remainingConstraints), app.message(['全自动剩余问题：',info.remainingConstraints{k}]); end
            app.updateDiagnostics();
        end
        function openTraining(app)
            app.ControlsTabs.SelectedTab=app.TrainingTab;
            if strcmp(app.AlgorithmSelector.Value,'auto-tune-v1') && ~app.TrainingDirty, app.ControlsTabs.SelectedTab=app.AutoTuneTab; end
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
            app.AutoTuneParameters.ColumnWidth={width-138,100};
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
                actualLabel='动态'; if strcmp(data.weightMode,'auto-tuned-v1'), actualLabel='实际'; end
                app.ScoreSummary.Text=sprintf('固定参照 %.5g · %s %s\n%s · %d/%d',data.total,actualLabel,dynamicText,data.state,data.grid);
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
                    if strcmp(data.weightMode,'auto-tuned-v1')
                        source='全自动获选权重';
                        if data.autoTrial>0, source=sprintf('全自动配置组%d的权重',data.autoTrial);
                        elseif strcmp(data.autoStage,'initial'), source='全自动初始候选权重'; end
                    end
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
            if strcmp(data.weightMode,'auto-tuned-v1') && ~strcmp(app.ScoreBasis.Value,'reference') && ~isempty(tableRows)
                contributionHeading='实际贡献'; viewStatus='本组实际权重';
                if strcmp(data.autoStage,'complete'), viewStatus='实际获选权重'; end
            end
            if ~isfinite(data.total), viewStatus='待计算 / 未记录'; end
            app.ScoreViewStatus.Text=[weightState,' · ',viewStatus];
            for k=1:numel(app.ScoreViews)
                view=app.ScoreViews{k}; if ~isvalid(view.table), continue; end
                view.table.Data=tableRows;
                view.table.ColumnName={'本版评分项','基础项',weightHeading,contributionHeading};
                view.table.Tooltip=sprintf('%s 视图：%s；来源：%s，网格%d/%d，版本%s。%s。', ...
                    data.description,viewStatus,data.state,data.grid,data.scoreVersion,data.weightSource);
                referenceTitle='固定参照分'; if data.unifiedHistory, referenceTitle='固定参照分（统一网格）'; end
                app.plotDiagnosticSeries(view.scoreAxes,data.scoreX,data.scoreY, ...
                    [referenceTitle,' · ',data.historyState],data.xLabel,'固定参照分','尚无迭代记录');
                objectiveTitle='内点目标（独立尺度）';
                if startsWith(data.historyState,'历史'), objectiveTitle=['历史 · ',objectiveTitle]; end
                if ~isempty(data.objectiveY)
                    app.plotDiagnosticSeries(view.objectiveAxes,data.objectiveX,data.objectiveY, ...
                        objectiveTitle,data.xLabel,'独立目标值','尚无记录');
                else
                    dynamicTitle='动态搜索分（权重会变）';
                    if data.unifiedHistory, dynamicTitle='本组实际分（统一网格，组间权重不同）'; end
                    app.plotDiagnosticSeries(view.objectiveAxes,data.dynamicX,data.dynamicY, ...
                        [dynamicTitle,' · ',data.historyState],data.xLabel,'实际分（非固定尺度）','未启用实际权重记录 / 缺少记录');
                end
            end
            app.updateCrossingViews(); app.refreshTrainingRuntime(); app.refreshAutoTuneDisplay();
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
                app.TrainingRuntime.Text='尚未开始训练；编辑初始设置后点击“应用训练设置”。';
                if strcmp(app.AlgorithmSelector.Value,'auto-tune-v1'), app.TrainingRuntime.Text='全自动尚未开始；在全自动页设置预算后点击“迭代优化”。'; end
                return;
            end
            h=app.History(end); state='本次'; iteration='未记录';
            if isfield(h,'iteration'), iteration=sprintf('%d',h.iteration); end
            if ~app.diagnosticsAreCurrent() || isempty(app.HistoryProject) || ~isequaln(app.HistoryProject,app.Project), state='上次'; end
            if isfield(h,'autoStage')
                controls=struct(); if isfield(h,'trainingControls'), controls=h.trainingControls; end
                app.TrainingRuntime.Text=sprintf('%s全自动：%s\n真实训练采样%s；控制点%s；差分设置%s mm', ...
                    state,strrep(app.autoProgressText(h),newline,'；'),app.recordNumber(h,'trainingSamples'), ...
                    app.recordNumber(controls,'controlPointCount'),app.recordNumber(controls,'gradientForce'));
                return;
            end
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
            app.SimulationSource.Enable=editable;
            app.ActualClosureButton.Enable=editable && ~app.TrainingDirty;
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
