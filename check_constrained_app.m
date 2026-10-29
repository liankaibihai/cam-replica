function check_constrained_app()
assert(batchStartupOptionUsed,'cam:ConstrainedAppBatchOnly','请使用独立 batch 运行 UI 检查。');
root=fileparts(mfilename('fullpath')); addpath(root);
app=CamReplicaApp('off'); cleaner=onCleanup(@()delete(app.Figure));
assert(strcmp(app.AlgorithmSelector.Value,'peak-gradient-v2'));
assert(ismember('fmincon-interior-point-experimental-v1',app.AlgorithmSelector.ItemsData));
app.AlgorithmSelector.Value='fmincon-interior-point-experimental-v1';
app.Project.params.samples=101; app.Project.params.camSamples=181; app.Project.params.iterations=1;
original=app.Project; app.syncInputs(); app.runOptimization();
assert(~app.Busy && strcmp(app.OptimizationInfo.algorithm,'fmincon-interior-point-experimental-v1'));
assert(isequaln(app.Project.params,original.params) && isequal(app.Project.nodes(1,:),original.nodes(1,:)));
assert(isfield(app.History,'objective') && isfield(app.OptimizationInfo,'verification'));
if app.OptimizationInfo.verifiedFeasible
    assert(contains(app.Status.Text,'加密离散模型检查通过'));
else
    assert(contains(app.Status.Text,'加密验收未通过或未完成'));
end
assert(contains(strjoin(app.Log.Value,newline),'历史评分仅供对照'));
folder=fullfile(root,'outputs','constrained_optimizer'); if ~isfolder(folder), mkdir(folder); end
drawnow;
exportapp(app.Figure,fullfile(folder,'constrained_app_preview.png'));
fprintf('CONSTRAINED_APP_PASS default retained, experimental dispatch, reporting and refined verdict\n');
end
