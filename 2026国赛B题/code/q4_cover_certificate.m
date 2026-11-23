function result = q4_cover_certificate(points,outputPath)
assert(isnumeric(points) && isreal(points) && size(points,2)==2 && size(points,1)>=3 && all(isfinite(points),'all'),'Q4:Points','Invalid stations.');
sideCount = 144;
domainRadius = 1800;
minimumRange = 1000;
witness = q4CoverWitness(points,domainRadius,minimumRange);
angles = (0:sideCount-1)'*2*pi/sideCount;
boundary = (domainRadius/cos(pi/sideCount)+0.01)*[cos(angles),sin(angles)];
cells = struct('root',{},'address',{},'vertices',{},'support',{},'hull',{},'distanceBound',{},'halfplaneMargin',{});
unresolved = struct('root',{},'address',{},'vertices',{});
maxDepth = 24;
processed = 0;
for root = 1:sideCount
    if ~witness.found
        checkCell([0,0;boundary(root,:);boundary(mod(root,sideCount)+1,:)],root,"");
    end
end
result = struct('passed',isempty(unresolved) && ~witness.found,'witness',witness,'points',points,'boundary',boundary,'domainRadius',domainRadius, ...
    'minimumRange',minimumRange,'maxDepth',maxDepth,'certifiedCells',numel(cells),'unresolvedCells',numel(unresolved), ...
    'cells',cells,'unresolved',unresolved,'method',"triangle_all_vertices_in_nearby_station_hull", ...
    'evidence',"NUMERICAL_CONTINUOUS_CERTIFICATE_NOT_HUMAN_AUDITED");
if nargin>=2 && strlength(string(outputPath))>0
    assert(~isfile(outputPath),'Q4:OutputExists','Keep prior results.');
    save(outputPath,'result');
end
    function checkCell(vertices,root,address)
        processed = processed+1;
        dist = zeros(size(points,1),3);
        for vertex = 1:3
            dist(:,vertex) = vecnorm(points-vertices(vertex,:),2,2);
        end
        support = find(max(dist,[],2)<=minimumRange-1e-5);
        ok = false;
        margin = -Inf;
        hull = [];
        if numel(support)>=3 && rank(points(support,:)-points(support(1),:),1e-8)==2
            hullIndex = convhull(points(support,1),points(support,2));
            hull = support(hullIndex(1:end-1));
            a = points(hull,:);
            b = a([2:end,1],:);
            edges = b-a;
            norms = vecnorm(edges,2,2);
            distances = zeros(numel(hull),3);
            for vertex = 1:3
                v = vertices(vertex,:)-a;
                distances(:,vertex) = (edges(:,1).*v(:,2)-edges(:,2).*v(:,1))./norms;
            end
            margin = min(distances,[],'all');
            ok = margin>=1e-7;
        end
        if ok
            cells(end+1) = struct('root',root,'address',address,'vertices',vertices,'support',support, ...
                'hull',hull,'distanceBound',max(dist(support,:),[],'all'),'halfplaneMargin',margin);
        elseif strlength(address)<maxDepth && processed<40000
            lengths = sum((vertices([2,3,1],:)-vertices).^2,2);
            [~,edge] = max(lengths);
            sequence = mod((edge-1)+(0:2),3)+1;
            a = vertices(sequence(1),:); b = vertices(sequence(2),:); c = vertices(sequence(3),:);
            midpoint = (a+b)/2;
            checkCell([a;midpoint;c],root,address+"0");
            checkCell([midpoint;b;c],root,address+"1");
        else
            unresolved(end+1) = struct('root',root,'address',address,'vertices',vertices);
        end
    end
end

function witness = q4CoverWitness(points,domainRadius,minimumRange)
[radius,angle] = ndgrid(linspace(0,domainRadius,181),linspace(0,2*pi,721));
locations = [radius(:).*cos(angle(:)),radius(:).*sin(angle(:))];
dx = points(:,1)'-locations(:,1);
dy = points(:,2)'-locations(:,2);
distance = hypot(dx,dy);
angles = mod(atan2(dy,dx),2*pi);
angles(distance>minimumRange) = Inf;
angles = sort(angles,2);
counts = sum(isfinite(angles),2);
gaps = diff(angles,1,2);
gaps(~isfinite(gaps)) = -Inf;
last = angles(sub2ind(size(angles),(1:size(angles,1))',max(counts,1)));
wrap = 2*pi+angles(:,1)-last;
[maxGap,index] = max([gaps,wrap],[],2);
[gap,row] = max(maxGap);
axis = angles(row,index(row))+gap/2;
if index(row)==size(angles,2)
    axis = last(row)+gap/2;
end
position = locations(row,:);
delta = points-position;
projections = delta*[cos(axis);sin(axis)];
distances = vecnorm(delta,2,2);
found = gap>pi+1e-8 && all(distances>minimumRange+1e-6 | projections<-1e-6) && norm(position)<=domainRadius+1e-8;
witness = struct('found',found,'position',position,'axisDeg',mod(rad2deg(axis),360), ...
    'maximumGapDeg',rad2deg(gap),'stationDistances',distances,'stationProjections',projections, ...
    'sampleCheckIsOnlyRejection',true);
end
