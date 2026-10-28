function report = compare_reference_files(referenceFile,candidateFile,options)
% Compare original app exported points with replica output, without alignment.
% Example: compare_reference_files('original.txt','cam_actual_candidate.csv', ...
%     ReferenceColumns=[1 2],CandidateColumns=[2 3],Closed=true)
arguments
    referenceFile (1,:) char
    candidateFile (1,:) char
    options.ReferenceColumns (1,2) double = [1 2]
    options.CandidateColumns (1,2) double = [1 2]
    options.Closed (1,1) logical = false
    options.OutputDirectory (1,:) char = fullfile(pwd,'outputs','reference_comparison')
end
R=camdesign.readXY(referenceFile,options.ReferenceColumns);
C=camdesign.readXY(candidateFile,options.CandidateColumns);
report=camdesign.compareCurves(R,C,Closed=options.Closed);
report.referenceFile=referenceFile; report.candidateFile=candidateFile;
if ~isfolder(options.OutputDirectory), mkdir(options.OutputDirectory); end
fid=fopen(fullfile(options.OutputDirectory,'comparison.json'),'w','n','UTF-8');
assert(fid>=0,'cam:ComparisonOutput','无法写入对照报告。'); cleanupFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fig=figure('Visible','off','Color','w'); cleanupFigure=onCleanup(@()close(fig));
plot(R(:,1),R(:,2),'b-','LineWidth',1.3); hold on;
plot(C(:,1),C(:,2),'r--','LineWidth',1.3); axis equal; grid on;
xlabel('X / mm'); ylabel('Y / mm'); legend('Original export','Replica export','Location','best');
title(sprintf('No alignment | sampled max distance %.6g mm',report.sampledSymmetricMaxMM));
exportgraphics(fig,fullfile(options.OutputDirectory,'overlay.png'),'Resolution',150);
fprintf('%s\n',jsonencode(report,'PrettyPrint',true));
end
