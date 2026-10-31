function [seed,record]=relayPerturbation(project,index,total,randomSeed,amplitude)
% Private stream: reproducible low-frequency/grouped offsets, no global RNG.
stream=RandStream('mt19937ar','Seed',randomSeed+index-1); n=size(project.nodes,1); t=linspace(0,1,n)';
coefficients=randn(stream,4,2); basis=sin(pi*t*(1:4)); offsets=basis*coefficients;
groups=randn(stream,5,2); offsets=offsets+.5*interp1(linspace(0,1,5)',groups,t,'pchip');
envelope=sin(pi*t).^2; envelope(1:min(2,n))=0; envelope(max(1,n-1):n)=0;
offsets=offsets.*envelope; offsets=offsets/max(1e-12,max(vecnorm(offsets,2,2)));
requested=amplitude*(index-1)/max(1,total-1)*2; if index==1, requested=0; end
seed=project; factor=1; low=project.params.bounds([1 3]); high=project.params.bounds([2 4]);
for attempt=0:16
    seed.nodes=project.nodes+requested*factor*offsets; seed.nodes(1,:)=project.nodes(1,:);
    if all(seed.nodes>=low & seed.nodes<=high,'all'), break; end
    factor=factor/2;
end
record=struct('index',index,'seed',randomSeed+index-1,'requestedAmplitudeMM',requested, ...
    'actualMaximumOffsetMM',max(vecnorm(seed.nodes-project.nodes,2,2)),'boundBacktrackFactor',factor, ...
    'coefficients',coefficients,'groups',groups,'offsetsMM',seed.nodes-project.nodes, ...
    'semantics','Four sine modes plus five smoothly interpolated groups, tapered at both ends; first/last two controls fixed in seed only. Bounds use logged amplitude backtracking, no parameter changes.');
end
