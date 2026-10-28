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
        StopRequested = false
        Busy = false
        CloseAfterStop = false
        SelectedTargetRow = 1
        SelectedNodeRow = 1
        PointButtons
        SimulationMode = false
        SimulationReference = []
        SimulationResult = []
    end
    properties (Access=private)
        DisplayedParameterFields = {}
        ParameterFields = {'wheelDiameter','gearRatio','lever','rollerRadius','referenceDiameter', ...
            'thickness','driveX','driveY','drivenX','drivenY','sensorX','sensorY','headingDeg', ...
            'startSteeringDeg','returnAngleDeg','maxSteeringDeg','maxPressureDeg','hitTolerance', ...
            'iterations','stepMM','gradientProbeMM','samples','camSamples'}
        ParameterLabels = {'主动轮直径 / mm','请求传动比（轮/凸轮）','机构系数 c / mm', ...
            '滚子半径 / mm','零位中心距 ×2 / mm','凸轮厚度元数据 / mm', ...
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
            root=uigridlayout(app.Figure,[4 2],'RowHeight',{42,38,'1x',116}, ...
                'ColumnWidth',{350,'1x'},'Padding',[14 12 14 12],'RowSpacing',10);
            title=uilabel(root,'Text','工创赛凸轮设计  /  路线、机构与几何校验', ...
                'FontSize',20,'FontWeight','bold','FontColor',[.12 .20 .30]);
            title.Layout.Row=1; title.Layout.Column=1;
            title.Layout.Column=[1 2];
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
            t=uitab(tabs,'Title','车体与求解'); g=uigridlayout(t,[1 1],'Padding',[0 0 0 0]);
            app.ParamsTable=uitable(g,'ColumnName',{'参数','数值'},'ColumnEditable',[false true], ...
                'ColumnWidth',{230,85},'ColumnFormat',{'char','numeric'},'RowName',{},'FontSize',12,'CellEditCallback',@(~,~)app.invalidate());
            app.PointButtons=gobjects(1,4);
            t=uitab(tabs,'Title','打卡点'); g=uigridlayout(t,[2 1],'RowHeight',{30,'1x'},'Padding',[0 0 0 0]);
            controls=uigridlayout(g,[1 2],'Padding',[0 0 0 0]);
            app.PointButtons(1)=uibutton(controls,'Text','选中行后插入','ButtonPushedFcn',@(~,~)app.modifyPoints('target',1));
            app.PointButtons(2)=uibutton(controls,'Text','删除选中行','ButtonPushedFcn',@(~,~)app.modifyPoints('target',-1));
            app.TargetsTable=uitable(g,'ColumnName',{'X / mm','Y / mm'},'ColumnEditable',[true true], ...
                'ColumnWidth',{145,145},'CellEditCallback',@(~,~)app.invalidate(), ...
                'CellSelectionCallback',@(~,event)app.selectPoint('target',event));
            t=uitab(tabs,'Title','路线节点'); g=uigridlayout(t,[2 1],'RowHeight',{30,'1x'},'Padding',[0 0 0 0]);
            controls=uigridlayout(g,[1 2],'Padding',[0 0 0 0]);
            app.PointButtons(3)=uibutton(controls,'Text','选中行后插入','ButtonPushedFcn',@(~,~)app.modifyPoints('node',1));
            app.PointButtons(4)=uibutton(controls,'Text','删除选中行','ButtonPushedFcn',@(~,~)app.modifyPoints('node',-1));
            app.NodesTable=uitable(g,'ColumnName',{'前轮 X / mm','前轮 Y / mm'},'ColumnEditable',[true true], ...
                'ColumnWidth',{145,145},'CellEditCallback',@(~,~)app.invalidate(), ...
                'CellSelectionCallback',@(~,event)app.selectPoint('node',event));
            t=uitab(tabs,'Title','评价权重'); g=uigridlayout(t,[1 1],'Padding',[0 0 0 0]);
            app.WeightsTable=uitable(g,'ColumnName',{'独立目标项','权重'},'ColumnEditable',[false true], ...
                'ColumnWidth',{220,85},'ColumnFormat',{'char','numeric'},'RowName',{},'CellEditCallback',@(~,~)app.invalidate());
            charts=uigridlayout(root,[2 2],'ColumnWidth',{'1x','1x'},'RowHeight',{'1x','1x'}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',12,'RowSpacing',14);
            charts.Layout.Row=3; charts.Layout.Column=2;
            app.RouteAxes=uiaxes(charts); app.RouteAxes.Layout.Row=1; app.RouteAxes.Layout.Column=[1 2];
            app.SteeringAxes=uiaxes(charts); app.SteeringAxes.Layout.Row=2; app.SteeringAxes.Layout.Column=1;
            app.CamAxes=uiaxes(charts); app.CamAxes.Layout.Row=2; app.CamAxes.Layout.Column=2;
            bottom=uigridlayout(root,[2 1],'RowHeight',{26,'1x'},'Padding',[0 0 0 0]);
            bottom.Layout.Row=4; bottom.Layout.Column=[1 2];
            app.Status=uilabel(bottom,'Text','准备就绪','FontSize',13,'FontWeight','bold');
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
            app.Mechanism.Value=p.mechanism; app.AutoRatio.Value=p.autoRatio;
            labels={'有序打卡偏差','前轮路线长度','转向变化率','压力角超限','前轮转角超限','包络欠切风险'};
            app.WeightsTable.Data=[labels(:),num2cell(p.weights(:))];
        end
        function readInputs(app)
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
            camdesign.validateProject(candidate); app.Project=candidate;
        end
        function calculate(app)
            if app.SimulationMode, app.runFixedCamSimulation(); return; end
            app.readInputs(); app.Result=camdesign.evaluate(app.Project,true); app.render();
            app.message(sprintf('完成几何计算；实际传动比 %.6g，工作段 %.1f°。', ...
                app.Result.cam.effectiveRatio,rad2deg(app.Result.cam.workEnd)));
            for k=1:numel(app.Result.warnings), app.message(app.Result.warnings{k}); end
        end
        function render(app)
            if isempty(app.Result), return; end
            r=app.Result.route; c=app.Result.cam; p=app.Project.params; a=app.RouteAxes;
            cla(a); hold(a,'on');
            plot(a,r.front(:,1),r.front(:,2),'Color',[.15 .40 .70],'LineWidth',1.5);
            plot(a,r.sensor(:,1),r.sensor(:,2),'Color',[.85 .25 .20],'LineWidth',1.6);
            plot(a,r.drive(:,1),r.drive(:,2),'--','Color',[.5 .55 .6]);
            plot(a,app.Project.nodes(:,1),app.Project.nodes(:,2),'.:','Color',[.2 .6 .42]);
            scatter(a,app.Project.targets(:,1),app.Project.targets(:,2),45,'k','o');
            for k=1:size(app.Project.targets,1)
                text(a,app.Project.targets(k,1),app.Project.targets(k,2),sprintf('  %d',k),'FontSize',10);
            end
            hold(a,'off'); axis(a,'equal'); grid(a,'on');
            xlim(a,p.bounds(1:2)); ylim(a,p.bounds(3:4));
            xlabel(a,'场地 X / mm'); ylabel(a,'场地 Y / mm'); title(a,'路线与有序打卡点');
            legend(a,{'前轮','传感器','主动轮','路线节点','打卡点'},'Location','southoutside','NumColumns',2);
            a=app.SteeringAxes; cla(a); plot(a,r.frontDistance,rad2deg(r.steering),'Color',[.15 .40 .70],'LineWidth',1.4);
            yline(a,p.maxSteeringDeg,'--'); yline(a,-p.maxSteeringDeg,'--'); grid(a,'on');
            title(a,'前轮转角（左转为正）'); xlabel(a,'前轮行程 / mm'); ylabel(a,'转角 / deg');
            a=app.CamAxes; cla(a); hold(a,'on');
            plot(a,c.pitch(:,1),c.pitch(:,2),'Color',[.2 .4 .75],'LineWidth',1.2);
            plot(a,c.actual(:,1),c.actual(:,2),'Color',[.85 .25 .20],'LineWidth',1.5);
            plot(a,c.actual(~c.workingMask,1),c.actual(~c.workingMask,2),'--','Color',[.5 .5 .5],'LineWidth',1.5);
            hold(a,'off'); axis(a,'equal'); grid(a,'on'); xlabel(a,'X / mm'); ylabel(a,'Y / mm');
            title(a,'理论与实际凸轮（含回程）'); legend(a,{'理论','实际候选','回程'},'Location','southoutside','NumColumns',3);
            m=app.Result.metrics;
            app.Status.Text=sprintf('最大打卡偏差 %.2f mm    最大压力角 %.1f°    目标函数 %.4f    轮廓交叉 %g', ...
                m.maxHitError,m.maxPressureDeg,m.score,m.intersectionCount);
            if m.maxPressureDeg>p.maxPressureDeg || m.minUndercutMargin<=0 || m.maxHitError>p.hitTolerance || m.intersectionCount>0
                app.Status.Text=[app.Status.Text,'    有指标超限，需改进'];
                app.Status.FontColor=[.65 .28 .08];
            else
                app.Status.FontColor=[.12 .20 .30];
            end
        end
        function invalidate(app)
            if app.SimulationMode
                app.SimulationResult=[];
                app.Status.Text='反推参数已修改，凸轮保持固定；点击“更新反推”查看路线变化。';
                return;
            end
            app.Result=[]; app.Status.Text='输入已修改，请重新计算；当前图像为上次结果。';
        end
        function toggleSimulation(app)
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
            if app.SimulationMode, state='off'; else, state='on'; end
            for k=[1 2 3 5 8], app.Buttons(k).Enable=state; end
            app.Mechanism.Enable=state; app.AutoRatio.Enable=state;
            app.TargetsTable.ColumnEditable=[~app.SimulationMode ~app.SimulationMode];
            app.NodesTable.ColumnEditable=[~app.SimulationMode ~app.SimulationMode];
            app.WeightsTable.ColumnEditable=[false ~app.SimulationMode];
            for k=1:numel(app.PointButtons), app.PointButtons(k).Enable=state; end
            if app.SimulationMode
                app.Buttons(4).Text='更新反推'; app.Buttons(7).Text='退出反推';
            else
                app.Buttons(4).Text='计算凸轮'; app.Buttons(7).Text='固定凸轮反推';
            end
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
            plot(app.RouteAxes,sim.sensor(:,1),sim.sensor(:,2),'k--','LineWidth',1.5,'DisplayName','固定凸轮试调');
            hold(app.RouteAxes,'off');
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
        function selectPoint(app,kind,event)
            if isempty(event.Indices), return; end
            if strcmp(kind,'target'), app.SelectedTargetRow=event.Indices(1,1);
            else, app.SelectedNodeRow=event.Indices(1,1); end
        end
        function modifyPoints(app,kind,operation)
            if app.Busy, return; end
            if strcmp(kind,'target'), table=app.TargetsTable; selected=app.SelectedTargetRow;
            else, table=app.NodesTable; selected=app.SelectedNodeRow; end
            data=table.Data; selected=max(1,min(size(data,1),selected));
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
            if strcmp(kind,'target'), app.message('打卡点已修改；点击“重建路线”可重新生成路线节点。'); end
        end
        function action(app,name)
            try
                if app.SimulationMode && ismember(name,{'import','save','seed','optimize','export'})
                    app.message('请先退出反推，恢复设计模式。'); return;
                end
                switch name
                    case 'calculate', app.calculate();
                    case 'seed'
                        app.readInputs(); app.Project.nodes=camdesign.seedNodes(app.Project.targets,app.Project.params);
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
                    case 'stop', app.StopRequested=true; app.message('将在当前梯度轮结束后停止。');
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
            if app.Busy || app.SimulationMode, return; end
            app.readInputs(); app.Busy=true; app.StopRequested=false; app.setBusy(true);
            cleanup=onCleanup(@()app.finishBusy());
            [project,history]=camdesign.optimize(app.Project,@app.optimizationUpdate);
            app.Project=project; app.History=history; app.syncInputs(); app.calculate();
            app.message(sprintf('优化结束：目标 %.5f → %.5f；共 %d 次评价。',history(1).score,history(end).score,history(end).evaluations));
        end
        function stop=optimizationUpdate(app,iteration,project,history)
            app.Project=project; app.NodesTable.Data=project.nodes;
            app.Result=camdesign.evaluate(project,false); app.render();
            app.Status.Text=sprintf('优化第 %d 轮 / %d    当前目标 %.5f    最大偏差 %.2f mm', ...
                iteration,project.params.iterations,history(end).score,history(end).maxHitError);
            drawnow; stop=app.StopRequested;
        end
        function setBusy(app,busy)
            if busy, state='off'; else, state='on'; end
            for k=[1:5,7:8], app.Buttons(k).Enable=state; end
            if busy, app.Buttons(6).Enable='on'; else, app.Buttons(6).Enable='off'; end
            app.Mechanism.Enable=state; app.AutoRatio.Enable=state;
            for k=1:numel(app.PointButtons), app.PointButtons(k).Enable=state; end
            app.ParamsTable.ColumnEditable=[false ~busy]; app.TargetsTable.ColumnEditable=[~busy ~busy];
            app.NodesTable.ColumnEditable=[~busy ~busy]; app.WeightsTable.ColumnEditable=[false ~busy];
        end
        function finishBusy(app)
            app.Busy=false;
            if isvalid(app.Figure), app.setBusy(false); end
            if app.CloseAfterStop && isvalid(app.Figure), delete(app.Figure); end
        end
        function closeRequested(app)
            if app.Busy, app.StopRequested=true; app.CloseAfterStop=true;
            else, delete(app.Figure); end
        end
        function message(app,text)
            old=app.Log.Value; if ischar(old), old={old}; end
            app.Log.Value=[old(max(1,end-25):end);{char(text)}];
        end
    end
end
