function item=candidateEvaluation(project,full)
% No budget handle or graphics enter a candidate worker.
item=struct('result',[],'identifier','','message','','started',now,'finished',NaN);
try, item.result=camdesign.evaluate(project,full);
catch ex, item.identifier=ex.identifier; item.message=ex.message; end
item.finished=now;
end
