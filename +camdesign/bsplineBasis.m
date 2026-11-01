function [B,D1,D2,D3]=bsplineBasis(knots,degree,u)
% Cox-de Boor basis and analytic derivatives, including one-sided endpoints.
% No Curve Fitting/Spline Toolbox dependency. Repeated interior knots allowed.
knots=knots(:)'; u=u(:); n=numel(knots)-degree-1;
assert(degree>=0 && degree==fix(degree) && n>degree && all(diff(knots)>=0), ...
    'cam:BSplineKnots','B样条节点向量无效。');
lo=knots(degree+1); hi=knots(n+1);
assert(hi>lo && all(isfinite(u)) && all(u>=lo & u<=hi), ...
    'cam:BSplineDomain','B样条参数超出定义域。');
persistent cache
if ~isempty(cache)
    for k=1:numel(cache)
        c=cache{k};
        if c.degree==degree && isequal(c.knots,knots) && isequal(c.u,u)
            B=c.B; D1=c.D1; D2=c.D2; D3=c.D3; return;
        end
    end
end
N=double(u>=knots(1:end-1) & u<knots(2:end));
% At the right boundary choose the final nonzero interval's left limit.
last=find(knots(1:end-1)<hi & knots(2:end)>=hi,1,'last');
N(u==hi,:)=0; N(u==hi,last)=1;
V=zeros(size(N)); A=V; J=V;
for d=1:degree
    m=numel(knots)-d-1; Q=zeros(numel(u),m); W=Q; H=Q; K=Q;
    for i=1:m
        left=knots(i+d)-knots(i); right=knots(i+d+1)-knots(i+1);
        if left>0
            Q(:,i)=Q(:,i)+(u-knots(i))/left.*N(:,i);
            W(:,i)=W(:,i)+d/left*N(:,i);
            H(:,i)=H(:,i)+d/left*V(:,i);
            K(:,i)=K(:,i)+d/left*A(:,i);
        end
        if right>0
            Q(:,i)=Q(:,i)+(knots(i+d+1)-u)/right.*N(:,i+1);
            W(:,i)=W(:,i)-d/right*N(:,i+1);
            H(:,i)=H(:,i)-d/right*V(:,i+1);
            K(:,i)=K(:,i)-d/right*A(:,i+1);
        end
    end
    N=Q; V=W; A=H; J=K;
end
B=N; D1=V; D2=A; D3=J;
c=struct('knots',knots,'degree',degree,'u',u,'B',B,'D1',D1,'D2',D2,'D3',D3);
cache=[{c},cache]; cache=cache(1:min(6,numel(cache)));
end
