function points = readXY(filename,columns)
% Plain numeric TXT/CSV/XYZ point reader. Explicit columns avoid guessing.
if nargin<2, columns=[1 2]; end
validateattributes(columns,{'double'},{'vector','numel',2,'integer','positive'});
data=readmatrix(filename);
assert(size(data,2)>=max(columns),'cam:ReferenceColumns','文件列数不足，请明确指定 X/Y 列。');
data=data(~all(isnan(data),2),:); points=data(:,columns);
validateattributes(points,{'double'},{'2d','ncols',2,'real','finite'});
assert(size(points,1)>=2,'cam:ReferenceFile','没有读取到足够的坐标点。');
end
