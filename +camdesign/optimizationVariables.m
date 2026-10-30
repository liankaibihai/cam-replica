function map=optimizationVariables(project,endDerivative)
% Eliminate exact endpoint equalities. Returned coordinates are orthonormal
% displacements in mm. Old unconstrained cubic/Bezier keep their old mapping.
if nargin<2, endDerivative=[]; end
n=size(project.nodes,1); mode=camdesign.routeModel(project.params);
E=zeros(1,n); E(1)=1; rhs=project.nodes(1,:); labels={'initial-position'};
if strcmp(mode,'bspline-v1')
    [~,D]=camdesign.bsplineBasis(project.params.bspline.knots,project.params.bspline.degree, ...
        [0;project.params.bspline.parameterLength]);
    E=[E;D(1,:)]; rhs=[rhs;cosd(project.params.headingDeg+project.params.startSteeringDeg),sind(project.params.headingDeg+project.params.startSteeringDeg)];
    labels{end+1}='initial-parameter-derivative';
    if isempty(endDerivative), endDerivative=project.params.bspline.endDerivative; end
    E=[E;D(2,:)]; rhs=[rhs;endDerivative]; labels{end+1}='final-parameter-derivative';
elseif ~isempty(endDerivative)
    if strcmp(mode,'bezier-blend-independent-v1')
        row=zeros(1,n); row(end-1:end)=[-1 1]*(n-1)/project.params.bezier.parameterLength;
        E=[E;row]; rhs=[rhs;endDerivative]; labels{end+1}='final-parameter-derivative';
    else
        [~,~,~,actual]=camdesign.routeSpline(project.nodes,project.params);
        assert(norm(actual-endDerivative)<1e-10,'cam:EndDerivative', ...
            '三次插值路线须先冻结与EndDerivative一致的routeSpline.endDerivative。');
        assert(isfield(project.params,'routeSpline'),'cam:EndDerivative','请先冻结三次样条站位与末端导数。');
        labels{end+1}='final-parameter-derivative-in-spline';
    end
end
norms=vecnorm(E,2,2); E=E./norms; rhs=rhs./norms;
assert(max(abs(E*project.nodes-rhs),[],'all')<1e-7,'cam:EndpointConstraint', ...
    '初始控制点不满足端点约束；请先受约束拟合，优化不会静默投影输入。');
if size(E,1)==1, Z=[zeros(1,n-1);eye(n-1)]; else, Z=null(E); end
map=struct('basis',Z,'constraintMatrix',E,'constraintRHS',rhs, ...
    'constraintRank',2*rank(E),'effectiveDOF',2*size(Z,2), ...
    'coordinateVariables',2*n,'endpointConstraints',{labels},'endDerivative',endDerivative);
end
