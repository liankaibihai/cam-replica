function report=check_constrained_sensitivity()
% Numerical sensitivity only. Physical parameters/thresholds are not relaxed.
assert(batchStartupOptionUsed,'cam:SensitivityBatchOnly','请使用独立 batch 运行。');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','constrained_optimizer','interior_point','sensitivity_300');
assert(~isfile(fullfile(folder,'verification.json')),'cam:SensitivityArchiveExists','拒绝覆盖已有敏感性诊断。');
if ~isfolder(folder), mkdir(folder); end
cases={}; flatOptions=[];
for kind={'rack','flat'}
    forwards=cell(1,2);
    for j=1:2
        steps=[.05 .005]; step=steps(j); label=sprintf('%s_forward_%gmm',kind{1},step);
        item=runCase(kind{1},step,'forward',1,300,label); cases{end+1}=item; forwards{j}=item;
    end
    if ~any(cellfun(@(x)x.info.verifiedFeasible,forwards))
        label=[kind{1},'_central_0.005mm']; item=runCase(kind{1},.005,'central',1,300,label); cases{end+1}=item;
    end
    if strcmp(kind{1},'flat')
        related=cases(cellfun(@(x)strcmp(x.mechanism,'flat'),cases));
        residual=cellfun(@(x)x.info.returnedMaxViolation,related); [~,which]=min(residual);
        flatOptions=related{which};
    end
end
% Re-solve on a denser grid, starting at the SAME original nodes.
label=sprintf('flat_dense2_%s_%gmm',flatOptions.differenceType,flatOptions.nominalDifferenceStepMM);
cases{end+1}=runCase('flat',flatOptions.nominalDifferenceStepMM,flatOptions.differenceType,2,300,label);

% A genuinely continuing run receives a distinct 1000-round budget/archive.
extensions={};
for j=1:numel(cases)
    if cases{j}.extendRecommended
        c=cases{j}; extensions{end+1}=runCase(c.mechanism,c.nominalDifferenceStepMM,c.differenceType,c.solveGridFactor,1000,[c.label,'_1000']);
    end
end
report=struct('release',version('-release'),'cases',{cases},'extensions1000',{extensions}, ...
    'scope','Only finite-difference configuration and clearly labeled solve-grid density change. Geometry, target ordering, autoRatio and 35/65/30 thresholds remain fixed; no global infeasibility claim.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONSTRAINED_SENSITIVITY_RECORDED %d cases %d extended cases\n',numel(cases),numel(extensions));

    function item=runCase(kind,step,differenceType,gridFactor,iterations,label)
        project=camdesign.defaultProject(); project.params.mechanism=kind; project.params.iterations=iterations;
        project.params.samples=gridFactor*(project.params.samples-1)+1;
        project.params.camSamples=gridFactor*(project.params.camSamples-1)+1;
        maxFunctions=max(30000,100*iterations);
        [q,h,info]=camdesign.optimizeFmincon(project,[],Algorithm='interior-point', ...
            DifferenceStepMM=step,DifferenceType=differenceType, ...
            MaxFunctionEvaluations=maxFunctions,MaxSeconds=180);
        assert(isequaln(q.params,project.params) && isequal(q.nodes(1,:),project.nodes(1,:)));
        assert(isequal([q.params.maxPressureDeg,q.params.maxSteeringDeg,q.params.hitTolerance],[35 65 30]));
        [~,keep]=unique([h.iteration],'stable'); trace=h(keep); first=max(1,numel(trace)-20);
        v=[trace.solverMaxViolation]; objective=[trace.solverObjective];
        vChange=(v(first)-v(end))/max(1e-8,v(first));
        fChange=(objective(first)-objective(end))/max(1e-8,abs(objective(first)));
        extend=info.iterations>=iterations && (vChange>.01 || fChange>.001);
        item=struct('label',label,'mechanism',kind,'differenceType',differenceType, ...
            'nominalDifferenceStepMM',step,'solveGridFactor',gridFactor, ...
            'requestedIterations',iterations,'actualIterations',info.iterations,'info',info,'history',h, ...
            'tailViolationReductionFraction',vChange,'tailObjectiveReductionFraction',fChange,'extendRecommended',extend);
        safeLabel=strrep(label,'.','p'); save(fullfile(folder,[safeLabel,'.mat']),'project','q','h','info');
        plotTrace(h,info,label,fullfile(folder,[safeLabel,'.png']));
        fine=info.verification.refinedGrid; pressure=NaN; hit=NaN; under=NaN; intersections=NaN;
        if fine.valid
            pressure=fine.metrics.maxPressureDeg; hit=fine.metrics.maxHitError;
            under=fine.metrics.minUndercutMargin; intersections=fine.metrics.intersectionCount;
        end
        fprintf('CONSTRAINED_SENSITIVITY %s requested=%d actual=%d seconds=%.3f evals=%d funcCount=%d reason=%s violation=%.9g finePressure=%.9f fineHit=%.9f fineUnder=%.9g fineIntersections=%d verified=%d\n', ...
            label,iterations,info.iterations,info.elapsedSeconds,info.evaluations,info.solverOutput.funcCount, ...
            info.reason,info.returnedMaxViolation,pressure,hit,under,intersections,info.verifiedFeasible);
        fprintf('SENSITIVITY_STOP %s stepsize=%.9g firstorderopt=%.9g\n',label,info.solverOutput.stepsize,info.solverOutput.firstorderopt);
    end
end

function plotTrace(h,info,label,path)
iteration=[h.iteration]; pressure=nan(size(h)); hit=pressure;
for k=1:numel(h)
    if h(k).solverValid
        pressure(k)=h(k).solverMetrics.maxPressureDeg; hit(k)=h(k).solverMetrics.maxHitError;
    end
end
f=figure('Visible','off','Position',[80 80 1200 850]); closer=onCleanup(@()close(f));
t=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
title(t,sprintf('%s | actual/requested %d/%d | %s',label,info.iterations,info.requestedIterations,info.reason),'Interpreter','none');
a=nexttile(t); plot(a,iteration,[h.solverObjective],iteration,[h.objective],'--'); title(a,'Constrained objective'); legend(a,{'Solver iterate','Retained candidate'});
a=nexttile(t); plot(a,iteration,pressure); yline(a,35,'k--','35 deg'); title(a,'Maximum pressure (deg)');
a=nexttile(t); plot(a,iteration,hit); yline(a,30,'k--','30 mm'); title(a,'Maximum ordered hit error (mm)');
a=nexttile(t); plot(a,iteration,[h.solverMaxViolation],iteration,[h.maxConstraintViolation],'--'); yline(a,0,'k--'); title(a,'Maximum positive normalized residual');
for a=findall(f,'Type','axes')', grid(a,'on'); xlabel(a,'Actual solver iteration'); end
exportgraphics(f,path,'Resolution',130);
end
