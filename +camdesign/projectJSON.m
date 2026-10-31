function project=projectJSON(action,file,project)
% Complete input fixture with numeric shape metadata and exact round-trip QA.
if strcmp(action,'write')
    camdesign.validateProject(project); shapes=collect(project,{});
    payload=struct('schema','cam-project-json-shapes-1','project',project,'numericShapes',shapes);
    fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'cam:ProjectJSON','无法写入项目JSON。');
    closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(payload,PrettyPrint=true)); clear closer;
    restored=camdesign.projectJSON('read',file);
    assert(isequaln(project,restored),'cam:ProjectJSONRoundTrip','JSON回读未逐值保留完整项目。');
elseif strcmp(action,'read')
    payload=jsondecode(fileread(file)); assert(strcmp(payload.schema,'cam-project-json-shapes-1'),'cam:ProjectJSON','未知项目JSON版本。');
    project=payload.project;
    for k=1:numel(payload.numericShapes)
        shape=payload.numericShapes(k); path=cellstr(string(shape.path)); value=getfield(project,path{:});
        value=reshape(cast(value,shape.class),shape.size(:)'); project=setfield(project,path{:},value);
    end
    camdesign.validateProject(project);
else, error('cam:ProjectJSON','Action须为write或read。'); end
end
function shapes=collect(value,path)
shapes=struct('path',{},'class',{},'size',{});
if isnumeric(value) || islogical(value)
    shapes=struct('path',{path},'class',class(value),'size',size(value));
elseif isstruct(value) && isscalar(value)
    for name=fieldnames(value)'
        item=collect(value.(name{1}),[path name]); shapes=[shapes item]; %#ok<AGROW>
    end
end
end
