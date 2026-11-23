root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
figureDir = fullfile(root,'figures');
files = dir(fullfile(figureDir,'fig*.png'));
ids = zeros(numel(files),1);
for k = 1:numel(files)
    token = regexp(files(k).name,'^fig(\d+)\.png$','tokens','once');
    assert(~isempty(token),'Unexpected figure file name.');
    ids(k) = str2double(token{1});
end
[~,order] = sort(ids);
files = files(order);
n = numel(files);
columns = 4;
rows = ceil(n/columns);
figure('Color','w','Name','Paper Figures');
tiledlayout(rows,columns,'Padding','compact','TileSpacing','compact');
for k = 1:n
    nexttile;
    image(imread(fullfile(figureDir,files(k).name)));
    axis image off;
    title(files(k).name,'Interpreter','none');
end
