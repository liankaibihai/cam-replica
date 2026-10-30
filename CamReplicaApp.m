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
        Mechanism
        AutoRatio
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
    end
    properties (Access=private)
        MapEditReference = []
        MapEditNodes = []
        NodeLine = []
        SelectedNodeMarker = []
        NodeMoveGuide = []
        RouteLines = []
        DisplayedParameterFields = {}
        ParameterFields = {'wheelDiameter','gearRatio','lever','rollerRadius','referenceDiameter', ...
            'thickness','driveX','driveY','drivenX','drivenY','sensorX','sensorY','headingDeg', ...
            'startSteeringDeg','returnAngleDeg','maxSteeringDeg','maxPressureDeg','hitTolerance', ...
            'iterations','stepMM','gradientProbeMM','samples','camSamples'}
        ParameterLabels = {'主动轮直径 / mm','请求传动比（轮/凸轮）','转向偏距 c / mm', ...
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
                'Position',[70 60 1320 860],'Visible',visibility,'Color',[.95 .96 .98]);
            app.Figure.CloseRequestFcn=@(~,~)app.closeRequested();
            app.Figure.WindowKeyPressFcn=@(~,event)app.routeEditorKey(event);
            root=uigridlayout(app.Figure,[4 2],'RowHeight',{34,36,'1x',76}, ...
                'ColumnWidth',{280,'1x'},'Padding',[12 8 12 8], ...
                'RowSpacing',6,'ColumnSpacing',10);
            titleBar=uigridlayout(root,[1 2],'ColumnWidth',{'1x',270},'Padding',[0 0 0 0]);
            titleBar.Layout.Row=1; titleBar.Layout.Column=[1 2];
            uilabel(titleBar,'Text','工创赛凸轮设计  /  路线、机构与几何校验', ...
                'FontSize',20,'FontWeight','bold','FontColor',[.12 .20 .30]);
            app.AlgorithmSelector=uidropdown(titleBar, ...
                'Items',{'峰值梯度（独立算法）','四方向加权 + 平滑（视频启发实验）','内点法非线性约束（实验）'}, ...
                'ItemsData',{'peak-gradient-v2','video-four-direction-v1','fmincon-interior-point-experimental-v1'},'Value','peak-gradient-v2', ...
                'ValueChangedFcn',@(~,~)app.refreshTrainingControls());
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
            side=uigridlayout(root,[3 1],'RowHeight',{30,28,'1x'},'Padding',[0 0 0 0]);
            side.Layout.Row=3; side.Layout.Column=1;
            app.Mechanism=uidropdown(side,'Items',{'齿条：h = cδ','平推：h = c tanδ'}, ...
                'ItemsData',{'rack','flat'},'Value','rack','ValueChangedFcn',@(~,~)app.invalidate());
            app.AutoRatio=uicheckbox(side,'Text','工作段过长时自动增大传动比','Value',true, ...
                'ValueChangedFcn',@(~,~)app.invalidate());
            tabs=uitabgroup(side);
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
            t=uitab(tabs,'Title','权重'); g=uigridlayout(t,[1 1],'Padding',[0 0 0 0]);
            app.WeightsTable=uitable(g,'ColumnName',{'独立目标项','权重'},'ColumnEditable',[false true], ...
                'ColumnWidth',{180,65},'ColumnFormat',{'char','numeric'},'RowName',{},'CellEditCallback',@(~,~)app.invalidate());
            t=uitab(tabs,'Title','训练');
            training=uigridlayout(t,[12 2],'RowHeight',[{30},repmat({26},1,9),{'1x',32}], ...
                'ColumnWidth',{170,'1x'},'Padding',[4 2 4 2],'ColumnSpacing',2,'RowSpacing',4);
            app.TrainingModel=uidropdown(training,'Items',{'三次插值样条（本版）','独立贝塞尔融合（实验）'}, ...
                'ItemsData',{'cubic','bezier-blend-independent-v1'},'ValueChangedFcn',@(~,~)app.markTrainingDirty());
            app.TrainingModel.Layout.Row=1; app.TrainingModel.Layout.Column=[1 2];
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
                label.Layout.Row=k+1; label.Layout.Column=1;
                app.TrainingFields(k)=uieditfield(training,'numeric','Value',1,'FontSize',11, ...
                    'Tooltip',tips{k},'ValueChangedFcn',@(~,~)app.markTrainingDirty());
                app.TrainingFields(k).Layout.Row=k+1; app.TrainingFields(k).Layout.Column=2;
            end
            app.TrainingInfo=uilabel(training,'Text','','FontSize',11,'WordWrap','on','VerticalAlignment','top');
            app.TrainingInfo.Layout.Row=11; app.TrainingInfo.Layout.Column=[1 2];
            app.TrainingApplyButton=uibutton(training,'Text','应用训练设置','FontSize',11,'ButtonPushedFcn',@(~,~)app.applyTraining());
            app.TrainingApplyButton.Layout.Row=12; app.TrainingApplyButton.Layout.Column=1;
            app.TrainingResetButton=uibutton(training,'Text','还原','FontSize',11,'ButtonPushedFcn',@(~,~)app.syncTrainingInputs());
            app.TrainingResetButton.Layout.Row=12; app.TrainingResetButton.Layout.Column=2;
            charts=uigridlayout(root,[2 2],'ColumnWidth',{'1.35x','1x'},'RowHeight',{'1x','2.7x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',12,'RowSpacing',10);
            charts.Layout.Row=3; charts.Layout.Column=2;
            routePanel=uigridlayout(charts,[2 1],'RowHeight',{32,'1x'},'Padding',[0 0 0 0]);
            routePanel.Layout.Row=[1 2]; routePanel.Layout.Column=1;
            editorBar=uigridlayout(routePanel,[1 4],'ColumnWidth',{76,76,80,'1x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',5);
            app.MapEditButton=uibutton(editorBar,'Text','地图编辑','ButtonPushedFcn',@(~,~)app.beginRouteEditing());
            app.ConfirmNodeButton=uibutton(editorBar,'Text','确认落点','Enable','off','ButtonPushedFcn',@(~,~)app.confirmRouteNode());
            app.CancelNodeButton=uibutton(editorBar,'Text','取消 / Esc','Enable','off','ButtonPushedFcn',@(~,~)app.cancelRouteEditing());
            app.MapEditHelp=uilabel(editorBar,'Text','独立三次样条路线节点','FontSize',11);
            app.RouteAxes=uiaxes(routePanel);
            app.RouteAxes.ButtonDownFcn=@(source,~)app.routeMapClick(source.CurrentPoint(1,1:2),source,app.Figure.SelectionType);
            app.SteeringAxes=uiaxes(charts); app.SteeringAxes.Layout.Row=1; app.SteeringAxes.Layout.Column=2;
            app.CamAxes=uiaxes(charts); app.CamAxes.Layout.Row=2; app.CamAxes.Layout.Column=2;
            bottom=uigridlayout(root,[2 1],'RowHeight',{36,'1x'},'Padding',[0 0 0 0]);
            bottom.Layout.Row=4; bottom.Layout.Column=[1 2];
            statusRow=uigridlayout(bottom,[1 2],'ColumnWidth',{'1x',190},'Padding',[0 0 0 0]);
            app.Status=uilabel(statusRow,'Text','准备就绪','FontSize',12,'FontWeight','bold','WordWrap','on');
            app.DirectionStatus=uilabel(statusRow,'Text','AI方向：无有效数据', ...
                'FontSize',10,'FontColor',[.4 .4 .4],'WordWrap','on');
            app.Log=uitextarea(bottom,'Editable','off','FontSize',12);
            app.syncInputs(); app.calculate();
            app.message('v0.2：齿条/平推、固定凸轮调参；独立样条与数值优化。尚未完成原版点集或实车对照。');
        end
        function syncInputs(app)
            p=app.Project.params;
            indices=1:numel(app.ParameterFields);
            if app.SimulationMode, indices=[1 2 3 5 7 8 10 11 12 13]; end
            app.DisplayedParameterFields=app.ParameterFields(indices);
            labels=app.ParameterLabels(indices);
            if app.SimulationMode, labels{2}='实际传动比（轮/凸轮）'; end
            values=cellfun(@(k)p.(k),app.DisplayedParameterFields,'UniformOutput',false);
            app.ParamsTable.Data=[labels(:),values(:)];
            app.TargetsTable.Data=app.Project.targets; app.NodesTable.Data=app.Project.nodes;
            app.updateNodeInfo();
            app.Mechanism.Value=p.mechanism; app.AutoRatio.Value=p.autoRatio;
            labels={'有序打卡偏差','前轮路线长度','转向变化率','压力角超限','前轮转角超限','包络欠切风险'};
            app.WeightsTable.Data=[labels(:),num2cell(p.weights(:))];
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
            p.mechanism=app.Mechanism.Value; p.autoRatio=app.AutoRatio.Value;
            p.weights=cellfun(@double,app.WeightsTable.Data(:,2))';
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
            a=app.CamAxes; cla(a); hold(a,'on');
            camLines=gobjects(1,4);
            camLines(1)=plot(a,c.pitch(:,1),c.pitch(:,2),'Color',[.2 .4 .75],'LineWidth',1.2);
            camLines(2)=plot(a,c.actual(:,1),c.actual(:,2),'Color',[.85 .25 .20],'LineWidth',1.5);
            camLines(3)=plot(a,NaN,NaN,'--','Color',[.5 .5 .5],'LineWidth',1.5);
            returnPoints=c.actual(~c.workingMask,:);
            if ~isempty(returnPoints), set(camLines(3),'XData',returnPoints(:,1),'YData',returnPoints(:,2)); end
            reference=p.referenceDiameter/2;
            if app.SimulationMode, reference=app.SimulationReference.project.params.referenceDiameter/2; end
            angle=linspace(0,2*pi,257);
            camLines(4)=plot(a,reference*cos(angle),reference*sin(angle),':','Color',[.2 .2 .2],'LineWidth',1.1,'Tag','zero-reference-circle');
            camLabels={'理论','实际','回程','零位圆 d/2'};
            if isfield(app.Result,'intersectionPoints') && ~isempty(app.Result.intersectionPoints)
                points=app.Result.intersectionPoints;
                camLines(5)=plot(a,points(:,1),points(:,2),'ro','LineStyle','none','MarkerSize',8,'LineWidth',1.6, ...
                    'HitTest','off','PickableParts','none','Tag','cam-self-intersections');
                camLabels{5}='实际自交';
            end
            plot(a,0,0,'k+','MarkerSize',7,'Tag','cam-center');
            hold(a,'off'); axis(a,'equal'); grid(a,'on'); xlabel(a,'X / mm'); ylabel(a,'Y / mm');
            extent=1.25*max([vecnorm(c.pitch,2,2);vecnorm(c.actual,2,2);reference]);
            xlim(a,[-extent extent]); ylim(a,[-extent extent]);
            title(a,'凸轮（含回程）');
            legend(a,camLines,camLabels, ...
                'Location','northeast','NumColumns',1,'FontSize',9,'IconColumnWidth',18,'AutoUpdate','off');
            m=app.Result.metrics;
            [~,trajectory]=camdesign.trajectoryBounds(r,p.bounds);
            crossText=sprintf('%g',m.intersectionCount);
            if ~m.geometryChecked, crossText='未完整检查'; end
            app.Status.Text=sprintf('最大打卡偏差 %.2f mm    最大压力角 %.1f°    目标函数 %.4f    轮廓自交 %s    五点中心出界 %.6g mm', ...
                m.maxHitError,m.maxPressureDeg,m.score,crossText,trajectory.maximumOutsideMM);
            if m.maxPressureDeg>p.maxPressureDeg || m.minUndercutMargin<=0 || m.maxHitError>p.hitTolerance || m.intersectionCount>0 || ~trajectory.satisfied
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
        end
        function fitRouteView(app,extraPoints)
            r=app.Result.route; bounds=app.Project.params.bounds;
            points=[r.front;r.sensor;r.drive;r.driven;app.Project.nodes;app.Project.targets];
            if nargin>1, points=[points;extraPoints]; end
            lower=min([points;bounds([1 3])],[],1);
            upper=max([points;bounds([2 4])],[],1);
            padding=.04*[diff(bounds(1:2)) diff(bounds(3:4))];
            xlim(app.RouteAxes,[lower(1)-padding(1) upper(1)+padding(1)]);
            ylim(app.RouteAxes,[lower(2)-padding(2) upper(2)+padding(2)]);
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
            app.Project.params.gearRatio=app.Result.cam.effectiveRatio;
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
                        app.Project=next;
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
            [project,history,info]=camdesign.optimize(app.Project,@app.optimizationUpdate,app.AlgorithmSelector.Value);
            app.Project=project; app.History=history; app.OptimizationDirection=[]; app.OptimizationInfo=info;
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
                    || m.minUndercutMargin<=0 || m.intersectionCount>0 || ~trajectory.satisfied, verdict='未达标候选'; end
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
            app.message(sprintf('%s，%d/%d 轮，原因：%s；%.3f 秒，%d 次评价；目标 %.6g → %.6g。', ...
                info.algorithm,info.iterations,info.requestedIterations,text,info.elapsedSeconds,info.evaluations,history(1).score,history(end).score));
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
        end
        function stop=optimizationUpdate(app,iteration,project,history)
            app.Project=project; app.NodesTable.Data=project.nodes;
            app.OptimizationDirection=history(end);
            app.Result=camdesign.evaluate(project,false); app.render();
            if strcmp(history(end).event,'searching')
                app.Status.Text=sprintf('搜索第 %d/%d 轮（已完成 %d 轮）    当前目标 %.5f    最大偏差 %.2f mm', ...
                    history(end).directionIteration,project.params.iterations,iteration,history(end).score,history(end).maxHitError);
            else
                app.Status.Text=sprintf('已完成 %d/%d 轮    当前目标 %.5f    最大偏差 %.2f mm', ...
                    iteration,project.params.iterations,history(end).score,history(end).maxHitError);
            end
            if isfield(history,'objective')
                app.Status.Text=sprintf('实验约束 %d/%d 轮    求解目标 %.5g    最大归一化违规 %.5g；尚待加密验收', ...
                    iteration,project.params.iterations,history(end).objective,history(end).maxConstraintViolation);
            end
            drawnow; stop=app.StopRequested;
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
            app.Mechanism.Enable=editable; app.AutoRatio.Enable=editable;
            app.AlgorithmSelector.Enable=editable;
            for k=1:numel(app.PointButtons), app.PointButtons(k).Enable=editable; end
            app.RefineRouteButton.Enable=editable;
            app.ParamsTable.ColumnEditable=[false ~app.Busy && ~app.MapEditMode];
            app.TargetsTable.ColumnEditable=[editable editable];
            app.NodesTable.ColumnEditable=[editable editable]; app.WeightsTable.ColumnEditable=[false editable];
            app.MapEditButton.Enable=editable;
            app.ConfirmNodeButton.Enable=app.MapEditMode && app.MapEditSelection>0 && ~app.Busy && ~app.SimulationMode;
            app.CancelNodeButton.Enable=app.MapEditMode && ~app.Busy && ~app.SimulationMode;
            app.refreshTrainingControls();
        end
        function finishBusy(app)
            app.Busy=false;
            if isvalid(app.Figure), app.setBusy(false); end
            if app.CloseAfterStop && isvalid(app.Figure), delete(app.Figure); end
        end
        function closeRequested(app)
            if app.Busy, app.StopRequested=true; app.CloseAfterStop=true;
            else
                if app.MapEditMode, app.cancelRouteEditing(); end
                delete(app.Figure);
            end
        end
        function message(app,text)
            old=app.Log.Value; if ischar(old), old={old}; end
            app.Log.Value=[old(max(1,end-25):end);{char(text)}];
        end
    end
end
