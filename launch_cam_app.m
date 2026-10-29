function app = launch_cam_app(project)
% Run this from the project directory in MATLAB R2025b.
addpath(fileparts(mfilename('fullpath')));
if nargin<1, project=camdesign.solarTestProject(); end
camdesign.validateProject(project);
app=CamReplicaApp('off');
app.Project=project; app.syncInputs(); app.calculate();
app.Figure.Visible='on';
app.message(project.name);
app.message(project.provenance);
if nargout==0, assignin('base','camReplicaApp',app); end
end
