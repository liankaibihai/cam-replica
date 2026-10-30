function report=check_constrained_optimizer(mode,outputFolder)
% Targeted contracts and identical-input solver comparison, never user figures.
if nargin<1, mode='all'; end
assert(ismember(mode,{'contracts','comparison','all'}));
assert(batchStartupOptionUsed,'cam:ConstrainedBatchOnly','请使用独立 MATLAB -batch 运行。');
root=fileparts(mfilename('fullpath')); addpath(root);
if nargin<2, outputFolder=fullfile(root,'outputs','constrained_optimizer'); end
folder=outputFolder; if ~isfolder(folder), mkdir(folder); end
caseFolder=fullfile(folder,'interior_point');
contracts=[]; cases={};
if ismember(mode,{'contracts','all'}), contracts=checkContracts(); end
if ismember(mode,{'comparison','all'})
    if ~isfolder(caseFolder), mkdir(caseFolder); end
    for mechanism={'rack','flat'}
        project=camdesign.defaultProject(); project.params.mechanism=mechanism{1};
        before=camdesign.evaluate(project,true); afters=cell(1,2);
        algorithms={'peak-gradient-v2','fmincon-interior-point-experimental-v1'};
        for k=1:2
            timer=tic; [q,h,info]=camdesign.optimize(project,[],algorithms{k}); elapsed=toc(timer);
            after=camdesign.evaluate(q,true); afters{k}=after;
            assert(isequaln(q.params,project.params) && isequal(q.targets,project.targets));
            assert(isequal(q.nodes(1,:),project.nodes(1,:)) && isequal(size(q.nodes),size(project.nodes)));
            assert(isequal([q.params.maxPressureDeg,q.params.maxSteeringDeg,q.params.hitTolerance],[35 65 30]));
            if isfield(info,'verification'), verification=info.verification;
            else, verification=camdesign.verifyConstrained(q,4); end
            fineMetrics=verification.refinedGrid.metrics;
            if isempty(fineMetrics)
                fineMetrics=struct('maxPressureDeg',NaN,'maxHitError',NaN, ...
                    'minUndercutMargin',NaN,'intersectionCount',NaN);
            end
            diagnostic=camdesign.fminconModel(q,project.nodes);
            item=struct('mechanism',mechanism{1},'algorithm',algorithms{k}, ...
                'before',before.metrics,'after',after.metrics,'elapsedSeconds',elapsed, ...
                'info',info,'history',h,'verification',verification,'commonSmoothObjective',diagnostic.objective, ...
                'parametersUnchanged',true,'startFixed',true);
            cases{end+1}=item;
            save(fullfile(caseFolder,[mechanism{1},'_',algorithms{k},'.mat']),'project','before','q','after','h','info','verification');
            fprintf('CONSTRAINED_COMPARE %s %s seconds=%.3f evals=%d iter=%d/%d reason=%s score=%.6g->%.6g objective=%.6g pressure=%.6f hit=%.6f steering=%.6f finePressure=%.6f fineHit=%.6f fineUndercut=%.6g fineIntersections=%d verified=%d\n', ...
                mechanism{1},algorithms{k},elapsed,info.evaluations,info.iterations,info.requestedIterations,info.reason, ...
                before.metrics.score,after.metrics.score,diagnostic.objective,after.metrics.maxPressureDeg, ...
                after.metrics.maxHitError,after.metrics.maxSteeringDeg,fineMetrics.maxPressureDeg, ...
                fineMetrics.maxHitError,fineMetrics.minUndercutMargin, ...
                fineMetrics.intersectionCount,verification.verifiedFeasible);
        end
        comparisonFigure(project,before,afters,fullfile(caseFolder,[mechanism{1},'_comparison.png']));
    end
end
report=struct('release',version('-release'),'mode',mode,'contracts',contracts,'cases',{cases}, ...
    'scope','Same nodes, route parameterization, physical parameters and thresholds per mechanism; smooth objective and historical score are distinct; no original/vehicle equivalence.');
