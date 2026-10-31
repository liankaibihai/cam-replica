function handled=cam_candidate_ui(app,key)
handled=true;
if strcmp(key,'install')
    root=findall(app.Figure,'Tag','cam-candidate-menu');
    if isempty(root)
        root=uimenu(app.Figure,'Text','候选并行（默认关闭）','Tag','cam-candidate-menu');
        rows={'候选并行开关','candidate-toggle';'2个候选worker','candidate-two';'4个候选worker','candidate-four';'准备候选进程池','candidate-prepare'};
        for k=1:size(rows,1), uimenu(root,'Text',rows{k,1},'Tag',['cam-' rows{k,2}], ...
                'MenuSelectedFcn',cam_app_ui_callback(app,rows{k,2})); end
    end
elseif startsWith(key,'candidate-')
    assert(~app.Busy,'cam:CandidateBusy','先停止当前任务再设置候选并行。');
    switch key
        case 'candidate-toggle', setappdata(app.Figure,'camCandidateEnabled',~enabled(app));
        case 'candidate-two', setappdata(app.Figure,'camCandidateWorkers',2);
        case 'candidate-four', setappdata(app.Figure,'camCandidateWorkers',4);
        case 'candidate-prepare'
            n=count(app); pool=gcp('nocreate');
            if ~isempty(pool) && (isa(pool,'parallel.ThreadPool') || pool.Cluster.NumThreads<n)
                assert(isempty(pool.FevalQueue.RunningFutures) && isempty(pool.FevalQueue.QueuedFutures), ...
                    'cam:CandidatePoolBusy','现有池仍有任务，未替换。');
                choice=uiconfirm(app.Figure,'需要替换现有空闲池，才能为协调进程配置候选线程。是否继续？', ...
                    '准备候选池','Options',{'替换空闲池','取消'},'DefaultOption',2,'CancelOption',2);
                if ~strcmp(choice,'替换空闲池'), return; end
                delete(pool); % Explicit UI confirmation; no running futures.
            end
            cam_candidate_pool(n);
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
value=false; if isappdata(app.Figure,'camCandidateEnabled'), value=getappdata(app.Figure,'camCandidateEnabled'); end
end
function value=count(app)
value=2; if isappdata(app.Figure,'camCandidateWorkers'), value=getappdata(app.Figure,'camCandidateWorkers'); end
end
