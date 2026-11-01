function pool=cam_candidate_pool(workers)
assert(ismember(workers,[2 4]),'cam:CandidateWorkers','候选并行支持2或4个worker。');
pool=backgroundPool;
assert(~isempty(pool) && pool.NumWorkers>=workers,'cam:CandidatePoolQuota', ...
    '候选线程资源不足%d个；可明确选择2个或关闭候选并行。未启动串行替代任务。',workers);
end
