function result=visitOrderAudit(path,targets,radius)
% Continuous polyline/disk entry events; separate from ordered projection.
% Radius is an explicit geometric assumption, never an RFID read guarantee.
validateattributes(path,{'double'},{'2d','ncols',2,'real','finite','nonempty'});
validateattributes(targets,{'double'},{'2d','ncols',2,'real','finite','nonempty'});
validateattributes(radius,{'double'},{'scalar','real','finite','positive'});
[locations,~,expected]=unique(targets,'rows','stable');
v=diff(path); lengths=vecnorm(v,2,2); distance=[0;cumsum(lengths)];
a=sum(v.^2,2); events=zeros(0,3);
for id=1:size(locations,1)
    w=path(1:end-1,:)-locations(id,:); b=2*sum(w.*v,2); c=sum(w.^2,2)-radius^2;
    disc=b.^2-4*a.*c; moving=a>1e-18;
    active=moving & disc>=0;
    lo=ones(size(a)); hi=zeros(size(a));
    lo(active)=max(0,(-b(active)-sqrt(disc(active)))./(2*a(active)));
    hi(active)=min(1,(-b(active)+sqrt(disc(active)))./(2*a(active)));
    stationary=~moving & c<=0; lo(stationary)=0; hi(stationary)=0;
    used=find((active | stationary) & lo<=hi);
    intervals=[distance(used)+lengths(used).*lo(used),distance(used)+lengths(used).*hi(used)];
    if isempty(intervals), continue; end
    merged=intervals(1,:);
    for k=2:size(intervals,1)
        if intervals(k,1)<=merged(end,2)+1e-7
            merged(end,2)=max(merged(end,2),intervals(k,2));
        else, merged(end+1,:)=intervals(k,:); end %#ok<AGROW>
    end
    events=[events;repmat(id,size(merged,1),1),merged]; %#ok<AGROW>
end
if ~isempty(events), events=sortrows(events,2); end
observed=events(:,1);
% Simultaneous entries into different disks are ambiguous, not a valid order.
ambiguous=size(events,1)>1 && any(diff(events(:,2))<=1e-7 & diff(events(:,1))~=0);
result=struct('geometricRadiusMM',radius,'expectedLocationIDs',expected', ...
    'observedLocationIDs',observed','eventEntryExitDistanceMM',events(:,2:3), ...
    'matchesRequiredOrderAndVisitCount',isequal(observed,expected) && ~ambiguous, ...
    'ambiguousSimultaneousEntries',ambiguous,'notSensorReadGuarantee',true, ...
    'scope','Polyline/disk entries; continuous dwell once, re-entry counted; repeated start/end remain separate required visits.');
end
