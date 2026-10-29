function report=check_solar_flat(requestedIterations)
% Same official preliminary input for both independent numerical backends.
if nargin<1, requestedIterations=300; end
assert(batchStartupOptionUsed,'cam:SolarBatchOnly','请使用独立 batch 运行。');
assert(ismember(requestedIterations,[300 1000]));
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','solar_flat_20261029',sprintf('iterations_%d',requestedIterations));
assert(~isfile(fullfile(folder,'verification.json')),'cam:SolarArchiveExists','已有记录，拒绝覆盖。');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject(); project.params.iterations=requestedIterations;
expected=[410 420;700 1580;1440 1100;3170 1560;4160 1440;5110 1630;5450 440;3250 350;2500 750;410 420];
assert(isequal(project.targets,expected) && strcmp(project.params.mechanism,'flat'));
assert(size(unique(project.targets,'rows'),1)==9 && size(project.targets,1)==10);
assert(isequal(project.params.bounds,[0 6000 0 2000]));
baseline=camdesign.verifyConstrained(project,4);
save(fullfile(folder,'initial_project.mat'),'project');
report=struct('release',version('-release'),'requestedIterations',requestedIterations, ...
    'project',project,'baseline',baseline,'cases',{{}}, ...
    'scope','Solar preliminary flat mechanism; unmeasured vehicle sizing and launch assumptions. Discrete model only, no original-app or vehicle equivalence.');
writeReport(report,fullfile(folder,'initial_verification.json'));
assert(baseline.optimizationGrid.valid,'cam:SolarInitialGeometry','初始测试项目无法计算：%s',baseline.optimizationGrid.errorMessage);
algorithms={'peak-gradient-v2','fmincon-interior-point-experimental-v1'};
cases=cell(1,2);
for k=1:2
    if k==1
        [q,h,info]=camdesign.optimize(project,[],algorithms{k});
        verification=camdesign.verifyConstrained(q,4);
    else
        [q,h,info]=camdesign.optimizeFmincon(project,[],MaxSeconds=600, ...
            MaxFunctionEvaluations=max(30000,100*requestedIterations));
        verification=info.verification;
    end
    assert(isequaln(q.params,project.params) && isequal(q.targets,project.targets));
    assert(isequal(q.nodes(1,:),project.nodes(1,:)));
    evaluated=camdesign.evaluate(q,true);
    assert(all(diff(evaluated.hits.indices)>0),'Ordered visits were not preserved.');
    if k==1, trend=[h.score]; else, trend=[h.solverMaxViolation]; end
    first=max(1,numel(trend)-10);
    reduction=(trend(first)-trend(end))/max(abs(trend(first)),1e-12);
    extend=info.iterations>=requestedIterations && reduction>.01 && ~verification.verifiedFeasible;
    cases{k}=struct('algorithm',algorithms{k},'info',info,'verification',verification, ...
        'history',h,'lastTenEntryReductionFraction',reduction,'extendBudgetRecommended',extend);
    save(fullfile(folder,[algorithms{k},'.mat']),'project','q','h','info','verification');
    plotHistory(h,fullfile(folder,[algorithms{k},'.png']),algorithms{k});
    report.cases=cases(1:k); writeReport(report,fullfile(folder,'verification.json'));
    fine=verification.refinedGrid;
    if fine.valid
        fprintf('SOLAR_FLAT %s requested=%d actual=%d reason=%s evals=%d finePressure=%.6f fineHit=%.6f fineSteering=%.6f undercut=%.6f intersections=%d verified=%d tailReduction=%.6f\n', ...
            algorithms{k},requestedIterations,info.iterations,info.reason,info.evaluations, ...
            fine.metrics.maxPressureDeg,fine.metrics.maxHitError,fine.metrics.maxSteeringDeg, ...
            fine.metrics.minUndercutMargin,fine.metrics.intersectionCount,verification.verifiedFeasible,reduction);
    else
        fprintf('SOLAR_FLAT %s requested=%d actual=%d reason=%s fineInvalid=%s\n', ...
            algorithms{k},requestedIterations,info.iterations,info.reason,fine.errorIdentifier);
    end
end
fprintf('SOLAR_FLAT_RECORDED requested=%d cases=%d; engineering status stored separately.\n',requestedIterations,numel(cases));
end

function writeReport(report,path)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0); closer=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end

function plotHistory(h,path,label)
f=figure('Visible','off','Position',[50 50 1100 700]); cleaner=onCleanup(@()close(f));
t=tiledlayout(f,2,2); title(t,label,'Interpreter','none');
a=nexttile(t); plot(a,[h.iteration],[h.score]); title(a,'Retained peak score');
a=nexttile(t); plot(a,[h.iteration],arrayfun(@(x)x.metrics.maxPressureDeg,h)); yline(a,35,'--'); title(a,'Maximum pressure / deg');
a=nexttile(t); plot(a,[h.iteration],[h.maxHitError]); yline(a,30,'--'); title(a,'Ordered hit error / mm');
a=nexttile(t); plot(a,[h.iteration],arrayfun(@(x)x.metrics.maxSteeringDeg,h)); yline(a,65,'--'); title(a,'Maximum steering / deg');
for a=findall(f,'Type','axes')', grid(a,'on'); xlabel(a,'Actual iteration'); end
exportgraphics(f,path,'Resolution',130);
end
