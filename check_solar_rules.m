function report=check_solar_rules()
% Rule-oriented audit of already computed candidates; no optimization rerun.
assert(batchStartupOptionUsed,'cam:SolarRulesBatchOnly','请使用独立 batch 运行。');
root=fileparts(mfilename('fullpath')); addpath(root);
targets=[0 0;20 0;20 20;0 0]; fixture=makeRoute(targets);
a=camdesign.auditSolarRoute(fixture,targets,[-1 21 -1 21],1);
assert(a.recognitionScenarios{1}.matchesRequiredOrderAndVisitCount);
fixture=makeRoute([targets;20 0]); b=camdesign.auditSolarRoute(fixture,targets,[-1 21 -1 21],1);
assert(~b.recognitionScenarios{1}.matchesRequiredOrderAndVisitCount);
assert(numel(b.recognitionScenarios{1}.observedLocationIDs)==5);
fixture=makeRoute([-10 0;10 0]); c=camdesign.auditSolarRoute(fixture,[0 0;10 0],[-5 20 -5 5],1);
assert(c.recognitionScenarios{1}.matchesRequiredOrderAndVisitCount,'Crossing between samples was missed.');
assert(c.modeledPointBounds.front.maximumOutsideMM==5);
folder=fullfile(root,'outputs','solar_flat_20261029','iterations_300');
assert(~isfile(fullfile(folder,'rule_audit.json')),'cam:SolarRulesArchiveExists','已有规则诊断，拒绝覆盖。');
files={'initial_project.mat','peak-gradient-v2.mat','fmincon-interior-point-experimental-v1.mat'};
cases=cell(1,numel(files));
for k=1:numel(files)
    saved=load(fullfile(folder,files{k}));
    if k==1, project=saved.project; else, project=saved.q; end
    project.params.samples=2401; project.params.camSamples=2881;
    result=camdesign.evaluate(project,true);
    audit=camdesign.auditSolarRoute(result.route,project.targets,project.params.bounds);
    cases{k}=struct('source',files{k},'routeSamples',2401,'audit',audit);
    maximumOutside=max(structfun(@(x)x.maximumOutsideMM,audit.modeledPointBounds));
    orderMatch=cellfun(@(x)x.matchesRequiredOrderAndVisitCount,audit.recognitionScenarios);
    fprintf('SOLAR_RULE_AUDIT %s maxModeledPointOutside=%.6f radii8p5_15_20_30_matches=%s\n',files{k},maximumOutside,mat2str(orderMatch));
end
report=struct('release',version('-release'),'analyticChecksPassed',3,'cases',{cases}, ...
    'scope','Boundary and geometric recognition diagnostics only; no full body clearance, RFID latency, physical tracking or original-app equivalence.');
fid=fopen(fullfile(folder,'rule_audit.json'),'w','n','UTF-8'); assert(fid>=0); cleaner=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
function r=makeRoute(xy)
r=struct('front',xy,'rear',xy,'drive',xy,'driven',xy,'sensor',xy);
end
