function report=check_training_convergence(requested)
% Real solar flat input; explicit independent curve/search settings.
if nargin<1, requested=300; end
assert(batchStartupOptionUsed && ismember(requested,[300 1000]));
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','training_controls_20261030',sprintf('convergence_%d',requested));
assert(~isfile(fullfile(folder,'verification.json')),'cam:TrainingArchiveExists','拒绝覆盖既有预算记录。');
if ~isfolder(folder), mkdir(folder); end
base=camdesign.solarTestProject(); base.params.iterations=requested;
algorithms={'fmincon-interior-point-experimental-v1','peak-gradient-v2'};
modes={'cubic','bezier-blend-independent-v1'}; cases={};
for kind=1:2
    for backend=1:2
        changes=struct('routeModel',modes{kind},'controlPointCount',50, ...
            'interpolationPerSegment',11,'iterations',requested);
        if kind==2, changes.bezierDegree=15; end
        if backend==2
            changes.gradientForce=.5; changes.learningRate=.3; changes.smoothingRate=.4;
            changes.adjustInterval=100; changes.adjustExponent=1;
        end
        [project,settingsInfo]=camdesign.applyTrainingSettings(base,changes,algorithms{backend});
        assert(isequal(project.targets,base.targets) && size(project.nodes,1)==50 && project.params.samples==540);
        initial=camdesign.verifyConstrained(project,4);
        assert(initial.optimizationGrid.valid,'cam:TrainingInitial','所选训练模式初始几何无效：%s',initial.optimizationGrid.errorMessage);
        if backend==1
            [q,h,info]=camdesign.optimizeFmincon(project,[],MaxSeconds=600, ...
                MaxFunctionEvaluations=max(30000,4*(2*(size(project.nodes,1)-1)+1)*(requested+1)));
        else
            [q,h,info]=camdesign.optimize(project,[],algorithms{backend});
        end
        assert(isequaln(q.params,project.params) && isequal(q.targets,base.targets) && isequal(q.nodes(1,:),base.nodes(1,:)));
        final=camdesign.verifyConstrained(q,4); extra=camdesign.verifyConstrained(q,8);
        fine=q; fine.params.samples=8*(q.params.samples-1)+1; fine.params.camSamples=8*(q.params.camSamples-1)+1;
        r=camdesign.evaluate(fine,true); rules=camdesign.auditSolarRoute(r.route,q.targets,q.params.bounds);
        if backend==1, trend=[h.solverMaxViolation]; else, trend=[h.score]; end
        first=max(1,numel(trend)-10); tail=(trend(first)-trend(end))/max(abs(trend(first)),1e-12);
        label=sprintf('%s_%s',modes{kind},algorithms{backend});
        item=struct('label',label,'settings',camdesign.trainingSettings(project),'settingsInfo',settingsInfo, ...
            'initial',initial,'info',info,'final4x',final,'final8x',extra,'ruleAudit',rules, ...
            'history',h,'geometryPassIncluding8x',final.verifiedFeasible && extra.verifiedFeasible, ...
            'lastTenEntryReductionFraction',tail, ...
            'extendRecommended',info.iterations>=requested && tail>.01 && ~extra.verifiedFeasible);
        cases{end+1}=item; %#ok<AGROW>
        save(fullfile(folder,[label,'.mat']),'project','q','h','info','final','extra','rules');
        camdesign.saveProject(q,fullfile(folder,[label,'_project.mat']));
        report=struct('release',version('-release'),'requestedIterations',requested,'cases',{cases}, ...
            'scope','Solar flat: cubic vs independent Bernstein blend, 50 control points, nominal 11 intervals per segment, explicit independent search schedule. Physical dimensions and engineering limits retained. No original-app or real-car equivalence.');
        fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
        fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fclose(fid);
        fprintf('TRAINING_LONG %s actual=%d/%d reason=%s pressure8x=%.9f hit8x=%.9f outside8x=%.9f pass=%d tail=%.6g\n', ...
            label,info.iterations,requested,info.reason,r.metrics.maxPressureDeg,r.metrics.maxHitError, ...
            extra.maxTrajectoryOutsideMM,item.geometryPassIncluding8x,tail);
    end
end
fprintf('TRAINING_LONG_RECORDED cases=%d extendRecommended=%d\n',numel(cases),any(cellfun(@(x)x.extendRecommended,cases)));
end
