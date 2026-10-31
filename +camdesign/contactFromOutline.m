function [q,contact]=contactFromOutline(outline,r,phase,options)
% Exact radial intersection with the outer boundary of polygon (+) disk(r).
% Positive phase rotates the physical cam clockwise; follower is fixed +X.
% Capsule candidates include BOTH endpoint circles and segment offset sides.
arguments
    outline double
    r (1,1) double {mustBeFinite,mustBeReal}
    phase double
    options.ContactToleranceMM (1,1) double {mustBeFinite,mustBePositive}=1e-7
    options.RotationConvention char='clockwise-cam-fixed-positive-x-v1'
end
assert(r>0,'cam:ActualContactRadius','实际轮廓接触v1要求正接触半径；r=0尚不支持。');
assert(strcmp(options.RotationConvention,'clockwise-cam-fixed-positive-x-v1'), ...
    'cam:ActualRotationConvention','仅支持正相位对应凸轮顺时针、固定+X径向推杆；不会自动猜测其他旋向。');
assert(isvector(phase) && ~isempty(phase) && isreal(phase) && all(isfinite(phase)), ...
    'cam:ActualPhase','接触相位须为有限实数标量或向量（rad）。');
phase=phase(:); g=geometry(outline); m=numel(phase); n=size(g.A,1);
q=zeros(m,1); point=zeros(m,2); normal=point; pressure=q; distance=q;
feature=zeros(m,1); sourceSegment=feature; activeCount=feature; multiple=false(m,1);
tol=g.numericToleranceMM; maximumResidual=0; maximumPenetration=0;
for first=1:64:m
    index=first:min(m,first+63); phi=phase(index); co=cos(phi); si=sin(phi);
    % Coordinates after rotating the physical polygon by -phi.
    x=co*g.A(:,1)'+si*g.A(:,2)'; y=-si*g.A(:,1)'+co*g.A(:,2)';
    dx=co*g.V(:,1)'+si*g.V(:,2)'; dy=-si*g.V(:,1)'+co*g.V(:,2)';
    circles=x+sqrt(max(0,r^2-y.^2)); circles(abs(y)>r+tol)=-Inf;
    [radius,which]=max(circles,[],2); kind=ones(size(radius));
    nx=-dy./g.length'; ny=dx./g.length';
    for side=[-1 1]
        t=(-y-side*r*ny)./dy;
        valid=dy~=0 & t>=-1e-11 & t<=1+1e-11;
        t=max(0,min(1,t)); candidates=x+t.*dx+side*r*nx; candidates(~valid)=-Inf;
        [edgeRadius,edge]=max(candidates,[],2); changed=edgeRadius>radius;
        radius(changed)=edgeRadius(changed); which(changed)=edge(changed); kind(changed)=2;
    end
    assert(all(isfinite(radius) & radius>0),'cam:ActualContactFailure','实际轮廓未找到正向外侧接触。');
    % Independent distance-to-EVERY-segment check. This does not reuse the
    % capsule feature's intersection parameter or any design motion law.
    projection=((radius-x).*dx-y.*dy)./g.lengthSquared';
    projection=max(0,min(1,projection)); closestX=x+projection.*dx; closestY=y+projection.*dy;
    distanceSquared=(radius-closestX).^2+closestY.^2;
    minimum=sqrt(min(distanceSquared,[],2));
    residual=abs(minimum-r); penetration=max(0,r-minimum);
    [inside,on]=inpolygon(radius.*co,radius.*si,g.outline(:,1),g.outline(:,2));
    assert(all(~inside & ~on) && all(residual<=options.ContactToleranceMM), ...
        'cam:ActualContactFailure','实际轮廓接触残差或穿透检查失败；未使用理论半径替代。');
    % At multiple contacts report the worst pressure among the active
    % segments. Shared endpoint duplicates do not count as distinct contacts.
    active=sqrt(distanceSquared)<=minimum+tol;
    alpha=atan2(abs(closestY),radius-closestX); alpha(~active)=-Inf;
    [worst,selected]=max(alpha,[],2);
    linear=sub2ind(size(closestX),(1:numel(index))',selected);
    chosen=[closestX(linear),closestY(linear)]; vector=[radius-chosen(:,1),-chosen(:,2)];
    vector=vector./vecnorm(vector,2,2);
    distinct=active & hypot(closestX-chosen(:,1),closestY-chosen(:,2))>max(10*tol,1e-9);
    q(index)=radius; point(index,:)=chosen; normal(index,:)=vector; pressure(index)=worst;
    distance(index)=minimum; feature(index)=kind; sourceSegment(index)=which;
    activeCount(index)=sum(active,2); multiple(index)=any(distinct,2);
    maximumResidual=max(maximumResidual,max(residual)); maximumPenetration=max(maximumPenetration,max(penetration));
end
contact=struct('valid',true,'phase',phase,'centerRadiusMM',q,'point',point,'normal',normal, ...
    'pressure',pressure,'maxPressureDeg',rad2deg(max(pressure)),'minimumDistanceMM',distance, ...
    'maxResidualMM',maximumResidual,'maxContactResidualMM',maximumResidual, ...
    'maxPenetrationMM',maximumPenetration,'centerOutside',true, ...
    'featureType',feature,'sourceSegment',sourceSegment,'activeSegmentCount',activeCount, ...
    'multipleDistinctContacts',multiple,'rollerRadiusMM',r,'contactToleranceMM',options.ContactToleranceMM, ...
    'outlineVertexCount',n,'closureGapMM',g.closureGapMM,'inputWinding',g.winding, ...
    'rotationConvention',options.RotationConvention, ...
    'featureLegend','1=endpoint circle; 2=segment-offset side; contact point/normal are in stationary follower coordinates.', ...
    'scope','Rigid disk and fixed closed polygon, outermost radial contact; no friction, preload, elastic deformation or manufacturing uncertainty.');
end

function g=geometry(outline)
assert(ismatrix(outline) && size(outline,2)==2 && size(outline,1)>=4 && isreal(outline) ...
    && all(isfinite(outline),'all'),'cam:ActualOutlineInvalid','实际轮廓须为至少4行的有限实数XY闭合折线。');
persistent cached
if ~isempty(cached)
    for k=1:numel(cached)
        if isequal(cached{k}.input,outline), g=cached{k}; return; end
    end
end
scale=max(1,max(abs(outline),[],'all')); numerical=max(128*eps(scale),1e-12);
gap=norm(outline(1,:)-outline(end,:));
assert(gap<=max(1e-8,1e-10*scale),'cam:ActualOutlineOpen','实际轮廓未闭合；不会自动补一条未知闭合边。');
raw=outline; outline(end,:)=outline(1,:);
A=outline(1:end-1,:); V=diff(outline); lengths=vecnorm(V,2,2);
assert(all(isfinite(lengths) & lengths>numerical),'cam:ActualOutlineDegenerate','实际轮廓含零长度或不可分辨线段。');
area2=sum(A(:,1).*outline(2:end,2)-A(:,2).*outline(2:end,1));
assert(isfinite(area2) && abs(area2)>numerical*sum(lengths),'cam:ActualOutlineDegenerate','实际轮廓面积退化。');
next=circshift(V,-1,1); cross=V(:,1).*next(:,2)-V(:,2).*next(:,1);
backtrack=abs(cross)<=numerical.*(lengths+circshift(lengths,-1)) & sum(V.*next,2)<0;
assert(~any(backtrack),'cam:ActualOutlineSelfIntersection','实际轮廓含相邻回折重叠边。');
assert(isempty(camdesign.selfIntersections(outline)),'cam:ActualOutlineSelfIntersection','实际轮廓自交或非相邻接触，不能作为支持的实体凸轮。');
[inside,on]=inpolygon(0,0,outline(:,1),outline(:,2));
assert(inside && ~on,'cam:ActualOutlineOrigin','实际轮廓须严格包含凸轮原点。');
winding='counterclockwise'; if area2<0, winding='clockwise'; end
g=struct('input',raw,'outline',outline,'A',A,'V',V,'length',lengths,'lengthSquared',lengths.^2, ...
    'numericToleranceMM',numerical,'closureGapMM',gap,'winding',winding);
cached=[{g},cached]; cached=cached(1:min(2,numel(cached)));
end
