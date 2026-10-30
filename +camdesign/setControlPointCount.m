function [project,info]=setControlPointCount(project,count)
% Cubic increase is exact insertion; reduction/Bezier resampling rebuilds.
camdesign.validateProject(project);
validateattributes(count,{'double'},{'scalar','integer','finite','>=',2,'<=',250});
oldCount=size(project.nodes,1); mode=camdesign.routeModel(project.params);
preserved=true; skipped=0;
if strcmp(mode,'bspline-v1')
    if count~=oldCount
        [project,fitInfo]=camdesign.toBSpline(project,count,project.params.bspline.degree);
        preserved=false;
    end
elseif strcmp(mode,'bezier-blend-independent-v1')
    assert(count>=project.params.bezier.degree+1,'cam:BezierCount','控制点数量须大于贝塞尔阶数。');
    if count~=oldCount
        project.nodes=interp1(linspace(0,1,oldCount)',project.nodes,linspace(0,1,count)','linear');
        preserved=false;
    end
elseif count>oldCount
    while size(project.nodes,1)<count
        [px,py,stations]=camdesign.routeSpline(project.nodes,project.params);
        middle=(stations(1:end-1)+stations(2:end))/2;
        points=[ppval(px,middle),ppval(py,middle)]; bounds=project.params.bounds;
        inside=all(points>=bounds([1 3]) & points<=bounds([2 4]),2);
        skipped=max(skipped,nnz(~inside)); lengths=diff(stations); lengths(~inside)=-Inf;
        [longest,segment]=max(lengths);
        assert(isfinite(longest),'cam:ControlCountUnavailable','场内无可保形插入的区段，未裁剪场外点。');
        project=camdesign.refineRoute(project,double(segment));
    end
elseif count<oldCount
    project=camdesign.refineRoute(project,[]); retained=round(linspace(1,oldCount,count));
    project.nodes=project.nodes(retained,:);
    project.params.routeSpline.stations=project.params.routeSpline.stations(retained);
    preserved=false;
end
camdesign.validateProject(project);
info=struct('oldCount',oldCount,'actualCount',size(project.nodes,1), ...
    'shapePreservationGuaranteed',preserved,'outsideSegmentsSkipped',skipped,'targetOrderUnchanged',true);
if exist('fitInfo','var'), info.fitInfo=fitInfo; end
end
