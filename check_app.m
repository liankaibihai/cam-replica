function check_app()
root=fileparts(mfilename('fullpath')); addpath(root);
fprintf('APP_CHECK_START\n');
app=CamReplicaApp('off'); cleaner=onCleanup(@()delete(app.Figure));
fprintf('APP_CONSTRUCTED\n');
assert(~isempty(app.Result) && isfinite(app.Result.metrics.score));
original=app.TargetsTable.Data;
app.SelectedTargetRow=1; app.modifyPoints('target',1); assert(size(app.TargetsTable.Data,1)==size(original,1)+1);
app.SelectedTargetRow=2; app.modifyPoints('target',-1); assert(isequal(app.TargetsTable.Data,original));
app.Mechanism.Value='flat'; app.calculate();
assert(strcmp(app.Project.params.mechanism,'flat'));
app.Mechanism.Value='rack'; app.calculate();
app.action('simulate');
app.Project.params.iterations=2; app.syncInputs(); app.runOptimization();
assert(~app.Busy && ~isempty(app.History));
app.Figure.Visible='on'; drawnow;
exportapp(app.Figure,fullfile(root,'outputs','app_preview.png'));
fprintf('APP_CHECK_PASS\n');
end
