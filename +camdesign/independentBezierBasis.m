function [basis,derivative,second]=independentBezierBasis(count,degree,u)
% Independent overlapping Bernstein windows, NOT Bezier_superposition.
% Window j uses controls j:j+degree over [j-1,j-1+degree]. Interior weights
% t^4(1-t)^4 have three vanishing derivatives at support ends. The first and
% last windows use one-sided weights. Caller handles endpoint constraints.
validateattributes(count,{'double'},{'scalar','integer','>=',4,'<=',250});
validateattributes(degree,{'double'},{'scalar','integer','>=',3,'<=',min(49,count-1)});
validateattributes(u,{'double'},{'vector','finite','real','>=',0,'<=',count-1});
u=u(:); persistent cache
if isempty(cache), cache={}; end
for k=1:numel(cache)
    item=cache{k};
    if item.count==count && item.degree==degree && isequal(item.u,u)
        basis=item.basis; derivative=item.derivative; second=item.second; return
    end
end
raw=zeros(numel(u),count); rawD=raw; rawDD=raw;
weightSum=zeros(numel(u),1); weightD=weightSum; weightDD=weightSum;
windows=count-degree;
for j=1:windows
    local=(u-(j-1))/degree; active=local>=0 & local<=1;
    if ~any(active), continue; end
    t=local(active); [b,db,ddb]=bernsteinBasis(degree,t);
    if windows==1
        w=ones(size(t)); dw=zeros(size(t)); ddw=dw;
    elseif j==1
        w=(1-t).^4; dw=-4*(1-t).^3/degree; ddw=12*(1-t).^2/degree^2;
    elseif j==windows
        w=t.^4; dw=4*t.^3/degree; ddw=12*t.^2/degree^2;
    else
        w=t.^4.*(1-t).^4;
        dw=(4*t.^3.*(1-t).^4-4*t.^4.*(1-t).^3)/degree;
        ddw=(12*t.^2.*(1-t).^4-32*t.^3.*(1-t).^3+12*t.^4.*(1-t).^2)/degree^2;
    end
    columns=j:j+degree;
    raw(active,columns)=raw(active,columns)+w.*b;
    rawD(active,columns)=rawD(active,columns)+dw.*b+w.*db/degree;
    rawDD(active,columns)=rawDD(active,columns)+ddw.*b+2*dw.*db/degree+w.*ddb/degree^2;
    weightSum(active)=weightSum(active)+w; weightD(active)=weightD(active)+dw;
    weightDD(active)=weightDD(active)+ddw;
end
assert(all(weightSum>0),'cam:BezierWeights','独立贝塞尔融合权重出现空缺。');
basis=raw./weightSum; derivative=(rawD-basis.*weightD)./weightSum;
second=(rawDD-basis.*weightDD-2*derivative.*weightD)./weightSum;
assert(all(isfinite(basis),'all') && all(isfinite(derivative),'all') ...
    && all(isfinite(second),'all'),'cam:ConstraintNonfinite','贝塞尔基函数非有限。');
cache=[{struct('count',count,'degree',degree,'u',u,'basis',basis,'derivative',derivative,'second',second)},cache];
cache=cache(1:min(4,numel(cache)));
end
function [b,d,dd]=bernsteinBasis(n,t)
b=bernstein(n,t); low=bernstein(n-1,t); lower=bernstein(n-2,t);
z=zeros(numel(t),1);
d=n*([z,low]-[low,z]);
dd=n*(n-1)*([z,z,lower]-2*[z,lower,z]+[lower,z,z]);
end
function b=bernstein(n,t)
b=zeros(numel(t),n+1);
for j=0:n, b(:,j+1)=nchoosek(n,j)*t.^j.*(1-t).^(n-j); end
end
