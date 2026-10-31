function report=check_feasibility_four_ui()
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
root=fileparts(mfilename('fullpath')); folder=fullfile(root,'outputs','feasibility_four_20261031','ui');
if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleanup=onCleanup(@()closeOwn(app));
assert(strcmp(app.AlgorithmSelector.Value,'peak-gradient-v2'));
p=fixture(); app.Project=p; app.syncInputs(); app.calculate();
app.DynamicWeightsEnabled.Value=true; invoke(app.DynamicWeightsEnabled);
app.AlgorithmSelector.Value='feasibility-four-direction-v1'; invoke(app.AlgorithmSelector); app.openTraining();
assert(strcmp(app.Buttons(5).Enable,'off') && app.DynamicWeightsEnabled.Value);
assert(strcmp(app.DynamicWeightsEnabled.Enable,'on') && contains(app.DynamicWeightInfo.Text,'不支持动态'));
assert(contains(app.Buttons(5).Tooltip,'关闭') && any(strcmp(app.AlgorithmSelector.ItemsData,'video-four-direction-v1')));
drawnow; exportapp(app.Figure,fullfile(folder,'dynamic_weight_conflict.png'));
checks={'new backend explicit choice with unchanged default and retained legacy path; enabled dynamic weights visibly block launch without silent disabling'};
app.DynamicWeightsEnabled.Value=false; invoke(app.DynamicWeightsEnabled); app.calculate();
assert(strcmp(app.Buttons(5).Enable,'on') && app.WeightsTable.ColumnEditable(2));
assert(strcmp(app.TrainingFields(6).Enable,'on') && strcmp(app.TrainingFields(7).Enable,'on'));
original=app.Project; app.runOptimization();
assert(isfield(app.OptimizationInfo,'rankingState') && strcmp(app.OptimizationInfo.algorithm,'feasibility-four-direction-v1'));
assert(isequaln(app.Project.params,original.params) && isequal(app.Project.targets,original.targets) && isequal(app.Project.nodes(1,:),original.nodes(1,:)));
assert(all([app.History.fullGeometryChecked]) && all([app.History.trainingFeasible]));
assert(contains(app.TrainingRuntime.Text,'8倍') && contains(app.TrainingRuntime.Text,'质量排序') && contains(app.Status.Text,'4/8倍'));
assert(contains(app.WeightsTable.Tooltip,'辅助提案') && contains(app.TrainingInfo.Text,'辅助提案'));
contestNotice=app.ContestGeometryNotice.Text;
fprintf('FEASIBILITY_UI_CONTEST_NOTICE %s\n',contestNotice);
assert(isempty(app.ContestGeometryReport) && contains(contestNotice,'失效') && contains(contestNotice,'重新检查'));
app.openTraining(); drawnow; exportapp(app.Figure,fullfile(folder,'completed_feasible_fixture.png'));
checks{end+1}='real run shows native phase/ranking and 8x physical metrics separately, unchanged hardware/model/start, with contest/body certification still absent';
completedRuntime=app.TrainingRuntime.Text; assert(startsWith(completedRuntime,'本次'));
app.TrainingFields(6).Value=.7; invoke(app.TrainingFields(6));
assert(app.TrainingDirty && startsWith(app.TrainingRuntime.Text,'上次') && contains(app.TrainingRuntime.Text,'8倍'));
drawnow; exportapp(app.Figure,fullfile(folder,'historical_after_input_edit.png'));
checks{end+1}='editing one training input marks the completed 8x metrics as previous results before settings are applied';
report=struct('release',version('-release'),'checksPassed',numel(checks),'checks',{checks}, ...
    'finalInfo',app.OptimizationInfo,'contestNotice',contestNotice,'completedRuntime',completedRuntime, ...
    'historicalRuntime',app.TrainingRuntime.Text,'scope','Short owned hidden UI contract only; long team optimization quality reported separately.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FEASIBILITY_FOUR_UI_PASS checks=%d\n',numel(checks));
end
function invoke(control), callback=control.ValueChangedFcn; callback(control,[]); end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
function p=fixture()
p=camdesign.defaultProject(); p.params.mechanism='flat'; p.params.gearRatio=35; p.params.sensorX=0; p.params.sensorY=0;
p.params.samples=101; p.params.camSamples=181; p.params.bounds=[0 1000 0 1000]; p.params.iterations=3;
p.nodes=[200 200;200 450;200 700]; p.targets=p.nodes;
[p,~]=camdesign.rebuildRoute(p,struct('routeModel','bezier-blend-independent-v1','controlPointCount',6, ...
    'bezierDegree',5,'interpolationPerSegment',20),'peak-gradient-v2');
end
