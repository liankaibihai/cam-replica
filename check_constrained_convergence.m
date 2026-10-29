function report=check_constrained_convergence(requestedIterations)
% Long-budget diagnostic, without changing geometric inputs or thresholds.
if nargin<1, requestedIterations=300; end
assert(ismember(requestedIterations,[300,1000]));
assert(batchStartupOptionUsed,'cam:ConvergenceBatchOnly','请使用独立 batch 运行。');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','constrained_optimizer','interior_point',sprintf('convergence_%d',requestedIterations));
assert(~isfile(fullfile(folder,'verification.json')),'cam:ConvergenceArchiveExists','已有该预算的诊断，拒绝覆盖历史记录。');
if ~isfolder(folder), mkdir(folder); end
cases=cell(1,2); kinds={'rack','flat'}; maxFunctions=max(30000,100*requestedIterations); maxSeconds=180;
for k=1:2
    project=camdesign.defaultProject(); project.params.mechanism=kinds{k};
    project.params.iterations=requestedIterations;
    [q,h,info]=camdesign.optimizeFmincon(project,[],Algorithm='interior-point', ...
        MaxFunctionEvaluations=maxFunctions,MaxSeconds=maxSeconds);
    assert(isequaln(q.params,project.params) && isequal(q.nodes(1,:),project.nodes(1,:)));
    assert(isequal([q.params.maxPressureDeg,q.params.maxSteeringDeg,q.params.hitTolerance],[35 65 30]));
    % Raw solver iterates and retained candidates are both recorded, separately.
    rounds=[h.iteration]; [~,keep]=unique(rounds,'stable'); uniqueHistory=h(keep);
    violation=[uniqueHistory.solverMaxViolation]; tail=max(1,numel(violation)-5);
    fractionalTailReduction=(violation(tail)-violation(end))/max(1e-12,violation(tail));
    reached=info.iterations>=requestedIterations;
    extend=reached && fractionalTailReduction>0.01 && ~info.verifiedFeasible;
    cases{k}=struct('mechanism',kinds{k},'requestedIterations',requestedIterations, ...
        'actualIterations',info.iterations,'reachedRequestedIterations',reached, ...
        'maxFunctionEvaluations',maxFunctions,'maxSecondsSoft',maxSeconds, ...
        'info',info,'history',h,'lastFiveIterationViolationReductionFraction',fractionalTailReduction, ...
        'extendTo1000Recommended',extend, ...
        'interpretation','Local solver termination and discrete validation only. Early termination is not completion of requested rounds, nor proof of global infeasibility or algorithm incapability.');
    save(fullfile(folder,[kinds{k},'.mat']),'project','q','h','info');
    convergenceFigure(h,info,fullfile(folder,[kinds{k},'_convergence.png']),kinds{k},requestedIterations);
    fine=info.verification.refinedGrid;
    finePressure=NaN; fineHit=NaN; fineUnder=NaN; fineIntersections=NaN;
    if fine.valid
        finePressure=fine.metrics.maxPressureDeg; fineHit=fine.metrics.maxHitError;
        fineUnder=fine.metrics.minUndercutMargin; fineIntersections=fine.metrics.intersectionCount;
    end
    fprintf('CONSTRAINED_LONG %s requested=%d actual=%d seconds=%.3f physicalEvals=%d funcCount=%d reason=%s exitflag=%d returnedViolation=%.9g solverViolation=%.9g finePressure=%.9f fineHit=%.9f fineUnder=%.9g fineIntersections=%d verified=%d tailReduction=%.9g\n', ...
        kinds{k},requestedIterations,info.iterations,info.elapsedSeconds,info.evaluations, ...
        info.solverOutput.funcCount,info.reason,info.solverExitflag,info.returnedMaxViolation, ...
        info.solverTerminalViolation,finePressure,fineHit,fineUnder,fineIntersections,info.verifiedFeasible,fractionalTailReduction);
    fprintf('CONSTRAINED_TERMINATION %s %s\n',kinds{k},strrep(info.solverOutput.message,newline,' '));
end
report=struct('release',version('-release'),'requestedIterations',requestedIterations, ...
    'maxFunctionEvaluations',maxFunctions,'maxSecondsSoft',maxSeconds,'cases',{cases}, ...
    'thresholds',[35 65 30],'parametersChangedForBudgetOnly',{'iterations'}, ...
    'scope','Identical default geometric inputs and autoRatio policy; independent long-budget record, no overwrite of 30-round or SQP histories.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONSTRAINED_LONG_RECORDED requested=%d cases=%d actual=%d,%d\n',requestedIterations,numel(cases),cases{1}.actualIterations,cases{2}.actualIterations);
if requestedIterations==300 && any(cellfun(@(item)item.extendTo1000Recommended,cases))
    check_constrained_convergence(1000);
end
end

function convergenceFigure(h,info,path,mechanism,requested)
iteration=[h.iteration]; objective=[h.solverObjective]; violation=[h.solverMaxViolation];
pressure=nan(size(h)); hit=pressure;
for j=1:numel(h)
    if h(j).solverValid
        pressure(j)=h(j).solverMetrics.maxPressureDeg; hit(j)=h(j).solverMetrics.maxHitError;
    end
end
f=figure('Visible','off','Position',[80 80 1250 900]); closer=onCleanup(@()close(f));
t=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
title(t,sprintf('%s | requested %d, actual %d | %s',mechanism,requested,info.iterations,info.reason),'Interpreter','none');
a=nexttile(t); plot(a,iteration,objective,'Color',[.1 .35 .6]); hold(a,'on'); plot(a,iteration,[h.objective],'--','Color',[.85 .35 .1]);
title(a,'Smooth constrained objective'); legend(a,{'Raw solver iterate','Retained candidate'},'Location','best');
a=nexttile(t); plot(a,iteration,pressure,'Color',[.1 .35 .6]); hold(a,'on'); plot(a,iteration,arrayfun(@(x)x.metrics.maxPressureDeg,h),'--','Color',[.85 .35 .1]); yline(a,35,'k--','35 deg');
title(a,'Maximum pressure, including return'); ylabel(a,'deg');
a=nexttile(t); plot(a,iteration,hit,'Color',[.1 .35 .6]); hold(a,'on'); plot(a,iteration,[h.maxHitError],'--','Color',[.85 .35 .1]); yline(a,30,'k--','30 mm');
title(a,'Maximum ordered hit error'); ylabel(a,'mm');
a=nexttile(t); plot(a,iteration,violation,'Color',[.1 .35 .6]); hold(a,'on'); plot(a,iteration,[h.maxConstraintViolation],'--','Color',[.85 .35 .1]); yline(a,0,'k--');
title(a,'Maximum positive normalized residual');
for a=findall(f,'Type','axes')', grid(a,'on'); xlabel(a,'Actual solver iteration'); end
exportgraphics(f,path,'Resolution',135);
end
