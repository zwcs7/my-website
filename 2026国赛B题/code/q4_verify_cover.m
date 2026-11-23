function verification = q4_verify_cover(certificate,points)
verification = struct('passed',false,'reason',"invalid_input",'minimumRangeSlack',Inf,'minimumHullSlack',Inf,'checkedCells',0);
try
    assert(isstruct(certificate) && isscalar(certificate) && certificate.passed);
    assert(isnumeric(points) && isreal(points) && size(points,2)==2 && all(isfinite(points),'all'));
    assert(isequal(points,certificate.points) && certificate.domainRadius==1800 && certificate.minimumRange==1000);
    boundary = certificate.boundary;
    assert(size(boundary,2)==2 && all(isfinite(boundary),'all'));
    vertexCount = size(boundary,1);
    mass = zeros(vertexCount,1);
    addresses = repmat({strings(0,1)},vertexCount,1);
    edges = boundary([2:end,1],:)-boundary;
    assert(all((edges(:,1).*(-boundary(:,2))-edges(:,2).*(-boundary(:,1)))./vecnorm(edges,2,2)>1800+1e-4));
    cells = certificate.cells;
    assert(certificate.certifiedCells==numel(cells) && certificate.unresolvedCells==0 && isempty(certificate.unresolved));
    for k = 1:numel(cells)
        item = cells(k);
        root = item.root;
        assert(isscalar(root) && root==fix(root) && root>=1 && root<=vertexCount);
        address = char(item.address);
        assert(numel(address)<=24 && all(ismember(address,'01')));
        v = [0,0;boundary(root,:);boundary(mod(root,vertexCount)+1,:)];
        for digit = address
            squaredLengths = [(v(2,1)-v(1,1))^2+(v(2,2)-v(1,2))^2; ...
                (v(3,1)-v(2,1))^2+(v(3,2)-v(2,2))^2; ...
                (v(1,1)-v(3,1))^2+(v(1,2)-v(3,2))^2];
            [~,longest] = max(squaredLengths);
            if longest==2, v=v([2,3,1],:); elseif longest==3, v=v([3,1,2],:); end
            mid = (v(1,:)+v(2,:))/2;
            if digit=='0', v=[v(1,:);mid;v(3,:)]; else, v=[mid;v(2,:);v(3,:)]; end
        end
        assert(isequal(v,item.vertices));
        mass(root) = mass(root)+2^(-numel(address));
        addresses{root}(end+1,1) = string(address);
        ids = item.hull;
        assert(numel(ids)>=3 && all(ids==fix(ids)) && all(ids>=1 & ids<=size(points,1)) && numel(unique(ids))==numel(ids));
        hull = points(ids,:);
        next = hull([2:end,1],:);
        edge = next-hull;
        lengths = hypot(edge(:,1),edge(:,2));
        assert(all(lengths>1e-6));
        assert(sum(hull(:,1).*next(:,2)-next(:,1).*hull(:,2))>1e-6);
        for j = 1:size(hull,1)
            allHullCross = edge(j,1)*(hull(:,2)-hull(j,2))-edge(j,2)*(hull(:,1)-hull(j,1));
            assert(all(allHullCross>=-1e-6));
            cellCross = edge(j,1)*(v(:,2)-hull(j,2))-edge(j,2)*(v(:,1)-hull(j,1));
            slack = min(cellCross/lengths(j));
            assert(slack>=5e-8);
            verification.minimumHullSlack = min(verification.minimumHullSlack,slack);
            for vertex = 1:3
                delta = hull(j,:)-v(vertex,:);
                distance = sqrt(delta(1)^2+delta(2)^2);
                assert(distance<=1000-5e-6);
                verification.minimumRangeSlack = min(verification.minimumRangeSlack,1000-distance);
            end
        end
        verification.checkedCells = verification.checkedCells+1;
    end
    assert(all(mass==1));
    for root = 1:vertexCount
        values = sort(addresses{root});
        assert(numel(unique(values))==numel(values));
        for k = 1:numel(values)-1
            assert(~startsWith(values(k+1),values(k)));
        end
    end
    verification.passed = true;
    verification.reason = "complete_partition_and_independent_vertex_checks";
catch failure
    verification.reason = string(failure.message);
end
end
