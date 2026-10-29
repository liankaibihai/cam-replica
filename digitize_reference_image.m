function report = digitize_reference_image(imagePath,calibration,outputDirectory)
%DIGITIZE_REFERENCE_IMAGE Measure visible trace pixels using axis ticks.
% Pixel coordinates are zero-based, with Y increasing downwards.
% Returns an UNORDERED point cloud, not raw exported points or a polyline.
% The screenshot is only read; the preview is a new scientific scatter plot.
arguments
    imagePath (1,1) string
    calibration struct
    outputDirectory (1,1) string
end
required={'xTicks','yTicks','region','color','pixelUncertainty'};
assert(all(isfield(calibration,required)),'cam:Calibration','Missing calibration fields.');
X=calibration.xTicks; Y=calibration.yTicks;
assert(isequal(size(X),[2 2]) && isequal(size(Y),[2 2]) && ...
    all(isfinite([X(:);Y(:)])),'cam:Calibration','Ticks must be two [pixel, coordinate] rows.');
assert(diff(X(:,1))~=0 && diff(Y(:,1))~=0 && diff(X(:,2))~=0 && diff(Y(:,2))~=0, ...
    'cam:Calibration','Tick positions and values must differ.');
rgb=imread(imagePath);
assert(ndims(rgb)==3 && size(rgb,3)==3 && isa(rgb,'uint8'), ...
    'cam:ReferenceImage','Use an unmodified RGB 8-bit screenshot.');
[height,width,~]=size(rgb);
if isfield(calibration,'imageSize')
    assert(isequal(calibration.imageSize,[width height]),'cam:ImageSize','Image size differs from calibration.');
end
roi=calibration.region;
validateRect(roi,width,height);
mask=false(height,width);
mask(roi(2)+1:roi(4)+1,roi(1)+1:roi(3)+1)=true;
if isfield(calibration,'excludeRects')
    for k=1:size(calibration.excludeRects,1)
        rect=calibration.excludeRects(k,:); validateRect(rect,width,height);
        mask(rect(2)+1:rect(4)+1,rect(1)+1:rect(3)+1)=false;
    end
end
R=double(rgb(:,:,1)); G=double(rgb(:,:,2)); B=double(rgb(:,:,3));
switch lower(string(calibration.color))
    case "red", trace=R>=160 & G<=120 & B<=120;
    case "blue", trace=B>=160 & R<=120 & G<=120;
    case "green", trace=G>=140 & R<=120 & B<=120;
    otherwise, error('cam:TraceColor','Supported colors: red, blue, green.');
end
[v,u]=find(mask & trace); u=u-1; v=v-1;
assert(numel(u)>=2,'cam:EmptyTrace','No usable colored trace; inspect calibration and image.');
sx=diff(X(:,2))/diff(X(:,1)); sy=diff(Y(:,2))/diff(Y(:,1));
points=[X(1,2)+(u-X(1,1))*sx,Y(1,2)+(v-Y(1,1))*sy];
assert(isscalar(calibration.pixelUncertainty) && isfinite(calibration.pixelUncertainty) && ...
    calibration.pixelUncertainty>0,'cam:PixelUncertainty','Specify a positive pixel allowance.');
report=struct('imagePath',imagePath,'imageSize',[width height], ...
    'calibration',calibration,'pixelCount',numel(u),'mmPerPixel',[abs(sx) abs(sy)], ...
    'assumedCoordinateAllowanceMM',calibration.pixelUncertainty*[abs(sx) abs(sy)], ...
    'boundsMM',[min(points);max(points)], ...
    'ordering','unordered visible color pixels; do not connect rows as a polyline', ...
    'interpretation','Display-space measurement only. Includes trace thickness and same-color markers. Occlusions, antialiasing and wrong calibration can increase error. Pixel allowance is an assumption, not a statistical confidence bound. No original/replica agreement has been tested.');
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
writematrix(points,fullfile(outputDirectory,'visible_points_unordered.csv'));
writematrix([u v],fullfile(outputDirectory,'source_pixels_unordered.csv'));
fid=fopen(fullfile(outputDirectory,'measurement.json'),'w','n','UTF-8');
assert(fid>=0); cleanupFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true));
fig=figure('Visible','off','Color','w','Position',[100 100 1100 450]);
cleanupFigure=onCleanup(@()close(fig));
scatter(points(:,1),points(:,2),4,'.','MarkerEdgeColor',[0.85 0.1 0.1]);
axis equal; grid on; xlabel('X / mm'); ylabel('Y / mm');
title('Visible trace digitization — unordered pixels, not original exported data');
exportgraphics(fig,fullfile(outputDirectory,'digitized_preview.png'),'Resolution',150);
fprintf('DIGITIZED %d pixels; scale X=%.4f, Y=%.4f mm/pixel\n',numel(u),abs(sx),abs(sy));
end

function validateRect(rect,width,height)
assert(isequal(size(rect),[1 4]) && all(isfinite(rect)) && all(rect==round(rect)) && ...
    rect(1)>=0 && rect(2)>=0 && rect(3)<width && rect(4)<height && ...
    rect(1)<=rect(3) && rect(2)<=rect(4), 'cam:PixelRect','Invalid [left top right bottom] pixel rectangle.');
end
