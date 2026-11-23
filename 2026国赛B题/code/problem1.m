function result = problem1(stations, bearings)
if nargin == 0
    result = runStudy();
    return
end
if nargin == 1 && (ischar(stations) || isstring(stations))
    if isequal(stations,'verify') || isequal(stations,"verify")
        result = runChecks();
        return
    end
    if isequal(stations,'group3') || isequal(stations,"group3")
        result = continuousStudy(freshOutput('组3'),true);
        return
    end
    if isequal(stations,'group4') || isequal(stations,"group4")
        result = explanationStudy(freshOutput('组4'),true);
        return
    end
    if isequal(stations,'group5') || isequal(stations,"group5")
        result = timingStudy(freshOutput('组5'));
        return
    end
    error('Q1:InvalidInput', '字符输入支持verify、group3、group4或group5；无参数运行可生成论文算例。');
end
if nargin ~= 2 || ~isnumeric(stations) || ~isreal(stations) || ~ismatrix(stations) || ...
        size(stations,2) ~= 2 || isempty(stations) || ...
        any(~isfinite(stations(:))) || ~isnumeric(bearings) || ...
        ~isreal(bearings) || ~isvector(bearings) || ...
        numel(bearings) ~= size(stations,1) || any(~isfinite(bearings(:)))
    error('Q1:InvalidInput', '输入须为有限实数检测点矩阵(m×2)及同源示向度向量(m×1，单位度)。');
end
stations = double(stations);
bearings = mod(double(bearings(:)),360);
origin = stations(1,:);
scale = max(1,max(abs(stations-origin),[],'all'));
localStations = (stations-origin)/scale;
if any(~isfinite(localStations(:))) || ~isfinite(scale)
    error('Q1:InvalidInput', '坐标跨度超出双精度可用范围。');