reportFolder=folder; if strcmp(mode,'comparison'), reportFolder=caseFolder; end
fid=fopen(fullfile(reportFolder,[mode,'.json']),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('CONSTRAINED_OPTIMIZER_%s_PASS %d comparison cases\n',upper(mode),numel(cases));
end

function report=checkContracts()
project=simpleCase(); initial=camdesign.fminconModel(project,project.nodes);
assert(initial.valid && initial.maxViolation==0);
expected=size(project.targets,1)+5*project.params.samples+2*project.params.camSamples+1;
assert(numel(initial.constraints)==expected);
longer=project; longer.nodes(:,2)=1.1*longer.nodes(:,2);
changed=camdesign.fminconModel(longer,project.nodes);
assert(changed.valid && numel(changed.constraints)==expected);
assert(nnz(initial.result.cam.workingMask)~=nnz(changed.result.cam.workingMask));
invalid=project; invalid.nodes(2,:)=invalid.nodes(1,:);
bad=camdesign.fminconModel(invalid,project.nodes);
assert(~bad.valid && strcmp(bad.errorIdentifier,'cam:Duplicate') && all(isfinite(bad.constraints)) ...
    && all(bad.constraints>0) && isfinite(bad.objective) && numel(bad.constraints)==expected);
programmingError=false;
try, camdesign.fminconModel(project,project.nodes,struct); catch ex, programmingError=startsWith(ex.identifier,'MATLAB:'); end
assert(programmingError,'Unexpected programming errors must propagate.');
checks={'fixed dimensions across moving work boundary; invalid geometry stays finite/infeasible; programming errors propagate'};
outside=project; outside.params.bounds(1)=-4;
outsideModel=camdesign.fminconModel(outside,project.nodes);
assert(outsideModel.valid && outsideModel.maxNodeBoundViolation>0 && outsideModel.maxViolation>0);

% Independently verify the hit constraint against an analytically straight path.
line=project; line.nodes=[0 0;0 250;0 500]; line.targets=[0 0;40 250;0 500];
model=camdesign.fminconModel(line,line.nodes);
assert(abs(model.result.hits.errors(2)-40)<1e-9);
assert(abs(model.constraints(2)-((40/30)^2-1))<1e-10);
assert(model.maxViolation>0);
checks{end+1}='40 mm analytic straight-path miss violates unchanged 30 mm tolerance';

[stopped,h,stopInfo]=camdesign.optimize(project,@(~,~,~)true,'fmincon-interior-point-experimental-v1');
assert(strcmp(stopInfo.reason,'user_stop') && stopInfo.iterations==0 && h(end).stopped);
assert(isequaln(stopped,project) && isfield(h,'objective') && isfield(h,'score'));
assert(all([h.nominalDifferenceStepMM]==stopInfo.nominalDifferenceStepMM));
checks{end+1}='immediate callback stop preserves complete project and history contract';

[q,h,info]=camdesign.optimize(project,[],'fmincon-interior-point-experimental-v1');
assert(isequaln(q.params,project.params) && isequal(q.nodes(1,:),project.nodes(1,:)));
assert(info.verifiedFeasible && info.verification.independentRefinement);
assert(info.verification.refinedGrid.routeSamples==4*(project.params.samples-1)+1);
assert(info.verification.refinedGrid.camSamples==4*(project.params.camSamples-1)+1);
assert(h(end).objective<=h(1).objective+1e-8 && info.objectiveCalls>0 && info.constraintCalls>0);
assert(all([h.maxConstraintViolation]==0),'Strict feasible incumbents must never be displaced by solver-tolerance violations.');
assert(strcmp(info.objectiveVersion,'length-steering-move-v1') && info.solverOutput.funcCount>0);
checks{end+1}='simple feasible interior-point case retains strict limits and passes fourfold/full-geometry verification';

[q2,h2,info2]=camdesign.optimize(project,@(iteration,~,~)iteration>=1,'fmincon-interior-point-experimental-v1');
assert(strcmp(info2.reason,'user_stop') && info2.iterations<=1 && h2(end).stopped);
assert(isequaln(q2.params,project.params) && isequal(q2.nodes(1,:),project.nodes(1,:)));
checks{end+1}='callback stop after a solver iteration returns a valid incumbent';

[~,~,timed]=camdesign.optimizeFmincon(project,[],MaxSeconds=eps);
assert(strcmp(timed.reason,'time_limit'));
checks{end+1}='wall-time budget is reported separately from solver convergence';
large=camdesign.defaultProject(); large.params.iterations=300;
[~,~,derived]=camdesign.optimizeFmincon(large,@(~,~,~)true);
assert(derived.maxFunctionEvaluations==4*(derived.freeVariables+1)*301 ...
    && derived.maxFunctionEvaluations>=30000 && startsWith(derived.functionBudgetSource,'derived'));
[~,~,explicit]=camdesign.optimizeFmincon(project,@(~,~,~)true,MaxFunctionEvaluations=17);
assert(explicit.maxFunctionEvaluations==17 && strcmp(explicit.functionBudgetSource,'explicit'));
checks{end+1}='default function budget scales to requested iterations; explicit budget is not overwritten';
report=struct('passed',numel(checks),'checks',{checks},'simpleInitial',initial.result.metrics, ...
    'simpleFinal',info.finalMetrics,'simpleInfo',info,'simpleHistory',h);
for k=1:numel(checks), fprintf('CONSTRAINED_CONTRACT_PASS %s\n',checks{k}); end
end

function project=simpleCase()
project=camdesign.defaultProject(); project.name='analytic feasible constrained case';
project.params.samples=101; project.params.camSamples=181; project.params.iterations=15;
project.params.sensorX=0; project.params.sensorY=0; project.params.autoRatio=false;
project.params.gearRatio=2;
project.params.bounds=[-1000 1000 -1000 1000];
project.targets=[0 0;0 250;0 500]; project.nodes=[0 0;-5 250;0 500];
end

function comparisonFigure(project,before,after,file)
f=figure('Visible','off','Position',[80 80 1300 980]); cleaner=onCleanup(@()close(f));
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
title(layout,[project.params.mechanism,' | identical physical inputs and thresholds']);
results=[{before},after]; colors={[.65 .65 .65],[.1 .35 .6],[.85 .35 .1]};
labels={'Initial','Peak gradient','Experimental interior-point'};
for k=1:3
    r=results{k}; a=nexttile(layout,1); hold(a,'on');
    plot(a,r.route.front(:,1),r.route.front(:,2),'Color',colors{k},'LineWidth',1.3);
    a=nexttile(layout,2); hold(a,'on'); plot(a,r.route.frontDistance,rad2deg(r.route.steering),'Color',colors{k});
    a=nexttile(layout,3); hold(a,'on'); plot(a,r.cam.actual(:,1),r.cam.actual(:,2),'Color',colors{k});
    a=nexttile(layout,4); hold(a,'on'); plot(a,rad2deg(r.cam.phi),rad2deg(r.cam.pressure),'Color',colors{k});
end
a=nexttile(layout,1); plot(a,project.targets(:,1),project.targets(:,2),'k.','MarkerSize',10);
axis(a,'equal'); grid(a,'on'); title(a,'Front route and targets'); xlabel(a,'X (mm)'); ylabel(a,'Y (mm)');
legend(a,[labels,{'Targets'}],'Location','best');
a=nexttile(layout,2); yline(a,project.params.maxSteeringDeg,'k--','65 deg'); yline(a,-project.params.maxSteeringDeg,'k--');
grid(a,'on'); title(a,'Steering'); xlabel(a,'Front distance (mm)'); ylabel(a,'Angle (deg)');
a=nexttile(layout,3); axis(a,'equal'); grid(a,'on'); title(a,'Actual discrete cam'); xlabel(a,'X (mm)'); ylabel(a,'Y (mm)');
a=nexttile(layout,4); yline(a,project.params.maxPressureDeg,'k--','35 deg');
xline(a,rad2deg(after{2}.cam.workEnd),':','Interior-point work end');
grid(a,'on'); title(a,'Pressure angle, work and return'); xlabel(a,'Cam phase (deg)'); ylabel(a,'Pressure angle (deg)');
exportgraphics(f,file,'Resolution',135);
end
