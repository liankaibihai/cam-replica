function features=video251Features(controlPoints,frontPath,frontWheelAngles)
%VIDEO251FEATURES Raw features visible in the 2.5.1 tutorial, not its score.
% Inputs: finite double N-by-2 control points, M-by-2 front path (mm), and
% a signed angle vector in radians. The angle count need not equal M.
% Evidence: docs/BEZIER_SOURCE_AUDIT.md, Simulation_cal lines 3-36,
% video 861804050-1-208.mp4 at 570-588 s. No Squares_standard_sum,
% distance_calculate, score_cal, or original Bezier generator is supplied.
validateattributes(controlPoints,{'double'},{'2d','ncols',2,'real','finite'},mfilename,'controlPoints');
validateattributes(frontPath,{'double'},{'2d','ncols',2,'real','finite'},mfilename,'frontPath');
validateattributes(frontWheelAngles,{'double'},{'vector','nonempty','real','finite'},mfilename,'frontWheelAngles');
assert(size(controlPoints,1)>=2,'cam:Video251ControlPointCount','控制折线至少需要两个点。');
assert(size(frontPath,1)>=2,'cam:Video251FrontPointCount','前轮折线至少需要两个点。');

frontEdges=frontPath(2:end,:)-frontPath(1:end-1,:);
frontSegmentLengths=(frontEdges(:,1).^2+frontEdges(:,2).^2).^0.5;
controlEdges=controlPoints(2:end,:)-controlPoints(1:end-1,:);
controlSegmentLengths=(controlEdges(:,1).^2+controlEdges(:,2).^2).^0.5;
% Diagnostic API guards: not claimed to be present in the filmed source.
assert(all(controlSegmentLengths>0),'cam:Video251ZeroControlEdge','控制折线存在零长段，不能计算相邻单位边夹角。');
assert(all(frontSegmentLengths>0),'cam:Video251ZeroFrontEdge','前轮折线存在零长段；请提供无相邻重复点的诊断输入。');

unitEdges=controlEdges./[controlSegmentLengths,controlSegmentLengths];
cosine=unitEdges(2:end,1).*unitEdges(1:end-1,1)+unitEdges(2:end,2).*unitEdges(1:end-1,2);
cosine(cosine>1)=1; cosine(cosine<-1)=-1;
controlTurns=acos(cosine);
controlFirst=controlTurns(2:end)-controlTurns(1:end-1);
controlSecond=controlFirst(2:end)-controlFirst(1:end-1);
angles=frontWheelAngles(:);
wheelFirst=angles(2:end)-angles(1:end-1);
wheelSecond=wheelFirst(2:end)-wheelFirst(1:end-1);

features=struct('sourceVersion','2.5.1-visible-fragment','angleUnit','rad','lengthUnit','mm', ...
    'controlPointCount',size(controlPoints,1),'frontPathPointCount',size(frontPath,1),'frontWheelAngleCount',numel(angles), ...
    'frontSegmentLengthsMM',frontSegmentLengths,'frontPolylineLengthMM',sum(frontSegmentLengths), ...
    'controlSegmentLengthsMM',controlSegmentLengths,'controlTurnAnglesRad',controlTurns, ...
    'controlTurnFirstDifferenceRad',controlFirst,'controlTurnSecondDifferenceRad',controlSecond, ...
    'frontWheelAnglesRad',angles,'frontWheelFirstDifferenceRad',wheelFirst,'frontWheelSecondDifferenceRad',wheelSecond, ...
    'aggregationImplemented',false,'scoreImplemented',false);
end
