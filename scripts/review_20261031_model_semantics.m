function review_20261031_model_semantics
% Find-only diagnostic: no optimization, no edits to user projects.
p=camdesign.solarTestProject(); p=camdesign.setControlPointCount(p,34);
u=linspace(0,1,4001)';
[~,~,st]=camdesign.routeSpline(p.nodes,p.params);
before=camdesign.routeGeometry(p.nodes,p.params,u*st(end));
[q,info]=camdesign.applyTrainingSettings(p,struct('routeModel','bezier-blend-independent-v1','bezierDegree',5),'peak-gradient-v2');
after=camdesign.routeGeometry(q.nodes,q.params,u*q.params.bezier.parameterLength);
out=struct;
out.cubicToBezier.nodesUnchanged=isequal(p.nodes,q.nodes);
out.cubicToBezier.sameParameterMaxMM=max(vecnorm(before-after,2,2));
out.cubicToBezier.hausdorffSampledMM=hausdorff(before,after);
out.cubicToBezier.conversionInfo=info;
[r,backInfo]=camdesign.applyTrainingSettings(q,struct('routeModel','cubic'),'peak-gradient-v2');
[~,~,sr]=camdesign.routeSpline(r.nodes,r.params);
back=camdesign.routeGeometry(r.nodes,r.params,u*sr(end));
out.bezierToCubic.nodesUnchanged=isequal(q.nodes,r.nodes);
out.bezierToCubic.sameParameterMaxMM=max(vecnorm(after-back,2,2));
out.bezierToCubic.hausdorffSampledMM=hausdorff(after,back);
out.bezierToCubic.conversionInfo=backInfo;
out.roundTripToOriginalMM=max(vecnorm(before-back,2,2));
% Point-count change can return a false preservation claim if degree changes first.
[d,degreeInfo]=camdesign.applyTrainingSettings(q,struct('bezierDegree',3),'peak-gradient-v2');
deg=camdesign.routeGeometry(d.nodes,d.params,u*d.params.bezier.parameterLength);
out.degreeChange.nodesUnchanged=isequal(q.nodes,d.nodes);
out.degreeChange.sameParameterMaxMM=max(vecnorm(after-deg,2,2));
out.degreeChange.hausdorffSampledMM=hausdorff(after,deg);
out.degreeChange.info=degreeInfo;
fig=figure('Visible','off','Position',[100 100 1200 480]); closeFig=onCleanup(@()close(fig));
plot(before(:,1),before(:,2),'k-','LineWidth',1.7); hold on;
plot(after(:,1),after(:,2),'r-','LineWidth',1.7);
plot(p.nodes(:,1),p.nodes(:,2),'o','Color',[.35 .65 .35],'MarkerSize',4);
plot(p.targets(:,1),p.targets(:,2),'bs','MarkerSize',7);
axis equal; grid on; xlabel('X / mm'); ylabel('Y / mm');
legend('Original cubic','Same coordinates as Bezier degree 5','Unchanged node array','Competition targets','Location','southoutside','NumColumns',4);
title('Model switch only: no optimization performed');
exportgraphics(fig,'local/review_20261031_model_switch.png','Resolution',140);
disp(jsonencode(out,PrettyPrint=true));
fid=fopen('local/review_20261031_model_semantics.json','w'); c=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(out,PrettyPrint=true));
end
function h=hausdorff(a,b)
da=inf(size(a,1),1); db=inf(size(b,1),1);
for k=1:size(a,1)
    dist=vecnorm(b-a(k,:),2,2); da(k)=min(dist); db=min(db,dist);
end
h=max([da;db]);
end
