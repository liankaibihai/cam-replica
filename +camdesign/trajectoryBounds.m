function [constraints,report]=trajectoryBounds(route,bounds)
% Four residual blocks (xmin,xmax,ymin,ymax), each with one value per station.
% Each residual uses the extreme across five modeled centers, normalized by
% field width/height. This is not a wheel/body envelope or continuous bound.
validateattributes(bounds,{'double'},{'vector','numel',4,'real','finite'});
bounds=bounds(:)'; width=bounds(2)-bounds(1); height=bounds(4)-bounds(3);
assert(width>0 && height>0,'cam:Bounds','场地坐标范围错误。');
names={'front','rear','drive','driven','sensor'};
validateattributes(route.front,{'double'},{'2d','ncols',2,'nonempty'});
count=size(route.front,1); points=zeros(count,2,numel(names)); components=struct();
maximumOutside=0; worstPoint=''; worstSide=''; worstSample=NaN;
sides={'xmin','xmax','ymin','ymax'};
for k=1:numel(names)
    xy=route.(names{k});
    assert(isequal(size(xy),[count 2]),'cam:ConstraintDimension','部件轨迹采样维数不一致。');
    assert(isreal(xy) && all(isfinite(xy),'all'),'cam:ConstraintNonfinite','部件轨迹出现非有限或复数坐标。');
    points(:,:,k)=xy;
    residual=[bounds(1)-xy(:,1),xy(:,1)-bounds(2),bounds(3)-xy(:,2),xy(:,2)-bounds(4)];
    [value,index]=max(residual(:));
    outside=max(0,value);
    components.(names{k})=struct('minimumXY',min(xy,[],1),'maximumXY',max(xy,[],1), ...
        'maximumOutsideMM',outside,'outsideSampleCount',nnz(any(residual>0,2)));
    if outside>maximumOutside
        maximumOutside=outside; worstPoint=names{k};
        [worstSample,side]=ind2sub(size(residual),index); worstSide=sides{side};
    end
end
minXY=min(points,[],3); maxXY=max(points,[],3);
residuals=[bounds(1)-minXY(:,1),maxXY(:,1)-bounds(2),bounds(3)-minXY(:,2),maxXY(:,2)-bounds(4)];
scaled=residuals./[width width height height]; constraints=scaled(:);
report=struct('sampleCount',count,'componentNames',{names},'residualBlockOrder',{sides}, ...
    'boundsMM',bounds,'satisfied',all(constraints<=0), ...
    'maximumOutsideMM',maximumOutside,'maxScaledViolation',max([0;constraints]), ...
    'worstPoint',worstPoint,'worstSide',worstSide,'worstSampleIndex',worstSample, ...
    'components',components, ...
    'scope','Five modeled centers at sampled route stations; no wheel widths, complete body envelope or continuous collision certification.');
end
