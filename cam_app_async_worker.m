function outcome=cam_app_async_worker(job,queue)
% Pure-data background adapter. Existing solvers and their budget owner stay
% on this one worker; this does not parallelize candidate search.
control=parallel.pool.PollableDataQueue;
send(queue,struct('runId',job.runId,'type','ready','control',control));
timer=tic; lastSent=-Inf; stopped=false; awaitingPreview=false; sequence=0; displayEvaluations=0;
outcome=struct('runId',job.runId,'kind',job.kind,'status','success','project',job.project, ...
    'result',[],'history',[],'info',struct(),'report',[],'simulation',[], ...
    'postProcessingEvaluations',0,'displayEvaluationAttempts',0,'elapsedSeconds',0,'errorIdentifier','','errorMessage','');
outcome.refinedInspection=[];
ledger=[];
try
    if shouldStop(), outcome.status='stopped'; return; end
    switch job.kind
        case 'calculate'
            outcome.result=camdesign.evaluate(job.project,true);
            if shouldStop(), outcome.status='stopped'; outcome.result=[]; end
        case 'optimize'
            options=struct();
            if isfield(job,'candidateWorkers') && job.candidateWorkers>0
                options.CandidateWorkers=job.candidateWorkers;
                limit=Inf; seconds=Inf;
                if ismember(job.algorithm,{'relay-sqp-v1','multistart-relay-sqp-v1'}), limit=200000; seconds=3600; end
                ledger=camdesign.PhysicalEvaluationBudget(limit,seconds); options.Budget=ledger;
            end
            [project,history,info]=camdesign.optimize(job.project,@progress,job.algorithm,options);
            outcome.project=project; outcome.history=history; outcome.info=info;
            if isfield(info,'cachedFinalResult') && ~isempty(info.cachedFinalResult)
                outcome.result=info.cachedFinalResult;
            else
                % The synchronous UI also calculates once after these older
                % backends. Keep it off the UI thread and report separately.
                outcome.result=camdesign.evaluate(project,true); outcome.postProcessingEvaluations=1;
            end
            if isfield(info,'verification') && isfield(info.verification,'refinedGrid')
                fine=info.verification.refinedGrid;
                if fine.valid && ~isempty(fine.metrics) && fine.metrics.intersectionCount>0
                    outcome.refinedInspection=camdesign.camInspectionData(project,outcome.result,info,'refined');
                    outcome.postProcessingEvaluations=outcome.postProcessingEvaluations+1;
                end
            end
        case 'actual-closure'
            outcome.result=camdesign.evaluate(job.project,true);
            if shouldStop(), outcome.status='stopped'; outcome.result=[]; return; end
            [outcome.report,outcome.simulation]=camdesign.verifyActualClosure(job.project,outcome.result);
            if shouldStop(), outcome.status='stopped'; outcome.result=[]; end
        otherwise, error('cam:BackgroundKind','Unknown background operation.');
    end
catch ex
    outcome.status='error'; outcome.errorIdentifier=ex.identifier; outcome.errorMessage=ex.message;
    if ~isempty(ex.cause), outcome.errorMessage=[outcome.errorMessage,newline,ex.cause{1}.message]; end
end
outcome.elapsedSeconds=toc(timer);
outcome.displayEvaluationAttempts=displayEvaluations;
if ~isempty(ledger), outcome.candidateLedger=ledger.snapshot(); end
    function stop=shouldStop()
        request=poll(control);
        while ~isempty(request)
            if isstruct(request) && strcmp(request.type,'preview-ack'), awaitingPreview=false;
            elseif islogical(request) || isnumeric(request), stopped=stopped || logical(request); end
            request=poll(control);
        end
        stop=stopped;
    end
    function stop=progress(iteration,project,history)
        stop=shouldStop();
        % Check BEFORE copying history/results; at most one preview is in
        % flight, and an acknowledgement is required before another is sent.
        if awaitingPreview || toc(timer)-lastSent<1.5 || stop, return; end
        lastSent=toc(timer);
        if isfield(history,'autoStage') && isfield(history,'comparisonGrid')
            grid=history(end).comparisonGrid; project.params.samples=grid(1); project.params.camSamples=grid(2);
        end
        result=[]; previewError='';
        if isfield(history,'displayResult') && ~isempty(history(end).displayResult)
            result=history(end).displayResult;
        else
            displayEvaluations=displayEvaluations+1;
            try, result=camdesign.evaluate(project,false);
            catch ex, previewError=[ex.identifier,' ',ex.message]; end
        end
        shown=history;
        if isfield(shown,'displayResult'), shown=rmfield(shown,'displayResult'); end
        sequence=sequence+1; awaitingPreview=true;
        send(queue,struct('runId',job.runId,'type','progress','iteration',iteration, ...
            'elapsedSeconds',lastSent,'last',shown(end),'history',shown,'project',project,'result',result, ...
            'sequence',sequence,'algorithm',job.algorithm,'displayEvaluationAttempts',displayEvaluations,'previewError',previewError));
    end
end
