function report=check_auto_tune_ui()
% Replay the core's real short-contract records; never start an optimizer.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:AutoTuneUIBatch','Use an independent batch.');
folder=fullfile(root,'outputs','auto_tune_20261030','ui'); if ~isfolder(folder), mkdir(folder); end
source=fullfile(root,'outputs','auto_tune_20261030','contracts','short_contract.mat'); saved=load(source);
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
assert(any(strcmp(app.AlgorithmSelector.ItemsData,'auto-tune-v1')));
original=app.inputProject(); assert(~isfield(original.params,'autoTune'));
app.Project=saved.q; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='auto-tune-v1'; call(app.AlgorithmSelector,'ValueChangedFcn');
assert(app.ControlsTabs.SelectedTab==app.AutoTuneTab && contains(app.TrainingShortcut.Text,'全自动'));
assert(strcmp(app.DynamicWeightsEnabled.Enable,'off') && app.DynamicWeightsEnabled.Value);
assert(strcmp(app.TrainingApplyButton.Enable,'off') && all(strcmp({app.TrainingFields.Enable},'off')));
base=camdesign.autoTuneSettings(app.Project.params);
app.AutoTuneFields(1).Value=base.trials+1; app.AutoTuneFields(2).Value=base.maxIterations+1;
candidate=app.inputProject(); edited=camdesign.autoTuneSettings(candidate.params);
assert(isequal(edited.selectedWeights,base.selectedWeights) && edited.seed==base.seed && edited.polishCount==base.polishCount);
assert(isequaln(candidate.params.dynamicWeights,saved.q.params.dynamicWeights) && isequal(candidate.params.weights,saved.q.params.weights));
camdesign.saveProject(candidate,fullfile(folder,'budget_roundtrip.mat'));
loaded=camdesign.importProject(fullfile(folder,'budget_roundtrip.mat')); assert(isequaln(loaded,candidate));
app.AutoTuneFields(1).Value=1; rejected=false;
try, app.inputProject(); catch, rejected=true; end
assert(rejected); restore(app,saved);
partial=saved.q; partial.params.autoTune=struct('trials',4,'maxIterations',2);
app.Project=partial; app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.syncInputs(); app.calculate();
assert(contains(app.AutoTuneVerdict.Text,'未记录') && ~isfield(app.Project.params.autoTune,'selectedWeights'));
restore(app,saved);
checks{end+1}='automatic controls expose budget/seed, preserve learned weights and old dynamic policy, validate and round-trip';

app.AlgorithmSelector.Value='peak-gradient-v2'; call(app.AlgorithmSelector,'ValueChangedFcn');
app.TrainingFields(6).Value=app.TrainingFields(6).Value+.1; call(app.TrainingFields(6),'ValueChangedFcn'); pending=app.TrainingFields(6).Value;
app.AlgorithmSelector.Value='auto-tune-v1'; call(app.AlgorithmSelector,'ValueChangedFcn');
assert(app.TrainingDirty && app.TrainingFields(6).Value==pending && strcmp(app.Buttons(5).Enable,'off'));
assert(app.ControlsTabs.SelectedTab==app.TrainingTab && strcmp(app.TrainingResetButton.Enable,'on'));
rejected=false; try, app.runOptimization(); catch ex, rejected=strcmp(ex.identifier,'cam:TrainingPending'); end
assert(rejected && app.TrainingDirty && app.TrainingFields(6).Value==pending);
call(app.TrainingResetButton,'ButtonPushedFcn'); call(app.TrainingShortcut,'ButtonPushedFcn');
assert(~app.TrainingDirty && app.ControlsTabs.SelectedTab==app.AutoTuneTab);
app.setBusy(true); assert(all(strcmp({app.AutoTuneFields.Enable},'off')) && strcmp(app.Buttons(6).Enable,'on'));
app.setBusy(false);
checks{end+1}='pending manual inputs block automatic start until explicit reset/application; busy budgets lock and stop remains enabled';

