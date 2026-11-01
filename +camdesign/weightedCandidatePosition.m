function [candidate,weights]=weightedCandidatePosition(nodes,probeScores,probe,anchor)
% Whole-candidate-set improvement weighting, not per-node normalization.
% Each row/column denotes one full point set with one node moved +/-X or +/-Y.
weights=max(0,anchor-probeScores); weights(~isfinite(weights))=0; weights(1,:)=0;
candidate=nodes; total=sum(weights,'all');
if total==0, return; end
offsets=probe*[1 0;-1 0;0 1;0 -1];
candidate=nodes+(weights*offsets)/total;
end
