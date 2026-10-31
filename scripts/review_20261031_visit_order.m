function review_20261031_visit_order
targets=[0 0;100 0;100 100];
path=[0 0;100 100;100 0;100 100];
r=struct('front',path,'rear',path,'drive',path,'driven',path,'sensor',path);
h=camdesign.orderedHits(path,targets);
a=camdesign.auditSolarRoute(r,targets,[-200 200 -200 200],8.5);
out=struct('targets',targets,'path',path,'orderedProjection',h,'geometricVisitAudit',a.recognitionScenarios{1});
assert(all(h.errors==0)); assert(~a.recognitionScenarios{1}.matchesRequiredOrderAndVisitCount);
disp(jsonencode(out,PrettyPrint=true));
fid=fopen('local/review_20261031_visit_order.json','w'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(out,PrettyPrint=true));
end
