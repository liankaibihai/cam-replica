function saveProject(project,filename)
camdesign.validateProject(project);
save(filename,'project','-v7');
end
