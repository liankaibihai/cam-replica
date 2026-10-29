function report=check_optimizer_quality(mode)
% Full default-input comparison, including unsuccessful/unfinished constraints.
if nargin<1, mode='current'; end
% Historical evidence must never be regenerated against the current implementation.
% This guard deliberately precedes path setup and all output-directory writes.
if strcmp(mode,'baseline')
    error('cam:HistoricalBaselineOnly', ...
        '历史基线只能在 a91d5e2 工作树中采集；当前代码拒绝 baseline 模式，已有 baseline.json 保持不变。');
end
assert(ismember(mode,{'current','convergence','smoothing-audit'}),'cam:QualityMode','未知质量检查模式。');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','optimizer_quality'); if ~isfolder(folder), mkdir(folder); end
caseFolder=fullfile(folder,mode); if ~isfolder(caseFolder), mkdir(caseFolder); end
if strcmp(mode,'convergence'), algorithms={'peak-gradient-v2','video-four-direction-v1'};
elseif strcmp(mode,'smoothing-audit'), algorithms={'video-four-direction-v1'};
else, algorithms={'legacy-v1','peak-gradient-v2','video-four-direction-v1'}; end
checkSearchContracts();
cases={};
for mechanism={'rack','flat'}
    for algorithm=algorithms
        p=camdesign.defaultProject(); p.params.mechanism=mechanism{1}; p.params.iterations=30;
        if ismember(mode,{'convergence','smoothing-audit'}), p.params.iterations=300; end
        before=camdesign.evaluate(p,true); timer=tic;
        [q,h,info]=camdesign.optimize(p,[],algorithm{1});
        elapsed=toc(timer); after=camdesign.evaluate(q,true);
        assert(isequal(q.nodes(1,:),p.nodes(1,:)) && all(diff([h.score])<=1e-8));
        item=struct('mechanism',mechanism{1},'algorithm',algorithm{1}, ...
            'before',before.metrics,'after',after.metrics,'optimizationSeconds',elapsed, ...
            'termination',info,'history',h,'warnings',{after.warnings}, ...
            'searchInitialScore',h(1).score,'searchFinalScore',h(end).score, ...
            'peakLocations',peakLocations(after),'stepSummary',stepSummary(h));
        cases{end+1}=item; %#ok<AGROW>
        stem=[mechanism{1},'_',algorithm{1}];
        save(fullfile(caseFolder,[stem,'.mat']),'p','q','before','after','h','info','elapsed');
        plotComparison(before,after,fullfile(caseFolder,[stem,'.png']),[mode,' ',stem]);
        fprintf('QUALITY_CASE %s %s elapsed=%.3fs iterations=%d/%d reason=%s hit=%.4f->%.4f workPressure=%.4f->%.4f returnPressure=%.4f->%.4f steering=%.4f->%.4f undercut=%.5f->%.5f score=%.8g->%.8g\n', ...
            mechanism{1},algorithm{1},elapsed,info.iterations,p.params.iterations,info.reason, ...
            before.metrics.maxHitError,after.metrics.maxHitError, ...
            before.metrics.maxWorkPressureDeg,after.metrics.maxWorkPressureDeg, ...
            before.metrics.maxReturnPressureDeg,after.metrics.maxReturnPressureDeg, ...
            before.metrics.maxSteeringDeg,after.metrics.maxSteeringDeg, ...
            before.metrics.minUndercutMargin,after.metrics.minUndercutMargin, ...
            h(1).score,h(end).score);
        if strcmp(algorithm{1},'legacy-v1')
            baselineFile=fullfile(folder,'baseline',[mechanism{1},'_baseline-a91d5e2.mat']);
            if ~isfile(baselineFile), baselineFile=fullfile(folder,[mechanism{1},'_baseline-a91d5e2.mat']); end
            if isfile(baselineFile)
                baseline=load(baselineFile,'q');
                assert(max(abs(q.nodes-baseline.q.nodes),[],'all')<1e-7,'Legacy comparison path changed.');
            end
        end
        if strcmp(mode,'smoothing-audit')
            archived=load(fullfile(folder,'convergence',[stem,'.mat']),'q');
            assert(max(abs(q.nodes-archived.q.nodes),[],'all')<1e-9,'Audit changed the archived convergence result.');
        end
    end
end
report=struct('release',version('-release'),'mode',mode,'cases',{cases}, ...
    'scope','Identical default inputs within each iteration budget; scores only comparable within one objective definition; no original EXE or vehicle equivalence.');