end
lineAngles = reshape([bearings-1,bearings+1].',[],1);
matrix = [sind(lineAngles),-cosd(lineAngles)];
matrix(2:2:end,:) = -matrix(2:2:end,:);
offset = sum(matrix.*repelem(localStations,2,1),2);
result = struct('status',"NUMERIC_UNCERTAIN",'message',"", ...
    'regionStatus',"NUMERIC_UNCERTAIN",'diameterStatus',"UNAVAILABLE", ...
    'circleStatus',"NOT_COMPUTED",'diameterBoundsEstimate',[NaN,NaN], ...
    'circleRadiusUpperEstimate',NaN,'pairAudit',zeros(0,8), ...
    'vertices',zeros(0,2),'diameter',NaN,'diameterEndpoints',nan(2,2), ...
    'circleCenter',[NaN,NaN],'circleRadius',NaN,'supportIndices',[], ...
    'supportWeights',[],'diameterCircleCoversWithinTolerance',NaN,'radius20Covers',NaN, ...
    'diameterCircleMaxExcess',NaN,'circleRadiusLowerEstimate',NaN,'circleOptimalityGap',NaN, ...
    'maxConstraintViolation',NaN,'maxCircleViolation',NaN, ...
    'coordinateTolerance',NaN,'recessionDirection',[NaN,NaN], ...
    'A',matrix,'b',offset*scale+matrix*origin.', ...
    'origin',origin,'scale',scale,'normalizedB',offset,'deltaDeg',1);
result.diagnostic = struct('code',"",'constraintRows',[], ...
    'stationIndices',[],'sides',strings(0,1),'values',struct());
result.regionCertificate = struct('status',"NOT_CHECKED");
originalMatrix = matrix;
originalOffset = offset;
[~,keep,group] = unique(matrix,'rows','stable');
sourceRows = zeros(numel(keep),1);
for row = 1:numel(keep)
    members = find(group == row);
    [~,tightest] = min(offset(members));
    sourceRows(row) = members(tightest);
end
offset = accumarray(group,offset,[],@min);
matrix = matrix(keep,:);
lineAngles = lineAngles(keep);
angleOffsets = bearings-bearings(1);
angleOffsets(angleOffsets>180) = angleOffsets(angleOffsets>180)-360;
angleOffsets(angleOffsets<-180) = angleOffsets(angleOffsets<-180)+360;
angleSpread = max(angleOffsets)-min(angleOffsets);
if abs(angleSpread-2) < 1e-9 && angleSpread ~= 2
    result.message = "公共方向接近有界/无界临界角，需提高精度核对。";
    [~,first] = min(angleOffsets);
    [~,second] = max(angleOffsets);
    result = setDiagnostic(result,"CRITICAL_RECESSION",[2*second-1,2*first], ...
        struct('angleSpreadDeg',angleSpread,'gapDeg',angleSpread-2,'thresholdDeg',1e-9));
    return
end
pairCount = size(matrix,1)*(size(matrix,1)-1)/2;
points = zeros(pairCount,2);
pointCount = 0;
equalityNormals = zeros(pairCount,2);
equalityCount = 0;
equalityPairs = zeros(pairCount,2);
audit = zeros(pairCount,8);
auditCount = 0;
for i = 1:size(matrix,1)-1
    for j = i+1:size(matrix,1)
        auditCount = auditCount+1;
        audit(auditCount,1:2) = sourceRows([i,j]);
        gap = mod(lineAngles(j)-lineAngles(i),180);
        if gap == 0
            audit(auditCount,3) = 1;
            if dot(matrix(i,:),matrix(j,:)) < 0
                width = offset(i)+offset(j);
                widthTolerance = 1024*eps(max(1,max(abs(offset([i,j])))));
                audit(auditCount,7:8) = [width,widthTolerance];
                if any(matrix(i,:) ~= -matrix(j,:))
                    result.message = "角度平行但生成法向未精确相反，不能以零间隙强判退化。";
                    result = setDiagnostic(result,"PARALLEL_NORMAL_MISMATCH",sourceRows([i,j]), ...
                        struct('normalResidual',matrix(i,:)+matrix(j,:),'gapMeters',width*scale));
                    return
                end
                if width ~= 0 && abs(width) < widthTolerance
                    result.message = "相向平行约束之间存在极小非零间隙，空集或维数判断不可靠。";
                    result = setDiagnostic(result,"TINY_PARALLEL_GAP",sourceRows([i,j]), ...
                        struct('gapMeters',width*scale,'thresholdMeters',widthTolerance*scale));
                    return
                elseif width < 0
                    result.status = "EMPTY";
                    result.regionStatus = "EMPTY";
                    result.circleStatus = "UNDEFINED";
                    result.message = "一对相向平行约束矛盾，交集为空。";
                    result = setDiagnostic(result,"CONTRADICTORY_PARALLELS",sourceRows([i,j]), ...
                        struct('gapMeters',width*scale,'thresholdMeters',widthTolerance*scale));
                    return
                elseif width == 0
                    equalityCount = equalityCount+1;
                    equalityNormals(equalityCount,:) = matrix(i,:);
                    equalityPairs(equalityCount,:) = sourceRows([i,j]);
                end
            end
            continue
        end
        block = matrix([i,j],:);
        [excluded,witness,margin] = excludedIntersection(matrix,offset,i,j);
        audit(auditCount,4:5) = [det(block),rcond(block)];
        if excluded
            audit(auditCount,3) = 2;
            audit(auditCount,6:7) = [sourceRows(witness),margin];
            continue
        end
        conditionEstimate = rcond(block);
        if conditionEstimate < 1e-10
            result.message = "存在极近乎平行的非平行边界，双精度分类不可靠。";
            result = setDiagnostic(result,"ILL_CONDITIONED_INTERSECTION",sourceRows([i,j]), ...
                struct('determinant',det(block),'rcond',conditionEstimate,'threshold',1e-10));
            return
        end
        point = (block\offset([i,j])).';
        tolerance = 256*eps(max(1,max(abs(point))));
        residual = matrix*point.'-offset;
        if all(residual <= tolerance)
            residual([i,j]) = 0;
            if conditionEstimate < 1e-6 && any(residual > 0)
                result.message = "病态交点依赖正残差容差才能满足其余约束，不能可靠确认远端位置。";
                [violation,witness] = max(residual);
                result = setDiagnostic(result,"SENSITIVE_POSITIVE_RESIDUAL",sourceRows([i,j,witness]), ...
                    struct('rcond',conditionEstimate,'residualMeters',violation*scale, ...
                    'thresholdMeters',tolerance*scale));
                return
            end
            pointCount = pointCount+1;
            points(pointCount,:) = point;
            audit(auditCount,3) = 3;
        else
            result.message = "交点未通过可行性检查，且无可靠排除证据，保留数值未定。";
            [violation,witness] = max(residual);
            result = setDiagnostic(result,"UNRESOLVED_INTERSECTION",sourceRows([i,j,witness]), ...
                struct('rcond',conditionEstimate,'residualMeters',violation*scale));
            return
        end
    end
end
points = points(1:pointCount,:);
equalityNormals = equalityNormals(1:equalityCount,:);
equalityPairs = equalityPairs(1:equalityCount,:);
result.pairAudit = audit(1:auditCount,:);
if isempty(points)
    result.status = "EMPTY";
    result.regionStatus = "EMPTY";
    result.circleStatus = "UNDEFINED";
    result = setDiagnostic(result,"ALL_INTERSECTIONS_EXCLUDED",unique(audit(:,1:2)), ...
        struct('pairCount',auditCount,'excludedCount',nnz(audit(:,3)==2)));
    result.message = "未找到相容位置；应复核同源关系、单位及观测。";
    return
end
tolerance = 1024*eps(max(1,max(abs(points),[],'all')));
vertices = zeros(size(points));
vertices(1,:) = points(1,:);
vertexCount = 1;
for i = 2:size(points,1)
    if all(vecnorm(vertices(1:vertexCount,:)-points(i,:),2,2) > tolerance)
        vertexCount = vertexCount+1;
        vertices(vertexCount,:) = points(i,:);
    end
end
vertices = vertices(1:vertexCount,:);
result.coordinateTolerance = tolerance*scale;
result.vertices = vertices*scale+origin;
if angleSpread <= 2
    directionAngle = bearings(1)+(max(angleOffsets-1)+min(angleOffsets+1))/2;
    direction = [cosd(directionAngle),sind(directionAngle)];
    if any(matrix*direction.' > 0)
        result.message = "公共方向不能满足原始齐次约束，临界舍入下不判无界。";
        [violation,witness] = max(matrix*direction.');
        result = setDiagnostic(result,"RECESSION_RESIDUAL",sourceRows(witness), ...
            struct('angleSpreadDeg',angleSpread,'maxResidual',violation));
        return
    end
    result.status = "UNBOUNDED";
    result.regionStatus = "UNBOUNDED";
    result.diameterStatus = "INFINITE";
    result.circleStatus = "NO_FINITE_CIRCLE";
    result.message = "角度交会区域无界，不存在有限直径或有限覆盖圆。";
    result.diameter = Inf;
    result.circleRadius = Inf;
    result.recessionDirection = direction;
    return
end
if size(vertices,1) == 1
    if rank(equalityNormals,1e-10) < 2 && ~all(stations == stations(1,:),'all')
        result.message = "顶点在容差内合并为一点，但缺少可靠的退化证据。";
        result = setDiagnostic(result,"POINT_WITHOUT_EQUALITIES",unique(equalityPairs), ...
            struct('equalityRank',rank(equalityNormals,1e-10),'toleranceMeters',tolerance*scale));
        return
    end
    result.status = "POINT";
elseif size(vertices,1) == 2
    if isempty(equalityNormals)
        result.message = "仅剩两个可辨顶点，但缺少可靠的线段退化证据。";
        result = setDiagnostic(result,"SEGMENT_WITHOUT_EQUALITY",unique(audit(audit(:,3)==3,1:2)), ...
            struct('toleranceMeters',tolerance*scale));
        return
    end
    result.status = "SEGMENT";
else
    singularValues = svd(vertices-vertices(1,:),0);
    if singularValues(2) <= tolerance*sqrt(size(vertices,1))
        if isempty(equalityNormals)
            result.message = "区域宽度低于容差，但没有精确相向约束支持线段判定。";
            result = setDiagnostic(result,"THIN_WITHOUT_EQUALITY",unique(audit(audit(:,3)==3,1:2)), ...
                struct('singularValuesMeters',singularValues*scale,'toleranceMeters',tolerance*scale));
            return
        end
        [~,pair] = farthestPair(vertices);
        vertices = vertices(pair,:);
        result.status = "SEGMENT";
    elseif singularValues(2) < 1e3*tolerance*sqrt(size(vertices,1))
        result.message = "区域极薄，几何维数在当前精度下不可靠。";
        result = setDiagnostic(result,"THIN_DIMENSION_UNCERTAIN",unique(audit(audit(:,3)==3,1:2)), ...
            struct('singularValuesMeters',singularValues*scale,'toleranceMeters',tolerance*scale));
        return
    else
        hull = convhull(vertices(:,1),vertices(:,2));
        vertices = vertices(hull(1:end-1),:);
        result.status = "BOUNDED_POLYGON";
    end
end
[diameter,pair] = farthestPair(vertices);
certificate = regionCertificate(originalMatrix,originalOffset,vertices,tolerance,equalityPairs);
result.regionCertificate = certificate;
if certificate.status ~= "NUMERIC_CHECKED"
    result.status = "NUMERIC_UNCERTAIN";
    result.message = "区域内外包含核对未通过，不能确认完整顶点集和直径。";
    result = setDiagnostic(result,"REGION_CERTIFICATE_UNCERTAIN",certificate.causeRows, ...
        struct('reason',certificate.reason,'toleranceMeters',tolerance*scale,'certificate',certificate));
    return
end
result.regionStatus = result.status;
result.diameterStatus = "FINITE";
result.vertices = vertices*scale+origin;
result.diameter = diameter*scale;
result.diameterEndpoints = vertices(pair,:)*scale+origin;
result.diameterBoundsEstimate = diameter*scale*[certificate.innerFactor,certificate.outerFactor];
if isfield(certificate,'endpointDistance')
    diameterErrorBound = 2*(certificate.endpointDistance+tolerance)*scale;
    result.diameterBoundsEstimate = [max(0,result.diameter-diameterErrorBound),result.diameter+diameterErrorBound];
end
result.maxConstraintViolation = max(0,max(matrix*vertices.'-offset,[],'all'))*scale;
midpoint = mean(vertices(pair,:),1);
result.diameterCircleMaxExcess = (max(vecnorm(vertices-midpoint,2,2))-diameter/2)*scale;
result.diameterCircleCoversWithinTolerance = double(result.diameterCircleMaxExcess <= tolerance*scale);
result = finishCircle(result,vertices,pair,tolerance);
end

function result = finishCircle(result,vertices,pair,tolerance)
[center,radius,support,weights] = enclosingCircle(vertices,pair,tolerance);
result = certifyCircle(result,vertices,center,radius,support,weights,tolerance);
end

function result = certifyCircle(result,vertices,center,radius,support,weights,tolerance)
scale = result.scale;
origin = result.origin;
diameter = result.diameter/scale;
result.status = "NUMERIC_UNCERTAIN";
result.circleStatus = "NUMERIC_UNCERTAIN";
result.circleCenter = [NaN,NaN];
result.circleRadius = NaN;
result.supportIndices = [];
result.supportWeights = [];
result.circleRadiusLowerEstimate = NaN;
result.circleRadiusUpperEstimate = NaN;
result.circleOptimalityGap = NaN;
result.maxCircleViolation = NaN;
result.radius20Covers = NaN;
if ~isnumeric(center) || ~isreal(center) || ~isequal(size(center),[1,2]) || ...
        any(~isfinite(center)) || ~isnumeric(radius) || ~isreal(radius) || ...
        ~isscalar(radius) || ~isfinite(radius) || radius < 0
    result.message = "圆心或半径不是有效有限参数，拒绝接收候选圆。";
    result = setDiagnostic(result,"INVALID_CIRCLE_PARAMETERS",[],struct());
    return
end
if ~isnumeric(support) || ~isreal(support) || ~isvector(support) || ...
        isempty(support) || numel(support)>3 || any(~isfinite(support)) || ...
        any(support~=fix(support)) || any(support<1 | support>size(vertices,1)) || ...
        numel(unique(support))~=numel(support)
    result.message = "候选圆支撑索引无效，拒绝接收且不访问非法索引。";
    result = setDiagnostic(result,"INVALID_CIRCLE_SUPPORT",[],struct());
    return
end
if ~isnumeric(weights) || ~isreal(weights) || ~isvector(weights) || ...
        numel(weights)~=numel(support) || any(~isfinite(weights))
    result.message = "候选圆支撑权重的类型、数量或有限性不满足要求。";
    result = setDiagnostic(result,"INVALID_CIRCLE_WEIGHTS",[],struct());
    return
end
weights = weights(:);
weightTolerance = 1e-9;
weightSum = sum(weights);
if ~isfinite(weightSum) || min(weights)<-weightTolerance || abs(weightSum-1)>weightTolerance
    result.message = "候选权重不能构成可靠凸组合，拒绝接收候选圆。";
    result = setDiagnostic(result,"INVALID_CIRCLE_WEIGHTS",[], ...
        struct('minimumWeight',min(weights),'weightSum',weightSum,'weightTolerance',weightTolerance));
    return
end
weights = max(weights,0);
weights = weights/sum(weights);
supportPoints = vertices(support,:);
weightedCenter = weights.'*supportPoints;
distances = hypot(vertices(:,1)-center(1),vertices(:,2)-center(2));
centerResidual = hypot(center(1)-weightedCenter(1),center(2)-weightedCenter(2));
coverageExcess = max(distances)-radius;
supportResidual = max(abs(distances(support)-radius));
acceptanceTolerance = 16*tolerance;
if any(~isfinite([distances;centerResidual;coverageExcess;supportResidual]))
    result.message = "圆接收复核产生非有限值，不能输出成功圆。";
    result = setDiagnostic(result,"NONFINITE_CIRCLE_CHECK",[],struct());
    return
end
if centerResidual>acceptanceTolerance || coverageExcess>acceptanceTolerance || ...
        supportResidual>acceptanceTolerance
    result.message = "圆心凸组合、逐顶点覆盖或支撑圆周复核未通过。";
    result = setDiagnostic(result,"CIRCLE_GEOMETRY_REJECTED",[], ...
        struct('centerResidualMeters',centerResidual*scale,'coverageExcessMeters',coverageExcess*scale, ...
        'supportResidualMeters',supportResidual*scale,'thresholdMeters',acceptanceTolerance*scale));
    return
end
lowerRadius = max(diameter/2,sqrt(sum(weights.*sum((supportPoints-weightedCenter).^2,2))));
gap = radius-lowerRadius;
if any(~isfinite([lowerRadius,gap,diameter])) || gap < -16*tolerance || ...
        gap > 16*tolerance || radius > diameter/sqrt(3)+16*tolerance
    result.message = "覆盖半径与支撑下界或平面几何界不一致，当前精度下不输出最优圆。";
    result = setDiagnostic(result,"CIRCLE_CERTIFICATE_UNCERTAIN",[], ...
        struct('radiusMeters',radius*scale,'lowerMeters',lowerRadius*scale,'gapMeters',gap*scale));
    return
end
domainDistance = result.regionCertificate.boundaryDistanceEstimate;
lowerEstimate = max(0,lowerRadius-domainDistance);
upperEstimate = radius+domainDistance;
outputCenter = center*scale+origin;
outputLengths = [radius,lowerEstimate,upperEstimate,upperEstimate-lowerEstimate]*scale;
if ~isfinite(domainDistance) || domainDistance<0 || ...
        any(~isfinite([outputCenter,outputLengths]))
    result.message = "区域误差或米制圆输出非有限，拒绝接收候选圆。";
    result = setDiagnostic(result,"INVALID_CIRCLE_OUTPUT",[],struct());
    return
end
result.status = result.regionStatus;
result.circleStatus = "OPTIMAL_NUMERIC";
result.circleCenter = outputCenter;
result.circleRadius = outputLengths(1);
result.supportIndices = support;
result.supportWeights = weights;
result.circleRadiusLowerEstimate = lowerEstimate*scale;
result.circleRadiusUpperEstimate = upperEstimate*scale;
result.circleOptimalityGap = max(0,upperEstimate-lowerEstimate)*scale;
result.maxCircleViolation = max(0,coverageExcess)*scale;
if (upperEstimate+16*tolerance)*scale < 20
    result.radius20Covers = 1;
elseif (lowerEstimate-16*tolerance)*scale > 20
    result.radius20Covers = 0;
end
result.message = "已计算纯示向度交会区域；维数及等式判定采用记录的数值容差。";
result = setDiagnostic(result,"",[],struct());
end

function [excluded,witness,margin] = excludedIntersection(matrix,offset,i,j)
first = matrix(i,:);
second = matrix(j,:);
products = [first(1)*second(2),first(2)*second(1); ...
    offset(i)*second(2),first(2)*offset(j); ...
    first(1)*offset(j),offset(i)*second(1)];
values = products(:,1)-products(:,2);
errors = 8*(eps(abs(products(:,1)))+eps(abs(products(:,2)))+eps(abs(values)));
determinant = values(1);
excluded = false;
witness = 1;
margin = NaN;
if abs(determinant) <= errors(1)
    return
end
numerator = values(2:3);
terms = [matrix(:,1)*numerator(1),matrix(:,2)*numerator(2),offset*determinant];
partial = terms(:,1)+terms(:,2);
residual = partial-terms(:,3);
errorBound = 8*(abs(matrix)*errors(2:3)+abs(offset)*errors(1)+ ...
    sum(eps(abs(terms)),2)+eps(abs(partial))+eps(abs(residual)));
[margin,witness] = max(sign(determinant)*residual-errorBound);
excluded = margin > 0;
end

function result = setDiagnostic(result,code,rows,values)
rows = rows(:).';
result.diagnostic.code = code;
result.diagnostic.constraintRows = rows;
result.diagnostic.stationIndices = ceil(rows/2);
sides = repmat("lower",size(rows));
sides(mod(rows,2)==0) = "upper";
result.diagnostic.sides = sides;
result.diagnostic.values = values;
end

function certificate = regionCertificate(matrix,offset,vertices,tolerance,equalityPairs)
certificate = struct('status',"NUMERIC_UNCERTAIN",'reason',"",'causeRows',[], ...
    'innerFactor',NaN,'outerFactor',NaN,'scope',"Generated double halfplanes; numerical evidence");
if size(vertices,1) <= 2
    certificate = degenerateCertificate(certificate,matrix,offset,vertices,tolerance,equalityPairs);
    return
end
directions = [1,0;-1,0;0,1;0,-1];
boxBounds = zeros(4,1);
boxErrors = zeros(4,1);
boxRows = zeros(4,2);
boxWeights = zeros(4,2);
boxAttempts = cell(4,1);
for row = 1:4
    [bound,normalError,indices,weights,attempt] = dualBound(matrix,offset,directions(row,:),0);
    boxBounds(row) = bound;
    boxErrors(row) = normalError;
    boxRows(row,:) = indices;
    boxWeights(row,:) = weights;
    boxAttempts{row} = attempt;
end
rho = max(boxErrors);
certificate.boxConstraints = boxRows;
certificate.boxWeights = boxWeights;
certificate.boxNormalError = boxErrors;
if any(~isfinite(boxBounds)) || rho >= 0.5
    certificate.reason = "NO_INDEPENDENT_FINITE_BOUND";
    missing = ~isfinite(boxBounds) | boxErrors >= 0.5;
    certificate.unresolvedDirections = directions(missing,:);
    certificate.boundAttempts = boxAttempts(missing);
    causes = zeros(8,1);
    causeCount = 0;
    for row = find(missing).'
        rows = boxAttempts{row}.constraintRows(:);
        causes(causeCount+(1:numel(rows))) = rows;
        causeCount = causeCount+numel(rows);
    end
    certificate.causeRows = unique(causes(causes>0)).';
    return
end
boxRadius = max(0,max(boxBounds))/(1-rho);
certificate.boxRadiusEstimate = boxRadius;
center = mean(vertices,1);
[centerResidual,centerRounding] = halfplaneResidual(matrix,offset,center);
marginLower = -centerResidual-centerRounding;
certificate.minimumInteriorSlack = min(marginLower);
if any(marginLower <= 0)
    certificate.reason = "NO_RESOLVED_STRICT_INTERIOR";
    certificate.causeRows = find(marginLower <= 0);
    return
end
[vertexResidual,vertexRounding] = halfplaneResidual(matrix,offset,vertices);
violations = max(0,max(vertexResidual+vertexRounding,[],2));
shrink = max(violations./(marginLower+violations));
count = size(vertices,1);
edgeRows = zeros(count,2);
edgeWeights = zeros(count,2);
edgeErrors = zeros(count,1);
edgeGaps = zeros(count,1);
edgeNormals = zeros(count,2);
edgeOffsets = zeros(count,1);
expansion = zeros(count,1);
for row = 1:count
    first = vertices(row,:);
    second = vertices(mod(row,count)+1,:);
    edge = second-first;
    normal = [edge(2),-edge(1)]/norm(edge);
    height = dot(normal,first);
    if dot(normal,center)>height
        normal = -normal;
        height = -height;
    end
    [upper,normalError,indices,weights] = dualBound(matrix,offset,normal,boxRadius);
    rounding = 8*(sum(eps(abs(normal.*first)))+eps(abs(height)));
    centerError = 8*(sum(eps(abs(normal.*center)))+eps(abs(dot(normal,center))));
    edgeRows(row,:) = indices;
    edgeWeights(row,:) = weights;
    edgeErrors(row) = normalError;
    edgeGaps(row) = upper-height+rounding;
    edgeNormals(row,:) = normal;
    edgeOffsets(row) = height;
    slack = height-dot(normal,center)-rounding-centerError;
    if slack <= 0 || ~isfinite(upper)
        certificate.reason = "UNRESOLVED_HULL_EDGE";
        certificate.causeRows = indices(indices>0);
        return
    end
    expansion(row) = max(0,edgeGaps(row))/slack;
end
growth = max(expansion);
radius = max(vecnorm(vertices-center,2,2));
certificate.edgeConstraints = edgeRows;
certificate.edgeWeights = edgeWeights;
certificate.edgeNormalError = edgeErrors;
certificate.edgeUpperGap = edgeGaps;
certificate.edgeNormals = edgeNormals;
certificate.edgeOffsets = edgeOffsets;
certificate.innerFactor = 1-shrink;
certificate.outerFactor = 1+growth;
certificate.center = center;
certificate.innerDistanceEstimate = shrink*radius;
certificate.outerDistanceEstimate = growth*radius;
certificate.boundaryDistanceEstimate = max(shrink,growth)*radius;
certificate.acceptanceTolerance = 128*tolerance;
if certificate.boundaryDistanceEstimate > certificate.acceptanceTolerance
    certificate.reason = "INNER_OUTER_GAP_TOO_LARGE";
    [~,edge] = max(expansion);
    certificate.causeRows = edgeRows(edge,edgeRows(edge,:)>0);
    return
end
certificate.status = "NUMERIC_CHECKED";
certificate.reason = "INNER_AND_OUTER_HOMOTHETIC_CONTAINMENT";
end

function [residual,rounding] = halfplaneResidual(matrix,offset,points)
first = matrix(:,1)*points(:,1).';
second = matrix(:,2)*points(:,2).';
partial = first+second;
residual = partial-offset;
rounding = 8*(eps(abs(first))+eps(abs(second))+eps(abs(partial))+eps(abs(residual)));
end

function [upper,normalError,indices,weights,attempt] = dualBound(matrix,offset,direction,radius)
count = size(matrix,1);
upper = Inf;
normalError = Inf;
indices = [0,0];
weights = [0,0];
attempt = struct('constraintRows',[],'normalErrorBound',Inf,'rcond',NaN, ...
    'normalErrorThreshold',1e-8);
for first = 1:count
    if isequal(direction,matrix(first,:)) && offset(first)<upper
        upper = offset(first);
        normalError = 0;
        indices = [first,first];
        weights = [1,0];
    end
    for second = first:count
        if first == second
            trialWeights = [dot(direction,matrix(first,:))/dot(matrix(first,:),matrix(first,:));0];
        else
            block = matrix([first,second],:).';
            if rcond(block) < 1e-12
                continue
            end
            trialWeights = block\direction.';
        end
        if any(trialWeights < 0)
            continue
        end
        block = matrix([first,second],:);
        terms = trialWeights.*block;
        partial = sum(terms,1);
        residual = direction-partial;
        residualSize = norm(residual,1);
        normalErrorBound = residualSize+8*(sum(eps(abs(terms)),'all')+ ...
            sum(eps(abs(partial)))+sum(eps(abs(residual)))+eps(residualSize));
        if normalErrorBound < attempt.normalErrorBound
            attempt.constraintRows = [first,second];
            attempt.normalErrorBound = normalErrorBound;
            attempt.rcond = rcond(block.');
        end
        if ~isfinite(normalErrorBound) || normalErrorBound > 1e-8
            continue
        end
        products = trialWeights.*offset([first,second]);
        bound = sum(products)+8*sum(eps(abs(products)))+8*eps(abs(sum(products)))+ ...
            radius*normalErrorBound+8*eps(abs(radius*normalErrorBound));
        if bound < upper
            upper = bound;
            normalError = normalErrorBound;
            indices = [first,second];
            weights = trialWeights.';
        end
    end
end
end

function certificate = degenerateCertificate(certificate,matrix,offset,vertices,tolerance,equalityPairs)
certificate.equalityConstraints = equalityPairs;
if isempty(equalityPairs)
    if size(vertices,1)==1 && all(offset==0) && all(vertices==0,'all')
        certificate.status = "NUMERIC_CHECKED";
        certificate.reason = "HOMOGENEOUS_POINT_WITHOUT_RECESSION";
        certificate.innerFactor = 1;
        certificate.outerFactor = 1;
        certificate.boundaryDistanceEstimate = tolerance;
    else
        certificate.reason = "NO_EXACT_OPPOSITE_EQUALITY";
    end
    return
end
rows = equalityPairs(1,:);
normal = matrix(rows(1),:);
height = offset(rows(1));
certificate.causeRows = rows;
if any(normal ~= -matrix(rows(2),:)) || height ~= -offset(rows(2))
    certificate.reason = "EQUALITY_NOT_EXACT";
    return
end
[~,pivot] = max(abs(normal));
anchor = [0,0];
anchor(pivot) = height/normal(pivot);
direction = [-normal(2),normal(1)];
lower = -Inf;
upper = Inf;
active = [0,0];
for row = 1:size(matrix,1)
    slope = dot(matrix(row,:),direction);
    remaining = offset(row)-dot(matrix(row,:),anchor);
    if slope == 0
        if remaining < 0
            certificate.reason = "UNRESOLVED_PARALLEL_IN_REDUCTION";
            certificate.causeRows = row;
            return
        end
    elseif abs(slope) < 1e-10
        certificate.reason = "ILL_CONDITIONED_INTERVAL_ENDPOINT";
        certificate.causeRows = row;
        return
    elseif slope > 0
        value = remaining/slope;
        if value < upper
            upper = value;
            active(2) = row;
        end
    else
        value = remaining/slope;
        if value > lower
            lower = value;
            active(1) = row;
        end
    end
end
certificate.interval = [lower,upper];
certificate.endpointConstraints = active;
if ~isfinite(lower) || ~isfinite(upper) || lower > upper
    certificate.reason = "UNRESOLVED_INTERVAL";
    return
end
expected = anchor+[lower;upper]*direction;
distance = pointSetDistance(vertices,expected);
certificate.endpointDistance = distance;
certificate.boundaryDistanceEstimate = distance+tolerance;
if distance > 128*tolerance
    certificate.reason = "INTERVAL_ENDPOINT_MISMATCH";
    return
end
certificate.status = "NUMERIC_CHECKED";
certificate.reason = "EXACT_EQUALITY_AND_INDEPENDENT_INTERVAL_REDUCTION";
certificate.innerFactor = 1;
certificate.outerFactor = 1;
end

function [diameter,pair] = farthestPair(vertices)
diameter = 0;
pair = [1,1];
for i = 1:size(vertices,1)-1
    for j = i+1:size(vertices,1)
        distance = norm(vertices(i,:)-vertices(j,:));
        if distance > diameter
            diameter = distance;
            pair = [i,j];
        end
    end
end
end

function [center,radius,support,weights] = enclosingCircle(vertices,pair,tolerance)
center = mean(vertices(pair,:),1);
radius = norm(vertices(pair(1),:)-center);
support = unique(pair,'stable');
weights = ones(numel(support),1)/numel(support);
if all(vecnorm(vertices-center,2,2) <= radius+tolerance)
    radius = max(vecnorm(vertices-center,2,2));
    return
end
radius = Inf;
for i = 1:size(vertices,1)-2
    for j = i+1:size(vertices,1)-1
        for k = j+1:size(vertices,1)
            differences = vertices([j,k],:)-vertices(i,:);
            if rcond(differences) < 1e-12
                continue
            end
            trialCenter = vertices(i,:)+(2*differences\sum(differences.^2,2)).';
            trialRadius = norm(trialCenter-vertices(i,:));
            if trialRadius < radius && ...
                    all(vecnorm(vertices-trialCenter,2,2) <= trialRadius+tolerance)
                barycentric = differences.'\(trialCenter-vertices(i,:)).';
                trialWeights = [1-sum(barycentric);barycentric];
                if min(trialWeights) < -1e-9
                    continue
                end
                center = trialCenter;
                radius = max(vecnorm(vertices-center,2,2));
                support = [i,j,k];
                weights = trialWeights;
            end
        end
    end
end
end

function study = runStudy()
outputDir = freshOutput('算例');
stationsSquare = [-1000,0;0,-1000];
bearingsSquare = [0;90];
stationsTriangle = [-1000,0;540,-500*sqrt(3);520,520*sqrt(3)];
bearingsTriangle = [1;121;241];
square = problem1(stationsSquare,bearingsSquare);
triangle = problem1(stationsTriangle,bearingsTriangle);
exportCase(outputDir,'两点交会',stationsSquare,bearingsSquare,square);
exportCase(outputDir,'三角形反例',stationsTriangle,bearingsTriangle,triangle);
summary = table(["两点交会（构造）";"三角形反例（构造）"], ...
    [size(square.vertices,1);size(triangle.vertices,1)], ...
    [square.diameter;triangle.diameter],[square.circleRadius;triangle.circleRadius], ...
    [square.circleCenter(1);triangle.circleCenter(1)], ...
    [square.circleCenter(2);triangle.circleCenter(2)], ...
    [square.diameterCircleCoversWithinTolerance;triangle.diameterCircleCoversWithinTolerance], ...
    'VariableNames',{'案例','顶点数','区域直径_m','最小覆盖半径_m', ...
    '圆心东坐标_m','圆心北坐标_m','同直径圆容差内覆盖'});
writetable(summary,fullfile(outputDir,'结果总表.csv'),'Encoding','UTF-8');
angles = [10;30;60;90];
errors = [-1;0;1];
observations = zeros(36,7);
metrics = zeros(36,7);
row = 0;
for i = 1:numel(angles)
    stations = [-1000,0;-1000*cosd(angles(i)),-1000*sind(angles(i))];
    for j = 1:3
        for k = 1:3
            row = row+1;
            bearings = [errors(j);angles(i)+errors(k)];
            geometry = problem1(stations,bearings);
            if geometry.status ~= "BOUNDED_POLYGON"
                error('Q1:StudyFailed','受控算例未得到可靠有界多边形。');
            end
            truthResidual = max(geometry.A*[0;0]-geometry.b);
            observations(row,:) = [row,stations(1,:),bearings(1),stations(2,:),bearings(2)];
            metrics(row,:) = [angles(i),errors(j),errors(k),geometry.diameter, ...
                geometry.circleRadius,norm(geometry.circleCenter),truthResidual];
        end
    end
end
inputTable = array2table(observations,'VariableNames',{'案例编号', ...
    '测点1东坐标_m','测点1北坐标_m','示向度1_deg','测点2东坐标_m', ...
    '测点2北坐标_m','示向度2_deg'});
sweepTable = array2table([(1:36).',metrics],'VariableNames',{'案例编号', ...
    '真实交会夹角_deg','误差1_deg','误差2_deg','区域直径_m','最小覆盖半径_m', ...
    '圆心至构造真值距离_m','真值最大约束残差_m'});
writetable(inputTable,fullfile(outputDir,'受控算例输入.csv'),'Encoding','UTF-8');
writetable(sweepTable,fullfile(outputDir,'受控算例逐例结果.csv'),'Encoding','UTF-8');
comparison = zeros(4,6);
for i = 1:4
    rows = metrics(:,1) == angles(i);
    baseline = rows & metrics(:,2) == 0 & metrics(:,3) == 0;
    comparison(i,:) = [angles(i),min(metrics(rows,4)),metrics(baseline,4), ...
        max(metrics(rows,4)),max(2*metrics(rows,5)),max(metrics(rows,6))];
end
comparisonTable = array2table(comparison,'VariableNames',{'真实交会夹角_deg', ...
    '最小直径_m','零误差直径_m','最大直径_m','最大覆盖圆直径_m','最大圆心偏差_m'});
writetable(comparisonTable,fullfile(outputDir,'受控几何比较.csv'),'Encoding','UTF-8');
plotCase(outputDir,'图1_两点交会',stationsSquare,bearingsSquare,square,[0,0],false);
plotCase(outputDir,'图2_同直径圆覆盖反例',stationsTriangle,bearingsTriangle, ...
    triangle,[20,20*sqrt(3)/3],true);
plotStudy(outputDir,comparison);
[multiInput,multiTable,multiGeometry] = multiStationStudy();
writetable(multiInput,fullfile(outputDir,'多测点输入.csv'),'Encoding','UTF-8');
writetable(multiTable,fullfile(outputDir,'多测点逐步交会.csv'),'Encoding','UTF-8');
plotMultiStation(outputDir,multiTable,multiGeometry);
[twoStationTable,twoStationCases] = twoStationStudy(outputDir,true);
continuous = continuousStudy(outputDir,true);
study = struct('version','1.6','outputDir',outputDir,'square',square, ...
    'triangle',triangle,'summary',summary,'sweepTable',sweepTable, ...
    'comparisonTable',comparisonTable,'multiInput',multiInput,'multiTable',multiTable, ...
    'multiGeometry',{multiGeometry},'twoStationTable',twoStationTable, ...
    'twoStationCases',{twoStationCases},'continuous',continuous, ...
    'matlabVersion',version,'release',version('-release'));
study.explanation = explanationStudy(outputDir,true,study);
study.timing = timingStudy(outputDir);
save(fullfile(outputDir,'算例结果.mat'),'study');
writeText(fullfile(outputDir,'算例说明.txt'),sprintf([ ...
    '本目录全部为自建几何算例，不是官方观测或模拟器成绩。\n' ...
    '纯示向度误差界固定为正负1度；未加入圆域或接收距离截断。\n' ...
    '受控算例真实源为(0,0)，两测点到源距离均为1000米。\n' ...
    '四种夹角，各枚举{-1,0,1}度误差的九种组合，共36例。\n' ...
    '零误差只是其中一种构造，不表示测量无误差。\n' ...
    '数值属于所列离散条件，不代表全部误差上的最坏界或概率统计。\n' ...
    '多测点实验使用固定的8个全向相容观测，依次加入第3至8个测点。\n' ...
    '各阶段同时用独立逐半平面裁剪核对顶点；裁剪初始框由前两站解析解保证包含区域。\n' ...
    '第2组另含两站一般几何分类、显式顶点与严格两站反例；不代表连续误差研究。\n' ...
    '第3组另给限定几何下连续误差定理、外包上下界与稳定性；不改变上述离散表含义。\n' ...
    'MATLAB版本：%s，发布版：%s。\n'],version,version('-release')));
disp(summary);
fprintf('已生成两组主算例、36组受控比较及7阶段多测点实验，结果目录：%s\n',outputDir);
end

function [inputTable,stageTable,geometries] = multiStationStudy()
angles = [0;90;210;310;135;45;260;170];
errors = [0;0;0.65;-0.4;0.8;-0.7;0.3;-0.2];
stations = -1000*[cosd(angles),sind(angles)];
bearings = mod(angles+errors,360);
inputTable = array2table([(1:8).',stations,angles,errors,bearings], ...
    'VariableNames',{'测点编号','东坐标_m','北坐标_m','真实方位_deg','固定误差_deg','示向度_deg'});
metrics = zeros(7,11);
geometries = cell(7,1);
for count = 2:8
    geometry = problem1(stations(1:count,:),bearings(1:count));
    if geometry.status ~= "BOUNDED_POLYGON"
        error('Q1:StudyFailed','多测点构造未得到可靠多边形。');
    end
    reference = clipReference(stations(1:count,:),bearings(1:count));
    referenceError = pointSetDistance(geometry.vertices,reference);
    truthResidual = max(-geometry.b);
    metrics(count-1,:) = [count,size(geometry.vertices,1),geometry.diameter, ...
        geometry.circleRadius,2*geometry.circleRadius/geometry.diameter, ...
        geometry.radius20Covers,geometry.circleOptimalityGap,referenceError, ...
        truthResidual,geometry.circleCenter];
    geometries{count-1} = geometry;
end
if any(diff(metrics(:,3:4),1,1)>1e-7,'all') || any(metrics(:,8)>1e-7) || any(metrics(:,9)>1e-7)
    error('Q1:StudyFailed','多测点单调性、裁剪复核或真值相容性未通过。');
end
stageTable = array2table(metrics,'VariableNames',{'累计测点数','顶点数','区域直径_m', ...
    '最小覆盖半径_m','覆盖半径相对D半径倍数','半径20容差判定','圆半径证书间隙_m', ...
    '独立裁剪顶点差_m','真值最大约束残差_m','圆心东坐标_m','圆心北坐标_m'});
end

function polygon = clipReference(stations,bearings,box)
if nargin < 3
    box = [100,100];
end
polygon = [-box(1),-box(2);box(1),-box(2);box(1),box(2);-box(1),box(2)];
for row = 1:size(stations,1)
    for side = [-1,1]
        angle = bearings(row)+side;
        normal = side*[-sind(angle),cosd(angle)];
        offset = dot(normal,stations(row,:));
        output = zeros(2*size(polygon,1),2);
        count = 0;
        for edge = 1:size(polygon,1)
            first = polygon(edge,:);
            second = polygon(mod(edge,size(polygon,1))+1,:);
            firstValue = dot(normal,first)-offset;
            secondValue = dot(normal,second)-offset;
            if firstValue <= 0
                count = count+1;
                output(count,:) = first;
            end
            if (firstValue < 0 && secondValue > 0) || (firstValue > 0 && secondValue < 0)
                count = count+1;
                output(count,:) = first+firstValue/(firstValue-secondValue)*(second-first);
            end
        end
        polygon = output(1:count,:);
        if isempty(polygon)
            return
        end
    end
end
end

function plotMultiStation(outputDir,stageTable,geometries)
fig = figure('Visible','off','Color','w','Position',[100,100,1250,520]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax = nexttile(layout);
hold(ax,'on');
colors = [0.1,0.3,0.55;0.7,0.2,0.15;0.2,0.5,0.3];
styles = {'--','-.','-'};
selection = [1,3,7];
handles = gobjects(3,1);
for i = 1:3
    vertices = geometries{selection(i)}.vertices;
    closedVertices = vertices([1:end,1],:);
    handles(i) = plot(ax,closedVertices(:,1),closedVertices(:,2),styles{i},'Color',colors(i,:), ...
        'LineWidth',1.7);
end
truthHandle = scatter(ax,0,0,55,'k','x','LineWidth',1.5);
axis(ax,'equal');
xlim(ax,[-23,23]);
ylim(ax,[-23,23]);
grid(ax,'on');
xlabel(ax,'东坐标 x / m');
ylabel(ax,'北坐标 y / m');
title(ax,'(a) 同一源的相容观测逐步收紧区域','Interpreter','none');
legend(ax,[handles;truthHandle],{'2个测点','4个测点','8个测点','构造真值'}, ...
    'Location','southoutside','NumColumns',2,'Interpreter','none');
ax = nexttile(layout);
counts = stageTable{:,1};
diameters = stageTable{:,3};
radii = stageTable{:,4};
plot(ax,counts,diameters/2,'--s','Color',colors(1,:),'LineWidth',1.4);
hold(ax,'on');
plot(ax,counts,radii,'-o','Color',colors(2,:),'LineWidth',1.8,'MarkerFaceColor','w');
plot(ax,counts,diameters/sqrt(3),':d','Color',colors(3,:),'LineWidth',1.6);
yline(ax,20,'k-.','LineWidth',1.1);
xticks(ax,counts);
xlim(ax,[1.7,8.3]);
ylim(ax,[14,31]);
grid(ax,'on');
xlabel(ax,'累计检测点数');
ylabel(ax,'半径 / m');
title(ax,'(b) 覆盖半径位于两个紧确界之间','Interpreter','none');
legend(ax,{'下界 D/2','最小覆盖半径','上界 D/√3','20 m'}, ...
    'Location','southoutside','NumColumns',2,'Interpreter','none');
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,'图4_多测点交会与覆盖界.png'),'Resolution',250);
savefig(fig,fullfile(outputDir,'图4_多测点交会与覆盖界.fig'));
end

function exportCase(outputDir,name,stations,bearings,geometry)
inputTable = array2table([(1:size(stations,1)).',stations,bearings], ...
    'VariableNames',{'测点编号','东坐标_m','北坐标_m','示向度_deg'});
vertexTable = array2table([(1:size(geometry.vertices,1)).',geometry.vertices], ...
    'VariableNames',{'顶点编号','东坐标_m','北坐标_m'});
writetable(inputTable,fullfile(outputDir,[name,'_输入.csv']),'Encoding','UTF-8');
writetable(vertexTable,fullfile(outputDir,[name,'_顶点.csv']),'Encoding','UTF-8');
end

function plotCase(outputDir,name,stations,bearings,geometry,truth,isCounterexample)
fig = figure('Visible','off','Color','w','Position',[100,100,1280,550]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax = nexttile(layout);
hold(ax,'on');
colors = [0.1,0.3,0.55;0.75,0.3,0.1;0.2,0.5,0.3];
for i = 1:size(stations,1)
    distance = 1.1*norm(truth-stations(i,:));
    for shift = [-1,1]
        finish = stations(i,:)+distance*[cosd(bearings(i)+shift),sind(bearings(i)+shift)];
        plot(ax,[stations(i,1),finish(1)],[stations(i,2),finish(2)],'--', ...
            'Color',colors(i,:),'LineWidth',1,'HandleVisibility','off');
    end
    finish = stations(i,:)+distance*[cosd(bearings(i)),sind(bearings(i))];
    plot(ax,[stations(i,1),finish(1)],[stations(i,2),finish(2)],'-', ...
        'Color',colors(i,:),'LineWidth',1.2,'HandleVisibility','off');
    scatter(ax,stations(i,1),stations(i,2),40,'k','filled','HandleVisibility','off');
    text(ax,stations(i,1),stations(i,2),sprintf('  S%d',i),'FontSize',11, ...
        'VerticalAlignment','bottom','Interpreter','none');
end
patch(ax,geometry.vertices(:,1),geometry.vertices(:,2),[0.4,0.75,0.85], ...
    'FaceAlpha',0.5,'EdgeColor',[0.1,0.25,0.4],'HandleVisibility','off');
scatter(ax,truth(1),truth(2),35,'k','x','HandleVisibility','off');
axis(ax,'equal');
extent = [stations;geometry.vertices];
padding = 0.09*max(max(extent)-min(extent));
xlim(ax,[min(extent(:,1))-padding,max(extent(:,1))+padding]);
ylim(ax,[min(extent(:,2))-padding,max(extent(:,2))+padding]);
grid(ax,'on');
title(ax,'(a) 自建测向几何：实线为示向度，虚线为±1°','Interpreter','none');
xlabel(ax,'东坐标 x / m');
ylabel(ax,'北坐标 y / m');
ax = nexttile(layout);
hold(ax,'on');
polygonHandle = patch(ax,geometry.vertices(:,1),geometry.vertices(:,2),[0.6,0.8,0.88], ...
    'FaceAlpha',0.35,'EdgeColor',[0.1,0.25,0.4],'LineWidth',1.5);
phase = linspace(0,2*pi,500).';
circle = geometry.circleCenter+geometry.circleRadius*[cos(phase),sin(phase)];
extent = [geometry.vertices;circle];
circleHandle = plot(ax,circle(:,1),circle(:,2),'-','Color',[0.65,0.15,0.15],'LineWidth',1.8);
diameterHandle = plot(ax,geometry.diameterEndpoints(:,1),geometry.diameterEndpoints(:,2), ...
    'k-.','LineWidth',1.4);
centerHandle = scatter(ax,geometry.circleCenter(1),geometry.circleCenter(2),55, ...
    [0.65,0.15,0.15],'+','LineWidth',1.7);
if isCounterexample
    midpoint = mean(geometry.diameterEndpoints,1);
    trialCircle = midpoint+geometry.diameter/2*[cos(phase),sin(phase)];
    extent = [extent;trialCircle];
    trialHandle = plot(ax,trialCircle(:,1),trialCircle(:,2),'--','Color',[0.2,0.45,0.2],'LineWidth',1.4);
    legend(ax,[polygonHandle,diameterHandle,circleHandle,trialHandle,centerHandle], ...
        {'定位区域','区域直径','最小包围圆','某一直径圆（半径D/2）','最小包围圆圆心'}, ...
        'Location','southoutside','NumColumns',2,'Interpreter','none');
else
    legend(ax,[polygonHandle,diameterHandle,circleHandle,centerHandle], ...
        {'定位区域','区域直径','最小包围圆','圆心'}, ...
        'Location','southoutside','NumColumns',2,'Interpreter','none');
end
scatter(ax,geometry.vertices(:,1),geometry.vertices(:,2),25,'k','filled','HandleVisibility','off');
axis(ax,'equal');
padding = 0.09*max(max(extent)-min(extent));
xlim(ax,[min(extent(:,1))-padding,max(extent(:,1))+padding]);
ylim(ax,[min(extent(:,2))-padding,max(extent(:,2))+padding]);
grid(ax,'on');
title(ax,sprintf('(b) 局部：D=%.4f m，最小覆盖半径=%.4f m', ...
    geometry.diameter,geometry.circleRadius),'Interpreter','none');
xlabel(ax,'东坐标 x / m');
ylabel(ax,'北坐标 y / m');
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,[name,'.png']),'Resolution',250);
savefig(fig,fullfile(outputDir,[name,'.fig']));
end

function plotStudy(outputDir,comparison)
fig = figure('Visible','off','Color','w','Position',[100,100,1100,470]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ax = nexttile(layout);
plot(ax,comparison(:,1),comparison(:,3),'-o','Color',[0.1,0.3,0.55], ...
    'LineWidth',1.6,'MarkerFaceColor','w');
hold(ax,'on');
plot(ax,comparison(:,1),comparison(:,4),'--s','Color',[0.7,0.2,0.15],'LineWidth',1.6);
grid(ax,'on');
xticks(ax,comparison(:,1));
xlim(ax,[5,95]);
ylim(ax,[0,1.1*max(comparison(:,4))]);
xlabel(ax,'两测点真实交会夹角 / °');
ylabel(ax,'定位区域直径 / m');
title(ax,'(a) 同为1000 m测距，不同交会夹角','Interpreter','none');
legend(ax,{'零误差构造','九种误差组合中的最大值'},'Location','northeast','Interpreter','none');
ax = nexttile(layout);
plot(ax,comparison(:,1),comparison(:,6),'-d','Color',[0.45,0.2,0.5],'LineWidth',1.6);
grid(ax,'on');
xticks(ax,comparison(:,1));
xlim(ax,[5,95]);
ylim(ax,[0,1.1*max(comparison(:,6))]);
xlabel(ax,'两测点真实交会夹角 / °');
ylabel(ax,'圆心至构造真值距离 / m');
title(ax,'(b) 九种误差组合中的最大圆心偏差','Interpreter','none');
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,'图3_受控几何比较.png'),'Resolution',250);
savefig(fig,fullfile(outputDir,'图3_受控几何比较.fig'));
end

function styleFigure(fig)
set(findall(fig,'-property','FontName'),'FontName','Microsoft YaHei');
set(findall(fig,'-property','FontSize'),'FontSize',11);
set(findall(fig,'Type','axes'),'Box','on');
end

function checks = runChecks()
outputDir = freshOutput('验证');
names = strings(0,1);
passed = false(0,1);
details = strings(0,1);
stations = [-1000,0;540,-500*sqrt(3);520,520*sqrt(3)];
bearings = [1;121;241];
triangle = problem1(stations,bearings);
expected = [0,0;40,0;20,20*sqrt(3)];
record('三角形端到端解析解',triangle.status == "BOUNDED_POLYGON" && ...
    pointSetDistance(triangle.vertices,expected) < 1e-7 && ...
    abs(triangle.diameter-40) < 1e-7 && ...
    norm(triangle.circleCenter-[20,20*sqrt(3)/3]) < 1e-7 && ...
    abs(triangle.circleRadius-40/sqrt(3)) < 1e-7,'检查顶点、直径、圆心和半径');
record('三角形不能由同直径圆覆盖',triangle.diameterCircleCoversWithinTolerance == 0 && ...
    triangle.radius20Covers == 0,'D=40米，最小覆盖半径大于20米');
square = problem1([-1000,0;0,-1000],[0;90]);
t = tand(1);
a = 1000*t/(1-t);
b = 1000*t/(1+t);
c = 1000*t*(1+t)/(1+t*t);
d = 1000*t*(1-t)/(1+t*t);
squareVertices = [a,a;-c,d;-b,-b;d,-c];
squareDiameter = sqrt(2)*1000*tand(2);
record('两站四边形解析基线',pointSetDistance(square.vertices,squareVertices) < 1e-7 && ...
    abs(square.diameter-squareDiameter) < 1e-7 && ...
    abs(square.circleRadius-squareDiameter/2) < 1e-7,'直接三角恒等式复算顶点和直径');
segment = problem1([-100,0;100,0],[1;181]);
record('线段退化',segment.status == "SEGMENT" && abs(segment.diameter-200)<1e-8 && ...
    norm(segment.circleCenter)<1e-8 && abs(segment.circleRadius-100)<1e-8,'[-100,100]×{0}');
point = problem1([-100,0;100,0;0,-100;0,100],[1;181;89;269]);
record('单点退化',point.status == "POINT" && point.diameter<1e-8 && ...
    norm(point.circleCenter)<1e-8,'交集为原点');
empty = problem1([0,0;100,0],[180;0]);
record('空集',empty.status == "EMPTY" && isnan(empty.diameter),'相背离的观测');
unbounded = problem1([0,0],0);
record('单楔形无界',unbounded.status == "UNBOUNDED" && isinf(unbounded.diameter), ...
    '不借助人工大方框截断');
ray = problem1([0,0;0,0],[359;1]);
record('临界公共射线',ray.status == "UNBOUNDED" && isinf(ray.diameter), ...
    '角差恰好2度仍无界');
wrappedCritical = problem1([0,0;0,0],[359;1+1e-14]);
record('跨0度极小正间隙',wrappedCritical.status == "NUMERIC_UNCERTAIN", ...
    '用原始齐次约束拦截角差舍入造成的无界误判');
uncertain = problem1([0,0;0,0],[0;2+1e-11]);
record('有界临界数值保护',uncertain.status == "NUMERIC_UNCERTAIN",'不强判有限多边形');
nearParallel = problem1([0,0;0,1000],[0;0.01]);
record('近乎平行但明确无界',nearParallel.status == "UNBOUNDED",'0.01度角差');
for gap = [-1e-3,1e-3]
    nearSwitch = problem1([0,0;0,-1],[0;2+gap]);
    if gap < 0
        ok = nearSwitch.status == "UNBOUNDED";
    else
        farPoint = [cosd(1),sind(1)]*cosd(1+gap)/sind(gap);
        ok = nearSwitch.status == "BOUNDED_POLYGON" && ...
            min(vecnorm(nearSwitch.vertices-farPoint,2,2)) < 1e-4 && ...
            nearSwitch.diameter >= norm(farPoint-[100,1])-1e-4;
    end
    record(sprintf('近临界角差%g度',gap),ok,'独立三角恒等式检查远顶点或无界性');
end
for height = [-1e-12,1e-12]
    thin = problem1([-100,0;100,height],[1;181]);
    record(sprintf('极小平行间隙%g米',height),thin.status == "NUMERIC_UNCERTAIN", ...
        '不把空集或极薄四边形误报线段');
end
rotation = -2;
rotationMatrix = [cosd(rotation),-sind(rotation);sind(rotation),cosd(rotation)];
translation = [2345,-1234];
moved = problem1(stations*rotationMatrix.'+translation,mod(bearings+rotation,360));
record('跨0度与刚体变换',abs(moved.diameter-triangle.diameter)<1e-7 && ...
    norm(moved.circleCenter-(triangle.circleCenter*rotationMatrix.'+translation))<1e-7, ...
    '旋转后含359度观测，平移不改变直径');
scaled = problem1(stations*0.1,bearings);
record('尺度不变量',abs(scaled.diameter-4)<1e-7 && ...
    abs(scaled.circleRadius-triangle.circleRadius*0.1)<1e-7,'长度按0.1倍变化');
duplicate = problem1([stations;stations],[bearings;bearings]);
record('重复观测不增加信息',pointSetDistance(duplicate.vertices,triangle.vertices)<1e-7 && ...
    abs(duplicate.circleRadius-triangle.circleRadius)<1e-7,'不平均缩小误差');
redundant = problem1([-1000,0;0,-1000;-1500,0],[0;90;1e-9]);
record('近同向冗余观测保持结果',redundant.status == "BOUNDED_POLYGON" && ...
    pointSetDistance(redundant.vertices,square.vertices)<1e-7 && ...
    abs(redundant.circleRadius-square.circleRadius)<1e-7, ...
    '用齐次不等式排除不可行的病态交点，不丢弃有效远顶点');
farTightened = problem1([0,0;0,-1;0,-1+1e-6],[0;2+1e-7;2+1e-7]);
farExpected = (1-1e-6)*cosd(1+1e-7)/sind(1e-7)*[cosd(1),sind(1)];
farSafe = farTightened.status == "NUMERIC_UNCERTAIN";
if farTightened.status == "BOUNDED_POLYGON"
    farSafe = abs(max(farTightened.vertices(:,1))-farExpected(1)) < 1;
end
record('近临界远端收紧不被容差吞没',farSafe, ...
    '旧远端约高估573米；只接受解析远端误差小于1米或明确数值未定');
squareDots = sum((square.vertices-square.diameterEndpoints(1,:)).* ...
    (square.vertices-square.diameterEndpoints(2,:)),2);
triangleDots = sum((triangle.vertices-triangle.diameterEndpoints(1,:)).* ...
    (triangle.vertices-triangle.diameterEndpoints(2,:)),2);
record('直径圆点积判据及Jung紧界',max(squareDots)<1e-7 && max(triangleDots)>100 && ...
    abs(2*square.circleRadius/square.diameter-1)<1e-10 && ...
    abs(sqrt(3)*triangle.circleRadius/triangle.diameter-1)<1e-10, ...
    '独立点积检验同直径圆；两主例分别达到上下界');
thresholdPass = true;
for targetRadius = [19.99,20,20.01]
    threshold = problem1(stations*(targetRadius/(40/sqrt(3))),bearings);
    if targetRadius == 20
        thresholdPass = thresholdPass && isnan(threshold.radius20Covers);
    else
        thresholdPass = thresholdPass && threshold.radius20Covers == double(targetRadius<20);
    end
end
record('20米临界使用半径上下证书',thresholdPass,'19.99米可覆盖，20米数值未定，20.01米不可覆盖');
[~,multiTable] = multiStationStudy();
record('七阶段独立裁剪与单调性',all(multiTable{:,8}<1e-7) && ...
    all(diff(multiTable{:,3:4},1,1)<=1e-7,'all') && ...
    pointSetDistance(clipReference(stations,bearings),triangle.vertices)<1e-7, ...
    '以逐边裁剪独立复核主算法顶点，并检查相容观测收紧区域');
truth = [20,20*sqrt(3)/3];
newStation = [20,-500];
newBearing = atan2d(truth(2)-newStation(2),truth(1)-newStation(1));
tightened = problem1([stations;newStation],[bearings;newBearing]);
record('增加相容观测不扩大区域',isfinite(tightened.diameter) && ...
    tightened.diameter<=triangle.diameter+1e-7 && ...
    tightened.circleRadius<=triangle.circleRadius+1e-7 && ...
    all(tightened.A*truth.'<=tightened.b+1e-7),'检查直径、覆盖半径和真值相容性');
rectangle = [0,0;30,0;30,40;0,40];
[rectangleDiameter,rectanglePair] = farthestPair(rectangle);
[rectangleCenter,rectangleRadius] = enclosingCircle(rectangle,rectanglePair,1e-10);
record('矩形几何子模块',abs(rectangleDiameter-50)<1e-9 && ...
    norm(rectangleCenter-[15,20])<1e-9 && abs(rectangleRadius-25)<1e-9,'非测向端到端案例');
obtuse = [0,0;40,0;10,1];
[~,obtusePair] = farthestPair(obtuse);
[obtuseCenter,obtuseRadius] = enclosingCircle(obtuse,obtusePair,1e-10);
record('钝角三角形子模块',norm(obtuseCenter-[20,0])<1e-9 && ...
    abs(obtuseRadius-20)<1e-9,'最小圆由最长边确定，非三点外接圆');
allGeometry = {triangle,square,segment,point,moved,scaled,duplicate,tightened};
certificatePass = true;
for i = 1:numel(allGeometry)
    geometry = allGeometry{i};
    support = geometry.vertices(geometry.supportIndices,:);
    weights = geometry.supportWeights;
    certificatePass = certificatePass && min(weights)>=-1e-9 && abs(sum(weights)-1)<1e-9 && ...
        norm(weights.'*support-geometry.circleCenter)<1e-7 && ...
        all(abs(vecnorm(support-geometry.circleCenter,2,2)-geometry.circleRadius)<1e-7) && ...
        all(vecnorm(geometry.vertices-geometry.circleCenter,2,2)<=geometry.circleRadius+1e-7) && ...
        all(geometry.A*geometry.vertices.'<=geometry.b+1e-7,'all');
end
record('覆盖与最优性证书',certificatePass,'顶点可行、圆覆盖、支撑点圆周与圆心凸组合');
invalid = {@()problem1([NaN,0],0),@()problem1([Inf,0],0), ...
    @()problem1([0,0;1,1],0),@()problem1([0,0],Inf), ...
    @()problem1(zeros(0,2),zeros(0,1)),@()problem1([1i,0],0)};
for i = 1:numel(invalid)
    rejected = false;
    try
        invalid{i}();
    catch exception
        rejected = strcmp(exception.identifier,'Q1:InvalidInput');
    end
    record(sprintf('非法输入%d',i),rejected,'须明确拒绝输入');
end
[groupNames,groupPassed,groupDetails] = reliabilityChecks(outputDir);
[twoNames,twoPassed,twoDetails] = twoStationChecks(outputDir);
groupNames = [groupNames;twoNames];
groupPassed = [groupPassed;twoPassed];
groupDetails = [groupDetails;twoDetails];
names = [names;groupNames];
passed = [passed;groupPassed];
details = [details;groupDetails];
checks = table(names,passed,details,'VariableNames',{'检查项','通过','依据'});
writetable(checks,fullfile(outputDir,'必要验证.csv'),'Encoding','UTF-8');
save(fullfile(outputDir,'验证结果.mat'),'checks','triangle','square','segment','point', ...
    'empty','unbounded','ray','uncertain','nearParallel','moved','scaled','duplicate','tightened');
fprintf('必要验证：%d/%d通过。结果目录：%s\n',sum(passed),numel(passed),outputDir);
if ~all(passed)
    disp(checks(~passed,:));
    error('Q1:VerificationFailed','必要验证未全部通过。');
end
    function record(name,ok,detail)
        names(end+1,1) = string(name);
        passed(end+1,1) = logical(ok);
        details(end+1,1) = string(detail);
    end
end

function [names,passed,details] = reliabilityChecks(outputDir)
names = strings(0,1);
passed = false(0,1);
details = strings(0,1);
stations = {[-1000,0;0,-1000],[-1000,0;540,-500*sqrt(3);520,520*sqrt(3)], ...
    [-100,0;100,0],[-100,0;100,0;0,-100;0,100],[0,0;100,0], ...
    [0,0;0,0],[0,0;0,0],[-100,0;100,1e-12],[-100,0;100,-1e-12], ...
    [-1000,0;0,-1000;-1500,0],[0,0;0,-1;0,-1+1e-6]};
bearings = {[0;90],[1;121;241],[1;181],[1;181;89;269],[180;0], ...
    [359;1],[359;1+1e-14],[1;181],[1;181],[0;90;1e-9],[0;2+1e-7;2+1e-7]};
labels = ["两站基线","三角形","线段","单点","空集","公共射线", ...
    "跨零临界","正微小间隙","负微小间隙","近同向冗余","近临界远端"];
angle = [0;90;45;135];
stations{end+1} = -[900;950;1000;1050].*[cosd(angle),sind(angle)];
bearings{end+1} = angle;
labels(end+1) = "八有效边";
rotation = [cosd(17),-sind(17);sind(17),cosd(17)];
stations{end+1} = [-100,0;100,0;50,0]*rotation.'+[2345,-1234];
bearings{end+1} = [1;181;181]+17;
labels(end+1) = "旋转退化三站";
maxRows = sum(cellfun(@(x)factorial(size(x,1)),stations));
permutationRows = cell(maxRows,21);
diagnosticRows = cell(numel(stations),7);
permutationCount = 0;
geometries = cell(size(stations));
for sample = 1:numel(stations)
    reference = problem1(stations{sample},bearings{sample});
    geometries{sample} = reference;
    diagnosticRows(sample,:) = {labels(sample),reference.regionStatus,reference.diameterStatus, ...
        reference.circleStatus,reference.diagnostic.code, ...
        string(mat2str(reference.diagnostic.constraintRows)),string(jsonencode(reference.diagnostic.values))};
    orders = perms(1:size(stations{sample},1));
    ok = true;
    for row = 1:size(orders,1)
        geometry = problem1(stations{sample}(orders(row,:),:),bearings{sample}(orders(row,:)));
        threshold = 1e-7;
        if sample == 11
            threshold = 1;
        end
        [same,comparison] = compareGeometry(reference,geometry,threshold);
        ok = ok && same;
        permutationCount = permutationCount+1;
        permutationRows(permutationCount,:) = {labels(sample),string(mat2str(orders(row,:))), ...
            geometry.regionStatus,geometry.circleStatus,comparison.vertexError,comparison.diameterError, ...
            comparison.radiusError,comparison.centerError,comparison.diameterBoundsError, ...
            comparison.radiusBoundsError,comparison.diameterCircleExcessError,comparison.circleGapError, ...
            comparison.circleViolationError,comparison.diameterCoverSame,comparison.radius20Same, ...
            comparison.vertexComparison,comparison.diameterComparison,comparison.circleComparison, ...
            comparison.coverageComparison,same,geometry.diagnostic.code};
    end
    record("01排列_"+labels(sample),ok,"比较状态、顶点、D/r/圆心及区间/覆盖；不适用项为NaN且有标记");
end
permutationTable = cell2table(permutationRows(1:permutationCount,:), ...
    'VariableNames',{'案例','测点顺序','区域状态','圆状态','顶点差_m','直径差_m','半径差_m','圆心差_m', ...
    '直径估计界差_m','半径估计界差_m','直径圆超量差_m','圆间隙差_m','圆违反量差_m', ...
    '直径圆覆盖一致','20米覆盖一致','顶点比较','直径比较','圆比较','覆盖比较','一致','诊断代码'});
writetable(permutationTable,fullfile(outputDir,'组1_排列逐例.csv'),'Encoding','UTF-8');
diagnosticTable = cell2table(diagnosticRows,'VariableNames', ...
    {'案例','区域状态','直径状态','圆状态','诊断代码','原约束行','诊断数值'});
writetable(diagnosticTable,fullfile(outputDir,'组1_诊断案例.csv'),'Encoding','UTF-8');
diagnosisPass = true;
for sample = [7,8,9]
    geometry = geometries{sample};
    diagnosisPass = diagnosisPass && geometry.status == "NUMERIC_UNCERTAIN" && ...
        strlength(geometry.diagnostic.code)>0 && ~isempty(geometry.diagnostic.constraintRows) && ...
        ~isempty(fieldnames(geometry.diagnostic.values));
end
critical = problem1([0,0;0,0],[0;2+1e-11]);
diagnosisPass = diagnosisPass && critical.diagnostic.code == "CRITICAL_RECESSION";
if geometries{11}.status == "NUMERIC_UNCERTAIN"
    diagnosisPass = diagnosisPass && ~isempty(geometries{11}.diagnostic.constraintRows);
end
record('02临界与小间隙致因诊断',diagnosisPass,'原约束行、测点、侧别、角差/间隙/条件信息可追溯');
segment = geometries{3};
point = geometries{4};
record('02精确退化独立一维复核',segment.regionCertificate.status == "NUMERIC_CHECKED" && ...
    point.regionCertificate.status == "NUMERIC_CHECKED" && ...
    isfield(segment.regionCertificate,'interval') && ...
    abs(segment.diameter-200)<1e-8 && point.diameter==0, ...
    '只在精确相向等式支持下，将全部约束化为一维端点区间');
square = geometries{1};
local = (square.vertices-square.origin)/square.scale;
tolerance = square.coordinateTolerance/square.scale;
missing = regionCertificate(square.A,square.normalizedB,local(1:3,:),tolerance,zeros(0,2));
outside = local;
outside(1,:) = outside(1,:)+[0.1,0.1];
extra = regionCertificate(square.A,square.normalizedB,outside,tolerance,zeros(0,2));
record('03漏角点负向核验',missing.status ~= "NUMERIC_CHECKED", ...
    '删除真实四边形的一个角点；即使仍闭合且内含，也必须拒绝外包含');
record('03伪角点负向核验',extra.status ~= "NUMERIC_CHECKED", ...
    '推移一个顶点到原约束外，内包含核对必须拒绝');
proofPass = true;
for sample = [1,2,12]
    geometry = geometries{sample};
    certificate = geometry.regionCertificate;
    proofPass = proofPass && certificate.status == "NUMERIC_CHECKED" && ...
        all(certificate.boxWeights>=0,'all') && all(certificate.edgeWeights>=0,'all') && ...
        certificate.innerFactor<=1 && certificate.outerFactor>=1 && ...
        all(ismember(geometry.pairAudit(:,3),[1,2,3]));
end
record('03全部线对与双包含证据',proofPass,'每个线对已处理；四向原约束外界、逐边外包含和严格内点内缩');
clipStations = {[-700,0;0,-1300],[-650,0;-1400*cosd(37),-1400*sind(37)],stations{12}};
clipBearings = {[0;90],[0;37],bearings{12}};
parameters = [700,1300,90;650,1400,37;900,950,90];
expectedCounts = [4,4,8];
clipRows = zeros(3,12);
clipGeometry = cell(3,1);
clipVertices = cell(3,1);
for sample = 1:3
    firstDistance = parameters(sample,1);
    secondDistance = parameters(sample,2);
    angle = parameters(sample,3);
    xBound = sind(1)*(firstDistance*cosd(angle-1)+secondDistance*cosd(1))/sind(angle-2);
    yBound = tand(1)*(xBound+firstDistance);
    reference = clipReference(clipStations{sample},clipBearings{sample},2*[xBound,yBound]);
    geometry = problem1(clipStations{sample},clipBearings{sample});
    distances = zeros(size(reference,1));
    for first = 1:size(reference,1)
        for second = 1:size(reference,1)
            distances(first,second) = hypot(reference(first,1)-reference(second,1), ...
                reference(first,2)-reference(second,2));
        end
    end
    [diameter,index] = max(distances,[],'all','linear');
    [first,second] = ind2sub(size(distances),index);
    center = (reference(first,:)+reference(second,:))/2;
    radius = max(hypot(reference(:,1)-center(1),reference(:,2)-center(2)));
    vertexError = pointSetDistance(reference,geometry.vertices);
    clipRows(sample,:) = [sample,size(reference,1),xBound,yBound,geometry.diameter,diameter, ...
        geometry.circleRadius,radius,vertexError,abs(geometry.diameter-diameter), ...
        abs(geometry.circleRadius-radius),radius-diameter/2];
    ok = geometry.status == "BOUNDED_POLYGON" && size(reference,1)==expectedCounts(sample) && ...
        all(abs(reference)<= [xBound,yBound]+1e-7,'all') && vertexError<1e-7 && ...
        abs(geometry.diameter-diameter)<1e-7 && abs(geometry.circleRadius-radius)<1e-7 && ...
        abs(radius-diameter/2)<1e-7;
    record(sprintf('04独立裁剪代表例%d',sample),ok, ...
        '初始框由首两站不等式推导；独立逐边裁剪、距离矩阵与中点覆盖的上下界复算');
    clipGeometry{sample} = geometry;
    clipVertices{sample} = reference;
    exportCase(outputDir,sprintf('独立复核%d',sample),clipStations{sample},clipBearings{sample},geometry);
end
clipTable = array2table(clipRows,'VariableNames',{'案例','顶点数','解析横界_m','解析纵界_m', ...
    '主直径_m','裁剪直径_m','主半径_m','独立半径_m','顶点差_m','直径差_m','半径差_m','独立圆下界差_m'});
writetable(clipTable,fullfile(outputDir,'组1_独立裁剪.csv'),'Encoding','UTF-8');
failed = certifyCircle(square,local,[NaN,NaN],Inf,[],[],tolerance);
rejected = certifyCircle(square,local,[0,0],100,[1,2],[0.5;0.5],tolerance);
splitPass = true;
for geometry = [failed,rejected]
    splitPass = splitPass && geometry.status == "NUMERIC_UNCERTAIN" && ...
        geometry.regionStatus == square.regionStatus && geometry.diameterStatus == "FINITE" && ...
        geometry.diameter==square.diameter && isequal(geometry.vertices,square.vertices) && ...
        geometry.circleStatus == "NUMERIC_UNCERTAIN" && isnan(geometry.circleRadius) && ...
        all(isnan(geometry.circleCenter)) && isnan(geometry.radius20Covers) && ...
        isnan(geometry.circleRadiusLowerEstimate) && isnan(geometry.circleRadiusUpperEstimate);
end
record('05圆失败保留可靠直径',splitPass,'对真实圆接收函数注入未找到和证书失败；旧总状态仍失败关闭，圆字段清空');
[receiptTable,validAcceptance] = circleReceiptChecks(geometries([1,2,3,4]));
writetable(receiptTable,fullfile(outputDir,'圆接收负向检查.csv'),'Encoding','UTF-8');
record('圆接收_正确半径错误圆心',all(receiptTable{1:5,'拒绝且保留几何'}), ...
    '保留正确半径与支撑，错误/NaN/Inf/错误形状/复数圆心均拒绝');
record('圆接收_非法半径支撑与权重',all(receiptTable{6:end,'拒绝且保留几何'}), ...
    '非法类型/维度/索引/权重、覆盖不足及错误支撑必须安全拒绝');
record('圆接收_四类正确圆保留',validAcceptance, ...
    '点、线段、二支撑四边形及三支撑三角形的正确候选仍成功');
changed = square;
changed.circleCenter = square.circleCenter+[100,0];
centerDetected = ~compareGeometry(square,changed,1e-7);
changed.circleCenter = [NaN,NaN];
centerDetected = centerDetected && ~compareGeometry(square,changed,1e-7);
changed = square;
changed.radius20Covers = 1-square.radius20Covers;
coverageDetected = ~compareGeometry(square,changed,1e-7);
changed.radius20Covers = NaN;
coverageDetected = coverageDetected && ~compareGeometry(square,changed,1e-7);
changed = square;
changed.diameterCircleCoversWithinTolerance = 1-square.diameterCircleCoversWithinTolerance;
coverageDetected = coverageDetected && ~compareGeometry(square,changed,1e-7);
record('排列比较器_圆心与覆盖差异必须检出',centerDetected && coverageDetected, ...
    '仅改圆心或两种覆盖判断；包括有限值/NaN语义不同');
[emptySame,emptyComparison] = compareGeometry(geometries{5},geometries{5},1e-7);
[uncertainSame,uncertainComparison] = compareGeometry(geometries{8},geometries{8},1e-7);
changed = geometries{6};
changed.circleRadius = -Inf;
infinityDetected = ~compareGeometry(geometries{6},changed,1e-7);
record('排列比较器_未执行项不记零',emptySame && uncertainSame && infinityDetected && ...
    isnan(emptyComparison.vertexError) && isnan(emptyComparison.diameterError) && ...
    isnan(emptyComparison.radiusError) && isnan(emptyComparison.centerError) && ...
    isnan(uncertainComparison.radius20Same) && emptyComparison.circleComparison=="NOT_APPLICABLE", ...
    '空/未定的差量为NaN并标不适用；无穷符号不同必须拒绝');
save(fullfile(outputDir,'组1_可靠性结果.mat'),'stations','bearings','labels','geometries', ...
    'permutationTable','critical','missing','extra','clipTable','clipStations','clipBearings', ...
    'parameters','clipGeometry','clipVertices','failed','rejected','receiptTable', ...
    'emptyComparison','uncertainComparison');
    function record(name,ok,detail)
        names(end+1,1) = string(name);
        passed(end+1,1) = logical(ok);
        details(end+1,1) = string(detail);
    end
end

function [checks,validAcceptance] = circleReceiptChecks(geometries)
square = geometries{1};
local = (square.vertices-square.origin)/square.scale;
center = (square.circleCenter-square.origin)/square.scale;
radius = square.circleRadius/square.scale;
support = square.supportIndices;
weights = square.supportWeights;
tolerance = square.coordinateTolerance/square.scale;
inputs = {center+[1,1],radius,support,weights;[NaN,NaN],radius,support,weights; ...
    [Inf,0],radius,support,weights;center.',radius,support,weights;center+1i,radius,support,weights; ...
    center,NaN,support,weights;center,Inf,support,weights;center,-radius,support,weights; ...
    center,[radius,radius],support,weights;center,radius,[],[];center,radius,[0,1],weights; ...
    center,radius,[1,size(local,1)+1],weights;center,radius,[1,1.5],weights; ...
    center,radius,[1,1],weights;center,radius,support,[];center,radius,support,zeros(size(weights)); ...
    center,radius,support,NaN(size(weights));center,radius,support,[-0.1;1.1]; ...
    center,radius,support,2*weights;center,radius,support,[0.8;0.2]; ...
    center,0.9*radius,support,weights;center,radius,1,1};
labels = ["错误圆心","NaN圆心","Inf圆心","圆心维度","复数圆心", ...
    "NaN半径","Inf半径","负半径","半径维度","空支撑","零索引","越界索引", ...
    "非整数索引","重复索引","权重数量","零权重","NaN权重","负权重", ...
    "权重和错误","凸组合圆心不一致","覆盖不足","支撑错误"];
results = cell(size(inputs,1),4);
for row = 1:size(inputs,1)
    try
        candidate = certifyCircle(square,local,inputs{row,:},tolerance);
        cleared = all(isnan([candidate.circleCenter,candidate.circleRadius, ...
            candidate.circleRadiusLowerEstimate,candidate.circleRadiusUpperEstimate, ...
            candidate.circleOptimalityGap,candidate.maxCircleViolation,candidate.radius20Covers])) && ...
            isempty(candidate.supportIndices) && isempty(candidate.supportWeights);
        preserved = candidate.regionStatus==square.regionStatus && ...
            candidate.diameterStatus==square.diameterStatus && candidate.diameter==square.diameter && ...
            isequal(candidate.vertices,square.vertices) && ...
            isequal(candidate.diameterBoundsEstimate,square.diameterBoundsEstimate);
        rejected = candidate.status=="NUMERIC_UNCERTAIN" && candidate.circleStatus=="NUMERIC_UNCERTAIN";
        results(row,:) = {labels(row),candidate.diagnostic.code,cleared && preserved && rejected,""};
    catch exception
        results(row,:) = {labels(row),"THREW_EXCEPTION",false,string(exception.identifier)};
    end
end
checks = cell2table(results,'VariableNames',{'故障输入','诊断代码','拒绝且保留几何','异常标识'});
validAcceptance = true;
for index = 1:numel(geometries)
    original = geometries{index};
    local = (original.vertices-original.origin)/original.scale;
    center = (original.circleCenter-original.origin)/original.scale;
    candidate = certifyCircle(original,local,center,original.circleRadius/original.scale, ...
        original.supportIndices,original.supportWeights,original.coordinateTolerance/original.scale);
    validAcceptance = validAcceptance && candidate.circleStatus=="OPTIMAL_NUMERIC" && ...
        norm(candidate.circleCenter-original.circleCenter)<1e-7 && ...
        abs(candidate.circleRadius-original.circleRadius)<1e-7;
end
end

function [same,comparison] = compareGeometry(first,second,tolerance)
comparison = struct('vertexError',NaN,'diameterError',NaN,'radiusError',NaN,'centerError',NaN, ...
    'diameterBoundsError',NaN,'radiusBoundsError',NaN,'diameterCircleExcessError',NaN, ...
    'circleGapError',NaN,'circleViolationError',NaN,'diameterCoverSame',NaN,'radius20Same',NaN, ...
    'vertexComparison',"NOT_APPLICABLE",'diameterComparison',"NOT_APPLICABLE", ...
    'circleComparison',"NOT_APPLICABLE",'coverageComparison',"NOT_APPLICABLE");
same = first.status==second.status && first.regionStatus==second.regionStatus && ...
    first.diameterStatus==second.diameterStatus && first.circleStatus==second.circleStatus && ...
    matchingNumberKinds(first.diameter,second.diameter) && ...
    matchingNumberKinds(first.circleRadius,second.circleRadius) && ...
    matchingNumberKinds(first.circleCenter,second.circleCenter) && ...
    isequaln(first.diameterCircleCoversWithinTolerance,second.diameterCircleCoversWithinTolerance) && ...
    isequaln(first.radius20Covers,second.radius20Covers);
if first.regionStatus~=second.regionStatus
    comparison.vertexComparison = "STATE_MISMATCH";
end
if first.diameterStatus~=second.diameterStatus
    comparison.diameterComparison = "STATE_MISMATCH";
    comparison.coverageComparison = "STATE_MISMATCH";
end
if first.circleStatus~=second.circleStatus
    comparison.circleComparison = "STATE_MISMATCH";
end
if first.regionStatus == "UNBOUNDED" && second.regionStatus == "UNBOUNDED"
    comparison.vertexComparison = "COMPARED";
    comparison.vertexError = pointSetDistance(first.vertices,second.vertices);
    same = same && isfinite(comparison.vertexError) && comparison.vertexError < tolerance;
end
if first.diameterStatus == "FINITE" && second.diameterStatus == "FINITE"
    comparison.vertexComparison = "COMPARED";
    comparison.diameterComparison = "COMPARED";
    comparison.coverageComparison = "COMPARED";
    comparison.vertexError = pointSetDistance(first.vertices,second.vertices);
    comparison.diameterError = finiteDifference(first.diameter,second.diameter);
    comparison.diameterBoundsError = finiteDifference(first.diameterBoundsEstimate,second.diameterBoundsEstimate);
    comparison.diameterCircleExcessError = finiteDifference(first.diameterCircleMaxExcess,second.diameterCircleMaxExcess);
    comparison.diameterCoverSame = double(isequaln(first.diameterCircleCoversWithinTolerance, ...
        second.diameterCircleCoversWithinTolerance));
    errors = [comparison.vertexError,comparison.diameterError,comparison.diameterBoundsError, ...
        comparison.diameterCircleExcessError];
    same = same && all(isfinite(errors)) && all(errors<tolerance) && comparison.diameterCoverSame==1;
end
if first.circleStatus == "OPTIMAL_NUMERIC" && second.circleStatus == "OPTIMAL_NUMERIC"
    comparison.circleComparison = "COMPARED";
    comparison.radiusError = finiteDifference(first.circleRadius,second.circleRadius);
    if all(isfinite([first.circleCenter,second.circleCenter]))
        comparison.centerError = hypot(first.circleCenter(1)-second.circleCenter(1), ...
            first.circleCenter(2)-second.circleCenter(2));
    end
    comparison.radiusBoundsError = finiteDifference( ...
        [first.circleRadiusLowerEstimate,first.circleRadiusUpperEstimate], ...
        [second.circleRadiusLowerEstimate,second.circleRadiusUpperEstimate]);
    comparison.circleGapError = finiteDifference(first.circleOptimalityGap,second.circleOptimalityGap);
    comparison.circleViolationError = finiteDifference(first.maxCircleViolation,second.maxCircleViolation);
    comparison.radius20Same = double(isequaln(first.radius20Covers,second.radius20Covers));
    errors = [comparison.radiusError,comparison.centerError,comparison.radiusBoundsError, ...
        comparison.circleGapError,comparison.circleViolationError];
    same = same && all(isfinite(errors)) && all(errors<tolerance) && comparison.radius20Same==1;
end
end

function same = matchingNumberKinds(first,second)
same = isequal(size(first),size(second)) && isequal(isnan(first),isnan(second)) && ...
    isequal(isinf(first),isinf(second)) && isequal(isinf(first)&first>0,isinf(second)&second>0);
end

function difference = finiteDifference(first,second)
difference = NaN;
if isequal(size(first),size(second)) && ~isempty(first) && ...
        all(isfinite(first),'all') && all(isfinite(second),'all')
    difference = max(abs(first-second),[],'all');
end
end

function distance = pointSetDistance(first,second)
if isempty(first) || isempty(second)
    distance = Inf;
    return
end
matrix = zeros(size(first,1),size(second,1));
for i = 1:size(first,1)
    matrix(i,:) = vecnorm(second-first(i,:),2,2).';
end
distance = max([min(matrix,[],1),min(matrix,[],2).']);
end

function outputDir = freshOutput(label)
root = fileparts(mfilename('fullpath'));
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
outputDir = fullfile(root,'运行结果',[label,'_',stamp]);
if isfolder(outputDir)
    error('Q1:OutputExists','输出目录已存在，请稍后重试，避免覆盖已有结果。');
end
mkdir(outputDir);
end

function writeText(path,text)
file = fopen(path,'w','n','UTF-8');
if file < 0
    error('Q1:WriteFailed','无法写入结果说明。');
end
cleanup = onCleanup(@() fclose(file));
fprintf(file,'%s',text);
end

function [summary,cases] = twoStationStudy(outputDir,makeFigure)
upperRatio = sind(91.5)/sind(1);
parameters = [700,1300,90;650,1400,37;1000,1000,91;700,1300,91; ...
    1000,900,89;1000,900,90.25;1000,900,90.5;1000,900,91.5; ...
    1000,900,91.75;1000,900,92;1000,900,93;1000,1000,3; ...
    1000,800,177;1000,800,178;1000,800,179;1000,800,180; ...
    1000,10,91;10,1000,91;20,20*0.999*upperRatio,90.5; ...
    -10,1000,91;-100,1000,91;0,0,91];
labels = ["正交不等距";"37度非对称";"91度等距反例";"91度不等距反例"; ...
    "下侧89度";"窄带90.25度";"窄带90.5度";"窄带91.5度"; ...
    "窄带91.75度";"边界92度";"上侧93度";"近同向3度"; ...
    "近相向177度";"法向合并178度";"近相向179度";"完全相向180度"; ...
    "低距比三角形";"高距比三角形";"最长边四边形"; ...
    "中心线交点在后方";"不相容空集";"同站单点"];
count = size(parameters,1);
cases = cell(count,1);
rows = cell(count,15);
inputRows = zeros(2*count,5);
for index = 1:count
    first = parameters(index,1);
    second = parameters(index,2);
    phi = parameters(index,3);
    bearings = [-phi/2;phi/2];
    stations = -[first;second].*[cosd(bearings),sind(bearings)];
    geometry = problem1(stations,bearings);
    cases{index} = struct('stations',stations,'bearings',bearings,'geometry',geometry);
    inputRows(2*index-1:2*index,:) = [repmat(index,2,1),(1:2).',stations,bearings];
    vertexError = NaN;
    diameterError = NaN;
    formulaState = "NOT_APPLICABLE";
    predictedCoverage = NaN;
    if phi>2 && phi<178
        [reference,formulaState] = twoStationFormula(first,second,phi);
        if geometry.diameterStatus == "FINITE" && ~isempty(reference)
            vertexError = pointSetDistance(geometry.vertices,reference);
            distances = hypot(reference(:,1)-reference(:,1).',reference(:,2)-reference(:,2).');
            diameterError = abs(geometry.diameter-max(distances,[],'all'));
        end
    end
    expectedState = "BOUNDED_POLYGON";
    if index <= 20
        predictedCoverage = double(phi<=90 || phi>=92);
    elseif index == 21
        expectedState = "EMPTY";
    else
        expectedState = "POINT";
        predictedCoverage = 1;
    end
    formulaMatches = formulaState == "NOT_APPLICABLE" || ...
        formulaState == geometry.regionStatus;
    coverageMatches = isequaln(predictedCoverage,geometry.diameterCircleCoversWithinTolerance);
    rows(index,:) = {labels(index),first,second,phi,geometry.regionStatus, ...
        size(geometry.vertices,1),geometry.diameter,geometry.circleRadius, ...
        geometry.diameterCircleCoversWithinTolerance,predictedCoverage, ...
        geometry.diameterCircleMaxExcess,formulaState,vertexError,diameterError, ...
        geometry.regionStatus==expectedState && formulaMatches && coverageMatches && ...
        (expectedState=="EMPTY" || geometry.circleStatus=="OPTIMAL_NUMERIC")};
end
summary = cell2table(rows,'VariableNames',{'案例','中心线有向距1_m','中心线有向距2_m', ...
    '较小示向度夹角_deg','区域状态','顶点数','直径_m','最小圆半径_m', ...
    '直径圆容差内覆盖','数学覆盖预测','直径圆最大超量_m','显式公式状态', ...
    '显式顶点差_m','显式直径差_m','分类一致'});
inputTable = array2table(inputRows,'VariableNames',{'案例编号','测站编号', ...
    '东坐标_m','北坐标_m','示向度_deg'});
writetable(summary,fullfile(outputDir,'组2_两站分类与公式.csv'),'Encoding','UTF-8');
writetable(inputTable,fullfile(outputDir,'组2_两站输入.csv'),'Encoding','UTF-8');
for index = [3,4,17,18,19]
    item = cases{index};
    exportCase(outputDir,sprintf('组2_案例%d',index),item.stations,item.bearings,item.geometry);
end
save(fullfile(outputDir,'组2_两站结果.mat'),'summary','cases','parameters','labels');
if makeFigure
    if ~all(summary{:,15})
        error('Q1:TwoStationStudyFailed','两站分类与现有求解结果不一致。');
    end
    plotTwoStation(outputDir,cases{3});
end
end

function [vertices,state] = twoStationFormula(first,second,phi)
if ~isscalar(first) || ~isscalar(second) || ~isscalar(phi) || ...
        ~isreal([first,second,phi]) || any(~isfinite([first,second,phi])) || phi<=2 || phi>=178
    error('Q1:FormulaDomain','显式参数公式要求有限实数且2<phi<178度。');
end
small = sind(1);
lower = sind(phi-1);
upper = sind(phi+1);
left = first*lower+second*small;
right = first*small+second*lower;
vertices = zeros(0,2);
if left<0 || right<0
    state = "EMPTY";
    return
end
if left == 0 || right == 0
    if left == 0
        point = [-first,0];
    else
        point = -second*[cosd(phi),sind(phi)];
    end
    rotation = [cosd(phi/2),sind(phi/2);-sind(phi/2),cosd(phi/2)];
    vertices = point*rotation.';
    state = "POINT";
    return
end
points = zeros(6,2);
count = 0;
for sigma = [-1,1]
    for tau = [-1,1]
        denominator = sind(phi+(tau-sigma));
        lambda = (first*sind(phi+tau)-tau*second*small)/denominator;
        mu = (sigma*first*small+second*sind(phi-sigma))/denominator;
        if lambda>=0 && mu>=0
            count = count+1;
            points(count,:) = [-first,0]+lambda*[cosd(sigma),sind(sigma)];
        end
    end
end
if first*upper-second*small <= 0
    count = count+1;
    points(count,:) = [-first,0];
end
if -first*small+second*upper <= 0
    count = count+1;
    points(count,:) = -second*[cosd(phi),sind(phi)];
end
points = unique(points(1:count,:),'rows');
if size(points,1) >= 3
    indices = convhull(points(:,1),points(:,2));
    points = points(indices(1:end-1),:);
end
rotation = [cosd(phi/2),sind(phi/2);-sind(phi/2),cosd(phi/2)];
vertices = points*rotation.';
if size(vertices,1) == 1
    state = "POINT";
else
    state = "BOUNDED_POLYGON";
end
end

function [names,passed,details] = twoStationChecks(outputDir)
names = strings(0,1);
passed = false(0,1);
details = strings(0,1);
[summary,cases] = twoStationStudy(outputDir,false);
record('07两站角度分类',all(summary{:,15}), ...
    '22个代表含窄带内外/端点、三角形、四边形、空和点；未定不算成功');
formulaRows = summary.('显式公式状态') ~= "NOT_APPLICABLE" & ...
    summary.('区域状态') ~= "EMPTY";
record('07独立显式顶点与六对直径', ...
    all(summary{formulaRows,13}<1e-7) && all(summary{formulaRows,14}<1e-7), ...
    '两条前向射线参数闭式计算候选与尖点，再以距离矩阵核对D');
expectedCounts = [3,3,4,3];
actualCounts = summary{[17,18,19,20],6}.';
record('07距离比改变区域形态',isequal(actualCounts,expectedCounts), ...
    '小/大正向距离比各产生三角形；临界内为四边形；负有向距可仍相容');
clippingOk = true;
clipRows = zeros(3,4);
for index = 1:3
    item = cases{index+1};
    phi = abs(diff(item.bearings));
    first = norm(item.stations(1,:));
    second = norm(item.stations(2,:));
    tangent = tand(1);
    coefficient = sind(phi)*(1-tangent^2)-2*tangent*abs(cosd(phi));
    boundX = tangent*((abs(cosd(phi))+tangent*sind(phi))*first+second)/coefficient;
    boundY = tangent*(boundX+first);
    outer = 2*hypot(boundX,boundY);
    clipped = clipReference(item.stations,item.bearings,[-outer,outer,-outer,outer]);
    errorValue = pointSetDistance(item.geometry.vertices,clipped);
    clippingOk = clippingOk && errorValue<1e-7 && coefficient>0;
    clipRows(index,:) = [index+1,outer,errorValue,size(clipped,1)];
end
clipTable = array2table(clipRows,'VariableNames',{'案例编号','独立包含框半边长_m','裁剪顶点差_m','顶点数'});
writetable(clipTable,fullfile(outputDir,'组2_独立裁剪.csv'),'Encoding','UTF-8');
record('07含独立范围证明的裁剪',clippingOk, ...
    '中央族由原不等式给含abs(cos(phi))的坐标界，旋转后用范数包含框独立裁剪');
equal = cases{3}.geometry;
radius = 1000*sind(1)/cosd(45.5);
expected = radius*[-sind(1),cosd(1);-sind(1),-cosd(1);1,0; ...
    -cosd(45.5)/sind(46.5),0];
weights = [1/(2*(1+sind(1)));1/(2*(1+sind(1)));sind(1)/(1+sind(1))];
record('07两站严格反例解析圆', ...
    pointSetDistance(equal.vertices,expected)<1e-7 && ...
    abs(equal.diameter-2*radius*cosd(1))<1e-7 && ...
    norm(equal.circleCenter)<1e-7 && abs(equal.circleRadius-radius)<1e-7 && ...
    norm(weights.'*expected(1:3,:))<1e-10 && ...
    equal.circleRadius>equal.diameter/2+1e-4, ...
    '91度等距四边形的四顶点、三正权支撑、O圆心和D/r均按闭式复核');
physicalRows = zeros(2,5);
for index = 1:2
    item = cases{index+2};
    candidateNorm = max(vecnorm(item.geometry.vertices,2,2));
    stationDistances = vecnorm(item.stations,2,2);
    physicalRows(index,:) = [index+2,candidateNorm,min(stationDistances)-candidateNorm, ...
        max(stationDistances)+candidateNorm,1450];
end
physicalTable = array2table(physicalRows,'VariableNames',{'案例编号','候选域原点距离上界_m', ...
    '全域站源距离下界_m','全域站源距离上界_m','可取全向接收半径_m'});
writetable(physicalTable,fullfile(outputDir,'组2_反例物理合法性.csv'),'Encoding','UTF-8');
record('07两站反例全域物理相容', ...
    all(physicalRows(:,2)<1800) && all(physicalRows(:,3)>5) && ...
    all(physicalRows(:,4)<physicalRows(:,5)) && ...
    cases{4}.geometry.diameterCircleCoversWithinTolerance==0, ...
    '凸性及逆三角不等式保证整个等距/不等距反例>5m、接收1450m以内且在1800m先验内');
edge = cases{19}.geometry;
vertices = edge.vertices;
sideLengths = vecnorm(vertices-vertices([2:end,1],:),2,2);
diagonals = [norm(vertices(1,:)-vertices(3,:)),norm(vertices(2,:)-vertices(4,:))];
record('07不能只检查两对角线', ...
    size(vertices,1)==4 && abs(edge.diameter-max(sideLengths))<1e-7 && ...
    edge.diameter>max(diagonals)+1e-7, ...
    '90.5度、距离比为四边形上阈值0.999倍时，严格最长对是一条边');
transformsOk = true;
for index = [1,3,4,17,19]
    item = cases{index};
    reversed = problem1(flipud(item.stations),flipud(item.bearings));
    transformsOk = transformsOk && compareGeometry(item.geometry,reversed,1e-7);
    reflected = problem1(item.stations.*[1,-1],-item.bearings);
    transformsOk = transformsOk && reflected.circleStatus=="OPTIMAL_NUMERIC" && ...
        pointSetDistance(reflected.vertices,item.geometry.vertices.*[1,-1])<1e-7 && ...
        norm(reflected.circleCenter-item.geometry.circleCenter.*[1,-1])<1e-7 && ...
        abs(reflected.diameter-item.geometry.diameter)<1e-7 && ...
        abs(reflected.circleRadius-item.geometry.circleRadius)<1e-7 && ...
        isequaln(reflected.diameterCircleCoversWithinTolerance,item.geometry.diameterCircleCoversWithinTolerance);
    angle = 37;
    rotation = [cosd(angle),-sind(angle);sind(angle),cosd(angle)];
    factor = 1.7;
    shift = [123,-456];
    moved = problem1(factor*item.stations*rotation.'+shift,item.bearings+angle);
    transformsOk = transformsOk && moved.circleStatus=="OPTIMAL_NUMERIC" && ...
        pointSetDistance(moved.vertices,factor*item.geometry.vertices*rotation.'+shift)<1e-7 && ...
        abs(moved.diameter-factor*item.geometry.diameter)<1e-7 && ...
        abs(moved.circleRadius-factor*item.geometry.circleRadius)<1e-7 && ...
        norm(moved.circleCenter-(factor*item.geometry.circleCenter*rotation.'+shift))<1e-7 && ...
        isequaln(moved.diameterCircleCoversWithinTolerance,item.geometry.diameterCircleCoversWithinTolerance);
end
record('07反例与形态变换复核',transformsOk, ...
    '交换测站、镜像、旋转37度、平移及缩放1.7；比较区域、D/r、圆心和无量纲覆盖结论');
observedStations = [-1000,0;0,-1000];
observedBearings = [-1;90];
observed = problem1(observedStations,observedBearings);
observedAngle = abs(mod(diff(observedBearings)+180,360)-180);
record('07报告轴夹角不等于真实夹角',observedAngle==91 && ...
    observed.circleStatus=="OPTIMAL_NUMERIC" && ...
    max(-observed.b)<=1e-7 && observed.diameterCircleCoversWithinTolerance==0 && ...
    observed.circleRadius>observed.diameter/2+1e-4, ...
    '真实交会90度，合法误差[-1,0]度使报告夹角91度；覆盖分类须使用报告轴');
exportCase(outputDir,'组2_真实90度报告91度',observedStations,observedBearings,observed);
unbounded = problem1([-1000,0;-1000*cosd(1),-1000*sind(1)],[0;1]);
critical = problem1([-1000,0;-1000*cosd(2),-1000*sind(2)],[0;2]);
record('07公共方向及临界无界',unbounded.regionStatus=="UNBOUNDED" && ...
    critical.regionStatus=="UNBOUNDED", ...
    '非空时1度有共同方向、2度恰接触仍有衰退射线；不套二维有界覆盖结论');
invalid = false;
try
    twoStationFormula(1000,1000,178);
catch exception
    invalid = strcmp(exception.identifier,'Q1:FormulaDomain');
end
[contactPoint,contactState] = twoStationFormula(-sind(1),1,91);
expectedContact = sind(1)*[cosd(45.5),-sind(45.5)];
record('07显式公式适用域保护',invalid && contactState=="POINT" && ...
    norm(contactPoint-expectedContact)<1e-12, ...
    '178度拒绝中央公式，端部由通用入口处理；有向距离边界L=0直接返回解析接触点');
save(fullfile(outputDir,'组2_验证结构.mat'),'summary','cases','clipTable','physicalTable','weights','expected','observed');
    function record(name,ok,detail)
        names(end+1,1) = string(name);
        passed(end+1,1) = logical(ok);
        details(end+1,1) = string(detail);
    end
end

function plotTwoStation(outputDir,item)
geometry = item.geometry;
vertices = geometry.vertices;
midpoint = mean(geometry.diameterEndpoints,1);
angles = linspace(0,2*pi,721).';
unitCircle = [cos(angles),sin(angles)];
optimal = geometry.circleCenter+geometry.circleRadius*unitCircle;
diameterCircle = midpoint+geometry.diameter/2*unitCircle;
fig = figure('Visible','off','Color','w','Position',[70,70,1150,510]);
cleanup = onCleanup(@()close(fig));
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
fill(vertices(:,1),vertices(:,2),[0.86,0.93,0.96],'EdgeColor',[0.12,0.28,0.38],'LineWidth',1.6);
hold on;
plot(optimal(:,1),optimal(:,2),'-','Color',[0.68,0.15,0.13],'LineWidth',1.6);
plot(diameterCircle(:,1),diameterCircle(:,2),'--','Color',[0.15,0.4,0.23],'LineWidth',1.6);
plot(geometry.diameterEndpoints(:,1),geometry.diameterEndpoints(:,2),'k-.','LineWidth',1.2);
plot(geometry.circleCenter(1),geometry.circleCenter(2),'+','Color',[0.68,0.15,0.13],'MarkerSize',8,'LineWidth',1.5);
axis equal;
grid on;
xlabel('东坐标 x / m');
ylabel('北坐标 y / m');
title('(a) 两站91°等距交会：完整四边形');
legend('定位区域','最小包围圆','直径端点中点圆','区域直径','最小圆圆心', ...
    'Location','southoutside','NumColumns',2);
[~,tipIndex] = max(vertices(:,1));
tip = vertices(tipIndex,:);
localVertices = vertices-tip;
localOptimal = optimal-tip;
localDiameter = diameterCircle-tip;
nexttile;
fill(localVertices(:,1),localVertices(:,2),[0.86,0.93,0.96],'EdgeColor',[0.12,0.28,0.38],'LineWidth',1.6);
hold on;
plot(localOptimal(:,1),localOptimal(:,2),'-','Color',[0.68,0.15,0.13],'LineWidth',1.8);
plot(localDiameter(:,1),localDiameter(:,2),'--','Color',[0.15,0.4,0.23],'LineWidth',1.8);
plot(0,0,'ko','MarkerFaceColor','k','MarkerSize',5);
axis equal;
xlim([-0.7,0.15]);
ylim([-0.55,0.55]);
grid on;
xlabel('相对最右顶点的东向偏移 / m');
ylabel('相对最右顶点的北向偏移 / m');
title(sprintf('(b) 漏盖局部：最大超量 %.4f m',geometry.diameterCircleMaxExcess));
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,'图5_两站91度反例与漏盖局部.png'),'Resolution',250);
savefig(fig,fullfile(outputDir,'图5_两站91度反例与漏盖局部.fig'));
end

function study = continuousStudy(outputDir,makeFigure)
parameters = [1000,1000,6;1000,1000,10;1000,1000,30; ...
    1000,1000,90;1000,1000,120;1000,1000,174;700,1300,37;700,1300,91];
count = size(parameters,1);
rows = cell(count,15);
cases = cell(count,1);
comparison = zeros(count,7);
inputRows = zeros(2*count,5);
names = strings(0,1);
passed = false(0,1);
details = strings(0,1);
for index = 1:count
    first = parameters(index,1);
    second = parameters(index,2);
    psi = parameters(index,3);
    axes = [0;psi];
    stations = -[first;second].*[cosd(axes),sind(axes)];
    inputRows(2*index-1:2*index,:) = [repmat(index,2,1),(1:2).',stations,axes];
    if first == second && psi>4 && psi<=88
        exact = first*sind(2)/sind(psi/2-2);
        estimate = struct('diameterLower',exact,'diameterUpper',exact, ...
            'radiusLower',exact/2,'radiusUpper',exact/2,'diameterWitness',[1,-1], ...
            'radiusWitness',[1,-1],'boxCount',0,'sampleCount',1,'leaves',zeros(0,9), ...
            'method',"EXACT_EQUAL_DISTANCE_THEOREM",'converged',true);
    else
        estimate = continuousBounds(stations,axes);
    end
    firstGeometry = problem1(stations,axes+estimate.diameterWitness.');
    secondGeometry = firstGeometry;
    if any(estimate.radiusWitness ~= estimate.diameterWitness)
        secondGeometry = problem1(stations,axes+estimate.radiusWitness.');
    end
    [reference,~,~] = continuousVertices(stations,axes,estimate.diameterWitness,[0,0]);
    comparison(index,1:3) = [pointSetDistance(firstGeometry.vertices,reference), ...
        abs(firstGeometry.diameter-estimate.diameterLower), ...
        abs(secondGeometry.circleRadius-estimate.radiusLower)];
    valid = firstGeometry.status=="BOUNDED_POLYGON" && ...
        secondGeometry.status=="BOUNDED_POLYGON" && estimate.converged && ...
        comparison(index,1)<1e-6 && comparison(index,2)<1e-6 && comparison(index,3)<1e-6;
    record(sprintf('组3案例%d最坏下界见证与主接口',index),valid, ...
        '闭式/参数盒下界均有合法误差见证；独立显式顶点与主求解D、r相符');
    outer = continuousVertices(stations,axes,[0,0],[1,1]);
    [outerDiameter,pair] = farthestPair(outer);
    [outerCenter,~,~,~] = enclosingCircle(outer,pair,1e-10);
    outerRadius = max(vecnorm(outer-outerCenter,2,2));
    comparison(index,4:5) = [outerDiameter,outerRadius];
    baseline = norm(stations(2,:)-stations(1,:));
    separation = min(sind([psi-4,psi+4]));
    constant = baseline/separation^2*pi/180;
    rows(index,:) = {index,first,second,psi,estimate.method,estimate.diameterLower, ...
        estimate.diameterUpper,estimate.radiusLower,estimate.radiusUpper, ...
        estimate.diameterWitness(1),estimate.diameterWitness(2), ...
        estimate.radiusWitness(1),estimate.radiusWitness(2),estimate.boxCount,constant};
    cases{index} = struct('stations',stations,'trueBearings',axes,'estimate',estimate, ...
        'diameterGeometry',firstGeometry,'radiusGeometry',secondGeometry, ...
        'outerVertices',outer,'outerCenter',outerCenter,'outerRadius',outerRadius);
    if ~isempty(estimate.leaves)
        leafTable = array2table(estimate.leaves,'VariableNames',{'误差1中心_deg', ...
            '误差2中心_deg','误差1半宽_deg','误差2半宽_deg','直径上估计_m', ...
            '半径上估计_m','中心直径_m','中心半径_m','深度'});
        writetable(leafTable,fullfile(outputDir,sprintf('组3_案例%d误差盒.csv',index)), ...
            'Encoding','UTF-8');
        area = sum(4*estimate.leaves(:,3).*estimate.leaves(:,4));
        comparison(index,6:7) = [area,estimate.sampleCount];
    else
        comparison(index,6:7) = [NaN,1];
    end
end
summary = cell2table(rows,'VariableNames',{'案例编号','真距1_m','真距2_m', ...
    '真实交会角_deg','依据','最大D下界_m','最大D上界_m','最大r下界_m','最大r上界_m', ...
    'D见证误差1_deg','D见证误差2_deg','r见证误差1_deg','r见证误差2_deg', ...
    '终端盒数','顶点L1角扰动常数_m每deg'});
inputTable = array2table(inputRows,'VariableNames',{'案例编号','测站编号', ...
    '东坐标_m','北坐标_m','真实方向_deg'});
referenceTable = array2table([(1:count).',comparison],'VariableNames',{'案例编号', ...
    '显式顶点与主解差_m','D下界见证差_m','r下界见证差_m','全误差并集直径_m', ...
    '全误差并集覆盖半径_m','终端盒面积_deg2','样本数'});
record('参数盒完整覆盖与上下界次序', ...
    all(abs(comparison(4:end,6)-4)<1e-12) && ...
    all(summary{:,7}>=summary{:,6}-1e-8) && all(summary{:,9}>=summary{:,8}-1e-8), ...
    '从根方盒逐次二等分；保留全部终端盒，面积4，界次序正确');
clipRows = zeros(3,3);
for row = 1:3
    index = [1,4,7];
    item = cases{index(row)};
    box = 2*max(vecnorm(item.outerVertices,2,2));
    clipped = clipReference(item.stations,item.trueBearings+item.estimate.diameterWitness.',[box,box]);
    clipRows(row,:) = [index(row),box,pointSetDistance(clipped,item.diameterGeometry.vertices)];
end
record('三种几何的独立裁剪',all(clipRows(:,3)<1e-6), ...
    '6度等距、90度等距、37度不等距；初始方框由扩大楔并集顶点证明包含');
clipTable = array2table(clipRows,'VariableNames',{'案例编号','包含框半边长_m','独立裁剪顶点差_m'});
probeErrors = [-0.8,0.55;0.27,-0.41;0.9,0.1];
probeRows = zeros(3,7);
for row = 1:3
    indices = [1,4,7];
    item = cases{indices(row)};
    firstErrors = probeErrors(row,:);
    secondErrors = firstErrors+[0.001,-0.0007];
    firstGeometry = problem1(item.stations,item.trueBearings+firstErrors.');
    secondGeometry = problem1(item.stations,item.trueBearings+secondErrors.');
    constant = summary{indices(row),15};
    upper = constant*sum(abs(secondErrors-firstErrors));
    probeRows(row,:) = [indices(row),sum(abs(secondErrors-firstErrors)), ...
        abs(firstGeometry.diameter-secondGeometry.diameter),2*upper, ...
        abs(firstGeometry.circleRadius-secondGeometry.circleRadius),upper, ...
        firstGeometry.status=="BOUNDED_POLYGON" && secondGeometry.status=="BOUNDED_POLYGON"];
end
record('角度输入分辨率稳定界',all(probeRows(:,7)==1) && ...
    all(probeRows(:,3)<=probeRows(:,4)) && all(probeRows(:,5)<=probeRows(:,6)), ...
    '只演示合法报告之间的0.001/-0.0007度变化；解析界覆盖整个声明范围');
probeTable = array2table(probeRows,'VariableNames',{'案例编号','角差L1_deg', ...
    '实际D变化_m','D变化解析上界_m','实际r变化_m','r变化解析上界_m','两次状态可靠'});
criticalAngles = [3;4;4.5;88];
criticalRows = cell(numel(criticalAngles),6);
for row = 1:numel(criticalAngles)
    psi = criticalAngles(row);
    axes = [0;psi];
    stations = -1000*[cosd(axes),sind(axes)];
    geometry = problem1(stations,axes+[1;-1]);
    expected = "UNBOUNDED";
    exact = Inf;
    if psi>4
        expected = "BOUNDED_POLYGON";
        exact = 1000*sind(2)/sind(psi/2-2);
    end
    criticalRows(row,:) = {psi,geometry.regionStatus,geometry.diameter,exact, ...
        geometry.circleRadius,geometry.regionStatus==expected && ...
        (isinf(exact) || abs(geometry.diameter-exact)<1e-5)};
end
criticalTable = cell2table(criticalRows,'VariableNames',{'真实交会角_deg','区域状态', ...
    '直径_m','数学直径_m','最小圆半径_m','阈值核对一致'});
record('4度临界与靠近平行放大',all(criticalTable{:,6}), ...
    '3度、4度合法端点无界，4.5度及88度与等距闭式一致；纯角域不截断');
rejected = 0;
invalidInputs = {@()continuousVertices([-1000,0;-1000,0],[0;0],[0,0],[1,1]), ...
    @()continuousVertices([-1000,0;0,-1000],[0;90],[1.1,0],[0,0]), ...
    @()continuousVertices([-1000,0;0,-1000],[0;90],[0,0],[-0.1,0])};
for row = 1:numel(invalidInputs)
    try
        invalidInputs{row}();
    catch exception
        rejected = rejected+strcmp(exception.identifier,'Q1:ContinuousDomain');
    end
end
record('连续研究适用域拒绝',rejected==numel(invalidInputs), ...
    '拒绝分母无安全角距、超出合法误差盒、负半宽；不向通用入口添加新假设');
checks = table(names,passed,details,'VariableNames',{'检查项','通过','依据'});
writetable(summary,fullfile(outputDir,'组3_连续最坏界.csv'),'Encoding','UTF-8');
writetable(inputTable,fullfile(outputDir,'组3_固定几何输入.csv'),'Encoding','UTF-8');
writetable(referenceTable,fullfile(outputDir,'组3_下界见证与并集.csv'),'Encoding','UTF-8');
writetable(clipTable,fullfile(outputDir,'组3_独立裁剪.csv'),'Encoding','UTF-8');
writetable(probeTable,fullfile(outputDir,'组3_输入角微扰.csv'),'Encoding','UTF-8');
writetable(criticalTable,fullfile(outputDir,'组3_临界角.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputDir,'组3_必要验证.csv'),'Encoding','UTF-8');
study = struct('version','1.4','outputDir',outputDir,'summary',summary,'cases',{cases}, ...
    'inputTable',inputTable,'referenceTable',referenceTable,'clipTable',clipTable, ...
    'probeTable',probeTable,'criticalTable',criticalTable,'checks',checks, ...
    'matlabVersion',version,'release',version('-release'));
save(fullfile(outputDir,'组3_连续误差结果.mat'),'study');
writeText(fullfile(outputDir,'组3_范围与精度.txt'),sprintf([ ...
    '固定真源(0,0)，固定真实方向0/psi，坐标精确输入；无位置误差模型。\n' ...
    '报告误差独立取连续[-1,1]度，报告楔半宽始终1度；无概率分布假设。\n' ...
    '等距且4<psi<=88度有解析全局最坏值，其他代表例给误差盒外包数值估计。\n' ...
    '每盒扩大半宽1+h是连续误差的区域并集，不改变正式求解误差界。\n' ...
    '外包数学界是解析命题；数值未实现全流程定向舍入，浮点余量不替代形式化认证。\n' ...
    '数值停止门槛D=max(0.02m,0.001*D下界)，r=max(0.01m,0.001*r下界)。\n' ...
    '继承71项本轮不重复运行；本文件group3分支只运行本组关键检查。\n' ...
    'MATLAB %s (%s)。\n'],version,version('-release')));
fprintf('第3组必要验证：%d/%d，目录：%s\n',sum(passed),numel(passed),outputDir);
disp(summary);
if ~all(passed)
    disp(checks(~passed,:));
    error('Q1:ContinuousVerification','连续误差必要检查未全部通过。');
end
if makeFigure
    plotContinuous(outputDir,summary);
end
    function record(name,ok,detail)
        names(end+1,1) = string(name);
        passed(end+1,1) = logical(ok);
        details(end+1,1) = string(detail);
    end
end

function [vertices,lambda,mu] = continuousVertices(stations,axes,center,halfwidth)
if ~isequal(size(stations),[2,2]) || numel(axes)~=2 || ...
        numel(center)~=2 || numel(halfwidth)~=2 || ...
        any(~isfinite([stations(:);axes(:);center(:);halfwidth(:)])) || ...
        any(halfwidth<0) || any(abs(center)+halfwidth>1+1e-12) || ...
        axes(2)-axes(1)<=4 || axes(2)-axes(1)>=176
    error('Q1:ContinuousDomain','连续研究要求合法误差子盒及4<真实角<176度。');
end
sides = [-1,-1;-1,1;1,-1;1,1];
anglesFirst = axes(1)+center(1)+sides(:,1)*(1+halfwidth(1));
anglesSecond = axes(2)+center(2)+sides(:,2)*(1+halfwidth(2));
first = [cosd(anglesFirst),sind(anglesFirst)];
second = [cosd(anglesSecond),sind(anglesSecond)];
baseline = stations(2,:)-stations(1,:);
denominator = sind(anglesSecond-anglesFirst);
lambda = (baseline(1)*second(:,2)-baseline(2)*second(:,1))./denominator;
mu = (baseline(1)*first(:,2)-baseline(2)*first(:,1))./denominator;
if any(denominator<=0) || any(lambda<=0) || any(mu<=0)
    error('Q1:ContinuousDomain','连续研究要求全部四交点严格前向且分母为正。');
end
vertices = stations(1,:)+lambda.*first;
end

function [diameter,radius,radiusLower] = continuousMetrics(stations,axes,center,halfwidth)
vertices = continuousVertices(stations,axes,center,halfwidth);
[diameter,pair] = farthestPair(vertices);
[circleCenter,radius,support,weights] = enclosingCircle(vertices,pair,1e-10);
if ~isfinite(radius) || any(~isfinite(circleCenter))
    error('Q1:ContinuousCircle','连续研究的圆计算未得到有限结果。');
end
radius = max(vecnorm(vertices-circleCenter,2,2));
weights = max(weights,0);
weights = weights/sum(weights);
supportPoints = vertices(support,:);
average = weights.'*supportPoints;
radiusLower = max(diameter/2,sqrt(sum(weights.*sum((supportPoints-average).^2,2))));
end

function estimate = continuousBounds(stations,axes)
capacity = 8193;
leaves = zeros(capacity,9);
leaves(1,:) = evaluateBox([0,0,1,1,0]);
count = 1;
sampleCount = 1;
lower = leaves(1,7:8);
witnesses = zeros(2,2);
corners = [-1,-1;-1,1;1,-1;1,1];
for index = 1:4
    [diameter,~,radiusLower] = continuousMetrics(stations,axes,corners(index,:),[0,0]);
    updateLower([diameter,radiusLower],corners(index,:));
end
sampleCount = sampleCount+4;
while true
    upper = max(leaves(1:count,5:6),[],1);
    tolerance = max([0.02,0.01],0.001*lower);
    if all(upper-lower<=tolerance)
        break
    end
    if count+1>capacity
        error('Q1:ContinuousBudget','参数盒达到上限但界差未收敛；不得发布完成。');
    end
    scores = max((leaves(1:count,5:6)-lower)./tolerance,[],2);
    [~,index] = max(scores);
    parent = leaves(index,:);
    [~,dimension] = max(parent(3:4));
    firstBox = parent([1:4,9]);
    firstBox(dimension+2) = firstBox(dimension+2)/2;
    secondBox = firstBox;
    firstBox(dimension) = firstBox(dimension)-firstBox(dimension+2);
    secondBox(dimension) = secondBox(dimension)+secondBox(dimension+2);
    firstBox(5) = firstBox(5)+1;
    secondBox(5) = secondBox(5)+1;
    firstChild = evaluateBox(firstBox);
    secondChild = evaluateBox(secondBox);
    firstChild(5:6) = min(firstChild(5:6),parent(5:6));
    secondChild(5:6) = min(secondChild(5:6),parent(5:6));
    leaves(index,:) = firstChild;
    count = count+1;
    leaves(count,:) = secondChild;
    updateLower(firstChild(7:8),firstChild(1:2));
    updateLower(secondChild(7:8),secondChild(1:2));
    sampleCount = sampleCount+2;
end
estimate = struct('diameterLower',lower(1),'diameterUpper',upper(1), ...
    'radiusLower',lower(2),'radiusUpper',upper(2),'diameterWitness',witnesses(1,:), ...
    'radiusWitness',witnesses(2,:),'boxCount',count,'sampleCount',sampleCount, ...
    'leaves',leaves(1:count,:),'method',"CONTINUOUS_BOX_ESTIMATE",'converged',true);
    function row = evaluateBox(box)
        [diameter,radius] = continuousMetrics(stations,axes,box(1:2),box(3:4));
        [sampleDiameter,~,sampleRadius] = continuousMetrics(stations,axes,box(1:2),[0,0]);
        padding = 1e-9*max([1,diameter,radius]);
        row = [box(1:4),diameter+padding,radius+padding, ...
            sampleDiameter,sampleRadius,box(5)];
    end
    function updateLower(values,errors)
        for column = 1:2
            if values(column)>lower(column)
                lower(column) = values(column);
                witnesses(column,:) = errors;
            end
        end
    end
end

function plotContinuous(outputDir,summary)
fig = figure('Visible','off','Color','w','Position',[80,80,1240,500]);
cleanup = onCleanup(@()close(fig));
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
angles = summary{1:6,4};
lower = summary{1:6,6};
upper = summary{1:6,7};
errorbar(angles,(lower+upper)/2,(upper-lower)/2,'ko','LineWidth',1.6, ...
    'MarkerFaceColor',[0.2,0.43,0.6],'MarkerSize',6);
set(gca,'YScale','log');
ylim([0.8*min(lower),1.2*max(upper)]);
grid on;
xlabel('真实交会角 / deg');
ylabel('连续误差下最大区域直径 / m');
title('(a) 固定两站等距1000 m：闭式值与外包界');
text(0.05,0.1,'6° / 10° / 30°：精确公式；其余：上下估计界', ...
    'Units','normalized','FontSize',10);
nexttile;
gaps = logspace(-1,1.3,160).';
exact = 1000*sind(2)./sind(gaps/2);
asymptotic = 2*1000*sind(2)./(gaps*pi/180);
loglog(gaps,exact,'-','Color',[0.7,0.2,0.15],'LineWidth',2);
hold on;
loglog(gaps,asymptotic,'k--','LineWidth',1.2);
grid on;
xlabel('真实交会角距离4°临界值的余量 / deg');
ylabel('连续误差下最大区域直径 / m');
title('(b) 靠近平行：最大直径按临界余量倒数放大');
legend('等距闭式最大值','小角渐近式','Location','southwest');
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,'图6_连续误差界与临界放大.png'),'Resolution',220);
savefig(fig,fullfile(outputDir,'图6_连续误差界与临界放大.fig'));
end

function study = explanationStudy(outputDir,makeFigure,baseline)
baselineSource = "CURRENT_RUN";
if nargin<3
    programRoot = fileparts(mfilename('fullpath'));
    relative = fullfile('运行结果','算例_20260911_130039_232','算例结果.mat');
    baselineSource = string(fullfile(programRoot,relative));
    if ~isfile(baselineSource)
        baselineSource = string(fullfile(fileparts(programRoot),'论文素材包','v1.4','程序',relative));
    end
    if ~isfile(baselineSource)
        error('Q1:BaselineMissing','group4要求包内随附的固定v1.3算例结果.mat；缺失时不能伪造输入。');
    end
    loaded = load(baselineSource,'study');
    baseline = loaded.study;
    if ~strcmp(baseline.version,'1.3')
        error('Q1:BaselineVersion','group4只读继承固定v1.3研究输入。');
    end
end
names = strings(0,1);
passed = false(0,1);
details = strings(0,1);
geometries = {baseline.square,baseline.twoStationCases{3}.geometry, ...
    baseline.multiGeometry{3},baseline.multiGeometry{4}};
labels = ["正交两站基线","两站91度反例","前4站","前5站"];
methods = ["顶点算术平均","最远点对中点","最小包围圆圆心"];
centerRows = cell(12,10);
row = 0;
centerPass = true;
for index = 1:4
    geometry = geometries{index};
    assert(geometry.status=="BOUNDED_POLYGON" && geometry.circleStatus=="OPTIMAL_NUMERIC");
    vertices = geometry.vertices;
    centers = [mean(vertices,1);mean(geometry.diameterEndpoints,1);geometry.circleCenter];
    for method = 1:3
        row = row+1;
        distances = vecnorm(vertices-centers(method,:),2,2);
        [radius,farthest] = max(distances);
        centerRows(row,:) = {labels(index),methods(method),centers(method,1),centers(method,2), ...
            radius,geometry.circleRadius,radius-geometry.circleRadius, ...
            100*(radius/geometry.circleRadius-1),radius-geometry.diameter/2,farthest};
        centerPass = centerPass && radius>=geometry.circleRadius-1e-8 && ...
            radius<=geometry.circleRadius+norm(centers(method,:)-geometry.circleCenter)+1e-8;
        if method==2
            centerPass = centerPass && abs(radius-geometry.diameter/2- ...
                geometry.diameterCircleMaxExcess)<1e-8;
        elseif method==3
            centerPass = centerPass && abs(radius-geometry.circleRadius)<1e-8;
        end
    end
end
centerTable = cell2table(centerRows,'VariableNames',{'案例','圆心方法','圆心东_m','圆心北_m', ...
    '最坏候选距离_m','最优半径_m','比最优多用半径_m','半径相对增幅_pct','相对D半径超量_m','最远顶点编号'});
record('三类圆心按同一最坏距离比较',centerPass, ...
    '4例12种圆心；最优性界、圆心位移上界及原直径圆超量相符');
edgeParts = cell(7,1);
stationParts = cell(7,1);
stageRows = zeros(7,7);
mappingPass = true;
for count = 2:8
    geometry = baseline.multiGeometry{count-1};
    [edges,stations,ok] = observationSources(geometry,count);
    edgeParts{count-1} = edges;
    stationParts{count-1} = stations;
    mappingPass = mappingPass && ok;
    stageRows(count-1,:) = [count,size(geometry.vertices,1),height(edges), ...
        sum(stations{:,3}>0),sum(stations{:,4}==0),geometry.diameter,geometry.circleRadius];
end
edgeTable = vertcat(edgeParts{:});
stationTable = vertcat(stationParts{:});
record('全部7阶段有效边映射',mappingPass, ...
    '边的两个端点必须共同贴合原约束；保留所有重复/同线来源，不以单顶点接触充当有效边');
stageTable = array2table(stageRows,'VariableNames',{'累计站数','顶点数','边来源记录数', ...
    '提供有效边的站数','无顶点接触站数','D_m','r_m'});
four = baseline.multiGeometry{3};
five = baseline.multiGeometry{4};
endpoints = four.diameterEndpoints;
midpoint = mean(endpoints,1);
halfDiameter = four.diameter/2;
newRows = [9,10];
endpointResidual = max(five.A(newRows,:)*endpoints.'-five.b(newRows),[],'all');
oldDistances = vecnorm(four.vertices-midpoint,2,2);
[oldRadius,oldIndex] = max(oldDistances);
newDistances = vecnorm(five.vertices-midpoint,2,2);
oldVertexResidual = five.A(newRows,:)*four.vertices(oldIndex,:).'-five.b(newRows);
fifth = stationTable{:,1}==5 & stationTable{:,2}==5;
extraConstraintResidual = four.A*five.vertices.'-four.b;
transitionPass = endpointResidual< -1e-6 && max(extraConstraintResidual,[],'all')<1e-7 && ...
    abs(four.diameter-five.diameter)<1e-8 && oldRadius-halfDiameter>1e-5 && ...
    max(newDistances)-halfDiameter<1e-7 && max(oldVertexResidual)>1e-5 && ...
    four.circleRadius-five.circleRadius>1e-5 && stationTable{fifth,3}>0;
transition = table(four.diameter,five.diameter,four.circleRadius,five.circleRadius, ...
    four.circleRadius-five.circleRadius,endpointResidual,oldRadius-halfDiameter, ...
    max(newDistances)-halfDiameter,oldIndex,max(oldVertexResidual), ...
    'VariableNames',{'D4_m','D5_m','r4_m','r5_m','半径下降_m','旧直径端点对新约束最大残差_m', ...
    '旧域对直径中点圆漏盖_m','新域对同一圆最大超量_m','被裁旧顶点编号','被裁旧顶点新约束违反_m'});
record('第5站保留最远对却裁去漏盖角点',transitionPass, ...
    '相同前4站构成第5站直接删除对照；端点严格满足新约束，旧漏盖点被排除，新域全部在同一直径圆内');
full = baseline.multiGeometry{7};
finalRows = stationTable{:,1}==8;
finalStations = stationTable(finalRows,:);
candidates = find(finalStations{:,3}==0 & finalStations{:,4}==0);
if isempty(candidates)
    error('Q1:RedundancyCandidate','固定8站中没有可用的严格无接触冗余候选。');
end
[~,best] = min(finalStations{candidates,5});
removed = finalStations{candidates(best),2};
inputTable = baseline.multiInput;
coordinates = inputTable{:,2:3};
bearings = inputTable{:,6};
keep = setdiff((1:8).',removed,'stable');
reduced = problem1(coordinates(keep,:),bearings(keep));
if reduced.status ~= "BOUNDED_POLYGON"
    error('Q1:DeletionUncertain','删除对照未得到可靠有界域。');
end
omitted = [2*removed-1,2*removed];
omittedMaximum = max(full.A(omitted,:)*reduced.vertices.'-full.b(omitted),[],2);
vertexError = pointSetDistance(full.vertices,reduced.vertices);
redundancyPass = all(omittedMaximum< -1e-6) && vertexError<1e-7 && ...
    abs(full.diameter-reduced.diameter)<1e-7 && abs(full.circleRadius-reduced.circleRadius)<1e-7;
deletionTable = table(removed,omittedMaximum(1),omittedMaximum(2),vertexError, ...
    full.diameter,reduced.diameter,full.circleRadius,reduced.circleRadius, ...
    'VariableNames',{'删除站号','删除后下边界最大残差_m','删除后上边界最大残差_m', ...
    '删除前后顶点集合差_m','删除前D_m','删除后D_m','删除前r_m','删除后r_m'});
record('最终8站一次删除核实冗余',redundancyPass, ...
    '在删站后的更大候选域逐顶点核对被删两约束均严格满足，再核对区域、D、r一致');
originalStageMatches = all(abs(stageTable{:,6:7}-baseline.multiTable{:,3:4})<1e-10,'all');
record('固定版本输入与复用范围',originalStageMatches && ...
    all(inputTable{:,1}==(1:8).') && all(abs(inputTable{:,5})<=1), ...
    '只读取固定7阶段几何；本组仅删除对照新增一次主几何求解，不重跑71项、13项和连续误差细分');
checks = table(names,passed,details,'VariableNames',{'检查项','通过','依据'});
writetable(centerTable,fullfile(outputDir,'组4_圆心最坏距离对照.csv'),'Encoding','UTF-8');
writetable(edgeTable,fullfile(outputDir,'组4_有效边与观测来源.csv'),'Encoding','UTF-8');
writetable(stationTable,fullfile(outputDir,'组4_各站边与顶点接触.csv'),'Encoding','UTF-8');
writetable(stageTable,fullfile(outputDir,'组4_阶段来源汇总.csv'),'Encoding','UTF-8');
writetable(transition,fullfile(outputDir,'组4_第4到5站解释.csv'),'Encoding','UTF-8');
writetable(deletionTable,fullfile(outputDir,'组4_最终8站删除对照.csv'),'Encoding','UTF-8');
writetable(inputTable,fullfile(outputDir,'组4_固定输入.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputDir,'组4_必要验证.csv'),'Encoding','UTF-8');
study = struct('version','1.5','outputDir',outputDir,'baselineSource',baselineSource, ...
    'centerTable',centerTable,'edgeTable',edgeTable,'stationTable',stationTable, ...
    'stageTable',stageTable,'transition',transition,'deletionTable',deletionTable, ...
    'deletedStation',removed,'reducedGeometry',reduced,'checks',checks, ...
    'inputTable',inputTable,'four',four,'five',five,'full',full, ...
    'matlabVersion',version,'release',version('-release'));
save(fullfile(outputDir,'组4_覆盖解释结果.mat'),'study');
writeText(fullfile(outputDir,'组4_输入与范围.txt'),sprintf([ ...
    '固定来源：%s\n' ...
    '原多站输入和7阶段几何只读复用，本轮不重跑既有几何实验和71/13项验证。\n' ...
    '新增一次删站求解；其他结果为已有可靠多边形的确定性后处理。\n' ...
    '圆心按全部候选点的最坏距离比较，顶点算术平均不是面积重心。\n' ...
    '有效边、单点接触、无接触不等于已完成删除核实；只有所列删除例声明冗余。\n' ...
    '正负1度纯角域不变，数值残差非全流程定向舍入证明；人工审核待完成。\n' ...
    'MATLAB %s (%s)。\n'],baselineSource,version,version('-release')));
disp(centerTable);
disp(transition);
disp(deletionTable);
fprintf('第4组必要检查：%d/%d，目录：%s\n',sum(passed),numel(passed),outputDir);
if ~all(passed)
    disp(checks(~passed,:));
    error('Q1:ExplanationChecks','覆盖解释性检查未全部通过。');
end
if makeFigure
    plotExplanation(outputDir,study);
end
    function record(name,ok,detail)
        names(end+1,1) = string(name);
        passed(end+1,1) = logical(ok);
        details(end+1,1) = string(detail);
    end
end

function [edgeTable,stationTable,ok] = observationSources(geometry,count)
assert(geometry.regionStatus=="BOUNDED_POLYGON" && size(geometry.A,1)==2*count);
vertices = geometry.vertices;
tolerance = max(1e-7,64*geometry.coordinateTolerance);
residual = geometry.A*vertices.'-geometry.b;
edgeRows = cell(2*count*size(vertices,1),11);
recordCount = 0;
edgeCounts = zeros(count,1);
contactCounts = zeros(count,1);
maximum = zeros(count,1);
ok = max(residual,[],'all')<=tolerance;
for edge = 1:size(vertices,1)
    following = mod(edge,size(vertices,1))+1;
    sources = find(all(abs(residual(:,[edge,following]))<=tolerance,2));
    ok = ok && ~isempty(sources) && norm(vertices(edge,:)-vertices(following,:))>tolerance;
    for index = 1:numel(sources)
        source = sources(index);
        station = ceil(source/2);
        side = "lower";
        if mod(source,2)==0
            side = "upper";
        end
        recordCount = recordCount+1;
        edgeRows(recordCount,:) = {count,edge,source,station,side,vertices(edge,1),vertices(edge,2), ...
            vertices(following,1),vertices(following,2),norm(vertices(edge,:)-vertices(following,:)), ...
            max(abs(residual(source,[edge,following])))};
        edgeCounts(station) = edgeCounts(station)+1;
    end
end
for station = 1:count
    rows = [2*station-1,2*station];
    contactCounts(station) = sum(any(abs(residual(rows,:))<=tolerance,1));
    maximum(station) = max(residual(rows,:),[],'all');
end
edgeTable = cell2table(edgeRows(1:recordCount,:),'VariableNames',{'累计站数','边编号','原约束行','来源站号', ...
    '报告边界侧','起点东_m','起点北_m','终点东_m','终点北_m','边长_m','两端贴边残差_m'});
stationTable = table(repmat(count,count,1),(1:count).',edgeCounts,contactCounts,maximum, ...
    'VariableNames',{'累计站数','站号','有效边记录数','接触顶点数','两约束最大残差_m'});
end

function plotExplanation(outputDir,study)
fig = figure('Visible','off','Color','w','Position',[80,80,1300,590]);
cleanup = onCleanup(@()close(fig));
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
angles = linspace(0,2*pi,600).';
unit = [cos(angles),sin(angles)];
nexttile;
four = study.four;
five = study.five;
fill(four.vertices(:,1),four.vertices(:,2),[0.9,0.9,0.9], ...
    'EdgeColor',[0.3,0.3,0.3],'LineWidth',1.3);
hold on;
fill(five.vertices(:,1),five.vertices(:,2),[0.65,0.8,0.87], ...
    'FaceAlpha',0.5,'EdgeColor',[0.12,0.35,0.47],'LineWidth',1.8);
firstCircle = four.circleCenter+four.circleRadius*unit;
secondCircle = five.circleCenter+five.circleRadius*unit;
plot(firstCircle(:,1),firstCircle(:,2),'--','Color',[0.6,0.15,0.13],'LineWidth',1.4);
plot(secondCircle(:,1),secondCircle(:,2),'k-','LineWidth',1.4);
plot(four.diameterEndpoints(:,1),four.diameterEndpoints(:,2),'k-.','LineWidth',1.5);
index = study.transition{1,9};
plot(four.vertices(index,1),four.vertices(index,2),'rx','MarkerSize',9,'LineWidth',1.8);
axis equal;
grid on;
xlim([-26,26]);
ylim([-34,18]);
xlabel('东坐标 x / m');
ylabel('北坐标 y / m');
title(sprintf('(a) 第4→5站：D不变，r下降%.4f m',four.circleRadius-five.circleRadius));
legend('前4站区域','前5站区域','前4站最小圆','前5站最小圆', ...
    '保留的最远点对','被裁去的旧漏盖点','Location','southoutside','NumColumns',2);
nexttile;
full = study.full;
fill(full.vertices(:,1),full.vertices(:,2),[0.92,0.94,0.95], ...
    'EdgeColor','k','LineWidth',1.6);
hold on;
subset = study.edgeTable(study.edgeTable{:,1}==8,:);
center = mean(full.vertices,1);
for index = 1:height(subset)
    endpoints = [subset{index,6:7};subset{index,8:9}];
    midpoint = mean(endpoints,1);
    outward = midpoint-center;
    labelPoint = midpoint+2.2*outward/norm(outward);
    side = '-';
    if subset{index,5}=="upper"
        side = '+';
    end
    text(labelPoint(1),labelPoint(2),sprintf('S%d%s',subset{index,4},side), ...
        'FontSize',11,'FontWeight','bold','HorizontalAlignment','center');
end
axis equal;
grid on;
xlim([-26,26]);
ylim([-34,18]);
xlabel('东坐标 x / m');
ylabel('北坐标 y / m');
title(sprintf('(b) 最终8站有效边；删S%d区域不变',study.deletedStation));
text(0.03,0.03,'S_i-：报告下边界；S_i+：报告上边界', ...
    'Units','normalized','FontSize',10,'Interpreter','none');
styleFigure(fig);
exportgraphics(fig,fullfile(outputDir,'图7_覆盖下降与观测来源.png'),'Resolution',220);
savefig(fig,fullfile(outputDir,'图7_覆盖下降与观测来源.fig'));
end


function study = timingStudy(outputDir)
axes = [0;90;210;310;135;45;260;170];
errors = [0;0;0.65;-0.4;0.8;-0.7;0.3;-0.2];
coordinates = -1000*[cosd(axes),sind(axes)];
reports = mod(axes+errors,360);
inputs = {[-1000,0;0,-1000],[0;90]; ...
    [-1000,0;540,-500*sqrt(3);520,520*sqrt(3)],[1;121;241]; ...
    coordinates(1:4,:),reports(1:4);coordinates,reports};
labels = ["正交两站";"等边三角形反例";"原前4站";"原最终8站"];
expected = [1000*sqrt(2)*tand(2),500*sqrt(2)*tand(2),4; ...
    40,40/sqrt(3),3;37.6163953284186,19.2963824383157,5; ...
    32.5605616113283,16.6635019263154,5];
samples = zeros(12,5);
metrics = zeros(4,7);
passed = false(4,1);
details = strings(4,1);
inputRows = cell(17,5);
inputRow = 0;
for index = 1:4
    stations = inputs{index,1};
    bearings = inputs{index,2};
    count = size(stations,1);
    for row = 1:count
        inputRow = inputRow+1;
        inputRows(inputRow,:) = {labels(index),row,stations(row,1),stations(row,2),bearings(row)};
    end
    warmup = problem1(stations,bearings);
    valid = warmup.status=="BOUNDED_POLYGON" && warmup.circleStatus=="OPTIMAL_NUMERIC";
    elapsed = zeros(3,1);
    for repetition = 1:3
        timer = tic;
        geometry = problem1(stations,bearings);
        elapsed(repetition) = toc(timer);
        row = (index-1)*3+repetition;
        samples(row,:) = [index,repetition,elapsed(repetition),geometry.diameter,geometry.circleRadius];
        valid = valid && geometry.status=="BOUNDED_POLYGON" && ...
            geometry.circleStatus=="OPTIMAL_NUMERIC" && ...
            size(geometry.vertices,1)==expected(index,3) && ...
            abs(geometry.diameter-expected(index,1))<1e-7 && ...
            abs(geometry.circleRadius-expected(index,2))<1e-7;
    end
    passed(index) = valid && all(isfinite(elapsed)) && all(elapsed>0);
    metrics(index,:) = [count,size(warmup.vertices,1),warmup.diameter, ...
        warmup.circleRadius,min(elapsed),median(elapsed),max(elapsed)];
    details(index) = "1次预热+3次正式接口计时；状态及D/r与已有解析或固定值一致";
end
inputTable = cell2table(inputRows,'VariableNames',{'算例','站号','东坐标_m','北坐标_m','报告角_deg'});
summary = [table(labels,'VariableNames',{'算例'}),array2table(metrics, ...
    'VariableNames',{'测点数','顶点数','直径_m','最小半径_m','最短_s','中位_s','最长_s'})];
sampleTable = array2table(samples,'VariableNames',{'算例序号','重复序号','耗时_s','直径_m','最小半径_m'});
checks = table(labels,passed,details,'VariableNames',{'检查','通过','说明'});
study = struct('version',"1.6",'matlabVersion',string(version),'release',string(version('-release')), ...
    'outputDir',outputDir,'summary',summary,'samples',sampleTable,'inputs',inputTable,'checks',checks, ...
    'warmupsPerCase',1,'timedCallsPerCase',3,'totalCoreCalls',16, ...
    'scope',"完整problem1(stations,bearings)含数值证据和最小圆；不含MATLAB启动、导出、绘图、研究分支；单计算线程");
writetable(inputTable,fullfile(outputDir,'组5_计时输入.csv'),'Encoding','UTF-8');
writetable(summary,fullfile(outputDir,'组5_耗时摘要.csv'),'Encoding','UTF-8');
writetable(sampleTable,fullfile(outputDir,'组5_逐次耗时.csv'),'Encoding','UTF-8');
writetable(checks,fullfile(outputDir,'组5_检查.csv'),'Encoding','UTF-8');
save(fullfile(outputDir,'组5结果.mat'),'study');
writeText(fullfile(outputDir,'组5摘要.txt'),sprintf('MATLAB %s %s\n检查%d/%d\n%s\n', ...
    study.matlabVersion,study.release,sum(passed),numel(passed),study.scope));
disp(summary);
if ~all(passed)
    error('Q1:TimingCheckFailed','计时输入或输出一致性检查失败。');
end
end

