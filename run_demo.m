function report = run_demo()
root=fileparts(mfilename('fullpath')); addpath(root);
project=camdesign.defaultProject();
before=camdesign.evaluate(project); project.params.iterations=15;
[optimized,history]=camdesign.optimize(project,@progress);
result=camdesign.evaluate(optimized); sim=camdesign.simulate(result.cam,optimized.params, ...
    result.route.front(1,:),result.route.heading(1));
output=fullfile(root,'outputs','demo'); paths=camdesign.exportResult(optimized,result,output);
fig=figure('Visible','off','Position',[80 80 1300 700],'Color','w'); cleanup=onCleanup(@()close(fig));
tiledlayout(2,2,'TileSpacing','compact');
nexttile([2 1]); hold on;
plot(before.route.sensor(:,1),before.route.sensor(:,2),'--','LineWidth',1.1);
plot(result.route.sensor(:,1),result.route.sensor(:,2),'LineWidth',1.5);
scatter(project.targets(:,1),project.targets(:,2),40,'k','o');
plot(sim.sensor(:,1),sim.sensor(:,2),':k'); axis equal; grid on;
legend('Initial sensor path','Optimized sensor path','Checkpoints','Inverse simulation','Location','southoutside');
xlabel('X / mm'); ylabel('Y / mm'); title('Independent cam design / 2027 example');
nexttile; plot(result.cam.pitch(:,1),result.cam.pitch(:,2)); hold on;
plot(result.cam.actual(:,1),result.cam.actual(:,2)); axis equal; grid on;
legend('Pitch curve','Roller envelope'); xlabel('X / mm'); ylabel('Y / mm');
nexttile; plot([history.iteration],[history.score],'-o'); grid on;
xlabel('Optimization iteration'); ylabel('Independent objective');
exportgraphics(fig,fullfile(output,'preview.png'),'Resolution',120);
report=struct('before',before.metrics,'after',result.metrics,'history',history, ...
    'inverseErrorMM',max(vecnorm(sim.sensor-result.route.sensor,2,2)),'paths',paths);
fid=fopen(fullfile(output,'demo_summary.json'),'w','n','UTF-8'); cleanFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fprintf('DEMO_RESULT %s\n',jsonencode(report.after));
    function stop=progress(iteration,~,h)
        fprintf('DEMO iteration=%d objective=%.6f error_mm=%.4f\n',iteration,h(end).score,h(end).maxHitError);
        stop=false;
    end
end
