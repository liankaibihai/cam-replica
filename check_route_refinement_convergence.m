function report=check_route_refinement_convergence(requested)
% Isolate fixed parameter stations and additional route-node DOFs.
if nargin<1, requested=300; end
assert(batchStartupOptionUsed && ismember(requested,[300 1000]));
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','route_refinement_20261029',sprintf('convergence_%d',requested));
assert(~isfile(fullfile(folder,'verification.json')),'cam:RefinementArchiveExists','已有该预算结果，拒绝覆盖。');
if ~isfolder(folder), mkdir(folder); end
original=camdesign.solarTestProject(); original.params.iterations=requested;
[fixed,freezeInfo]=camdesign.refineRoute(original,[]);
[refined,first]=camdesign.refineRoute(original); [refined,second]=camdesign.refineRoute(refined);
projects={original,fixed,refined}; labels={'legacy_chord_10','fixed_station_10','refined_twice'};
algorithms={'peak-gradient-v2','fmincon-interior-point-experimental-v1'};
cases={};
for k=1:3
    project=projects{k}; initial=camdesign.evaluate(project,true);
    for a=1:2
        reused=false;
        if k==1 && requested==300
            source=fullfile(root,'outputs','solar_flat_20261029','iterations_300',[algorithms{a},'.mat']);
            prior=load(source); assert(isequaln(prior.project,project));
            q=prior.q; h=prior.h; info=prior.info; verification=prior.verification;
            reused=true;
        else
            source='';
            if a==1
                [q,h,info]=camdesign.optimize(project,[],algorithms{a});
                verification=camdesign.verifyConstrained(q,4);
            else
                [q,h,info]=camdesign.optimizeFmincon(project,[],MaxSeconds=600, ...
                    MaxFunctionEvaluations=max(30000,4*(2*(size(project.nodes,1)-1)+1)*(requested+1)));
                verification=info.verification;
            end
        end
        assert(isequaln(q.params,project.params) && isequal(q.targets,original.targets));
        assert(isequal(q.nodes(1,:),original.nodes(1,:)));
        fine=q; fine.params.samples=2401; fine.params.camSamples=2881;
        result=camdesign.evaluate(fine,true);
        rules=camdesign.auditSolarRoute(result.route,q.targets,q.params.bounds);
        maxOutside=max(structfun(@(x)x.maximumOutsideMM,rules.modeledPointBounds));
        if a==1, trend=[h.score]; else, trend=[h.solverMaxViolation]; end
        start=max(1,numel(trend)-10);
        tail=(trend(start)-trend(end))/max(abs(trend(start)),1e-12);
        extend=info.iterations>=requested && tail>.01 && ~verification.verifiedFeasible;
        item=struct('label',labels{k},'algorithm',algorithms{a},'nodeCount',size(project.nodes,1), ...
            'initialMetrics',initial.metrics,'info',info,'verification',verification, ...
            'ruleAudit',rules,'maxModeledPointOutsideMM',maxOutside,'history',h, ...
            'reusedPreviousRun',reused,'previousSource',source, ...
            'lastTenEntryReductionFraction',tail,'extendRecommended',extend);
        cases{end+1}=item; %#ok<AGROW>
        save(fullfile(folder,[labels{k},'_',algorithms{a},'.mat']),'project','q','h','info','verification','rules');
        fprintf('REFINEMENT_LONG %s %s nodes=%d reused=%d actual=%d/%d reason=%s pressure=%.6f hit=%.6f outside=%.6f verified=%d tail=%.6f\n', ...
            labels{k},algorithms{a},size(project.nodes,1),reused,info.iterations,requested,info.reason, ...
            result.metrics.maxPressureDeg,result.metrics.maxHitError,maxOutside,verification.verifiedFeasible,tail);
        report=struct('release',version('-release'),'requestedIterations',requested, ...
            'refinementInfo',{{freezeInfo,first,second}},'cases',{cases}, ...
            'scope','Same initial curve and fixed physical inputs. Legacy 300-round histories reused; new station/DOF cases separately optimized. Discrete checks and modeled-point boundary audit only, no original-app/vehicle equivalence.');
        writeReport(report,fullfile(folder,'verification.json'));
    end
end
fprintf('REFINEMENT_LONG_RECORDED cases=%d extendRecommended=%d\n',numel(cases),any(cellfun(@(x)x.extendRecommended,cases)));
end
function writeReport(report,path)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0); cleaner=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
