function result = q2_localization(firstPoint, firstBearing, outputRoot)
settings = struct('delta',1,'sourceRadius',1800,'receiveMin',1000, ...
    'receiveMax',1500,'nearRadius',5,'speed',5,'circleSides',720, ...
    'scoreTolerance',0.15,'maxSplits',700,'initialBins',36, ...
    'budgets',[100 200 400 600 800 1000 1500 2000],'version','1.3.0', ...
    'useCache',true,'searchSteps',[25 8 2 0.5 0.1]);
if nargin >= 1 && (ischar(firstPoint) || isstring(firstPoint))
    if ~isscalar(string(firstPoint)) || ~any(string(firstPoint) == ["verify12" "verify34" "report34" "verify101112" "report101112" "verify6809" "report6809" "verify1315" "report1315" "verifycoverage"])
        error('未知运行模式。');
    end
    if nargin < 3
        outputRoot = fullfile(fileparts(mfilename('fullpath')),'研究验证', ...
            char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
    end
    if string(firstPoint) == "verifycoverage"
        assert(nargin>=2 && isstruct(firstBearing),'须提供固定结果文件列表。');
        result = verifyCoverage151(settings,firstBearing,outputRoot);
    elseif string(firstPoint) == "verify1315"
        options = struct;
        if nargin>=2 && isstruct(firstBearing)
            options = firstBearing;
        end
        result = verifyResearch150(settings,options,outputRoot);
    elseif string(firstPoint) == "report1315"
        assert(nargin>=2 && isfile(firstBearing),'须提供已完成研究MAT文件。');
        result = report150(firstBearing,outputRoot);
    elseif string(firstPoint) == "report6809"
        assert(nargin>=2 && isfile(firstBearing),'须提供已完成研究MAT文件。');
        result = report140(firstBearing,outputRoot);
    elseif string(firstPoint) == "verify6809"
        options = struct;
        if nargin>=2 && isstruct(firstBearing)
            options = firstBearing;
        end
        result = verifyResearch140(settings,options,outputRoot);
    elseif string(firstPoint) == "report101112"
        assert(nargin>=2 && isfile(firstBearing),'须提供已完成研究MAT文件。');
        assert(~isfolder(outputRoot),'输出目录已存在。');
        loaded = load(firstBearing,'result'); result = loaded.result;
        assert(strcmp(result.version,settings.version) && all(result.checks.Passed),'研究数据未通过或版本不符。');
        mkdir(outputRoot); figures130(result,outputRoot);
    elseif string(firstPoint) == "verify101112"
        options = struct;
        if nargin>=2 && isstruct(firstBearing)
            options = firstBearing;
        end
        result = verifyResearch130(settings,options,outputRoot);
    elseif string(firstPoint) == "verify12"
        result = verifyResearch12(settings,outputRoot);
    elseif string(firstPoint) == "verify34"
        result = verifyResearch34(settings,outputRoot);
    else
        assert(nargin>=2 && isfile(firstBearing),'须提供已完成研究MAT文件。');
        assert(~isfolder(outputRoot),'输出目录已存在。');
        loaded = load(firstBearing,'result');
        assert(any(string(loaded.result.version)==["1.2.0" string(settings.version)]) && all(loaded.result.checks.Passed), ...
            '仅可导出已通过的本版研究数据。');
        mkdir(outputRoot);
        result = exportResearch34(loaded.result,outputRoot,settings);
    end
    return
end
if nargin == 0
    firstPoints = [0 0;1750 0;1780 0;1750 0;2600 0;1760 0];
    firstBearings = [0;0;90;180;180;0];
    names = ["中心首测";"边缘朝外";"边缘切向";"边缘朝内";"圆域外首测";"首测已足够"];
elseif nargin >= 2
    validateattributes(firstPoint,{'numeric'},{'real','finite','size',[1 2]});
    validateattributes(firstBearing,{'numeric'},{'real','finite','scalar'});
    firstPoints = firstPoint;
    firstBearings = mod(firstBearing,360);
    names = "输入场景";
else
    error('必须同时提供首点坐标和示向度。');
end
if nargin < 3
    outputRoot = fullfile(fileparts(mfilename('fullpath')),'运行结果', ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
if isfolder(outputRoot)
    error('输出目录已经存在，请使用新的目录以保留既有结果。');
end
mkdir(outputRoot);
started = tic;
fprintf('第二问：精度优先，预算分析补充。全部默认场景均为自建。\n');
fprintf('MATLAB %s；程序版本 %s\n',version,settings.version);
phaseStarted = tic;
checks = basicChecks(settings);
checkSeconds = toc(phaseStarted);
exportSeconds = 0;
caseResults = cell(numel(firstBearings),1);
for caseIndex = 1:numel(firstBearings)
    fprintf('开始场景 %d/%d：%s\n',caseIndex,numel(firstBearings),names(caseIndex));
    caseResults{caseIndex} = solveCase(firstPoints(caseIndex,:), ...
        firstBearings(caseIndex),names(caseIndex),settings);
    item = caseResults{caseIndex};
    fprintf('推荐局部点 (%.3f, %.3f) 米；最坏半径区间 [%.5f, %.5f] 米\n', ...
        item.point(1),item.point(2),item.final.lower,item.final.upper);
    phaseStarted = tic;
    checks = [checks; verifyCase(item,settings)];
    checkSeconds = checkSeconds+toc(phaseStarted);
    phaseStarted = tic;
    exportCase(item,caseIndex,outputRoot);
    exportSeconds = exportSeconds+toc(phaseStarted);
end
summary = summarizeCases(caseResults);
writetable(summary,fullfile(outputRoot,'场景结果总表.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputRoot,'必要验证.csv'),'Encoding','UTF-8');
performance = performanceTable34(caseResults);
writetable(performance,fullfile(outputRoot,'评分与求解计时.csv'),'Encoding','UTF-8');
result = struct('settings',settings,'cases',{caseResults},'summary',summary, ...
    'checks',checks,'matlabVersion',version,'elapsedSeconds',toc(started));
phaseStarted = tic;
makeFigures(caseResults,settings,outputRoot);
figureSeconds = toc(phaseStarted);
result.performance = performance;
result.phaseSeconds = struct('verification',checkSeconds,'caseExport',exportSeconds,'figures',figureSeconds);
result.elapsedSeconds = toc(started);
save(fullfile(outputRoot,'完整结果.mat'),'result');
assert(all(checks.Passed),'必要验证存在失败，请查看必要验证.csv。');
fprintf('必要验证 %d 项，失败 %d 项；总耗时 %.2f 秒。\n', ...
    height(checks),sum(~checks.Passed),result.elapsedSeconds);
fprintf('输出：%s\n',outputRoot);
end

function item = solveCase(firstPoint,bearing,name,settings)
solveStarted = tic;
settings.scoreContext = newScoreContext34(settings.useCache);
geometryStarted = tic;
rotation = [cosd(bearing) -sind(bearing);sind(bearing) cosd(bearing)];
sourceCenter = -firstPoint*rotation;
witness = initialWitness(sourceCenter,settings);
[outer,inner] = initialRegion(sourceCenter,settings);
precise = settings;
precise.circleSides = 5760;
precise.scoreTolerance = 0.002;
precise.maxSplits = 2200;
[fineOuter,fineInner] = initialRegion(sourceCenter,precise);
[initialCenter,initialUpper] = enclosingCircle(fineOuter);
initialSupport = feasibleSupport(fineInner,[0 0],settings.nearRadius);
[~,~,initialLower] = enclosingCircle(initialSupport);
domain = receiveDomain(fineOuter,settings);
geometrySeconds = toc(geometryStarted);
points = candidatePoints(settings,domain);
scores = scoreRows(points,outer,inner,settings);
coarseCount = size(points,1);
coarseBest = min(scores(:,2));
polish = precise;
polish.circleSides = 2880;
polish.scoreTolerance = 0.006;
polish.maxSplits = 1600;
geometryStarted = tic;
[polishOuter,polishInner] = initialRegion(sourceCenter,polish);
geometrySeconds = geometrySeconds+toc(geometryStarted);
levels = [coarseCount coarseBest];
profiles = [settings.budgets inf inf];
for profile = 1:numel(profiles)
    budgetLimit = profiles(profile);
    originalOnly = profile == numel(profiles);
    mask = vecnorm(points,2,2)<=budgetLimit+1e-7;
    if originalOnly
        mask = mask & safePoints(points,settings);
    end
    pool = find(mask);
    [~,order] = sort(scores(pool,2));
    ranked = pool(order);
    seeds = points(ranked(1),:);
    for j = 2:numel(ranked)
        if all(vecnorm(seeds-points(ranked(j),:),2,2)>max(5,initialUpper/25))
            seeds(end+1,:) = points(ranked(j),:);
        end
        if size(seeds,1) == 3
            break
        end
    end
    for j = 1:size(seeds,1)
        [newPoints,newScores] = polishPoint(seeds(j,:),budgetLimit,originalOnly, ...
            domain,polishOuter,polishInner,polish);
        points = [points;newPoints];
        scores = [scores;newScores];
    end
end
levels(end+1,:) = [size(points,1),min(scores(:,2))];
threshold = -inf(size(points,1),1);
for budgetLimit = [settings.budgets inf]
    pool = vecnorm(points,2,2)<=budgetLimit+1e-7;
    threshold(pool) = max(threshold(pool),min(scores(pool,2)));
end
oldMask = safePoints(points,settings);
threshold(oldMask) = max(threshold(oldMask),min(scores(oldMask,2)));
contenders = find(scores(:,1)<=threshold+0.015);
for k = 1:numel(contenders)
    j = contenders(k);
    scores(j,:) = scoreRows(points(j,:),fineOuter,fineInner,precise);
end
selected = bestIndex(points,scores(:,2));
point = points(selected,:);
final = scorePoint(point,fineOuter,fineInner,precise);
if final.feedback == "near"
    posterior = clipDisk(fineOuter,point,settings.nearRadius,5760,true);
else
    posterior = clipWedge(fineOuter,point,final.angle,settings.delta);
    direction = [cosd(final.angle) sind(final.angle)];
    posterior = clipPlane(posterior,-direction,-dot(direction,point)-5*cosd(settings.delta));
end
[center,radius] = enclosingCircle(posterior);
oldPool = find(oldMask);
oldIndex = oldPool(bestIndex(points(oldPool,:),scores(oldPool,2)));
oldPoint = points(oldIndex,:);
oldScore = scorePoint(oldPoint,fineOuter,fineInner,precise);
baselinePoints = [0 0;500 450;500 -450;500 0;oldPoint];
baselineScores = zeros(5,3);
baselineScores(1,:) = [initialLower initialUpper 0];
for k = 2:5
    baseline = scorePoint(baselinePoints(k,:),fineOuter,fineInner,precise);
    baselineScores(k,:) = [baseline.lower baseline.upper norm(baselinePoints(k,:))/settings.speed+5];
end
budget = zeros(numel(settings.budgets),6);
for k = 1:numel(settings.budgets)
    indices = find(vecnorm(points,2,2)<=settings.budgets(k)+1e-7);
    j = indices(bestIndex(points(indices,:),scores(indices,2)));
    budget(k,:) = [settings.budgets(k),points(j,:),scores(j,1:2),norm(points(j,:))/settings.speed+5];
end
domainAngles = (-180:0.25:180)';
domainRadii = domainLimit(domainAngles,domain,settings);
domainBoundary = domainRadii.*[cosd(domainAngles) sind(domainAngles)];
levels(end+1,:) = [size(points,1),min(scores(:,2))];
item = struct('name',name,'firstPoint',firstPoint,'bearing',bearing, ...
    'rotation',rotation,'sourceCenter',sourceCenter,'initial',fineOuter, ...
    'initialInner',fineInner,'initialRadius',initialUpper,'initialCenter',initialCenter, ...
    'initialLower',initialLower,'witness',witness,'domain',domain,'domainBoundary',domainBoundary, ...
    'points',points,'scores',scores,'point',point,'globalPoint',point*rotation'+firstPoint, ...
    'final',final,'posterior',posterior,'posteriorCenter',center, ...
    'posteriorRadius',radius,'baselinePoints',baselinePoints, ...
    'baselineScores',baselineScores,'budget',budget,'searchLevels',levels, ...
    'oldPoint',oldPoint,'oldScore',oldScore,'initialSufficient',initialUpper<=20, ...
    'secondSufficient',final.upper<=20,'finiteGridLower',min(scores(:,1)), ...
    'contenderCount',numel(contenders));
item.performance = scoreSnapshot34(settings.scoreContext);
item.performance.solveSeconds = toc(solveStarted);
item.performance.geometrySeconds = geometrySeconds;
end

function rows = scoreRows(points,outer,inner,settings)
rows = zeros(size(points,1),5);
for k = 1:size(points,1)
    score = scorePoint(points(k,:),outer,inner,settings);
    rows(k,:) = [score.lower score.upper score.angle score.splits score.gap];
end
end

function points = candidatePoints(settings,domain)
points = zeros(0,2);
for angle = unique([-180:5:175 -59 59])
    limit = domainLimit(angle,domain,settings);
    if limit<1e-6
        continue
    end
    radii = unique([5 10 25 50 settings.budgets limit*[0.1 0.25 0.5 0.75 1]]);
    radii = radii(radii<=limit+1e-8);
    points = [points;radii(:)*[cosd(angle) sind(angle)]];
end
for angle = unique([-85:5:85 -59 59])
    limit = min(settings.receiveMin,2*settings.receiveMin*cosd(abs(angle)+settings.delta));
    radii = unique([25 50 settings.budgets limit]);
    radii = radii(radii<=limit+1e-8);
    points = [points;radii(:)*[cosd(angle) sind(angle)]];
end
points = unique([points;500 450;500 -450;500 0],'rows');
end

function [points,scores] = polishPoint(seed,budget,originalOnly,domain,outer,inner,settings)
points = seed;
scores = scoreRows(seed,outer,inner,settings);
current = seed;
currentScore = scores(1,2);
directions = [cosd((0:45:315)') sind((0:45:315)')];
for step = settings.searchSteps
    for iteration = 1:12
        trial = current+step*directions;
        angles = atan2d(trial(:,2),trial(:,1));
        lengths = vecnorm(trial,2,2);
        if originalOnly
            limits = max(0,min(settings.receiveMin,2*settings.receiveMin*cosd(abs(angles)+settings.delta)));
            limits(abs(angles)>=90-settings.delta) = 0;
        else
            limits = domainLimit(angles,domain,settings);
        end
        limits = min(limits,budget);
        trial = trial.*min(1,limits./max(lengths,1e-12));
        trial = trial(vecnorm(trial,2,2)>1e-6,:);
        trial = unique(trial,'rows');
        trialScores = scoreRows(trial,outer,inner,settings);
        points = [points;trial];
        scores = [scores;trialScores];
        if isempty(trial)
            break
        end
        j = bestIndex(trial,trialScores(:,2));
        if trialScores(j,2)>=currentScore-1e-7
            break
        end
        current = trial(j,:);
        currentScore = trialScores(j,2);
    end
end
end

function domain = receiveDomain(polygon,settings)
support = polygon;
radius = settings.receiveMin;
for k = 1:size(polygon,1)
    first = polygon(k,:);
    edge = polygon(mod(k,size(polygon,1))+1,:)-first;
    a = dot(edge,edge);
    b = 2*dot(first,edge);
    c = dot(first,first)-radius^2;
    discriminant = b*b-4*a*c;
    if a>1e-18 && discriminant>=0
        fractions = (-b+[-1 1]*sqrt(discriminant))/(2*a);
        for fraction = fractions
            if fraction>=0 && fraction<=1
                support(end+1,:) = first+fraction*edge;
            end
        end
    end
end
domain = struct('polygon',polygon,'support',support, ...
    'allowance',max(0,radius^2-sum(support.^2,2)));
end

function limits = domainLimit(angles,domain,settings)
directions = [cosd(angles(:)) sind(angles(:))];
projection = directions*domain.support';
roots = projection+sqrt(max(0,projection.^2+domain.allowance'));
limits = min(roots,[],2);
for k = 1:numel(limits)
    if polygonContains(domain.polygon,-settings.receiveMin*directions(k,:))
        limits(k) = 0;
    end
end
limits = max(0,limits);
end

function violation = domainViolation(point,domain,settings)
support = domain.support;
if norm(point)>0
    stationary = -settings.receiveMin*point/norm(point);
    if polygonContains(domain.polygon,stationary)
        support(end+1,:) = stationary;
    end
end
violation = max(sum((support-point).^2,2)-max(settings.receiveMin^2,sum(support.^2,2)));
end

function inside = polygonContains(polygon,point)
if isempty(polygon)
    inside = false;
    return
elseif size(polygon,1)==1
    inside = norm(point-polygon(1,:))<1e-8;
    return
elseif rank(polygon-polygon(1,:))<2
    [~,last] = max(vecnorm(polygon-polygon(1,:),2,2));
    edge = polygon(last,:)-polygon(1,:);
    offset = point-polygon(1,:);
    fraction = dot(offset,edge)/max(dot(edge,edge),1e-20);
    projections = (polygon-polygon(1,:))*edge'/max(dot(edge,edge),1e-20);
    inside = fraction>=min(projections)-1e-10 && fraction<=max(projections)+1e-10 ...
        && norm(offset-fraction*edge)<1e-8;
    return
end
edges = polygon([2:end 1],:)-polygon;
offset = point-polygon;
inside = all(edges(:,1).*offset(:,2)-edges(:,2).*offset(:,1)>=-1e-7);
end

function witness = initialWitness(sourceCenter,settings)
angle = atan2d(sourceCenter(2),sourceCenter(1));
angles = unique([-settings.delta 0 settings.delta max(-settings.delta,min(settings.delta,angle))]);
witness = zeros(0,2);
for angle = angles
    direction = [cosd(angle) sind(angle)];
    projection = dot(sourceCenter,direction);
    discriminant = settings.sourceRadius^2-sum(sourceCenter.^2)+projection^2;
    if discriminant<0
        continue
    end
    lower = max(settings.nearRadius,projection-sqrt(discriminant));
    upper = min(settings.receiveMax,projection+sqrt(discriminant));
    if upper>=lower && upper>settings.nearRadius
        distance = (lower+upper)/2;
        if distance>settings.nearRadius
            witness(end+1,:) = distance*direction;
        end
    end
end
if isempty(witness)
    error('首测不相容：源圆域、距离及方向约束不存在可行位置。');
end
end

function mask = safePoints(points,settings)
centers = [0 0;settings.receiveMin*cosd(settings.delta) settings.receiveMin*sind(settings.delta); ...
    settings.receiveMin*cosd(settings.delta) -settings.receiveMin*sind(settings.delta)];
mask = true(size(points,1),1);
for k = 1:3
    mask = mask & vecnorm(points-centers(k,:),2,2)<=settings.receiveMin+1e-8;
end
end

function index = bestIndex(points,upper)
[~,order] = sortrows([upper vecnorm(points,2,2) points],[1 2 3 4]);
index = order(1);
end

function [outer,inner] = initialRegion(sourceCenter,settings)
outer = circlePolygon([0 0],settings.receiveMax,settings.circleSides,true);
outer = clipWedge(outer,[0 0],0,settings.delta);
outer = clipPlane(outer,[-1 0],-settings.nearRadius*cosd(settings.delta));
outer = clipDisk(outer,sourceCenter,settings.sourceRadius,settings.circleSides,true);
inner = circlePolygon([0 0],settings.receiveMax,settings.circleSides,false);
inner = clipWedge(inner,[0 0],0,settings.delta);
inner = clipPlane(inner,[-1 0],-settings.nearRadius*cosd(settings.delta));
inner = clipDisk(inner,sourceCenter,settings.sourceRadius,settings.circleSides,false);
witness = initialWitness(sourceCenter,settings);
inner = unique([inner;witness],'rows');
if size(inner,1)>=3 && rank(inner-inner(1,:))==2
    order = convhull(inner(:,1),inner(:,2));
    inner = inner(order(1:end-1),:);
end
end

function score = scorePoint(point,outer,inner,settings)
if ~isfield(settings,'scoreContext')
    score = computeScorePoint(point,outer,inner,settings);
    return
end
context = settings.scoreContext;
context.stats('requests') = context.stats('requests')+1;
key = scoreKey34(point,outer,inner,settings);
if ~isKey(context.seen,key)
    context.seen(key) = true;
    context.stats('uniqueKeys') = context.stats('uniqueKeys')+1;
end
if context.enabled && isKey(context.values,key)
    context.stats('hits') = context.stats('hits')+1;
    score = context.values(key);
    return
end
started = tic;
score = computeScorePoint(point,outer,inner,settings);
context.stats('kernelSeconds') = context.stats('kernelSeconds')+toc(started);
context.stats('kernelCalls') = context.stats('kernelCalls')+1;
if context.enabled
    context.values(key) = score;
end
end

function score = computeScorePoint(point,outer,inner,settings)
outer = clipDisk(outer,point,settings.receiveMax,settings.circleSides,true);
inner = clipDisk(inner,point,settings.receiveMax,settings.circleSides,false);
nearSides = max(64,settings.circleSides/8);
nearOuter = clipDisk(outer,point,settings.nearRadius,nearSides,true);
nearInner = clipDisk(inner,point,settings.nearRadius,nearSides,false);
[~,nearUpper] = enclosingCircle(nearOuter);
nearUpper = min(settings.nearRadius,nearUpper);
nearInner = feasibleSupport(nearInner,[0 0],settings.nearRadius);
[~,~,nearLower] = enclosingCircle(nearInner);
centers = (0:settings.initialBins-1)'*(360/settings.initialBins);
widths = repmat(180/settings.initialBins,settings.initialBins,1);
upper = zeros(size(centers));
lower = nearLower;
bestAngle = NaN;
bestFeedback = "near";
for k = 1:numel(centers)
    [lo,hi] = intervalScore(point,outer,inner,centers(k),widths(k),settings);
    upper(k) = hi;
    if lo > lower
        lower = lo;
        bestAngle = centers(k);
        bestFeedback = "direction";
    end
end
splits = 0;
while max([upper;nearUpper])-lower > settings.scoreTolerance && splits < settings.maxSplits
    [~,index] = max(upper);
    halfWidth = widths(index)/2;
    middle = centers(index);
    childCenters = middle+[-halfWidth;halfWidth];
    for j = 1:2
        [lo,hi] = intervalScore(point,outer,inner,childCenters(j),halfWidth,settings);
        if lo > lower
            lower = lo;
            bestAngle = childCenters(j);
            bestFeedback = "direction";
        end
        if j == 1
            centers(index) = childCenters(j);
            widths(index) = halfWidth;
            upper(index) = hi;
        else
            centers(end+1,1) = childCenters(j);
            widths(end+1,1) = halfWidth;
            upper(end+1,1) = hi;
        end
    end
    splits = splits+1;
end
upperBound = max([upper;nearUpper])+1e-6;
lowerBound = max(0,lower-1e-6);
score = struct('lower',lowerBound,'upper',upperBound,'gap',upperBound-lowerBound, ...
    'angle',mod(bestAngle,360),'splits',splits,'nearUpper',nearUpper, ...
    'maxHalfWidth',max(widths),'feedback',bestFeedback);
end

function [lower,upper] = intervalScore(point,outer,inner,center,halfWidth,settings)
envelope = clipWedge(outer,point,center,settings.delta+halfWidth);
direction = [cosd(center) sind(center)];
envelope = clipPlane(envelope,-direction,-dot(direction,point)- ...
    settings.nearRadius*cosd(settings.delta+halfWidth));
[~,upper] = enclosingCircle(envelope);
section = clipWedge(inner,point,center,settings.delta);
if ~isempty(section)
    section = feasibleSupport(section,[0 0;point],settings.nearRadius);
end
[~,~,lower] = enclosingCircle(section);
end

function support = feasibleSupport(polygon,centers,radius)
support = polygon;
if isempty(polygon)
    return
end
count = size(polygon,1);
for centerIndex = 1:size(centers,1)
    center = centers(centerIndex,:);
    if all(vecnorm(polygon-center,2,2)>radius+1e-8)
        continue
    end
    for k = 1:count
        next = mod(k,count)+1;
        edge = polygon(next,:)-polygon(k,:);
        offset = polygon(k,:)-center;
        a = dot(edge,edge);
        b = 2*dot(offset,edge);
        c = dot(offset,offset)-(radius+1e-6)^2;
        discriminant = b*b-4*a*c;
        if a<=1e-20 || discriminant<0
            continue
        end
        fractions = (-b+[-1 1]*sqrt(discriminant))/(2*a);
        for fraction = fractions
            if fraction>=0 && fraction<=1
                support(end+1,:) = polygon(k,:)+fraction*edge;
            end
        end
    end
end
valid = true(size(support,1),1);
for k = 1:size(centers,1)
    valid = valid & vecnorm(support-centers(k,:),2,2)>radius+1e-8;
end
support = support(valid,:);
end

function polygon = circlePolygon(center,radius,count,outer)
angles = (0:count-1)'*(360/count);
if outer
    angles = angles+180/count;
    radius = radius/cosd(180/count);
end
polygon = center+radius*[cosd(angles) sind(angles)];
end

function polygon = clipDisk(polygon,center,radius,count,outer)
if isempty(polygon)
    return
end
if all(vecnorm(polygon-center,2,2)<=radius*(1-1e-12)) && outer
    return
end
angles = (0:count-1)'*(360/count);
bound = radius;
if ~outer
    angles = angles+180/count;
    bound = radius*cosd(180/count);
    if all(vecnorm(polygon-center,2,2)<=bound*(1-1e-12))
        return
    end
end
normals = [cosd(angles) sind(angles)];
for k = 1:count
    polygon = clipPlane(polygon,normals(k,:),bound+dot(normals(k,:),center));
    if isempty(polygon)
        return
    end
end
end

function polygon = clipWedge(polygon,point,angle,delta)
left = [cosd(angle-delta) sind(angle-delta)];
right = [cosd(angle+delta) sind(angle+delta)];
normal = [left(2) -left(1)];
polygon = clipPlane(polygon,normal,dot(normal,point));
normal = [-right(2) right(1)];
polygon = clipPlane(polygon,normal,dot(normal,point));
end

function output = clipPlane(polygon,normal,bound)
if isempty(polygon)
    output = zeros(0,2);
    return
end
values = polygon*normal'-bound;
inside = values<=1e-10;
if all(inside)
    output = polygon;
    return
elseif ~any(inside)
    output = zeros(0,2);
    return
end
count = size(polygon,1);
output = zeros(count+2,2);
next = 0;
for k = 1:count
    previous = mod(k-2,count)+1;
    if inside(k) ~= inside(previous)
        fraction = values(previous)/(values(previous)-values(k));
        next = next+1;
        output(next,:) = polygon(previous,:)+fraction*(polygon(k,:)-polygon(previous,:));
    end
    if inside(k)
        next = next+1;
        output(next,:) = polygon(k,:);
    end
end
output = output(1:next,:);
if size(output,1)>1
    keep = [true;vecnorm(diff(output),2,2)>1e-9];
    output = output(keep,:);
end
end

function [center,radius,certificate] = enclosingCircle(points)
if isempty(points)
    center = [NaN NaN];
    radius = 0;
    certificate = 0;
    return
end
count = size(points,1);
if count == 1
    center = points(1,:);
    radius = 0;
    certificate = 0;
    return
end
distances = (points(:,1)-points(:,1)').^2+(points(:,2)-points(:,2)').^2;
[diameterSquared,flat] = max(distances(:));
[first,last] = ind2sub([count count],flat);
center = (points(first,:)+points(last,:))/2;
radius = sqrt(diameterSquared)/2;
certificate = radius;
if all(vecnorm(points-center,2,2)<=radius+1e-8)
    radius = max(vecnorm(points-center,2,2));
    return
end
bestRadius = inf;
for i = 1:count-2
    for j = i+1:count-1
        for k = j+1:count
            firstEdge = points(j,:)-points(i,:);
            secondEdge = points(k,:)-points(i,:);
            determinant = firstEdge(1)*secondEdge(2)-firstEdge(2)*secondEdge(1);
            if abs(determinant)<=1e-12*max(1,norm(firstEdge)*norm(secondEdge))
                continue
            end
            firstLength = dot(firstEdge,firstEdge);
            secondLength = dot(secondEdge,secondEdge);
            offset = [secondEdge(2)*firstLength-firstEdge(2)*secondLength, ...
                firstEdge(1)*secondLength-secondEdge(1)*firstLength]/(2*determinant);
            candidate = points(i,:)+offset;
            trialRadius = norm(offset);
            if trialRadius < bestRadius && all(vecnorm(points-candidate,2,2)<=trialRadius+1e-8)
                bestRadius = trialRadius;
                center = candidate;
                sides = sort([firstLength secondLength sum((points(j,:)-points(k,:)).^2)]);
                if sides(3)>=sides(1)+sides(2)-1e-9
                    certificate = sqrt(sides(3))/2;
                else
                    certificate = trialRadius;
                end
            end
        end
    end
end
assert(isfinite(bestRadius),'包围圆计算失败，需检查退化顶点。');
radius = max(vecnorm(points-center,2,2));
end

function checks = basicChecks(settings)
labels = strings(0,1);
passed = false(0,1);
errors = zeros(0,1);
sets = {[0 0],[-20 0;20 0],[0 0;40 0;20 20*sqrt(3)], ...
    [-2 -1;2 -1;2 1;-2 1],[0 0;1 0;2 0;2 0]};
expected = [0 20 40/sqrt(3) sqrt(5) 1];
for k = 1:numel(sets)
    [~,radius,certificate] = enclosingCircle(sets{k});
    labels(end+1,1) = "包围圆已知解"+k;
    errors(end+1,1) = max(abs([radius certificate]-expected(k)));
    passed(end+1,1) = errors(end)<1e-7;
end
boundary = [1000*cosd(59) 1000*sind(59)];
source = 1000*[cosd(-1) sind(-1)];
labels(end+1,1) = "扇区接收等号边界";
errors(end+1,1) = abs(norm(boundary-source)-1000);
passed(end+1,1) = errors(end)<1e-7 && safePoints(boundary,settings);
state = rng;
cleanup = onCleanup(@()rng(state));
rng(20260911,'twister');
maximumError = 0;
for k = 1:12
    points = randn(7,2)*10;
    [~,radius] = enclosingCircle(points);
    independent = 0;
    for i = 1:5
        for j = i+1:6
            for m = j+1:7
                lengths = sort([norm(points(i,:)-points(j,:)), ...
                    norm(points(i,:)-points(m,:)),norm(points(j,:)-points(m,:))]);
                if lengths(3)^2>=lengths(1)^2+lengths(2)^2
                    value = lengths(3)/2;
                else
                    semi = sum(lengths)/2;
                    area = sqrt(max(0,semi*prod(semi-lengths)));
                    value = prod(lengths)/(4*area);
                end
                independent = max(independent,value);
            end
        end
    end
    maximumError = max(maximumError,abs(radius-independent));
end
labels(end+1,1) = "包围圆与三点子集公式独立复算";
errors(end+1,1) = maximumError;
passed(end+1,1) = maximumError<1e-7;
invalidInputs = {[NaN 0],[0 0 0]};
for k = 1:numel(invalidInputs)
    rejected = false;
    try
        q2_localization(invalidInputs{k},0);
    catch
        rejected = true;
    end
    labels(end+1,1) = "非法首点拒绝"+k;
    errors(end+1,1) = double(~rejected);
    passed(end+1,1) = rejected;
end
square = [-1 -1;1 -1;1 1;-1 1];
empty = clipPlane(square,[1 0],-2);
labels(end+1,1) = "矛盾半平面返回空集";
errors(end+1,1) = size(empty,1);
passed(end+1,1) = isempty(empty);
nearPoint = [500 0];
nearRegion = clipDisk(circlePolygon([0 0],1500,360,true),nearPoint,5,360,true);
[nearCenter,nearRadius] = enclosingCircle(nearRegion);
labels(end+1,1) = "near独立分支与5米范围";
errors(end+1,1) = max(norm(nearCenter-nearPoint),abs(nearRadius-5));
passed(end+1,1) = errors(end)<0.001;
precise = settings;
precise.circleSides = 5760;
[region,~] = initialRegion([0 0],precise);
domain = receiveDomain(region,settings);
angles = (-88:0.5:88)';
alpha = abs(angles)+settings.delta;
analytic = min(2000*cosd(alpha),5*cosd(alpha)+sqrt(1000^2-25*sind(alpha).^2));
computed = domainLimit(angles,domain,settings);
labels(end+1,1) = "连续接收域与四圆盘解析式对照";
errors(end+1,1) = max(abs(computed-analytic));
passed(end+1,1) = errors(end)<0.002 && all(computed<=analytic+1e-7);
crossing = [800 -20;1200 -20;1200 20;800 20];
point = 1050*[cosd(60) sind(60)];
vertexViolation = max(sum((crossing-point).^2,2)-max(1000^2,sum(crossing.^2,2)));
completeViolation = domainViolation(point,receiveDomain(crossing,settings),settings);
labels(end+1,1) = "跨1000米阈值不可仅检查顶点";
errors(end+1,1) = double(~(vertexViolation<0 && completeViolation>0));
passed(end+1,1) = errors(end)==0;
witness = initialWitness([-1794.99 0],settings);
labels(end+1,1) = "极窄合法首测的解析见证";
errors(end+1,1) = max(0,max(vecnorm(witness-[-1794.99 0],2,2))-1800);
passed(end+1,1) = all(vecnorm(witness,2,2)>5) && errors(end)<1e-7;
rejected = false;
try
    initialWitness([-2000 0],settings);
catch
    rejected = true;
end
labels(end+1,1) = "方向与源域不相容时拒绝求解";
errors(end+1,1) = double(~rejected);
passed(end+1,1) = rejected;
checks = table(labels,passed,errors,'VariableNames',{'Check','Passed','Error'});
end

function checks = verifyCase(item,settings)
labels = item.name+"_"+["候选接收约束";"预算最优上界非增"; ...
    "空间候选逐级加密非增";"构造真值包含与包围";"旋转跨零一致"; ...
    "反馈最坏半径上下界";"精细反馈间隙";"原三圆盘包含于新域"; ...
    "首测与二测信息单调";"扩域与相同精化基线比较"];
passed = false(numel(labels),1);
errors = zeros(numel(labels),1);
violations = zeros(size(item.points,1),1);
for k = 1:size(item.points,1)
    violations(k) = domainViolation(item.points(k,:),item.domain,settings);
end
errors(1) = max(0,max(violations));
passed(1) = errors(1)<1e-5;
errors(2) = max([0;diff(item.budget(:,5))]);
passed(2) = errors(2)<1e-7;
errors(3) = max([0;diff(item.searchLevels(:,2))]);
passed(3) = errors(3)<1e-7;
truthCount = 0;
maximumViolation = 0;
truths = [item.witness;feasibleSupport(item.initialInner,[0 0],settings.nearRadius)];
for truthIndex = 1:size(truths,1)
        truth = truths(truthIndex,:);
        distance = norm(truth);
        if norm(truth-item.sourceCenter)>settings.sourceRadius+1e-8
            continue
        end
        maximumViolation = max(maximumViolation,norm(truth-item.point)-max(1000,distance));
        for secondError = [-1 0 1]
            if norm(truth-item.point)<=5
                region = clipDisk(item.initial,item.point,5,1440,true);
            else
                bearing = atan2d(truth(2)-item.point(2),truth(1)-item.point(1))+secondError;
                region = clipWedge(item.initial,item.point,bearing,settings.delta);
            end
            [center,radius] = enclosingCircle(region);
            if isempty(region)
                maximumViolation = inf;
            else
                maximumViolation = max(maximumViolation,norm(truth-center)-radius);
                edges = region([2:end 1],:)-region;
                relative = truth-region;
                lengths = vecnorm(edges,2,2);
                signed = (edges(:,1).*relative(:,2)-edges(:,2).*relative(:,1))./max(lengths,1e-12);
                maximumViolation = max(maximumViolation,-min(signed));
            end
            truthCount = truthCount+1;
        end
end
errors(4) = maximumViolation;
passed(4) = truthCount>0 && maximumViolation<1e-6;
globalPoint = item.point*item.rotation'+item.firstPoint;
recovered = (globalPoint-item.firstPoint)*item.rotation;
errors(5) = max(norm(recovered-item.point),abs(mod(359.8-0.2+180,360)-180+0.4));
passed(5) = errors(5)<1e-7;
errors(6) = max(0,item.final.lower-item.final.upper);
passed(6) = errors(6)<1e-7;
errors(7) = item.final.gap;
passed(7) = item.final.gap<0.005;
angles = (-88:1:88)';
oldRadii = min(1000,2000*cosd(abs(angles)+settings.delta));
newRadii = domainLimit(angles,item.domain,settings);
errors(8) = max(0,max(oldRadii-newRadii));
passed(8) = errors(8)<1e-7;
errors(9) = max(0,item.final.upper-item.initialRadius);
passed(9) = errors(9)<0.005 && item.initialLower<=item.initialRadius+1e-7;
errors(10) = max(0,item.final.upper-item.oldScore.upper);
passed(10) = errors(10)<1e-7;
checks = table(labels,passed,errors,'VariableNames',{'Check','Passed','Error'});
end

function summary = summarizeCases(items)
count = numel(items);
names = strings(count,1);
values = zeros(count,21);
for k = 1:count
    item = items{k};
    names(k) = item.name;
    values(k,:) = [item.firstPoint item.bearing item.globalPoint item.point ...
        item.final.lower item.final.upper norm(item.point)/5+5 ...
        size(item.points,1) item.final.upper-item.finiteGridLower ...
        item.initialLower item.initialRadius item.initialCenter*item.rotation'+item.firstPoint ...
        item.oldScore.lower item.oldScore.upper item.initialSufficient item.secondSufficient ...
        (item.initialRadius-item.final.upper)/item.initialRadius*100];
end
summary = [table(names,'VariableNames',{'场景'}),array2table(values, ...
    'VariableNames',{'首点X米','首点Y米','首示向度','第二点X米','第二点Y米', ...
    '局部前进米','局部侧移米','最坏半径下界米','最坏半径上界米', ...
    '移动加检测秒','候选点数','有限候选最优差距上界米', ...
    '首测半径下界米','首测半径上界米','首测圆心X米','首测圆心Y米', ...
    '三圆盘精化下界米','三圆盘精化上界米','首测20米充分','二测20米充分','半径上界改善百分比'})];
end

function exportCase(item,index,outputRoot)
prefix = sprintf('场景%d_',index);
support = item.domain.support;
violation = sum((support-item.point).^2,2)-max(1000^2,sum(support.^2,2));
[maximum,indexMaximum] = max(violation);
writetable(array2table([item.point maximum support(indexMaximum,:)], ...
    'VariableNames',{'推荐前进米','推荐侧移米','最大约束违反量平方米','支持源前进米','支持源侧向米'}), ...
    fullfile(outputRoot,[prefix '接收保证数值证书.csv']),'Encoding','UTF-8');
writetable(array2table(item.domainBoundary,'VariableNames',{'前进米','侧向米'}), ...
    fullfile(outputRoot,[prefix '改进候选域边界.csv']),'Encoding','UTF-8');
writetable(array2table(item.domain.support,'VariableNames',{'前进米','侧向米'}), ...
    fullfile(outputRoot,[prefix '连续接收证书支持点.csv']),'Encoding','UTF-8');
values = [item.points item.scores vecnorm(item.points,2,2)/5+5];
columns = {'前进米','侧移米','半径下界米','半径上界米','不利示向度', ...
    '反馈二分次数','半径间隙米','移动加检测秒'};
writetable(array2table(values,'VariableNames',columns), ...
    fullfile(outputRoot,[prefix '全部候选.csv']),'Encoding','UTF-8');
writetable(array2table(item.budget,'VariableNames', ...
    {'预算米','前进米','侧移米','半径下界米','半径上界米','移动加检测秒'}), ...
    fullfile(outputRoot,[prefix '预算权衡.csv']),'Encoding','UTF-8');
baselineNames = ["首测已有信息";"固定左侧移";"固定右侧移";"前向共线";"三圆盘内精化"];
writetable([table(baselineNames,'VariableNames',{'策略'}), ...
    array2table([item.baselinePoints item.baselineScores], ...
    'VariableNames',{'前进米','侧移米','半径下界米','半径上界米','移动加检测秒'})], ...
    fullfile(outputRoot,[prefix '基线比较.csv']),'Encoding','UTF-8');
writetable(array2table(item.searchLevels,'VariableNames',{'累计候选点数','最优半径上界米'}), ...
    fullfile(outputRoot,[prefix '空间加密.csv']),'Encoding','UTF-8');
writetable(array2table(item.initial,'VariableNames',{'前进米','侧向米'}), ...
    fullfile(outputRoot,[prefix '首测外包顶点.csv']),'Encoding','UTF-8');
writetable(array2table(item.posterior,'VariableNames',{'前进米','侧向米'}), ...
    fullfile(outputRoot,[prefix '不利反馈外包顶点.csv']),'Encoding','UTF-8');
end

function makeFigures(items,settings,outputRoot)
blue = [0.10 0.34 0.62];
orange = [0.85 0.43 0.10];
grey = [0.35 0.38 0.42];
font = 'Microsoft YaHei';
angles = linspace(-90+settings.delta,90-settings.delta,1201)';
radii = min(settings.receiveMin,2*settings.receiveMin*cosd(abs(angles)+settings.delta));
original = radii.*[cosd(angles) sind(angles)];
columns = min(3,numel(items));
rows = ceil(numel(items)/columns);
figureOne = figure('Visible','off','Color','w','Position',[80 80 1200 380*rows]);
layout = tiledlayout(figureOne,rows,columns,'TileSpacing','compact','Padding','compact');
for k = 1:numel(items)
    ax = nexttile(layout);
    item = items{k};
    boundary = item.domainBoundary;
    fill(ax,boundary(:,1),boundary(:,2),[0.89 0.94 0.98],'EdgeColor',blue,'LineWidth',1.2);
    hold(ax,'on');
    plot(ax,original(:,1),original(:,2),'--','Color',grey,'LineWidth',1.2);
    plot(ax,item.point(1),item.point(2),'p','MarkerSize',12,'MarkerFaceColor',orange,'MarkerEdgeColor','k');
    plot(ax,0,0,'k+','MarkerSize',7);
    axis(ax,'equal');grid(ax,'on');
    xlabel(ax,'前进位移（m）');ylabel(ax,'侧向位移（m）');
    title(ax,item.name+'：连续保接收域');
    legend(ax,{'利用源圆域','原三圆盘域','推荐测点','首测点'}, ...
        'Location','southoutside','NumColumns',2,'FontSize',8);
end
set(findall(figureOne,'Type','axes'),'FontName',font,'FontSize',10,'Box','on');
exportFigure(figureOne,fullfile(outputRoot,'图1_候选区域与选点'));
figureTwo = figure('Visible','off','Color','w','Position',[80 80 1200 360*rows]);
layout = tiledlayout(figureTwo,rows,columns,'TileSpacing','compact','Padding','compact');
for k = 1:numel(items)
    ax = nexttile(layout);
    item = items{k};
    plot(ax,item.budget(:,1),item.budget(:,5),'-o','Color',blue,'LineWidth',1.5, ...
        'MarkerFaceColor','w','MarkerSize',5);
    hold(ax,'on');
    yline(ax,item.final.upper,'--','Color',orange,'LineWidth',1.2);
    legend(ax,{'预算内推荐','不限制移动预算'},'Location','northeast','FontSize',8);
    grid(ax,'on');xlabel(ax,'移动预算（m）');ylabel(ax,'最坏半径上界（m）');
    title(ax,item.name+'（自建，各图尺度不同）');xlim(ax,[0 max(settings.budgets)*1.05]);
end
set(findall(figureTwo,'Type','axes'),'FontName',font,'FontSize',10,'Box','on');
exportFigure(figureTwo,fullfile(outputRoot,'图2_预算与定位质量'));
figureThree = figure('Visible','off','Color','w','Position',[80 80 1200 360*rows]);
layout = tiledlayout(figureThree,rows,columns,'TileSpacing','compact','Padding','compact');
circleAngles = linspace(0,360,361)';
for k = 1:numel(items)
    ax = nexttile(layout);
    item = items{k};
    polygon = item.posterior;
    fill(ax,polygon(:,1),polygon(:,2),[0.84 0.91 0.97],'EdgeColor',blue,'LineWidth',1.2);
    hold(ax,'on');
    circle = item.posteriorCenter+item.posteriorRadius*[cosd(circleAngles) sind(circleAngles)];
    plot(ax,circle(:,1),circle(:,2),'--','Color',orange,'LineWidth',1.4);
    plot(ax,item.posteriorCenter(1),item.posteriorCenter(2),'+','Color','k','MarkerSize',7);
    axis(ax,'equal');margin = max(item.posteriorRadius*1.3,0.1);
    xlim(ax,item.posteriorCenter(1)+[-margin margin]);ylim(ax,item.posteriorCenter(2)+[-margin margin]);
    xlabel(ax,'局部前进坐标（m）');ylabel(ax,'局部侧向坐标（m）');
    title(ax,sprintf('%s：代表反馈 r = %.3f m',item.name,item.posteriorRadius));
    legend(ax,{'定位区域外包','包围圆','圆心'},'Location','southoutside','FontSize',8);
end
set(findall(figureThree,'Type','axes'),'FontName',font,'FontSize',10,'Box','on');
exportFigure(figureThree,fullfile(outputRoot,'图3_不利反馈定位区域'));
end

function exportFigure(handle,path)
exportgraphics(handle,[path '.png'],'Resolution',200);
exportgraphics(handle,[path '.pdf'],'ContentType','vector');
savefig(handle,[path '.fig']);
close(handle);
end

function result = verifyResearch12(settings,outputRoot)
if isfolder(outputRoot)
    error('输出目录已经存在，请使用新的目录。');
end
base = fileparts(mfilename('fullpath'));
inputFile = fullfile(base,'既有结果_v1.1.1','完整结果.mat');
if ~isfile(inputFile)
    inputFile = fullfile(base,'论文素材包','v1.1.1','运行结果','20260911_093333_770','完整结果.mat');
end
assert(isfile(inputFile),'缺少固定v1.1.1结果文件。');
prior = load(inputFile,'result');
assert(strcmp(prior.result.settings.version,'1.1.1'),'必须使用固定v1.1.1输入。');
mkdir(outputRoot);
started = tic;
fprintf('第01和02项研究验证；MATLAB %s；程序%s\n',version,settings.version);
names = strings(0,1); passed = false(0,1); residuals = zeros(0,1);
firstSource = 1459.5; lastSource = 1500; diskRadius = 1005;
numerator = (lastSource-firstSource)*diskRadius;
denominatorSquared = (firstSource^2-diskRadius^2)*(lastSource^2-diskRadius^2);
maxTangent = numerator/sqrt(denominatorSquared);
maxAngle = atand(maxTangent);
maxCosine = (firstSource+lastSource)*diskRadius/(firstSource*lastSource+diskRadius^2);
extremePoint = diskRadius*[maxCosine sqrt(1-maxCosine^2)];
view = [firstSource 0;lastSource 0]-extremePoint;
directAngle = atan2d(abs(det(view)),dot(view(1,:),view(2,:)));
proof = table(firstSource,lastSource,diskRadius,denominatorSquared,maxTangent,maxAngle, ...
    2-maxAngle,(lastSource-firstSource)/2,extremePoint(1),extremePoint(2), ...
    'VariableNames',{'SourceA','SourceB','SafeDiskRadius','DenominatorSquared', ...
    'MaxTangent','MaxAngleDeg','AngleMarginDeg','RadiusLower','ExtremeX','ExtremeY'});
record("01解析最大视角与向量夹角一致",abs(directAngle-maxAngle)<1e-10,abs(directAngle-maxAngle));
record("01严格比较链",denominatorSquared>1178000^2 && numerator/1178000<0.0346 ...
    && 0.0346<pi/90 && pi/90<tand(2),2-maxAngle);
record("01两个源均为普通方向反馈",firstSource-diskRadius>5,lastSource-diskRadius);
record("01后验下界严格大于20米",(lastSource-firstSource)/2>20,0.25);
record("01朝内源圆不截断条件",1500<3500*cosd(1) && 1750<1800,3500*cosd(1)-1500);
validationAngles = linspace(-180,180,721)';
q = diskRadius*[cosd(validationAngles) sind(validationAngles)];
v1 = [firstSource 0]-q; v2 = [lastSource 0]-q;
sampleAngle = atan2d(abs(v1(:,1).*v2(:,2)-v1(:,2).*v2(:,1)),sum(v1.*v2,2));
record("01圆周方向公式抽查",max(sampleAngle)<=maxAngle+1e-10,maxAngle-max(sampleAngle));
writetable(proof,fullfile(outputRoot,'01_下界核验.csv'),'Encoding','UTF-8');
caseIndices = [1 5 3];
data = cell(6,1);
for k = 1:3
    item = prior.result.cases{caseIndices(k)};
    data{k} = struct('name',item.name+"推荐反馈",'sourceCenter',item.sourceCenter, ...
        'point',item.point,'angle',item.final.angle,'feedback',item.final.feedback, ...
        'previousLower',item.final.lower,'previousUpper',item.final.upper, ...
        'previousPosterior',item.posteriorRadius);
end
data{4} = struct('name',"近距完整圆盘",'sourceCenter',[0 0],'point',[500 0], ...
    'angle',NaN,'feedback',"near",'previousLower',NaN,'previousUpper',NaN,'previousPosterior',NaN);
data{5} = struct('name',"共线相向开边界",'sourceCenter',[0 0],'point',[500 0], ...
    'angle',180,'feedback',"direction",'previousLower',NaN,'previousUpper',NaN,'previousPosterior',NaN);
data{6} = struct('name',"接收边界诊断",'sourceCenter',[2600 0],'point',[-500 0], ...
    'angle',0,'feedback',"direction",'previousLower',NaN,'previousUpper',NaN,'previousPosterior',NaN);
precise = settings; precise.circleSides = 5760;
rows = cell(6,1); details = cell(6,1);
for k = 1:6
    item = data{k};
    geometry = exactGeometry12(item.sourceCenter,item.point,item.angle,item.feedback);
    [center,lower,upper,certificate] = exactCircle12(geometry);
    [outer,inner] = initialRegion(item.sourceCenter,precise);
    outer = clipDisk(outer,item.point,1500,5760,true);
    inner = clipDisk(inner,item.point,1500,5760,false);
    if item.feedback == "near"
        mainOuter = clipDisk(outer,item.point,5,720,true);
        mainInner = clipDisk(inner,item.point,5,720,false);
        mainSupport = feasibleSupport(mainInner,[0 0],5);
        [~,mainUpper] = enclosingCircle(mainOuter);
        mainUpper = min(5,mainUpper);
        [~,~,mainLower] = enclosingCircle(mainSupport);
    else
        [mainLower,mainUpper] = intervalScore(item.point,outer,inner,item.angle,0,precise);
        mainOuter = clipWedge(outer,item.point,item.angle,1);
        direction = [cosd(item.angle) sind(item.angle)];
        mainOuter = clipPlane(mainOuter,-direction,-dot(direction,item.point)-5*cosd(1));
        mainInner = clipWedge(inner,item.point,item.angle,1);
        mainSupport = feasibleSupport(mainInner,[0 0;item.point],5);
    end
    outerViolation = exactPolygonContainment12(geometry,mainOuter);
    innerViolation = max([0;constraintViolation12(geometry,mainSupport)]);
    proofGap = upper-lower;
    radius = (lower+upper)/2;
    sourceClearance = norm(center)-upper;
    pointClearance = norm(center-item.point)-upper;
    if k == 5
        exactKnown = sqrt(250^2-2500*cosd(1)+25);
        epsilon = 1e-7;
        witness = [(5+epsilon)*[cosd(1) sind(1)]; ...
            [500 0]-(5+epsilon)*[cosd(1) sind(1)]];
        strictLower = norm(witness(1,:)-witness(2,:))/2;
        record("02共线闭式与连续复算一致",abs(radius-exactKnown)<3e-6,abs(radius-exactKnown));
        record("02开边界合法逼近见证",all(vecnorm(witness,2,2)>5) ...
            && all(vecnorm(witness-[500 0],2,2)>5) && abs(strictLower-exactKnown)<2e-7, ...
            exactKnown-strictLower);
        certificate.strictWitness = witness;
        writematrix(witness,fullfile(outputRoot,'02_5_合法逼近见证.csv'));
    elseif k == 4
        exactKnown = 5;
        record("02近距整圆解析解",abs(radius-5)<3e-6 && norm(center-[500 0])<1e-7,abs(radius-5));
        record("02近距圆盘首楔形包含",asind(5/500)<1,1-asind(5/500));
        record("02近距后验远离首点开边界",sourceClearance>5,sourceClearance-5);
    else
        exactKnown = NaN;
        record("02"+k+"后验远离5米开边界",min(sourceClearance,pointClearance)>5, ...
            min(sourceClearance,pointClearance)-5);
    end
    record("02"+k+"独立支撑上下界闭合",proofGap<1e-5,proofGap);
    record("02"+k+"支撑权重非负归一",all(certificate.weights>=0) ...
        && abs(sum(certificate.weights)-1)<1e-12,abs(sum(certificate.weights)-1));
    record("02"+k+"支撑可行及圆心凸组合",certificate.supportViolation<2e-7 ...
        && certificate.centerResidual<2e-7,max(certificate.supportViolation,certificate.centerResidual));
    record("02"+k+"真实曲线包含于主外包",outerViolation<2e-6,outerViolation);
    record("02"+k+"主下界支撑真实可行",innerViolation<2e-6,innerViolation);
    record("02"+k+"固定反馈半径夹逼",mainLower<=upper+2e-6 && mainUpper>=lower-2e-6, ...
        max(mainLower-upper,lower-mainUpper));
    if k <= 3
        record("02"+k+"独立后验不超过既有最坏上界",upper<=item.previousUpper+2e-6, ...
            item.previousUpper-upper);
    end
    support = certificate.support;
    atExcludedBoundary = vecnorm(support,2,2)<=5+1e-8;
    if item.feedback == "direction"
        atExcludedBoundary = atExcludedBoundary | vecnorm(support-item.point,2,2)<=5+1e-8;
    end
    witnessTable = table(support(:,1),support(:,2),certificate.weights,atExcludedBoundary, ...
        'VariableNames',{'X','Y','Weight','UsesClosureBoundary'});
    writetable(witnessTable,fullfile(outputRoot,sprintf('02_%d_支撑证书.csv',k)),'Encoding','UTF-8');
    rows{k} = table(string(item.name),item.point(1),item.point(2),string(item.feedback),item.angle, ...
        center(1),center(2),lower,upper,mainLower,mainUpper,mainUpper-radius, ...
        proofGap,outerViolation,innerViolation,sourceClearance,pointClearance, ...
        item.previousLower,item.previousUpper,item.previousPosterior,exactKnown, ...
        size(support,1),certificate.iterations, ...
        'VariableNames',{'Case','PointX','PointY','Feedback','AngleDeg','CenterX','CenterY', ...
        'ExactLower','ExactUpper','MainLower','MainUpper','MainUpperMinusExact', ...
        'IndependentGap','OuterViolation','InnerViolation','FirstClearance','SecondClearance', ...
        'PreviousWorstLower','PreviousWorstUpper','PreviousPosterior','ClosedFormRadius', ...
        'SupportCount','Iterations'});
    details{k} = struct('input',item,'geometry',geometry,'center',center,'lower',lower, ...
        'upper',upper,'certificate',certificate,'mainOuter',mainOuter,'mainSupport',mainSupport);
    fprintf('%s：独立[%.9f, %.9f]；主实现固定反馈[%.9f, %.9f]\n', ...
        item.name,lower,upper,mainLower,mainUpper);
end
emptyGeometry = exactGeometry12([0 0],[500 500],0,"direction");
record("02不相容反馈空集拒绝",isempty(emptyGeometry.nodes),size(emptyGeometry.nodes,1));
badRejected = false;
try
    exactGeometry12([0 0],[NaN 0],0,"direction");
catch
    badRejected = true;
end
record("02非法坐标拒绝",badRejected,0);
summary = vertcat(rows{:});
checks = table(names,passed,residuals,'VariableNames',{'Check','Passed','Residual'});
writetable(summary,fullfile(outputRoot,'02_独立几何对照.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputRoot,'必要验证.csv'),'Encoding','UTF-8');
researchFigure12(details,outputRoot);
status = 'FAIL';
if all(checks.Passed)
    status = 'SELF_CHECKED';
end
result = struct('version',settings.version,'matlabVersion',version,'proof',proof, ...
    'summary',summary,'checks',checks,'details',{details},'elapsedSeconds',toc(started), ...
    'inputVersion','1.1.1','status',status);
save(fullfile(outputRoot,'研究完整结果.mat'),'result');
fprintf('研究检查%d项，失败%d项，耗时%.3f秒。\n',height(checks),sum(~checks.Passed),result.elapsedSeconds);
assert(all(checks.Passed),'第01/02项验证存在失败，禁止发布。');
    function record(label,ok,value)
        names(end+1,1) = label;
        passed(end+1,1) = ok;
        residuals(end+1,1) = value;
    end
end

function geometry = exactGeometry12(sourceCenter,point,angle,feedback)
validateattributes(sourceCenter,{'numeric'},{'real','finite','size',[1 2]});
validateattributes(point,{'numeric'},{'real','finite','size',[1 2]});
circles = [sourceCenter 1800 1;0 0 1500 1;point 1500 1;0 0 5 -1];
normals = [sind(-1) -cosd(-1);-sind(1) cosd(1)];
bounds = zeros(2,1);
if feedback == "near"
    circles = [circles;point 5 1];
elseif feedback == "direction"
    validateattributes(angle,{'numeric'},{'real','finite','scalar'});
    newNormals = [sind(angle-1) -cosd(angle-1);-sind(angle+1) cosd(angle+1)];
    normals = [normals;newNormals];
    bounds = [bounds;newNormals*point'];
    circles = [circles;point 5 -1];
else
    error('未知反馈类型。');
end
geometry = struct('circles',circles,'normals',normals,'bounds',bounds);
nodes = zeros(0,2);
for i = 1:size(normals,1)
    for j = i+1:size(normals,1)
        matrix = normals([i j],:);
        if abs(det(matrix))>1e-12
            nodes(end+1,:) = (matrix\bounds([i j]))';
        end
    end
    direction = [-normals(i,2) normals(i,1)];
    for j = 1:size(circles,1)
        center = circles(j,1:2); radius = circles(j,3);
        signed = dot(normals(i,:),center)-bounds(i);
        heightSquared = radius^2-signed^2;
        if heightSquared>=-1e-8
            foot = center-signed*normals(i,:);
            nodes = [nodes;foot+sqrt(max(0,heightSquared))*direction; ...
                foot-sqrt(max(0,heightSquared))*direction];
        end
    end
end
for i = 1:size(circles,1)
    for j = i+1:size(circles,1)
        origin = circles(i,1:2); offset = circles(j,1:2)-origin;
        distance = norm(offset); radius = circles(i,3); otherRadius = circles(j,3);
        if distance<1e-12 || distance>radius+otherRadius+1e-8 ...
                || distance<abs(radius-otherRadius)-1e-8
            continue
        end
        unit = offset/distance;
        projection = (radius^2-otherRadius^2+distance^2)/(2*distance);
        heightSquared = radius^2-projection^2;
        if heightSquared>=-1e-7
            middle = origin+projection*unit;
            vertical = sqrt(max(0,heightSquared))*[-unit(2) unit(1)];
            nodes = [nodes;middle+vertical;middle-vertical];
        end
    end
    nodes = [nodes;circles(i,1:2)+circles(i,3)*[1 0;0 1;-1 0;0 -1]];
end
nodes = nodes(constraintViolation12(geometry,nodes)<=1e-7,:);
geometry.nodes = uniquetol(nodes,1e-10,'ByRows',true,'DataScale',1);
end

function violation = constraintViolation12(geometry,points)
violation = -inf(size(points,1),1);
for k = 1:size(geometry.circles,1)
    circle = geometry.circles(k,:);
    current = circle(4)*(vecnorm(points-circle(1:2),2,2)-circle(3));
    violation = max(violation,current);
end
if ~isempty(points)
    violation = max(violation,max(points*geometry.normals'-geometry.bounds',[],2));
end
end

function [farthest,distance] = curveFarthest12(geometry,center)
candidates = geometry.nodes;
for k = 1:size(geometry.circles,1)
    circle = geometry.circles(k,:);
    offset = circle(1:2)-center;
    if norm(offset)>1e-12
        candidate = circle(1:2)+circle(3)*offset/norm(offset);
        if constraintViolation12(geometry,candidate)<=1e-7
            candidates(end+1,:) = candidate;
        end
    end
end
assert(~isempty(candidates),'真实后验为空。');
[distance,index] = max(vecnorm(candidates-center,2,2));
farthest = candidates(index,:);
end

function [center,lower,upper,certificate] = exactCircle12(geometry)
points = geometry.nodes;
assert(~isempty(points),'真实后验为空。');
for iteration = 1:80
    [center,radius,support,weights] = supportCircle12(points);
    [farthest,distance] = curveFarthest12(geometry,center);
    meanPoint = weights'*support;
    lower = sqrt(sum(weights.*sum((support-meanPoint).^2,2)));
    if distance-lower<2e-7
        break
    end
    points = uniquetol([points;farthest],1e-11,'ByRows',true,'DataScale',1);
end
assert(distance-lower<2e-7,'独立曲线包围圆证书尚未闭合。');
certificate = struct('support',support,'weights',weights,'iterations',iteration, ...
    'rawLower',lower,'rawUpper',distance,'finiteRadius',radius, ...
    'supportViolation',max(constraintViolation12(geometry,support)), ...
    'centerResidual',norm(center-meanPoint),'farthest',farthest);
lower = max(0,lower-1e-6); upper = distance+1e-6;
end

function [center,radius,support,weights] = supportCircle12(points)
count = size(points,1); radius = inf; center = [NaN NaN];
support = zeros(0,2); weights = zeros(0,1);
if count == 1
    center = points; radius = 0; support = points; weights = 1; return
end
for i = 1:count-1
    for j = i+1:count
        trialCenter = (points(i,:)+points(j,:))/2;
        trialRadius = norm(points(i,:)-trialCenter);
        if trialRadius<radius && all(vecnorm(points-trialCenter,2,2)<=trialRadius+2e-8)
            center = trialCenter; radius = trialRadius;
            support = points([i j],:); weights = [0.5;0.5];
        end
    end
end
if isfinite(radius)
    return
end
for i = 1:count-2
    for j = i+1:count-1
        for k = j+1:count
            triangle = points([i j k],:);
            edges = triangle(2:3,:)-triangle(1,:);
            if rcond(edges)<1e-12
                continue
            end
            offset = (2*edges)\sum(edges.^2,2);
            trialCenter = triangle(1,:)+offset';
            trialRadius = norm(offset);
            if trialRadius>=radius
                continue
            end
            matrix = [triangle';ones(1,3)];
            barycentric = matrix\[trialCenter';1];
            if any(barycentric < -1e-9)
                continue
            end
            if all(vecnorm(points-trialCenter,2,2)<=trialRadius+2e-8)
                center = trialCenter; radius = trialRadius; support = triangle;
                weights = max(0,barycentric); weights = weights/sum(weights);
            end
        end
    end
end
assert(isfinite(radius),'独立有限支撑证书构造失败。');
end

function violation = exactPolygonContainment12(geometry,polygon)
assert(size(polygon,1)>=3,'本组复算预期非退化主外包。');
twiceArea = sum(polygon(:,1).*polygon([2:end 1],2)-polygon(:,2).*polygon([2:end 1],1));
orientation = sign(twiceArea); violation = -inf;
for i = 1:size(polygon,1)
    edge = polygon(mod(i,size(polygon,1))+1,:)-polygon(i,:);
    if norm(edge)<1e-12
        continue
    end
    normal = orientation*[edge(2) -edge(1)]/norm(edge);
    candidates = geometry.nodes;
    for k = 1:size(geometry.circles,1)
        circle = geometry.circles(k,:);
        stationary = circle(1:2)+circle(3)*normal;
        if constraintViolation12(geometry,stationary)<=1e-7
            candidates(end+1,:) = stationary;
        end
    end
    violation = max(violation,max((candidates-polygon(i,:))*normal'));
end
end

function researchFigure12(details,outputRoot)
handle = figure('Visible','off','Color','w','Position',[100 100 1500 890]);
layout = tiledlayout(handle,2,3,'TileSpacing','compact','Padding','loose');
for i = 1:numel(details)
    data = details{i}; geometry = data.geometry; ax = nexttile(layout);
    polygon = data.mainOuter;
    h1 = plot(ax,polygon([1:end 1],1),polygon([1:end 1],2),'--','Color',[0.85 0.30 0.12],'LineWidth',1.5);
    hold(ax,'on');
    angles = linspace(0,360,12001)';
    h2 = plot(ax,NaN,NaN,'Color',[0.12 0.35 0.60],'LineWidth',1.1);
    for j = 1:size(geometry.circles,1)
        circle = geometry.circles(j,:);
        points = circle(1:2)+circle(3)*[cosd(angles) sind(angles)];
        points(constraintViolation12(geometry,points)>1e-7,:) = NaN;
        plot(ax,points(:,1),points(:,2),'Color',[0.12 0.35 0.60],'LineWidth',1.1);
    end
    for j = 1:size(geometry.normals,1)
        normal = geometry.normals(j,:);
        onLine = geometry.nodes(abs(geometry.nodes*normal'-geometry.bounds(j))<1e-6,:);
        if size(onLine,1)>=2
            direction = [-normal(2) normal(1)];
            projection = onLine*direction';
            values = linspace(min(projection),max(projection),501)';
            points = geometry.bounds(j)*normal+values*direction;
            points(constraintViolation12(geometry,points)>1e-7,:) = NaN;
            plot(ax,points(:,1),points(:,2),'Color',[0.12 0.35 0.60],'LineWidth',1.1);
        end
    end
    circle = data.center+data.upper*[cosd(angles) sind(angles)];
    h3 = plot(ax,circle(:,1),circle(:,2),':','Color',[0.25 0.25 0.25],'LineWidth',1.1);
    support = data.certificate.support;
    h4 = plot(ax,support(:,1),support(:,2),'ko','MarkerFaceColor','w','MarkerSize',5);
    axis(ax,'equal'); grid(ax,'on');
    margin = max(data.upper*1.18,0.1);
    xlim(ax,data.center(1)+[-margin margin]);ylim(ax,data.center(2)+[-margin margin]);
    title(ax,sprintf('%s\nr = %.6f m',data.input.name,(data.lower+data.upper)/2),'FontSize',11);
    xlabel(ax,'局部前进坐标（m）'); ylabel(ax,'局部侧向坐标（m）');
    legend(ax,[h1 h2 h3 h4],{'主实现外包','真实圆弧/直线','独立包围圆','下界支撑点'}, ...
        'Location','southoutside','FontSize',8);
end
set(findall(handle,'Type','axes'),'FontName','Microsoft YaHei','FontSize',9);
exportgraphics(handle,fullfile(outputRoot,'02_独立几何复算.png'),'Resolution',200);
savefig(handle,fullfile(outputRoot,'02_独立几何复算.fig'));
close(handle);
end

function context = newScoreContext34(enabled)
context = struct('enabled',enabled,'values',containers.Map('KeyType','char','ValueType','any'), ...
    'seen',containers.Map('KeyType','char','ValueType','logical'), ...
    'stats',containers.Map({'requests','hits','kernelCalls','uniqueKeys','kernelSeconds'},{0,0,0,0,0}));
end

function key = scoreKey34(point,outer,inner,settings)
numbers = [point(:);size(outer,1);size(inner,1);settings.delta;settings.receiveMax; ...
    settings.nearRadius;settings.circleSides;settings.scoreTolerance;settings.maxSplits; ...
    settings.initialBins;outer(:);inner(:)];
key = reshape(num2hex(numbers).',1,[]);
end

function snapshot = scoreSnapshot34(context)
snapshot = struct('enabled',context.enabled,'requests',context.stats('requests'), ...
    'hits',context.stats('hits'),'kernelCalls',context.stats('kernelCalls'), ...
    'uniqueKeys',context.stats('uniqueKeys'),'kernelSeconds',context.stats('kernelSeconds'));
end

function output = performanceTable34(items)
rows = cell(numel(items),1);
for k = 1:numel(items)
    item = items{k}; metric = item.performance;
    rows{k} = table(string(item.name),metric.enabled,metric.solveSeconds,metric.geometrySeconds, ...
        metric.kernelSeconds,metric.requests,metric.hits,metric.kernelCalls,metric.uniqueKeys, ...
        'VariableNames',{'Case','CacheEnabled','SolveSeconds','GeometrySeconds','ScoreKernelSeconds', ...
        'Requests','Hits','KernelCalls','UniqueKeys'});
end
output = vertcat(rows{:});
end

function result = verifyResearch34(settings,outputRoot)
assert(~isfolder(outputRoot),'输出目录已经存在，请使用新目录。');
base = fileparts(mfilename('fullpath'));
priorFile = fullfile(base,'既有结果_v1.1.1','完整结果.mat');
proofFile = fullfile(base,'研究验证','20260911_01_02','研究完整结果.mat');
if ~isfile(priorFile)
    priorFile = fullfile(base,'论文素材包','v1.1.1','运行结果','20260911_093333_770','完整结果.mat');
    proofFile = fullfile(base,'论文素材包','v1.1.2','研究验证','20260911_01_02','研究完整结果.mat');
end
assert(isfile(priorFile) && isfile(proofFile),'缺少固定的前版证据。');
priorData = load(priorFile,'result'); prior = priorData.result;
proofData = load(proofFile,'result'); reference = proofData.result;
assert(strcmp(prior.settings.version,'1.1.1'),'固定输入版本不正确。');
mkdir(outputRoot); started = tic;
labels = strings(0,1); passed = false(0,1); residuals = zeros(0,1);
fprintf('第03/04项研究；MATLAB %s；程序%s\n',version,settings.version);
geometryRows = cell(15,1); index = 0;
for caseIndex = [1 3 6]
    item = reference.details{caseIndex}; input = item.input;
    truth = (item.lower+item.upper)/2;
    for sides = [360 720 1440 2880 5760]
        config = settings; config.circleSides = sides;
        clock = tic;
        [outer,inner] = initialRegion(input.sourceCenter,config);
        outer = clipDisk(outer,input.point,config.receiveMax,sides,true);
        inner = clipDisk(inner,input.point,config.receiveMax,sides,false);
        [lower,upper] = intervalScore(input.point,outer,inner,input.angle,0,config);
        index = index+1;
        geometryRows{index} = table(string(input.name),sides,input.angle,truth,lower,upper, ...
            truth-lower,upper-truth,1800*(1/cos(pi/sides)-1),toc(clock), ...
            'VariableNames',{'Case','CircleSides','FixedAngleDeg','ReferenceRadius','Lower','Upper', ...
            'LowerDeficit','UpperExcess','Single1800DiskRadialExcess','Seconds'});
        record("03几何夹逼"+caseIndex+"_"+sides,lower<=item.upper+2e-6 && upper>=item.lower-2e-6, ...
            max(lower-item.upper,item.lower-upper));
    end
end
geometryTable = vertcat(geometryRows{:});
writetable(geometryTable,fullfile(outputRoot,'03_固定反馈几何误差.csv'),'Encoding','UTF-8');
fprintf('固定反馈几何15组完成。\n');
feedbackRows = cell(15,1); index = 0;
for caseIndex = [1 5 3]
    item = prior.cases{caseIndex}; config = settings;
    config.circleSides = 5760; config.maxSplits = 2200;
    config.scoreContext = newScoreContext34(true);
    [outer,inner] = initialRegion(item.sourceCenter,config);
    previousLower = -inf; previousUpper = inf;
    for tolerance = [0.15 0.02 0.006 0.002 0.0005]
        config.scoreTolerance = tolerance; clock = tic;
        score = scorePoint(item.point,outer,inner,config);
        elapsed = toc(clock); index = index+1;
        feedbackRows{index} = table(string(item.name),5760,tolerance,score.lower,score.upper,score.gap, ...
            score.splits,score.gap<=tolerance+1e-8,elapsed, ...
            'VariableNames',{'Case','CircleSides','Tolerance','Lower','Upper','Gap','Splits','MetTolerance','Seconds'});
        record("03固定几何反馈细化"+caseIndex+"_"+tolerance,score.lower>=previousLower-1e-7 ...
            && score.upper<=previousUpper+1e-7 && score.lower<=score.upper, ...
            max(previousLower-score.lower,score.upper-previousUpper));
        previousLower = score.lower; previousUpper = score.upper;
    end
end
feedbackTable = vertcat(feedbackRows{:});
writetable(feedbackTable,fullfile(outputRoot,'03_固定几何反馈细化.csv'),'Encoding','UTF-8');
fprintf('固定几何反馈细化15组完成。\n');
spatialRows = cell(8,1); spatialDetails = cell(2,1); index = 0;
for studyIndex = 1:2
    indices = [1 5]; item = prior.cases{indices(studyIndex)};
    config = settings; config.circleSides = 2880; config.scoreTolerance = 0.006; config.maxSplits = 1600;
    config.scoreContext = newScoreContext34(true);
    finalConfig = config; finalConfig.circleSides = 5760;
    finalConfig.scoreTolerance = 0.0005; finalConfig.maxSplits = 2200;
    [outer,inner] = initialRegion(item.sourceCenter,config);
    [fineOuter,fineInner] = initialRegion(item.sourceCenter,finalConfig);
    domain = receiveDomain(fineOuter,settings);
    commonPoints = candidatePoints(settings,domain);
    commonScores = scoreRows(commonPoints,outer,inner,config);
    [~,order] = sort(commonScores(:,2));
    seeds = commonPoints(order(1),:);
    for j = 2:numel(order)
        if all(vecnorm(seeds-commonPoints(order(j),:),2,2)>max(5,item.initialRadius/25))
            seeds(end+1,:) = commonPoints(order(j),:);
        end
        if size(seeds,1)==3
            break
        end
    end
    outcomes = cell(4,1); localIndex = 0;
    for seedCount = [1 3]
        for fineSteps = [false true]
            localIndex = localIndex+1; clock = tic;
            config.searchSteps = [25 8 2];
            if fineSteps
                config.searchSteps = [25 8 2 0.5 0.1];
            end
            points = commonPoints; scores = commonScores;
            for j = 1:seedCount
                [trial,trialScores] = polishPoint(seeds(j,:),inf,false,domain,outer,inner,config);
                points = [points;trial]; scores = [scores;trialScores];
            end
            best = bestIndex(points,scores(:,2)); point = points(best,:);
            final = scorePoint(point,fineOuter,fineInner,finalConfig);
            index = index+1;
            spatialRows{index} = table(string(item.name),seedCount,config.searchSteps(end),2880,0.006, ...
                point(1),point(2),scores(best,1),scores(best,2),final.lower,final.upper, ...
                size(points,1),size(unique(points,'rows'),1),toc(clock), ...
                'VariableNames',{'Case','SeedCount','LastStep','SearchCircleSides','SearchTolerance', ...
                'PointX','PointY','SearchLower','SearchUpper','FinalLower','FinalUpper', ...
                'CandidateRows','UniqueCoordinates','IncrementalSeconds'});
            outcomes{localIndex} = struct('seeds',seeds(1:seedCount,:),'steps',config.searchSteps, ...
                'point',point,'final',final,'points',points,'scores',scores);
            record("03空间候选安全"+studyIndex+"_"+localIndex,domainViolation(point,domain,settings)<=1e-5, ...
                domainViolation(point,domain,settings));
        end
    end
    spatialDetails{studyIndex} = outcomes;
    fprintf('%s固定评分空间对比完成。\n',item.name);
end
spatialTable = vertcat(spatialRows{:});
writetable(spatialTable,fullfile(outputRoot,'03_固定评分空间搜索.csv'),'Encoding','UTF-8');
rankRows = cell(8,1); index = 0;
for studyIndex = 1:2
    pairs = [1 2;3 4;1 3;2 4];
    group = spatialTable((studyIndex-1)*4+(1:4),:);
    for j = 1:4
        old = group(pairs(j,1),:); new = group(pairs(j,2),:); index = index+1;
        lowerImprovement = old.FinalLower-new.FinalUpper;
        upperImprovement = old.FinalUpper-new.FinalLower;
        relation = "区间重叠_尚不能区分";
        if lowerImprovement>0
            relation = "后者改善已由区间确认";
        elseif upperImprovement<0
            relation = "后者较差已由区间确认";
        end
        rankRows{index} = table(old.Case,old.SeedCount,old.LastStep,new.SeedCount,new.LastStep, ...
            lowerImprovement,upperImprovement,relation, ...
            'VariableNames',{'Case','OldSeeds','OldLastStep','NewSeeds','NewLastStep', ...
            'ImprovementLower','ImprovementUpper','Conclusion'});
    end
end
rankingTable = vertcat(rankRows{:});
writetable(rankingTable,fullfile(outputRoot,'03_候选排序区间.csv'),'Encoding','UTF-8');
roundRows = cell(12,1); index = 0;
for caseIndex = 1:6
    item = prior.cases{caseIndex}; config = settings;
    config.circleSides = 5760; config.scoreTolerance = 0.002; config.maxSplits = 2200;
    config.scoreContext = newScoreContext34(true);
    [outer,inner] = initialRegion(item.sourceCenter,config);
    domain = receiveDomain(outer,settings);
    original = scorePoint(item.point,outer,inner,config);
    for digits = [3 2]
        scale = 10^digits;
        roundedGlobal = round(item.globalPoint,digits);
        roundedLocal = (roundedGlobal-item.firstPoint)*item.rotation;
        rawViolation = domainViolation(roundedLocal,domain,settings);
        selectedGlobal = roundedGlobal;
        if rawViolation>1e-5
            [dx,dy] = ndgrid(-2:2,-2:2);
            trialGlobal = roundedGlobal+[dx(:) dy(:)]/scale;
            trialLocal = (trialGlobal-item.firstPoint)*item.rotation;
            valid = false(size(dx(:)));
            for j = 1:numel(valid)
                valid(j) = domainViolation(trialLocal(j,:),domain,settings)<=1e-5;
            end
            assert(any(valid),'附近量化格点尚未找到安全点。');
            trialGlobal = trialGlobal(valid,:);
            [~,order] = sortrows([vecnorm(trialGlobal-item.globalPoint,2,2) trialGlobal],[1 2 3]);
            selectedGlobal = trialGlobal(order(1),:);
        end
        selectedLocal = (selectedGlobal-item.firstPoint)*item.rotation;
        selectedViolation = domainViolation(selectedLocal,domain,settings);
        score = scorePoint(selectedLocal,outer,inner,config); index = index+1;
        roundRows{index} = table(string(item.name),digits,roundedGlobal(1),roundedGlobal(2), ...
            rawViolation,rawViolation<=1e-5,selectedGlobal(1),selectedGlobal(2),selectedViolation, ...
            norm(selectedGlobal-item.globalPoint),original.lower,original.upper,score.lower,score.upper, ...
            score.lower-original.upper,score.upper-original.lower, ...
            'VariableNames',{'Case','Digits','RawGlobalX','RawGlobalY','RawViolationM2','RawSafe', ...
            'CheckedGlobalX','CheckedGlobalY','CheckedViolationM2','ShiftMeters', ...
            'OriginalLower','OriginalUpper','CheckedLower','CheckedUpper','RiskChangeLower','RiskChangeUpper'});
        record("03最终量化格点接收证书"+caseIndex+"_"+digits,selectedViolation<=1e-5,selectedViolation);
        record("03最终量化格点精度"+caseIndex+"_"+digits, ...
            max(abs(selectedGlobal*scale-round(selectedGlobal*scale)))<1e-7, ...
            max(abs(selectedGlobal*scale-round(selectedGlobal*scale))));
    end
end
roundingTable = vertcat(roundRows{:});
writetable(roundingTable,fullfile(outputRoot,'03_全局坐标舍入安全.csv'),'Encoding','UTF-8');
fprintf('坐标舍入12组完成；原始舍入不安全%d组，已另存核验格点。\n',sum(~roundingTable.RawSafe));
cacheChecks = cacheChecks34(settings);
for k = 1:height(cacheChecks)
    record(cacheChecks.Check(k),cacheChecks.Passed(k),cacheChecks.Residual(k));
end
benchmarkRows = cell(4,1); benchmarkCases = cell(4,1);
warm = settings; warm.circleSides = 720; warm.scoreContext = newScoreContext34(true);
[warmOuter,warmInner] = initialRegion([-1750 0],warm);
scorePoint([38 -30],warmOuter,warmInner,warm);
warm.scoreContext = newScoreContext34(false);
scorePoint([38 -30],warmOuter,warmInner,warm);
for k = 1:4
    config = settings; switches = [false true true false]; config.useCache = switches(k);
    clock = tic;
    item = solveCase([1750 0],0,"边缘朝外",config);
    elapsed = toc(clock); benchmarkCases{k} = item;
    metric = item.performance;
    benchmarkRows{k} = table(k,config.useCache,elapsed,metric.geometrySeconds,metric.kernelSeconds, ...
        metric.requests,metric.hits,metric.kernelCalls,metric.uniqueKeys, ...
        'VariableNames',{'Order','CacheEnabled','WallSeconds','GeometrySeconds','ScoreKernelSeconds', ...
        'Requests','Hits','KernelCalls','UniqueKeys'});
    record("04计数守恒"+k,metric.requests==metric.hits+metric.kernelCalls, ...
        metric.requests-metric.hits-metric.kernelCalls);
    if config.useCache
        record("04开启时每键只计算一次"+k,metric.kernelCalls==metric.uniqueKeys, ...
            metric.kernelCalls-metric.uniqueKeys);
    end
    if k>1
        [same,field] = sameCase34(benchmarkCases{1},item);
        record("04开关缓存结果逐字段一致"+k,same,double(~same));
        assert(same,'缓存改变了结果字段：%s',field);
    end
    fprintf('缓存对照%d/4，开关%d，%.3f秒，命中%d/%d。\n',k,config.useCache,elapsed,metric.hits,metric.requests);
end
[same,field] = sameCase34(prior.cases{2},benchmarkCases{1});
record("04与已发布v1.1.1场景逐字段一致",same,double(~same));
assert(same,'与既有结果不同：%s',field);
benchmarkTable = vertcat(benchmarkRows{:});
writetable(benchmarkTable,fullfile(outputRoot,'04_缓存ABBA计时.csv'),'Encoding','UTF-8');
checks = table(labels,passed,residuals,'VariableNames',{'Check','Passed','Residual'});
writetable(checks,fullfile(outputRoot,'必要验证.csv'),'Encoding','UTF-8');
status = 'FAIL'; if all(checks.Passed), status = 'SELF_CHECKED'; end
result = struct('version',settings.version,'matlabVersion',version,'status',status, ...
    'geometry',geometryTable,'feedback',feedbackTable,'spatial',spatialTable,'ranking',rankingTable, ...
    'rounding',roundingTable,'benchmark',benchmarkTable,'checks',checks, ...
    'spatialDetails',{spatialDetails},'benchmarkCases',{benchmarkCases},'elapsedSeconds',toc(started));
result.elapsedSeconds = toc(started);
result = exportResearch34(result,outputRoot,settings);
fprintf('03/04检查%d项，失败%d项，总耗时%.3f秒。\n',height(result.checks),sum(~result.checks.Passed),result.elapsedSeconds);
assert(all(result.checks.Passed),'第03/04项研究检查失败。');
    function record(label,ok,value)
        labels(end+1,1) = label;
        passed(end+1,1) = ok;
        residuals(end+1,1) = value;
    end
end

function output = cacheChecks34(settings)
settings.scoreContext = newScoreContext34(true);
[outer,inner] = initialRegion([0 0],settings); point = [842 -545];
first = scorePoint(point,outer,inner,settings);
second = scorePoint(point,outer,inner,settings);
labels = "04相同输入复用整个评分结构";
passed = isequaln(first,second); errors = double(~passed);
fields = ["delta" "receiveMax" "nearRadius" "circleSides" "scoreTolerance" "maxSplits" "initialBins"];
for k = 1:numel(fields)+3
    config = settings; testOuter = outer; testInner = inner; testPoint = point;
    if k<=numel(fields)
        field = fields(k); config.(field) = config.(field)+1;
        if field=="delta" || field=="scoreTolerance" || field=="nearRadius"
            config.(field) = settings.(field)+0.001;
        end
    elseif k==numel(fields)+1
        testOuter(1,1) = testOuter(1,1)+1e-8;
    elseif k==numel(fields)+2
        testInner(1,1) = testInner(1,1)+1e-8;
    else
        testPoint(1) = testPoint(1)+eps(testPoint(1));
    end
    before = scoreSnapshot34(config.scoreContext);
    cached = scorePoint(testPoint,testOuter,testInner,config);
    direct = computeScorePoint(testPoint,testOuter,testInner,config);
    after = scoreSnapshot34(config.scoreContext);
    ok = isequaln(cached,direct) && after.kernelCalls==before.kernelCalls+1;
    labels(end+1,1) = "04缓存依赖隔离"+k; passed(end+1,1) = ok; errors(end+1,1) = double(~ok);
end
otherContext = newScoreContext34(true);
labels(end+1,1) = "04新场景缓存为空"; passed(end+1,1) = otherContext.values.Count==0;
errors(end+1,1) = otherContext.values.Count;
output = table(labels,passed,errors,'VariableNames',{'Check','Passed','Residual'});
end

function [same,field] = sameCase34(first,second)
names = fieldnames(first); same = true; field = '';
for k = 1:numel(names)
    if strcmp(names{k},'performance')
        continue
    end
    if ~isfield(second,names{k}) || ~isequaln(first.(names{k}),second.(names{k}))
        same = false; field = names{k}; return
    end
end
end

function researchFigure34(result,outputRoot)
handle = figure('Visible','off','Color','w','Position',[100 100 1320 830]);
layout = tiledlayout(handle,2,2,'TileSpacing','compact','Padding','loose');
ax = nexttile(layout); hold(ax,'on');
names = unique(result.geometry.Case,'stable');
styles = {'-o','--s',':^'};
for k = 1:numel(names)
    rows = result.geometry(result.geometry.Case==names(k),:);
    plot(ax,rows.CircleSides,max(rows.UpperExcess,2e-6),styles{k},'LineWidth',1.2,'DisplayName',names(k));
end
set(ax,'XScale','log','YScale','log');grid(ax,'on');
xlabel(ax,'圆盘边数');ylabel(ax,'固定反馈半径上包多出量（m）');
title(ax,{'几何近似：反馈保持不变','图示下限2e-6 m表示差异未分辨'});
legend(ax,'Location','southoutside','FontSize',8);
ax = nexttile(layout);hold(ax,'on');names = unique(result.feedback.Case,'stable');
for k = 1:numel(names)
    rows = result.feedback(result.feedback.Case==names(k),:);
    plot(ax,rows.Tolerance,rows.Gap,styles{k},'LineWidth',1.2,'DisplayName',names(k));
end
set(ax,'XScale','log','YScale','log');grid(ax,'on');
xlim(ax,[min(result.feedback.Tolerance)/1.15 max(result.feedback.Tolerance)*1.15]);
ylim(ax,[min(result.feedback.Gap)/1.3 max(result.feedback.Gap)*1.3]);
xlabel(ax,'反馈细化停止容差（m）');ylabel(ax,'最坏半径上下界间隙（m）');
title(ax,'固定5760边：反馈细化后的总间隙');legend(ax,'Location','southoutside','FontSize',8);
ax = nexttile(layout);
values = result.benchmark.WallSeconds;
bar(ax,1:4,values,'FaceColor',[0.20 0.42 0.64]);
xticks(ax,1:4);xticklabels(ax,{'关A1','开B1','开B2','关A2'});ylabel(ax,'完整单场求解时间（s）');
title(ax,'同一输入的缓存ABBA对照');grid(ax,'on');
ax = nexttile(layout);
values = [result.benchmark.KernelCalls result.benchmark.Hits];
bar(ax,1:4,values,'stacked');xticks(ax,1:4);xticklabels(ax,{'关A1','开B1','开B2','关A2'});
ylabel(ax,'评分请求次数');title(ax,'实际计算与精确缓存复用');
legend(ax,{'实际评分核调用','缓存命中'},'Location','southoutside');grid(ax,'on');
set(findall(handle,'Type','axes'),'FontName','Microsoft YaHei','FontSize',10);
exportgraphics(handle,fullfile(outputRoot,'03_04_误差与缓存.png'),'Resolution',200);
savefig(handle,fullfile(outputRoot,'03_04_误差与缓存.fig'));close(handle);
end

function result = exportResearch34(result,outputRoot,settings)
base = fileparts(mfilename('fullpath'));
referenceFile = fullfile(base,'研究验证','20260911_01_02','研究完整结果.mat');
if ~isfile(referenceFile)
    referenceFile = fullfile(base,'论文素材包','v1.1.2','研究验证','20260911_01_02','研究完整结果.mat');
end
reference = load(referenceFile,'result');
geometry = result.geometry;
geometry.ReferenceLower = zeros(height(geometry),1);
geometry.ReferenceUpper = zeros(height(geometry),1);
decompositionRows = cell(height(geometry),1);
result.checks = result.checks(~startsWith(result.checks.Check,"03下界来源分解"),:);
for k = 1:height(geometry)
    index = find(reference.result.summary.Case==geometry.Case(k));
    assert(isscalar(index),'独立参考场景不唯一。');
    geometry.ReferenceLower(k) = reference.result.summary.ExactLower(index);
    geometry.ReferenceUpper(k) = reference.result.summary.ExactUpper(index);
    detail = reference.result.details{index}; input = detail.input;
    config = settings; config.circleSides = geometry.CircleSides(k);
    [~,inner] = initialRegion(input.sourceCenter,config);
    inner = clipDisk(inner,input.point,config.receiveMax,config.circleSides,false);
    section = clipWedge(inner,input.point,input.angle,config.delta);
    section = feasibleSupport(section,[0 0;input.point],config.nearRadius);
    [~,mainRadius,mainCertificate] = enclosingCircle(section);
    [finiteCenter,~,support,weights] = supportCircle12(section);
    meanPoint = weights'*support;
    finiteLower = max(0,sqrt(sum(weights.*sum((support-meanPoint).^2,2)))-1e-6);
    finiteUpper = max(vecnorm(section-finiteCenter,2,2))+1e-6;
    finiteMiddle = (finiteLower+finiteUpper)/2;
    shapeLoss = geometry.ReferenceRadius(k)-finiteMiddle;
    certificateSlack = finiteMiddle-mainCertificate;
    violation = max(constraintViolation12(detail.geometry,section));
    residual = max([violation-1e-7,finiteUpper-finiteLower-3e-6, ...
        mainCertificate-finiteUpper,finiteLower-mainRadius-1e-7,mainRadius-finiteUpper-1e-7, ...
        abs(mainCertificate-geometry.Lower(k))-1e-8, ...
        abs(shapeLoss+certificateSlack-geometry.LowerDeficit(k))-1e-8]);
    result.checks = [result.checks;table("03下界来源分解"+k,residual<=0,residual, ...
        'VariableNames',{'Check','Passed','Residual'})];
    decompositionRows{k} = table(geometry.Case(k),config.circleSides,size(section,1), ...
        finiteLower,finiteUpper,mainRadius,mainCertificate,shapeLoss, ...
        geometry.ReferenceLower(k)-finiteUpper,geometry.ReferenceUpper(k)-finiteLower, ...
        certificateSlack,finiteLower-mainCertificate,finiteUpper-mainCertificate,violation, ...
        'VariableNames',{'Case','CircleSides','SupportCount','FiniteLower','FiniteUpper', ...
        'MainFiniteRadius','MainCertificate','SupportLossMidpoint','SupportLossLower', ...
        'SupportLossUpper','CertificateSlackMidpoint','CertificateSlackLower','CertificateSlackUpper', ...
        'SupportViolationMeters'});
end
geometry.UpperExcessLower = geometry.Upper-geometry.ReferenceUpper;
geometry.UpperExcessUpper = geometry.Upper-geometry.ReferenceLower;
geometry.LowerDeficitLower = geometry.ReferenceLower-geometry.Lower;
geometry.LowerDeficitUpper = geometry.ReferenceUpper-geometry.Lower;
geometry.UpperDifferenceResolved = geometry.UpperExcessLower>0;
result.geometry = geometry;
result.feedback.RawGapBeforeMargin = max(0,result.feedback.Gap-2e-6);
result.feedback.MetTolerance = result.feedback.RawGapBeforeMargin<=result.feedback.Tolerance+1e-8;
result.reportedGapMargin = 2e-6;
result.decomposition = vertcat(decompositionRows{:});
off = result.benchmark(~result.benchmark.CacheEnabled,:);
on = result.benchmark(result.benchmark.CacheEnabled,:);
result.cacheSummary = table(height(off),height(on),mean(off.WallSeconds),mean(on.WallSeconds), ...
    mean(off.WallSeconds)/mean(on.WallSeconds),100*(1-mean(on.WallSeconds)/mean(off.WallSeconds)), ...
    mean(on.Requests),mean(on.Hits),mean(on.KernelCalls),100*mean(on.Hits./on.Requests), ...
    'VariableNames',{'OffRuns','OnRuns','MeanOffSeconds','MeanOnSeconds','ObservedSpeedRatio', ...
    'TimeReductionPercent','RequestsPerRun','HitsPerRun','KernelCallsPerRun','HitPercent'});
result.status = 'FAIL';
if all(result.checks.Passed)
    result.status = 'SELF_CHECKED';
end
tables = {result.geometry,result.feedback,result.spatial,result.ranking,result.rounding,result.benchmark,result.checks, ...
    result.decomposition,result.cacheSummary};
files = {'03_固定反馈几何误差.csv','03_固定几何反馈细化.csv','03_固定评分空间搜索.csv', ...
    '03_候选排序区间.csv','03_全局坐标舍入安全.csv','04_缓存ABBA计时.csv','必要验证.csv', ...
    '03_几何与证书损失分解.csv','04_缓存收益汇总.csv'};
for k = 1:numel(files)
    writetable(tables{k},fullfile(outputRoot,files{k}),'Encoding','UTF-8');
end
exportStarted = tic;
researchFigure34(result,outputRoot);
result.artifactExportSeconds = toc(exportStarted);
save(fullfile(outputRoot,'研究完整结果.mat'),'result');
assert(all(result.checks.Passed),'第03/04项导出与分解核验失败。');
end


function geometry = sourceGeometry130(sourceCenter,settings)
circles = [sourceCenter settings.sourceRadius 1;0 0 settings.receiveMax 1;0 0 settings.nearRadius -1];
normals = [sind(-settings.delta) -cosd(settings.delta);-sind(settings.delta) cosd(settings.delta)];
geometry = struct('circles',circles,'normals',normals,'bounds',[0;0], ...
    'sourceCenter',sourceCenter,'receiveMin',settings.receiveMin);
curves = [circles(:,1:3);0 0 settings.receiveMin];
raw = [0 0];
for i = 1:size(curves,1)
    origin = curves(i,1:2); radius = curves(i,3);
    raw = [raw;origin+radius*[1 0;0 1;-1 0;0 -1]];
    for j = i+1:size(curves,1)
        other = curves(j,1:2); rho = curves(j,3); offset = other-origin;
        distance = norm(offset);
        if distance<1e-12 || distance>radius+rho+1e-9 || distance<abs(radius-rho)-1e-9
            continue
        end
        unit = offset/distance;
        projection = (radius^2-rho^2+distance^2)/(2*distance);
        heightSquared = radius^2-projection^2;
        if heightSquared>=-1e-7
            middle = origin+projection*unit;
            vertical = sqrt(max(0,heightSquared))*[-unit(2) unit(1)];
            raw = [raw;middle+vertical;middle-vertical];
        end
    end
    for j = 1:size(normals,1)
        signed = dot(normals(j,:),origin);
        heightSquared = radius^2-signed^2;
        if heightSquared>=-1e-7
            foot = origin-signed*normals(j,:);
            direction = [-normals(j,2) normals(j,1)];
            raw = [raw;foot+sqrt(max(0,heightSquared))*direction;foot-sqrt(max(0,heightSquared))*direction];
        end
    end
end
arcs = zeros(0,6); segments = zeros(0,4); endpoints = zeros(0,2);
for i = 1:size(curves,1)
    origin = curves(i,1:2); radius = curves(i,3);
    on = abs(vecnorm(raw-origin,2,2)-radius)<1e-6;
    angles = mod(atan2(raw(on,2)-origin(2),raw(on,1)-origin(1)),2*pi);
    angleTolerance = max(1e-12,1e-7/radius);
    angles = uniquetol([angles;0;pi/2;pi;3*pi/2],angleTolerance,'DataScale',1);
    angles = sort(angles); angles(end+1) = angles(1)+2*pi;
    for j = 1:numel(angles)-1
        start = angles(j); finish = angles(j+1);
        middle = origin+radius*[cos((start+finish)/2) sin((start+finish)/2)];
        if finish-start>angleTolerance && constraintViolation12(geometry,middle)<=1e-8
            arcs(end+1,:) = [origin radius start finish norm(middle)<=settings.receiveMin+1e-8];
            endpoints = [endpoints;origin+radius*[cos(start) sin(start);cos(finish) sin(finish)]];
        end
    end
end
for i = 1:size(normals,1)
    direction = [-normals(i,2) normals(i,1)];
    on = abs(raw*normals(i,:)')<1e-6;
    coordinates = sort(uniquetol(raw(on,:)*direction',1e-9,'DataScale',1));
    for j = 1:numel(coordinates)-1
        first = coordinates(j)*direction; last = coordinates(j+1)*direction;
        middle = (first+last)/2;
        if norm(last-first)>1e-8 && constraintViolation12(geometry,middle)<=1e-8
            segments(end+1,:) = [first last]; endpoints = [endpoints;first;last];
        end
    end
end
valid = constraintViolation12(geometry,raw)<=1e-8;
isolated = raw(valid & vecnorm(raw,2,2)>settings.nearRadius+1e-7,:);
nodes = [isolated;endpoints];
if isempty(nodes)
    error('真实首测源域为空，或在当前数值容差下无法分辨。');
end
nodes = uniquetol(nodes,1e-8,'ByRows',true,'DataScale',1);
assert(all(constraintViolation12(geometry,nodes)<1e-5),'源域端点不合法。');
geometry.nodes = nodes; geometry.arcs = arcs; geometry.segments = segments;
removed = raw(valid & vecnorm(raw,2,2)<=settings.nearRadius+1e-7,:);
if ~isempty(removed)
    distance = inf(size(removed,1),1);
    for k = 1:size(nodes,1)
        distance = min(distance,vecnorm(removed-nodes(k,:),2,2));
    end
    removed = removed(distance>1e-6,:);
end
geometry.removedNearIsolates = removed;
end

function [violation,witness] = exactSafe130(point,geometry)
if norm(point)==0
    violation = 0; witness = geometry.nodes(1,:); return
end
candidates = geometry.nodes;
for k = 1:size(geometry.arcs,1)
    arc = geometry.arcs(k,:); origin = arc(1:2);
    if arc(6)
        offset = origin-point;
    else
        offset = -point;
    end
    if norm(offset)<1e-14
        continue
    end
    direction = offset/norm(offset);
    angle = mod(atan2(direction(2),direction(1))-arc(4),2*pi);
    if angle<=arc(5)-arc(4)+1e-12
        candidates(end+1,:) = origin+arc(3)*direction;
    end
end
values = sum((candidates-point).^2,2)-max(geometry.receiveMin^2,sum(candidates.^2,2));
[violation,index] = max(values); witness = candidates(index,:);
end

function [lower,upper] = exactLimits130(angles,geometry)
directions = [cosd(angles(:)) sind(angles(:))];
lower = zeros(size(angles(:))); upper = zeros(size(lower));
for k = 1:numel(lower)
    projection = geometry.nodes*directions(k,:)';
    allowance = max(0,geometry.receiveMin^2-sum(geometry.nodes.^2,2));
    upper(k) = min(projection+sqrt(max(0,projection.^2+allowance)));
    upper(k) = max(0,upper(k));
    if upper(k)==0
        continue
    end
    for iteration = 1:45
        middle = (lower(k)+upper(k))/2;
        violation = exactSafe130(middle*directions(k,:),geometry);
        if violation<=0
            lower(k) = middle;
        else
            upper(k) = middle;
        end
        if upper(k)-lower(k)<1e-7
            break
        end
    end
end
end

function points = sourceSamples130(geometry,count,settings)
points = geometry.nodes;
for k = 1:size(geometry.arcs,1)
    arc = geometry.arcs(k,:);
    angles = linspace(arc(4),arc(5),max(3,ceil(count*(arc(5)-arc(4))/(2*settings.delta*pi/180))));
    points = [points;arc(1:2)+arc(3)*[cos(angles(:)) sin(angles(:))]];
end
for k = 1:size(geometry.segments,1)
    segment = geometry.segments(k,:);
    fractions = linspace(0,1,count)';
    points = [points;segment(1:2)+(segment(3:4)-segment(1:2)).*fractions];
end
for angle = linspace(-settings.delta,settings.delta,5)
    direction = [cosd(angle) sind(angle)];
    projection = dot(geometry.sourceCenter,direction);
    discriminant = settings.sourceRadius^2-sum(geometry.sourceCenter.^2)+projection^2;
    if discriminant<0
        continue
    end
    lower = max(settings.nearRadius+1e-4,projection-sqrt(discriminant));
    upper = min(settings.receiveMax,projection+sqrt(discriminant));
    if lower<=upper
        points = [points;linspace(lower,upper,count)'*direction];
    end
end
valid = constraintViolation12(geometry,points)<=1e-7 & vecnorm(points,2,2)>settings.nearRadius+1e-7;
points = uniquetol(points(valid,:),1e-7,'ByRows',true,'DataScale',1);
end

function library = pairLibrary130(points,settings)
count = size(points,1);
[i,j] = find(triu(true(count),1));
first = points(i,:); last = points(j,:); delta = last-first;
radii = vecnorm(delta,2,2)/2;
[radii,order] = sort(radii,'descend');
keep = radii>1e-8; order = order(keep); radii = radii(keep);
first = first(order,:); last = last(order,:); delta = last-first;
library = struct('first',first,'last',last,'middle',(first+last)/2, ...
    'normal',cotd(2*settings.delta)*[-delta(:,2) delta(:,1)],'radius',radii);
end

function [lower,index,kind] = pairBox130(box,library,inherited)
lower = inherited; index = 0; kind = 0;
center = (box(1:2)+box(3:4))/2;
for start = 1:2048:numel(library.radius)
    finish = min(start+2047,numel(library.radius));
    if library.radius(start)<=lower+1e-9
        return
    end
    indices = (start:finish)';
    indices = indices(library.radius(indices)-1e-7>lower);
    if isempty(indices)
        continue
    end
    middle = library.middle(indices,:); normal = library.normal(indices,:);
    delta = center-middle; squared = library.radius(indices).^2;
    possible = sum(delta.^2,2)-squared>=abs(sum(delta.*normal,2))-1e-8;
    indices = indices(possible);
    if isempty(indices)
        continue
    end
    middle = library.middle(indices,:); normal = library.normal(indices,:);
    first = library.first(indices,:); last = library.last(indices,:);
    a = max(box(1:2),min(box(3:4),middle+normal/2))-middle;
    b = max(box(1:2),min(box(3:4),middle-normal/2))-middle;
    fplus = sum(a.^2,2)-library.radius(indices).^2-sum(a.*normal,2);
    fminus = sum(b.^2,2)-library.radius(indices).^2+sum(b.*normal,2);
    firstDistance = vecnorm(first-max(box(1:2),min(box(3:4),first)),2,2);
    lastDistance = vecnorm(last-max(box(1:2),min(box(3:4),last)),2,2);
    valid = fplus>=1e-5 & fminus>=1e-5 & firstDistance>5+1e-7 & lastDistance>5+1e-7;
    hit = find(valid,1);
    if ~isempty(hit)
        index = indices(hit); lower = library.radius(index)-1e-7; kind = 1; return
    end
end
end

function [outside,index] = excludeBox130(box,support,receiveMin)
closest = max(box(1:2),min(box(3:4),support));
values = sum((support-closest).^2,2)-max(receiveMin^2,sum(support.^2,2));
[value,index] = max(values); outside = value>1e-4;
end

function result = branchBounds130(geometry,library,upper,options)
support = [geometry.nodes;library.first(1,:);library.last(1,:)];
radii = sqrt(max(geometry.receiveMin^2,sum(support.^2,2)));
initialBox = [max(support-radii,[],1) min(support+radii,[],1)];
assert(all(initialBox(1:2)<=initialBox(3:4)),'安全覆盖框为空。');
if options.symmetric
    initialBox(2) = max(0,initialBox(2));
end
nodes = zeros(2*options.maxNodes+1,11);
nodes(1,1:4) = initialBox;
[lower,index,kind] = pairBox130(initialBox,library,0);
nodes(1,5:8) = [lower 1 index kind];
count = 1; active = 1; iterations = 0;
trace = zeros(options.maxNodes+1,4); traceCount = 1;
trace(1,:) = [0 lower upper 1];
target = max(options.absoluteGap,options.relativeGap*upper);
started = tic;
while ~isempty(active) && iterations<options.maxNodes
    [globalLower,position] = min(nodes(active,5));
    if upper-globalLower<=target
        break
    end
    parent = active(position); active(position) = [];
    box = nodes(parent,1:4);
    [~,axis] = max(box(3:4)-box(1:2));
    middle = (box(axis)+box(axis+2))/2;
    first = box; first(axis+2) = middle;
    second = box; second(axis) = middle;
    childIds = count+(1:2); nodes(parent,6) = 2; nodes(parent,9:10) = childIds;
    for child = 1:2
        count = count+1;
        current = first; if child==2, current=second; end
        [outside,sourceIndex] = excludeBox130(current,support,geometry.receiveMin);
        inherited = nodes(parent,5);
        if outside
            nodes(count,:) = [current inf 3 sourceIndex 0 0 0 parent];
        else
            [bound,pairIndex,kind] = pairBox130(current,library,inherited);
            assert(bound>=inherited-1e-9,'子盒下界未继承父界。');
            state = 1;
            if bound>=upper
                state = 4;
            end
            nodes(count,:) = [current bound state pairIndex kind 0 0 parent];
            if state==1
                active(end+1) = count;
            end
        end
    end
    iterations = iterations+1;
    if mod(iterations,100)==0
        if isempty(active), globalLower=upper; else, globalLower=min(nodes(active,5)); end
        traceCount = traceCount+1; trace(traceCount,:) = [iterations globalLower upper numel(active)];
    end
    if mod(iterations,1000)==0
        fprintf('连续界节点%d，下界%.8f，上界%.8f，活跃盒%d。\n',iterations,globalLower,upper,numel(active));
    end
end
if isempty(active), globalLower=upper; else, globalLower=min(nodes(active,5)); end
traceCount = traceCount+1; trace(traceCount,:) = [iterations globalLower upper numel(active)];
nodes = nodes(1:count,:);
assert(globalLower<=upper+1e-5,'连续下界超过可行上界。');
result = struct('lower',globalLower,'upper',upper,'gap',upper-globalLower, ...
    'target',target,'targetMet',upper-globalLower<=target,'nodes',nodes,'trace',trace(1:traceCount,:), ...
    'iterations',iterations,'active',active,'initialBox',initialBox,'support',support, ...
    'seconds',toc(started),'coverage','true_safe_domain','symmetryUsed',options.symmetric);
end



function result = verifyResearch130(settings,options,outputRoot)
assert(~isfolder(outputRoot),'输出目录已存在。');
defaults = struct('cases',[1 2 3 4 5 6],'maxNodes',3000,'sourceSamples',17, ...
    'absoluteGap',0.005,'relativeGap',0.01,'angleStep',1,'makeFigures',true, ...
    'adaptiveRounds',2,'adaptiveSeeds',128,'upperCandidates',12);
names = fieldnames(options);
for k = 1:numel(names)
    assert(isfield(defaults,names{k}),'未知研究选项。');
    defaults.(names{k}) = options.(names{k});
end
options = defaults;
validateattributes(options.cases,{'numeric'},{'integer','positive','<=',6,'vector'});
validateattributes(options.maxNodes,{'numeric'},{'scalar','integer','positive'});
validateattributes(options.sourceSamples,{'numeric'},{'scalar','integer','>=',5,'<=',257});
validateattributes(options.adaptiveRounds,{'numeric'},{'scalar','integer','>=',0,'<=',5});
validateattributes(options.adaptiveSeeds,{'numeric'},{'scalar','integer','>=',1,'<=',512});
validateattributes(options.upperCandidates,{'numeric'},{'scalar','integer','>=',0,'<=',64});
validateattributes(options.absoluteGap,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(options.relativeGap,{'numeric'},{'scalar','real','finite','positive','<',1});
validateattributes(options.angleStep,{'numeric'},{'scalar','real','finite','positive','<=',10});
base = fileparts(mfilename('fullpath'));
priorFile = fullfile(base,'既有结果_v1.1.1','完整结果.mat');
if ~isfile(priorFile)
    priorFile = fullfile(base,'论文素材包','v1.1.1','运行结果','20260911_093333_770','完整结果.mat');
end
loaded = load(priorFile,'result'); prior = loaded.result;
mkdir(outputRoot); started = tic;
fprintf('研究10/12/11，MATLAB %s，版本%s。\n',version,settings.version);
checks = geometryChecks130(settings);
writetable(checks,fullfile(outputRoot,'初始必要验证.csv'),'Encoding','UTF-8');
assert(all(checks.Passed),'初始几何与解析检查失败。');
details = cell(numel(options.cases),1); rows = cell(numel(options.cases),1);
for j = 1:numel(options.cases)
    caseIndex = options.cases(j); item = prior.cases{caseIndex};
    fprintf('场景%d %s：构造真实域。\n',caseIndex,item.name);
    geometry = sourceGeometry130(item.sourceCenter,settings);
    config = settings; config.circleSides = 5760; config.scoreTolerance = 0.002; config.maxSplits = 2200;
    config.scoreContext = newScoreContext34(true);
    [outer,inner] = initialRegion(item.sourceCenter,config); oldDomain = receiveDomain(outer,config);
    angles = (-180:options.angleStep:180)';
    [trueLower,trueUpper] = exactLimits130(angles,geometry);
    oldLimits = domainLimit(angles,oldDomain,config);
    safeGap = trueUpper-oldLimits;
    domainTable = table(angles,oldLimits,trueLower,trueUpper,safeGap, ...
        'VariableNames',{'AngleDeg','PolygonDomainRadius','TrueRadiusLower','TrueRadiusUpper','RadialGapUpper'});
    writetable(domainTable,fullfile(outputRoot,sprintf('10_场景%d_域边界.csv',caseIndex)),'Encoding','UTF-8');
    trueViolation = exactSafe130(item.point,geometry);
    localOptions = options;
    fullSector = sectorContained130(item.sourceCenter,settings);
    localOptions.symmetric = abs(item.sourceCenter(2))<1e-10 || fullSector;
    sample = sourceSamples130(geometry,options.sourceSamples,settings);
    if item.final.feedback=="direction"
        posterior = clipWedge(inner,item.point,item.final.angle,settings.delta);
        extra = feasibleSupport(posterior,[0 0;item.point],settings.nearRadius);
        sample = [sample;extra];
    end
    valid = constraintViolation12(geometry,sample)<=1e-7 & vecnorm(sample,2,2)>settings.nearRadius+1e-7;
    sample = uniquetol(sample(valid,:),1e-7,'ByRows',true,'DataScale',1);
    fprintf('合法源样本%d；构造连续源对证书。\n',size(sample,1));
    library = pairLibrary130(sample,settings);
    bound = branchBounds130(geometry,library,item.final.upper,localOptions);
    refinement = [0 numel(library.radius) bound.lower bound.upper bound.iterations bound.seconds];
    for round = 1:options.adaptiveRounds
        if bound.targetMet,break,end
        library = enrichPairs130(geometry,sample,library,bound,options,settings);
        bound = branchBounds130(geometry,library,item.final.upper,localOptions);
        refinement(end+1,:) = [round numel(library.radius) bound.lower bound.upper bound.iterations bound.seconds];
    end
    feasiblePoint = item.point; feasibleScore = item.final; upperTrials = zeros(0,6);
    if ~bound.targetMet && options.upperCandidates>0
        [feasiblePoint,feasibleScore,upperTrials] = refineUpper130(item,geometry,bound,outer,inner,config,options);
        if feasibleScore.upper<bound.upper
            bound = branchBounds130(geometry,library,feasibleScore.upper,localOptions);
            refinement(end+1,:) = [99 numel(library.radius) bound.lower bound.upper bound.iterations bound.seconds];
        end
    end
    sample = uniquetol([sample;library.first;library.last],1e-7,'ByRows',true,'DataScale',1);
    fprintf('场景%d连续下界%.8f，上界%.8f，差距%.8f，分支%d。\n',caseIndex,bound.lower,bound.upper,bound.gap,bound.iterations);
    treeChecks = validateTree130(bound,library,geometry,caseIndex);
    checks = [checks;treeChecks];
    contraction = domainDistance130(geometry,5760,settings);
    label = "10连续收缩证书条件"+caseIndex;
    checks = [checks;table(label,contraction.supported,contraction.commonRadiusResidual, ...
        'VariableNames',{'Check','Passed','Residual'})];
    label = "10旧推荐点真实连续接收"+caseIndex;
    checks = [checks;table(label,trueViolation<=1e-4,trueViolation,'VariableNames',{'Check','Passed','Residual'})];
    label = "11可行上界点真实安全"+caseIndex;
    violation = exactSafe130(feasiblePoint,geometry);
    checks = [checks;table(label,violation<=1e-4,violation,'VariableNames',{'Check','Passed','Residual'})];
    label = "10旧域方向包含"+caseIndex;
    residual = max(oldLimits-trueUpper);
    checks = [checks;table(label,residual<=2e-5,residual,'VariableNames',{'Check','Passed','Residual'})];
    label = "11全部源见证真实合法"+caseIndex;
    allSources = [library.first;library.last];
    residual = max(constraintViolation12(geometry,allSources));
    validSources = residual<=1e-7 && all(vecnorm(allSources,2,2)>settings.nearRadius+1e-7);
    checks = [checks;table(label,validSources,residual,'VariableNames',{'Check','Passed','Residual'})];
    directions = [cosd(angles) sind(angles)];
    detail = struct('name',item.name,'caseIndex',caseIndex,'geometry',geometry,'domainTable',domainTable, ...
        'trueBoundary',directions.*trueLower,'oldBoundary',directions.*oldLimits, ...
        'sourceSamples',sample,'pairLibrary',library,'bound',bound,'oldPoint',item.point, ...
        'oldScore',item.final,'fullSector',fullSector,'symmetry',localOptions.symmetric, ...
        'contraction',contraction,'refinement',refinement,'feasiblePoint',feasiblePoint, ...
        'feasibleScore',feasibleScore,'upperTrials',upperTrials);
    details{j} = detail;
    angularAllowance = (3000+3000/cos(pi/5760))*(options.angleStep*pi/180)/2;
    rows{j} = table(string(item.name),caseIndex,fullSector,localOptions.symmetric,size(sample,1), ...
        numel(library.radius),max(safeGap),max(safeGap)+angularAllowance,contraction.hausdorffBound,trueViolation, ...
        bound.lower,bound.upper,bound.gap,100*bound.gap/bound.upper,bound.targetMet,bound.iterations,bound.seconds, ...
        feasiblePoint(1),feasiblePoint(2), ...
        'VariableNames',{'Case','CaseIndex','FullSectorEquivalent','ReflectionUsed','LegalSources','SourcePairs', ...
        'SampledRadialGapUpper','AllDirectionsRadialGapUpper','ContinuousHausdorffUpper','OldPointTrueViolationM2', ...
        'GlobalLower','FeasibleUpper','AbsoluteGap','GapOverUpperPercent','TargetMet','Splits','BranchSeconds','FeasibleX','FeasibleY'});
    writetable(array2table(bound.nodes,'VariableNames',{'XLow','YLow','XHigh','YHigh','Lower','State', ...
        'WitnessIndex','WitnessKind','Child1','Child2','Parent'}), ...
        fullfile(outputRoot,sprintf('11_场景%d_覆盖树.csv',caseIndex)),'Encoding','UTF-8');
    writetable(array2table(bound.trace,'VariableNames',{'Splits','GlobalLower','FeasibleUpper','ActiveLeaves'}), ...
        fullfile(outputRoot,sprintf('11_场景%d_收敛轨迹.csv',caseIndex)),'Encoding','UTF-8');
    writetable(array2table(sample,'VariableNames',{'X','Y'}), ...
        fullfile(outputRoot,sprintf('11_场景%d_合法源样本.csv',caseIndex)),'Encoding','UTF-8');
    writetable(array2table(refinement,'VariableNames',{'Round','Pairs','GlobalLower','FeasibleUpper','Splits','Seconds'}), ...
        fullfile(outputRoot,sprintf('11_场景%d_见证加密.csv',caseIndex)),'Encoding','UTF-8');
    writetable(array2table(upperTrials,'VariableNames',{'X','Y','TrueSafeViolationM2','ScoreLower','ScoreUpper','OldDomainRadiusSlack'}), ...
        fullfile(outputRoot,sprintf('10_11_场景%d_可行点复查.csv',caseIndex)),'Encoding','UTF-8');
end
summary = vertcat(rows{:});
writetable(summary,fullfile(outputRoot,'10_12_11_结果总表.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputRoot,'必要验证.csv'),'Encoding','UTF-8');
status = 'FAIL'; if all(checks.Passed),status='SELF_CHECKED';end
result = struct('version',settings.version,'matlabVersion',version,'settings',settings,'options',options, ...
    'summary',summary,'checks',checks,'details',{details},'status',status,'elapsedSeconds',toc(started));
if options.makeFigures
    figures130(result,outputRoot);
end
result.elapsedSeconds = toc(started);
save(fullfile(outputRoot,'研究完整结果.mat'),'result','-v7.3');
fprintf('研究检查%d项，失败%d项，%.3f秒。\n',height(checks),sum(~checks.Passed),result.elapsedSeconds);
assert(all(checks.Passed),'研究检查存在失败。');
end

function library = enrichPairs130(geometry,sample,library,bound,options,settings)
active = bound.active;
[~,order] = sort(bound.nodes(active,5)); active = active(order);
pool = active(1:max(1,ceil(numel(active)/2)));
chosen = unique(round(linspace(1,numel(pool),min(options.adaptiveSeeds,numel(pool)))));
boxes = bound.nodes(pool(chosen),1:4); centers = (boxes(:,1:2)+boxes(:,3:4))/2;
anchors = [geometry.nodes;sample(unique(round(linspace(1,size(sample,1),min(64,size(sample,1))))),:)];
valid = constraintViolation12(geometry,anchors)<=1e-7 & vecnorm(anchors,2,2)>settings.nearRadius+1e-7;
anchors = uniquetol(anchors(valid,:),1e-7,'ByRows',true,'DataScale',1);
extra = zeros(0,4);
for k = 1:size(centers,1)
    point = centers(k,:);
    for j = 1:size(anchors,1)
        anchor = anchors(j,:); offset = anchor-point;
        if norm(offset)<=settings.nearRadius+1e-7,continue,end
        for angle = [-1 1].*(2*settings.delta-[0.005;0.00005])
            for turn = angle'
                rotation = [cosd(turn) -sind(turn);sind(turn) cosd(turn)];
                direction = (rotation*offset')'/norm(offset);
                parameters = zeros(0,1);
                for c = 1:size(geometry.circles,1)
                    circle = geometry.circles(c,:); difference = point-circle(1:2);
                    projection = dot(difference,direction);
                    discriminant = projection^2-sum(difference.^2)+circle(3)^2;
                    if discriminant>=0
                        parameters = [parameters;-projection-sqrt(discriminant);-projection+sqrt(discriminant)];
                    end
                end
                denominator = geometry.normals*direction';
                validLine = abs(denominator)>1e-12;
                parameters = [parameters;(geometry.bounds(validLine)-geometry.normals(validLine,:)*point')./denominator(validLine)];
                candidates = point+parameters(parameters>settings.nearRadius+1e-7)*direction;
                valid = constraintViolation12(geometry,candidates)<=1e-7 & vecnorm(candidates,2,2)>settings.nearRadius+1e-7;
                candidates = candidates(valid,:);
                extra = [extra;repmat(anchor,size(candidates,1),1) candidates];
            end
        end
    end
end

extra = uniquetol(extra,1e-8,'ByRows',true,'DataScale',1);
first = [library.first;extra(:,1:2)]; last = [library.last;extra(:,3:4)]; delta = last-first;
radii = vecnorm(delta,2,2)/2; [radii,order] = sort(radii,'descend');
keep = radii>1e-8; order = order(keep); radii = radii(keep);
first = first(order,:); last = last(order,:); delta = last-first;
library = struct('first',first,'last',last,'middle',(first+last)/2, ...
    'normal',cotd(2*settings.delta)*[-delta(:,2) delta(:,1)],'radius',radii);
fprintf('解析加密新增源对%d，总见证%d。\n',size(extra,1),numel(library.radius));
end

function [point,score,trials] = refineUpper130(item,geometry,bound,outer,inner,config,options)
point = item.point; score = item.final; trials = zeros(0,6);
[~,order] = sort(bound.nodes(bound.active,5));
active = bound.active(order); active = active(1:max(1,ceil(numel(active)/2)));
indices = unique(round(linspace(1,numel(active),min(options.upperCandidates,numel(active)))));
boxes = bound.nodes(active(indices),1:4); candidates = (boxes(:,1:2)+boxes(:,3:4))/2;
domain = receiveDomain(outer,config);
for k = 1:size(candidates,1)
    candidate = candidates(k,:); length = norm(candidate);
    if length<1e-6,continue,end
    angle = atan2d(candidate(2),candidate(1));
    [limit,~] = exactLimits130(angle,geometry);
    candidate = candidate/length*min(length,max(0,limit-1e-5));
    if norm(candidate)<1e-6,continue,end
    violation = exactSafe130(candidate,geometry);
    if violation>0,continue,end
    evaluated = scorePoint(candidate,outer,inner,config);
    slack = domainLimit(atan2d(candidate(2),candidate(1)),domain,config)-norm(candidate);
    trials(end+1,:) = [candidate violation evaluated.lower evaluated.upper slack];
    if evaluated.upper<score.upper,point=candidate;score=evaluated;end
end
fprintf('补查可行点%d，最佳可行上界%.8f。\n',size(trials,1),score.upper);
end

function contained = sectorContained130(center,settings)
projections = center*[cosd(settings.delta) cosd(settings.delta);-sind(settings.delta) sind(settings.delta)];
minimum = min(projections);
if norm(center)>0
    opposite = atan2d(-center(2),-center(1));
    if abs(opposite)<=settings.delta
        minimum = -norm(center);
    end
end
distanceSquared = [settings.nearRadius;settings.receiveMax].^2+sum(center.^2)- ...
    2*[settings.nearRadius;settings.receiveMax]*minimum;
contained = max(distanceSquared)<=settings.sourceRadius^2;
end

function checks = geometryChecks130(settings)
labels = strings(0,1); passed = false(0,1); residuals = zeros(0,1);
geometry = sourceGeometry130([0 0],settings);
record("10原点安全",exactSafe130([0 0],geometry)==0,exactSafe130([0 0],geometry));
[lower,upper] = exactLimits130([0;180],geometry);
expected = 5*cosd(settings.delta)+sqrt(1000^2-25*sind(settings.delta)^2);
record("10中心前向四圆盘解析",lower(1)<=expected+1e-7 && upper(1)>=expected-1e-7,upper(1)-expected);
record("10中心后向无正位移",upper(2)<1e-6,upper(2));
record("12中心完整扇区",sectorContained130([0 0],settings),0);
record("12朝内完整扇区",sectorContained130([1750 0],settings),0);
record("12朝外发生截断",~sectorContained130([-1750 0],settings),0);
for p = [700 300;900 100;100 700;1300 400]'
    a = exactSafe130(p',geometry); b = exactSafe130(p'.*[1 -1],geometry);
    record("12安全域镜像"+numel(passed),abs(a-b)<1e-6,a-b);
end
beta = 0.5; alpha = -0.5;
distance = -5*cosd(beta)+sqrt(1800^2-25*sind(beta)^2);
center = -distance*[cosd(alpha) sind(alpha)];
special = sourceGeometry130(center,settings);
isolated = 5*[cosd(-1) sind(-1)];
remaining = min(vecnorm(special.nodes-isolated,2,2));
record("10删除5米孤立伪源",remaining>1e-3,remaining);
record("10保留5米合法极限端点",min(vecnorm(special.nodes-[5 0],2,2))<1e-5, ...
    min(vecnorm(special.nodes-[5 0],2,2)));
sample = sourceSamples130(special,9,settings);
record("10孤立接触例仍有合法首测",~isempty(sample),size(sample,1));
pair = pairLibrary130([100 0;102 0],settings);
[lo,~,~] = pairBox130([-1 -1 1 1],pair,0);
record("11整盒共同方向已知例",abs(lo-1)<1e-5,lo-1);
[lo,~,~] = pairBox130([99 -1 103 1],pair,0);
record("11近源非法方向排除",lo==0,lo);
blocked = false;
try
    sourceGeometry130([-5000 0],settings);
catch
    blocked = true;
end
record("10不相容首测拒绝",blocked,double(~blocked));
certificate = domainDistance130(geometry,5760,settings);
record("10中心连续域差证书",certificate.supported && certificate.hausdorffBound<0.01,certificate.hausdorffBound);
angles = (-180:3:180)';
[radial,~] = exactLimits130(angles,geometry);
truePoints = radial.*[cosd(angles) sind(angles)];
contracted = (1-certificate.fraction)*truePoints+certificate.fraction*[500 0];
config = settings; config.circleSides = 5760;
[outer,~] = initialRegion([0 0],config); domain = receiveDomain(outer,config);
allowance = domainLimit(atan2d(contracted(:,2),contracted(:,1)),domain,config);
residual = max(vecnorm(contracted,2,2)-allowance);
record("10收缩点外包域独立复查",residual<1e-6,residual);
dense = sourceSamples130(geometry,257,settings);
for p = [800 200;1000 20;200 900]'
    exact = exactSafe130(p',geometry);
    sampled = max(sum((dense-p').^2,2)-max(1000^2,sum(dense.^2,2)));
    record("10连续极值不小于密集见证"+numel(passed),exact>=sampled-1e-6,exact-sampled);
end
testPoints = [0 0;2 0;1 sqrt(3)];
[center,radius] = enclosingCircle(testPoints);
rotation = [cosd(37) -sind(37);sind(37) cosd(37)];
translation = [123 -456];
[changedCenter,changedRadius] = enclosingCircle(testPoints*rotation+translation);
residual = max(abs([changedCenter-center*rotation-translation changedRadius-radius]));
record("12包围圆刚体等变",residual<1e-9,residual);
record("12锐角三点支撑已知解",abs(radius-2/sqrt(3))<1e-10,radius-2/sqrt(3));
[center,radius] = enclosingCircle([0 0;4 0;1 0.1]);
record("12钝角三点归为直径支撑",norm(center-[2 0])<1e-10 && abs(radius-2)<1e-10,radius-2);
point = 1000*[cosd(-35) sind(-35)];
[first,last,valid] = analyticPair130(point,settings);
angle = acosd(max(-1,min(1,dot(first-point,last-point)/(norm(first-point)*norm(last-point)))));
record("12双源分支相容角解析",valid && abs(angle-2*settings.delta)<1e-8,angle-2*settings.delta);
record("12双源分支合法首测",valid && all(vecnorm([first;last],2,2)>5),norm(first));
single = sourceGeometry130([3300 0],settings);
record("10保留大于5米合法孤源",size(single.nodes,1)==1 && norm(single.nodes-[1500 0])<1e-5, ...
    min(vecnorm(single.nodes-[1500 0],2,2)));
unsupported = domainDistance130(single,5760,settings);
record("10共同半径不足不误用收缩界",~unsupported.supported && isinf(unsupported.hausdorffBound), ...
    double(unsupported.supported));
testAngles = [-90 -89 -60 -1 1 60 89 90]';
[lower,upper] = exactLimits130(testAngles,geometry);
corners = [5*cosd(1) -5*sind(1);5*cosd(1) 5*sind(1);1000*cosd(1) -1000*sind(1);1000*cosd(1) 1000*sind(1)];
projection = corners*[cosd(testAngles) sind(testAngles)]';
roots = projection+sqrt(max(0,projection.^2+1000^2-sum(corners.^2,2)));
expected = min(roots,[],1)';
residual = max([lower-expected;expected-upper]);
record("10四圆盘斜向切换解析",residual<1e-6,residual);
checks = table(labels,passed,residuals,'VariableNames',{'Check','Passed','Residual'});
    function record(label,ok,residual)
        labels(end+1,1)=label;passed(end+1,1)=ok;residuals(end+1,1)=residual;
    end
end

function figures130(result,outputRoot)
blue = [0.10 0.34 0.62]; orange = [0.85 0.43 0.10]; font = 'Microsoft YaHei';
count = numel(result.details); columns = min(3,count); rows = ceil(count/columns);
first = figure('Visible','off','Color','w','Position',[80 80 1200 390*rows]);
layout = tiledlayout(first,rows,columns,'TileSpacing','compact','Padding','compact');
for k = 1:count
    item = result.details{k}; ax = nexttile(layout);
    plot(ax,item.trueBoundary(:,1),item.trueBoundary(:,2),'-','Color',blue,'LineWidth',2);
    hold(ax,'on');plot(ax,item.oldBoundary(:,1),item.oldBoundary(:,2),'--','Color',orange,'LineWidth',1.3);
    plot(ax,item.feasiblePoint(1),item.feasiblePoint(2),'kp','MarkerFaceColor','w','MarkerSize',10);
    plot(ax,0,0,'k+','MarkerSize',7);axis(ax,'equal');grid(ax,'on');
    title(ax,sprintf('%s：连续域差 ≤ %.2f mm',item.name,ceil(1e5*item.contraction.hausdorffBound)/100));
    xlabel(ax,'前进位移（m）');ylabel(ax,'侧向位移（m）');
    legend(ax,{'真实域数值边界','旧外包模型安全域','上界见证点','首测点'}, ...
        'Location','southoutside','NumColumns',2,'FontSize',8);
end
title(layout,'构造场景：边界按方向绘制；标题为连续Hausdorff界，非风险误差','FontName',font,'FontSize',12);
set(findall(first,'Type','axes'),'FontName',font,'FontSize',10,'Box','on');
exportFigure(first,fullfile(outputRoot,'图10_真实域与连续域差'));
second = figure('Visible','off','Color','w','Position',[80 80 1200 370*rows]);
layout = tiledlayout(second,rows,columns,'TileSpacing','compact','Padding','compact');
for k = 1:count
    item = result.details{k}; ax = nexttile(layout); trace = item.bound.trace;
    stairs(ax,trace(:,1),trace(:,2),'-','Color',blue,'LineWidth',1.7);hold(ax,'on');
    yline(ax,item.bound.upper,'--','Color',orange,'LineWidth',1.5);
    title(ax,sprintf('%s：L=%.4f，U=%.4f m',item.name,item.bound.lower,item.bound.upper));
    xlabel(ax,'最终见证库的连续二分次数');ylabel(ax,'最坏定位半径（m）');grid(ax,'on');
    ylim(ax,[0 item.bound.upper*1.18]);
    legend(ax,{'连续全域下界','可行策略上界'},'Location','southeast','FontSize',8);
end
title(layout,'统一保接收策略：真实连续域上的界限；未闭合差距如实保留','FontName',font,'FontSize',12);
set(findall(second,'Type','axes'),'FontName',font,'FontSize',10,'Box','on');
exportFigure(second,fullfile(outputRoot,'图11_连续全域上下界'));
end

function result = domainDistance130(geometry,sides,settings)
center = geometry.sourceCenter; delta = settings.delta;
projections = center*[cosd(delta) cosd(delta);-sind(delta) sind(delta)];
for angle = [atan2d(center(2),center(1)) atan2d(-center(2),-center(1))]
    if abs(angle)<=delta
        projections(end+1) = dot(center,[cosd(angle) sind(angle)]);
    end
end
minimum = min(projections); maximum = max(projections);
minSquare = min(projections.^2);
if minimum<=0 && maximum>=0,minSquare=0;end
discriminant = settings.sourceRadius^2-sum(center.^2)+minSquare;
middleDiscriminant = settings.sourceRadius^2-center(2)^2;
commonRadius = NaN; commonResidual = inf;
if middleDiscriminant>=0
    lo = max(settings.nearRadius,center(1)-sqrt(middleDiscriminant));
    hi = min(settings.receiveMax,center(1)+sqrt(middleDiscriminant));
    commonRadius = (lo+hi)/2;
    commonResidual = commonRadius^2+sum(center.^2)-2*commonRadius*minimum-settings.sourceRadius^2;
end
supported = discriminant>0 && commonRadius>settings.nearRadius && ...
    commonRadius<settings.receiveMax && commonResidual<0;
distance = inf; fraction = NaN; bound = inf;
margin = settings.receiveMin-sqrt(settings.receiveMin^2+500^2-2*settings.receiveMin*500*cosd(delta));
sourceBound = min(sqrt(max(settings.receiveMin^2,sum(geometry.nodes.^2,2)))+ ...
    vecnorm(geometry.nodes-[500 0],2,2));
if supported
    axisRadius = max(lo,min(hi,500));
    sourceBound = min(sourceBound,max(settings.receiveMin,axisRadius)+abs(axisRadius-500));
    increment = settings.sourceRadius^2*tan(pi/sides)^2;
    circleShift = increment/(sqrt(discriminant+increment)+sqrt(discriminant));
    distance = max([settings.nearRadius*(1-cosd(delta)), ...
        settings.receiveMax*(1/cos(pi/sides)-1),circleShift]);
    fraction = 2*distance/(margin+2*distance);
    bound = fraction*sourceBound;
end
result = struct('supported',supported,'commonRadius',commonRadius,'commonRadiusResidual',commonResidual, ...
    'minimumDiscriminant',discriminant,'sourceHausdorffUpper',distance,'interiorMargin',margin, ...
    'fraction',fraction,'pointDistanceUpper',sourceBound,'hausdorffBound',bound,'circleSides',sides);
end

function [first,last,valid] = analyticPair130(point,settings)
length = norm(point); phi = atan2d(point(2),point(1)); delta = settings.delta; limit = settings.receiveMax;
denominator = limit*sind(4*delta)-length*sind(phi+3*delta);
radius = (limit*length*sind(3*delta-phi)-length^2*sind(2*delta))/denominator;
first = radius*[cosd(-delta) sind(-delta)]; last = limit*[cosd(delta) sind(delta)];
rotation = [cosd(2*delta) -sind(2*delta);sind(2*delta) cosd(2*delta)];
turned = (rotation*(last-point)')';
scale = dot(first-point,turned)/sum(turned.^2);
valid = abs(denominator)>1e-10 && phi<-delta && radius>settings.nearRadius && ...
    radius<=limit && scale>0 && min(vecnorm([first;last]-point,2,2))>settings.nearRadius;
end

function checks = validateTree130(result,library,geometry,caseIndex)
tree = result.nodes; coverage = true; bounds = true; excluded = true;
for k = 1:size(tree,1)
    box = tree(k,1:4);
    if tree(k,6)==2
        ids = tree(k,9:10);
        first = tree(ids(1),1:4); last = tree(ids(2),1:4);
        axis = find(first(3:4)~=box(3:4));
        ok = isscalar(axis) && all(first(1:2)==box(1:2)) && all(last(3:4)==box(3:4));
        if ok
            other = 3-axis;
            ok = first(axis+2)==last(axis) && first(other+2)==box(other+2) && last(other)==box(other);
        end
        coverage = coverage && ok && all(tree(ids,11)==k);
    elseif tree(k,6)==3
        [ok,~] = excludeBox130(box,result.support,geometry.receiveMin);
        excluded = excluded && ok;
    end
    if tree(k,6)~=3
        inherited = 0;
        if tree(k,11)>0, inherited=tree(tree(k,11),5);end
        if tree(k,7)>0
            index = tree(k,7);
            first = library.first(index,:); last = library.last(index,:);
            normal = library.normal(index,:); middle = (first+last)/2;
            circleCenters = [middle+normal/2;middle-normal/2];
            circleRadiusSquared = library.radius(index)^2+sum(normal.^2)/4;
            closest = max(box(1:2),min(box(3:4),circleCenters));
            circleResidual = sum((closest-circleCenters).^2,2)-circleRadiusSquared;
            sources = [first;last]; nearest = max(box(1:2),min(box(3:4),sources));
            valid = all(circleResidual>=-1e-3) && all(vecnorm(sources-nearest,2,2)>5);
            bounds = bounds && valid && tree(k,5)<=max(inherited,library.radius(index))+1e-8;
        else
            bounds = bounds && tree(k,5)<=inherited+1e-8;
        end
    end
end
active = find(tree(:,6)==1);
activeMatch = isequal(sort(active(:)),sort(result.active(:)));
pruned = all(tree(tree(:,6)==4,5)>=result.upper);
expectedLower = result.upper;
if ~isempty(active),expectedLower=min(expectedLower,min(tree(active,5)));end
finalMatch = abs(expectedLower-result.lower)<1e-8;
radii = sqrt(max(geometry.receiveMin^2,sum(result.support.^2,2)));
box = [max(result.support-radii,[],1) min(result.support+radii,[],1)];
if result.symmetryUsed,box(2)=max(0,box(2));end
rootMatch = isequal(box,result.initialBox) && isequal(tree(1,1:4),box);
states = all(ismember(tree(:,6),[1 2 3 4]));
flags = [coverage;excluded;bounds;activeMatch;pruned;finalMatch;rootMatch;states];
labels = ["11覆盖树连续分割";"11排空证书逐叶复查";"11两圆独立公式复查";"11活跃叶完整"; ...
    "11上界剪枝合法";"11最终连续下界一致";"11根框覆盖真实域";"11节点状态完整"]+caseIndex;
checks = table(labels,flags,double(~flags), ...
    'VariableNames',{'Check','Passed','Residual'});
end


function result = verifyResearch140(settings,options,outputRoot)
defaults = struct('stage','06','resume',true,'makeFigures',true,'maxCases',inf);
names = fieldnames(options);
for k = 1:numel(names)
    assert(isfield(defaults,names{k}),'Unknown research option.');
    defaults.(names{k}) = options.(names{k});
end
options = defaults;
assert(isscalar(string(options.stage)) && any(string(options.stage)==["06" "08" "09"]),'Invalid stage.');
validateattributes(options.resume,{'logical'},{'scalar'});
validateattributes(options.makeFigures,{'logical'},{'scalar'});
validateattributes(options.maxCases,{'numeric'},{'real','scalar','positive'});
assert(isinf(options.maxCases) || options.maxCases==floor(options.maxCases),'maxCases must be an integer.');
stage = char(string(options.stage));
settings.budgets = [400 1000];
plan = plan140(stage);
sourceText = fileread([mfilename('fullpath') '.m']);
identity = struct('stage',stage,'version','1.4.0','settings',settings,'plan',plan,'sourceText',sourceText);
manifestFile = fullfile(outputRoot,'manifest.mat');
if isfolder(outputRoot)
    assert(options.resume && isfile(manifestFile),'Existing output is not a resumable research folder.');
    loaded = load(manifestFile,'identity');
    assert(isequaln(identity,loaded.identity),'Source, settings or plan changed: use a new output folder.');
else
    mkdir(outputRoot);
    save(manifestFile,'identity');
end
started = tic;
status140(outputRoot,'RUNNING',stage,0,numel(plan),'Starting or resuming.');
try
    initialFile = fullfile(outputRoot,'initial_checks.mat');
    if isfile(initialFile)
        loaded = load(initialFile,'checks');
        initialChecks = loaded.checks;
    else
        checks = boundaryChecks140(settings);
        save(initialFile,'checks');
        writetable(checks,fullfile(outputRoot,'initial_checks.csv'),'Encoding','UTF-8');
        initialChecks = checks;
    end
    assert(all(initialChecks.Passed),'Boundary checks failed.');
    details = cell(numel(plan),1);
    newlyRun = 0;
    for k = 1:numel(plan)
        caseFile = fullfile(outputRoot,sprintf('case_%02d.mat',k));
        if isfile(caseFile)
            loaded = load(caseFile,'detail');
            assert(isequaln(loaded.detail.spec,plan(k)),'Checkpoint plan mismatch.');
            details{k} = loaded.detail;
        elseif newlyRun<options.maxCases
            fprintf('Stage %s case %d/%d: %s\n',stage,k,numel(plan),plan(k).name);
            status140(outputRoot,'RUNNING',stage,k-1,numel(plan),char(plan(k).name));
            config = settings;
            config.delta = plan(k).delta;
            if strcmp(stage,'09')
                if plan(k).quota>0
                    detail = matching140(plan(k),config);
                else
                    detail = ablation140(plan(k),config);
                end
            else
                item = solveCase(plan(k).firstPoint,plan(k).bearing,plan(k).name,config);
                [coarseOuter,coarseInner] = initialRegion(item.sourceCenter,config);
                coarseStarted = tic;
                coarse = scorePoint(item.point,coarseOuter,coarseInner,config);
                coarseSeconds = toc(coarseStarted);
                detail = struct('spec',plan(k),'item',item,'checks',caseChecks140(item,config), ...
                    'row',row140(plan(k),item,coarse.lower,coarse.upper,item.performance.solveSeconds), ...
                    'selectedCoarseScore',coarse,'coarseAuditSeconds',coarseSeconds,'finalScoring',[5760 0.002 2200]);
                detail.row.CoarseAuditSeconds = coarseSeconds;
                detail.row.StartCount = NaN;
                detail.row.RefinedCandidateCount = item.contenderCount;
            end
            details{k} = detail;
            save(caseFile,'detail');
            writetable(detail.row,fullfile(outputRoot,sprintf('case_%02d.csv',k)),'Encoding','UTF-8');
            writetable(detail.checks,fullfile(outputRoot,sprintf('case_%02d_checks.csv',k)),'Encoding','UTF-8');
            newlyRun = newlyRun+1;
        end
        if ~isempty(details{k})
            assert(all(details{k}.checks.Passed),'Case checks failed: %s',plan(k).name);
        end
        result = collect140(stage,settings,plan,details,initialChecks,toc(started));
        save(fullfile(outputRoot,'checkpoint.mat'),'result');
        writetable(result.summary,fullfile(outputRoot,'summary.csv'),'Encoding','UTF-8');
        if strcmp(stage,'09') && ~isempty(result.matchingSummary)
            writetable(result.matchingSummary,fullfile(outputRoot,'matching_summary.csv'),'Encoding','UTF-8');
        end
        writetable(result.checks,fullfile(outputRoot,'checks.csv'),'Encoding','UTF-8');
    end
    completed = sum(~cellfun(@isempty,details));
    if completed<numel(plan)
        result.status = 'RUNNING';
        status140(outputRoot,'RUNNING',stage,completed,numel(plan),'Stopped at maxCases; resume to continue.');
        save(fullfile(outputRoot,'checkpoint.mat'),'result');
        return
    end
    if strcmp(stage,'06')
        [result.symmetry,extraChecks] = symmetry140(details,settings);
        result.checks = [result.checks;extraChecks];
        writetable(result.symmetry,fullfile(outputRoot,'symmetry.csv'),'Encoding','UTF-8');
    elseif strcmp(stage,'08')
        result.sensitivity = sensitivity140(details);
        writetable(result.sensitivity,fullfile(outputRoot,'sensitivity.csv'),'Encoding','UTF-8');
    else
        result.comparisons = comparisons140(details(1:20));
        result.matchingComparisons = matchingComparisons140(details(21:28));
        writetable(result.matchingComparisons,fullfile(outputRoot,'matching_comparisons.csv'),'Encoding','UTF-8');
        for k = 1:5:20
            initialK = details{k}.gridPoints;
            initialC = details{k+1}.gridPoints;
            nested = isequaln(initialK,initialC(safePoints(initialC,settings),:));
            result.checks = [result.checks;check140(details{k}.spec.name+"_nested identical coordinate grid",nested,double(~nested))];
        end
        for k = 5:5:20
            sameSearch = isequaln(details{k}.item.points,details{k-1}.item.points) ...
                && isequaln(details{k}.coarseScores,details{k-1}.coarseScores);
            result.checks = [result.checks;check140(details{k}.spec.name+"_only reranking changed",sameSearch,double(~sameSearch))];
        end
        writetable(result.comparisons,fullfile(outputRoot,'comparisons.csv'),'Encoding','UTF-8');
    end
    result.status = 'SELF_CHECKED';
    result.elapsedSeconds = toc(started);
    if ~all(result.checks.Passed)
        result.status = 'FAIL';
    end
    save(fullfile(outputRoot,'result.mat'),'result');
    writetable(result.checks,fullfile(outputRoot,'checks.csv'),'Encoding','UTF-8');
    assert(all(result.checks.Passed),'Research checks failed.');
    if options.makeFigures
        figure140(result,outputRoot);
    end
    status140(outputRoot,'SELF_CHECKED',stage,completed,numel(plan),'Computational checks complete; visual and human review pending.');
    fprintf('Stage %s SELF_CHECKED: %d checks, 0 failures.\n',stage,height(result.checks));
catch exception
    completed = 0;
    if exist('details','var')
        completed = sum(~cellfun(@isempty,details));
    end
    if exist('result','var')
        result.status = 'FAIL';
        result.failureMessage = exception.message;
        save(fullfile(outputRoot,'result.mat'),'result');
        save(fullfile(outputRoot,'checkpoint.mat'),'result');
    end
    status140(outputRoot,'FAIL',stage,completed,numel(plan),exception.message);
    rethrow(exception)
end
end

function plan = plan140(stage)
base = struct('name',"",'firstPoint',[1200 800],'bearing',25,'delta',1, ...
    'budget',inf,'domain',"C(P+)",'seeds',3,'steps',[25 8 2 0.5 0.1], ...
    'rerank',false,'factor',"input",'geometry',1,'method',0,'quota',0);
if strcmp(stage,'06')
    plan = repmat(base,4,1);
    plan(1).name = "Nonaxis base";
    angle = 334.6;
    rotation = [cosd(angle) -sind(angle);sind(angle) cosd(angle)];
    plan(2).name = "Rotated across zero";
    plan(2).firstPoint = base.firstPoint*rotation';
    plan(2).bearing = mod(base.bearing+angle,360);
    plan(3).name = "Mirrored input";
    plan(3).firstPoint = base.firstPoint.*[1 -1];
    plan(3).bearing = mod(-base.bearing,360);
    plan(4).name = "Exterior nonaxis";
    plan(4).firstPoint = [2300 500];
    plan(4).bearing = 200;
elseif strcmp(stage,'08')
    plan = repmat(base,7,1);
    plan(1).name = "Baseline delta 1";
    plan(2).name = "First x minus 1m"; plan(2).firstPoint(1) = base.firstPoint(1)-1;
    plan(3).name = "First x plus 1m"; plan(3).firstPoint(1) = base.firstPoint(1)+1;
    plan(4).name = "Bearing minus 0.1deg"; plan(4).bearing = base.bearing-0.1;
    plan(5).name = "Bearing plus 0.1deg"; plan(5).bearing = base.bearing+0.1;
    plan(6).name = "Constructed delta 0.9"; plan(6).delta = 0.9; plan(6).factor = "constructed parameter";
    plan(7).name = "Constructed delta 1.1"; plan(7).delta = 1.1; plan(7).factor = "constructed parameter";
else
    plan = repmat(base,28,1);
    firstPoints = [0 0;1750 0]; bearings = [0 90]; budgets = [400 1000];
    labels = ["K coarse single" "C coarse single" "C coarse multi" "C fine multi" "C fine reranked"];
    k = 0;
    for g = 1:2
        for budget = budgets
            for m = 1:5
                k = k+1; plan(k).geometry = g; plan(k).method = m;
                plan(k).firstPoint = firstPoints(g,:); plan(k).bearing = bearings(g);
                plan(k).budget = budget; plan(k).name = "G"+g+" B"+budget+" "+labels(m);
                plan(k).factor = labels(m);
                if m==1
                    plan(k).domain = "K";
                end
                if m<=2
                    plan(k).seeds = 1;
                end
                if m<=3
                    plan(k).steps = [25 8];
                end
                plan(k).rerank = m==5;
            end
        end
    end
    for g = 1:2
        for budget = budgets
            for m = 6:7
                k = k+1;
                plan(k).geometry = g; plan(k).method = m;
                plan(k).firstPoint = firstPoints(g,:); plan(k).bearing = bearings(g);
                plan(k).budget = budget; plan(k).seeds = 0; plan(k).steps = [];
                plan(k).quota = 32;
                if m==6
                    plan(k).domain = "K";
                end
                plan(k).factor = plan(k).domain+" fixed 32 scores";
                plan(k).name = "G"+g+" B"+budget+" "+plan(k).factor;
            end
        end
    end
end
end

function result = collect140(stage,settings,plan,details,initialChecks,elapsed)
active = details(~cellfun(@isempty,details));
summary = table; matchingSummary = table; checks = initialChecks;
for k = 1:numel(active)
    if active{k}.spec.quota>0
        matchingSummary = [matchingSummary;active{k}.row];
    else
        summary = [summary;active{k}.row];
    end
    checks = [checks;active{k}.checks];
end
result = struct('version','1.4.0','stage',stage,'status','RUNNING','settings',settings, ...
    'plan',plan,'details',{details},'summary',summary,'checks',checks, ...
    'matlabVersion',version,'elapsedSeconds',elapsed,'paperEligible',false, ...
    'scope','Constructed finite scenarios; heuristic selection; no new global optimality proof.');
result.matchingSummary = matchingSummary;
end

function status140(outputRoot,status,stage,completed,total,message)
state = struct('status',status,'stage',stage,'completed',completed,'total',total, ...
    'updated',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),'message',message, ...
    'paperEligible',false,'resumeCommand',sprintf('q2_localization(''verify6809'',struct(''stage'',''%s'',''resume'',true),outputRoot)',stage));
file = fopen(fullfile(outputRoot,'status.json'),'w','n','UTF-8');
assert(file>=0,'Cannot write progress status.');
cleanup = onCleanup(@()fclose(file));
fwrite(file,jsonencode(state,'PrettyPrint',true),'char');
end

function detail = ablation140(spec,settings)
started = tic;
settings.scoreContext = newScoreContext34(true);
rotation = [cosd(spec.bearing) -sind(spec.bearing);sind(spec.bearing) cosd(spec.bearing)];
sourceCenter = -spec.firstPoint*rotation;
fine = settings; fine.circleSides = 5760; fine.scoreTolerance = 0.002; fine.maxSplits = 2200;
[fineOuter,fineInner] = initialRegion(sourceCenter,fine);
[outer,inner] = initialRegion(sourceCenter,settings);
domain = receiveDomain(fineOuter,settings);
originalOnly = spec.domain=="K";
points = commonGrid140(domain,spec.budget,settings);
if originalOnly
    points = points(safePoints(points,settings),:);
end
gridPoints = points;
scores = scoreRows(points,outer,inner,settings);
gridCount = size(points,1);
[~,order] = sortrows([scores(:,2) vecnorm(points,2,2) points],[1 2 3 4]);
seeds = points(order(1),:);
for k = 2:numel(order)
    if size(seeds,1)>=spec.seeds
        break
    end
    if all(vecnorm(seeds-points(order(k),:),2,2)>10)
        seeds(end+1,:) = points(order(k),:);
    end
end
search = settings; search.searchSteps = spec.steps;
for k = 1:size(seeds,1)
    [extraPoints,extraScores] = polishPoint(seeds(k,:),spec.budget,originalOnly,domain,outer,inner,search);
    points = [points;extraPoints]; scores = [scores;extraScores];
end
[points,uniqueIndices] = unique(points,'rows'); scores = scores(uniqueIndices,:);
coarseIndex = bestIndex(points,scores(:,2));
coarsePoint = points(coarseIndex,:);
selected = coarseIndex;
refinedIndices = coarseIndex;
refinedScores = scoreRows(points(coarseIndex,:),fineOuter,fineInner,fine);
if spec.rerank
    [~,order] = sortrows([scores(:,2) vecnorm(points,2,2) points],[1 2 3 4]);
    refinedIndices = order(1:min(6,numel(order)));
    refinedScores = scoreRows(points(refinedIndices,:),fineOuter,fineInner,fine);
    selected = refinedIndices(bestIndex(points(refinedIndices,:),refinedScores(:,2)));
end
point = points(selected,:);
final = scorePoint(point,fineOuter,fineInner,fine);
[~,initialUpper] = enclosingCircle(fineOuter);
[~,~,initialLower] = enclosingCircle(feasibleSupport(fineInner,[0 0],settings.nearRadius));
item = struct('name',spec.name,'firstPoint',spec.firstPoint,'bearing',spec.bearing, ...
    'rotation',rotation,'sourceCenter',sourceCenter,'initial',fineOuter,'initialInner',fineInner, ...
    'initialRadius',initialUpper,'initialLower',initialLower,'witness',initialWitness(sourceCenter,settings), ...
    'domain',domain,'points',points,'point',point,'globalPoint',point*rotation'+spec.firstPoint,'final',final);
item.performance = scoreSnapshot34(settings.scoreContext);
item.performance.solveSeconds = toc(started);
checks = caseChecks140(item,settings);
violation = max(vecnorm(points,2,2)-spec.budget);
checks = [checks;check140(spec.name+"_fixed movement budget",violation<=1e-6,max(0,violation))];
if originalOnly
    checks = [checks;check140(spec.name+"_K candidate membership",all(safePoints(points,settings)),sum(~safePoints(points,settings)))];
end
row = row140(spec,item,scores(selected,1),scores(selected,2),item.performance.solveSeconds);
row.StartCount = size(seeds,1); row.RefinedCandidateCount = numel(refinedIndices);
detail = struct('spec',spec,'item',item,'checks',checks,'row',row,'gridCount',gridCount,'gridPoints',gridPoints, ...
    'coarseScores',scores,'coarsePoint',coarsePoint,'coarseSelectedScore',scores(coarseIndex,:), ...
    'selectedCoarseScore',scores(selected,:),'refinedIndices',refinedIndices, ...
    'refinedScores',refinedScores,'seeds',seeds,'finalScoring',[5760 0.002 2200]);
end

function row = row140(spec,item,coarseLower,coarseUpper,elapsed)
state = radiusState140(item.final.lower,item.final.upper);
row = table(spec.name,spec.firstPoint(1),spec.firstPoint(2),spec.bearing,spec.delta,spec.factor, ...
    spec.geometry,spec.method,spec.budget,spec.domain,spec.seeds,numel(spec.steps),1, ...
    coarseLower,coarseUpper,item.final.lower,item.final.upper,item.final.gap, ...
    norm(item.point),norm(item.point)/5+5,item.point(1),item.point(2), ...
    item.globalPoint(1),item.globalPoint(2),mod(atan2d(item.point(2),item.point(1))+spec.bearing,360), ...
    item.performance.requests,item.performance.kernelCalls,item.performance.kernelSeconds,elapsed,state, ...
    'VariableNames',{'Case','FirstX','FirstY','BearingDeg','DeltaDeg','Factor','Geometry','Method', ...
    'BudgetMeters','Domain','StartCount','SpatialLevels','RefinedCandidateCount','SelectedCoarseLower', ...
    'SelectedCoarseUpper','Lower','Upper','Gap','MoveMeters','TravelAndMeasureSeconds','LocalX','LocalY', ...
    'GlobalX','GlobalY','MoveDirectionDeg','ScoreRequests','KernelCalls','KernelSeconds','SolveSeconds','Radius20State'});
end

function checks = caseChecks140(item,settings)
name = item.name;
geometry = sourceGeometry130(item.sourceCenter,settings);
violation = exactSafe130(item.point,geometry);
checks = check140(name+"_continuous reception certificate",violation<1e-5,max(0,violation));
values = zeros(size(item.points,1),1);
for k = 1:numel(values)
    values(k) = domainViolation(item.points(k,:),item.domain,settings);
end
checks = [checks;check140(name+"_all candidates in C(P+)",max(values)<1e-5,max(0,max(values)))];
checks = [checks;check140(name+"_ordered risk interval",item.final.lower<=item.final.upper,item.final.lower-item.final.upper)];
checks = [checks;check140(name+"_feedback score gap under 0.005m",item.final.gap<0.005,item.final.gap)];
checks = [checks;check140(name+"_information cannot worsen risk",item.final.upper<=item.initialRadius+0.005,max(0,item.final.upper-item.initialRadius))];
roundTrip = norm((item.globalPoint-item.firstPoint)*item.rotation-item.point);
checks = [checks;check140(name+"_global local coordinate roundtrip",roundTrip<1e-7,roundTrip)];
truths = [item.witness;feasibleSupport(item.initialInner,[0 0],settings.nearRadius)];
worst = 0; regionWorst = 0; count = 0;
for k = 1:size(truths,1)
    truth = truths(k,:);
    if norm(truth-item.sourceCenter)>settings.sourceRadius+1e-7 || norm(truth)<=settings.nearRadius
        continue
    end
    for errorAngle = [-settings.delta 0 settings.delta]
        if norm(truth-item.point)<=settings.nearRadius
            posterior = clipDisk(item.initial,item.point,settings.nearRadius,5760,true);
        else
            angle = atan2d(truth(2)-item.point(2),truth(1)-item.point(1))+errorAngle;
            posterior = clipDisk(item.initial,item.point,settings.receiveMax,5760,true);
            posterior = clipWedge(posterior,item.point,angle,settings.delta);
            direction = [cosd(angle) sind(angle)];
            posterior = clipPlane(posterior,-direction,-dot(direction,item.point)-settings.nearRadius*cosd(settings.delta));
        end
        if isempty(posterior)
            worst = inf;
        else
            [center,radius] = enclosingCircle(posterior);
            worst = max(worst,norm(truth-center)-radius);
        end
        regionWorst = max(regionWorst,posteriorDistance151(posterior,truth));
        count = count+1;
    end
end
checks = [checks;check140(name+"_constructed truth posterior region coverage",count>0 && regionWorst<1e-6,regionWorst); ...
    check140(name+"_constructed truth posterior enclosing circle coverage",count>0 && worst<1e-6,worst)];
end

function checks = check140(name,passed,value)
checks = table(string(name),logical(passed),double(value),'VariableNames',{'Check','Passed','Error'});
end

function checks = boundaryChecks140(settings)
checks = basicChecks(settings);
nearGeometry = exactGeometry12([0 0],[500 0],0,"near");
directionGeometry = exactGeometry12([0 0],[500 0],0,"direction");
points = [504.999 0;505 0;505.001 0];
nearValues = constraintViolation12(nearGeometry,points);
directionValues = constraintViolation12(directionGeometry,points);
checks = [checks;check140("5m near closed boundary",all(nearValues(1:2)<=1e-8) && nearValues(3)>0,nearValues(3))];
checks = [checks;check140("5m directional closure excludes interior",directionValues(1)>0 && all(directionValues(2:3)<=1e-8),directionValues(1))];
critical = -settings.nearRadius*cosd(settings.delta)+sqrt(settings.sourceRadius^2-settings.nearRadius^2*sind(settings.delta)^2);
witness = initialWitness([-critical+0.01 0],settings);
rejected = false;
try
    initialWitness([-critical-0.01 0],settings);
catch
    rejected = true;
end
checks = [checks;check140("compatibility switch around analytic threshold",rejected && all(vecnorm(witness,2,2)>settings.nearRadius),critical)];
fine = settings; fine.circleSides = 5760;
first = 1730; last = 1780;
for k = 1:28
    middle = (first+last)/2;
    polygon = initialRegion([-middle 0],fine);
    [~,radius] = enclosingCircle(polygon);
    if radius>20
        first = middle;
    else
        last = middle;
    end
end
polygon = initialRegion([-first+0.02 0],fine);
[~,above] = enclosingCircle(polygon);
polygon = initialRegion([-last-0.02 0],fine);
[~,below] = enclosingCircle(polygon);
checks = [checks;check140("20m initial sufficient state switch",below<20 && above>20,above-below)];
checks = [checks;check140("20m upper bound equality guarantees",radiusState140(19,20)=="GUARANTEED",0); ...
    check140("20m lower bound equality remains unresolved",radiusState140(20,20.001)=="UNRESOLVED",0); ...
    check140("20m strict lower bound disproves guarantee",radiusState140(20.001,20.002)=="NOT_GUARANTEED",0)];
checks = [checks;check140("declared geometry constants unchanged",settings.nearRadius==5 && settings.receiveMin==1000 && settings.receiveMax==1500 && settings.sourceRadius==1800,0)];
rejected = false;
try
    q2_localization([0 0],NaN);
catch
    rejected = true;
end
checks = [checks;check140("nonfinite first bearing rejected",rejected,double(~rejected))];
end

function [output,checks] = symmetry140(details,settings)
base = details{1}.item;
fine = settings; fine.circleSides = 5760; fine.scoreTolerance = 0.002; fine.maxSplits = 2200;
rows = cell(2,1); checks = table;
for k = 2:3
    item = details{k}.item;
    if k==2
        point = base.point;
        center = base.sourceCenter;
        angle = 334.6;
        rotation = [cosd(angle) -sind(angle);sind(angle) cosd(angle)];
        expectedGlobal = base.globalPoint*rotation';
    else
        point = base.point.*[1 -1];
        center = base.sourceCenter.*[1 -1];
        expectedGlobal = base.globalPoint.*[1 -1];
    end
    started = tic;
    crossScore = scorePoint(point,item.initial,item.initialInner,fine);
    seconds = toc(started);
    sourceError = norm(center-item.sourceCenter);
    globalError = norm(point*item.rotation'+item.firstPoint-expectedGlobal);
    samePointDifference = [crossScore.lower-base.final.upper crossScore.upper-base.final.lower];
    selectedDifference = [item.final.lower-base.final.upper item.final.upper-base.final.lower];
    safeViolation = exactSafe130(point,sourceGeometry130(item.sourceCenter,settings));
    samePointOverlap = samePointDifference(1)<=1e-6 && samePointDifference(2)>=-1e-6;
    selectedOverlap = selectedDifference(1)<=1e-6 && selectedDifference(2)>=-1e-6;
    rows{k-1} = table(item.name,point(1),point(2),crossScore.lower,crossScore.upper, ...
        sourceError,globalError,safeViolation,samePointDifference(1),samePointDifference(2), ...
        selectedDifference(1),selectedDifference(2),samePointOverlap,selectedOverlap,seconds, ...
        'VariableNames',{'Transform','MappedLocalX','MappedLocalY','MappedLower','MappedUpper', ...
        'SourceCenterError','GlobalMapError','MappedSafeViolation','MappedRiskDifferenceLower', ...
        'MappedRiskDifferenceUpper','SelectedRiskDifferenceLower','SelectedRiskDifferenceUpper', ...
        'MappedIntervalsOverlap','SelectedIntervalsOverlap','CrossScoreSeconds'});
    checks = [checks;check140(item.name+"_source transform",sourceError<1e-7,sourceError); ...
        check140(item.name+"_physical measurement transform",globalError<1e-7,globalError); ...
        check140(item.name+"_mapped strategy safe",safeViolation<1e-5,max(0,safeViolation)); ...
        check140(item.name+"_mapped objective interval compatible",samePointOverlap,max([0 samePointDifference(1) -samePointDifference(2)]))];
end
output = vertcat(rows{:});
end

function output = sensitivity140(details)
base = details{1}.item;
rows = cell(numel(details),1);
for k = 1:numel(details)
    item = details{k}.item; spec = details{k}.spec;
    change = [item.final.lower-base.final.upper item.final.upper-base.final.lower];
    baseAngle = atan2d(base.point(2),base.point(1))+base.bearing;
    angle = atan2d(item.point(2),item.point(1))+item.bearing;
    rows{k} = table(spec.name,spec.factor,spec.delta,change(1),change(2), ...
        norm(item.point)-norm(base.point),norm(item.globalPoint-base.globalPoint), ...
        mod(angle-baseAngle+180,360)-180,details{k}.row.Radius20State, ...
        'VariableNames',{'Case','Factor','DeltaDeg','RiskChangeLower','RiskChangeUpper', ...
        'MoveLengthChangeMeters','SelectedGlobalPointChangeMeters','MoveDirectionChangeDeg','Radius20State'});
end
output = vertcat(rows{:});
end

function output = comparisons140(details)
rows = cell(16,1); j = 0;
for k = 1:numel(details)
    current = details{k};
    if current.spec.method==1
        continue
    end
    previous = details{k-1};
    assert(current.spec.budget==previous.spec.budget && current.spec.geometry==previous.spec.geometry,'Comparison budget or geometry mismatch.');
    lo = previous.item.final.lower-current.item.final.upper;
    hi = previous.item.final.upper-current.item.final.lower;
    verdict = "UNRESOLVED";
    if lo>0
        verdict = "IMPROVED";
    elseif hi<0
        verdict = "WORSE";
    end
    j = j+1;
    rows{j} = table(current.spec.geometry,current.spec.budget,previous.spec.factor,current.spec.factor, ...
        lo,hi,verdict,previous.row.MoveMeters,current.row.MoveMeters, ...
        previous.row.KernelCalls,current.row.KernelCalls,previous.row.SolveSeconds,current.row.SolveSeconds, ...
        current.row.KernelCalls/max(1,previous.row.KernelCalls),false, ...
        'VariableNames',{'Geometry','BudgetMeters','Before','After','RiskImprovementLower', ...
        'RiskImprovementUpper','Verdict','BeforeMoveMeters','AfterMoveMeters','BeforeKernelCalls', ...
        'AfterKernelCalls','BeforeSolveSeconds','AfterSolveSeconds','KernelCallRatio','EqualComputeBudget'});
end
output = vertcat(rows{1:j});
end

function figure140(result,outputRoot)
rows = result.summary;
if strcmp(result.stage,'09')
    figureHandle = figure('Visible','off','Color','w','Position',[100 100 1150 760]);
    layout = tiledlayout(figureHandle,2,2,'TileSpacing','compact','Padding','compact');
    for k = 1:4
        ax = nexttile(layout);
        indices = (k-1)*5+(1:5);
        middle = (rows.Lower(indices)+rows.Upper(indices))/2;
        errorbar(ax,1:5,middle,middle-rows.Lower(indices),rows.Upper(indices)-middle,'o-', ...
            'LineWidth',1.5,'MarkerFaceColor','w','Color',[0.1 0.3 0.6]);
        xticks(ax,1:5); xticklabels(ax,{'K粗单起点','扩域粗单','扩域粗多','扩域细多','精算重排'});
        xlim(ax,[0.5 5.5]);
        title(ax,sprintf('几何%d，移动预算%g m',rows.Geometry(indices(1)),rows.BudgetMeters(indices(1))));
        ylabel(ax,'最坏定位半径（m）'); grid(ax,'on');
    end
    title(layout,'同移动预算、统一精算；未统一限制评分次数');
else
    figureHandle = figure('Visible','off','Color','w','Position',[100 100 1150 730]);
    layout = tiledlayout(figureHandle,2,1,'TileSpacing','compact','Padding','compact');
    ax = nexttile(layout);
    middle = (rows.Lower+rows.Upper)/2;
    errorbar(ax,1:height(rows),middle,middle-rows.Lower,rows.Upper-middle,'o', ...
        'LineStyle','none','LineWidth',1.5,'MarkerFaceColor','w','Color',[0.1 0.3 0.6]);
    if strcmp(result.stage,'06')
        labels = {'非轴向基准','整体旋转跨零','镜像首测','圆域外非轴向'};
    else
        labels = {'基准','首点x减1m','首点x加1m','方位减0.1度','方位加0.1度','构造参数0.9度','构造参数1.1度'};
    end
    ylabel(ax,'最坏定位半径（m）'); grid(ax,'on');
    xticks(ax,1:height(rows)); xticklabels(ax,labels); xtickangle(ax,15);
    xlim(ax,[0.5 height(rows)+0.5]);
    ax = nexttile(layout);
    plot(ax,1:height(rows),rows.MoveMeters,'s','LineStyle','none','LineWidth',1.5,'Color',[0.65 0.28 0.08]);
    ylabel(ax,'推荐移动距离（m）'); grid(ax,'on');
    xticks(ax,1:height(rows)); xticklabels(ax,labels); xtickangle(ax,15);
    xlim(ax,[0.5 height(rows)+0.5]);
    title(layout,sprintf('第%s项构造场景；风险区间统一使用5760边、0.002 m容差、2200次细分',result.stage));
end
set(findall(figureHandle,'Type','text'),'FontName','Microsoft YaHei');
set(findall(figureHandle,'Type','axes'),'FontName','Microsoft YaHei','FontSize',10,'Box','on');
exportgraphics(figureHandle,fullfile(outputRoot,['stage_' result.stage '.png']),'Resolution',180);
savefig(figureHandle,fullfile(outputRoot,['stage_' result.stage '.fig']));
close(figureHandle);
end

function state = radiusState140(lower,upper)
validateattributes(lower,{'numeric'},{'real','finite','scalar','nonnegative'});
validateattributes(upper,{'numeric'},{'real','finite','scalar','>=',lower});
state = "UNRESOLVED";
if upper<=20
    state = "GUARANTEED";
elseif lower>20
    state = "NOT_GUARANTEED";
end
end

function points = commonGrid140(domain,budget,settings)
angles = unique([-180:15:165 -59 59])';
oldLimits = max(0,min(settings.receiveMin,2*settings.receiveMin*cosd(abs(angles)+settings.delta)));
oldLimits(abs(angles)>=90-settings.delta) = 0;
newLimits = domainLimit(angles,domain,settings);
limits = min([oldLimits newLimits],budget);
points = [0 0];
for k = 1:numel(angles)
    for column = 1:2
        limit = limits(k,column);
        if limit>1e-6
            radii = unique([min(25,limit) limit*[0.25 0.5 0.75 1]]);
            points = [points;radii(:)*[cosd(angles(k)) sind(angles(k))]];
        end
    end
end
points = unique(points,'rows');
end

function detail = matching140(spec,settings)
started = tic;
settings.scoreContext = newScoreContext34(true);
rotation = [cosd(spec.bearing) -sind(spec.bearing);sind(spec.bearing) cosd(spec.bearing)];
sourceCenter = -spec.firstPoint*rotation;
fine = settings; fine.circleSides = 5760; fine.scoreTolerance = 0.002; fine.maxSplits = 2200;
[fineOuter,fineInner] = initialRegion(sourceCenter,fine);
[outer,inner] = initialRegion(sourceCenter,settings);
domain = receiveDomain(fineOuter,settings);
common = commonGrid140(domain,spec.budget,settings);
if spec.domain=="K"
    available = common(safePoints(common,settings),:);
else
    available = common;
end
assert(size(available,1)>=spec.quota,'Insufficient unique candidates for fixed scoring quota.');
nonzero = available(vecnorm(available,2,2)>1e-9,:);
[~,order] = sortrows([atan2d(nonzero(:,2),nonzero(:,1)) vecnorm(nonzero,2,2) nonzero],[1 2 3 4]);
nonzero = nonzero(order,:);
indices = round(linspace(1,size(nonzero,1),spec.quota-1));
points = [0 0;nonzero(indices,:)];
assert(size(unique(points,'rows'),1)==spec.quota,'Quota selection must contain distinct points.');
scores = scoreRows(points,outer,inner,settings);
coarsePerformance = scoreSnapshot34(settings.scoreContext);
index = bestIndex(points,scores(:,2)); point = points(index,:);
final = scorePoint(point,fineOuter,fineInner,fine);
[~,initialUpper] = enclosingCircle(fineOuter);
[~,~,initialLower] = enclosingCircle(feasibleSupport(fineInner,[0 0],settings.nearRadius));
item = struct('name',spec.name,'firstPoint',spec.firstPoint,'bearing',spec.bearing, ...
    'rotation',rotation,'sourceCenter',sourceCenter,'initial',fineOuter,'initialInner',fineInner, ...
    'initialRadius',initialUpper,'initialLower',initialLower,'witness',initialWitness(sourceCenter,settings), ...
    'domain',domain,'points',points,'point',point,'globalPoint',point*rotation'+spec.firstPoint,'final',final);
item.performance = scoreSnapshot34(settings.scoreContext);
item.performance.solveSeconds = toc(started);
checks = caseChecks140(item,settings);
checks = [checks;check140(spec.name+"_fixed unique coarse evaluations",coarsePerformance.kernelCalls==spec.quota && coarsePerformance.requests==spec.quota,coarsePerformance.kernelCalls); ...
    check140(spec.name+"_one uniform precision final evaluation",item.performance.kernelCalls==spec.quota+1 && item.performance.requests==spec.quota+1,item.performance.kernelCalls); ...
    check140(spec.name+"_fixed movement budget",max(vecnorm(points,2,2))<=spec.budget+1e-6,max(vecnorm(points,2,2))-spec.budget)];
if spec.domain=="K"
    checks = [checks;check140(spec.name+"_K candidate membership",all(safePoints(points,settings)),sum(~safePoints(points,settings)))];
end
row = row140(spec,item,scores(index,1),scores(index,2),item.performance.solveSeconds);
row.FixedCoarseQuota = spec.quota;
row.CoarseKernelCalls = coarsePerformance.kernelCalls;
row.FinalKernelCalls = item.performance.kernelCalls-coarsePerformance.kernelCalls;
row.AvailableCandidateCount = size(available,1);
detail = struct('spec',spec,'item',item,'checks',checks,'row',row,'gridPoints',points, ...
    'availableCandidates',available,'coarseScores',scores,'coarsePerformance',coarsePerformance, ...
    'selectedCoarseScore',scores(index,:),'finalScoring',[5760 0.002 2200], ...
    'samplingRule','Zero plus equally spaced ranks in angle-radius-coordinate sorted legal common grid.');
end

function output = matchingComparisons140(details)
rows = cell(4,1);
for j = 1:4
    first = details{2*j-1}; last = details{2*j};
    assert(first.spec.geometry==last.spec.geometry && first.spec.budget==last.spec.budget,'Quota comparison mismatch.');
    lo = first.item.final.lower-last.item.final.upper;
    hi = first.item.final.upper-last.item.final.lower;
    verdict = "UNRESOLVED";
    if lo>0
        verdict = "IMPROVED";
    elseif hi<0
        verdict = "WORSE";
    end
    matched = first.row.KernelCalls==last.row.KernelCalls && first.row.CoarseKernelCalls==last.row.CoarseKernelCalls;
    assert(matched,'Quota scores do not match.');
    rows{j} = table(first.spec.geometry,first.spec.budget,first.spec.quota,first.row.Lower,first.row.Upper, ...
        last.row.Lower,last.row.Upper,lo,hi,verdict,first.row.MoveMeters,last.row.MoveMeters, ...
        first.row.KernelCalls,last.row.KernelCalls,first.row.SolveSeconds,last.row.SolveSeconds,matched,false, ...
        'VariableNames',{'Geometry','BudgetMeters','CoarseQuota','KLower','KUpper','CLower','CUpper', ...
        'RiskImprovementLower','RiskImprovementUpper','Verdict','KMoveMeters','CMoveMeters', ...
        'KKernelCalls','CKernelCalls','KSolveSeconds','CSolveSeconds','EqualScoreCount','EqualCpuTime'});
end
output = vertcat(rows{:});
end

function result = report140(inputFile,outputRoot)
assert(~isfolder(outputRoot) && ~isfile(outputRoot),'报告输出须为全新路径。');
loaded = load(inputFile,'result');
assert(isfield(loaded,'result') && isstruct(loaded.result),'研究MAT中缺少结果。');
result = loaded.result;
assert(strcmp(result.version,'1.4.0') && strcmp(result.status,'SELF_CHECKED'),'只可重导1.4.0已完成研究。');
assert(any(string(result.stage)==["06" "08" "09"]) && all(result.checks.Passed),'研究阶段无效或存在未通过检查。');
assert(~isempty(result.details) && all(~cellfun(@isempty,result.details)),'研究场景尚未全部完成。');
mkdir(outputRoot);
figure140(result,outputRoot);
matchingCount = 0; matchingSeconds = 0; matchingCalls = 0; matchingRequests = 0;
if isfield(result,'matchingSummary') && ~isempty(result.matchingSummary)
    matchingCount = height(result.matchingSummary);
    matchingSeconds = sum(result.matchingSummary.SolveSeconds);
    matchingCalls = sum(result.matchingSummary.KernelCalls);
    matchingRequests = sum(result.matchingSummary.ScoreRequests);
end
metadata = struct('version',result.version,'matlabVersion',result.matlabVersion,'stage',result.stage, ...
    'sourceResultFile',char(inputFile),'status',result.status,'reportOnly',true,'paperEligible',false, ...
    'caseCount',numel(result.details),'mainCaseCount',height(result.summary),'matchingCaseCount',matchingCount, ...
    'checks',height(result.checks),'failedChecks',sum(~result.checks.Passed),'elapsedSeconds',result.elapsedSeconds, ...
    'sumSolveSeconds',sum(result.summary.SolveSeconds)+matchingSeconds,'matchingSolveSeconds',matchingSeconds, ...
    'sumKernelCalls',sum(result.summary.KernelCalls)+matchingCalls, ...
    'sumScoreRequests',sum(result.summary.ScoreRequests)+matchingRequests, ...
    'generatedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
file = fopen(fullfile(outputRoot,'report_metadata.json'),'w','n','UTF-8');
assert(file>=0,'无法写入报告元信息。');
cleanup = onCleanup(@()fclose(file));
fwrite(file,jsonencode(metadata,'PrettyPrint',true),'char');
fprintf('第%s项图表已从固定MAT重导；未重新计算实验。\n',result.stage);
end

function result = verifyResearch150(settings,options,outputRoot)
base = fileparts(mfilename('fullpath'));
defaults = struct('priorFile',fullfile(base,'论文素材包','v1.2.0','运行结果','20260911_113635_390','完整结果.mat'), ...
    'boundsFile',fullfile(base,'论文素材包','v1.3.0','研究验证','20260911_10_12_11','研究完整结果.mat'), ...
    'taus',[20 50 100],'budgets',[0 25 50 100 200 400 600 800 1000 1500 2000], ...
    'seeds',2,'finalists',3,'refinementSteps',5,'makeFigures',true,'resume',true,'maxCases',inf);
names = fieldnames(options);
for k = 1:numel(names)
    assert(isfield(defaults,names{k}),'Unknown budget research option.');
    defaults.(names{k}) = options.(names{k});
end
options = defaults;
options.taus = values150(options.taus,true);
options.budgets = unique([0 values150(options.budgets,false)]);
validateattributes(options.seeds,{'numeric'},{'scalar','integer','>=',1,'<=',3});
validateattributes(options.finalists,{'numeric'},{'scalar','integer','>=',1,'<=',6});
validateattributes(options.refinementSteps,{'numeric'},{'scalar','integer','>=',0,'<=',8});
validateattributes(options.makeFigures,{'logical'},{'scalar'});
validateattributes(options.resume,{'logical'},{'scalar'});
validateattributes(options.maxCases,{'numeric'},{'real','scalar','positive'});
assert(isinf(options.maxCases) || options.maxCases==floor(options.maxCases),'maxCases must be an integer.');
assert(isfile(options.priorFile) && isfile(options.boundsFile),'Fixed input MAT files are required.');
loaded = load(options.priorFile,'result'); prior = loaded.result;
loaded = load(options.boundsFile,'result'); bounds = loaded.result;
assert(numel(prior.cases)==6 && all(prior.checks.Passed),'Prior six-case result is incomplete or failed.');
assert(strcmp(bounds.version,'1.3.0') && strcmp(bounds.status,'SELF_CHECKED') && all(bounds.checks.Passed),'Inherited global evidence is incomplete or failed.');
assert(numel(bounds.details)==6,'Six inherited global certificates are required.');
parameters = {'delta','sourceRadius','receiveMin','receiveMax','nearRadius','speed'};
for k = 1:numel(parameters)
    name = parameters{k};
    assert(isequal(settings.(name),prior.settings.(name)) && isequal(settings.(name),bounds.settings.(name)), ...
        'Fixed input physical parameter mismatch: %s',name);
end
provenance = struct('priorFile',char(options.priorFile),'priorSHA256',digest150(options.priorFile), ...
    'boundsFile',char(options.boundsFile),'boundsSHA256',digest150(options.boundsFile), ...
    'inheritedVersion',bounds.version,'inheritedMatlabVersion',bounds.matlabVersion, ...
    'evidenceLevel','Inherited double-precision continuous safe-domain certificate; not interval arithmetic.');
identityOptions = rmfield(options,{'makeFigures','resume','maxCases'});
identity = struct('version','1.5.1','options',identityOptions,'provenance',provenance, ...
    'sourceText',fileread([mfilename('fullpath') '.m']));
manifestFile = fullfile(outputRoot,'manifest.mat');
if isfolder(outputRoot)
    assert(options.resume && isfile(manifestFile),'Existing folder is not a resumable budget study.');
    loaded = load(manifestFile,'identity');
    assert(isequaln(identity,loaded.identity),'Source or fixed inputs changed; use a new output folder.');
else
    assert(~isfile(outputRoot),'Output path is a file.');
    mkdir(outputRoot); save(manifestFile,'identity');
end
started = tic;
status150(outputRoot,'RUNNING',0,'Starting or resuming six fixed cases.');
try
    initialChecks = budgetChecks150;
    writetable(initialChecks,fullfile(outputRoot,'initial_checks.csv'),'Encoding','UTF-8');
    assert(all(initialChecks.Passed),'Initial budget checks failed.');
    details = cell(6,1); newlyRun = 0;
    expectedPoints = [0 0;1750 0;1780 0;1750 0;2600 0;1760 0];
    expectedBearings = [0 0 90 180 180 0];
    for k = 1:6
        item = prior.cases{k}; inherited = bounds.details{k};
        assert(norm(item.firstPoint-expectedPoints(k,:))<1e-9 && item.bearing==expectedBearings(k),'Unexpected fixed scenario.');
        assert(inherited.caseIndex==k && norm(item.sourceCenter-inherited.geometry.sourceCenter)<1e-9,'Global certificate scenario mismatch.');
        file = fullfile(outputRoot,sprintf('case_%02d.mat',k));
        if isfile(file)
            loaded = load(file,'detail'); details{k} = loaded.detail;
            assert(details{k}.caseIndex==k,'Checkpoint scenario mismatch.');
        elseif newlyRun<options.maxCases
            fprintf('Budget case %d/6: %s\n',k,item.name);
            status150(outputRoot,'RUNNING',k-1,char(item.name));
            detail = budgetCase150(k,item,inherited,settings,options);
            details{k} = detail;
            save(file,'detail');
            writeCase150(detail,outputRoot);
            newlyRun = newlyRun+1;
        end
        if ~isempty(details{k})
            assert(all(details{k}.checks.Passed),'Budget case checks failed: %d',k);
        end
        result = collect150(details,initialChecks,settings,options,provenance,toc(started));
        save(fullfile(outputRoot,'checkpoint.mat'),'result');
        writetable(result.targets,fullfile(outputRoot,'target_budgets.csv'),'Encoding','UTF-8');
        writetable(result.summary,fullfile(outputRoot,'summary.csv'),'Encoding','UTF-8');
        writetable(result.checks,fullfile(outputRoot,'checks.csv'),'Encoding','UTF-8');
    end
    completed = sum(~cellfun(@isempty,details));
    if completed<6
        status150(outputRoot,'RUNNING',completed,'Stopped at maxCases; resume with unchanged source and inputs.');
        return
    end
    result.status = 'SELF_CHECKED';
    save(fullfile(outputRoot,'result.mat'),'result');
    if options.makeFigures
        figures150(result,outputRoot);
    end
    status150(outputRoot,'SELF_CHECKED',6,'Computation complete; human review pending.');
    fprintf('Budget study SELF_CHECKED: %d checks, 0 failures.\n',height(result.checks));
catch exception
    completed = 0;
    if exist('details','var')
        completed = sum(~cellfun(@isempty,details));
    end
    if exist('result','var')
        result.status = 'FAIL'; result.failureMessage = exception.message;
        save(fullfile(outputRoot,'result.mat'),'result');
        save(fullfile(outputRoot,'checkpoint.mat'),'result');
    end
    status150(outputRoot,'FAIL',completed,exception.message);
    rethrow(exception)
end
end

function values = values150(values,positive)
validateattributes(values,{'numeric'},{'real','finite','vector','nonempty'});
if positive
    assert(all(values>0),'Target radii must be positive.');
else
    assert(all(values>=0),'Movement budgets cannot be negative.');
end
values = unique(values(:)');
end

function hash = digest150(path)
file = fopen(path,'rb'); assert(file>=0,'Cannot read input for hashing.');
cleanup = onCleanup(@()fclose(file));
digest = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(file)
    bytes = fread(file,1048576,'*uint8');
    digest.update(typecast(bytes(:),'int8'));
end
bytes = typecast(digest.digest(),'uint8');
hash = lower(reshape(dec2hex(bytes,2).',1,[]));
end

function status150(outputRoot,status,completed,message)
state = struct('version','1.5.1','status',status,'completedCases',completed,'totalCases',6, ...
    'message',message,'updated',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),'paperEligible',false);
file = fopen(fullfile(outputRoot,'status.json'),'w','n','UTF-8');
assert(file>=0,'Cannot save study status.');
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s',jsonencode(state,'PrettyPrint',true));
end

function detail = budgetCase150(caseIndex,prior,inherited,settings,options)
started = tic;
settings.scoreContext = newScoreContext34(true);
fine = settings; fine.circleSides = 5760; fine.scoreTolerance = 0.002; fine.maxSplits = 2200;
rotation = [cosd(prior.bearing) -sind(prior.bearing);sind(prior.bearing) cosd(prior.bearing)];
sourceCenter = -prior.firstPoint*rotation;
[outer,inner] = initialRegion(sourceCenter,fine);
[coarseOuter,coarseInner] = initialRegion(sourceCenter,settings);
domain = receiveDomain(outer,settings);
geometry = sourceGeometry130(sourceCenter,settings);
[~,initialUpper] = enclosingCircle(outer);
initialSupport = feasibleSupport(inner,[0 0],settings.nearRadius);
[~,~,initialLower] = enclosingCircle(initialSupport);
zeroScore = struct('lower',initialLower,'upper',initialUpper,'gap',initialUpper-initialLower, ...
    'feedback',"no_new_measurement",'angle',NaN,'splits',0);
actions = actionRow150(1,"ZERO_ACTION",0,NaN,[0 0],prior,rotation,zeroScore,0,0,0);
seedPoints = unique([prior.point;prior.oldPoint;prior.budget(:,2:3)],'rows');
seedPoints = seedPoints(vecnorm(seedPoints,2,2)<=max(options.budgets)+1e-7,:);
for k = 1:size(seedPoints,1)
    actions = appendAction150(actions,seedPoints(k,:),"PRIOR_COORDINATE_REEVALUATED",norm(seedPoints(k,:)),NaN, ...
        prior,rotation,geometry,domain,outer,inner,fine);
end
searchRows = cell(numel(options.budgets)-1,1); rowIndex = 0;
search = settings; search.searchSteps = [25 8 2 0.5];
for budget = options.budgets(options.budgets>0)
    searchStarted = tic; before = scoreSnapshot34(settings.scoreContext); beforeActions = height(actions);
    points = commonGrid140(domain,budget,settings);
    if ~isempty(seedPoints)
        scaled = seedPoints.*min(1,budget./max(vecnorm(seedPoints,2,2),1e-12));
        points = unique([points;scaled],'rows');
    end
    scores = scoreRows(points,coarseOuter,coarseInner,settings);
    gridCount = size(points,1);
    [~,order] = sortrows([scores(:,2) vecnorm(points,2,2) points],[1 2 3 4]);
    seeds = points(order(1),:);
    for k = 2:numel(order)
        if size(seeds,1)>=options.seeds
            break
        end
        if all(vecnorm(seeds-points(order(k),:),2,2)>max(1,budget/20))
            seeds(end+1,:) = points(order(k),:);
        end
    end
    for k = 1:size(seeds,1)
        [extra,extraScores] = polishPoint(seeds(k,:),budget,false,domain,coarseOuter,coarseInner,search);
        points = [points;extra]; scores = [scores;extraScores];
    end
    [points,indices] = unique(points,'rows'); scores = scores(indices,:);
    [~,order] = sortrows([scores(:,2) vecnorm(points,2,2) points],[1 2 3 4]);
    finalists = order(1:min(options.finalists,numel(order)));
    for k = 1:numel(finalists)
        actions = appendAction150(actions,points(finalists(k),:),"FIXED_BUDGET_SEARCH",budget,NaN, ...
            prior,rotation,geometry,domain,outer,inner,fine);
    end
    after = scoreSnapshot34(settings.scoreContext); rowIndex = rowIndex+1;
    searchRows{rowIndex} = table(budget,gridCount,size(points,1),size(seeds,1),numel(finalists),height(actions)-beforeActions, ...
        after.requests-before.requests,after.kernelCalls-before.kernelCalls,toc(searchStarted), ...
        'VariableNames',{'BudgetMeters','InitialCandidates','SearchedCandidates','SeedCount','Finalists', ...
        'NewFineActions','ScoreRequests','KernelCalls','Seconds'});
end
if isempty(searchRows)
    searchLog = table;
else
    searchLog = vertcat(searchRows{:});
end
refineRows = cell(0,1);
for tau = options.taus
    if initialUpper<=tau || inherited.bound.lower>tau
        continue
    end
    feasible = find(actions.Upper<=tau);
    if isempty(feasible)
        continue
    end
    [~,order] = sortrows([actions.MoveMeters(feasible) actions.Upper(feasible)],[1 2]);
    best = feasible(order(1)); high = actions.MoveMeters(best); low = 0;
    direction = [actions.LocalX(best) actions.LocalY(best)]/high;
    for step = 1:options.refinementSteps
        beforeLow = low; beforeHigh = high;
        distance = (low+high)/2;
        [actions,index] = appendAction150(actions,distance*direction,"TARGET_RAY_REFINEMENT",distance,tau, ...
            prior,rotation,geometry,domain,outer,inner,fine);
        decision = "NOT_CERTIFIED";
        if actions.Upper(index)<=tau
            high = distance; decision = "CERTIFIED_FEASIBLE";
        else
            low = distance;
            if actions.Lower(index)>tau
                decision = "POINT_RISK_EXCEEDS_TARGET";
            end
        end
        refineRows{end+1,1} = table(tau,step,beforeLow,beforeHigh,distance,index,actions.Lower(index), ...
            actions.Upper(index),decision,high, ...
            'VariableNames',{'TargetRadius','Step','SearchLowMeters','SearchHighMeters','ProbeMeters','ActionId', ...
            'ProbeLower','ProbeUpper','ProbeState','RetainedFeasibleDistance'});
    end
end
if isempty(refineRows)
    refinement = table;
else
    refinement = vertcat(refineRows{:});
end
[dominance,upperFrontier] = dominance150(actions);
frontierBudgets = unique([options.budgets(:);actions.MoveMeters]);
frontier = frontier150(actions,frontierBudgets);
targets = targets150(caseIndex,string(prior.name),actions,inherited.bound.lower,options.taus);
chosen = find(actions.Upper==min(actions.Upper),1);
selected = struct('name',string(prior.name),'sourceCenter',sourceCenter,'point',[actions.LocalX(chosen) actions.LocalY(chosen)], ...
    'points',[actions.LocalX actions.LocalY],'domain',domain,'initial',outer,'initialInner',inner, ...
    'initialRadius',initialUpper,'initialLower',initialLower,'witness',initialWitness(sourceCenter,settings), ...
    'firstPoint',prior.firstPoint,'rotation',rotation,'globalPoint',[actions.GlobalX(chosen) actions.GlobalY(chosen)], ...
    'final',struct('lower',actions.Lower(chosen),'upper',actions.Upper(chosen),'gap',actions.Gap(chosen)));
checks = caseChecks140(selected,settings);
if chosen==1
    checks = checks(~endsWith(checks.Check,"_feedback score gap under 0.005m"),:);
end
nonzero = actions.Kind~="ZERO_ACTION";
initialViolation = max(constraintViolation12(geometry,initialSupport));
checks = [checks;check140(string(prior.name)+"_inherited global bound consistent",inherited.bound.lower<=min(actions.Upper)+1e-5,inherited.bound.lower-min(actions.Upper)); ...
    check140(string(prior.name)+"_budget guarantee envelope nonincreasing",all(diff(frontier.GuaranteedUpper)<=1e-9),max([0;diff(frontier.GuaranteedUpper)])); ...
    check140(string(prior.name)+"_finite pool lower uses every affordable action",all(frontier.FinitePoolLower<=frontier.GuaranteedUpper+1e-9),max(frontier.FinitePoolLower-frontier.GuaranteedUpper)); ...
    check140(string(prior.name)+"_zero action no extra measurement cost",actions.MoveMeters(1)==0 && actions.AdditionalSeconds(1)==0 && actions.Upper(1)==initialUpper,actions.AdditionalSeconds(1)); ...
    check140(string(prior.name)+"_all recorded budgets respected",all(actions.MoveMeters<=actions.OriginBudgetMeters+1e-6),max(actions.MoveMeters-actions.OriginBudgetMeters)); ...
    check140(string(prior.name)+"_zero initial interval and feasible support valid",initialLower>=0 && initialLower<=initialUpper && initialViolation<1e-7,max(0,initialViolation)); ...
    check140(string(prior.name)+"_zero initial gap recorded without feedback claim",abs(actions.Gap(1)-(initialUpper-initialLower))<1e-12,actions.Gap(1)); ...
    check140(string(prior.name)+"_nonzero uniform fine score gap",all(actions.Gap(nonzero)<0.005),max([0;actions.Gap(nonzero)])); ...
    check140(string(prior.name)+"_target action upper bounds certified",all(targets.RiskUpper(targets.State=="FEASIBLE_UPPER_FOUND")<=targets.TargetRadius(targets.State=="FEASIBLE_UPPER_FOUND")),0); ...
    check140(string(prior.name)+"_only zero movement has proven minimum",all(targets.MinimumProven==(targets.State=="ZERO_ACTION_GUARANTEED")),0)];
if ~isempty(refinement)
    checks = [checks;check140(string(prior.name)+"_ray probes remain in safe domain",all(actions.SafeViolationM2<1e-5),max(actions.SafeViolationM2))];
end
performance = scoreSnapshot34(settings.scoreContext);
detail = struct('caseIndex',caseIndex,'name',string(prior.name),'firstPoint',prior.firstPoint,'bearing',prior.bearing, ...
    'sourceCenter',sourceCenter,'actions',actions,'dominance',dominance,'paretoActions',actions(~dominance.CertainlyDominated,:), ...
    'upperFrontier',upperFrontier,'frontier',frontier,'targets',targets,'searchLog',searchLog,'refinement',refinement, ...
    'checks',checks,'performance',performance,'elapsedSeconds',toc(started),'fineScoring',[5760 0.002 2200], ...
    'inheritedGlobalLower',inherited.bound.lower,'inheritedGlobalUpper',inherited.bound.upper, ...
    'inheritedCaseIndex',inherited.caseIndex,'candidateDomain','C(P+)','selected',selected, ...
    'targetRefinementScope','Sampled safe ray refinement gives feasible upper bounds only; no monotonic ray assumption or necessary budget certificate.');
end

function [actions,index] = appendAction150(actions,point,kind,budget,tau,prior,rotation,geometry,domain,outer,inner,settings)
index = find(actions.LocalX==point(1) & actions.LocalY==point(2),1);
if ~isempty(index)
    return
end
if norm(point)<1e-10
    index = 1; return
end
assert(norm(point)<=budget+1e-6,'Candidate exceeds its movement budget.');
[safeViolation,~] = exactSafe130(point,geometry);
polygonViolation = domainViolation(point,domain,settings);
assert(safeViolation<1e-5 && polygonViolation<1e-5,'Candidate lacks reception safety certificate.');
started = tic; score = scorePoint(point,outer,inner,settings); seconds = toc(started);
assert(score.gap<0.005 && score.lower<=score.upper,'Uniform fine score did not converge.');
index = height(actions)+1;
actions = [actions;actionRow150(index,kind,budget,tau,point,prior,rotation,score,safeViolation,polygonViolation,seconds)];
end

function row = actionRow150(index,kind,budget,tau,point,prior,rotation,score,safeViolation,polygonViolation,seconds)
globalPoint = point*rotation'+prior.firstPoint;
additionalSeconds = norm(point)/5+5;
if kind=="ZERO_ACTION"
    additionalSeconds = 0;
end
row = table(index,string(kind),budget,tau,point(1),point(2),globalPoint(1),globalPoint(2),norm(point), ...
    additionalSeconds,score.lower,score.upper,score.gap,string(score.feedback),score.angle, ...
    safeViolation,polygonViolation,score.splits,seconds, ...
    'VariableNames',{'ActionId','Kind','OriginBudgetMeters','OriginTargetRadius','LocalX','LocalY','GlobalX','GlobalY', ...
    'MoveMeters','AdditionalSeconds','Lower','Upper','Gap','WorstFeedback','WorstBearingDeg','SafeViolationM2', ...
    'CandidateDomainViolationM2','FeedbackSplits','FineScoreSeconds'});
end

function [dominance,upperFrontier] = dominance150(actions)
count = height(actions); certain = false(count,1); upperKept = true(count,1);
certainWitness = zeros(count,1); upperWitness = zeros(count,1);
differenceLower = NaN(count,1); differenceUpper = NaN(count,1); state = repmat("UPPER_RETAINED",count,1);
for i = 1:count
    cheaper = actions.MoveMeters<=actions.MoveMeters(i);
    riskDominates = cheaper & actions.Upper<=actions.Lower(i) & ...
        (actions.MoveMeters<actions.MoveMeters(i) | actions.Upper<actions.Lower(i));
    riskDominates(i) = false;
    if any(riskDominates)
        eligible = find(riskDominates);
        [~,order] = sortrows([actions.Upper(eligible) actions.MoveMeters(eligible) eligible],[1 2 3]);
        certain(i) = true; certainWitness(i) = eligible(order(1));
    end
    upperDominates = cheaper & actions.Upper<=actions.Upper(i) & ...
        (actions.MoveMeters<actions.MoveMeters(i) | actions.Upper<actions.Upper(i) | actions.ActionId<i);
    upperDominates(i) = false;
    if any(upperDominates)
        eligible = find(upperDominates);
        [~,order] = sortrows([actions.Upper(eligible) actions.MoveMeters(eligible) eligible],[1 2 3]);
        j = eligible(order(1)); upperKept(i) = false; upperWitness(i) = j;
        differenceLower(i) = actions.Lower(i)-actions.Upper(j);
        differenceUpper(i) = actions.Upper(i)-actions.Lower(j);
        state(i) = "UPPER_ONLY_UNCERTAIN_RISK";
        if certain(i)
            state(i) = "CERTAINLY_DOMINATED";
        elseif actions.MoveMeters(j)==actions.MoveMeters(i) && actions.Upper(j)==actions.Upper(i)
            state(i) = "EQUAL_UPPER_REPRESENTATIVE";
        end
    end
end
dominance = table(actions.ActionId,certain,certainWitness,upperKept,upperWitness,differenceLower,differenceUpper,state, ...
    'VariableNames',{'ActionId','CertainlyDominated','CertainWitnessAction','UpperFrontierRetained', ...
    'UpperWitnessAction','WitnessImprovementLower','WitnessImprovementUpper','State'});
upperFrontier = sortrows(actions(upperKept,:),{'MoveMeters','Upper','ActionId'});
end

function frontier = frontier150(actions,budgets)
budgets = values150(budgets,false)';
rows = cell(numel(budgets),1);
for k = 1:numel(budgets)
    affordable = find(actions.MoveMeters<=budgets(k)+1e-8);
    assert(~isempty(affordable),'Zero action is missing from the candidate pool.');
    [~,order] = sortrows([actions.Upper(affordable) actions.MoveMeters(affordable) affordable],[1 2 3]);
    index = affordable(order(1));
    rows{k} = table(budgets(k),numel(affordable),min(actions.Lower(affordable)),actions.Upper(index),index, ...
        actions.Lower(index),actions.MoveMeters(index),actions.AdditionalSeconds(index), ...
        'VariableNames',{'BudgetMeters','AffordableActionCount','FinitePoolLower','GuaranteedUpper','SelectedActionId', ...
        'SelectedActionLower','SelectedMoveMeters','SelectedAdditionalSeconds'});
end
frontier = vertcat(rows{:});
end

function targets = targets150(caseIndex,name,actions,globalLower,taus)
rows = cell(numel(taus),1);
for k = 1:numel(taus)
    tau = taus(k);
    eligible = find(actions.Upper<=tau);
    budget = NaN; index = NaN; lower = NaN; upper = NaN; seconds = NaN;
    if ~isempty(eligible)
        [~,order] = sortrows([actions.MoveMeters(eligible) actions.Upper(eligible) eligible],[1 2 3]);
        index = eligible(order(1)); budget = actions.MoveMeters(index);
        lower = actions.Lower(index); upper = actions.Upper(index); seconds = actions.AdditionalSeconds(index);
    end
    [state,minimumProven] = targetState150(actions.Upper(1),globalLower,budget,tau);
    necessaryLower = 0;
    if state=="IMPOSSIBLE_IN_SAFE_CLASS"
        assert(isnan(budget),'Inherited lower certificate contradicts a feasible action.');
        necessaryLower = NaN;
    end
    rows{k} = table(caseIndex,name,tau,state,budget,necessaryLower,minimumProven,index,lower,upper,seconds,globalLower, ...
        'VariableNames',{'CaseIndex','Case','TargetRadius','State','FeasibleBudgetUpperMeters','NecessaryBudgetLowerMeters', ...
        'MinimumProven','ActionId','RiskLower','RiskUpper','AdditionalSeconds','InheritedGlobalLower'});
end
targets = vertcat(rows{:});
end

function [state,minimumProven] = targetState150(initialUpper,globalLower,knownBudget,tau)
validateattributes(initialUpper,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(globalLower,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(tau,{'numeric'},{'scalar','real','finite','positive'});
assert(isscalar(knownBudget) && (isnan(knownBudget) || (~isinf(knownBudget) && knownBudget>=0)),'Invalid feasible budget.');
minimumProven = false;
if initialUpper<=tau
    state = "ZERO_ACTION_GUARANTEED"; minimumProven = true;
elseif globalLower>tau
    state = "IMPOSSIBLE_IN_SAFE_CLASS";
elseif ~isnan(knownBudget) && ~isinf(knownBudget)
    state = "FEASIBLE_UPPER_FOUND";
else
    state = "UNRESOLVED";
end
end

function checks = budgetChecks150
checks = check140("budget zero is admitted",isequal(values150([200 0 100 100],false),[0 100 200]),0);
invalid = {[-1 20],[NaN 20],[Inf 20],[],[1+1i 20]};
for k = 1:numel(invalid)
    rejected = false;
    try
        values150(invalid{k},false);
    catch
        rejected = true;
    end
    checks = [checks;check140("invalid movement budget rejected "+k,rejected,double(~rejected))];
end
invalidTau = {[0 20],[-1 20],[NaN 20],[Inf 20],[]};
for k = 1:numel(invalidTau)
    rejected = false;
    try
        values150(invalidTau{k},true);
    catch
        rejected = true;
    end
    checks = [checks;check140("invalid target radius rejected "+k,rejected,double(~rejected))];
end
[state,proven] = targetState150(20,1,0,20);
checks = [checks;check140("initial upper equality proves zero minimum",state=="ZERO_ACTION_GUARANTEED" && proven,0)];
[state,proven] = targetState150(100,20,NaN,20);
checks = [checks;check140("global lower equality does not disprove target",state=="UNRESOLVED" && ~proven,0)];
[state,proven] = targetState150(100,20.001,NaN,20);
checks = [checks;check140("strict inherited lower excludes safe class",state=="IMPOSSIBLE_IN_SAFE_CLASS" && ~proven,0)];
[state,proven] = targetState150(100,1,50,20);
checks = [checks;check140("positive feasible upper does not prove minimum",state=="FEASIBLE_UPPER_FOUND" && ~proven,0)];
actions = table((1:4)',[0;1;2;1.5],[10;8;7;5],[10;9;8;9.5],[0;5.2;5.4;5.3], ...
    'VariableNames',{'ActionId','MoveMeters','Lower','Upper','AdditionalSeconds'});
[dominance,~] = dominance150(actions);
frontier = frontier150(actions,[0 1 1.5 2]);
checks = [checks;check140("overlapping intervals cannot prove risk dominance",~dominance.CertainlyDominated(4) && ~dominance.UpperFrontierRetained(4),0); ...
    check140("finite pool lower retains uncertain upper-dominated action",frontier.FinitePoolLower(end)==5,frontier.FinitePoolLower(end)); ...
    check140("known finite pool envelope monotone",isequal(frontier.GuaranteedUpper,[10;9;9;8]),max(diff(frontier.GuaranteedUpper)))];
end

function result = collect150(details,initialChecks,settings,options,provenance,elapsed)
active = details(~cellfun(@isempty,details));
checks = initialChecks; targets = table; rows = cell(numel(active),1);
for k = 1:numel(active)
    item = active{k}; checks = [checks;item.checks]; targets = [targets;item.targets];
    rows{k} = table(item.caseIndex,item.name,height(item.actions),height(item.paretoActions),height(item.upperFrontier), ...
        item.inheritedGlobalLower,min(item.actions.Upper),item.performance.requests,item.performance.kernelCalls, ...
        item.performance.kernelSeconds,item.elapsedSeconds, ...
        'VariableNames',{'CaseIndex','Case','FineActionsIncludingZero','NotCertainlyDominatedActions','UpperFrontierActions', ...
        'InheritedGlobalLower','BestFoundUpper','ScoreRequests','KernelCalls','KernelSeconds','CaseSeconds'});
end
if isempty(rows)
    summary = table;
else
    summary = vertcat(rows{:});
end
result = struct('version','1.5.1','status','RUNNING','matlabVersion',version,'settings',settings,'options',options, ...
    'provenance',provenance,'details',{details},'summary',summary,'targets',targets,'checks',checks, ...
    'elapsedSeconds',elapsed,'paperEligible',false,'scope','Finite verified action pool; positive feasible budgets are upper bounds only.');
end

function writeCase150(detail,outputRoot)
prefix = sprintf('case_%02d_',detail.caseIndex);
fields = {'actions','dominance','paretoActions','upperFrontier','frontier','targets','searchLog','refinement','checks'};
for k = 1:numel(fields)
    value = detail.(fields{k});
    if ~isempty(value)
        writetable(value,fullfile(outputRoot,[prefix fields{k} '.csv']),'Encoding','UTF-8');
    end
end
end

function figures150(result,outputRoot)
count = numel(result.details);
figureHandle = figure('Visible','off','Color','w','Position',[80 80 1240 820],'PaperPositionMode','auto');
layout = tiledlayout(figureHandle,2,3,'TileSpacing','compact','Padding','loose');
for k = 1:count
    item = result.details{k}; curve = item.frontier; ax = nexttile(layout);
    stairs(ax,curve.BudgetMeters,curve.GuaranteedUpper,'-','LineWidth',1.8,'Color',[0.10 0.33 0.61]);
    hold(ax,'on');
    stairs(ax,curve.BudgetMeters,curve.FinitePoolLower,'--','LineWidth',1.1,'Color',[0.35 0.35 0.35]);
    yline(ax,item.inheritedGlobalLower,':','LineWidth',1.4,'Color',[0.75 0.30 0.08]);
    xlim(ax,[0 max(1,max(curve.BudgetMeters))*1.03]);
    ylim(ax,[0 max(curve.GuaranteedUpper)*1.06]);
    title(ax,item.name); xlabel(ax,'允许移动预算（m）'); ylabel(ax,'最坏定位半径（m）'); grid(ax,'on');
    legend(ax,{'已找到的保证上界','有限动作池最优值下界','继承的连续全域下界'}, ...
        'Location','northeast','FontSize',8,'FontName','Microsoft YaHei');
end
title(layout,{'移动预算增加时，已找到的保证上界不增','灰虚线仅约束有限动作池；未把有限搜索前沿称为连续最优'},'FontName','Microsoft YaHei');
set(findall(figureHandle,'Type','text'),'FontName','Microsoft YaHei');
set(findall(figureHandle,'Type','axes'),'FontName','Microsoft YaHei','FontSize',10,'Box','on');
print(figureHandle,fullfile(outputRoot,'图13_移动预算与风险前沿.png'),'-dpng','-r180');
savefig(figureHandle,fullfile(outputRoot,'图13_移动预算与风险前沿.fig')); close(figureHandle);
figureHandle = figure('Visible','off','Color','w','Position',[80 80 1120 790],'PaperPositionMode','auto');
ax = axes(figureHandle,'Position',[0.13 0.13 0.80 0.70]); hold(ax,'on');
taus = result.options.taus; names = strings(count,1);
for row = 1:count
    item = result.details{row}; names(row) = item.name;
    for column = 1:numel(taus)
        target = item.targets(column,:);
        if target.State=="ZERO_ACTION_GUARANTEED"
            color = [0.89 0.96 0.90]; label = sprintf('0 m\n首测已够，最小预算为0');
        elseif target.State=="IMPOSSIBLE_IN_SAFE_CLASS"
            color = [1.00 0.92 0.90]; label = sprintf('继承全域下界排除\nL > %.3g m',taus(column));
        elseif target.State=="FEASIBLE_UPPER_FOUND"
            color = [0.89 0.94 1.00]; label = sprintf('%.3f m\n已找到的可行预算上界',ceil(target.FeasibleBudgetUpperMeters*1000)/1000);
        else
            color = [0.94 0.94 0.94]; label = sprintf('尚未找到\n不等同于不可能');
        end
        rectangle(ax,'Position',[column-0.46 row-0.43 0.92 0.86],'FaceColor',color,'EdgeColor',[0.65 0.68 0.72]);
        text(ax,column,row,label,'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName','Microsoft YaHei','FontSize',11);
    end
end
set(ax,'YDir','reverse','XTick',1:numel(taus),'XTickLabel',compose('%.3g m',taus), ...
    'YTick',1:count,'YTickLabel',names,'FontName','Microsoft YaHei','FontSize',11,'TickLength',[0 0]);
xlim(ax,[0.4 numel(taus)+0.6]); ylim(ax,[0.35 count+0.65]);
xlabel(ax,'目标定位半径（用户确认的分析阈值）');
title(ax,{'反求预算：正数仅为已找到的可行上界，未证明最小必需移动量', ...
    '零动作直接使用首测后验；连续下界仅沿用完全相同场景与保接收策略的既有证据', ...
    '正预算按0.001 m向上显示；CSV保留未经舍入的预算与坐标'},'FontName','Microsoft YaHei');
box(ax,'off');
print(figureHandle,fullfile(outputRoot,'图13_目标半径与可行预算上界.png'),'-dpng','-r180');
savefig(figureHandle,fullfile(outputRoot,'图13_目标半径与可行预算上界.fig')); close(figureHandle);
workflow150(outputRoot);
end

function result = report150(inputFile,outputRoot)
assert(~isfolder(outputRoot) && ~isfile(outputRoot),'报告输出须为全新路径。');
loaded = load(inputFile,'result');
assert(isfield(loaded,'result'),'研究MAT中缺少结果。'); result = loaded.result;
assert(any(strcmp(result.version,{'1.5.0','1.5.1'})) && strcmp(result.status,'SELF_CHECKED') && all(result.checks.Passed),'只可重导通过检查的1.5系列结果。');
assert(numel(result.details)==6 && all(~cellfun(@isempty,result.details)),'六个固定场景尚未完成。');
mkdir(outputRoot); figures150(result,outputRoot);
metadata = struct('version',result.version,'status',result.status,'matlabVersion',result.matlabVersion, ...
    'sourceResultFile',char(inputFile),'sourceResultSHA256',digest150(inputFile),'reportOnly',true,'paperEligible',false, ...
    'caseCount',6,'targetRadii',result.options.taus,'checks',height(result.checks),'failedChecks',sum(~result.checks.Passed), ...
    'originalElapsedSeconds',result.elapsedSeconds,'sumCaseSeconds',sum(result.summary.CaseSeconds), ...
    'sumKernelCalls',sum(result.summary.KernelCalls),'sumScoreRequests',sum(result.summary.ScoreRequests), ...
    'generatedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
file = fopen(fullfile(outputRoot,'report_metadata.json'),'w','n','UTF-8');
assert(file>=0,'无法写入报告元信息。'); cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s',jsonencode(metadata,'PrettyPrint',true));
fprintf('13/15图表从固定MAT重导，未重新计算实验。\n');
end

function workflow150(outputRoot)
figureHandle = figure('Visible','off','Color','w','Position',[80 80 1220 960],'PaperPositionMode','auto');
positions = [0.30 0.84 0.42 0.08;0.30 0.70 0.42 0.08;0.03 0.70 0.21 0.08; ...
    0.30 0.55 0.42 0.10;0.30 0.40 0.42 0.10;0.03 0.38 0.21 0.15; ...
    0.03 0.19 0.21 0.13;0.30 0.25 0.42 0.09;0.30 0.10 0.42 0.11;0.76 0.10 0.21 0.11];
labels = {'首测输入、目标半径与可用移动预算';'构造首测后验：已有精度是否足够？'; ...
    '足够：采用零动作\newline不增加检测时间'; ...
    '固定预算内搜索与统一精算\newline建立已核验动作池并查继承全域下界'; ...
    '是否存在预算内上界≤目标\newline且已通过保接收复核的动作？'; ...
    '无此动作时：\newline全域下界>目标则排除；\newline否则仍未解决。\newline不得宣称保证目标'; ...
    '队伍可另行决定执行\newline精度优先主方案；\newline明确目标保证尚未成立'; ...
    '执行已选策略：安全复核后移动检测'; ...
    '录入真实 direction / near，更新后验\newline接口待接入：目前需要人工衔接'; ...
    '人工核对实际后验半径\newline与目标，记录达标状态'};
for k = 1:size(positions,1)
    color = [0.92 0.95 0.99]; style = '-';
    if k==3
        color = [0.89 0.96 0.90];
    elseif k==6 || k==7
        color = [1.00 0.92 0.90];
    elseif k>=9
        color = [1.00 0.95 0.86]; style = '--';
    end
    annotation(figureHandle,'textbox',positions(k,:),'String',labels{k},'FitBoxToText','off', ...
        'HorizontalAlignment','center','VerticalAlignment','middle','FontName','Microsoft YaHei', ...
        'FontSize',11,'BackgroundColor',color,'EdgeColor',[0.35 0.42 0.50],'LineWidth',1.2,'LineStyle',style);
end
edges = [1 2;2 4;4 5;5 8;8 9;6 7];
for k = 1:size(edges,1)
    first = positions(edges(k,1),:); last = positions(edges(k,2),:);
    style = '-';
    if edges(k,2)>=9
        style = '--';
    end
    annotation(figureHandle,'arrow',[first(1)+first(3)/2 last(1)+last(3)/2], ...
        [first(2) last(2)+last(4)],'LineWidth',1.2,'LineStyle',style);
end
annotation(figureHandle,'arrow',[0.30 0.24],[0.74 0.74],'LineWidth',1.2);
annotation(figureHandle,'arrow',[0.30 0.24],[0.45 0.45],'LineWidth',1.2);
annotation(figureHandle,'arrow',[0.24 0.30],[0.255 0.295],'LineWidth',1.2,'LineStyle','--');
annotation(figureHandle,'arrow',[0.72 0.76],[0.155 0.155],'LineWidth',1.2,'LineStyle','--');
annotation(figureHandle,'textbox',[0.245 0.745 0.05 0.03],'String','是', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',10);
annotation(figureHandle,'textbox',[0.245 0.455 0.05 0.03],'String','否', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',10);
annotation(figureHandle,'textbox',[0.54 0.35 0.10 0.035],'String','是', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',10);
annotation(figureHandle,'textbox',[0.54 0.655 0.10 0.035],'String','否', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',10);
annotation(figureHandle,'textbox',[0.10 0.95 0.80 0.04],'String','问题二行动流程与当前实现边界', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',16,'HorizontalAlignment','center');
annotation(figureHandle,'textbox',[0.10 0.015 0.80 0.05], ...
    'String','本研究验证规划阶段；未解决分支不取消精度优先主目标。橙色虚线框为人工衔接，并非已实现的自动反馈接口。', ...
    'EdgeColor','none','FontName','Microsoft YaHei','FontSize',11,'HorizontalAlignment','center');
print(figureHandle,fullfile(outputRoot,'图15_行动流程与接口边界.png'),'-dpng','-r180');
savefig(figureHandle,fullfile(outputRoot,'图15_行动流程与接口边界.fig')); close(figureHandle);
end

function distance = posteriorDistance151(polygon,point)
if isempty(polygon)
    distance = inf;
    return
end
if size(polygon,1)==1
    distance = norm(point-polygon(1,:));
    return
end
if size(polygon,1)>=3 && rank(polygon-polygon(1,:))==2 && inpolygon(point(1),point(2),polygon(:,1),polygon(:,2))
    distance = 0;
    return
end
edges = polygon([2:end 1],:)-polygon;
fractions = sum((point-polygon).*edges,2)./max(sum(edges.^2,2),realmin);
projections = polygon+min(1,max(0,fractions)).*edges;
distance = min(vecnorm(projections-point,2,2));
end

function checks = coverageChecks151
square = [-1 -1;1 -1;1 1;-1 1];
outside = [1.1 0];
[center,radius] = enclosingCircle(square);
missedByCircle = norm(outside-center)<radius;
outsideDistance = posteriorDistance151(square,outside);
checks = [check140("polygon interior is covered",posteriorDistance151(square,[0 0])==0,0); ...
    check140("polygon edge is covered",posteriorDistance151(square,[1 0])<1e-12,0); ...
    check140("polygon vertex is covered",posteriorDistance151(square,[1 1])<1e-12,0); ...
    check140("inside circle outside posterior is rejected",missedByCircle && abs(outsideDistance-0.1)<1e-12,outsideDistance); ...
    check140("clockwise posterior distance unchanged",abs(posteriorDistance151(flipud(square),outside)-0.1)<1e-12,0); ...
    check140("segment posterior distance",abs(posteriorDistance151([0 0;2 0],[1 0.4])-0.4)<1e-12,0); ...
    check140("point posterior distance",abs(posteriorDistance151([2 3],[5 7])-5)<1e-12,0); ...
    check140("empty posterior rejects a truth",isinf(posteriorDistance151(zeros(0,2),[0 0])),0); ...
    check140("collinear posterior covers segment",posteriorDistance151([0 0;1 0;2 0],[1 0])<1e-12,0)];
end

function result = verifyCoverage151(settings,options,outputRoot)
assert(isfield(options,'files') && isscalar(fieldnames(options)),'须且只能提供files。');
files = string(options.files);
assert(isvector(files) && ~isempty(files) && all(isfile(files)),'固定结果文件缺失。');
assert(~isfolder(outputRoot) && ~isfile(outputRoot),'输出目录须为全新路径。');
mkdir(outputRoot);
checks = coverageChecks151;
rows = cell(0,1); hashes = strings(numel(files),1);
for fileIndex = 1:numel(files)
    loaded = load(files(fileIndex),'result'); study = loaded.result;
    assert(strcmp(study.status,'SELF_CHECKED') && all(study.checks.Passed),'仅复核已完成的固定结果。');
    hashes(fileIndex) = string(digest150(files(fileIndex)));
    for caseIndex = 1:numel(study.details)
        detail = study.details{caseIndex};
        config = settings;
        if isfield(detail,'spec') && isfield(detail,'item')
            config.delta = detail.spec.delta;
            item = detail.item;
        elseif isfield(detail,'selected')
            config.delta = study.settings.delta;
            item = detail.selected;
        else
            error('未知案例结构。');
        end
        caseChecks = caseChecks140(item,config);
        if norm(item.point)<1e-10
            caseChecks = caseChecks(~endsWith(caseChecks.Check,"_feedback score gap under 0.005m"),:);
        end
        regionRow = endsWith(caseChecks.Check,"_constructed truth posterior region coverage");
        circleRow = endsWith(caseChecks.Check,"_constructed truth posterior enclosing circle coverage");
        assert(sum(regionRow)==1 && sum(circleRow)==1,'后验检查项不完整。');
        rows{end+1,1} = table(fileIndex,caseIndex,string(item.name),config.delta,caseChecks.Error(regionRow), ...
            caseChecks.Error(circleRow),all(caseChecks.Passed), ...
            'VariableNames',{'FileIndex','CaseIndex','Case','DeltaDeg','PosteriorDistanceMeters','CircleResidualMeters','Passed'});
        caseChecks.Check = "file"+fileIndex+"/case"+caseIndex+"/"+caseChecks.Check;
        checks = [checks;caseChecks];
    end
end
summary = vertcat(rows{:});
result = struct('version','1.5.1','status','SELF_CHECKED','matlabVersion',version,'checks',checks, ...
    'summary',summary,'inputFiles',files,'inputSHA256',hashes,'paperEligible',false);
if ~all(checks.Passed)
    result.status = 'FAIL';
end
writetable(checks,fullfile(outputRoot,'checks.csv'),'Encoding','UTF-8');
writetable(summary,fullfile(outputRoot,'summary.csv'),'Encoding','UTF-8');
save(fullfile(outputRoot,'result.mat'),'result');
assert(all(checks.Passed),'后验区域直接包含检查失败。');
fprintf('Posterior coverage SELF_CHECKED: %d cases, %d checks, 0 failures.\n',height(summary),height(checks));
end