restore(app,saved); app.OptimizationInfo=[];
app.optimizationUpdate(saved.h(end).iteration,saved.q,saved.h);
grid=saved.h(end).comparisonGrid;
assert(isequal([app.Project.params.samples app.Project.params.camSamples],grid));
assert(isequal(app.ScoreDisplayData.grid,grid) && abs(app.ScoreDisplayData.total-saved.h(end).score)<1e-7);
assert(strcmp(app.ScoreDisplayData.weightMode,'auto-tuned-v1') && isequal(app.ScoreDisplayData.activeWeights,saved.h(end).activeWeights));
rows=app.AutoTuneParameters.Data; index=strcmp(rows(:,1),'真实训练采样');
assert(strcmp(rows{index,2},sprintf('%.6g',saved.h(end).trainingSamples)));
assert(contains(app.ScoreTrendAxes.Title.String,'统一网格') && contains(app.ObjectiveTrendAxes.Title.String,'组间权重不同'));
assert(~isfield(saved.h,'objective'));
app.StopRequested=true; assert(app.optimizationUpdate(saved.h(end).iteration,saved.q,saved.h)); app.StopRequested=false;
for k=1:numel(saved.h)
    h=saved.h(k);
    if strcmp(h.autoStage,'search') || strcmp(h.autoStage,'polish')
        text=app.autoProgressText(h);
        assert(contains(text,sprintf('本组%d/%d',h.trialIteration,h.trialBudget)) && contains(text,sprintf('累计%d',h.iteration)));
    end
end
checks{end+1}='real callback displays the common grid and recorded native training controls, separate cumulative/trial progress and truthful stop response';

restore(app,saved); app.finishAutoTune(saved.info);
assert(isequal([app.TrainingFields.Value],struct2array(camdesign.trainingSettings(saved.q))));
assert(contains(app.Status.Text,'未通过') && contains(app.AutoTuneVerdict.Text,'未通过'));
assert(isequal(app.Project.params.weights,saved.p.params.weights) && app.Project.params.gearRatio==35);
assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.activeRows));
assert(isempty(app.ScoreDisplayData.objectiveY) && isequal(app.ScoreDisplayData.dynamicY,[saved.h.dynamicScore]));
app.History=[]; app.updateDiagnostics(); assert(isequal(app.ScoreDisplayData.activeWeights,saved.info.finalActiveWeights));
assert(strcmp(app.ScoreDisplayData.weightMode,'auto-tuned-v1'));
assert(contains(app.AutoTuneProgress.Text,'已有结束记录'));
positive=struct('fullAuto',true,'verifiedFeasible',saved.a.verifiedFeasible,'convergencePassed',saved.a.convergencePassed,'assessment',saved.a);
[text,~,passed]=app.autoTuneGrade(positive);
if isfield(saved.a,'numericalChecks'), assert(passed); else, assert(~passed && contains(text,'未验证')); end
legacy=positive;
if isfield(legacy.assessment,'numericalChecks'), legacy.assessment=rmfield(legacy.assessment,'numericalChecks'); end
[text,color,passed]=app.autoTuneGrade(legacy); assert(~passed && contains(text,'未验证') && ~isequal(color,[.14 .40 .28]));
positive.convergencePassed=false; [~,~,passed]=app.autoTuneGrade(positive); assert(~passed);
positive.convergencePassed=true; positive.verifiedFeasible=false; [~,~,passed]=app.autoTuneGrade(positive); assert(~passed);
partial=positive; partial.verifiedFeasible=true;
partial.assessment.numericalChecks=rmfield(saved.a.numericalChecks,'passed');
[~,~,passed]=app.autoTuneGrade(partial); assert(~passed);
assert(sum(contains(app.FullLog,'请求上限'))>=numel(saved.info.trials));
checks{end+1}='final settings refill from the winner; actual weights support info-only records; acceptance requires both feasibility and convergence flags';

restore(app,saved); app.finishAutoTune(saved.info); call(app.TrainingShortcut,'ButtonPushedFcn');
for wh={[1320 860],[1120 760]}
    dimensions=wh{1}; app.Figure.Position=[10 10 dimensions]; call(app.Figure,'SizeChangedFcn');
    capture(app,folder,sprintf('auto_tune_%dx%d.png',dimensions));
    assert(app.ControlsTabs.SelectedTab==app.AutoTuneTab && strcmp(app.AutoTuneProgress.Visible,'on') && strcmp(app.AutoTuneVerdict.Visible,'on'));
end
report=struct('release',version('-release'),'checks',{checks},'source',source,'optimizerRun',false, ...
    'selectedTrial',saved.info.selectedTrial,'totalIterations',saved.info.iterations,'totalBudget',saved.info.requestedIterations, ...
    'actualWeights',saved.info.finalActiveWeights,'scope','Owned hidden UI and recorded contract replay; no new tuning or quality experiment.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('AUTO_TUNE_UI_CASE_PASS %s\n',checks{k}); end
fprintf('AUTO_TUNE_UI_PASS cases=%d optimizerRun=false ratio=35\n',numel(checks));
end
function restore(app,saved)
app.Project=saved.q; app.History=saved.h; app.HistoryProject=saved.q; app.OptimizationInfo=saved.info;
app.AlgorithmSelector.Value='auto-tune-v1'; app.syncInputs(); app.calculate();
end
function call(object,property)
callback=object.(property); callback(object,[]);
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow; exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
