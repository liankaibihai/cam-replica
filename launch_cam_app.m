function app = launch_cam_app()
% Run this from the project directory in MATLAB R2025b.
addpath(fileparts(mfilename('fullpath')));
app=CamReplicaApp();
if nargout==0, assignin('base','camReplicaApp',app); end
end
