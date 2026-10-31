classdef PhysicalEvaluationBudget < handle
    % Counts actual evaluate attempts, including invalid geometry/full checks.
    properties (SetAccess=private)
        Limit
        Used=0
        FullChecks=0
        Invalid=0
        MaxSeconds
        Timer
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
            if obj.Used>=min(obj.Limit,stopAt), error('cam:PhysicalEvaluationBudget','实际物理评价预算已用尽。'); end
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
                'scope','Actual camdesign.evaluate attempts, including failures and full acceptance checks; cache/objective/constraint calls do not count. Independent final assessment excluded.');
        end
    end
end
