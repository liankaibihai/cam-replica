function report=check_dynamic_weights_ui()
% Owned hidden UI, short integration only. No convergence/vehicle claims.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:DynamicUIBatch','Use an independent batch.');
folder=fullfile(root,'outputs','dynamic_weights_20261030'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
solar=camdesign.solarTestProject(); solar.params.samples=101; solar.params.camSamples=181; solar.params.iterations=2;
app.Project=solar; app.syncInputs(); app.calculate();
assert(~isfield(app.inputProject().params,'dynamicWeights') && ~app.DynamicWeightsEnabled.Value);
assert(strcmp(app.ScoreBasis.Value,'auto') && all(strcmp(app.WeightsTable.Data(:,3),'未记录')));
assert(~app.ScoreDisplayData.dynamicAvailable && isempty(app.ScoreDisplayData.dynamicY));
checks{end+1}='legacy projects keep static defaults without field injection or invented active weights';

app.DynamicWeightsEnabled.Value=true; call(app.DynamicWeightsEnabled,'ValueChangedFcn');
values=[1 2 5 .5];
for k=1:4, app.DynamicWeightFields(k).Value=values(k); call(app.DynamicWeightFields(k),'ValueChangedFcn'); end
assert(contains(app.ScoreSummary.Text,'历史') && strcmp(app.DynamicWeightFields(1).Enable,'on'));
candidate=app.inputProject(); settings=camdesign.dynamicWeightSettings(candidate.params);
assert(settings.enabled && settings.interval==1 && settings.gain==2 && settings.maxMultiplier==5 && settings.response==.5);
app.DynamicWeightFields(1).Value=0; rejected=false;
try, app.inputProject(); catch, rejected=true; end
assert(rejected); app.DynamicWeightFields(1).Value=1; app.calculate();
camdesign.saveProject(app.inputProject(),fullfile(folder,'dynamic_ui_project.mat'));
loaded=camdesign.importProject(fullfile(folder,'dynamic_ui_project.mat'));
assert(isequaln(loaded,app.Project) && isequaln(loaded.params.weights,solar.params.weights));
app.Project=loaded; app.syncInputs(); app.calculate();
assert(app.DynamicWeightsEnabled.Value && isequal([app.DynamicWeightFields.Value],values));
checks{end+1}='four settings/open switch validate and round-trip; base weights are preserved';

app.setBusy(true); assert(strcmp(app.DynamicWeightsEnabled.Enable,'off') && all(strcmp({app.DynamicWeightFields.Enable},'off')));
app.setBusy(false); app.beginRouteEditing(); assert(app.MapEditMode && strcmp(app.DynamicWeightsEnabled.Enable,'off'));
app.cancelRouteEditing(); app.toggleSimulation(); assert(app.SimulationMode && strcmp(app.DynamicWeightsEnabled.Enable,'off'));
app.toggleSimulation();
checks{end+1}='busy, map editing and fixed-cam simulation disable dynamic setting edits';

app.runOptimization(); h=app.History; info=app.OptimizationInfo; project=app.Project;
assert(isequal(project.params.weights,solar.params.weights) && project.params.gearRatio==35);
assert(strcmp(h(end).weightMode,'violation-adaptive-v1') && any([h.weightUpdateIteration]>0));
if isfield(h,'weightChanged'), assert(any([h.weightChanged])); end
assert(contains(app.DynamicWeightSource.Text,sprintf('第%d轮',h(end).weightUpdateIteration)));
assert(app.ScoreDisplayData.dynamicAvailable && isequal(app.ScoreDisplayData.activeWeights,h(end).activeWeights));
assert(isequal(app.ScoreDisplayData.scoreY,[h.score]) && isequal(app.ScoreDisplayData.dynamicY,[h.dynamicScore]));
assert(contains(app.ScoreTrendAxes.Title.String,'固定参照') && contains(app.ObjectiveTrendAxes.Title.String,'权重会变'));
assert(all(abs(str2double(app.WeightsTable.Data(:,3))-h(end).activeWeights(:))<1e-4*max(1,h(end).activeWeights(:))));
app.ScoreBasis.Value='reference'; call(app.ScoreBasis,'ValueChangedFcn'); assertTable(app,false);
app.ScoreBasis.Value='dynamic'; call(app.ScoreBasis,'ValueChangedFcn'); assertTable(app,true);
assert(contains(app.ScoreSummary.Text,'固定参照') && contains(app.ScoreSummary.Text,'动态'));
checks{end+1}='real short search records feed separate score curves, real active weights and matching contribution-table selection';

oldDynamic=app.ScoreDisplayData.dynamicTotal; oldWeights=h(end).activeWeights;
app.WeightsTable.Data{1,2}=2*app.WeightsTable.Data{1,2}; call(app.WeightsTable,'CellEditCallback');
assert(contains(app.ScoreSummary.Text,'历史') && app.ScoreDisplayData.dynamicTotal==oldDynamic);
assert(strcmp(app.WeightsTable.ColumnName{3},'历史') && contains(app.DynamicWeightSource.Text,'历史'));
assert(isequal(app.ScoreDisplayData.activeWeights,oldWeights));
app.calculate(); assert(~app.ScoreDisplayData.dynamicAvailable && isempty(app.ScoreDisplayData.activeWeights));
assert(strcmp(app.ScoreBasis.Value,'dynamic') && isempty(app.ScoreTable.Data) && contains(app.ScoreDisplayData.historyState,'历史'));
restore(app,project,h,info);
app.CrossSource.Value='refined'; call(app.CrossSource,'ValueChangedFcn');
assert(contains(app.ScoreSummary.Text,'加密复查') && isequal(app.ScoreDisplayData.activeWeights,oldWeights));
expected=sum(app.CamInspectionRecord.result.metrics.terms.*oldWeights);
assert(abs(app.ScoreDisplayData.dynamicTotal-expected)<1e-9*max(1,expected));
app.ScoreBasis.Value='dynamic'; call(app.ScoreBasis,'ValueChangedFcn'); assertTable(app,true);
capture(app,folder,'dynamic_refined.png');
app.CrossSource.Value='current'; call(app.CrossSource,'ValueChangedFcn');
checks{end+1}='edited inputs retain historical weights; new unmatched results hide them; dense results re-score matching recorded weights';

app.History=rmfield(h,{'referenceWeights','activeWeights','dynamicScore','weightMode','weightUpdateIteration'});
app.OptimizationInfo=[]; app.updateDiagnostics();
assert(~app.ScoreDisplayData.dynamicAvailable && all(strcmp(app.WeightsTable.Data(:,3),'未记录')));
assert(contains(app.DynamicWeightSource.Text,'未记录'));
assert(isempty(app.ScoreDisplayData.dynamicY));
app.History=[]; app.OptimizationInfo=info; app.updateDiagnostics();
assert(app.ScoreDisplayData.dynamicAvailable && isequal(app.ScoreDisplayData.activeWeights,info.finalActiveWeights));
restore(app,project,h,info);
checks{end+1}='missing old history is never reconstructed from input settings; matched final info is an explicit fallback';

app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1'; call(app.AlgorithmSelector,'ValueChangedFcn');
assert(strcmp(app.Buttons(5).Enable,'off') && all(strcmp({app.DynamicWeightFields.Enable},'off')));
assert(contains(app.DynamicWeightInfo.Text,'暂不支持') && app.DynamicWeightsEnabled.Value);
rejected=false; try, camdesign.optimize(app.Project,[],'fmincon-interior-point-experimental-v1');
catch ex, rejected=strcmp(ex.identifier,'cam:DynamicWeightsBackend'); end
assert(rejected);
app.DynamicWeightsEnabled.Value=false; call(app.DynamicWeightsEnabled,'ValueChangedFcn');
assert(strcmp(app.DynamicWeightsEnabled.Enable,'off') && strcmp(app.Buttons(5).Enable,'on'));
assert(~camdesign.dynamicWeightSettings(app.inputProject().params).enabled);
checks{end+1}='interior-point disables enabling dynamic mode, explains conflicts, permits switching it off and backend rejects unsupported configuration';

restore(app,project,h,info); app.ControlsTabs.SelectedTab=app.WeightsTab;
app.ScoreBasis.Value='dynamic'; call(app.ScoreBasis,'ValueChangedFcn');
for wh={[1320 860],[1120 760]}
    dimensions=wh{1}; app.Figure.Position=[10 10 dimensions]; call(app.Figure,'SizeChangedFcn');
    capture(app,folder,sprintf('dynamic_weights_%dx%d.png',dimensions));
    assert(strcmp(app.DynamicWeightsEnabled.Visible,'on') && isequal(app.ScoreDisplayData.activeWeights,h(end).activeWeights));
    assertTable(app,true);
end
report=struct('release',version('-release'),'checks',{checks},'actualIterations',info.iterations, ...
    'settings',info.dynamicWeights,'referenceWeights',info.referenceWeights,'finalActiveWeights',info.finalActiveWeights, ...
    'referenceScore',app.ScoreDisplayData.total,'dynamicScore',app.ScoreDisplayData.dynamicTotal, ...
    'scope','Owned hidden callbacks and two-iteration integration; no optimizer quality, native pointer or engineering approval.');
save(fullfile(folder,'ui_short_search.mat'),'project','h','info');
fid=fopen(fullfile(folder,'ui_verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('DYNAMIC_UI_CASE_PASS %s\n',checks{k}); end
fprintf('DYNAMIC_WEIGHTS_UI_PASS cases=%d iterations=%d ratio=35\n',numel(checks),info.iterations);
end
function call(object,property)
callback=object.(property); callback(object,[]);
end
function restore(app,project,h,info)
app.Project=project; app.History=h; app.HistoryProject=project; app.OptimizationInfo=info;
app.AlgorithmSelector.Value='peak-gradient-v2'; app.syncInputs(); app.calculate();
end
function assertTable(app,dynamic)
data=app.ScoreDisplayData; expected=data.rows; total=data.total;
if dynamic, expected=data.activeRows; total=data.dynamicTotal; end
assert(isequal(app.ScoreTable.Data,expected));
assert(abs(sum(cell2mat(expected(:,4)))-total)<1e-9*max(1,total));
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow; exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
