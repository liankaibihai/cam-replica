function report=check_results_panel_ui()
% Owned hidden windows, genuine callbacks and preserved failing cam data.
% This checks display contracts, never optimizer convergence or vehicle use.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:ResultsBatchOnly','请使用独立 batch。');
folder=fullfile(root,'outputs','results_panel_20261030'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
solar=camdesign.solarTestProject(); app.Project=solar; app.syncInputs(); app.calculate();
assert(isequal(app.TrainingModel.Items,{'三次样条（通过节点）','贝塞尔曲线（控制点调形）'}));
assert(isequal(app.AlgorithmSelector.Items,{'梯度搜索（峰值评分）','四方向试探（加权）','约束优化（内点法）','全自动调优（权重＋训练）'}));
assert(contains(app.TrainingModel.Tooltip,'路线画法') && contains(app.AlgorithmSelector.Tooltip,'全自动还会比较路线模型'));
assert(strcmp(app.AutoRatio.Visible,'off') && strcmp(app.AutoRatio.Enable,'off'));
assert(contains(app.RatioNotice.Text,'固定使用用户输入 35'));
assert(contains(app.TrainingRuntime.Text,'尚未开始训练'));
for dimensions={[1320 860],[1120 760],[1920 1080]}
    wh=dimensions{1}; app.Figure.Position=[10 10 wh]; call(app.Figure,'SizeChangedFcn'); drawnow;
    app.ControlsTabs.SelectedTab=app.ParamsTable.Parent.Parent;
    call(app.TrainingShortcut,'ButtonPushedFcn'); drawnow;
    assert(app.ControlsTabs.SelectedTab==app.TrainingTab && strcmp(app.TrainingShortcut.Visible,'on'));
    button=relativePosition(app.TrainingShortcut,app.Figure);
    apply=relativePosition(app.TrainingApplyButton,app.Figure);
    route=relativePosition(app.RouteAxes,app.Figure); cam=relativePosition(app.CamAxes,app.Figure);
    assert(all(button(1:2)>=0) && button(2)+button(4)<=wh(2));
    assert(all(apply(1:2)>=0) && apply(2)+apply(4)<=wh(2));
    assert(route(3)>250 && route(4)>200 && cam(3)>220 && cam(4)>130);
    assert(app.Project.params.gearRatio==35 && app.Result.cam.effectiveRatio==35);
    capture(app,folder,sprintf('training_%dx%d.png',wh));
    camBox=equalPlotBox(app.CamAxes); minimum=280; if wh(1)<1220, minimum=200; end
    assert(all(camBox(3:4)>=minimum),'Cam plot is too small after layout/export.');
    legend=getpixelposition(app.CamAxes.Legend,true);
    curve=app.CamInspectionRecord.result.cam.actual;
    pixels=(curve-[app.CamAxes.XLim(1) app.CamAxes.YLim(1)])./[diff(app.CamAxes.XLim) diff(app.CamAxes.YLim)].*camBox(3:4)+camBox(1:2);
    assert(~any(all(pixels>=legend(1:2) & pixels<=legend(1:2)+legend(3:4),2)),'Cam legend covers actual contour.');
end
checks{end+1}='plain model/method names; permanent training shortcut and apply controls visible at three sizes';
fprintf('RESULTS_UI_PROGRESS layout complete\n');

% Legacy autoRatio never changes a user value; explicit table input is kept.
app.Project.params.autoRatio=true; app.syncInputs(); app.AutoRatio.Value=true;
candidate=app.inputProject(); assert(candidate.params.gearRatio==35 && ~candidate.params.autoRatio);
assert(any(contains(app.FullLog,'旧项目')));
app.ParamsTable.Data{2,2}=32; call(app.ParamsTable,'CellEditCallback'); app.calculate();
assert(app.Project.params.gearRatio==32 && app.Result.cam.effectiveRatio==32 && ~app.Project.params.autoRatio);
app.Project=solar; app.syncInputs(); app.calculate();
checks{end+1}='legacy true is explained and ignored; manual 35-to-32 input survives calculation unchanged';

data=app.ScoreDisplayData; assert(size(data.rows,1)==6 && data.consistent);
assert(isequal(cell2mat(data.rows(:,2)),app.Result.metrics.terms(:)));
assert(isequal(cell2mat(data.rows(:,3)),solar.params.weights(:)));
assert(abs(sum(cell2mat(data.rows(:,4)))-data.total)<1e-9*max(1,data.total));
oldData=data; oldWeights=solar.params.weights;
app.WeightsTable.Data{1,2}=oldWeights(1)*2; call(app.WeightsTable,'CellEditCallback');
assert(contains(app.ScoreSummary.Text,'历史') && contains(app.CamSourceLabel.Text,'历史'));
assert(isequal(app.ScoreDisplayData.rows,oldData.rows) && strcmp(app.CrossSource.Enable,'off'));
app.calculate(); assert(app.ScoreDisplayData.consistent && app.Project.params.weights(1)==oldWeights(1)*2);
assert(app.ScoreDisplayData.rows{1,3}==oldWeights(1)*2 && contains(app.ScoreSummary.Text,'当前计算'));
assert(contains(app.ScoreTable.Tooltip,'不是原版十二项'));
assert(contains(app.Status.Text,'回程') && ~app.Result.metrics.returnAngleSatisfied);
checks{end+1}='six weighted terms sum to common score; edits retain historical weights and mark score/cam stale; return shortfall remains visible';
fprintf('RESULTS_UI_PROGRESS fixed ratio and score complete\n');

% A short real optimizer run supplies the displayed runtime values.
fixture=solar; fixture.params.samples=101; fixture.params.camSamples=181;
app.Project=fixture; app.syncInputs(); app.calculate();
setField(app,'iterations',1); setField(app,'controlPointCount',size(fixture.nodes,1)); setField(app,'interpolationPerSegment',12);
setField(app,'gradientForce',.25); setField(app,'learningRate',.8); setField(app,'smoothingRate',.2);
setField(app,'adjustInterval',4); setField(app,'adjustExponent',.5);
applied=app.applyTraining(); assert(applied,'%s',app.Status.Text); initialValues=[app.TrainingFields.Value];
fprintf('RESULTS_UI_PROGRESS short search requested=%d nodes=%d\n',app.Project.params.iterations,size(app.Project.nodes,1));
app.runOptimization();
actualHistory=app.History; actualInfo=app.OptimizationInfo; actualProject=app.Project;
assert(numel(actualHistory)>=2 && actualHistory(end).iteration==1 && isfield(actualHistory,'plannedSmoothingRates'));
assert(isequal(initialValues,[app.TrainingFields.Value]));
assert(contains(app.TrainingRuntime.Text,sprintf('探测 %.5g mm',actualHistory(end).probeMM)));
assert(contains(app.TrainingRuntime.Text,sprintf('采纳位移 %.5g mm',actualHistory(end).stepMM)));
assert(contains(app.TrainingRuntime.Text,mat2str(actualHistory(end).plannedSmoothingRates,3)));
assert(isequal(app.ScoreDisplayData.scoreY,[actualHistory.score]) && isempty(app.ScoreDisplayData.objectiveY));
assert(contains(app.ScoreDisplayData.historyState,'本次训练'));
app.History=rmfield(actualHistory,'plannedSmoothingRates'); app.updateDiagnostics();
assert(contains(app.TrainingRuntime.Text,'计划平滑 未记录'));
app.History=rmfield(app.History,'probeMM'); app.updateDiagnostics();
assert(contains(app.TrainingRuntime.Text,'不能从初始设置反推'));
app.History=actualHistory; app.updateDiagnostics();
capture(app,folder,'actual_search_runtime.png');
checks{end+1}='real short search history drives read-only probe, decay, planned/accepted step and smoothing; old missing fields stay missing';
fprintf('RESULTS_UI_PROGRESS real runtime complete\n');

% Use a preserved real interior-point history to verify separate scales.
source=fullfile(root,'outputs','training_controls_20261030','sensitivity_300','cold_degree7_forward005.mat');
stored=load(source,'q','h','info');
assert(isfield(stored,'h') && isfield(stored.h,'objective'));
app.History=stored.h; app.HistoryProject=[]; app.OptimizationInfo=stored.info; app.updateDiagnostics();
assert(isequal(app.ScoreDisplayData.scoreY,[stored.h.score]));
assert(isequal(app.ScoreDisplayData.objectiveY,[stored.h.objective]));
assert(app.ScoreTrendAxes~=app.ObjectiveTrendAxes && contains(app.ScoreDisplayData.historyState,'历史'));
scoreLine=findobj(app.ScoreTrendAxes,'Type','line'); objectiveLine=findobj(app.ObjectiveTrendAxes,'Type','line');
assert(isequal(scoreLine.YData,[stored.h.score]) && isequal(objectiveLine.YData,[stored.h.objective]));
assert(contains(app.TrainingRuntime.Text,'求解器记录') && contains(app.TrainingRuntime.Text,'本法不使用学习率'));
app.OptimizationInfo=[]; app.updateDiagnostics(); assert(contains(app.TrainingRuntime.Text,'名义差分 未记录'));
call(app.ScoreDetailsButton,'ButtonPushedFcn'); capture(app,folder,'historical_separate_objective.png');
captureFigure(app.DiagnosticsFigure,folder,'large_score_history.png');
checks{end+1}='preserved real constrained score and objective plot on independent axes; historical/missing parameter provenance is explicit';
fprintf('RESULTS_UI_PROGRESS historical scales complete\n');

for k=1:305, app.message(sprintf('结果面板日志验收 %03d',k)); end
assert(numel(app.Log.Value)==200 && numel(app.FullLog)>=305);
call(app.LogDetailsButton,'ButtonPushedFcn'); detail=app.DiagnosticsFigure;
logs=findobj(detail,'Type','uitextarea'); assert(isscalar(logs));
assert(any(contains(logs.Value,'日志验收 001')) && any(contains(logs.Value,'日志验收 305')));
assert(numel(logs.Value)==numel(app.FullLog) && logs.FontSize>=13);
call(app.LogDetailsButton,'ButtonPushedFcn'); assert(app.DiagnosticsFigure==detail);
captureFigure(detail,folder,'large_complete_log.png');
checks{end+1}='main log keeps 200 recent lines; reusable large window retains the full log';
fprintf('RESULTS_UI_PROGRESS complete log verified\n');

% Historical fixed input explicitly reproduces eight real dense crossings.
% This ratio is a TEST fixture only and never a default or automatic choice.
archiveSource=fullfile(fileparts(source),'verification.json'); archive=jsondecode(fileread(archiveSource));
archived=archive.cases(strcmp({archive.cases.label},'cold_degree7_forward005'));
crossProject=stored.q; crossProject.params.gearRatio=archived.final8x.refinedGrid.effectiveRatio;
crossProject.params.autoRatio=false; app.Project=crossProject; app.syncInputs(); app.calculate();
crossProject=app.Project;
coarse=app.Result; coarseGrid=[numel(coarse.route.u),size(coarse.cam.actual,1)];
assert(coarse.metrics.intersectionCount==0);
app.History=[]; app.HistoryProject=crossProject;
app.OptimizationInfo=struct('verification',struct('refinedGrid',struct('routeSamples',4313,'camSamples',5761)));
app.CrossSource.Value='refined'; call(app.CrossSource,'ValueChangedFcn');
dense=app.CamInspectionRecord; marker=findobj(app.CamAxes,'Tag','cam-self-intersections');
actual=findobj(app.CamAxes,'Tag','inspected-cam-actual');
fprintf('RESULTS_UI_PROGRESS selected source=%s grid=%d/%d count=%g label=%s\n',dense.source,dense.grid,dense.result.metrics.intersectionCount,app.CamSourceLabel.Text);
assert(isequal(dense.grid,[4313 5761]) && dense.result.metrics.intersectionCount==8,'%s',app.CamSourceLabel.Text);
assert(isscalar(marker) && numel(marker.XData)==8 && isscalar(actual));
assert(isequal([actual.XData(:),actual.YData(:)],dense.result.cam.actual));
assert(isequal([marker.XData(:),marker.YData(:)],dense.result.intersectionPoints));
assert(isequal(app.CrossTable.Data(:,2:3),dense.result.intersectionPairs));
assert(isequal(app.CrossTable.Data(:,4:5),dense.result.intersectionPoints));
assert(isequal(app.ScoreDisplayData.grid,dense.grid) && app.ScoreDisplayData.consistent);
assert(isequaln(app.Project,crossProject) && isequaln(app.Result,coarse));
assert(contains(app.CamSourceLabel.Text,'加密复查') && contains(app.CamSourceLabel.Text,'8 对'));
assert(contains(app.Status.Text,'加密复查') && contains(app.Status.Text,'轮廓自交 8'));
call(app.CrossDetailsButton,'ButtonPushedFcn'); fullLimits=[app.CamAxes.XLim app.CamAxes.YLim];
capture(app,folder,'genuine_fine_crossings_main.png'); captureFigure(detail,folder,'genuine_fine_crossings_large.png');
callback=app.CrossTable.CellSelectionCallback; cam_invoke_ui_callback(callback,app.CrossTable,struct('Indices',[1 1]));
point=dense.result.intersectionPoints(1,:); zoomLimits=[app.CamAxes.XLim app.CamAxes.YLim];
assert(norm([mean(zoomLimits(1:2)),mean(zoomLimits(3:4))]-point)<1e-8);
assert(diff(zoomLimits(1:2))<diff(fullLimits(1:2)));
captureFigure(detail,folder,'genuine_crossing_zoom.png');
call(app.CrossResetButton,'ButtonPushedFcn'); assert(isequal([app.CamAxes.XLim app.CamAxes.YLim],fullLimits));
app.NodesTable.Data(2,1)=app.NodesTable.Data(2,1)+.5; app.updateDiagnostics();
assert(contains(app.CamSourceLabel.Text,'历史') && contains(app.ScoreSummary.Text,'历史'));
assert(strcmp(app.CrossSource.Enable,'off'));
app.NodesTable.Data=crossProject.nodes;
app.CrossSource.Value='current'; call(app.CrossSource,'ValueChangedFcn');
assert(isequal(app.CamInspectionRecord.grid,coarseGrid) && isempty(findobj(app.CamAxes,'Tag','cam-self-intersections')));
checks{end+1}='real coarse-zero/fine-eight crossings use matching dense contour, coordinates, segment pairs and score; selection zoom and full return work';
fprintf('RESULTS_UI_PROGRESS fine crossings complete\n');

% Missing data never becomes a fabricated zero score or made-up history.
missing=camdesign.resultDisplayData([],[],[],[]);
assert(isnan(missing.total) && isempty(missing.rows) && isempty(missing.scoreY) && isempty(missing.objectiveY));
app.Project=actualProject; app.History=actualHistory; app.HistoryProject=actualProject; app.OptimizationInfo=actualInfo;
app.syncInputs(); app.calculate(); call(app.TrainingShortcut,'ButtonPushedFcn');
call(app.ScoreDetailsButton,'ButtonPushedFcn');
app.Figure.Position=[10 10 1320 860]; call(app.Figure,'SizeChangedFcn'); capture(app,folder,'final_training_score_1320x860.png');
app.closeRequested(); assert(~isgraphics(app.Figure) && ~isgraphics(detail));
checks{end+1}='missing data stays missing; closing owned app also closes its owned results window';
report=struct('release',version('-release'),'checks',{checks},'historicalSource',source, ...
    'historicalRatioSource',archiveSource, ...
    'fineGrid',dense.grid,'fineCrossingCount',8,'fixtureFixedRatio',crossProject.params.gearRatio, ...
    'shortSearchIterations',actualHistory(end).iteration,'scope', ...
    'Owned hidden UI callback/layout checks and preserved failed geometry; not native pointer interaction, convergence or engineering approval.');
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('RESULTS_UI_CASE_PASS %s\n',checks{k}); end
fprintf('RESULTS_UI_PASS cases=%d fineCrossings=8 shortSearchIterations=1\n',numel(checks));
end
function call(object,property)
callback=object.(property); cam_invoke_ui_callback(callback,object,[]);
end
function setField(app,name,value)
index=find(strcmp(app.TrainingFieldNames,name)); app.TrainingFields(index).Value=value;
call(app.TrainingFields(index),'ValueChangedFcn');
end
function position=relativePosition(object,figure)
position=getpixelposition(object,true); origin=getpixelposition(figure,true);
% uifigure descendants report coordinates relative to the figure content.
if position(1)>figure.Position(3), position(1:2)=position(1:2)-origin(1:2); end
end
function box=equalPlotBox(a)
scale=[1 1]; if strcmp(a.Units,'normalized'), scale=a.Parent.Position(3:4); else, assert(strcmp(a.Units,'pixels')); end
position=getpixelposition(a.Parent,true); inner=a.InnerPosition.*[scale scale]; origin=position(1:2);
ratio=diff(a.XLim)/diff(a.YLim); dimensions=[min(inner(3),inner(4)*ratio),min(inner(4),inner(3)/ratio)];
box=[origin+inner(1:2)+(inner(3:4)-dimensions)/2,dimensions];
end
function capture(app,folder,name)
captureFigure(app.Figure,folder,name);
end
function captureFigure(figure,folder,name)
drawnow; exportapp(figure,fullfile(folder,name)); pause(.15); drawnow;
exportapp(figure,fullfile(folder,name));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
