function result = orderedHits(path,targets)
% Greedy ordered projection onto polyline segments (geometric, not RFID score).
A=path(1:end-1,:); V=diff(path); den=sum(V.^2,2);
N=size(A,1); lower=1; fraction=0; errors=zeros(size(targets,1),1);
points=zeros(size(targets)); indices=errors;
for k=1:size(targets,1)
    t=sum((targets(k,:)-A).*V,2)./max(den,eps);
    t=max(0,min(1,t)); t(lower)=max(t(lower),fraction);
    Q=A+t.*V; dist=vecnorm(Q-targets(k,:),2,2); dist(1:lower-1)=inf;
    [errors(k),which]=min(dist); points(k,:)=Q(which,:);
    lower=min(which,N); fraction=t(which); indices(k)=which+t(which);
end
result=struct('errors',errors,'points',points,'indices',indices);
end
