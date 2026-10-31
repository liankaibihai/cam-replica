function report=check_route_length_ui()
% Display-only checks; calculate existing routes and replay a saved optimizer
% output without starting any optimizer or touching another MATLAB window.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:LengthBatchOnly','Use an independent batch.');
folder=fullfile(root,'outputs','route_length_20261030'); if ~isfolder(folder), mkdir(folder); end
app=CamReplicaApp('off'); cleaner=onCleanup(@()closeOwn(app)); checks={};
app.Project=camdesign.solarTestProject(); app.syncInputs(); app.calculate();
assertLengths(app,app.Result.metrics);
initial=app.Result.metrics; initialText=app.LengthSummary.Text;
assert(contains(initialText,'总路程（前轮轨迹）') && contains(initialText,'主动轮行程'));
assert(contains(app.LengthSummary.Tooltip,'不是评分表中归一化'));
assert(app.LengthSummary.Parent==app.ResultsTabs.Parent);
assert(app.ScoreDisplayData.routeLengthMM~=app.Result.metrics.terms(2));
checks{end+1}='current raw route/drive lengths display in metres and millimetres, separately from the normalized score';

app.NodesTable.Data(2,1)=app.NodesTable.Data(2,1)+1;
callback=app.NodesTable.CellEditCallback; cam_invoke_ui_callback(callback,app.NodesTable,[]);
assert(contains(app.LengthSummary.Text,'历史 / 待重算') && contains(app.ScoreSummary.Text,'历史 / 待重算'));
assert(app.ScoreDisplayData.routeLengthMM==initial.routeLength && app.ScoreDisplayData.driveLengthMM==initial.driveLength);
app.calculate(); assertLengths(app,app.Result.metrics);
assert(contains(app.LengthSummary.Text,'当前计算') && ~contains(app.LengthSummary.Text,'历史'));
assert(app.ScoreDisplayData.routeLengthMM~=initial.routeLength);
checks{end+1}='input edits label cached lengths historical; recalculation refreshes both lengths from the new result';

coarse=app.Result; base=app.Project;
app.CrossSource.Value='refined'; callback=app.CrossSource.ValueChangedFcn; cam_invoke_ui_callback(callback,app.CrossSource,[]);
fine=app.CamInspectionRecord.result; assertLengths(app,fine.metrics);
assert(contains(app.LengthSummary.Text,'加密复查') && strcmp(app.CamInspectionRecord.source,'refined'));
assert(isequaln(app.Project,base) && isequaln(app.Result,coarse));
capture(app,folder,'refined_lengths.png');
app.CrossSource.Value='current'; cam_invoke_ui_callback(callback,app.CrossSource,[]); assertLengths(app,coarse.metrics);
assert(contains(app.LengthSummary.Text,'当前计算'));
checks{end+1}='fine/coarse source switches refresh lengths from the same displayed grid without changing the project';

source=fullfile(root,'outputs','fixed_ratio_results_20261030','convergence_300','solar_fixed35_candidate.mat');
saved=load(source,'q','h','info');
app.Project=saved.q; app.History=saved.h; app.HistoryProject=saved.q; app.OptimizationInfo=saved.info;
app.AlgorithmSelector.Value=saved.info.algorithm;
app.syncInputs(); app.calculate(); assertLengths(app,app.Result.metrics);
assert(isequaln(app.History,saved.h) && app.OptimizationInfo.iterations==saved.info.iterations);
assert(app.Project.params.gearRatio==35 && contains(app.LengthSummary.Text,'当前计算'));
optimized=app.Result.metrics; optimizedText=app.LengthSummary.Text;
checks{end+1}='saved optimization output refreshes lengths through the final calculation/render path; no optimization is run';

original=app.CamInspectionRecord;
missing=original; missing.result.metrics=rmfield(missing.result.metrics,{'routeLength','driveLength'});
app.CamInspectionRecord=missing; app.updateDiagnostics();
assert(count(app.LengthSummary.Text,'待计算')==2 && ~contains(app.LengthSummary.Text,'NaN'));
assert(isnan(app.ScoreDisplayData.routeLengthMM) && isnan(app.ScoreDisplayData.driveLengthMM));
empty=camdesign.resultDisplayData([],[],[],[]);
assert(isnan(empty.routeLengthMM) && isnan(empty.driveLengthMM));
app.CamInspectionRecord=original; app.updateDiagnostics(); assertLengths(app,optimized);
checks{end+1}='missing result/metric fields remain missing and display pending calculation rather than a zero';

for dimensions={[1320 860],[1120 760]}
    wh=dimensions{1}; app.Figure.Position=[10 10 wh]; callback=app.Figure.SizeChangedFcn; cam_invoke_ui_callback(callback,app.Figure,[]);
    callback=app.TrainingShortcut.ButtonPushedFcn; cam_invoke_ui_callback(callback,app.TrainingShortcut,[]);
    tabs=app.ResultsTabs.Children;
    for k=1:numel(tabs)
        app.ResultsTabs.SelectedTab=tabs(k); drawnow;
        assert(strcmp(app.LengthSummary.Visible,'on') && strcmp(app.LengthSummary.Text,optimizedText));
    end
    scoreTab=tabs(strcmp({tabs.Title},'评分与趋势')); app.ResultsTabs.SelectedTab=scoreTab;
    capture(app,folder,sprintf('route_length_%dx%d.png',wh));
    labelPosition=getpixelposition(app.LengthSummary,true);
    assert(all(labelPosition(1:2)>=0) && all(labelPosition(1:2)+labelPosition(3:4)<=wh+1));
    assert(app.LengthSummary.Position(3)>=wh(1)-30 && app.LengthSummary.Position(4)>=28);
    assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.rows) && size(app.ScoreTable.Data,1)==6);
    assert(isequaln(app.Project,saved.q) && app.Result.metrics.routeLength==optimized.routeLength);
end
checks{end+1}='persistent length strip stays visible across result tabs and two window sizes; numerical results remain unchanged';

report=struct('release',version('-release'),'checks',{checks},'initialLengthsMM', ...
    [initial.routeLength initial.driveLength],'optimizedLengthsMM',[optimized.routeLength optimized.driveLength], ...
    'optimizedText',optimizedText,'savedOptimizerSource',source,'optimizerRun',false, ...
    'scope','Owned hidden app only, raw metric display/source/layout checks; no physical algorithm changes or optimization rerun.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for k=1:numel(checks), fprintf('ROUTE_LENGTH_CASE_PASS %s\n',checks{k}); end
fprintf('ROUTE_LENGTH_UI_PASS cases=%d routeMM=%.9f driveMM=%.9f optimizerRun=false\n',numel(checks),optimized.routeLength,optimized.driveLength);
end
function assertLengths(app,metrics)
assert(app.ScoreDisplayData.routeLengthMM==metrics.routeLength && app.ScoreDisplayData.driveLengthMM==metrics.driveLength);
assert(contains(app.LengthSummary.Text,sprintf('%.3f m（%.2f mm）',metrics.routeLength/1000,metrics.routeLength)));
assert(contains(app.LengthSummary.Text,sprintf('%.3f m（%.2f mm）',metrics.driveLength/1000,metrics.driveLength)));
end
function capture(app,folder,name)
drawnow; exportapp(app.Figure,fullfile(folder,name)); pause(.15); drawnow;
exportapp(app.Figure,fullfile(folder,name));
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
