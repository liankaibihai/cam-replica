function report=check_dynamic_weights()
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
folder=fullfile(root,'outputs','dynamic_weights_20261030','contracts'); if ~isfolder(folder), mkdir(folder); end
p=camdesign.solarTestProject(); original=p; config=camdesign.dynamicWeightSettings(p.params);
assert(~config.enabled && isequaln(p,original));
bad=p.params; bad.dynamicWeights=struct('interval',0); failed=false;
try, camdesign.dynamicWeightSettings(bad); catch, failed=true; end
assert(failed); checks={'optional defaults preserve project and invalid schedules are rejected'};
p.params.dynamicWeights=config; p.params.dynamicWeights.enabled=true;
m=struct('maxHitError',2*p.params.hitTolerance,'maxPressureDeg',2*p.params.maxPressureDeg, ...
    'maxSteeringDeg',2*p.params.maxSteeringDeg,'minUndercutMargin',0);
[w,v]=camdesign.updateDynamicWeights(p.params,m);
assert(isequal(v,[1 0 0 1 1 1]));
assert(isequal(w,p.params.weights.*[2 1 1 2 2 2]));
m.maxHitError=1e9; m.minUndercutMargin=-1e9;
for k=1:20, w=camdesign.updateDynamicWeights(p.params,m,w); end
assert(all(w>=p.params.weights & w<=5*p.params.weights) && isequal(w(2:3),p.params.weights(2:3)));
m.maxHitError=0; m.maxPressureDeg=0; m.maxSteeringDeg=0; m.minUndercutMargin=1;
relaxed=camdesign.updateDynamicWeights(p.params,m,w); assert(all(relaxed<=w & relaxed>=p.params.weights));
zero=p.params; zero.weights(1)=0; z=camdesign.updateDynamicWeights(zero,m); assert(z(1)==0);
checks{end+1}='analytic violation response, bounded growth, relaxation and intentionally zero base weights';

for method={'peak-gradient-v2','video-four-direction-v1'}
    a=original; a.params.iterations=6; b=a; b.params.dynamicWeights=config;
    [qa,ha]=camdesign.optimizeSearch(a,[],method{1}); [qb,hb]=camdesign.optimizeSearch(b,[],method{1});
    assert(isequaln(qa.nodes,qb.nodes) && isequaln([ha.score],[hb.score]));
    p.params.iterations=12; p.params.dynamicWeights.interval=2;
    [q,h,info]=camdesign.optimizeSearch(p,[],method{1});
    assert(isequaln(q.params,p.params) && q.params.gearRatio==35);
    assert(info.dynamicWeights.enabled && isequal(info.referenceWeights,p.params.weights));
    assert(any(arrayfun(@(x)any(x.activeWeights~=x.referenceWeights),h)));
    assert(any([h.weightChanged]) && all(mod([h([h.weightChanged]).weightUpdateIteration]-1,2)==0));
    for k=1:numel(h)
        assert(abs(h(k).score-sum(h(k).referenceWeights.*h(k).metrics.terms))<1e-9);
        assert(abs(h(k).dynamicScore-sum(h(k).activeWeights.*h(k).metrics.terms))<1e-9);
        if k>1 && h(k).accepted
            assert(isequal(h(k).activeWeights,h(k-1).activeWeights));
            assert(h(k).dynamicScore<h(k-1).dynamicScore);
        end
    end
end
checks{end+1}='both search backends preserve static behavior when disabled and compare accepted moves at one frozen weight vector';
checks{end+1}='history reference/dynamic scores match recorded terms and weights; all user parameters stay fixed';

[stopped,h,info]=camdesign.optimizeSearch(p,@(~,~,~)true,'peak-gradient-v2');
assert(isequaln(stopped,p) && info.iterations==0 && numel(h)==1 && strcmp(info.reason,'user_stop'));
checks{end+1}='cancellation before the first round preserves inputs and initial weight provenance';
file=fullfile(folder,'settings_roundtrip.mat'); camdesign.saveProject(p,file); loaded=camdesign.importProject(file);
assert(isequaln(loaded.params.dynamicWeights,p.params.dynamicWeights));
r=camdesign.evaluate(p,true); paths=camdesign.exportResult(p,r,fullfile(folder,'export'));
exported=jsondecode(fileread(paths.report)); assert(exported.params.gearRatio==35 && exported.params.dynamicWeights.enabled);
checks{end+1}='save/import/export preserve dynamic configuration without changing physical metrics or fixed transmission';
for method={'fmincon-interior-point-experimental-v1','legacy-v1'}
    failed=false; try, camdesign.optimize(p,[],method{1}); catch ex, failed=strcmp(ex.identifier,'cam:DynamicWeightsBackend'); end
    assert(failed);
end
checks{end+1}='unsupported constrained and historical backends explicitly reject enabled dynamic schedules';
report=struct('release',version('-release'),'checks',{checks},'scope','Contracts only; short calls do not assess convergence.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('DYNAMIC_WEIGHTS_PASS cases=%d\n',numel(checks));
end
