function yes=feasibilityFourBetter(candidate,current)
% A fully feasible incumbent cannot be traded for ANY infeasible improvement.
yes=false;
if ~candidate.valid || ~candidate.fullChecked, return; end
if current.feasible
    if candidate.feasible, yes=lower(candidate.qualityObjective,current.qualityObjective); end
elseif candidate.feasible
    yes=true;
else
    first=[candidate.violationSquared candidate.maxNormalizedViolation candidate.qualityObjective];
    second=[current.violationSquared current.maxNormalizedViolation current.qualityObjective];
    for k=1:3
        if lower(first(k),second(k)), yes=true; return; end
        if lower(second(k),first(k)), return; end
    end
end
end
function yes=lower(a,b)
yes=a<b-1e-10*max(1,abs(b));
end
