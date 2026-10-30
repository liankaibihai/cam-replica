function report=check_independent_bezier_basis()
assert(batchStartupOptionUsed,'cam:BasisBatchOnly','Use an independent batch.');
root=fileparts(mfilename('fullpath')); addpath(root);
u=linspace(0,11,1001)'; [b,d,dd]=camdesign.independentBezierBasis(12,5,u);
assert(max(abs(sum(b,2)-1))<1e-12 && min(b,[],'all')>=-1e-14);
assert(max(abs(sum(d,2)))<1e-12 && max(abs(sum(dd,2)))<1e-11);
line=[(0:11)',zeros(12,1)];
assert(max(abs(b*line(:,1)-u))<1e-11);
assert(max(abs(d*line(:,1)-1))<1e-11 && max(abs(dd*line(:,1)))<1e-10);
controls=[0 0;1 3;2 -2;3 4;4 -1;5 0];
[reference,t]=camdesign.bezierCurve(controls,1000);
[single,sd,sdd]=camdesign.independentBezierBasis(6,5,5*t);
assert(max(abs(single*controls-reference),[],'all')<1e-12);
assert(norm(sd(1,:)*controls-(controls(2,:)-controls(1,:)))<1e-12);
assert(norm(sd(end,:)*controls-(controls(end,:)-controls(end-1,:)))<1e-12);
points=sin((0:11)'*[.9 1.3])*100;
query=[.13;1.27;3.82;5.12;8.61;10.73]; h=1e-4;
[base,first,second]=camdesign.independentBezierBasis(12,5,query);
plus=camdesign.independentBezierBasis(12,5,query+h);
minus=camdesign.independentBezierBasis(12,5,query-h);
firstError=max(abs(first*points-(plus-minus)*points/(2*h)),[],'all');
secondError=max(abs(second*points-(plus-2*base+minus)*points/h^2),[],'all');
assert(firstError<1e-5 && secondError<1e-4);
joins=(1:10)'; epsilon=1e-6;
[left,ld,ldd]=camdesign.independentBezierBasis(12,5,joins-epsilon);
[right,rd,rdd]=camdesign.independentBezierBasis(12,5,joins+epsilon);
joinDifferences=[max(abs((left-right)*points),[],'all'), ...
    max(abs((ld-rd)*points),[],'all'),max(abs((ldd-rdd)*points),[],'all')];
assert(all(joinDifferences<1e-3));
% Cache hits must not confuse arbitrary vectors sharing their endpoints/size.
other=query; other(3)=other(3)+.2; a=camdesign.independentBezierBasis(12,5,other);
assert(norm(a-base,'fro')>1e-3);
again=camdesign.independentBezierBasis(12,5,query); assert(isequaln(again,base));
for point=[0 3.2 11]
    [one,oneD,oneDD]=camdesign.independentBezierBasis(12,5,point);
    [batch,batchD,batchDD]=camdesign.independentBezierBasis(12,5,[point;point]);
    assert(isequal(one,batch(1,:)) && isequal(oneD,batchD(1,:)) && isequal(oneDD,batchDD(1,:)));
end
report=struct('release',version('-release'),'checks',7,'firstDifferenceError',firstError, ...
    'secondDifferenceError',secondError,'joinDifferences',joinDifferences, ...
    'scope','Independent raw Bernstein partition, constant/linear reproduction, source single-curve agreement, analytic derivatives and cache keys. Endpoint constraints and vehicle integration tested separately.');
folder=fullfile(root,'outputs','training_controls_20261030'); if ~isfolder(folder), mkdir(folder); end
fid=fopen(fullfile(folder,'bezier_basis_verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('INDEPENDENT_BEZIER_BASIS_PASS checks=7 firstError=%.9g secondError=%.9g scalarQueries=true\n',firstError,secondError);
end
