function app = launch_cam_app(project)
% Run this from the project directory in MATLAB R2025b.
addpath(fileparts(mfilename('fullpath')));
if nargin<1 && evalin('base','exist(''camReplicaApp'',''var'')')
    existing=evalin('base','camReplicaApp');
    if isa(existing,'CamReplicaApp') && isvalid(existing) && isgraphics(existing.Figure)
        app=existing;
        warning('cam:AppAlreadyOpen', ...
            '已有窗口及未保存输入保持不变。源码更新后若按钮报匿名回调错误，请运行 repair_cam_app_callbacks(camReplicaApp)，不要清空工作区或关闭旧窗。');
        return;
    end
end
if nargin<1, project=camdesign.teamSolarProject(); end
camdesign.validateProject(project);
app=CamReplicaApp('off');
app.Project=project; app.syncInputs(); app.calculate();
app.Figure.Visible='on';
app.message(project.name);
app.message(project.provenance);
if nargout==0, assignin('base','camReplicaApp',app); end
end
