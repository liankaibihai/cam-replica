function pairs = selfIntersections(points)
% Nonadjacent line intersections, including touching/collinear overlaps.
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
end
