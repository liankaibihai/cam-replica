function report=auditSolarRoute(route,targets,bounds,radii)
% Geometric route audit; disk intersections do not model RFID read behaviour.
if nargin<4, radii=[8.5 15 20 30]; end
validateattributes(targets,{'double'},{'2d','ncols',2,'finite'});
validateattributes(radii,{'double'},{'vector','positive','finite'});
[locations,~,visitIDs]=unique(targets,'rows','stable');
fields={'front','rear','drive','driven','sensor'}; footprint=struct();
for k=1:numel(fields)
    xy=route.(fields{k});
    clearance=[xy(:,1)-bounds(1),bounds(2)-xy(:,1),xy(:,2)-bounds(3),bounds(4)-xy(:,2)];
    footprint.(fields{k})=struct('minXY',min(xy,[],1),'maxXY',max(xy,[],1), ...
        'minimumBoundaryClearanceMM',min(clearance,[],'all'), ...
        'maximumOutsideMM',max(0,-min(clearance,[],'all')));
end
xy=route.sensor; delta=diff(xy); lengthMM=vecnorm(delta,2,2); distance=[0;cumsum(lengthMM)];
scenarios=cell(1,numel(radii));
for k=1:numel(radii)
    radius=radii(k); events=zeros(0,3);
    for id=1:size(locations,1)
        intervals=zeros(0,2);
        for j=1:size(delta,1)
            v=delta(j,:); w=xy(j,:)-locations(id,:); a=dot(v,v);
            if a<1e-18
                if dot(w,w)<=radius^2, intervals(end+1,:)=[distance(j),distance(j)]; end %#ok<AGROW>
                continue
            end
            b=2*dot(w,v); c=dot(w,w)-radius^2; discriminant=b*b-4*a*c;
            if discriminant<0, continue; end
            lo=max(0,(-b-sqrt(discriminant))/(2*a)); hi=min(1,(-b+sqrt(discriminant))/(2*a));
            if lo<=hi, intervals(end+1,:)=distance(j)+lengthMM(j)*[lo hi]; end %#ok<AGROW>
        end
        if isempty(intervals), continue; end
        merged=intervals(1,:);
        for j=2:size(intervals,1)
            if intervals(j,1)<=merged(end,2)+1e-7
                merged(end,2)=max(merged(end,2),intervals(j,2));
            else, merged(end+1,:)=intervals(j,:); end %#ok<AGROW>
        end
        events=[events;repmat(id,size(merged,1),1),merged]; %#ok<AGROW>
    end
    if ~isempty(events), events=sortrows(events,2); end
    observed=events(:,1);
    scenarios{k}=struct('geometricRadiusMM',radius,'expectedLocationIDs',visitIDs', ...
        'observedLocationIDs',observed','eventEntryExitDistanceMM',events(:,2:3), ...
        'matchesRequiredOrderAndVisitCount',isequal(observed,visitIDs), ...
        'notSensorReadGuarantee',true);
end
report=struct('modeledPointBounds',footprint,'recognitionScenarios',{scenarios}, ...
    'boundaryScope','Dense sampled reference-point trajectories and their straight segments, not complete wheel/body footprint or a continuous spline bound.', ...
    'recognitionScope','Continuous polyline/disk entries; contiguous dwell counts once, exit then re-entry counts again. Radii are sensitivity scenarios, not guaranteed RFID ranges.');
end
