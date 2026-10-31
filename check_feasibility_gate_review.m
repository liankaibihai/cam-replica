function report=check_feasibility_gate_review()
% Compare new exact feasibility classification to the existing public verifier.
assert(batchStartupOptionUsed,'cam:BatchOnly','Use independent batch.');
folder=fullfile('outputs','feasibility_four_20261031','independent_gate_review');
if ~isfolder(folder), mkdir(folder); end
saved=load(fullfile('outputs','feasibility_four_20261031','legacy','primary','solver_result.mat'),'q');
p=saved.q; native=camdesign.evaluate(p,true); m=native.metrics;
% A known valid-geometry route, with thresholds just either side of measured peaks.
base=p; base.params.maxPressureDeg=m.maxPressureDeg+1;
base.params.hitTolerance=m.maxHitError+1;
base.params.returnAngleDeg=m.actualReturnDeg-1;
% Changing hitTolerance also changes ordered-entry events: keep the original
% event radius for this real route and test pressure, steering and return only.
base.params.hitTolerance=p.params.hitTolerance;
cases={p,base}; names={'original slight pressure violation','test-only wider pressure threshold'};
fields={'maxPressureDeg','maxSteeringDeg','returnAngleDeg'};
values=[m.maxPressureDeg m.maxSteeringDeg m.actualReturnDeg];
for k=1:3
    for sign=[-1 1]
        q=base; q.params.(fields{k})=values(k)+sign*1e-8;
        cases{end+1}=q; names{end+1}=sprintf('%s %+d e-8',fields{k},sign); %#ok<AGROW>
    end
end
classifications=false(numel(cases),1);
for k=1:numel(cases)
    r=camdesign.evaluate(cases{k},true); state=camdesign.feasibilityFourState(cases{k},r);
    old=camdesign.verifyConstrained(cases{k},2);
    assert(state.feasible==old.optimizationGrid.feasible,'New and existing exact gates disagree.');
    quick=camdesign.evaluate(cases{k},false); partial=camdesign.feasibilityFourState(cases{k},quick);
    assert(~partial.feasible && ~partial.fullChecked,'Unchecked geometry cannot be feasible.');
    classifications(k)=state.feasible;
end
assert(~classifications(1) && classifications(2));
assert(isequal(classifications(3:end)',[false true false true true false]));
report=struct('release',version('-release'),'checksPassed',numel(cases),'names',{names}, ...
    'classifications',classifications,'scope','Existing verifier versus new exact gates near real measured peaks; thresholds modified ONLY in test copies, never optimization or saved candidate.');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0); c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('FEASIBILITY_GATE_REVIEW_PASS %d\n',numel(cases));
end
