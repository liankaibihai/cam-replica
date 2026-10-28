function result = ppDerivative(pp,order)
% Differentiate a scalar pp spline without Curve Fitting Toolbox.
result=pp;
for j=1:order
    [breaks,c,~,k,d]=unmkpp(result);
    if k<=1, c=zeros(size(c,1),1); else, c=c(:,1:k-1).*(k-1:-1:1); end
    result=mkpp(breaks,c,d);
end
end
