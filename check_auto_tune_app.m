function report=check_auto_tune_app()
% Exercise the actual optimize button lifecycle in an owned hidden instance.
% The tiny budget checks wiring only; it says nothing about tuning quality.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
folder=fullfile(fileparts(mfilename('fullpath')),'outputs','auto_tune_20261030','app');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject();
project.params.autoTune=struct('trials',2,'maxIterations',1,'seed',2027,'polishCount',0);
project.params.dynamicWeights=struct('enabled',true);
app=CamReplicaApp('off'); cleanup=onCleanup(@()closeOwn(app));
app.Project=project; app.syncInputs(); app.calculate();
app.AlgorithmSelector.Value='auto-tune-v1'; callback=app.AlgorithmSelector.ValueChangedFcn; cam_invoke_ui_callback(callback,app.AlgorithmSelector,[]);
callback=app.Buttons(5).ButtonPushedFcn; cam_invoke_ui_callback(callback,app.Buttons(5),[]);
assert(~app.Busy && isstruct(app.OptimizationInfo) && app.OptimizationInfo.fullAuto);
assert(strcmp(app.History(end).autoStage,'complete') && app.OptimizationInfo.iterations<=2);
assert(app.Project.params.gearRatio==35 && isequal(app.Project.params.weights,project.params.weights));
assert(app.Project.params.dynamicWeights.enabled && strcmp(app.DynamicWeightsEnabled.Enable,'off'));
assert(isequaln(app.Project,app.HistoryProject) && isequaln(app.Project,app.CamInspectionRecord.project));
assert(isequal(app.ScoreDisplayData.activeWeights,app.OptimizationInfo.finalActiveWeights));
assert(isequal(app.ScoreTable.Data,app.ScoreDisplayData.activeRows));
assert(contains(app.Status.Text,'未通过') && ~app.OptimizationInfo.verifiedFeasible);
q=app.Project; h=app.History; info=app.OptimizationInfo;
save(fullfile(folder,'button_run.mat'),'project','q','h','info');
report=struct('release',version('-release'),'optimizerRun',true,'actualIterations',info.iterations, ...
    'checks',{{'actual button dispatch returns through full-auto finish and restores nonbusy controls', ...
    'selected project, history, display, active weights and fixed user parameters stay consistent', ...
    'short-run failures remain failures in visible final status'}}, ...
    'scope','End-to-end UI wiring only; two total rounds are not a quality assessment.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fprintf('AUTO_TUNE_APP_PASS iterations=%d qualityAssessment=false\n',info.iterations);
end
function closeOwn(app)
if ~isempty(app.DiagnosticsFigure) && isgraphics(app.DiagnosticsFigure), delete(app.DiagnosticsFigure); end
if isgraphics(app.Figure), delete(app.Figure); end
end
