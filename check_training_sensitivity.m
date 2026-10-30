function report=check_training_sensitivity()
% Explicit numerical/initialization diagnostics; do not change UI defaults.
assert(batchStartupOptionUsed);
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','training_controls_20261030','sensitivity_300');
assert(~isfile(fullfile(folder,'verification.json')),'cam:TrainingSensitivityArchive','拒绝覆盖既有敏感性报告。');
if ~isfolder(folder), mkdir(folder); end
base=camdesign.solarTestProject();
warm=load(fullfile(root,'outputs','trajectory_bounds_20261029','convergence_300','same_initial_curve.mat'));
labels={'cold_degree15_forward005','cold_degree7_forward005','warm_degree7_forward005','cold_degree15_central0005'};
degrees=[15 7 7 15]; steps=[.05 .05 .05 .005]; types={'forward','forward','forward','central'};
cases={};
for k=1:numel(labels)
    source=base; if k==3, source=warm.q; end
    changes=struct('routeModel','bezier-blend-independent-v1','controlPointCount',50, ...
        'interpolationPerSegment',11,'bezierDegree',degrees(k),'iterations',300);
    project=camdesign.applyTrainingSettings(source,changes,'fmincon-interior-point-experimental-v1');
    initial=camdesign.verifyConstrained(project,4);
    [q,h,info]=camdesign.optimizeFmincon(project,[],MaxSeconds=600,MaxFunctionEvaluations=120000, ...
        DifferenceStepMM=steps(k),DifferenceType=types{k});
    assert(isequaln(project.params,q.params) && isequal(project.targets,q.targets));
    final=camdesign.verifyConstrained(q,8);
    cases{end+1}=struct('label',labels{k},'initial',initial,'info',info,'final8x',final); %#ok<AGROW>
    save(fullfile(folder,[labels{k},'.mat']),'project','q','h','info','final');
    camdesign.saveProject(q,fullfile(folder,[labels{k},'_project.mat']));
    report=struct('release',version('-release'),'cases',{cases}, ...
        'scope','Explicit degree, initialization and finite-difference diagnostics at 300 requested rounds/120000 evaluations/600 second soft budgets. Default settings and all physical dimensions/thresholds unchanged.');
    fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
    fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fclose(fid);
    fprintf('TRAINING_SENSITIVITY %s actual=%d/300 reason=%s pressure8x=%.9f hit8x=%.9f outside8x=%.9f pass=%d\n', ...
        labels{k},info.iterations,info.reason,final.refinedGrid.metrics.maxPressureDeg, ...
        final.refinedGrid.metrics.maxHitError,final.maxTrajectoryOutsideMM,final.verifiedFeasible);
end
end