fid=fopen(fullfile(folder,[mode,'.json']),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('OPTIMIZER_QUALITY_%s_PASS %d cases\n',upper(mode),numel(cases));
end

function checkSearchContracts()
% Independently enumerate full candidate point sets to check global normalization.
nodes=[0 0;10 20;30 40]; probe=.5; anchor=4.8;
scores=inf(3,4); scores(2,1:3)=[4.5 4.65 4.7]; scores(3,1)=4.25;
[actual,w]=camdesign.weightedCandidatePosition(nodes,scores,probe,anchor);
sets=repmat(nodes,1,1,4);
sets(2,1,1)=sets(2,1,1)+probe; sets(2,1,2)=sets(2,1,2)-probe;
sets(2,2,3)=sets(2,2,3)+probe; sets(3,1,4)=sets(3,1,4)+probe;
expected=sum(sets.*reshape([.3 .15 .1 .55],1,1,[]),3)/1.1;
assert(max(abs(actual-expected),[],'all')<1e-12 && abs(sum(w,'all')-1.1)<1e-12);
assert(isequal(camdesign.weightedCandidatePosition(nodes,inf(3,4),probe,anchor),nodes));
p=camdesign.defaultProject(); p.params.samples=201; p.params.camSamples=241; p.params.iterations=30;
[q,h,info]=camdesign.optimize(p,@(~,~,~)true);
assert(strcmp(info.reason,'user_stop') && info.iterations==0 && h(end).stopped && isequal(q.nodes,p.nodes));
p.params.weights=zeros(1,6);
[q,h,info]=camdesign.optimize(p);
assert(strcmp(info.reason,'gradient_tolerance') && info.iterations<30 && isequal(q.nodes,p.nodes));
assert(all([h.score]==0));
fprintf('SEARCH_CONTRACTS_PASS whole-set weighting, no-improvement, stop and refinement reporting\n');
end

function out=peakLocations(r)
work=find(r.cam.workingMask); ret=find(~r.cam.workingMask);
[~,i]=max(r.cam.pressure(work)); [~,j]=max(r.cam.pressure(ret));
[~,u]=min(r.cam.undercutMargin);
out=struct('workPressurePhaseDeg',rad2deg(r.cam.phi(work(i))), ...
    'returnPressurePhaseDeg',rad2deg(r.cam.phi(ret(j))), ...
    'minUndercutPhaseDeg',rad2deg(r.cam.phi(u)));
end
function out=stepSummary(h)
out=struct('available',isfield(h,'stepType'));
if ~out.available, return; end
out.accepted=sum([h.accepted]); out.smoothingAccepted=sum(contains({h.stepType},'neighbor_smoothing'));
out.coordinateRescues=sum(contains({h.stepType},'coordinate_rescue'));
out.probeRefinements=sum(strcmp({h.stepType},'no_step'));
out.lastStepMM=h(end).stepMM; out.maxStepMM=max([h.stepMM]);
if isfield(h,'smoothingAttempts')
    out.totalSmoothingAttempts=sum([h.smoothingAttempts]);
    out.acceptedSmoothingAlphas=[h([h.smoothingAlpha]>0).smoothingAlpha];
end
end

function plotComparison(before,after,file,label)
f=figure('Visible','off','Position',[60 60 1350 1080]); cleaner=onCleanup(@()close(f));
layout=tiledlayout(f,4,2,'TileSpacing','compact','Padding','compact');
for col=1:2
    if col==1, r=before; caption='Before'; else, r=after; caption='After'; end
    a=nexttile(layout,col); plot(a,r.route.front(:,1),r.route.front(:,2),'k-',r.route.sensor(:,1),r.route.sensor(:,2),'r-');
    axis(a,'equal'); grid(a,'on'); title(a,[label,' ',caption],'Interpreter','none'); ylabel(a,'Y / mm');
    a=nexttile(layout,2+col); plot(a,r.route.frontDistance,rad2deg(r.route.steering)); grid(a,'on'); ylabel(a,'Steering / deg');
    a=nexttile(layout,4+col); plot(a,r.cam.pitch(:,1),r.cam.pitch(:,2),'b-',r.cam.actual(:,1),r.cam.actual(:,2),'r-');
    axis(a,'equal'); grid(a,'on'); ylabel(a,'Cam Y / mm');
    a=nexttile(layout,6+col); plot(a,rad2deg(r.cam.phi),rad2deg(r.cam.pressure));
    xline(a,rad2deg(r.cam.workEnd),'--','Work / return'); grid(a,'on'); ylabel(a,'Pressure / deg'); xlabel(a,'Cam phase / deg');
end
exportgraphics(layout,file,Resolution=120);
end
