classdef CandidateFutureScope < handle
    % A bound method handle keeps this container alive during stack unwind.
    properties
        Futures={}
    end
    methods
        function close(scope)
            for index=1:numel(scope.Futures)
                future=scope.Futures{index}; if isempty(future), continue; end
                try
                    if ~strcmp(future.State,'finished'), cancel(future); end
                    wait(future);
                catch ex
                    warning('cam:CandidateCleanup','候选退出清理未完成：%s；未知预留未释放。',ex.message);
                end
            end
        end
    end
end
