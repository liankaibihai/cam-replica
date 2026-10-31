classdef PhysicalEvaluationBudget < handle
    % Counts actual evaluate attempts, including invalid geometry/full checks.
    properties (SetAccess=private)
        Limit
        Used=0
        FullChecks=0
        Invalid=0
        MaxSeconds
        Timer
        Reserved=0
        ParallelIntervals=zeros(0,2)
    end
    methods
        function obj=PhysicalEvaluationBudget(limit,maxSeconds)
            if nargin<2, maxSeconds=Inf; end
            assert(isscalar(limit) && limit>=1 && (isinf(limit) || (isfinite(limit) && limit==fix(limit))),'cam:PhysicalBudget','物理评价预算须为正整数或Inf。');
            assert(isscalar(maxSeconds) && maxSeconds>0,'cam:PhysicalBudget','时间上限须为正数。');
            obj.Limit=limit; obj.MaxSeconds=maxSeconds; obj.Timer=tic;
        end
        function check(obj,stopAt)
            if nargin<2, stopAt=Inf; end
            if obj.Used+obj.Reserved>=min(obj.Limit,stopAt), error('cam:PhysicalEvaluationBudget','实际物理评价预算已用尽。'); end
            if toc(obj.Timer)>=obj.MaxSeconds, error('cam:PhysicalTimeBudget','物理评价时间预算已用尽。'); end
        end
        function result=evaluate(obj,project,full,stopAt)
            if nargin<4, stopAt=Inf; end
            obj.check(stopAt); obj.Used=obj.Used+1; obj.FullChecks=obj.FullChecks+double(full);
            try, result=camdesign.evaluate(project,full);
            catch ex, obj.Invalid=obj.Invalid+1; rethrow(ex); end
        end
        function data=snapshot(obj)
            data=struct('limit',obj.Limit,'used',obj.Used,'fullChecks',obj.FullChecks,'invalid',obj.Invalid, ...
                'elapsedSeconds',toc(obj.Timer),'maxSeconds',obj.MaxSeconds, ...
                'reserved',obj.Reserved,'parallelIntervals',obj.ParallelIntervals, ...
                'scope','Actual camdesign.evaluate attempts, including failures and full acceptance checks; cache/objective/constraint calls do not count. Independent final assessment excluded.');
        end
        function records=evaluateBatch(obj,projects,full,stopAt,workers,stopCheck)
            % Reserve before submission, settle actual attempts after drain.
            % A failed future retains its reservation (unknown execution),
            % never refunds it or fabricates a physical-attempt count.
            if nargin<6, stopCheck=[]; end
            pool=cam_candidate_pool(workers);
            assert(~isempty(pool) && pool.NumWorkers>=workers,'cam:CandidatePool','候选池配额不足，未开始探针。');
            available=min(numel(projects),min(obj.Limit,stopAt)-obj.Used-obj.Reserved);
            records=cell(1,available);
            futures={};
            scope=camdesign.CandidateFutureScope; cleanupGuard=onCleanup(@scope.close);
            for first=1:workers:available
                obj.check(stopAt); last=min(available,first+workers-1); futures=cell(1,last-first+1);
                failure=[]; scope.Futures={};
                for k=first:last
                    obj.Reserved=obj.Reserved+1;
                    try, futures{k-first+1}=parfeval(pool,@camdesign.candidateEvaluation,1,projects{k},full); scope.Futures=futures;
                    catch ex, obj.Reserved=obj.Reserved-1; failure=ex; break; end
                end
                for k=first:last
                    if isempty(futures{k-first+1}), continue; end
                    try
                        item=fetchOutputs(futures{k-first+1}); records{k}=item;
                        obj.Reserved=obj.Reserved-1; obj.Used=obj.Used+1; obj.FullChecks=obj.FullChecks+double(full);
                        obj.Invalid=obj.Invalid+double(~isempty(item.identifier));
                        obj.ParallelIntervals(end+1,:)=[item.started item.finished];
                    catch ex, failure=ex; end
                end
                if ~isempty(failure), rethrow(failure); end
                drawnow;
                if ~isempty(stopCheck) && stopCheck(), error('cam:CandidateStopped','用户停止；已结算当前批次。'); end
            end
        end
    end
end
