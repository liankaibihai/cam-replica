function report=check_auto_score_view_ui()
% Replay real recorded weights through UI updates; no optimizer is started.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:AutoScoreBatch','Use an independent batch.');
folder=fullfile(root,'outputs','auto_score_view_20261030'); if ~isfolder(folder), mkdir(folder); end
source=fullfile(root,'outputs','dynamic_weights_20261030','ui_short_search.mat'); saved=load(source,'project','h','info');
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
assert(strcmp(app.ScoreBasis.Value,'auto') && strcmp(app.ScoreBasis.Enable,'on'));
assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.rows) && contains(app.ScoreViewStatus.Text,'待记录'));
app.Project=saved.project; app.syncInputs(); app.calculate();
assert(strcmp(app.ScoreBasis.Value,'auto') && isempty(app.ScoreDisplayData.activeWeights));
app.optimizationUpdate(saved.h(end).iteration,saved.project,saved.h); app.calculate();
assertActual(app); assert(strcmp(app.ScoreBasis.Value,'auto'));
assert(isequal(app.ScoreDisplayData.scoreY,[saved.h.score]) && contains(app.ScoreTrendAxes.Title.String,'固定参照'));
checks{end+1}='default automatic view survives missing records and switches to real active weights when a matching callback arrives';

app.ScoreBasis.Value='reference'; call(app.ScoreBasis,'ValueChangedFcn');
app.optimizationUpdate(saved.h(end).iteration,saved.project,saved.h); app.calculate();
assert(strcmp(app.ScoreBasis.Value,'reference') && isequal(app.ScoreTable.Data,app.ScoreDisplayData.rows));
assert(contains(app.ScoreViewStatus.Text,'固定参照'));
app.ScoreBasis.Value='dynamic'; call(app.ScoreBasis,'ValueChangedFcn'); assertActual(app);
app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.updateDiagnostics();
assert(strcmp(app.ScoreBasis.Value,'dynamic') && isempty(app.ScoreTable.Data) && contains(app.ScoreViewStatus.Text,'待记录'));
app.calculate(); assert(strcmp(app.ScoreBasis.Value,'dynamic') && isempty(app.ScoreTable.Data));
app.optimizationUpdate(saved.h(end).iteration,saved.project,saved.h); app.calculate();
assert(strcmp(app.ScoreBasis.Value,'dynamic')); assertActual(app);
checks{end+1}='explicit fixed/dynamic choices survive calculation and callbacks; missing dynamic data stays pending without changing the choice';

app.ScoreBasis.Value='auto'; call(app.ScoreBasis,'ValueChangedFcn');
oldWeights=app.ScoreDisplayData.activeWeights; oldRows=app.ScoreTable.Data;
app.WeightsTable.Data{1,2}=2*app.WeightsTable.Data{1,2}; call(app.WeightsTable,'CellEditCallback');
assert(isequal(app.ScoreTable.Data,oldRows) && contains(app.ScoreViewStatus.Text,'历史'));
assert(isequal(app.ScoreDisplayData.activeWeights,oldWeights));
app.calculate();
assert(strcmp(app.ScoreBasis.Value,'auto') && isempty(app.ScoreDisplayData.activeWeights));
assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.rows) && contains(app.ScoreViewStatus.Text,'待记录'));
restore(app,saved);
app.CrossSource.Value='refined'; call(app.CrossSource,'ValueChangedFcn'); assertActual(app);
assert(strcmp(app.ScoreBasis.Value,'auto') && contains(app.ScoreViewStatus.Text,'加密'));
expected=sum(app.CamInspectionRecord.result.metrics.terms.*saved.h(end).activeWeights);
assert(abs(app.ScoreDisplayData.activeTotal-expected)<1e-9*max(1,expected));
app.CrossSource.Value='current'; call(app.CrossSource,'ValueChangedFcn');
checks{end+1}='automatic view labels cached historical weights, rejects unmatched records and re-scores a matching dense grid';

legacy=rmfield(saved.h,{'referenceWeights','activeWeights','dynamicScore','weightMode','weightUpdateIteration'});
app.History=legacy; app.OptimizationInfo=[]; app.updateDiagnostics();
assert(strcmp(app.ScoreBasis.Value,'auto') && isempty(app.ScoreDisplayData.activeWeights));
assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.rows) && contains(app.ScoreViewStatus.Text,'待记录'));
restore(app,saved); call(app.ScoreDetailsButton,'ButtonPushedFcn');
tables=findobj(app.DiagnosticsFigure,'Type','uitable'); matched=0;
for table=tables'
    if size(table.Data,2)==4, assert(isequal(table.Data,app.ScoreDisplayData.activeRows)); matched=matched+1; end
end
assert(matched==1);
checks{end+1}='old records never invent actual weights; main and detailed score tables share the automatic basis';

app.ControlsTabs.SelectedTab=app.WeightsTab;
for wh={[1320 860],[1120 760]}
    dimensions=wh{1}; app.Figure.Position=[10 10 dimensions]; call(app.Figure,'SizeChangedFcn');
    capture(app,folder,sprintf('auto_actual_%dx%d.png',dimensions)); assertActual(app);
    assert(strcmp(app.ScoreTable.ColumnName{3},'实际') && strcmp(app.ScoreTable.ColumnName{4},'动态贡献'));
    assert(contains(app.ScoreViewStatus.Text,'实际动态权重'));
end
app.History=[]; app.HistoryProject=[]; app.OptimizationInfo=[]; app.updateDiagnostics();
capture(app,folder,'auto_waiting_1120x760.png');
app.ScoreBasis.Value='dynamic'; call(app.ScoreBasis,'ValueChangedFcn');
capture(app,folder,'manual_dynamic_waiting.png');
assert(strcmp(app.ScoreBasis.Value,'dynamic') && isempty(app.ScoreTable.Data));
checks{end+1}='automatic/actual/pending labels and short headers stay visible at 1320 and 1120; manual pending view remains explicit';

report=struct('release',version('-release'),'checks',{checks},'source',source,'optimizerRun',false, ...
    'referenceWeights',saved.h(end).referenceWeights,'activeWeights',saved.h(end).activeWeights, ...
    'defaultView','auto','scope','Owned hidden UI record replay and layout only; no optimization quality experiment.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('AUTO_SCORE_CASE_PASS %s\n',checks{k}); end
fprintf('AUTO_SCORE_VIEW_UI_PASS cases=%d optimizerRun=false default=auto\n',numel(checks));
end
function restore(app,saved)
app.Project=saved.project; app.History=saved.h; app.HistoryProject=saved.project; app.OptimizationInfo=saved.info;
app.syncInputs(); app.calculate();
end
function assertActual(app)
data=app.ScoreDisplayData;
assert(data.dynamicAvailable && isequal(app.ScoreTable.Data,data.activeRows));
assert(isequal(cell2mat(app.ScoreTable.Data(:,3)),data.activeWeights(:)));
assert(abs(sum(cell2mat(app.ScoreTable.Data(:,4)))-data.dynamicTotal)<1e-9*max(1,data.dynamicTotal));
end
function call(object,property)
callback=object.(property); cam_invoke_ui_callback(callback,object,[]);
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow; exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
