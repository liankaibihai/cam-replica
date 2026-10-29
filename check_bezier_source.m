function report=check_bezier_source()
% Original-script comparison plus independent de Casteljau evaluation.
root=fileparts(mfilename('fullpath')); addpath(root);
assert(batchStartupOptionUsed,'cam:BezierBatchOnly','请使用独立 MATLAB -batch 实例运行本检查。');
fixture=fullfile(root,'local','additional_sources_20261029','2','Bezier_Curve.m');
assert(isfile(fixture),'cam:BezierFixture','请先按来源文档准备原文件副本。');
expected='36664c57c112e408d9ce059c5ee153d7c8a561e45df3a8e0e5924904fece1477';
assert(strcmp(sha256(fixture),expected),'cam:BezierFixtureChanged','原脚本哈希不符。');
assert(isempty(findall(groot,'Type','figure')),'cam:BezierExistingFigures', ...
    '请在独立批处理实例运行，原脚本会使用figure(1)。');
visible=get(groot,'defaultFigureVisible'); set(groot,'defaultFigureVisible','off');
restore=onCleanup(@()set(groot,'defaultFigureVisible',visible));
oldRng=rng; restoreRng=onCleanup(@()rng(oldRng)); rng(20261029,'twister');
reference=runSource(fixture);
[actual,t,c]=camdesign.bezierCurve(reference.control,reference.segments);
sourceError=max(abs(actual-reference.points),[],'all');
assert(isequal(actual,reference.points) && isequal(c,reference.coefficients));
checks={'unmodified SHA256-locked source: same controls, coefficients and 1001 points are bit exact'};

% Compare a different algorithm, including 0th degree and 3D inputs.
degrees=[0 1 2 5 12 30]; dimensions=[2 3]; maxIndependentError=0;
for dimension=dimensions
    for degree=degrees
        control=randn(degree+1,dimension)*100;
        [p,q]=camdesign.bezierCurve(control,37);
        independent=zeros(size(p));
        for j=1:numel(q)
            work=control;
            for k=degree:-1:1
                work=(1-q(j))*work(1:k,:)+q(j)*work(2:k+1,:);
            end
            independent(j,:)=work(1,:);
        end
        err=max(abs(p-independent),[],'all'); maxIndependentError=max(maxIndependentError,err);
        assert(err<1e-10);
        assert(isequal(p(1,:),control(1,:)) && isequal(p(end,:),control(end,:)));
        assert(size(p,1)==38 && size(p,2)==dimension);
    end
end
checks{end+1}='independent de Casteljau, degrees 0/1/2/5/12/30 in 2D and 3D, endpoints and sample count';
[line,q]=camdesign.bezierCurve([2 3;6 11],4);
assert(max(abs(line-([2 3]+q.*[4 8])),[],'all')<1e-12);
[quadratic,~,c]=camdesign.bezierCurve([0 0;2 4;4 0],2);
assert(isequal(c,[1;2;1]) && isequal(quadratic,[0 0;2 2;4 0]));
checks{end+1}='hand-computed linear and quadratic curves with midpoint and Pascal coefficients';
control=[-3 7;2 -1;8 4;5 6];
[base,q]=camdesign.bezierCurve(control,23);
angle=.31; rotation=[cos(angle) -sin(angle);sin(angle) cos(angle)];
changed=camdesign.bezierCurve(control*rotation+[13 -7],23);
assert(max(abs(changed-(base*rotation+[13 -7])),[],'all')<1e-12);
reversed=camdesign.bezierCurve(flipud(control),23);
assert(max(abs(reversed-flipud(base)),[],'all')<1e-12);
checks{end+1}='affine rigid transform and control-order reversal';
report=struct('date','2026-10-29','release',version('-release'), ...
    'sourceSHA256',expected,'sourceMaxAbsError',sourceError,'sourceBitExact',isequal(actual,reference.points), ...
    'sourceControlPoints',reference.control,'sourceSegments',reference.segments, ...
    'deCasteljauCases',numel(degrees)*numel(dimensions),'maxIndependentError',maxIndependentError, ...
    'passedGroups',numel(checks),'checks',{checks}, ...
    'scope','Single Bernstein curve only; not overlapping superposition or 3.1.2 equivalence.');
folder=fullfile(root,'outputs','bezier_source'); if ~isfolder(folder),mkdir(folder);end
save(fullfile(folder,'reference.mat'),'reference','actual');
fid=fopen(fullfile(folder,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
for j=1:numel(checks),fprintf('BEZIER_SOURCE_CHECK_PASS %s\n',checks{j});end
fprintf('BEZIER_SOURCE_PASS sourceMaxAbs=%.17g deCasteljauMaxAbs=%.17g\n',sourceError,maxIndependentError);
end

function reference=runSource(path)
run(path); % The original clear only clears this helper's workspace.
reference=struct('control',points_control,'points',points_bezier, ...
    'coefficients',Yang_Hui,'segments',num,'degree',bezier_order);
end
function hash=sha256(path)
fid=fopen(path,'rb'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
md=java.security.MessageDigest.getInstance('SHA-256'); md.update(fread(fid,Inf,'*uint8'));
hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
