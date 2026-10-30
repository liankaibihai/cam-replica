function [pairs,locations] = selfIntersections(points)
% Nonadjacent line intersections, including touching/collinear overlaps.
% Optional coordinates preserve one row per detected pair. Overlapping or
% tolerance-level contacts use a representative midpoint, not unique points.
if norm(points(1,:)-points(end,:))>1e-8, points=[points;points(1,:)]; end
A=points(1:end-1,:); B=points(2:end,:); n=size(A,1); pairs=zeros(0,2);
cross2=@(x,y) x(:,1).*y(:,2)-x(:,2).*y(:,1);
tol=1e-9*max(1,max(abs(points),[],'all'));
for i=1:n-2
    j=(i+2:n)'; if i==1, j(j==n)=[]; end
    if isempty(j), continue; end
    overlap=all(max(min(A(i,:),B(i,:)),min(A(j,:),B(j,:))) <= ...
        min(max(A(i,:),B(i,:)),max(A(j,:),B(j,:)))+tol,2);
    j=j(overlap); if isempty(j), continue; end
    u=B(i,:)-A(i,:); v=B(j,:)-A(j,:);
    c1=cross2(repmat(u,numel(j),1),A(j,:)-A(i,:));
    c2=cross2(repmat(u,numel(j),1),B(j,:)-A(i,:));
    c3=cross2(v,A(i,:)-A(j,:)); c4=cross2(v,B(i,:)-A(j,:));
    hit=(min(c1,c2)<=tol & max(c1,c2)>=-tol & min(c3,c4)<=tol & max(c3,c4)>=-tol);
    pairs=[pairs;repmat(i,sum(hit),1),j(hit)]; %#ok<AGROW>
end
if nargout<2, return; end
locations=zeros(size(pairs,1),2);
for k=1:size(pairs,1)
    i=pairs(k,1); j=pairs(k,2);
    a=A(i,:); c=A(j,:); u=B(i,:)-a; v=B(j,:)-c;
    denominator=cross2(u,v);
    parallelTolerance=16*eps(max([1,dot(u,u),dot(v,v)]));
    if abs(denominator)>parallelTolerance
        t=cross2(c-a,v)/denominator; s=cross2(c-a,u)/denominator;
        first=a+min(1,max(0,t))*u; second=c+min(1,max(0,s))*v;
    elseif dot(u,u)>=dot(v,v) && dot(u,u)>eps
        interval=[dot(c-a,u),dot(c+v-a,u)]/dot(u,u);
        t=min(1,max(0,(max(0,min(interval))+min(1,max(interval)))/2));
        first=a+t*u;
        s=min(1,max(0,dot(first-c,v)/max(dot(v,v),eps))); second=c+s*v;
    elseif dot(v,v)>eps
        interval=[dot(a-c,v),dot(a+u-c,v)]/dot(v,v);
        s=min(1,max(0,(max(0,min(interval))+min(1,max(interval)))/2));
        second=c+s*v;
        t=min(1,max(0,dot(second-a,u)/max(dot(u,u),eps))); first=a+t*u;
    else
        first=a; second=c;
    end
    locations(k,:)=(first+second)/2;
end
end
