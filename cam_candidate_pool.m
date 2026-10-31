function pool=cam_candidate_pool(workers)
assert(ismember(workers,[2 4]),'cam:CandidateWorkers','候选并行支持2或4个worker。');
pool=gcp('nocreate');
if ~isempty(pool)
    assert(~isa(pool,'parallel.ThreadPool') && pool.Cluster.NumThreads>=workers,'cam:CandidatePoolQuota', ...
        '现有池线程配额不足或为Threads池；请在候选并行菜单明确准备所需池。未替换现有池。');
else
    cluster=parcluster('Processes'); cluster.NumThreads=workers; pool=parpool(cluster,1);
end
end
