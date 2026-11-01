function handled=cam_candidate_ui(app,key)
handled=true;
if strcmp(key,'install')
    rows={'候选并行开关','candidate-toggle';'2个候选线程','candidate-two';'4个候选线程','candidate-four';'检查候选线程资源','candidate-prepare'};
    root=findall(app.Figure,'Tag','cam-candidate-menu');
    if isempty(root)
        root=uimenu(app.Figure,'Text','候选并行（默认4线程）','Tag','cam-candidate-menu');
        for k=1:size(rows,1), uimenu(root,'Text',rows{k,1},'Tag',['cam-' rows{k,2}], ...
                'MenuSelectedFcn',cam_app_ui_callback(app,rows{k,2})); end
    end
    root.Text='候选线程：四方向/接力（其他方法串行）';
    for k=1:size(rows,1)
        item=findall(root,'Tag',['cam-' rows{k,2}]); assert(isscalar(item),'cam:CandidateIdentity','候选菜单项不唯一。');
        item.Text=rows{k,1};
    end
elseif startsWith(key,'candidate-')
    assert(~app.Busy,'cam:CandidateBusy','先停止当前任务再设置候选并行。');
    switch key
        case 'candidate-toggle', setappdata(app.Figure,'camCandidateEnabled',~enabled(app));
        case 'candidate-two', setappdata(app.Figure,'camCandidateWorkers',2);
        case 'candidate-four', setappdata(app.Figure,'camCandidateWorkers',4);
        case 'candidate-prepare'
            cam_candidate_pool(count(app));
    end
else, handled=false; return;
end
for item=findall(app.Figure,'Type','uimenu')'
    if strcmp(item.Tag,'cam-candidate-toggle'), item.Checked=enabled(app);
    elseif strcmp(item.Tag,'cam-candidate-two'), item.Checked=count(app)==2;
    elseif strcmp(item.Tag,'cam-candidate-four'), item.Checked=count(app)==4; end
end
end
function value=enabled(app)
value=true; if isappdata(app.Figure,'camCandidateEnabled'), value=getappdata(app.Figure,'camCandidateEnabled'); end
end
function value=count(app)
value=4; if isappdata(app.Figure,'camCandidateWorkers'), value=getappdata(app.Figure,'camCandidateWorkers'); end
end
