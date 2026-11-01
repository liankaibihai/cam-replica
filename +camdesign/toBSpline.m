function [project,fitInfo]=toBSpline(project,count,degree)
% Fit the SAME source geometry, never reinterpret interpolating nodes as CPs.
% Uniform fixed clamped knots; initial position, initial unit derivative and
% source final parameter derivative are exact linear coefficient constraints.
camdesign.validateProject(project); source=project; mode=camdesign.routeModel(project.params);
validateattributes(degree,{'double'},{'scalar','integer'});
assert(ismember(degree,[3 5]),'cam:BSplineDegree','标准B样条仅支持三次或五次。');
validateattributes(count,{'double'},{'scalar','integer','>=',degree+1,'<=',250});
if strcmp(mode,'bspline-v1'), lengthMM=project.params.bspline.parameterLength;
elseif strcmp(mode,'bezier-blend-independent-v1'), lengthMM=project.params.bezier.parameterLength;
else, [~,~,stations]=camdesign.routeSpline(project.nodes,project.params); lengthMM=stations(end); end
interior=linspace(0,lengthMM,count-degree+1);
knots=[zeros(1,degree+1),interior(2:end-1),lengthMM*ones(1,degree+1)];
[ends,endD]=camdesign.routeGeometry(source.nodes,source.params,[0;lengthMM]);
startD=[cosd(project.params.headingDeg+project.params.startSteeringDeg),sind(project.params.headingDeg+project.params.startSteeringDeg)];
[E0,ED]=camdesign.bsplineBasis(knots,degree,[0;lengthMM]);
E=[E0(1,:);ED(1,:);ED(2,:)]; rhs=[ends(1,:);startD;endD(2,:)];
% Normalize constraint rows before nullspace/particular solution for mm units.
norms=vecnorm(E,2,2); E=E./norms; rhs=rhs./norms;
Z=null(E); particular=E'*((E*E')\rhs);
u=linspace(0,lengthMM,max(2001,40*count))';
F=camdesign.routeGeometry(source.nodes,source.params,u);
B=camdesign.bsplineBasis(knots,degree,u);
nodes=particular+Z*((B*Z)\(F-B*particular));
project.nodes=nodes; project.params.routeModel='bspline-v1';
for field={'routeSpline','bezier','bspline'}
    if isfield(project.params,field{1}), project.params=rmfield(project.params,field{1}); end
end
project.params.bspline=struct('type','fixed-clamped-bspline-v1','degree',degree, ...
    'knots',knots,'parameterLength',lengthMM,'endDerivative',endD(2,:));
camdesign.validateProject(project);
% Independent offset grid for reported fit error, not the LS training rows.
v=linspace(0,lengthMM,4002)'; v=v(1:2:end)+(lengthMM/4001)/2; v=min(v,lengthMM);
Q=camdesign.routeGeometry(source.nodes,source.params,v);
P=camdesign.bsplineRoute(nodes,project.params,v); errors=vecnorm(P-Q,2,2);
[~,actualD]=camdesign.bsplineRoute(nodes,project.params,[0;lengthMM]);
angles=atan2(abs(actualD(:,1).*endD(:,2)-actualD(:,2).*endD(:,1)),sum(actualD.*endD,2));
fitInfo=struct('sourceModel',mode,'degree',degree,'controlPointCount',count, ...
    'positionRMSMM',sqrt(mean(errors.^2)),'positionMaxMM',max(errors), ...
    'endpointPositionErrorMM',vecnorm(E0*nodes-ends,2,2)', ...
    'endpointDerivativeError',vecnorm(actualD-[startD;endD(2,:)],2,2)', ...
    'endpointTangentErrorDeg',rad2deg(angles)', ...
    'constraintRank',2*rank(E),'effectiveDOF',2*size(Z,2), ...
    'shapePreservationGuaranteed',false,'parameterLength',lengthMM, ...
    'endpointPolicy','Fixed initial position and full initial/final parameter derivatives; final position fitted.', ...
    'controlBoundsPolicy','Coefficients are not clipped; physical trajectory bounds are checked downstream.');
end
