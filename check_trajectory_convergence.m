function report=check_trajectory_convergence(requested)
% Solar flat long-budget run after enforcing modeled-point field boundaries.
if nargin<1, requested=300; end
assert(batchStartupOptionUsed && ismember(requested,[300 1000]));
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','trajectory_bounds_20261029',sprintf('convergence_%d',requested));
assert(~isfile(fullfile(folder,'verification.json')),'cam:BoundaryArchiveExists','拒绝覆盖既有诊断。');
if ~isfolder(folder), mkdir(folder); end
project=camdesign.solarTestProject();
project=camdesign.refineRoute(camdesign.refineRoute(project));
prior=load(fullfile(root,'outputs','route_refinement_20261029','convergence_300', ...
    'refined_twice_fmincon-interior-point-experimental-v1.mat'));
oldGate=camdesign.verifyConstrained(prior.q,4);
assert(~oldGate.verifiedFeasible,'Old out-of-bounds candidate was accepted.');
inputs={project,prior.q}; labels={'same_initial_curve','previous_cam_candidate'}; cases={};
for k=1:2
    project=inputs{k}; project.params.iterations=requested;
    initial=camdesign.verifyConstrained(project,4);
    [q,h,info]=camdesign.optimizeFmincon(project,[],MaxSeconds=600, ...
        MaxFunctionEvaluations=max(30000,4*(2*(size(project.nodes,1)-1)+1)*(requested+1)));
    assert(isequaln(q.params,project.params) && isequal(q.targets,project.targets));
    assert(isequal(q.nodes(1,:),project.nodes(1,:)));
    extraFine=camdesign.verifyConstrained(q,8);
    fine=q; fine.params.samples=4801; fine.params.camSamples=5761;
    evaluated=camdesign.evaluate(fine,true);
    rules=camdesign.auditSolarRoute(evaluated.route,q.targets,q.params.bounds);
    outside=max(structfun(@(x)x.maximumOutsideMM,rules.modeledPointBounds));
    sequence=cellfun(@(x)x.matchesRequiredOrderAndVisitCount,rules.recognitionScenarios);
    trend=[h.solverMaxViolation]; first=max(1,numel(trend)-10);
    tail=(trend(first)-trend(end))/max(abs(trend(first)),1e-12);
    item=struct('label',labels{k},'initial',initial,'info',info,'extraFine',extraFine, ...
        'ruleAudit',rules,'maxModeledPointOutsideMM',outside,'history',h, ...
        'geometryGatePassIncluding8x',info.verifiedFeasible && extraFine.verifiedFeasible, ...
        'lastTenEntryViolationReductionFraction',tail, ...
        'extendRecommended',info.iterations>=requested && tail>.01 && ~extraFine.verifiedFeasible);
    cases{end+1}=item; %#ok<AGROW>
    save(fullfile(folder,[labels{k},'.mat']),'project','q','h','info','extraFine','rules');
    showCandidate(q,evaluated,labels{k},fullfile(folder,[labels{k},'.png']));
    report=struct('release',version('-release'),'requestedIterations',requested, ...
        'previousCandidateRechecked',oldGate,'cases',{cases}, ...
        'scope','Same physical inputs; modeled reference-point field bounds, full cam gates at coarse/4x/8x grids. Extra disk scenarios are RFID sensitivity only. No full vehicle envelope, original-app or real-car guarantee.');
    fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
    fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fclose(fid);
    fprintf('BOUNDARY_LONG %s actual=%d/%d reason=%s pressure8x=%.9f hit8x=%.9f outside8x=%.9f geometryPass=%d diskScenarios=%s tail=%.6g\n', ...
        labels{k},info.iterations,requested,info.reason,evaluated.metrics.maxPressureDeg, ...
        evaluated.metrics.maxHitError,outside,item.geometryGatePassIncluding8x,mat2str(sequence),tail);
end
fprintf('BOUNDARY_LONG_RECORDED cases=%d extendRecommended=%d\n',numel(cases),any(cellfun(@(x)x.extendRecommended,cases)));
end
function showCandidate(project,result,label,path)
f=figure('Visible','off','Position',[80 80 1400 850],'Color','w'); cleaner=onCleanup(@()close(f));
t=tiledlayout(f,2,2,'TileSpacing','compact'); title(t,[label,' | sampled geometry only'],'Interpreter','none');
a=nexttile(t,[1 2]); r=result.route; hold(a,'on');
plot(a,r.front(:,1),r.front(:,2),'k-',r.sensor(:,1),r.sensor(:,2),'r-', ...
    r.drive(:,1),r.drive(:,2),'b-',r.driven(:,1),r.driven(:,2),'b--');
plot(a,project.nodes(:,1),project.nodes(:,2),'o-','Color',[.2 .6 .3],'MarkerSize',3);
scatter(a,project.targets(:,1),project.targets(:,2),40,'k');
b=project.params.bounds; rectangle(a,'Position',[b(1) b(3) diff(b(1:2)) diff(b(3:4))],'LineStyle','--');
axis(a,'equal'); grid(a,'on'); xlabel(a,'X / mm'); ylabel(a,'Y / mm');
legend(a,{'front','sensor','drive','driven','nodes','targets'},'Location','northoutside','NumColumns',6);
a=nexttile(t); plot(a,r.frontDistance,rad2deg(r.steering)); grid(a,'on'); xlabel(a,'Front travel / mm'); ylabel(a,'Steering / deg');
a=nexttile(t); plot(a,rad2deg(result.cam.phi),rad2deg(result.cam.pressure)); yline(a,35,'--'); grid(a,'on');
xlabel(a,'Cam angle / deg'); ylabel(a,'Pressure / deg');
exportgraphics(f,path,'Resolution',125);
end
