function output = problem4(mode,config)
if nargin < 1
    mode = "offline";
end
if nargin < 2
    config = struct;
end
mode = string(mode);
assert(isscalar(mode) && ismember(mode,["offline","validate","practice","figures","layoutStudy","localValidate","localStudy","localFigures","opticalValidate","opticalStudy","opticalFigures","iterationStudy","iterationValidate"]),'Q4:Mode','Unsupported mode. Formal testing is disabled.');
root = fileparts(mfilename('fullpath'));
settings = struct('version',"0.9.0-adaptive-active-clear-candidate",'angleMargin',1.01,'clearMargin',19.5,'diskSides',72, ...
    'localLimit',6,'silenceLimit',2,'layout',"triangle",'seed',2026091204,'strategy',"safe",'optical',"legacy");
if mode=="practice"
    settings.layout = "triangle";
    settings.optical = "nearest";
end
if isfield(config,'layout')
    settings.layout = string(config.layout);
end
assert(isscalar(settings.layout) && ismember(settings.layout,["triangle","square","triangle990","triangle990shift","ring22"]),'Q4:Layout','Invalid layout.');
if isfield(config,'strategy')
    settings.strategy = string(config.strategy);
end
if ismember(mode,["offline","layoutStudy"]) && ~isfield(config,'strategy')
    settings.strategy = "baseline";
end
assert(isscalar(settings.strategy) && ismember(settings.strategy,["baseline","safe","cost"]),'Q4:Strategy','Invalid local strategy.');
settings.localPolicy = "legacy";
if mode=="practice"
    settings.localPolicy = "persistent_anchor_blend";
end
if isfield(config,'localPolicy')
    settings.localPolicy = string(config.localPolicy);
end
assert(isscalar(settings.localPolicy) && ismember(settings.localPolicy,["legacy","anchor_blend","persistent_anchor_blend","active_clear"]),'Q4:LocalPolicy','Invalid local measurement policy.');
assert(settings.localPolicy=="legacy" || settings.strategy=="safe",'Q4:LocalPolicy','Anchor blending requires the retained safe strategy.');
if isfield(config,'optical')
    settings.optical = string(config.optical);
end
assert(isscalar(settings.optical) && ismember(settings.optical,["legacy","cells","nearest"]),'Q4:OpticalPolicy','Invalid optical policy.');
settings.serviceOrder = "centroid";
if isfield(config,'serviceOrder')
    settings.serviceOrder = string(config.serviceOrder);
end
assert(isscalar(settings.serviceOrder) && ismember(settings.serviceOrder,["centroid","joint_route","joint_steps"]),'Q4:ServiceOrder','Invalid service order.');
settings.opportunistic = false;
if isfield(config,'opportunistic')
    settings.opportunistic = config.opportunistic;
end
assert(islogical(settings.opportunistic) && isscalar(settings.opportunistic),'Q4:OpportunitySetting','Opportunistic sampling must be a logical scalar.');
settings.coverageOrder = "open_route";
if isfield(config,'coverageOrder')
    settings.coverageOrder = string(config.coverageOrder);
end
assert(isscalar(settings.coverageOrder) && ismember(settings.coverageOrder,["open_route","nearest_station"]),'Q4:CoverageOrder','Invalid coverage order.');
settings.coveragePolicy = "fixed";
if mode=="practice"
    settings.coveragePolicy = "ordered_tail";
end
if isfield(config,'coveragePolicy')
    settings.coveragePolicy = string(config.coveragePolicy);
end
assert(isscalar(settings.coveragePolicy) && ismember(settings.coveragePolicy,["fixed","certified_tail","ordered_tail"]),'Q4:CoveragePolicy','Invalid coverage policy.');
settings.tailMinimumClears = 15;
if settings.coveragePolicy=="ordered_tail"
    settings.tailMinimumClears = 10;
end
if isfield(config,'tailMinimumClears')
    settings.tailMinimumClears = config.tailMinimumClears;
end
assert(isnumeric(settings.tailMinimumClears) && isscalar(settings.tailMinimumClears) && ...
    ((settings.coveragePolicy=="ordered_tail" && settings.tailMinimumClears==10 && settings.coverageOrder=="open_route") || ...
    (settings.coveragePolicy~="ordered_tail" && settings.tailMinimumClears==15)),'Q4:TailTrigger','Invalid certified tail configuration.');
assert(settings.layout~="ring22" || settings.coveragePolicy=="fixed",'Q4:RingPolicy','Ring layout uses its own complete certificate and fixed cover.');
assert(~ismember(settings.serviceOrder,["joint_route","joint_steps"]) || (settings.layout=="ring22" && settings.coveragePolicy=="fixed" && ~settings.opportunistic),'Q4:JointRouteSetting','Joint route study retains fixed ring coverage and local budgets.');
if mode == "practice"
    q4PracticeGate(config);
end
if ~isfield(config,'outputPath')
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    token = char(java.util.UUID.randomUUID());
    config.outputPath = fullfile(root,'运行结果',[char(mode) '_' stamp '_' token(1:8)]);
end
config.outputPath = char(config.outputPath);
assert(~isfolder(config.outputPath) && ~isfile(config.outputPath),'Q4:OutputExists','Use a new output directory.');
mkdir(config.outputPath);
metadata = struct('version',settings.version,'mode',mode,'matlab',version,'release',version('-release'), ...
    'settings',settings,'startedUtc',string(datetime('now','TimeZone','UTC')),'sourceSha256',q4FileHash([mfilename('fullpath') '.m']), ...
    'evidence',"SELF_CHECKED_NOT_HUMAN_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(config.outputPath,'metadata.json'),metadata);
if mode == "validate"
    checks = q4CoreChecks();
    checks = [checks;q4LayoutChecks()];
    for kind = ["triangle","square","triangle990","triangle990shift"]
        [p,t,info] = q4Grid(kind);
        [more,evidence] = q4CoverageChecks(p,t,info);
        more.Properties.VariableNames = {'Name','Passed'};
        more.Name = kind+" / "+string(more.Name);
        checks = [checks;more];
        q4WriteJson(fullfile(config.outputPath,char(kind+"_coverage.json")),evidence);
    end
    mkdir(fullfile(config.outputPath,'transport'));
    more = q4TransportChecks(fullfile(config.outputPath,'transport'));
    writetable(more,fullfile(config.outputPath,'transport_checks.csv'),'Encoding','UTF-8');
    checks = [checks;more(:,{'Name','Passed'})];
    writetable(checks,fullfile(config.outputPath,'checks.csv'),'Encoding','UTF-8');
    output = struct('path',config.outputPath,'passed',sum(checks.Passed),'total',height(checks),'allPassed',all(checks.Passed));
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
    fprintf('Q4 VALIDATION: %d/%d\n',output.passed,output.total);
    assert(output.allPassed,'Q4:Validation','A necessary validation failed.');
elseif mode == "opticalValidate"
    checks = [q4OpticalCellChecks();q4OpticalFlowChecks()];
    writetable(checks,fullfile(config.outputPath,'checks.csv'),'Encoding','UTF-8');
    output = struct('path',config.outputPath,'passed',sum(checks.Passed),'total',height(checks),'allPassed',all(checks.Passed));
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
    fprintf('Q4 OPTICAL VALIDATION: %d/%d\n',output.passed,output.total);
    assert(output.allPassed,'Q4:OpticalValidation','An optical validation failed.');
elseif mode == "opticalStudy"
    output = q4OpticalStudy(config.outputPath,settings,config);
elseif mode == "opticalFigures"
    data = load(fullfile(config.inputPath,'results.mat'),'summary','aggregate');
    q4OpticalFigures(config.outputPath,data.summary,data.aggregate,["legacy","cells","nearest"]);
    output = struct('path',config.outputPath,'inputPath',config.inputPath);
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
elseif mode == "localValidate"
    checks = [q4SafeGeometryChecks();q4LocalChecks()];
    writetable(checks,fullfile(config.outputPath,'checks.csv'),'Encoding','UTF-8');
    output = struct('path',config.outputPath,'passed',sum(checks.Passed),'total',height(checks),'allPassed',all(checks.Passed));
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
    fprintf('Q4 LOCAL VALIDATION: %d/%d\n',output.passed,output.total);
    assert(output.allPassed,'Q4:Validation','An affected local validation failed.');
elseif mode == "localStudy"
    output = q4LocalStudy(config.outputPath,settings,config);
elseif mode == "localFigures"
    data = load(fullfile(config.inputPath,'results.mat'),'summary','aggregate');
    q4LocalFigures(config.outputPath,data.summary,data.aggregate,["baseline","safe","cost"]);
    output = struct('path',config.outputPath,'inputPath',config.inputPath);
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
elseif mode == "iterationValidate"
    if isfield(config,'validationScope') && string(config.validationScope)=="anchor_blend"
        checks = q4AnchorBlendChecks();
    elseif isfield(config,'validationScope') && string(config.validationScope)=="certified_tail"
        checks = q4TailChecks(config);
    elseif isfield(config,'validationScope') && string(config.validationScope)=="coverage_order"
        checks = q4CoverageOrderChecks();
    elseif isfield(config,'validationScope') && string(config.validationScope)=="opportunity"
        checks = q4OpportunityChecks();
    else
        checks = [q4OpportunityChecks();q4CoverageOrderChecks()];
    end
    writetable(checks,fullfile(config.outputPath,'checks.csv'),'Encoding','UTF-8');
    output = struct('passed',sum(checks.Passed),'total',height(checks),'allPassed',all(checks.Passed));
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
    assert(output.allPassed,'Q4:IterationValidation','An affected iteration check failed.');
elseif mode == "iterationStudy"
    output = q4IterationStudy(config.outputPath,settings,config);
elseif mode == "offline"
    output = q4Offline(config.outputPath,settings);
elseif mode == "layoutStudy"
    output = q4LayoutStudy(config.outputPath,settings,config);
elseif mode == "figures"
    assert(isfield(config,'inputPath') && isfile(fullfile(config.inputPath,'results.mat')),'Q4:FigureSource','Use an existing saved offline result.');
    data = load(fullfile(config.inputPath,'results.mat'),'summary','grids','details','scenarios');
    q4Figures(config.outputPath,data.summary,data.grids,data.details,data.scenarios);
    output = struct('path',config.outputPath,'inputPath',config.inputPath, ...
        'inputSha256',q4FileHash(fullfile(config.inputPath,'results.mat')),'evidence',"RENDERED_FROM_SAVED_CONSTRUCTED_RESULTS");
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
else
    [points,triangles,info] = q4Grid(settings.layout);
    settings.robotId = char(config.robotId);
    settings.requestPrefix = ['q4-' char(java.util.UUID.randomUUID())];
    settings.outputPath = config.outputPath;
    [exchange,report] = q4Transport(config);
    solution = q4Solve(exchange,settings,points,triangles,info);
    transport = report();
    q4SaveRun(config.outputPath,solution,struct([]),[],settings);
    save(fullfile(config.outputPath,'transport.mat'),'transport');
    q4WriteJson(fullfile(config.outputPath,'transport_summary.json'),transport);
    output = struct('path',config.outputPath,'complete',solution.complete,'cleared',sum(solution.status==2), ...
        'virtualTime_s',solution.virtualTime,'meanClearTime_s',q4MeanTime(solution.virtualTime,sum(solution.status==2)), ...
        'caseCode',string(config.caseCode),'failure',solution.failure,'officialTotal',[]);
    q4WriteJson(fullfile(config.outputPath,'summary.json'),output);
    fprintf('Q4 PRACTICE: complete=%d, cleared=%d, T=%.6f s\n',output.complete,output.cleared,output.virtualTime_s);
    assert(solution.complete,'Q4:Incomplete','Practice did not complete; inspect saved evidence.');
end
end

function q4PracticeGate(config)
required = {'robotId','baseUrl','caseCode','guiConfirmedUtc','confirmedProblem','confirmedMode'};
assert(all(isfield(config,required)),'Q4:PracticeGate','Confirm the current problem 4 practice GUI and supply its case, identity and time.');
assert(isequal(config.confirmedProblem,4) && string(config.confirmedMode)=="practice",'Q4:PracticeGate','Only GUI-confirmed problem 4 practice is supported.');
confirmed = datetime(config.guiConfirmedUtc,'TimeZone','UTC');
age = seconds(datetime('now','TimeZone','UTC')-confirmed);
assert(isscalar(age) && isfinite(age) && age>=-5 && age<=300,'Q4:PracticeGate','GUI confirmation must be from this case within five minutes.');
assert(strlength(string(config.caseCode))>0 && strlength(string(config.robotId))>0,'Q4:PracticeGate','Case and robot identity are required.');
assert(~isempty(regexp(char(config.baseUrl),'^http://127\.0\.0\.1:[0-9]+$','once')),'Q4:PracticeGate','Use the observed local simulator endpoint.');
end

function solution = q4Solve(exchange,settings,points,triangles,info)
if ~isfield(settings,'optical')
    settings.optical = "legacy";
end
if ~isfield(settings,'strategy')
    settings.strategy = "baseline";
end
if ~isfield(settings,'serviceOrder')
    settings.serviceOrder = "centroid";
end
if ~isfield(settings,'opportunistic')
    settings.opportunistic = false;
end
if ~isfield(settings,'coverageOrder')
    settings.coverageOrder = "open_route";
end
if ~isfield(settings,'coveragePolicy')
    settings.coveragePolicy = "fixed";
end
if ~isfield(settings,'tailMinimumClears')
    settings.tailMinimumClears = 15;
end
if ~isfield(settings,'localPolicy')
    settings.localPolicy = "legacy";
end
[~,gridEvidence] = q4CoverageChecks(points,triangles,info);
assert(isfield(gridEvidence,'continuousCoverageSupported') && gridEvidence.continuousCoverageSupported,'Q4:CoverageCertificate','The fixed layout must support continuous directional coverage before entering.');
status = zeros(1,20);
coverage = false(size(points,1),20);
visited = false(size(points,1),1);
requiredStations = true(size(points,1),1);
tailPlan = struct('applied',false,'serialBefore',0,'requiredStations',requiredStations,'removedStations',zeros(0,1));
tailPlanned = false;
coverageQueue = zeros(0,1);
lastStationSilent = false;
lastCoverageStation = 0;
tracks = cell(1,20);
position = [0,0];
receiver = 1;
virtualTime = 0;
costs = zeros(1,5);
events = struct('serial',{},'path',{},'x',{},'y',{},'channel',{},'result',{},'bearing',{},'virtualTime',{},'receiver',{},'phase',{},'certRadius',{});
opticalPlans = struct('channel',{},'serialBefore',{},'mode',{},'anchor',{},'angle',{},'polygon',{},'queue',{},'cells',{},'certificate',{},'legacyFallback',{},'failureIdentifier',{});
opticalPrunes = struct('id',{},'point',{},'polygon',{},'failedPoint',{},'failedSerial',{},'bound',{},'channel',{});
opticalVisits = struct('channel',{},'serial',{},'cellId',{},'point',{},'remainingIds',{},'mode',{});
opticalSkipped = zeros(1,20);
certificates = struct('serial',{},'channel',{},'polygon',{},'position',{},'previousPosition',{},'center',{},'bound',{});
decisions = struct('serialBefore',{},'channel',{},'attempt',{},'silence',{},'evidence',{});
serviceDecisions = struct('serialBefore',{},'known',{},'distances',{},'selected',{},'mode',{});
jointDecisions = struct('serialBefore',{},'position',{},'known',{},'targets',{},'remainingStations',{},'totalKnown',{},'order',{},'routeLength',{},'type',{},'selected',{});
history = struct('channel',{},'polygon',{},'position',{},'kind',{},'serial',{});
failure = struct('identifier',"",'message',"");
stopReason = "";
complete = false;
serial = 0;
entered = false;
exited = false;
localMeasures = zeros(1,20);
serviceSilence = zeros(1,20);
serviceEverSilent = false(1,20);
opportunisticUsed = false(1,20);
fallbackAttempts = zeros(1,20);
noSignals = zeros(1,20);
maximumActions = size(points,1)*20+16*(settings.localLimit+152)+2;
phase = "enter";
try
    act('/enter',position,0,NaN);
    entered = true;
    while (any(~visited & requiredStations) || any(status==1)) && sum(status==2)<16
        eligibleTail = settings.coveragePolicy=="certified_tail" || (settings.coveragePolicy=="ordered_tail" && lastStationSilent);
        if eligibleTail && ~tailPlanned && sum(status==2)>=settings.tailMinimumClears
            if settings.coveragePolicy=="ordered_tail"
                tailPlan = q4OrderedTailPlan(position,points,visited,sum(status==0));
                tailPlan.silentStation = lastCoverageStation;
                coverageQueue = tailPlan.route;
            else
                tailPlan = q4TailPlan(position,points,visited,sum(status==0));
            end
            tailPlan.serialBefore = serial;
            tailPlan.minimumClears = settings.tailMinimumClears;
            requiredStations = tailPlan.requiredStations;
            tailPlanned = true;
            if isfield(settings,'outputPath')
                q4Append(fullfile(settings.outputPath,'coverage_decisions.jsonl'),tailPlan);
            end
        end
        remaining = find(~visited & requiredStations);
        scheduledStation = 0;
        if ismember(settings.serviceOrder,["joint_route","joint_steps"])
            known = find(status==1);
            totalKnown = sum(status==1 | status==2);
            decision = q4JointRouteChoice(position,points,remaining,known,tracks,totalKnown,serial,settings,localMeasures,serviceSilence,serviceEverSilent);
            jointDecisions(end+1) = decision;
            if decision.type=="service"
                distances = vecnorm(decision.targets-position,2,2)';
                serviceDecisions(end+1) = struct('serialBefore',serial,'known',known,'distances',distances,'selected',decision.selected,'mode',settings.serviceOrder);
                service(decision.selected);
                continue
            end
            scheduledStation = decision.selected;
        end
        if isempty(remaining)
            break
        end
        if ismember(settings.serviceOrder,["joint_route","joint_steps"])
            station = scheduledStation;
            assert(ismember(station,remaining),'Q4:JointRouteProgress','The chosen cover station must be unvisited.');
        elseif settings.coveragePolicy=="ordered_tail" && tailPlanned
            if isempty(coverageQueue)
                [order,~] = q4OpenRoute(position,points(remaining,:));
                coverageQueue = remaining(order);
            end
            station = coverageQueue(1);
            coverageQueue(1) = [];
            assert(requiredStations(station) && ~visited(station),'Q4:CoverageQueue','Tail queue must name a required unvisited station.');
        elseif settings.coverageOrder=="nearest_station"
            station = q4NearestStation(position,points,visited | ~requiredStations);
        else
            [order,~] = q4OpenRoute(position,points(remaining,:));
            station = remaining(order(1));
        end
        channels = find(status==0);
        channels = [channels(channels==receiver),channels(channels~=receiver)];
        phase = "coverage";
        lastStationSilent = true;
        lastCoverageStation = station;
        for channel = channels
            if sum(status==1 | status==2)==16
                break
            end
            response = act('/measure',points(station,:),channel,NaN);
            coverage(station,channel) = true;
            if string(response.measure_result)=="no_signal"
                noSignals(channel) = noSignals(channel)+1;
            else
                lastStationSilent = false;
                status(channel) = 1;
                track = struct('polygon',q4Disk([0,0],1800,settings.diskSides),'anchor',position,'angle',NaN, ...
                    'firstAnchor',position,'firstAngle',NaN,'seen',position,'near',false, ...
                    'observations',q4PastObservations(events(1:end-1),channel));
                track = positive(track,response);
                track = q4Remember(track,position,response);
                track.firstAngle = track.angle;
                tracks{channel} = track;
                retain(channel,"discovery");
            end
        end
        visited(station) = true;
        while any(status==1) && ~ismember(settings.serviceOrder,["joint_route","joint_steps"])
            known = find(status==1);
            if settings.opportunistic
                for opportunityChannel = known
                    opportunityTrack = tracks{opportunityChannel};
                    if q4OpportunityEligible(opportunityTrack,position,localMeasures(opportunityChannel),opportunisticUsed(opportunityChannel),settings)
                        phase = "opportunistic_measure";
                        response = act('/measure',position,opportunityChannel,NaN);
                        localMeasures(opportunityChannel) = localMeasures(opportunityChannel)+1;
                        opportunisticUsed(opportunityChannel) = true;
                        opportunityTrack.seen(end+1,:) = position;
                        if string(response.measure_result)=="no_signal"
                            noSignals(opportunityChannel) = noSignals(opportunityChannel)+1;
                        else
                            opportunityTrack = positive(opportunityTrack,response);
                        end
                        opportunityTrack = q4Remember(opportunityTrack,position,response);
                        tracks{opportunityChannel} = opportunityTrack;
                        retain(opportunityChannel,string(response.measure_result));
                    end
                end
            end
            distances = zeros(size(known));
            for knownIndex = 1:numel(known)
                distances(knownIndex) = norm(mean(tracks{known(knownIndex)}.polygon,1)-position);
            end
            [~,idx] = min(distances);
            serviceDecisions(end+1) = struct('serialBefore',serial,'known',known,'distances',distances,'selected',known(idx),'mode',settings.serviceOrder);
            service(known(idx));
        end
        if ~lastStationSilent
            coverageQueue = zeros(0,1);
        end
        if all(status==2 | (status==0 & all(coverage(requiredStations,:),1)))
            break
        end
    end
    if sum(status==2)==16
        stopReason = "sixteen_distinct_clears";
        status(status==0) = 3;
    else
        empty = status==0 & all(coverage(requiredStations,:),1);
        status(empty) = 3;
        assert(all(status==2 | status==3),'Q4:IncompleteCoverage','Unknown channels lack complete directional coverage.');
        if tailPlan.applied
            assert(q4TailCoverage(points(requiredStations,:)).passed,'Q4:TailCoverage','The reduced scan set lacks continuous coverage.');
            stopReason = "certified_directional_coverage_and_all_discovered_cleared";
        else
            stopReason = "directional_coverage_and_all_discovered_cleared";
        end
    end
    phase = "exit";
    act('/exit',position,0,NaN);
    exited = true;
    complete = true;
catch errorInfo
    failure.identifier = string(errorInfo.identifier);
    failure.message = string(errorInfo.message);
    stopReason = "incomplete_failure";
    if entered && ~exited
        try
            phase = "failure_exit";
            act('/exit',position,0,NaN);
            exited = true;
        catch
        end
    end
end
solution = snapshot();

    function response = act(path,destination,channel,certRadius)
        assert(all(isfinite(destination)) && all(abs(destination)<=2e6),'Q4:Position','Invalid action coordinates.');
        serial = serial+1;
        assert(serial<=maximumActions+1,'Q4:ActionBound','Finite action budget exceeded.');
        payload = struct('arena_id','default','robot_id',settings.robotId,'request_id',sprintf('%s-%05d',settings.requestPrefix,serial));
        if ismember(string(path),["/measure","/clear"])
            payload.position = struct('x',destination(1),'y',destination(2));
            payload.channel = channel;
        end
        response = exchange(path,payload);
        assert(isstruct(response) && isfield(response,'accepted') && isequal(response.accepted,true),'Q4:Rejected','An action was not accepted.');
        result = "";
        bearing = NaN;
        increment = zeros(1,5);
        if ismember(string(path),["/measure","/clear"])
            increment(1) = norm(destination-position)/5;
            position = destination;
            if string(path)=="/measure"
                increment(2) = 5;
                increment(3) = double(receiver~=channel);
                receiver = channel;
                result = string(response.measure_result);
                if result=="direction"
                    bearing = response.svd_deg;
                end
            else
                result = string(response.clear_result);
                if result=="success"
                    increment(4) = 5;
                else
                    increment(5) = 3;
                end
            end
        end
        previousTime = virtualTime;
        virtualTime = response.virtual_time_s;
        costs = costs+increment;
        events(end+1) = struct('serial',serial,'path',string(path),'x',position(1),'y',position(2),'channel',channel, ...
            'result',result,'bearing',bearing,'virtualTime',virtualTime,'receiver',receiver,'phase',phase,'certRadius',certRadius);
        assert(abs(virtualTime-previousTime-sum(increment))<=2e-5,'Q4:Accounting','Accepted action timing disagrees with the official rules.');
        if isfield(settings,'outputPath')
            q4Append(fullfile(settings.outputPath,'actions.jsonl'),events(end));
            q4WriteJson(fullfile(settings.outputPath,'progress.json'),struct('actions',numel(events),'phase',phase, ...
                'cleared',sum(status==2),'virtualTime_s',virtualTime,'position',position,'receiver',receiver));
        end
    end

    function track = positive(track,response)
        track.anchor = position;
        track.near = string(response.measure_result)=="near";
        if track.near
            track.polygon = q4ClipDisk(track.polygon,position,5,settings.diskSides);
        else
            track.angle = response.svd_deg;
            track.polygon = q4ClipDisk(track.polygon,position,1500,settings.diskSides);
            track.polygon = q4Wedge(track.polygon,position,track.angle,settings.angleMargin);
        end
        assert(~isempty(track.polygon) && all(isfinite(track.polygon),'all'),'Q4:EmptyRegion','Positive feedback produced an empty or invalid conservative region.');
    end

    function retain(channel,kind)
        history(end+1) = struct('channel',channel,'polygon',tracks{channel}.polygon,'position',position,'kind',kind,'serial',serial);
    end

    function service(channel)
        silence = 0;
        everLocalSilence = false;
        firstAttempt = 1;
        if settings.serviceOrder=="joint_steps"
            silence = serviceSilence(channel);
            everLocalSilence = serviceEverSilent(channel);
            firstAttempt = localMeasures(channel)+1;
        end
        for attempt = firstAttempt:settings.localLimit+1
            track = tracks{channel};
            [center,radius] = q4Circle(track.polygon);
            if track.near
                center = track.anchor;
                radius = 5;
            end
            if radius<=settings.clearMargin
                destination = center;
                if settings.strategy~="baseline"
                    [destination,radius] = q4SafeClearPoint(track.polygon,position,center,settings.clearMargin);
                end
                certificates(end+1) = struct('serial',serial+1,'channel',channel,'polygon',track.polygon, ...
                    'position',destination,'previousPosition',position,'center',center,'bound',radius);
                phase = "certified_clear";
                response = act('/clear',destination,channel,radius);
                assert(string(response.clear_result)=="success",'Q4:CertifiedClear','A certified clear failed.');
                status(channel) = 2;
                return
            end
            if attempt>settings.localLimit || silence>=settings.silenceLimit || localMeasures(channel)>=settings.localLimit
                break
            end
            destination = q4LegacyPoint(track,center,radius,attempt);
            if ismember(settings.localPolicy,["anchor_blend","persistent_anchor_blend"])
                policySilence = silence;
                if settings.localPolicy=="persistent_anchor_blend"
                    policySilence = double(everLocalSilence);
                end
                destination = q4LocalPolicyPoint(track,center,radius,attempt,policySilence,position,"anchor_blend");
            end
            if settings.localPolicy=="active_clear"
                plan = q4ActivePlan(track,position,localMeasures(channel),silence,everLocalSilence,settings);
                decisions(end+1) = struct('serialBefore',serial,'channel',channel,'attempt',attempt,'silence',silence,'evidence',plan);
                if plan.type=="optical"
                    break
                end
                destination = plan.destination;
            end
            if settings.strategy=="cost" && ~isempty(destination)
                [destination,prediction] = q4LocalPoint(track,position,receiver,channel,attempt,settings);
                decisions(end+1) = struct('serialBefore',serial,'channel',channel,'attempt',attempt,'silence',silence,'evidence',prediction);
            end
            if isempty(destination)
                break
            end
            assert(norm(destination)<=2000,'Q4:LocalBound','Local candidate exceeds the proved movement bound.');
            phase = "local_measure";
            response = act('/measure',destination,channel,NaN);
            localMeasures(channel) = localMeasures(channel)+1;
            track.seen(end+1,:) = position;
            if string(response.measure_result)=="no_signal"
                silence = silence+1;
                everLocalSilence = true;
                noSignals(channel) = noSignals(channel)+1;
            else
                silence = 0;
                track = positive(track,response);
            end
            track = q4Remember(track,position,response);
            tracks{channel} = track;
            retain(channel,string(response.measure_result));
            if settings.serviceOrder=="joint_steps"
                serviceSilence(channel) = silence;
                serviceEverSilent(channel) = everLocalSilence;
                return
            end
        end
        track = tracks{channel};
        [queue,queueCertificate] = q4OpticalQueue(track.firstAnchor,track.firstAngle,track.polygon,position);
        assert(~isempty(queue) && size(queue,1)<=152,'Q4:OpticalQueue','Finite optical cover is missing.');
        cells = struct('id',{},'point',{},'polygon',{});
        cellCertificate = queueCertificate;
        opticalMode = settings.optical;
        legacyFallback = false;
        fallbackIdentifier = "";
        if opticalMode~="legacy"
            try
                [cells,cellCertificate] = q4OpticalCells(track.firstAnchor,track.firstAngle,track.polygon);
            catch cellError
                if ~strcmp(cellError.identifier,'Q4:OpticalCellEnvelope')
                    rethrow(cellError)
                end
                opticalMode = "legacy";
                legacyFallback = true;
                fallbackIdentifier = string(cellError.identifier);
            end
        end
        opticalPlans(end+1) = struct('channel',channel,'serialBefore',serial,'mode',opticalMode, ...
            'anchor',track.firstAnchor,'angle',track.firstAngle,'polygon',track.polygon,'queue',queue, ...
            'cells',cells,'certificate',cellCertificate,'legacyFallback',legacyFallback,'failureIdentifier',fallbackIdentifier);
        phase = "optical_fallback";
        if opticalMode=="legacy"
            for opticalIndex = 1:size(queue,1)
                response = act('/clear',queue(opticalIndex,:),channel,NaN);
                fallbackAttempts(channel) = fallbackAttempts(channel)+1;
                opticalVisits(end+1) = struct('channel',channel,'serial',serial,'cellId',0,'point',position,'remainingIds',[],'mode',opticalMode);
                if string(response.clear_result)=="success"
                    status(channel) = 2;
                    return
                end
            end
        else
            if norm(cells(end).point-position)<norm(cells(1).point-position)
                cells = cells(end:-1:1);
            end
            while ~isempty(cells)
                selected = 1;
                if opticalMode=="nearest"
                    locations = vertcat(cells.point);
                    distances = vecnorm(locations-position,2,2);
                    tied = find(distances<=min(distances)+1e-9);
                    [~,tieIndex] = min([cells(tied).id]);
                    selected = tied(tieIndex);
                end
                selectedId = cells(selected).id;
                remainingIds = [cells.id];
                response = act('/clear',cells(selected).point,channel,NaN);
                fallbackAttempts(channel) = fallbackAttempts(channel)+1;
                opticalVisits(end+1) = struct('channel',channel,'serial',serial,'cellId',selectedId, ...
                    'point',position,'remainingIds',remainingIds,'mode',opticalMode);
                if string(response.clear_result)=="success"
                    status(channel) = 2;
                    return
                end
                [cells,removed] = q4PruneCells(cells,position,serial);
                assert(any([removed.id]==selectedId),'Q4:OpticalProgress','The failed owner cell must be excluded.');
                opticalSkipped(channel) = opticalSkipped(channel)+numel(removed)-1;
                for removedIndex = 1:numel(removed)
                    item = removed(removedIndex);
                    opticalPrunes(end+1) = struct('id',item.id,'point',item.point,'polygon',item.polygon, ...
                        'failedPoint',item.failedPoint,'failedSerial',item.failedSerial,'bound',item.bound,'channel',channel);
                end
            end
        end
        error('Q4:OpticalExhausted','All certified optical covering locations failed for an existing source.');
    end

    function value = snapshot()
        value = struct('complete',complete,'stopReason',stopReason,'status',status,'coverage',coverage,'visited',visited, ...
            'points',points,'triangles',triangles,'gridInfo',info,'requiredStations',requiredStations,'tailPlan',tailPlan,'position',position,'receiver',receiver,'virtualTime',virtualTime, ...
            'shadowTracks',{tracks},'costs',costs,'events',events,'history',history,'failure',failure,'entered',entered,'exited',exited, ...
            'opticalPlans',opticalPlans,'opticalPrunes',opticalPrunes,'opticalVisits',opticalVisits,'opticalSkipped',opticalSkipped, ...
            'certificates',certificates,'decisions',decisions,'serviceDecisions',serviceDecisions,'jointDecisions',jointDecisions,'localMeasures',localMeasures,'opportunisticUsed',opportunisticUsed,'fallbackAttempts',fallbackAttempts,'noSignals',noSignals,'maximumActions',maximumActions);
    end
end

function polygon = q4Disk(center,radius,sides)
angle = ((0:sides-1)'+0.5)*360/sides;
polygon = center+radius/cosd(180/sides)*[cosd(angle),sind(angle)];
end

function polygon = q4ClipDisk(polygon,center,radius,sides)
for angle = (0:sides-1)*360/sides
    normal = [cosd(angle),sind(angle)];
    polygon = q4Plane(polygon,normal,dot(normal,center)+radius);
end
end

function polygon = q4Wedge(polygon,anchor,angle,delta)
lower = [cosd(angle-delta),sind(angle-delta)];
upper = [cosd(angle+delta),sind(angle+delta)];
normal = [lower(2),-lower(1)];
polygon = q4Plane(polygon,normal,dot(normal,anchor));
normal = [-upper(2),upper(1)];
polygon = q4Plane(polygon,normal,dot(normal,anchor));
end

function result = q4Plane(polygon,normal,bound)
if isempty(polygon)
    result = polygon;
    return
end
values = polygon*normal'-bound-1e-8;
result = zeros(2*size(polygon,1),2);
count = 0;
previous = size(polygon,1);
for current = 1:size(polygon,1)
    if (values(current)<=0) ~= (values(previous)<=0)
        ratio = values(previous)/(values(previous)-values(current));
        count = count+1;
        result(count,:) = polygon(previous,:)+ratio*(polygon(current,:)-polygon(previous,:));
    end
    if values(current)<=0
        count = count+1;
        result(count,:) = polygon(current,:);
    end
    previous = current;
end
result = unique(result(1:count,:),'rows','stable');
end

function [center,radius] = q4Circle(points)
assert(~isempty(points) && size(points,2)==2 && all(isfinite(points),'all'),'Q4:CircleInput','Finite nonempty points required.');
center = points(1,:);
radius = 0;
for i = 2:size(points,1)
    if norm(points(i,:)-center)<=radius+1e-8
        continue
    end
    center = points(i,:);
    radius = 0;
    for j = 1:i-1
        if norm(points(j,:)-center)<=radius+1e-8
            continue
        end
        center = (points(i,:)+points(j,:))/2;
        radius = norm(points(i,:)-center);
        for k = 1:j-1
            if norm(points(k,:)-center)<=radius+1e-8
                continue
            end
            trio = points([i,j,k],:);
            matrix = 2*(trio(2:3,:)-trio(1,:));
            rhs = sum((trio(2:3,:)-trio(1,:)).^2,2);
            if rcond(matrix)>1e-12
                center = trio(1,:)+(matrix\rhs)';
            else
                pairs = [1,2;1,3;2,3];
                lengths = vecnorm(trio(pairs(:,1),:)-trio(pairs(:,2),:),2,2);
                [~,far] = max(lengths);
                center = mean(trio(pairs(far,:),:),1);
            end
            radius = max(vecnorm(trio-center,2,2));
        end
    end
end
radius = max(vecnorm(points-center,2,2))+1e-7;
end

function distance = q4DistancePolygon(point,polygon)
if size(polygon,1)==1
    distance = norm(point-polygon);
    return
end
[inside,on] = inpolygon(point(1),point(2),polygon(:,1),polygon(:,2));
if inside || on
    distance = 0;
    return
end
a = polygon;
b = polygon([2:end,1],:);
edge = b-a;
weights = sum((point-a).*edge,2)./max(sum(edge.^2,2),realmin);
nearest = a+max(0,min(1,weights)).*edge;
distance = min(vecnorm(nearest-point,2,2));
end

function [queue,certificate] = q4OpticalQueue(anchor,angle,polygon,position)
assert(all(isfinite(anchor)) && isfinite(angle),'Q4:OpticalInput','An accepted first direction is required.');
local = zeros(152,2);
for col = 0:75
    local(2*col+(1:2),:) = [20*col,-13.5*(-1)^col;20*col,13.5*(-1)^col];
end
rotation = [cosd(angle),sind(angle);-sind(angle),cosd(angle)];
allPoints = anchor+local*rotation;
keep = false(152,1);
for k = 1:152
    keep(k) = q4DistancePolygon(allPoints(k,:),polygon)<=20+1e-6;
end
queue = allPoints(keep,:);
if ~isempty(queue) && norm(queue(end,:)-position)<norm(queue(1,:)-position)
    queue = flipud(queue);
end
certificate = struct('rectangle',[0,1500,-27,27],'coverRadius',hypot(10,13.5), ...
    'originalCount',152,'retainedCount',size(queue,1),'originalSnakeLength',3552,'safeFiltering',true);
end

function [exchange,report] = q4World(sources)
assert(isnumeric(sources) && size(sources,2)==7 && size(sources,1)>=1 && size(sources,1)<=16 && all(isfinite(sources),'all'),'Q4:Sources','Invalid constructed sources.');
assert(numel(unique(sources(:,1)))==size(sources,1) && all(sources(:,1)>=1 & sources(:,1)<=20 & fix(sources(:,1))==sources(:,1)),'Q4:Sources','Invalid channels.');
assert(all(vecnorm(sources(:,2:3),2,2)<=1800+1e-7) && all(sources(:,4)>=1000 & sources(:,4)<=1500) && all(ismember(sources(:,5),[0,1])),'Q4:Sources','Invalid source geometry.');
position = [0,0];
receiver = 1;
time = 0;
active = false;
cleared = false(size(sources,1),1);
cache = containers.Map('KeyType','char','ValueType','any');
exchange = @send;
report = @state;
    function response = send(path,payload)
        key = char(payload.request_id);
        signature = [char(path) '|' jsonencode(payload)];
        if isKey(cache,key)
            record = cache(key);
            assert(strcmp(signature,record.signature),'Q4:IdConflict','One id cannot name different actions.');
            response = record.response;
            return
        end
        response = struct('accepted',true,'real_timestamp_ms',0,'virtual_time_s',time);
        if string(path)=="/enter"
            assert(~active && isempty(keys(cache)),'Q4:WorldState','World may be entered once.');
            active = true;
            response.max_virtual_duration_s = 360000;
            response.max_real_duration_s = 1200;
            response.remaining_real_duration_s = 1200;
        elseif string(path)=="/exit"
            assert(active,'Q4:WorldState','No active world.');
            active = false;
            response.exit_reason = 'user_exit';
        else
            assert(active && ismember(string(path),["/measure","/clear"]),'Q4:WorldState','Invalid active action.');
            at = [payload.position.x,payload.position.y];
            channel = payload.channel;
            assert(all(isfinite(at)) && all(abs(at)<=2e6) && isscalar(channel) && channel>=1 && channel<=20 && fix(channel)==channel,'Q4:WorldInput','Invalid action.');
            travel = norm(at-position)/5;
            position = at;
            target = find(sources(:,1)==channel & ~cleared,1);
            distance = Inf;
            visible = false;
            if ~isempty(target)
                displacement = at-sources(target,2:3);
                distance = norm(displacement);
                axis = [cosd(sources(target,6)),sind(sources(target,6))];
                visible = distance<=sources(target,4)+1e-9 && (sources(target,5)==0 || dot(axis,displacement)>=-1e-9);
            end
            if string(path)=="/measure"
                time = time+travel+double(receiver~=channel)+5;
                receiver = channel;
                response.measure_result = 'no_signal';
                if visible
                    if distance<=5
                        response.measure_result = 'near';
                    else
                        response.measure_result = 'direction';
                        bearing = atan2d(-displacement(2),-displacement(1));
                        err = q4SpatialError(at,channel,sources(target,7));
                        response.svd_deg = mod(round(mod(bearing+err,360),2),360);
                    end
                end
            else
                success = ~isempty(target) && distance<=20+1e-9;
                time = time+travel+3+2*success;
                response.clear_result = 'no_target_in_range';
                if success
                    cleared(target) = true;
                    response.clear_result = 'success';
                end
            end
        end
        response.virtual_time_s = time;
        assert(time<=360000,'Q4:VirtualLimit','Constructed run exceeded the virtual time limit.');
        cache(key) = struct('signature',signature,'response',response);
    end
    function value = state()
        value = struct('position',position,'receiver',receiver,'time',time,'cleared',cleared,'active',active);
    end
end

function err = q4SpatialError(position,channel,kind)
if kind==1
    err = 1;
elseif kind==2
    err = -1;
elseif kind==3
    err = sin(position(1)/750+position(2)/520+channel);
else
    err = sin(position(1)*0.037+position(2)*0.023+channel*1.17);
end
end

function scenarios = q4Scenarios(seed)
previous = rng;
cleanup = onCleanup(@() rng(previous));
rng(seed,'twister');
scenarios = struct('name',{},'sources',{},'group',{});
for k = 1:28
    count = 10+mod(k-1,7);
    channels = sort(randperm(20,count))';
    angle = 360*rand(count,1);
    radius = 1800*sqrt(rand(count,1));
    xy = radius.*[cosd(angle),sind(angle)];
    reception = 1000+500*rand(count,1);
    directional = double(rand(count,1)<0.65);
    directional(1) = 0;
    directional(end) = 1;
    direction = 360*rand(count,1);
    err = mod((1:count)'+k,4);
    group = "constructed_random";
    if k<=8
        group = "constructed_boundary";
        reception(:) = 1000;
        if k<=3
            angle = (0:count-1)'*360/count+0.13*k;
            xy = 1800*[cosd(angle),sind(angle)];
            direction = angle+90*(k-1);
            directional(2:end) = 1;
        elseif k==4
            xy = repmat([1700,0],count,1)+[80*rand(count,1),40*(rand(count,1)-0.5)];
            direction(:) = 0;
            directional(2:end) = 1;
        elseif k==5
            xy(1,:) = [0,0];
            xy(2,:) = [3,0];
            direction(2) = 0;
            directional(2) = 1;
        elseif k==6
            xy(1:5,:) = [-1300,0;-650,0;0,650;650,650;1300,0];
            direction(1:5) = [180;270;90;45;0];
        elseif k==7
            angle = (0:count-1)'*360/count;
            xy = 1400*[cosd(angle),sind(angle)];
            directional(2:end) = 1;
            direction = angle;
        else
            reception(:) = 1500;
            err(:) = 1;
        end
    end
    scenarios(end+1) = struct('name',sprintf('Q4_%02d_N%02d',k,count),'sources',[channels,xy,reception,directional,direction,err],'group',group);
end
end

function output = q4Offline(path,settings)
scenarios = q4Scenarios(settings.seed);
summaryRows = cell(0,15);
gridRows = cell(0,5);
details = cell(2,numel(scenarios));
for variant = 1:2
    kinds = ["triangle","square"];
    kind = kinds(variant);
    [points,triangles,info] = q4Grid(kind);
    [order,length] = q4OpenRoute([0,0],points);
    gridRows(end+1,:) = {kind,size(points,1),size(triangles,1),length,length/5+119*size(points,1)};
    writetable(array2table(points,'VariableNames',{'X_m','Y_m'}),fullfile(path,char(kind+"_stations.csv")),'Encoding','UTF-8');
    save(fullfile(path,char(kind+"_layout.mat")),'points','triangles','info','order');
    for k = 1:numel(scenarios)
        cfg = settings;
        cfg.robotId = 'OFFLINE_Q4';
        cfg.requestPrefix = sprintf('%s-%d',kind,k);
        [exchange,report] = q4World(scenarios(k).sources);
        solution = q4Solve(exchange,cfg,points,triangles,info);
        world = report();
        audit = q4Audit(solution,scenarios(k).sources,world);
        runPath = fullfile(path,char(kind),scenarios(k).name);
        mkdir(runPath);
        q4SaveRun(runPath,solution,world,scenarios(k).sources,cfg);
        q4WriteJson(fullfile(runPath,'audit.json'),audit);
        cleared = sum(world.cleared);
        summaryRows(end+1,:) = {kind,string(scenarios(k).name),scenarios(k).group,size(scenarios(k).sources,1),cleared, ...
            solution.complete && all(world.cleared) && audit.allPassed,solution.virtualTime,q4MeanTime(solution.virtualTime,cleared), ...
            solution.costs(1)*5,solution.costs(2)/5,solution.costs(3),solution.costs(5)/3,sum(solution.fallbackAttempts), ...
            numel(solution.events),string(solution.failure.identifier)};
        details{variant,k} = solution;
        fprintf('Q4 %s %s: %d/%d T=%.3f audit=%d\n',kind,scenarios(k).name,cleared,size(scenarios(k).sources,1),solution.virtualTime,audit.allPassed);
        writetable(cell2table(summaryRows,'VariableNames',{'Layout','Scenario','Group','SourceCount','Cleared','FullClearVerified','VirtualTime_s','MeanClearTime_s','Distance_m','Measures','Switches','FailedClears','OpticalAttempts','Actions','Failure'}),fullfile(path,'summary.csv'),'Encoding','UTF-8');
    end
end
summary = cell2table(summaryRows,'VariableNames',{'Layout','Scenario','Group','SourceCount','Cleared','FullClearVerified','VirtualTime_s','MeanClearTime_s','Distance_m','Measures','Switches','FailedClears','OpticalAttempts','Actions','Failure'});
grids = cell2table(gridRows,'VariableNames',{'Layout','Stations','Triangles','StationOnlyRoute_m','Full20ChannelScan_s'});
writetable(grids,fullfile(path,'grid_comparison.csv'),'Encoding','UTF-8');
save(fullfile(path,'results.mat'),'summary','grids','scenarios','settings','details','-v7.3');
output = struct('path',path,'runs',height(summary),'fullClearVerified',sum(summary.FullClearVerified),'allPassed',all(summary.FullClearVerified), ...
    'triangleMean_s',mean(summary.VirtualTime_s(summary.Layout=="triangle")),'squareMean_s',mean(summary.VirtualTime_s(summary.Layout=="square")), ...
    'evidence',"CONSTRUCTED_CASES_ONLY_NOT_OFFICIAL");
q4WriteJson(fullfile(path,'summary.json'),output);
q4Figures(path,summary,grids,details,scenarios);
assert(output.allPassed,'Q4:OfflineFailure','A constructed scenario failed; all evidence has been retained.');
end

function audit = q4Audit(solution,sources,world)
contained = true;
silencePreserved = true;
for k = 1:numel(solution.history)
    item = solution.history(k);
    if item.kind=="no_signal"
        previous = find([solution.history(1:k-1).channel]==item.channel,1,'last');
        silencePreserved = silencePreserved && ~isempty(previous);
        if ~isempty(previous)
            for vertex = item.polygon'
                silencePreserved = silencePreserved && q4DistancePolygon(vertex',solution.history(previous).polygon)<=2e-5;
            end
        end
    end
    target = sources(sources(:,1)==item.channel,2:3);
    contained = contained && size(target,1)==1 && q4DistancePolygon(target,item.polygon)<=2e-5;
end
counts = zeros(1,20);
time = 0;
position = [0,0];
receiver = 1;
semantics = true;
safeClears = true;
certificateCount = 0;
actualCoverage = false(size(solution.coverage));
for k = 1:numel(solution.events)
    e = solution.events(k);
    at = [e.x,e.y];
    if ismember(e.path,["/measure","/clear"])
        time = time+norm(at-position)/5;
        position = at;
        row = find(sources(:,1)==e.channel,1);
        if e.path=="/measure"
            time = time+5+double(receiver~=e.channel);
            receiver = e.channel;
            actualCoverage(vecnorm(solution.points-at,2,2)<=1e-6,e.channel) = true;
            visible = false;
            distance = Inf;
            if ~isempty(row) && counts(e.channel)==0
                delta = at-sources(row,2:3);
                distance = hypot(delta(1),delta(2));
                halfPlane = cosd(sources(row,6))*delta(1)+sind(sources(row,6))*delta(2);
                visible = distance<=sources(row,4)+1e-9 && (sources(row,5)==0 || halfPlane>=-1e-9);
            end
            if e.result=="no_signal"
                semantics = semantics && ~visible;
            elseif e.result=="near"
                semantics = semantics && visible && distance<=5 && isnan(e.bearing);
            elseif e.result=="direction"
                trueAngle = atan2d(sources(row,3)-at(2),sources(row,2)-at(1));
                errorAngle = abs(mod(e.bearing-trueAngle+180,360)-180);
                semantics = semantics && visible && distance>5 && errorAngle<=1.0050001;
            else
                semantics = false;
            end
        else
            success = ~isempty(row) && counts(e.channel)==0 && norm(sources(row,2:3)-at)<=20+1e-9;
            semantics = semantics && success==(e.result=="success");
            time = time+3+2*success;
            if e.result=="success"
                counts(e.channel) = counts(e.channel)+1;
            end
            if isfinite(e.certRadius)
                certificateCount = certificateCount+1;
                cert = solution.certificates([solution.certificates.serial]==e.serial);
                prior = find([solution.history.channel]==e.channel & [solution.history.serial]<e.serial,1,'last');
                valid = ~isempty(prior) && numel(cert)==1 && isequal(cert.polygon,solution.history(prior).polygon) && cert.channel==e.channel && isequal(cert.position,at) && ...
                    q4ClearCovered(cert.polygon,at,19.5);
                safeClears = safeClears && e.certRadius<=19.5+1e-6 && success && valid;
            end
        end
    end
    semantics = semantics && abs(time-e.virtualTime)<=5e-5 && receiver==e.receiver;
end
safeClears = safeClears && certificateCount==numel(solution.certificates);
coverageReal = all(~solution.coverage | actualCoverage,'all');
absence = true;
if solution.complete && sum(solution.status==2)<16
    absent = find(solution.status==3);
    if isfield(solution,'tailPlan') && solution.tailPlan.applied
        tailAudit = q4TailAudit(solution);
        absence = tailAudit.allPassed && ~any(ismember(sources(:,1),absent));
    else
        absence = all(all(solution.coverage(:,absent))) && ~any(ismember(sources(:,1),absent));
    end
end
finite = numel(solution.events)<=solution.maximumActions && all(solution.localMeasures<=6) && all(solution.fallbackAttempts<=152);
opticalAudit = q4OpticalAudit(solution,sources);
audit = struct('positionContainment',contained,'actionAndTiming',semantics,'certifiedClears',safeClears,'actualCoverage',coverageReal, ...
    'absence',absence,'silenceNonExpansion',silencePreserved,'finiteActions',finite,'allSourcesCleared',all(world.cleared),'independentTiming_s',time,'opticalFeedback',opticalAudit);
audit.allPassed = opticalAudit.allPassed && silencePreserved && contained && semantics && safeClears && coverageReal && absence && finite && all(world.cleared) && solution.complete;
end

function q4SaveRun(path,solution,world,sources,settings)
q4WriteJson(fullfile(path,'joint_decisions.json'),solution.jointDecisions);
if isfield(solution,'tailPlan')
    q4WriteJson(fullfile(path,'coverage_plan.json'),solution.tailPlan);
end
q4WriteJson(fullfile(path,'optical_plans.json'),solution.opticalPlans);
q4WriteJson(fullfile(path,'optical_prunes.json'),solution.opticalPrunes);
q4WriteJson(fullfile(path,'optical_visits.json'),solution.opticalVisits);
save(fullfile(path,'run.mat'),'solution','world','sources','settings','-v7.3');
if ~isempty(solution.events)
    writetable(struct2table(solution.events),fullfile(path,'actions.csv'),'Encoding','UTF-8');
end
writetable(array2table(solution.coverage,'VariableNames',cellstr("Channel"+(1:20))),fullfile(path,'coverage.csv'),'Encoding','UTF-8');
if ~isempty(sources)
    writetable(array2table(sources,'VariableNames',{'Channel','X_m','Y_m','Reception_m','Directional','Axis_deg','ErrorMode'}),fullfile(path,'constructed_sources.csv'),'Encoding','UTF-8');
end
q4WriteJson(fullfile(path,'result.json'),struct('complete',solution.complete,'stopReason',solution.stopReason,'status',solution.status, ...
    'virtualTime_s',solution.virtualTime,'cleared',sum(solution.status==2),'costs',solution.costs,'failure',solution.failure));
end

function value = q4MeanTime(time,count)
value = NaN;
if count>0
    value = time/count;
end
end

function q4WriteJson(path,value)
fid = fopen(path,'w','n','UTF-8');
assert(fid>=0,'Q4:File','Could not create result file.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end

function q4Append(path,value)
fid = fopen(path,'a','n','UTF-8');
assert(fid>=0,'Q4:File','Could not append action evidence.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value));
end

function value = q4FileHash(path)
fid = fopen(path,'rb');
assert(fid>=0,'Q4:Hash','Source could not be read.');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
value = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end


function [points,triangles,info] = q4Grid(kind)
kind = lower(string(kind));
if isscalar(kind) && kind=="ring22"
    [points,triangles,info] = q4RingLayout();
    return
end
if ~isscalar(kind) || ~ismember(kind,["triangle","square","triangle990","triangle990shift"])
    error('q4:GridKind','Use one of the four fixed layouts.');
end
domainRadius = 1800;
minimumRange = 1000;
clipTolerance = 1e-8;
shift = [0,0];
if kind ~= "square"
    spacing = 900;
    if kind ~= "triangle"
        spacing = 990;
    end
    basis = [spacing,0;spacing/2,sqrt(3)*spacing/2];
    if kind == "triangle990shift"
        shift = sum(basis,1)/3;
    end
    extent = ceil(2*(domainRadius+spacing+norm(shift))/(sqrt(3)*spacing))+1;
    axisValues = -extent:extent;
    offsets = cat(3,[0,0;1,0;0,1],[1,1;0,1;1,0]);
else
    spacing = 650;
    basis = spacing*eye(2);
    extent = 3;
    axisValues = -3:2;
    offsets = cat(3,[0,0;1,0;1,1],[0,0;1,1;0,1]);
end
cellCoordinates = zeros(0,2);
for first = axisValues
    for second = axisValues
        for orientation = 1:2
            lattice = offsets(:,:,orientation)+[first,second];
            vertices = lattice*basis+shift;
            if q4OriginTriangleDistance(vertices) <= domainRadius+clipTolerance
                cellCoordinates = [cellCoordinates;lattice];
            end
        end
    end
end
if kind == "square"
    [first,second] = meshgrid(-3:3,-3:3);
    latticePoints = sortrows([first(:),second(:)]);
    [found,pointIndex] = ismember(cellCoordinates,latticePoints,'rows');
    if ~all(found)
        error('q4:SquareIndex','A square grid cell has an invalid vertex.');
    end
else
    [latticePoints,~,pointIndex] = unique(cellCoordinates,'rows');
end
points = latticePoints*basis+shift;
triangles = reshape(pointIndex,3,[])';
edgePairs = [triangles(:,[1,2]);triangles(:,[2,3]);triangles(:,[3,1])];
edgeLengths = vecnorm(points(edgePairs(:,1),:)-points(edgePairs(:,2),:),2,2);
info = struct('kind',kind,'spacing',spacing,'shift',shift,'stationCount',size(points,1),...
    'cellCount',size(triangles,1),'maxEdge',max(edgeLengths),...
    'domainRadius',domainRadius,'minimumRange',minimumRange,...
    'enumerationExtent',extent,'clipTolerance',clipTolerance,...
    'generationRule',"Keep full closed triangles intersecting the closed source disk");
end

function distance = q4OriginTriangleDistance(vertices)
edges = vertices([2,3,1],:)-vertices;
crossValues = edges(:,1).*(-vertices(:,2))-edges(:,2).*(-vertices(:,1));
if all(crossValues >= -1e-7) || all(crossValues <= 1e-7)
    distance = 0;
    return
end
fractions = min(1,max(0,-sum(vertices.*edges,2)./sum(edges.^2,2)));
nearest = vertices+fractions.*edges;
distance = min(vecnorm(nearest,2,2));
end

function [order,length] = q4OpenRoute(start,points)
if ~isequal(size(start),[1,2]) || size(points,2) ~= 2 || ...
        any(~isfinite(start),'all') || any(~isfinite(points),'all')
    error('q4:RouteInput','Route coordinates must be finite planar points.');
end
stationCount = size(points,1);
order = zeros(1,stationCount);
available = true(stationCount,1);
position = start;
for step = 1:stationCount
    distances = sum((points-position).^2,2);
    distances(~available) = Inf;
    [~,selected] = min(distances);
    order(step) = selected;
    available(selected) = false;
    position = points(selected,:);
end
for pass = 1:min(100,2*stationCount)
    bestChange = -1e-8;
    bestFirst = 0;
    bestLast = 0;
    for first = 1:stationCount-1
        if first == 1
            previous = start;
        else
            previous = points(order(first-1),:);
        end
        for last = first+1:stationCount
            left = points(order(first),:);
            right = points(order(last),:);
            change = norm(previous-right)-norm(previous-left);
            if last < stationCount
                following = points(order(last+1),:);
                change = change+norm(left-following)-norm(right-following);
            end
            if change < bestChange
                bestChange = change;
                bestFirst = first;
                bestLast = last;
            end
        end
    end
    if bestFirst == 0
        break
    end
    order(bestFirst:bestLast) = order(bestLast:-1:bestFirst);
end
route = [start;points(order,:)];
length = sum(vecnorm(diff(route,1,1),2,2));
end

function [checks,evidence] = q4CoverageChecks(points,triangles,info)
if isstruct(info) && isscalar(info) && isfield(info,'kind') && isscalar(string(info.kind)) && string(info.kind)=="ring22"
    [expectedPoints,expectedTriangles,expectedInfo] = q4RingLayout();
    valid = isequal(points,expectedPoints) && isequal(triangles,expectedTriangles) && isequaln(info,expectedInfo);
    checks = table("IndependentContinuousRingCover",valid,'VariableNames',{'Name','Passed'});
    evidence = struct('continuousCoverageSupported',valid,'stationCount',size(points,1),'certificate',expectedInfo.certificateSummary);
    return
end
names = strings(0,1);
passed = false(0,1);
evidence = struct('status',"INVALID_INPUT",'arithmetic',"double",...
    'formalIntervalCertificate',false,'sampledCasesAreContinuousProof',false);
validPoints = isnumeric(points) && size(points,2) == 2 && ~isempty(points) && all(isfinite(points),'all');
validTriangles = isnumeric(triangles) && size(triangles,2) == 3 && ~isempty(triangles) && ...
    all(isfinite(triangles),'all') && all(triangles == round(triangles),'all') && ...
    all(triangles >= 1,'all') && all(triangles <= size(points,1),'all');
requiredFields = {'kind','spacing','shift','stationCount','cellCount','maxEdge','domainRadius','minimumRange'};
validInfo = isstruct(info) && isscalar(info) && all(isfield(info,requiredFields));
if validInfo
    validInfo = isscalar(string(info.kind)) && ismember(string(info.kind),["triangle","square","triangle990","triangle990shift"]) && ...
        isscalar(info.spacing) && isfinite(info.spacing) && info.spacing > 0 && ...
        isnumeric(info.shift) && isequal(size(info.shift),[1,2]) && all(isfinite(info.shift)) && ...
        isscalar(info.domainRadius) && isfinite(info.domainRadius) && info.domainRadius > 0 && ...
        isscalar(info.minimumRange) && isfinite(info.minimumRange) && info.minimumRange > 0;
end
names(end+1,1) = "FinitePlanarStations"; passed(end+1,1) = validPoints;
names(end+1,1) = "ValidTriangleIndices"; passed(end+1,1) = validTriangles;
names(end+1,1) = "ValidCoverageMetadata"; passed(end+1,1) = validInfo;
if ~(validPoints && validTriangles && validInfo)
    checks = table(names,passed,'VariableNames',{'Name','Passed'});
    return
end
tolerance = 1e-7;
kind = string(info.kind);
expectedShift = [0,0];
if kind ~= "square"
    expectedSpacing = 900;
    if kind ~= "triangle"
        expectedSpacing = 990;
    end
    basis = [expectedSpacing,0;expectedSpacing/2,sqrt(3)*expectedSpacing/2];
    if kind == "triangle990shift"
        expectedShift = [495,165*sqrt(3)];
    end
    allowed = cat(3,sortrows([0,0;1,0;0,1]),sortrows([1,1;0,1;1,0]));
else
    expectedSpacing = 650;
    basis = expectedSpacing*eye(2);
    allowed = cat(3,sortrows([0,0;1,0;1,1]),sortrows([0,0;1,1;0,1]));
end
lattice = (points-expectedShift)/basis;
integerLattice = round(lattice);
canonical = all(abs(lattice-integerLattice) <= 1e-10,'all');
for cellIndex = 1:size(triangles,1)
    vertices = integerLattice(triangles(cellIndex,:),:);
    normalized = sortrows(vertices-min(vertices,[],1));
    canonical = canonical && (isequal(normalized,allowed(:,:,1)) || isequal(normalized,allowed(:,:,2)));
end
uniqueStations = size(unique(integerLattice,'rows'),1) == size(points,1);
uniqueCells = size(unique(sort(triangles,2),'rows'),1) == size(triangles,1);
allEdges = sort([triangles(:,[1,2]);triangles(:,[2,3]);triangles(:,[3,1])],2);
[edgePairs,~,edgeIndex] = unique(allEdges,'rows');
edgeCounts = accumarray(edgeIndex,1);
edgeLengths = vecnorm(points(edgePairs(:,1),:)-points(edgePairs(:,2),:),2,2);
boundaryEdges = edgePairs(edgeCounts == 1,:);
edgeStart = points(boundaryEdges(:,1),:);
edgeVector = points(boundaryEdges(:,2),:)-edgeStart;
projection = min(1,max(0,-sum(edgeStart.*edgeVector,2)./sum(edgeVector.^2,2)));
boundaryDistances = vecnorm(edgeStart+projection.*edgeVector,2,2);
originContained = false;
for cellIndex = 1:size(triangles,1)
    vertices = points(triangles(cellIndex,:),:);
    coordinates = [vertices';ones(1,3)]\[0;0;1];
    if all(isfinite(coordinates)) && all(coordinates >= -1e-10)
        originContained = true;
        break
    end
end
boundaryOutside = ~isempty(boundaryDistances) && all(boundaryDistances >= info.domainRadius-tolerance);
meshPredicates = canonical && uniqueStations && uniqueCells && all(edgeCounts <= 2) && ...
    originContained && boundaryOutside;
strictRange = all(edgeLengths < info.minimumRange-tolerance);
inDomain = find(vecnorm(points,2,2) <= info.domainRadius+tolerance);
neighborCount = zeros(numel(inDomain),1);
maximumGap = Inf(numel(inDomain),1);
vertexDirectionsPassed = true;
directionNormals = [cosd((0:5:355)'),sind((0:5:355)')];
for sourceIndex = 1:numel(inDomain)
    offsets = points-points(inDomain(sourceIndex),:);
    distances = vecnorm(offsets,2,2);
    offsets = offsets(distances > tolerance & distances <= info.minimumRange-tolerance,:);
    neighborCount(sourceIndex) = size(offsets,1);
    if ~isempty(offsets)
        angles = sort(atan2(offsets(:,2),offsets(:,1)));
        maximumGap(sourceIndex) = max(diff([angles;angles(1)+2*pi]));
        vertexDirectionsPassed = vertexDirectionsPassed && all(max(offsets*directionNormals',[],1) >= -tolerance);
    else
        vertexDirectionsPassed = false;
    end
end
vertexNeighborhoods = ~isempty(maximumGap) && all(maximumGap <= pi+1e-10);
boundaryAngles = (0:2:358)'*pi/180;
boundarySources = info.domainRadius*[cos(boundaryAngles),sin(boundaryAngles)];
boundaryDirectionOffsets = [0,pi/2,-pi/2];
boundaryCaseCount = numel(boundaryAngles)*numel(boundaryDirectionOffsets);
boundaryCasePassed = true(boundaryCaseCount,1);
boundaryWitnesses = zeros(boundaryCaseCount,1);
caseIndex = 0;
for sourceIndex = 1:size(boundarySources,1)
    offsets = points-boundarySources(sourceIndex,:);
    distances = vecnorm(offsets,2,2);
    nearIndices = find(distances > tolerance & distances <= info.minimumRange-tolerance);
    for directionOffset = boundaryDirectionOffsets
        caseIndex = caseIndex+1;
        direction = boundaryAngles(sourceIndex)+directionOffset;
        products = offsets(nearIndices,:)*[cos(direction);sin(direction)];
        visible = find(products >= -tolerance,1);
        if isempty(visible)
            boundaryCasePassed(caseIndex) = false;
        else
            boundaryWitnesses(caseIndex) = nearIndices(visible);
        end
    end
end
metadataMatches = info.spacing == expectedSpacing && norm(info.shift-expectedShift)<=tolerance && info.domainRadius == 1800 && info.minimumRange == 1000 && ...
    info.stationCount == size(points,1) && info.cellCount == size(triangles,1) && abs(info.maxEdge-max(edgeLengths)) <= tolerance;
squareShape = true;
if kind == "square"
    [first,second] = meshgrid(-3:3,-3:3);
    squareShape = isequal(sortrows(integerLattice),sortrows([first(:),second(:)]));
end
newNames = ["UniqueStations";"CanonicalNonoverlappingGridCells";"UniqueTriangleCells";...
    "AtMostTwoCellsPerEdge";"OriginContainedInMesh";"BoundaryOutsideSourceDisk";...
    "ContinuousDiskMeshPredicates";"StrictMinimumRangeMargin";...
    "VertexContinuousDirectionGap";"VertexDirectionSamples";...
    "BoundaryOutwardAndTangentSamples";"OriginStationMatchesLayout";...
    "ExternalStationsIncluded";"MetadataMatchesGeometry";"Square49StationShape"];
newPassed = [uniqueStations;canonical;uniqueCells;all(edgeCounts <= 2);originContained;boundaryOutside;...
    meshPredicates;strictRange;vertexNeighborhoods;vertexDirectionsPassed;all(boundaryCasePassed);...
    (any(vecnorm(points,2,2) < tolerance) == (kind~="triangle990shift"));any(vecnorm(points,2,2) > info.domainRadius+tolerance);...
    metadataMatches;squareShape];
checks = table([names;newNames],[passed;newPassed],'VariableNames',{'Name','Passed'});
evidence.status = "ANALYTIC_PROOF_WITH_FINITE_FLOATING_POINT_MESH_CHECKS";
evidence.continuousCoverageSupported = meshPredicates && strictRange && vertexNeighborhoods && metadataMatches;
evidence.stationCount = size(points,1);
evidence.spacing = expectedSpacing;
evidence.shift = expectedShift;
evidence.cellCount = size(triangles,1);
evidence.maximumCellEdge = max(edgeLengths);
evidence.rangeMargin = info.minimumRange-max(edgeLengths);
evidence.minimumBoundaryDistance = min(boundaryDistances);
evidence.boundaryDistanceMargin = min(boundaryDistances)-info.domainRadius;
evidence.boundaryEdges = boundaryEdges;
evidence.boundaryDistances = boundaryDistances;
evidence.vertexNeighborhoods = table(inDomain,neighborCount,maximumGap*180/pi,...
    'VariableNames',{'StationIndex','NeighborCount','MaximumAngularGapDegrees'});
evidence.boundaryCaseCount = boundaryCaseCount;
evidence.boundaryCasePassed = boundaryCasePassed;
evidence.boundaryWitnesses = boundaryWitnesses;
evidence.vertexDirectionCaseCount = numel(inDomain)*size(directionNormals,1);
evidence.proof = "Canonical grid triangles have disjoint interiors. Origin inclusion and absence of mesh boundary inside the source disk imply full disk inclusion. Every containing triangle vertex is within its maximum edge length. A convex combination guarantees a point in every closed emission half-plane. At lattice sources, nonzero nearby points with maximum angular gap at most pi remove zero-vector degeneracy.";
end


function [exchange,report] = q4Transport(config)
assert(isstruct(config) && isscalar(config) && all(isfield(config,{'baseUrl','robotId','outputPath'})), ...
    'Q4:TransportConfig','Transport requires baseUrl, robotId, and outputPath.');
defaults = struct('requestTimeoutSec',10,'maxAttempts',3,'retryPauseSec',0.1,'exitReserveSec',15);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(config,names{index})
        config.(names{index}) = defaults.(names{index});
    end
end
assert(q4TransportNumber(config.requestTimeoutSec,0.05,60) ...
    && q4TransportNumber(config.maxAttempts,1,8) && fix(config.maxAttempts) == config.maxAttempts ...
    && q4TransportNumber(config.retryPauseSec,0,5) && q4TransportNumber(config.exitReserveSec,1,120), ...
    'Q4:TransportConfig','Invalid bounded timeout, retry, or exit reserve setting.');
assert(q4TransportText(config.baseUrl) && ~isempty(regexp(char(config.baseUrl), ...
    '^http://(127\.0\.0\.1|localhost):[0-9]{1,5}$','once')), ...
    'Q4:TransportConfig','The simulator URL must be a local HTTP address without a trailing slash.');
assert(q4TransportText(config.robotId) && ~isempty(char(config.robotId)) ...
    && numel(unicode2native(char(config.robotId),'UTF-8')) <= 64 ...
    && q4TransportIdentifier(config.robotId), ...
    'Q4:TransportConfig','Invalid robot identifier.');
assert(q4TransportText(config.outputPath) && isfolder(config.outputPath), ...
    'Q4:TransportConfig','Create a dedicated output directory before constructing the transport.');
ledgerPath = fullfile(config.outputPath,'request_response.jsonl');
assert(~isfile(ledgerPath),'Q4:ExistingOutput','The request ledger already exists; use a new output directory.');
timer = tic;
clock = struct('now',@() toc(timer),'sleep',@(duration) pause(duration));
if isfield(config,'clock')
    clock = config.clock;
end
assert(isstruct(clock) && all(isfield(clock,{'now','sleep'})) ...
    && isa(clock.now,'function_handle') && isa(clock.sleep,'function_handle'), ...
    'Q4:TransportConfig','Invalid transport clock.');
sender = @(path,body,timeout) q4TransportHttp(config.baseUrl,path,body,timeout);
if isfield(config,'sender')
    assert(isa(config.sender,'function_handle'),'Q4:TransportConfig','sender must be a function handle.');
    sender = config.sender;
end
entered = false;
exited = false;
busy = false;
pending = [];
position = [0,0];
receiver = 1;
virtualTime = 0;
maxVirtual = 360000;
deadline = Inf;
enterStarted = NaN;
programEnded = NaN;
clearedChannels = zeros(1,0);
costs = zeros(1,5);
rows = cell(0,11);
lastFault = struct('identifier','','message','');
cache = containers.Map('KeyType','char','ValueType','any');
exchange = @q4Dispatch;
report = @q4Report;

    function response = q4Dispatch(path,payload)
        assert(~busy,'Q4:Serial','A request is already active.');
        busy = true;
        try
            response = q4Execute(path,payload);
        catch errorInfo
            busy = false;
            rethrow(errorInfo)
        end
        busy = false;
    end

    function response = q4Execute(path,payload)
        path = string(path);
        q4TransportRequest(path,payload,config.robotId);
        key = char(payload.request_id);
        body = jsonencode(payload);
        signature = char(path+"|"+string(body));
        if isKey(cache,key)
            previous = cache(key);
            assert(strcmp(previous.signature,signature),'Q4:Conflict','A completed request ID has different content.');
            response = previous.response;
            return
        end
        assert(~exited,'Q4:State','The session has already exited.');
        if ~isempty(pending)
            assert(strcmp(pending.signature,signature),'Q4:Pending', ...
                'Only the exact pending path, body, and request ID may be retried.');
            body = pending.body;
        else
            if path == "/enter"
                assert(~entered && isnan(enterStarted),'Q4:State','A new entry is not permitted.');
            else
                assert(entered,'Q4:State','The session has not entered.');
                if path ~= "/exit"
                    assert(clock.now() < deadline-config.exitReserveSec-0.05,'Q4:RealBudget', ...
                        'New actions stopped to preserve time for exit.');
                    target = [payload.position.x,payload.position.y];
                    predicted = norm(target-position)/5+5;
                    if path == "/measure"
                        predicted = predicted+double(payload.channel ~= receiver);
                    end
                    assert(virtualTime+predicted < maxVirtual,'Q4:VirtualBudget', ...
                        'The proposed action would exhaust the virtual budget.');
                end
            end
        end
        for attempt = 1:config.maxAttempts
            allowance = Inf;
            if entered
                allowance = deadline-clock.now();
                if path ~= "/exit"
                    allowance = allowance-config.exitReserveSec;
                end
            end
            assert(allowance > 0.05,'Q4:RealBudget','No safe request time remains; inspect pending before exit.');
            timeout = min(config.requestTimeoutSec,allowance-0.01);
            q4Record(struct('event','request','path',path,'requestId',key,'body',body, ...
                'payload',payload,'attempt',attempt,'timeoutSec',timeout));
            if entered
                allowance = deadline-clock.now();
                if path ~= "/exit"
                    allowance = allowance-config.exitReserveSec;
                end
                assert(allowance > 0.05,'Q4:RealBudget','Persistence consumed the remaining request budget.');
                timeout = min(timeout,allowance-0.01);
            end
            if isempty(pending)
                pending = struct('path',path,'payload',payload,'body',body,'requestId',key, ...
                    'signature',signature,'firstSentAt_s',clock.now(),'attempts',0,'stage','prepared');
            end
            if path == "/enter" && isnan(enterStarted)
                enterStarted = pending.firstSentAt_s;
            end
            pending.attempts = pending.attempts+1;
            pending.stage = 'sent_unresolved';
            try
                packet = sender(char(path),body,timeout);
            catch errorInfo
                lastFault = struct('identifier',errorInfo.identifier,'message',errorInfo.message);
                q4Record(struct('event','transport_error','requestId',key,'attempt',attempt, ...
                    'identifier',errorInfo.identifier,'message',errorInfo.message));
                if attempt == config.maxAttempts
                    error('Q4:Unresolved','The same request remains unresolved after %d attempts: %s.',attempt,key);
                end
                sleepTime = config.retryPauseSec;
                if entered
                    sleepTime = min(sleepTime,max(0,deadline-clock.now()-config.exitReserveSec-0.05));
                end
                if sleepTime > 0
                    clock.sleep(sleepTime);
                end
                continue
            end
            pending.stage = 'response_received_unconfirmed';
            pending.packet = packet;
            q4Record(struct('event','response','requestId',key,'attempt',attempt,'packet',packet));
            assert(isstruct(packet) && isscalar(packet) && all(isfield(packet,{'statusCode','body'})) ...
                && q4TransportNumber(packet.statusCode,100,599) && fix(packet.statusCode) == packet.statusCode, ...
                'Q4:Response','Malformed HTTP packet; the request remains pending.');
            response = packet.body;
            if q4TransportText(response)
                try
                    response = jsondecode(char(response));
                catch
                    error('Q4:Response','Invalid JSON response; the request remains pending.');
                end
            end
            assert(isstruct(response) && isscalar(response) ...
                && all(isfield(response,{'accepted','real_timestamp_ms','virtual_time_s'})) ...
                && islogical(response.accepted) && isscalar(response.accepted) ...
                && q4TransportNumber(response.real_timestamp_ms,0,Inf) ...
                && q4TransportNumber(response.virtual_time_s,0,Inf), ...
                'Q4:Response','Malformed response fields; the request remains pending.');
            if packet.statusCode == 409
                error('Q4:Conflict','HTTP 409; inspect the saved request ledger before continuing.');
            end
            if packet.statusCode ~= 200
                if ~response.accepted && ismember(packet.statusCode,[400,404,405,413,415])
                    pending = [];
                    if path == "/enter"
                        enterStarted = NaN;
                    end
                end
                error('Q4:HttpStatus','HTTP %d; no accepted action was returned.',packet.statusCode);
            end
            if ~response.accepted
                pending = [];
                if path == "/enter"
                    enterStarted = NaN;
                end
                error('Q4:Rejected','The request was rejected; confirmed state was not changed.');
            end
            q4TransportResponse(path,response);
            target = position;
            nextReceiver = receiver;
            channel = NaN;
            bearing = NaN;
            result = "entered";
            stepCosts = zeros(1,5);
            if path == "/measure" || path == "/clear"
                target = [payload.position.x,payload.position.y];
                channel = payload.channel;
                stepCosts(1) = norm(target-position);
                if path == "/measure"
                    stepCosts(2) = double(channel ~= receiver);
                    stepCosts(3) = 5;
                    nextReceiver = channel;
                    result = string(response.measure_result);
                    if result == "direction"
                        bearing = response.svd_deg;
                    end
                else
                    result = string(response.clear_result);
                    if result == "success"
                        stepCosts(5) = 5;
                    else
                        stepCosts(4) = 3;
                    end
                end
            elseif path == "/exit"
                result = string(response.exit_reason);
            end
            stepTime = stepCosts(1)/5+sum(stepCosts(2:5));
            expectedTime = (round(virtualTime*1e6)+round(stepTime*1e6))/1e6;
            residual = response.virtual_time_s-expectedTime;
            assert(abs(residual) <= 2e-6+8*eps(max(1,abs(expectedTime))), ...
                'Q4:TimeAccounting','Reported virtual time disagrees with the action cost; the request remains pending.');
            if path == "/enter"
                entered = true;
                deadline = enterStarted+response.remaining_real_duration_s;
                maxVirtual = response.max_virtual_duration_s;
            elseif path == "/exit"
                exited = true;
                programEnded = clock.now();
            elseif path == "/clear" && result == "success"
                clearedChannels = unique([clearedChannels,channel]);
            end
            position = target;
            receiver = nextReceiver;
            virtualTime = response.virtual_time_s;
            costs = costs+stepCosts;
            rows(end+1,:) = {string(key),path,position(1),position(2),channel,result,bearing, ...
                virtualTime,receiver,residual,true};
            cache(key) = struct('signature',signature,'response',response);
            pending = [];
            return
        end
        error('Q4:Unresolved','The request remains pending.');
    end

    function q4Record(event)
        event.timestampUtc = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
        event.clientElapsed_s = clock.now();
        q4TransportAppend(ledgerPath,event);
    end

    function state = q4Report()
        elapsed = NaN;
        if ~isnan(enterStarted)
            ended = programEnded;
            if isnan(ended)
                ended = clock.now();
            end
            elapsed = ended-enterStarted;
        end
        log = cell2table(rows,'VariableNames',{'RequestId','Path','X_m','Y_m','Channel', ...
            'Result','Bearing_deg','VirtualTime_s','Receiver','TimeResidual_s','Accepted'});
        state = struct('pending',pending,'unresolved',~isempty(pending),'entered',entered,'exited',exited, ...
            'closed',exited,'busy',busy,'virtualTime',virtualTime,'position',position,'receiver',receiver, ...
            'remainingRealSec',max(0,deadline-clock.now()),'deadline_s',deadline,'programElapsed',elapsed, ...
            'clearedChannels',clearedChannels,'acceptedActions',size(rows,1),'log',log,'costs',costs, ...
            'lastFault',lastFault,'ledgerPath',ledgerPath);
    end
end

function q4TransportRequest(path,payload,robotId)
assert(isscalar(path) && ismember(path,["/enter","/measure","/clear","/exit"]), ...
    'Q4:Request','Only the four official exact paths are allowed.');
fields = {'arena_id';'robot_id';'request_id'};
if path == "/measure" || path == "/clear"
    fields = [fields;{'position';'channel'}];
end
assert(isstruct(payload) && isscalar(payload) && isequal(sort(fieldnames(payload)),sort(fields)), ...
    'Q4:Request','Unexpected or missing request fields.');
assert(q4TransportText(payload.arena_id) && strcmp(payload.arena_id,'default') ...
    && q4TransportText(payload.robot_id) && strcmp(payload.robot_id,robotId) ...
    && q4TransportText(payload.request_id),'Q4:Request','Request identity mismatch.');
assert(~isempty(regexp(char(payload.request_id),'^[A-Za-z0-9_-]{1,128}$','once')), ...
    'Q4:Request','Use an ASCII alphanumeric request ID with optional hyphens or underscores.');
if isfield(payload,'position')
    assert(isstruct(payload.position) && isscalar(payload.position) ...
        && isequal(sort(fieldnames(payload.position)),{'x';'y'}) ...
        && q4TransportNumber(payload.position.x,-2e6,2e6) && q4TransportNumber(payload.position.y,-2e6,2e6) ...
        && q4TransportNumber(payload.channel,1,20) && fix(payload.channel) == payload.channel, ...
        'Q4:Request','Invalid finite position or integer channel.');
end
end

function q4TransportResponse(path,response)
if path == "/enter"
    assert(all(isfield(response,{'max_virtual_duration_s','max_real_duration_s','remaining_real_duration_s'})) ...
        && q4TransportNumber(response.max_virtual_duration_s,1,360000) ...
        && q4TransportNumber(response.max_real_duration_s,1,1200) ...
        && q4TransportNumber(response.remaining_real_duration_s,0,response.max_real_duration_s), ...
        'Q4:Response','Invalid entry time budget.');
elseif path == "/measure"
    assert(isfield(response,'measure_result') && q4TransportText(response.measure_result) ...
        && ismember(string(response.measure_result),["direction","near","no_signal"]), ...
        'Q4:Response','Invalid measurement result.');
    if string(response.measure_result) == "direction"
        assert(isfield(response,'svd_deg') && q4TransportNumber(response.svd_deg,0,360) && response.svd_deg < 360, ...
            'Q4:Response','A direction result requires a finite bearing in [0,360).');
    end
elseif path == "/clear"
    assert(isfield(response,'clear_result') && q4TransportText(response.clear_result) ...
        && ismember(string(response.clear_result),["success","no_target_in_range"]), ...
        'Q4:Response','Invalid clearing result.');
else
    assert(isfield(response,'exit_reason') && q4TransportText(response.exit_reason) ...
        && string(response.exit_reason) == "user_exit",'Q4:Response','Invalid exit result.');
end
end

function valid = q4TransportNumber(value,lower,upper)
valid = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value >= lower && value <= upper;
end

function valid = q4TransportText(value)
valid = (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value) && ~ismissing(value));
end

function valid = q4TransportIdentifier(value)
codes = double(char(value));
valid = true;
index = 1;
while index <= numel(codes)
    point = codes(index);
    if point >= 55296 && point <= 56319
        if index == numel(codes) || codes(index+1) < 56320 || codes(index+1) > 57343
            valid = false;
            return
        end
        point = 65536+1024*(point-55296)+codes(index+1)-56320;
        index = index+1;
    elseif point >= 56320 && point <= 57343
        valid = false;
        return
    end
    if point <= 31 || (point >= 127 && point <= 159) ...
            || (point > 159 && double(javaMethod('getType','java.lang.Character',int32(point))) == 16)
        valid = false;
        return
    end
    index = index+1;
end
end

function packet = q4TransportHttp(baseUrl,path,body,timeout)
sendTimer = tic;
persistent netReady
if isempty(netReady)
    NET.addAssembly('System.Net.Http');
    netReady = true;
end
handler = System.Net.Http.HttpClientHandler;
handler.UseProxy = false;
handler.AllowAutoRedirect = false;
handler.UseCookies = false;
client = System.Net.Http.HttpClient(handler);
clientCleanup = onCleanup(@() client.Dispose());
client.MaxResponseContentBufferSize = int64(1048576);
cancellation = System.Threading.CancellationTokenSource;
cancelCleanup = onCleanup(@() cancellation.Dispose());
content = System.Net.Http.StringContent(char(body),System.Text.Encoding.UTF8,'application/json');
contentCleanup = onCleanup(@() content.Dispose());
try
    remaining = timeout-toc(sendTimer);
    assert(remaining > 0.01,'Q4:RequestTimeout','HTTP initialization exhausted its total timeout.');
    client.Timeout = System.TimeSpan.FromSeconds(remaining);
    cancellation.CancelAfter(int32(max(1,floor(1000*remaining))));
    responseTask = client.PostAsync([char(baseUrl),char(path)],content,cancellation.Token);
    while ~responseTask.IsCompleted
        remaining = timeout-toc(sendTimer);
        assert(remaining > 0,'Q4:RequestTimeout','The complete HTTP response exceeded its total timeout.');
        pause(min(0.01,remaining));
    end
    response = responseTask.Result;
    responseCleanup = onCleanup(@() response.Dispose());
    textTask = response.Content.ReadAsStringAsync();
    packet = struct('statusCode',double(response.StatusCode),'body',char(textTask.Result));
catch errorInfo
    cancellation.Cancel();
    rethrow(errorInfo)
end
end

function q4TransportAppend(path,value)
bytes = unicode2native([jsonencode(value),newline],'UTF-8');
handle = fopen(path,'a','n','UTF-8');
assert(handle >= 0,'Q4:Log','Cannot open the request ledger.');
try
    count = fwrite(handle,bytes,'uint8');
    [message,errorNumber] = ferror(handle);
    closeStatus = fclose(handle);
catch errorInfo
    try
        fclose(handle);
    catch
    end
    rethrow(errorInfo)
end
assert(count == numel(bytes) && errorNumber == 0 && closeStatus == 0, ...
    'Q4:Log','The complete request or response could not be persisted: %s',message);
end

function checks = q4TransportChecks(outputPath)
assert(isfolder(outputPath),'Q4:CheckOutput','Create a dedicated transport check output directory.');
modes = ["lost_response","rejected","malformed","wrong_clock","real_budget","invalid_request"];
passed = false(numel(modes),1);
details = strings(numel(modes),1);
for index = 1:numel(modes)
    folder = fullfile(outputPath,char(modes(index)));
    assert(~isfolder(folder),'Q4:ExistingOutput','Use a fresh transport check directory.');
    mkdir(folder);
    try
        q4TransportCheckCase(folder,modes(index));
        passed(index) = true;
        details(index) = "Constructed sender check passed; no simulator connection.";
    catch errorInfo
        details(index) = string(errorInfo.identifier)+": "+string(errorInfo.message);
    end
end
checks = table(modes',passed,details,'VariableNames',{'Name','Passed','Details'});
end

function q4TransportCheckCase(outputPath,mode)
nowTime = 0;
sentBodies = strings(0,1);
sentPaths = strings(0,1);
worldCache = containers.Map('KeyType','char','ValueType','any');
worldTime = 0;
worldPosition = [0,0];
worldReceiver = 1;
worldActions = 0;
faultInjected = false;
config = struct('baseUrl','http://127.0.0.1:2026','robotId','transport-check','outputPath',outputPath, ...
    'sender',@q4FakeSend,'clock',struct('now',@q4FakeNow,'sleep',@q4FakeSleep), ...
    'requestTimeoutSec',1,'maxAttempts',2,'retryPauseSec',0,'exitReserveSec',3);
[exchange,report] = q4Transport(config);
entry = q4CheckPayload('entry');
exchange('/enter',entry);
action = q4CheckPayload('action');
action.position = struct('x',3,'y',4);
action.channel = 2;
exitPayload = q4CheckPayload('exit');
if mode == "lost_response"
    response = exchange('/measure',action);
    count = numel(sentBodies);
    duplicate = exchange('/measure',action);
    assert(isequal(response,duplicate) && numel(sentBodies) == count && sentBodies(2) == sentBodies(3) ...
        && sentPaths(2) == sentPaths(3),'Q4:Check','Lost response retry or cached deduplication failed.');
    action.request_id = 'clear';
    action.channel = 3;
    exchange('/clear',action);
    state = report();
    assert(state.receiver == 2 && state.virtualTime == 12 && isequal(state.clearedChannels,3), ...
        'Q4:Check','Clear changed receiver or accounting.');
    action.request_id = 'measure-again';
    action.channel = 2;
    exchange('/measure',action);
    exchange('/exit',exitPayload);
    state = report();
    assert(state.exited && isempty(state.pending) && state.virtualTime == 17 ...
        && state.acceptedActions == 5 && worldActions == 5,'Q4:Check','Deduplicated final state mismatch.');
elseif mode == "rejected"
    q4CheckError(@() exchange('/measure',action),'Q4:Rejected');
    state = report();
    assert(state.virtualTime == 0 && isequal(state.position,[0,0]) && isempty(state.pending) ...
        && state.acceptedActions == 1,'Q4:Check','Rejected response changed confirmed state.');
    exchange('/exit',exitPayload);
elseif mode == "malformed" || mode == "wrong_clock"
    identifier = 'Q4:Response';
    if mode == "wrong_clock"
        identifier = 'Q4:TimeAccounting';
    end
    q4CheckError(@() exchange('/measure',action),identifier);
    state = report();
    assert(state.virtualTime == 0 && state.acceptedActions == 1 && ~isempty(state.pending), ...
        'Q4:Check','Invalid response changed confirmed state or discarded pending.');
    count = numel(sentBodies);
    q4CheckError(@() exchange('/exit',exitPayload),'Q4:Pending');
    assert(numel(sentBodies) == count,'Q4:Check','A new exit was sent while an action remained unresolved.');
    exchange('/measure',action);
    state = report();
    assert(state.virtualTime == 7 && state.acceptedActions == 2 && isempty(state.pending), ...
        'Q4:Check','Identical request recovery did not restore confirmed state.');
elseif mode == "real_budget"
    nowTime = 3;
    q4CheckError(@() exchange('/measure',action),'Q4:RealBudget');
    state = report();
    assert(numel(sentBodies) == 1 && isempty(state.pending) && state.remainingRealSec == 2, ...
        'Q4:Check','Entry remaining time or unsent budget stop mismatch.');
    exchange('/exit',exitPayload);
    state = report();
    assert(state.exited,'Q4:Check','The exit reserve was not usable.');
else
    action.position.x = NaN;
    q4CheckError(@() exchange('/measure',action),'Q4:Request');
    state = report();
    assert(numel(sentBodies) == 1 && isempty(state.pending) && state.acceptedActions == 1, ...
        'Q4:Check','Invalid input reached the sender.');
end

    function payload = q4CheckPayload(key)
        payload = struct('arena_id','default','robot_id','transport-check','request_id',key);
    end

    function q4FakeSleep(duration)
        nowTime = nowTime+duration;
    end

    function value = q4FakeNow()
        value = nowTime;
    end

    function packet = q4FakeSend(path,body,timeout)
        assert(timeout > 0,'Q4:Check','A nonpositive timeout reached the sender.');
        sentBodies(end+1,1) = string(body);
        sentPaths(end+1,1) = string(path);
        payload = jsondecode(body);
        key = char(payload.request_id);
        if isKey(worldCache,key)
            packet = worldCache(key);
            return
        end
        response = struct('accepted',true,'real_timestamp_ms',1000*nowTime,'virtual_time_s',worldTime);
        if strcmp(path,'/enter')
            response.max_virtual_duration_s = 360000;
            response.max_real_duration_s = 1200;
            response.remaining_real_duration_s = 100;
            if mode == "real_budget"
                response.remaining_real_duration_s = 5;
            end
        elseif strcmp(path,'/exit')
            response.exit_reason = 'user_exit';
        elseif mode == "rejected" && strcmp(path,'/measure')
            response.accepted = false;
            response.virtual_time_s = 0;
            packet = struct('statusCode',200,'body',response);
            return
        else
            target = [payload.position.x,payload.position.y];
            increment = norm(target-worldPosition)/5+5;
            worldPosition = target;
            if strcmp(path,'/measure')
                increment = increment+double(payload.channel ~= worldReceiver);
                worldReceiver = payload.channel;
                response.measure_result = 'direction';
                response.svd_deg = 30;
            else
                response.clear_result = 'success';
            end
            worldTime = (round(worldTime*1e6)+round(increment*1e6))/1e6;
            response.virtual_time_s = worldTime;
        end
        worldActions = worldActions+1;
        packet = struct('statusCode',200,'body',response);
        worldCache(key) = packet;
        if strcmp(path,'/measure') && ~faultInjected
            faultInjected = true;
            if mode == "lost_response"
                error('Q4:InjectedLoss','The backend executed the action but its first response was lost.');
            elseif mode == "malformed"
                packet.body.svd_deg = NaN;
            elseif mode == "wrong_clock"
                packet.body.virtual_time_s = packet.body.virtual_time_s+1;
            end
        end
    end
end

function q4CheckError(action,identifier)
observed = '';
try
    action();
catch errorInfo
    observed = errorInfo.identifier;
end
assert(strcmp(observed,identifier),'Q4:Check','Expected %s but received %s.',identifier,observed);
end


function checks = q4LayoutChecks()
names = strings(0,1);
passed = false(0,1);
kinds = ["triangle990","triangle990shift"];
expected = [31,42;27,37];
for index = 1:numel(kinds)
    [points,triangles,info] = q4Grid(kinds(index));
    [baseChecks,evidence] = q4CoverageChecks(points,triangles,info);
    names(end+1,1) = kinds(index)+" / FixedCandidateGeometry";
    passed(end+1,1) = all(baseChecks.Passed) && evidence.continuousCoverageSupported && ...
        size(points,1)==expected(index,1) && size(triangles,1)==expected(index,2) && abs(evidence.rangeMargin-10)<1e-7;
    centers = (points(triangles(:,1),:)+points(triangles(:,2),:)+points(triangles(:,3),:))/3;
    [~,cellIndex] = min(vecnorm(centers,2,2));
    damaged = triangles;
    damaged(cellIndex,:) = [];
    changed = info;
    changed.cellCount = size(damaged,1);
    [~,badEvidence] = q4CoverageChecks(points,damaged,changed);
    names(end+1,1) = kinds(index)+" / MissingInteriorCellRejected";
    passed(end+1,1) = ~badEvidence.continuousCoverageSupported;
    changed = info;
    changed.shift = changed.shift+[1,0];
    [~,badEvidence] = q4CoverageChecks(points,triangles,changed);
    names(end+1,1) = kinds(index)+" / ForgedShiftRejected";
    passed(end+1,1) = ~badEvidence.continuousCoverageSupported;
    changed = info;
    changed.shift = [NaN,0];
    [badChecks,~] = q4CoverageChecks(points,triangles,changed);
    names(end+1,1) = kinds(index)+" / NonfiniteShiftRejected";
    passed(end+1,1) = ~all(badChecks.Passed);
    damagedPoints = points*1.02;
    changed = info;
    changed.maxEdge = 1009.8;
    [badChecks,badEvidence] = q4CoverageChecks(damagedPoints,triangles,changed);
    names(end+1,1) = kinds(index)+" / RangeAndLatticeViolationRejected";
    passed(end+1,1) = ~badEvidence.continuousCoverageSupported && ~badChecks.Passed(badChecks.Name=="StrictMinimumRangeMargin");
end
[points,triangles,info] = q4Grid("triangle");
names(end+1,1) = "Baseline37StationDefinitionPreserved";
passed(end+1,1) = size(points,1)==37 && size(triangles,1)==54 && info.spacing==900 && isequal(info.shift,[0,0]);
checks = table(names,passed,'VariableNames',{'Name','Passed'});
end

function checks = q4CoreChecks()
names = strings(0,1);
passed = false(0,1);
square = [-2,-2;2,-2;2,2;-2,2];
clipped = q4Plane(square,[1,0],0);
record("HalfPlaneCrossingAndClosedBoundary",all(clipped(:,1)<=1e-7) && ...
    q4DistancePolygon([-1,0],clipped)<=1e-7 && q4DistancePolygon([0,1],clipped)<=1e-7 && ...
    q4DistancePolygon([1,0],clipped)>0.99 && abs(polyarea(clipped(:,1),clipped(:,2))-8)<1e-6);
record("HalfPlaneEmptyIntersection",isempty(q4Plane(square,[1,0],-3)));
polygon = q4Wedge(q4Disk([0,0],1800,72),[0,0],359.8,1.01);
targets = 1000*[cosd([358.8;359.8;0.8]),sind([358.8;359.8;0.8])];
ok = q4DistancePolygon([-100,0],polygon)>99;
for k = 1:size(targets,1)
    ok = ok && q4DistancePolygon(targets(k,:),polygon)<1e-6;
end
record("WedgeAcrossZeroAndForwardOnly",ok);
ok = true;
for angle = [0,90,180,270,359.999]
    anchor = [70,-130];
    polygon = q4Wedge(q4Disk([0,0],1800,72),anchor,angle,1.01);
    for errorAngle = [-1,0,1]
        target = anchor+1000*[cosd(angle+errorAngle),sind(angle+errorAngle)];
        ok = ok && q4DistancePolygon(target,polygon)<1e-6;
    end
end
record("WedgeExtremeBearingErrors",ok);
center = [27,-43];
polygon = q4Disk(center,1800,72);
angles = (0:0.5:359.5)';
targets = center+1800*[cosd(angles),sind(angles)];
ok = all(vecnorm(polygon-center,2,2)>1800);
edges = polygon([2:end,1],:)-polygon;
distances = abs(edges(:,1).*(center(2)-polygon(:,2))-edges(:,2).*(center(1)-polygon(:,1)))./vecnorm(edges,2,2);
ok = ok && all(abs(distances-1800)<1e-7);
for k = 1:size(targets,1)
    ok = ok && q4DistancePolygon(targets(k,:),polygon)<1e-6;
end
record("CircumscribedDiskContainsTrueCircle",ok);
polygon = q4ClipDisk(q4Disk([0,0],1800,72),[1500,0],1500,72);
targets = [0,0;1500,0;750,700];
ok = ~isempty(polygon);
for k = 1:size(targets,1)
    ok = ok && q4DistancePolygon(targets(k,:),polygon)<1e-6;
end
record("DiskClippingKeepsTangencyAndInterior",ok);
record("CircleRejectsEmptyInput",throws(@() q4Circle(zeros(0,2)),"Q4:CircleInput"));
record("CircleRejectsNonfiniteInput",throws(@() q4Circle([0,NaN;1,0]),"Q4:CircleInput"));
[center,radius] = q4Circle([-10,0;0,0;5,0;10,0;10,0]);
[singleCenter,singleRadius] = q4Circle([3,4]);
record("CircleCollinearDuplicateAndSingleton",norm(center)<1e-7 && abs(radius-10)<1e-6 && ...
    isequal(singleCenter,[3,4]) && singleRadius<1e-6);
equilateral = [0,0;40,0;20,20*sqrt(3)];
[center,radius] = q4Circle(equilateral);
record("FortyMeterDiameterDoesNotCertifyClear",abs(radius-40/sqrt(3))<1e-6 && radius>20 && ...
    all(vecnorm(equilateral-center,2,2)<=radius));
nearlyCollinear = [0,0;1000,1e-10;2000,0];
[center,radius] = q4Circle(nearlyCollinear);
record("CircleNearCollinearContainment",all(isfinite(center)) && isfinite(radius) && ...
    abs(radius-1000)<1e-6 && all(vecnorm(nearlyCollinear-center,2,2)<=radius));
[exchange,report] = q4World([1,3,0,1000,1,0,1]);
exchange('/enter',payload('behind-enter',[0,0],1));
response = exchange('/measure',payload('behind-measure',[0,0],1));
record("DirectionalBackSideAtThreeMetersIsSilent",string(response.measure_result)=="no_signal" && ...
    ~isfield(response,'svd_deg') && abs(response.virtual_time_s-5)<1e-9);
exchange('/measure',payload('retune',[0,0],5));
request = payload('behind-clear',[0,0],1);
clearResponse = exchange('/clear',request);
state = report();
record("OpticalClearWorksOnDirectionalBackSide",string(clearResponse.clear_result)=="success" && state.cleared);
record("ClearDoesNotRetuneReceiver",state.receiver==5 && abs(state.time-16)<1e-9);
repeated = exchange('/clear',request);
repeatedState = report();
record("SameRequestIdIsIdempotent",isequal(clearResponse,repeated) && isequal(state,repeatedState));
conflict = request;
conflict.channel = 2;
record("ConflictingRequestIdIsRejected",throws(@() exchange('/clear',conflict),"Q4:IdConflict"));
[exchange,~] = q4World([2,0,3,1000,0,0,1]);
exchange('/enter',payload('near-enter',[0,0],2));
response = exchange('/measure',payload('near-measure',[0,0],2));
record("NearHasNoBearingAndPaysSwitch",string(response.measure_result)=="near" && ...
    ~isfield(response,'svd_deg') && abs(response.virtual_time_s-6)<1e-9);
[exchange,~] = q4World([2,100,0,1000,0,0,1]);
exchange('/enter',payload('repeat-enter',[0,0],2));
first = exchange('/measure',payload('repeat-first',[0,0],2));
second = exchange('/measure',payload('repeat-second',[0,0],2));
record("RepeatedLocationKeepsExtremeBearingError",string(first.measure_result)=="direction" && ...
    first.svd_deg==1 && second.svd_deg==first.svd_deg && abs(second.virtual_time_s-first.virtual_time_s-5)<1e-9);
[exchange,~] = q4World([1,1800,0,1000,1,0,2]);
exchange('/enter',payload('boundary-enter',[0,0],1));
radial = exchange('/measure',payload('boundary-radial',[2800,0],1));
tangent = exchange('/measure',payload('boundary-tangent',[1800,1000],1));
outside = exchange('/measure',payload('boundary-outside',[2800.01,0],1));
record("WorldClosedRangeAndEmissionBoundaries",string(radial.measure_result)=="direction" && ...
    string(tangent.measure_result)=="direction" && string(outside.measure_result)=="no_signal");
record("InvalidWorldAndRouteInputsRejected",throws(@() q4World([1,0,0,999,0,0,0]),"Q4:Sources") && ...
    throws(@() q4World([1,0,0,1000,0,0,0;1,10,0,1000,0,0,0]),"Q4:Sources") && ...
    throws(@() q4OpenRoute([0,0],[Inf,0]),"q4:RouteInput") && ...
    throws(@() q4Grid("invalid"),"q4:GridKind"));
rectangle = [0,-27;1500,-27;1500,27;0,27];
[queue,certificate] = q4OpticalQueue([0,0],0,rectangle,[0,0]);
ok = size(queue,1)==152 && size(unique(queue,'rows'),1)==152 && ...
    certificate.originalCount==152 && abs(certificate.coverRadius-hypot(10,13.5))<1e-12 && certificate.coverRadius<20;
for x = [0,10:20:1490,1500]
    for y = [-27,0,27]
        ok = ok && min(vecnorm(queue-[x,y],2,2))<=certificate.coverRadius+1e-7;
    end
end
record("Optical152PointRectangleCover",ok);
anchor = [450,-350];
angle = 359.8;
rotation = [cosd(angle),sind(angle);-sind(angle),cosd(angle)];
ok = true;
for x = [0,10,730,1500]
    for y = [-26.4,0,26.4]
        target = anchor+[x,y]*rotation;
        polygon = q4Disk(target,0.05,12);
        [queue,certificate] = q4OpticalQueue(anchor,angle,polygon,anchor);
        ok = ok && ~isempty(queue) && size(queue,1)<152 && ...
            min(vecnorm(queue-target,2,2))<=20 && certificate.retainedCount==size(queue,1);
    end
end
record("OpticalConservativeFilteringKeepsTruePointCover",ok);
record("OpticalQueueRequiresFiniteFirstBearing",throws(@() q4OpticalQueue([0,0],NaN,rectangle,[0,0]),"Q4:OpticalInput"));
[points,triangles,info] = q4Grid("triangle");
centroids = (points(triangles(:,1),:)+points(triangles(:,2),:)+points(triangles(:,3),:))/3;
[~,interior] = min(vecnorm(centroids,2,2));
damaged = triangles;
damaged(interior,:) = [];
info.cellCount = size(damaged,1);
[meshChecks,evidence] = q4CoverageChecks(points,damaged,info);
record("MissingInternalCellBreaksContinuousCoverage",size(damaged,1)==size(triangles,1)-1 && ...
    all(vecnorm(points(triangles(interior,:),:),2,2)<1800) && ~evidence.continuousCoverageSupported && ...
    ~meshChecks.Passed(meshChecks.Name=="ContinuousDiskMeshPredicates"));
points = [0,0;2,0;3,2;-2,1;0,-3;1,1];
[order,length] = q4OpenRoute([0,0],points);
[repeatOrder,repeatLength] = q4OpenRoute([0,0],points);
[emptyOrder,emptyLength] = q4OpenRoute([0,0],zeros(0,2));
measured = sum(vecnorm(diff([[0,0];points(order,:)],1,1),2,2));
record("OpenRoutePermutationLengthAndDeterminism",isequal(sort(order),1:size(points,1)) && ...
    isequal(order,repeatOrder) && abs(length-measured)<1e-10 && repeatLength==length && isempty(emptyOrder) && emptyLength==0);
checks = table(names,passed,'VariableNames',{'Name','Passed'});

    function record(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = isscalar(value) && logical(value);
    end

    function value = throws(action,identifier)
        value = false;
        try
            action();
        catch exception
            value = string(exception.identifier)==string(identifier);
        end
    end

    function value = payload(id,position,channel)
        value = struct('arena_id','default','robot_id','OFFLINE_CORE_CHECK',...
            'request_id',id,'position',struct('x',position(1),'y',position(2)),'channel',channel);
    end
end


function q4Figures(path,summary,grids,details,scenarios)
figurePath = fullfile(path,'figures');
if ~isfolder(figurePath)
    mkdir(figurePath);
end
fontName = 'Microsoft YaHei';
kinds = ["triangle","square"];
layoutNames = ["900米三角网格","49点方格"];
assert(size(details,1)==2 && size(details,2)==numel(scenarios),'Q4:FigureInput','Figure inputs do not share the scenario layout.');
angle = linspace(0,2*pi,721);
circle = 1800*[cos(angle(:)),sin(angle(:))];
insideColor = [0.13,0.39,0.64];
outsideColor = [0.81,0.43,0.12];
firstFigure = figure('Visible','off','Color','w','Units','pixels','Position',[40,40,1400,760]);
firstCleanup = onCleanup(@() close(firstFigure));
firstLayout = tiledlayout(firstFigure,1,2,'TileSpacing','compact','Padding','compact');
for variant = 1:2
    ax = nexttile(firstLayout,variant);
    q4StyleAxes(ax,fontName);
    solution = details{variant,1};
    points = solution.points;
    triangles = solution.triangles;
    row = grids(string(grids.Layout)==kinds(variant),:);
    assert(height(row)==1,'Q4:FigureGrid','Each coverage layout requires one result row.');
    hold(ax,'on');
    patch(ax,'Faces',triangles,'Vertices',points,'FaceColor','none','EdgeColor',[0.80,0.83,0.86],'LineWidth',0.65,'HandleVisibility','off');
    boundaryHandle = plot(ax,circle(:,1),circle(:,2),'k-','LineWidth',1.5);
    inside = vecnorm(points,2,2)<=1800+1e-7;
    insideHandle = scatter(ax,points(inside,1),points(inside,2),34,'o','MarkerEdgeColor',insideColor,'MarkerFaceColor',insideColor,'LineWidth',1.0);
    outsideHandle = scatter(ax,points(~inside,1),points(~inside,2),45,'s','MarkerEdgeColor',outsideColor,'MarkerFaceColor','w','LineWidth',1.5);
    originHandle = plot(ax,0,0,'kp','MarkerFaceColor','k','MarkerSize',10);
    axis(ax,'equal');
    xlim(ax,[-2850,2850]);
    ylim(ax,[-2850,2850]);
    xticks(ax,-2000:1000:2000);
    yticks(ax,-2000:1000:2000);
    xlabel(ax,'东西坐标 x / m','FontName',fontName,'Interpreter','none');
    ylabel(ax,'南北坐标 y / m','FontName',fontName,'Interpreter','none');
    title(ax,{char("（"+string(char(96+variant))+"）"+layoutNames(variant)),sprintf('%d个测点，域外%d个；仅站点路线 %.0f m',row.Stations,sum(~inside),row.StationOnlyRoute_m)},'FontName',fontName,'FontSize',12,'FontWeight','normal','Interpreter','none');
    if variant==1
        firstAxes = ax;
        firstHandles = [boundaryHandle,insideHandle,outsideHandle,originHandle];
    end
end
firstLegend = legend(firstAxes,firstHandles,{'源域边界：半径1800 m','圆域内测点','圆域外测点','出发点'},'Orientation','horizontal','NumColumns',4,'FontName',fontName,'FontSize',11,'Interpreter','none','Box','off');
firstLegend.Layout.Tile = 'south';
title(firstLayout,'图1  连续方向覆盖的两种候选布局','FontName',fontName,'FontSize',16,'FontWeight','bold','Interpreter','none');
subtitle(firstLayout,'保留圆域外测点；网格单元提供距离与闭半平面的联合覆盖保证','FontName',fontName,'FontSize',11,'Interpreter','none');
q4ExportFigure(firstFigure,figurePath,'figure01_directional_coverage');
clear firstCleanup
scenarioCount = numel(scenarios);
triangleTime = zeros(scenarioCount,1);
squareTime = zeros(scenarioCount,1);
pairVerified = false(scenarioCount,1);
boundaryCases = false(scenarioCount,1);
for k = 1:scenarioCount
    firstRow = summary(string(summary.Layout)=="triangle" & string(summary.Scenario)==string(scenarios(k).name),:);
    secondRow = summary(string(summary.Layout)=="square" & string(summary.Scenario)==string(scenarios(k).name),:);
    assert(height(firstRow)==1 && height(secondRow)==1,'Q4:FigurePair','Every case needs exactly one result from each layout.');
    triangleTime(k) = firstRow.VirtualTime_s;
    squareTime(k) = secondRow.VirtualTime_s;
    pairVerified(k) = firstRow.FullClearVerified && secondRow.FullClearVerified;
    boundaryCases(k) = string(scenarios(k).group)=="constructed_boundary";
end
hasFallback = false(scenarioCount,1);
for k = 1:scenarioCount
    hasFallback(k) = sum(details{1,k}.fallbackAttempts)>0 && details{1,k}.complete;
end
candidates = find(hasFallback);
if isempty(candidates)
    candidates = (1:scenarioCount)';
end
[~,medianIndex] = min(abs(triangleTime(candidates)-median(triangleTime(candidates))));
representative = candidates(medianIndex);
solution = details{1,representative};
sources = scenarios(representative).sources;
[~,focusChannel] = max(solution.fallbackAttempts);
if sum(solution.fallbackAttempts)==0
    focusChannel = sources(1,1);
end
sourcePosition = sources(sources(:,1)==focusChannel,2:3);
events = solution.events;
channelMask = [events.channel]'==focusChannel & string({events.path})'=="/clear";
clearLocations = [[events(channelMask).x]',[events(channelMask).y]'];
zoomRadius = 100;
if ~isempty(clearLocations)
    recent = clearLocations(max(1,end-7):end,:);
    zoomRadius = max(80,min(240,max(vecnorm(recent-sourcePosition,2,2))+30));
end
secondFigure = figure('Visible','off','Color','w','Units','pixels','Position',[40,40,1440,850]);
secondCleanup = onCleanup(@() close(secondFigure));
secondLayout = tiledlayout(secondFigure,1,2,'TileSpacing','compact','Padding','compact');
fullAxes = nexttile(secondLayout,1);
q4StyleAxes(fullAxes,fontName);
trajectoryHandles = q4TrajectoryPanel(fullAxes,solution,sources,0,180);
plot(fullAxes,circle(:,1),circle(:,2),'k:','LineWidth',1.1,'HandleVisibility','off');
axis(fullAxes,'equal');
allCoordinates = [[events.x]',[events.y]';sources(:,2:3)];
fullLimit = max(2000,ceil((max(abs(allCoordinates),[],'all')+150)/500)*500);
xlim(fullAxes,[-fullLimit,fullLimit]);
ylim(fullAxes,[-fullLimit,fullLimit]);
xticks(fullAxes,-2000:1000:2000);
yticks(fullAxes,-2000:1000:2000);
rectangle(fullAxes,'Position',[sourcePosition-zoomRadius,2*zoomRadius,2*zoomRadius],'EdgeColor',[0.2,0.2,0.2],'LineStyle','--','LineWidth',1.0);
xlabel(fullAxes,'东西坐标 x / m','FontName',fontName,'Interpreter','none');
ylabel(fullAxes,'南北坐标 y / m','FontName',fontName,'Interpreter','none');
title(fullAxes,{'（a）完整动作轨迹',sprintf('构造案例 %s；T = %.1f s',scenarios(representative).name,solution.virtualTime)},'FontName',fontName,'FontSize',12,'FontWeight','normal','Interpreter','none');
zoomAxes = nexttile(secondLayout,2);
q4StyleAxes(zoomAxes,fontName);
q4TrajectoryPanel(zoomAxes,solution,sources,focusChannel,min(70,zoomRadius/2));
axis(zoomAxes,'equal');
xlim(zoomAxes,sourcePosition(1)+[-zoomRadius,zoomRadius]);
ylim(zoomAxes,sourcePosition(2)+[-zoomRadius,zoomRadius]);
xlabel(zoomAxes,'东西坐标 x / m','FontName',fontName,'Interpreter','none');
ylabel(zoomAxes,'南北坐标 y / m','FontName',fontName,'Interpreter','none');
title(zoomAxes,{'（b）清除过程局部放大',sprintf('频道%d；该频道光学兜底尝试%d次',focusChannel,solution.fallbackAttempts(focusChannel))},'FontName',fontName,'FontSize',12,'FontWeight','normal','Interpreter','none');
secondLegend = legend(fullAxes,trajectoryHandles,{'扫描移动与测点','补测移动与测点','光学清除移动','构造源真值','定向发射轴向','清除成功位置','清除失败位置','原点出发'},'NumColumns',4,'FontName',fontName,'FontSize',11,'Interpreter','none','Box','off');
secondLegend.Layout.Tile = 'south';
title(secondLayout,'图2  构造案例中的搜索、补测与光学清除','FontName',fontName,'FontSize',16,'FontWeight','bold','Interpreter','none');
subtitle(secondLayout,'真值仅来自自建场景；箭头只表示发射轴向，长度不代表接收半径；清除位置不等于真值','FontName',fontName,'FontSize',10.5,'Interpreter','none');
q4ExportFigure(secondFigure,figurePath,'figure02_constructed_trajectory');
clear secondCleanup
thirdFigure = figure('Visible','off','Color','w','Units','pixels','Position',[40,40,1440,810]);
thirdCleanup = onCleanup(@() close(thirdFigure));
thirdLayout = tiledlayout(thirdFigure,1,2,'TileSpacing','compact','Padding','compact');
pairedAxes = nexttile(thirdLayout,1);
q4StyleAxes(pairedAxes,fontName);
hold(pairedAxes,'on');
pairedLimit = max(1000,ceil(max([triangleTime;squareTime])*1.10/1000)*1000);
equalHandle = plot(pairedAxes,[0,pairedLimit],[0,pairedLimit],'k--','LineWidth',1.0);
boundaryHandle = scatter(pairedAxes,squareTime(boundaryCases),triangleTime(boundaryCases),50,'s','MarkerEdgeColor',outsideColor,'MarkerFaceColor','w','LineWidth',1.4);
randomHandle = scatter(pairedAxes,squareTime(~boundaryCases),triangleTime(~boundaryCases),44,'o','MarkerEdgeColor',insideColor,'MarkerFaceColor',insideColor,'LineWidth',1.0);
if any(~pairVerified)
    scatter(pairedAxes,squareTime(~pairVerified),triangleTime(~pairVerified),100,'x','MarkerEdgeColor','k','LineWidth',1.8,'HandleVisibility','off');
end
axis(pairedAxes,'equal');
xlim(pairedAxes,[0,pairedLimit]);
ylim(pairedAxes,[0,pairedLimit]);
xlabel(pairedAxes,'49点方格总虚拟时间 / s','FontName',fontName,'Interpreter','none');
ylabel(pairedAxes,'900米三角网格总虚拟时间 / s','FontName',fontName,'Interpreter','none');
title(pairedAxes,{'（a）逐场总虚拟时间配对',sprintf('三角更快%d场；方格更快%d场；相同%d场',sum(triangleTime<squareTime-1e-6),sum(squareTime<triangleTime-1e-6),sum(abs(triangleTime-squareTime)<=1e-6))},'FontName',fontName,'FontSize',12,'FontWeight','normal','Interpreter','none');
legend(pairedAxes,[equalHandle,boundaryHandle,randomHandle],{'两方案等时','边界构造案例','随机构造案例'},'Location','northwest','FontName',fontName,'FontSize',10.5,'Interpreter','none','Box','off');
costAxes = nexttile(thirdLayout,2);
q4StyleAxes(costAxes,fontName);
costMeans = zeros(2,5);
for variant = 1:2
    selected = summary(string(summary.Layout)==kinds(variant),:);
    components = [selected.Distance_m/5,5*selected.Measures,selected.Switches,5*selected.Cleared,3*selected.FailedClears];
    assert(all(abs(sum(components,2)-selected.VirtualTime_s)<1e-3),'Q4:FigureCost','Cost decomposition does not agree with saved virtual time.');
    costMeans(variant,:) = mean(components,1);
end
costHandles = bar(costAxes,1:2,costMeans,'stacked','BarWidth',0.56,'LineWidth',0.6);
costColors = [0.18,0.43,0.66;0.91,0.67,0.25;0.35,0.35,0.35;0.46,0.59,0.33;0.60,0.36,0.64];
for part = 1:5
    costHandles(part).FaceColor = costColors(part,:);
    costHandles(part).EdgeColor = [0.30,0.30,0.30];
end
xticks(costAxes,[1,2]);
xticklabels(costAxes,cellstr(layoutNames));
xlim(costAxes,[0.4,2.6]);
costTotal = sum(costMeans,2);
paired = table(string({scenarios.name})',boundaryCases,triangleTime,squareTime,squareTime-triangleTime,pairVerified, ...
    'VariableNames',{'Scenario','BoundaryCase','TriangleTime_s','SquareTime_s','Saving_s','BothFullClear'});
writetable(paired,fullfile(path,'paired_comparison.csv'),'Encoding','UTF-8');
costTable = array2table(costMeans,'VariableNames',{'Move_s','Measure_s','Switch_s','Success_s','Failure_s'});
costTable = addvars(costTable,kinds','Before',1,'NewVariableNames','Layout');
writetable(costTable,fullfile(path,'cost_components.csv'),'Encoding','UTF-8');
ylim(costAxes,[0,max(costTotal)*1.19]);
ylabel(costAxes,'每场平均虚拟时间 / s','FontName',fontName,'Interpreter','none');
title(costAxes,{'（b）完整任务平均成本分解',sprintf('每个布局均包含全部%d个构造案例',scenarioCount)},'FontName',fontName,'FontSize',12,'FontWeight','normal','Interpreter','none');
for variant = 1:2
    text(costAxes,variant,costTotal(variant)+max(costTotal)*0.025,sprintf('%.1f s',costTotal(variant)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontName',fontName,'FontSize',11,'Interpreter','none');
end
costLegend = legend(costAxes,costHandles,{'移动','检测','频道切换','成功清除','失败清除'},'NumColumns',5,'Orientation','horizontal','FontName',fontName,'FontSize',11,'Interpreter','none','Box','off');
costLegend.Layout.Tile = 'south';
title(thirdLayout,sprintf('图3  两布局在%d个同场构造案例中的完整任务成本',scenarioCount),'FontName',fontName,'FontSize',16,'FontWeight','bold','Interpreter','none');
subtitle(thirdLayout,sprintf('等时线下方表示三角方案更快；两方案均完整核验的配对为%d/%d；构造结果不代表官方分布或全局最优',sum(pairVerified),scenarioCount),'FontName',fontName,'FontSize',10.5,'Interpreter','none');
q4ExportFigure(thirdFigure,figurePath,'figure03_paired_costs');
clear thirdCleanup
end

function q4StyleAxes(ax,fontName)
set(ax,'FontName',fontName,'FontSize',11,'LineWidth',0.8,'XColor',[0.18,0.18,0.18],'YColor',[0.18,0.18,0.18], ...
    'TickLabelInterpreter','none','Box','off','Layer','top','GridColor',[0.78,0.80,0.82],'GridAlpha',0.30,'MinorGridAlpha',0.15);
grid(ax,'on');
end

function handles = q4TrajectoryPanel(ax,solution,sources,focusChannel,arrowLength)
hold(ax,'on');
events = solution.events;
valid = ismember(string({events.path})',["/measure","/clear"]);
selectedEvents = events(valid);
coordinates = [[selectedEvents.x]',[selectedEvents.y]'];
previous = [[0,0];coordinates(1:end-1,:)];
phases = string({selectedEvents.phase})';
paths = string({selectedEvents.path})';
results = string({selectedEvents.result})';
channels = [selectedEvents.channel]';
include = true(size(channels));
if focusChannel>0
    include = channels==focusChannel;
end
colors = [0.13,0.39,0.64;0.81,0.43,0.12;0.58,0.31,0.63];
styles = {'-','--','-.'};
markers = {'s','^','none'};
widths = [0.9,1.2,1.1];
handles = gobjects(1,8);
for phaseIndex = 1:3
    if phaseIndex==1
        mask = include & phases=="coverage";
    elseif phaseIndex==2
        mask = include & phases=="local_measure";
    else
        mask = include & paths=="/clear";
    end
    segmentX = reshape([previous(mask,1),coordinates(mask,1),NaN(sum(mask),1)]',[],1);
    segmentY = reshape([previous(mask,2),coordinates(mask,2),NaN(sum(mask),1)]',[],1);
    plot(ax,segmentX,segmentY,'Color',colors(phaseIndex,:),'LineStyle',styles{phaseIndex},'LineWidth',widths(phaseIndex),'HandleVisibility','off');
    handles(phaseIndex) = plot(ax,NaN,NaN,'Color',colors(phaseIndex,:),'LineStyle',styles{phaseIndex},'LineWidth',widths(phaseIndex),'Marker',markers{phaseIndex},'MarkerSize',5,'MarkerFaceColor','w');
    if phaseIndex<3
        locations = unique(coordinates(mask,:),'rows');
        scatter(ax,locations(:,1),locations(:,2),24,markers{phaseIndex},'MarkerEdgeColor',colors(phaseIndex,:),'MarkerFaceColor','w','LineWidth',0.9,'HandleVisibility','off');
    end
end
if focusChannel>0
    sources = sources(sources(:,1)==focusChannel,:);
end
handles(4) = scatter(ax,sources(:,2),sources(:,3),48,'d','MarkerEdgeColor',[0.12,0.12,0.12],'MarkerFaceColor',[0.12,0.12,0.12],'LineWidth',1.0);
directional = sources(:,5)==1;
handles(5) = quiver(ax,sources(directional,2),sources(directional,3),arrowLength*cosd(sources(directional,6)),arrowLength*sind(sources(directional,6)),0,'Color',[0.12,0.12,0.12],'LineWidth',1.2,'MaxHeadSize',0.9);
success = include & paths=="/clear" & results=="success";
failed = include & paths=="/clear" & results~="success";
handles(6) = scatter(ax,coordinates(success,1),coordinates(success,2),90,'p','MarkerEdgeColor',colors(3,:),'MarkerFaceColor','w','LineWidth',1.5);
handles(7) = scatter(ax,coordinates(failed,1),coordinates(failed,2),22,'x','MarkerEdgeColor',colors(3,:),'LineWidth',1.0);
handles(8) = plot(ax,0,0,'k+','MarkerSize',11,'LineWidth',1.5);
end

function q4ExportFigure(fig,path,name)
set(findall(fig,'-property','FontName'),'FontName','Microsoft YaHei');
set(fig,'Renderer','painters','InvertHardcopy','off');
drawnow;
exportgraphics(fig,fullfile(path,[name '.png']),'Resolution',240,'BackgroundColor','white');
exportgraphics(fig,fullfile(path,[name '.pdf']),'ContentType','vector','BackgroundColor','white');
savefig(fig,fullfile(path,[name '.fig']));
end

function output = q4LayoutStudy(path,settings,config)
assert(isfield(config,'baselinePath') && isfile(fullfile(config.baselinePath,'results.mat')),'Q4:StudyBaseline','Use the fixed previous offline baseline.');
previous = load(fullfile(config.baselinePath,'results.mat'),'summary','scenarios');
scenarios = q4Scenarios(settings.seed);
assert(isequaln(previous.scenarios,scenarios),'Q4:StudyScenarios','The fixed baseline and current study must share identical scenarios.');
kinds = ["triangle","triangle990","triangle990shift"];
baselineRows = previous.summary(string(previous.summary.Layout)=="triangle",:);
assert(height(baselineRows)==numel(scenarios) && all(baselineRows.FullClearVerified),'Q4:StudyBaseline','The fixed triangle baseline is incomplete.');
studyConfig = struct('layouts',kinds,'seed',settings.seed,'scenarioCount',numel(scenarios), ...
    'baselinePath',string(config.baselinePath),'baselineSummarySha256',q4FileHash(fullfile(config.baselinePath,'summary.csv')), ...
    'sourceSha256',q4FileHash([mfilename('fullpath') '.m']),'selectionPolicy',"REPORT_ALL_CANDIDATES_WITHOUT_AUTOMATIC_DEFAULT_CHANGE", ...
    'scope',"ITEM1_COVERAGE_LAYOUT_AND_DRAIN_TAIL_ONLY",'evidence',"SEEN_CONSTRUCTED_SCENARIOS_NOT_OFFICIAL");
q4WriteJson(fullfile(path,'study_config.json'),studyConfig);
save(fullfile(path,'study_config.mat'),'studyConfig','scenarios','settings');
details = cell(numel(kinds),numel(scenarios));
layouts = cell(numel(kinds),1);
gridRows = cell(numel(kinds),8);
records = cell(0,1);
for variant = 1:numel(kinds)
    kind = kinds(variant);
    [points,triangles,info] = q4Grid(kind);
    [checks,evidence] = q4CoverageChecks(points,triangles,info);
    geometryPassed = all(checks.Passed) && evidence.continuousCoverageSupported;
    writetable(checks,fullfile(path,char(kind+"_coverage_checks.csv")),'Encoding','UTF-8');
    q4WriteJson(fullfile(path,char(kind+"_coverage.json")),evidence);
    assert(geometryPassed,'Q4:StudyCoverage','A study layout lacks the required continuous coverage evidence.');
    [order,routeLength] = q4OpenRoute([0,0],points);
    layouts{variant} = struct('kind',kind,'points',points,'triangles',triangles,'info',info,'order',order,'evidence',evidence);
    gridRows(variant,:) = {kind,size(points,1),size(triangles,1),info.spacing,routeLength, ...
        routeLength/5+119*size(points,1),evidence.rangeMargin,evidence.minimumBoundaryDistance};
    writetable(array2table(points,'VariableNames',{'X_m','Y_m'}),fullfile(path,char(kind+"_stations.csv")),'Encoding','UTF-8');
    save(fullfile(path,char(kind+"_layout.mat")),'points','triangles','info','order','evidence');
    for caseIndex = 1:numel(scenarios)
        scene = scenarios(caseIndex);
        reference = baselineRows(string(baselineRows.Scenario)==string(scene.name),:);
        assert(height(reference)==1,'Q4:StudyPair','Each study scenario requires exactly one fixed baseline row.');
        cfg = settings;
        cfg.layout = kind;
        cfg.robotId = 'OFFLINE_Q4';
        cfg.requestPrefix = sprintf('%s-%d',kind,caseIndex);
        [exchange,report] = q4World(scene.sources);
        timer = tic;
        solution = q4Solve(exchange,cfg,points,triangles,info);
        wallTime = toc(timer);
        world = report();
        runPath = fullfile(path,char(kind),scene.name);
        mkdir(runPath);
        q4SaveRun(runPath,solution,world,scene.sources,cfg);
        try
            audit = q4Audit(solution,scene.sources,world);
        catch auditError
            audit = struct('allPassed',false,'failureIdentifier',string(auditError.identifier),'failureMessage',string(auditError.message));
        end
        q4WriteJson(fullfile(runPath,'audit.json'),audit);
        [metrics,accounting,stopEvidence] = q4StudyMetrics(solution,world);
        q4WriteJson(fullfile(runPath,'stop_evidence.json'),stopEvidence);
        q4WriteJson(fullfile(runPath,'cost_metrics.json'),metrics);
        writetable(accounting,fullfile(runPath,'action_accounting.csv'),'Encoding','UTF-8');
        baselineTimeMatch = kind~="triangle" || abs(solution.virtualTime-reference.VirtualTime_s)<=1e-7;
        baselineActionMatch = kind~="triangle" || numel(solution.events)==reference.Actions;
        baselineCostMatch = kind~="triangle" || (abs(solution.costs(1)*5-reference.Distance_m)<=1e-7 && ...
            solution.costs(2)/5==reference.Measures && solution.costs(3)==reference.Switches && solution.costs(5)/3==reference.FailedClears);
        fullClear = solution.complete && all(world.cleared) && audit.allPassed && geometryPassed && ...
            metrics.accountingPassed && stopEvidence.allPassed && baselineTimeMatch && baselineActionMatch && baselineCostMatch;
        delta = solution.virtualTime-reference.VirtualTime_s;
        records{end+1,1} = struct('Layout',kind,'Scenario',string(scene.name),'Group',string(scene.group), ...
            'SourceCount',size(scene.sources,1),'Cleared',sum(world.cleared),'FullClearVerified',fullClear, ...
            'GeometryCoverageValid',geometryPassed,'AuditPassed',audit.allPassed,'ActualStopEvidence',stopEvidence.allPassed, ...
            'AccountingPassed',metrics.accountingPassed,'BaselineTimeMatch',baselineTimeMatch,'BaselineActionMatch',baselineActionMatch, ...
            'BaselineCostMatch',baselineCostMatch, ...
            'StopReason',string(solution.stopReason),'VirtualTime_s',solution.virtualTime, ...
            'BaselineTime_s',reference.VirtualTime_s,'DeltaTime_s',delta,'DeltaPercent',100*delta/reference.VirtualTime_s, ...
            'MeanClearTime_s',q4MeanTime(solution.virtualTime,sum(world.cleared)),'FirstClear_s',metrics.firstClearTime_s, ...
            'LastClear_s',metrics.lastClearTime_s,'AfterLastClear_s',metrics.afterLastClear_s, ...
            'Move_s',metrics.costs_s(1),'Measure_s',metrics.costs_s(2),'Switch_s',metrics.costs_s(3), ...
            'SuccessClear_s',metrics.costs_s(4),'FailedClear_s',metrics.costs_s(5), ...
            'TailMove_s',metrics.tailCosts_s(1),'TailMeasure_s',metrics.tailCosts_s(2),'TailSwitch_s',metrics.tailCosts_s(3), ...
            'TailSuccessClear_s',metrics.tailCosts_s(4),'TailFailedClear_s',metrics.tailCosts_s(5), ...
            'CoveragePhase_s',metrics.coveragePhase_s,'LocalMeasurePhase_s',metrics.localMeasurePhase_s, ...
            'OpticalPhase_s',metrics.opticalPhase_s,'CertifiedClearPhase_s',metrics.certifiedClearPhase_s, ...
            'Distance_m',metrics.costs_s(1)*5,'Measures',metrics.costs_s(2)/5,'Switches',metrics.costs_s(3), ...
            'FailedClears',metrics.costs_s(5)/3,'OpticalAttempts',sum(solution.fallbackAttempts), ...
            'CoverageMeasures',metrics.coverageMeasures,'VisitedStations',sum(solution.visited), ...
            'AbsentChannels',numel(stopEvidence.absentChannels),'FullyScannedAbsentChannels',stopEvidence.fullyScannedAbsentChannels, ...
            'Actions',numel(solution.events),'WallTime_s',wallTime,'TimeResidual_s',metrics.maximumTimeResidual_s, ...
            'Failure',string(solution.failure.identifier),'FailureMessage',string(solution.failure.message));
        details{variant,caseIndex} = solution;
        summary = struct2table(vertcat(records{:}));
        writetable(summary,fullfile(path,'summary.csv'),'Encoding','UTF-8');
        fprintf('Q4 ITEM1 %s %s: %d/%d T=%.6f delta=%+.6f tail=%.6f passed=%d\n', ...
            kind,scene.name,sum(world.cleared),size(scene.sources,1),solution.virtualTime,delta,metrics.afterLastClear_s,fullClear);
    end
end
grids = cell2table(gridRows,'VariableNames',{'Layout','Stations','Triangles','Spacing_m','StationOnlyRoute_m', ...
    'Full20ChannelScan_s','RangeMargin_m','MinimumBoundaryDistance_m'});
writetable(grids,fullfile(path,'grid_comparison.csv'),'Encoding','UTF-8');
summary = struct2table(vertcat(records{:}));
aggregate = q4StudyAggregate(summary,kinds);
writetable(aggregate,fullfile(path,'aggregate.csv'),'Encoding','UTF-8');
slowCases = summary(summary.Layout~="triangle" & summary.DeltaTime_s>1e-7,:);
writetable(slowCases,fullfile(path,'slow_cases.csv'),'Encoding','UTF-8');
for kind = kinds(2:end)
    writetable(slowCases(slowCases.Layout==kind,:),fullfile(path,char(kind+"_slow_cases.csv")),'Encoding','UTF-8');
end
failedCases = summary(~summary.FullClearVerified,:);
writetable(failedCases,fullfile(path,'failed_cases.csv'),'Encoding','UTF-8');
save(fullfile(path,'results.mat'),'summary','aggregate','slowCases','failedCases','grids','layouts','details','scenarios','settings','studyConfig','-v7.3');
output = struct('path',path,'runs',height(summary),'fullClearVerified',sum(summary.FullClearVerified), ...
    'allPassed',all(summary.FullClearVerified),'scenarioIdentityMatch',true, ...
    'baselineTimeMatch',all(summary.BaselineTimeMatch),'baselineActionMatch',all(summary.BaselineActionMatch), ...
    'baselineCostMatch',all(summary.BaselineCostMatch), ...
    'slowCaseCount',height(slowCases),'failedCaseCount',height(failedCases),'layouts',kinds, ...
    'defaultChanged',false,'evidence',"SEEN_CONSTRUCTED_CASES_ONLY_NOT_OFFICIAL_NOT_HUMAN_AUDITED");
q4WriteJson(fullfile(path,'summary.json'),output);
q4StudyFigures(path,summary,grids,layouts,kinds);
assert(output.allPassed,'Q4:StudyFailure','A layout study run failed; all produced evidence has been retained.');
end

function [metrics,accounting,evidence] = q4StudyMetrics(solution,world)
events = solution.events;
eventCount = numel(events);
increments = zeros(eventCount,5);
observedIncrements = zeros(eventCount,1);
residuals = zeros(eventCount,1);
actualMeasurements = false(size(solution.coverage));
actualNoSignals = false(size(solution.coverage));
position = [0,0];
receiver = 1;
time = 0;
previousTime = 0;
receiverValid = true;
for index = 1:eventCount
    event = events(index);
    if ismember(event.path,["/measure","/clear"])
        at = [event.x,event.y];
        increments(index,1) = norm(at-position)/5;
        position = at;
        if event.path=="/measure"
            increments(index,2) = 5;
            increments(index,3) = double(receiver~=event.channel);
            receiver = event.channel;
            matches = vecnorm(solution.points-at,2,2)<=1e-6;
            actualMeasurements(matches,event.channel) = true;
            if event.result=="no_signal"
                actualNoSignals(matches,event.channel) = true;
            end
        elseif event.result=="success"
            increments(index,4) = 5;
        else
            increments(index,5) = 3;
        end
    end
    observedIncrements(index) = event.virtualTime-previousTime;
    previousTime = event.virtualTime;
    time = time+sum(increments(index,:));
    residuals(index) = max(abs(time-event.virtualTime),abs(sum(increments(index,:))-observedIncrements(index)));
    receiverValid = receiverValid && event.receiver==receiver;
end
paths = string({events.path})';
results = string({events.result})';
phases = string({events.phase})';
successRows = find(paths=="/clear" & results=="success");
firstClearTime = NaN;
lastClearTime = NaN;
tailCosts = NaN(1,5);
tailTime = NaN;
tailRows = false(eventCount,1);
if ~isempty(successRows)
    firstClearTime = events(successRows(1)).virtualTime;
    lastClearTime = events(successRows(end)).virtualTime;
    tailRows(successRows(end)+1:end) = true;
    tailCosts = sum(increments(tailRows,:),1);
    tailTime = solution.virtualTime-lastClearTime;
end
costs = sum(increments,1);
totalResidual = max([abs(sum(costs)-solution.virtualTime),abs(sum(costs)-world.time),max(abs(costs-solution.costs))]);
tailResidual = abs(sum(tailCosts)-tailTime);
accountingPassed = eventCount>0 && receiverValid && all(residuals<=5e-5) && totalResidual<=5e-5 && ...
    isfinite(tailResidual) && tailResidual<=5e-5;
metrics = struct('costs_s',costs,'tailCosts_s',tailCosts,'firstClearTime_s',firstClearTime, ...
    'lastClearTime_s',lastClearTime,'afterLastClear_s',tailTime, ...
    'coveragePhase_s',sum(observedIncrements(phases=="coverage")), ...
    'localMeasurePhase_s',sum(observedIncrements(phases=="local_measure")), ...
    'opticalPhase_s',sum(observedIncrements(phases=="optical_fallback")), ...
    'certifiedClearPhase_s',sum(observedIncrements(phases=="certified_clear")), ...
    'coverageMeasures',sum(phases=="coverage" & paths=="/measure"), ...
    'maximumTimeResidual_s',max([residuals;totalResidual;tailResidual]), ...
    'tailContainedInTotalCosts',true,'accountingPassed',accountingPassed);
absent = find(solution.status==3);
successfulChannels = unique([events(successRows).channel]);
recordedCoverageReal = all(~solution.coverage | actualMeasurements,'all');
fullyScannedAbsent = sum(all(actualNoSignals(:,absent),1));
sixteenStop = numel(successfulChannels)==16 && sum(solution.status==2)==16 && ...
    solution.stopReason=="sixteen_distinct_clears";
coverageStop = numel(successfulChannels)<16 && all(actualNoSignals(:,absent),'all') && ...
    all(solution.coverage(:,absent),'all') && all(solution.status==2 | solution.status==3) && ...
    solution.stopReason=="directional_coverage_and_all_discovered_cleared";
tailAudit = q4TailAudit(solution);
certifiedStop = numel(successfulChannels)<16 && tailAudit.allPassed && ...
    solution.stopReason=="certified_directional_coverage_and_all_discovered_cleared";
clearStateMatches = isequal(sort(successfulChannels),find(solution.status==2));
exitConfirmed = eventCount>=2 && paths(1)=="/enter" && paths(end)=="/exit" && solution.entered && solution.exited && ~world.active;
evidence = struct('absentChannels',absent,'successfulChannels',successfulChannels, ...
    'fullyScannedAbsentChannels',fullyScannedAbsent,'actualNoSignals',actualNoSignals, ...
    'recordedCoverageReal',recordedCoverageReal,'clearStateMatches',clearStateMatches, ...
    'sixteenDistinctClearsStop',sixteenStop,'directionalCoverageStop',coverageStop,'certifiedDirectionalCoverageStop',certifiedStop,'tailAudit',tailAudit,'exitConfirmed',exitConfirmed);
evidence.allPassed = solution.complete && recordedCoverageReal && clearStateMatches && exitConfirmed && (sixteenStop || coverageStop || certifiedStop);
accounting = table((1:eventCount)',paths,[events.channel]',phases,observedIncrements, ...
    increments(:,1),increments(:,2),increments(:,3),increments(:,4),increments(:,5),tailRows,residuals, ...
    'VariableNames',{'Serial','Path','Channel','Phase','ObservedIncrement_s','Move_s','Measure_s','Switch_s', ...
    'SuccessClear_s','FailedClear_s','AfterLastClear','TimeResidual_s'});
end

function aggregate = q4StudyAggregate(summary,kinds)
groups = ["all_28","boundary_8","random_20","source_count_16","source_count_below_16"];
records = cell(0,1);
for groupIndex = 1:numel(groups)
    group = groups(groupIndex);
    if group=="boundary_8"
        mask = summary.Group=="constructed_boundary";
    elseif group=="random_20"
        mask = summary.Group=="constructed_random";
    elseif group=="source_count_16"
        mask = summary.SourceCount==16;
    elseif group=="source_count_below_16"
        mask = summary.SourceCount<16;
    else
        mask = true(height(summary),1);
    end
    base = summary(mask & summary.Layout=="triangle",:);
    for kind = kinds
        selected = summary(mask & summary.Layout==kind,:);
        assert(height(selected)==height(base) && all(selected.Scenario==base.Scenario),'Q4:StudyAggregate','Paired groups must have matching scenarios.');
        records{end+1,1} = struct('Group',group,'Layout',kind,'Scenarios',height(selected), ...
            'Verified',sum(selected.FullClearVerified),'MeanTime_s',mean(selected.VirtualTime_s), ...
            'BaselineMeanTime_s',mean(base.VirtualTime_s),'MeanDeltaTime_s',mean(selected.DeltaTime_s), ...
            'MeanTimeChangePercent',100*(mean(selected.VirtualTime_s)/mean(base.VirtualTime_s)-1), ...
            'Faster',sum(selected.DeltaTime_s < -1e-7),'Slower',sum(selected.DeltaTime_s>1e-7), ...
            'Equal',sum(abs(selected.DeltaTime_s)<=1e-7),'WorstDeltaTime_s',max(selected.DeltaTime_s), ...
            'WorstDeltaPercent',max(selected.DeltaPercent),'MeanTail_s',mean(selected.AfterLastClear_s), ...
            'MeanTailDelta_s',mean(selected.AfterLastClear_s-base.AfterLastClear_s), ...
            'MeanCoveragePhase_s',mean(selected.CoveragePhase_s),'MeanMove_s',mean(selected.Move_s), ...
            'MeanMeasure_s',mean(selected.Measure_s),'MeanSwitch_s',mean(selected.Switch_s), ...
            'MeanSuccessClear_s',mean(selected.SuccessClear_s),'MeanFailedClear_s',mean(selected.FailedClear_s), ...
            'MeanTailMove_s',mean(selected.TailMove_s),'MeanTailMeasure_s',mean(selected.TailMeasure_s), ...
            'MeanTailSwitch_s',mean(selected.TailSwitch_s),'MeanTailSuccessClear_s',mean(selected.TailSuccessClear_s), ...
            'MeanTailFailedClear_s',mean(selected.TailFailedClear_s),'MeanOpticalAttempts',mean(selected.OpticalAttempts));
    end
end
aggregate = struct2table(vertcat(records{:}));
end

function q4StudyFigures(path,summary,grids,layouts,kinds)
figurePath = fullfile(path,'figures');
mkdir(figurePath);
fontName = 'Microsoft YaHei';
labels = {'900米三角基线','990米三角候选','990米重心平移候选'};
colors = [0.15,0.38,0.62;0.85,0.40,0.12;0.43,0.32,0.62];
firstFigure = figure('Visible','off','Color','white','Position',[100,100,1450,550]);
firstCleanup = onCleanup(@() close(firstFigure));
firstLayout = tiledlayout(firstFigure,1,3,'Padding','compact','TileSpacing','compact');
angle = linspace(0,2*pi,721)';
allPoints = vertcat(layouts{1}.points,layouts{2}.points,layouts{3}.points);
extent = ceil(max(abs(allPoints),[],'all')/500)*500+150;
for variant = 1:numel(kinds)
    axisHandle = nexttile(firstLayout);
    hold(axisHandle,'on');
    item = layouts{variant};
    meshHandle = triplot(item.triangles,item.points(:,1),item.points(:,2),'Parent',axisHandle,'Color',[0.72,0.75,0.79],'LineWidth',0.65);
    set(meshHandle,'HandleVisibility','off');
    circleHandle = plot(axisHandle,1800*cos(angle),1800*sin(angle),'k--','LineWidth',1.2);
    stationHandle = scatter(axisHandle,item.points(:,1),item.points(:,2),24,colors(variant,:),'filled');
    originHandle = plot(axisHandle,0,0,'k+','MarkerSize',10,'LineWidth',1.4);
    axis(axisHandle,'equal');
    xlim(axisHandle,[-extent,extent]);
    ylim(axisHandle,[-extent,extent]);
    q4StyleAxes(axisHandle,fontName);
    xlabel(axisHandle,'x / m','FontName',fontName);
    ylabel(axisHandle,'y / m','FontName',fontName);
    title(axisHandle,{sprintf('%s：%d站',labels{variant},grids.Stations(variant)), ...
        sprintf('单元边长 %.0f m；接收余量 %.0f m',grids.Spacing_m(variant),grids.RangeMargin_m(variant))}, ...
        'FontName',fontName,'FontSize',12,'FontWeight','normal');
    if variant==1
        legend(axisHandle,[circleHandle,stationHandle,originHandle],{'源位置边界','覆盖站点','机器人起点'}, ...
            'Location','southoutside','Orientation','horizontal','FontName',fontName,'FontSize',10,'Box','off');
    end
end
title(firstLayout,'第1项：三个具有连续方向覆盖依据的布局','FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(firstLayout,'完整闭三角单元覆盖半径1800米源域；外部站点保留；所有发射朝向采用同一覆盖论证', ...
    'FontName',fontName,'FontSize',10.5);
q4ExportFigure(firstFigure,figurePath,'figure01_layout_comparison');
clear firstCleanup
secondFigure = figure('Visible','off','Color','white','Position',[100,100,1450,890]);
secondCleanup = onCleanup(@() close(secondFigure));
secondLayout = tiledlayout(secondFigure,2,2,'Padding','compact','TileSpacing','compact');
pairAxes = nexttile(secondLayout,[1,2]);
hold(pairAxes,'on');
candidateHandles = gobjects(1,2);
markers = {'o','s'};
styles = {'-','--'};
for variant = 2:numel(kinds)
    rows = summary(summary.Layout==kinds(variant),:);
    candidateHandles(variant-1) = plot(pairAxes,1:height(rows),rows.DeltaPercent, ...
        'Color',colors(variant,:),'LineStyle',styles{variant-1},'Marker',markers{variant-1}, ...
        'MarkerFaceColor','white','MarkerSize',4.5,'LineWidth',1.15);
end
yline(pairAxes,0,'k-','LineWidth',0.9,'HandleVisibility','off');
xline(pairAxes,8.5,':','边界场景 / 随机场景','FontName',fontName,'FontSize',10,'LabelVerticalAlignment','top','HandleVisibility','off');
q4StyleAxes(pairAxes,fontName);
xlim(pairAxes,[0.5,28.5]);
xticks(pairAxes,1:28);
xlabel(pairAxes,'同场构造案例编号','FontName',fontName);
ylabel(pairAxes,'完整T相对基线变化 / %','FontName',fontName);
title(pairAxes,'（a）全部28场配对：高于零线表示变慢','FontName',fontName,'FontSize',13,'FontWeight','normal');
legend(pairAxes,candidateHandles,labels(2:end),'FontName',fontName,'Location','southoutside','Orientation','horizontal','Box','off');
costs = zeros(numel(kinds),5);
tailCosts = zeros(numel(kinds),5);
for variant = 1:numel(kinds)
    rows = summary(summary.Layout==kinds(variant),:);
    costs(variant,:) = mean(rows{:,{'Move_s','Measure_s','Switch_s','SuccessClear_s','FailedClear_s'}},1);
    tailCosts(variant,:) = mean(rows{:,{'TailMove_s','TailMeasure_s','TailSwitch_s','TailSuccessClear_s','TailFailedClear_s'}},1);
end
costAxes = nexttile(secondLayout);
costHandles = bar(costAxes,1:3,costs,'stacked','BarWidth',0.65);
tailAxes = nexttile(secondLayout);
tailHandles = bar(tailAxes,1:3,tailCosts,'stacked','BarWidth',0.65);
costColors = [0.20,0.40,0.62;0.41,0.63,0.71;0.91,0.67,0.29;0.47,0.61,0.42;0.70,0.39,0.40];
for component = 1:5
    set(costHandles(component),'FaceColor',costColors(component,:),'EdgeColor',[0.25,0.25,0.25],'LineWidth',0.45);
    set(tailHandles(component),'FaceColor',costColors(component,:),'EdgeColor',[0.25,0.25,0.25],'LineWidth',0.45);
end
q4StyleAxes(costAxes,fontName);
q4StyleAxes(tailAxes,fontName);
xticks(costAxes,1:3);
xticklabels(costAxes,labels);
xticks(tailAxes,1:3);
xticklabels(tailAxes,labels);
ylabel(costAxes,'每场平均虚拟时间 / s','FontName',fontName);
ylabel(tailAxes,'每场平均尾程时间 / s','FontName',fontName);
title(costAxes,'（b）完整任务的五项费用','FontName',fontName,'FontSize',13,'FontWeight','normal');
title(tailAxes,'（c）末次成功清除至退出的尾程','FontName',fontName,'FontSize',13,'FontWeight','normal');
ylim(costAxes,[0,max(sum(costs,2))*1.15]);
ylim(tailAxes,[0,max(sum(tailCosts,2))*1.15]);
for variant = 1:numel(kinds)
    text(costAxes,variant,sum(costs(variant,:))+max(sum(costs,2))*0.025,sprintf('%.1f s',sum(costs(variant,:))), ...
        'HorizontalAlignment','center','FontName',fontName,'FontSize',11);
    text(tailAxes,variant,sum(tailCosts(variant,:))+max(sum(tailCosts,2))*0.025,sprintf('%.1f s',sum(tailCosts(variant,:))), ...
        'HorizontalAlignment','center','FontName',fontName,'FontSize',11);
end
costLegend = legend(costAxes,costHandles,{'移动','检测','切频','成功清除','失败清除'}, ...
    'NumColumns',5,'Orientation','horizontal','FontName',fontName,'FontSize',11,'Box','off');
costLegend.Layout.Tile = 'south';
title(secondLayout,'第1项：完整任务耗时及排空尾程的同场比较','FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(secondLayout,'尾程已包含在完整费用内，不重复相加；全部变慢场景保留；构造案例不代表官方分布或全局最优', ...
    'FontName',fontName,'FontSize',10.5);
q4ExportFigure(secondFigure,figurePath,'figure02_paired_time_and_drain_tail');
clear secondCleanup
end


function [destination,bound] = q4SafeClearPoint(polygon,position,center,limit)
validPolygon = isnumeric(polygon) && isreal(polygon) && ismatrix(polygon) && ~isempty(polygon) ...
    && size(polygon,2)==2 && all(isfinite(polygon),'all');
validPosition = isnumeric(position) && isreal(position) && isequal(size(position),[1,2]) && all(isfinite(position));
validCenter = isnumeric(center) && isreal(center) && isequal(size(center),[1,2]) && all(isfinite(center));
validLimit = isnumeric(limit) && isreal(limit) && isscalar(limit) && isfinite(limit) && limit>1e-7;
assert(validPolygon && validPosition && validCenter && validLimit,'Q4:SafeClearInput','A finite polygon, two row coordinates and a positive clear margin are required.');
polygon = double(polygon);
position = double(position);
center = double(center);
limit = double(limit);
rho = limit-1e-7;
tolerance = min(1e-9,32*eps(max([1;abs(polygon(:));abs(position(:));abs(center(:));limit])));
[valid,bound] = q4ClearCovered(polygon,center,rho+tolerance);
assert(valid && bound<=limit,'Q4:SafeClearInfeasible','The supplied center does not cover the polygon with the required margin.');
destination = center;
best = hypot(center(1)-position(1),center(2)-position(2));
[valid,atBound] = q4ClearCovered(polygon,position,rho);
if valid
    destination = position;
    bound = atBound;
    return
end
for first = 1:size(polygon,1)
    vector = position-polygon(first,:);
    distance = hypot(vector(1),vector(2));
    if distance>rho
        accept(polygon(first,:)+rho*(vector/distance));
    else
        accept(position);
    end
    for second = first+1:size(polygon,1)
        vector = polygon(second,:)-polygon(first,:);
        distance = hypot(vector(1),vector(2));
        if distance==0 || ~isfinite(distance) || distance>2*rho+tolerance
            continue
        end
        middle = polygon(first,:)+vector/2;
        normal = [-vector(2),vector(1)]/distance;
        height = sqrt(max(0,(rho-distance/2)*(rho+distance/2)));
        accept(middle+height*normal);
        accept(middle-height*normal);
    end
end
[valid,bound] = q4ClearCovered(polygon,destination,limit);
assert(valid && bound<=rho+tolerance && isfinite(best),'Q4:SafeClearCertificate','The selected point must cover every outer polygon vertex.');

    function accept(candidate)
        [covered,candidateBound] = q4ClearCovered(polygon,candidate,rho+tolerance);
        travel = hypot(candidate(1)-position(1),candidate(2)-position(2));
        if covered && candidateBound<=limit && isfinite(travel) && travel<best
            destination = candidate;
            best = travel;
        end
    end
end

function [covered,bound] = q4ClearCovered(polygon,point,limit)
covered = false;
bound = Inf;
validPolygon = isnumeric(polygon) && isreal(polygon) && ismatrix(polygon) && ~isempty(polygon) ...
    && size(polygon,2)==2 && all(isfinite(polygon),'all');
validPoint = isnumeric(point) && isreal(point) && isequal(size(point),[1,2]) && all(isfinite(point));
validLimit = isnumeric(limit) && isreal(limit) && isscalar(limit) && isfinite(limit) && limit>=0;
if ~validPolygon || ~validPoint || ~validLimit
    return
end
deltaX = double(polygon(:,1))-double(point(1));
deltaY = double(polygon(:,2))-double(point(2));
bound = max(hypot(deltaX,deltaY));
covered = isfinite(bound) && bound<=double(limit);
end

function checks = q4SafeGeometryChecks()
names = strings(0,1);
passed = false(0,1);
limit = 19.5;
rho = limit-1e-7;
polygon = [-10,0;10,0;0,6];
[point,bound] = q4SafeClearPoint(polygon,[0,0],[0,0],limit);
record("SafeClearAlreadyCoveredNeedsNoMovement",isequal(point,[0,0]) && abs(bound-10)<1e-12);
[point,bound] = q4SafeClearPoint([0,0],[100,0],[0,0],limit);
record("SafeClearSingletonMatchesRadialProjection",norm(point-[rho,0])<1e-10 && abs(bound-rho)<1e-10);
collinear = [-10,0;0,0;10,0;10,0];
[point,bound] = q4SafeClearPoint(collinear,[0,100],[0,0],limit);
record("SafeClearRepeatedCollinearVertices",norm(point-[0,sqrt(rho^2-100)])<1e-9 && bound<=limit);
[point,bound] = q4SafeClearPoint([-rho,0;rho,0],[0,100],[0,0],limit);
record("SafeClearTangentDisksGiveUniquePoint",norm(point)<1e-9 && abs(bound-rho)<1e-9);
span = rho-1e-4;
[point,bound] = q4SafeClearPoint([-span,0;span,0],[0,100],[0,0],limit);
record("SafeClearNearTangencyKeepsFeasibleLens",norm(point-[0,sqrt((rho-span)*(rho+span))])<1e-8 && bound<=limit);
angles = ((0:71)'+0.5)*5;
outer = 5/cosd(2.5)*[cosd(angles),sind(angles)];
direction = [cosd(2.5),sind(2.5)];
[point,bound] = q4SafeClearPoint(outer,100*direction,[0,0],limit);
distances = hypot(outer(:,1)-point(1),outer(:,2)-point(2));
record("SafeClearNearCoversCompleteOuterPolygon",max(distances)<=limit && abs(bound-max(distances))<1e-12 ...
    && norm(point-(rho-5/cosd(2.5))*direction)<1e-8);
[covered,bound] = q4ClearCovered(outer,(limit-5)*direction,limit);
record("SafeClearNearDiskShortcutLeaksOuterVertex",~covered && bound>limit+0.004);
forgedRadius = 5;
[covered,bound] = q4ClearCovered(polygon,[30,0],limit);
record("SafeClearRejectsForgedRadiusMissingVertex",forgedRadius<limit && ~covered && abs(bound-40)<1e-12);
span = rho-1e-6;
[point,bound] = q4SafeClearPoint([-span,0;span,0],[0,0],[0,0],limit);
record("SafeClearInsideThresholdIsFeasible",isequal(point,[0,0]) && bound<rho);
record("SafeClearOutsideThresholdIsRejected",rejects(@() q4SafeClearPoint([-limit-1e-6,0;limit+1e-6,0], ...
    [0,100],[0,0],limit),"Q4:SafeClearInfeasible"));
record("SafeClearRejectsInfeasibleFallback",rejects(@() q4SafeClearPoint(polygon,[100,30],[1000,0],limit),"Q4:SafeClearInfeasible"));
position = [100,30];
[point,bound] = q4SafeClearPoint(polygon,position,[0,0],limit);
angles = (0:14399)'*2*pi/14400;
reference = Inf;
for first = 1:size(polygon,1)
    samples = polygon(first,:)+rho*[cos(angles),sin(angles)];
    valid = true(size(angles));
    for second = 1:size(polygon,1)
        valid = valid & hypot(samples(:,1)-polygon(second,1),samples(:,2)-polygon(second,2))<=rho+1e-10;
    end
    distances = hypot(samples(valid,1)-position(1),samples(valid,2)-position(2));
    if ~isempty(distances)
        reference = min(reference,min(distances));
    end
end
travel = hypot(point(1)-position(1),point(2)-position(2));
record("SafeClearIndependentBoundarySampling",isfinite(reference) && bound<=limit && travel<=reference+1e-8 ...
    && reference-travel<0.02 && travel<hypot(position(1),position(2)));
rotation = [cosd(73),sind(73);-sind(73),cosd(73)];
shift = [1700,-1100];
[transformed,transformedBound] = q4SafeClearPoint(polygon*rotation+shift,position*rotation+shift,shift,limit);
record("SafeClearTranslationAndRotationAgree",norm(transformed-(point*rotation+shift))<1e-7 && abs(transformedBound-bound)<1e-7);
record("SafeClearRejectsEmptyAndNonfinitePolygon",rejects(@() q4SafeClearPoint(zeros(0,2),[0,0],[0,0],limit),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint([NaN,0],[0,0],[0,0],limit),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint([Inf,0],[0,0],[0,0],limit),"Q4:SafeClearInput"));
record("SafeClearRejectsWrongCoordinateDimensions",rejects(@() q4SafeClearPoint(ones(2,3),[0,0],[0,0],limit),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[0;0],[0,0],limit),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[0,0],[0;0],limit),"Q4:SafeClearInput"));
record("SafeClearRejectsInvalidLimit",rejects(@() q4SafeClearPoint(polygon,[0,0],[0,0],0),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[0,0],[0,0],1e-7),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[0,0],[0,0],NaN),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[0,0],[0,0],Inf),"Q4:SafeClearInput"));
record("SafeClearRejectsComplexInput",rejects(@() q4SafeClearPoint([1i,0],[0,0],[0,0],limit),"Q4:SafeClearInput") ...
    && rejects(@() q4SafeClearPoint(polygon,[1i,0],[0,0],limit),"Q4:SafeClearInput"));
record("SafeClearCoverageRejectsInvalidEvidence",~q4ClearCovered(zeros(0,2),[0,0],limit) ...
    && ~q4ClearCovered(polygon,[NaN,0],limit) && ~q4ClearCovered(polygon,[0;0],limit) ...
    && ~q4ClearCovered(polygon,[0,0],NaN) && ~q4ClearCovered(polygon,[0,0],-1));
checks = table(names,passed,'VariableNames',{'Name','Passed'});

    function record(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = islogical(value) && isscalar(value) && value;
    end

    function value = rejects(action,identifier)
        value = false;
        try
            action();
        catch errorInfo
            value = string(errorInfo.identifier)==identifier;
        end
    end
end


function observations = q4PastObservations(events,channel)
observations = struct('position',{},'kind',{},'bearing',{});
for k = 1:numel(events)
    if events(k).path=="/measure" && events(k).channel==channel
        observations(end+1) = struct('position',[events(k).x,events(k).y],'kind',events(k).result,'bearing',events(k).bearing);
    end
end
end

function track = q4Remember(track,position,response)
bearing = NaN;
if string(response.measure_result)=="direction"
    bearing = response.svd_deg;
end
track.observations(end+1) = struct('position',position,'kind',string(response.measure_result),'bearing',bearing);
observations = track.observations;
positive = zeros(0,2);
negative = zeros(0,2);
for observation = observations
    if ismember(observation.kind,["direction","near"])
        positive(end+1,:) = observation.position;
    elseif observation.kind=="no_signal"
        negative(end+1,:) = observation.position;
    end
end
[candidate,trace] = q4JointShadow(track.polygon,positive,negative);
[~,radiusBefore] = q4Circle(track.polygon);
[~,radiusAfter] = q4Circle(candidate);
areaBefore = polyarea(track.polygon(:,1),track.polygon(:,2));
areaAfter = polyarea(candidate(:,1),candidate(:,2));
accepted = (areaBefore-areaAfter)/max(areaBefore,realmin)>=1e-4 || radiusBefore-radiusAfter>=0.01;
if ~isfield(track,'shadowUpdates')
    track.shadowUpdates = cell(0,1);
end
track.shadowUpdates{end+1,1} = struct('observationCount',numel(observations),'before',track.polygon, ...
    'candidate',candidate,'accepted',accepted,'trace',trace,'positive',positive,'negative',negative);
if accepted
    track.polygon = candidate;
end
end

function destination = q4LegacyPoint(track,center,radius,attempt)
normal = [-sind(track.angle),cosd(track.angle)];
offset = min(80,0.3*radius);
signs = [1,-1,0,2,-2];
destination = [];
for index = mod((attempt-1)+(0:4),5)+1
    candidate = center+signs(index)*offset*normal;
    if all(vecnorm(track.seen-candidate,2,2)>1e-6)
        destination = candidate;
        return
    end
end
end

function destination = q4LocalPolicyPoint(track,center,radius,attempt,silence,~,policy)
destination = q4LegacyPoint(track,center,radius,attempt);
if policy=="anchor_blend" && silence==1 && ~isempty(destination)
    candidate = (track.anchor+destination)/2;
    if all(isfinite(candidate)) && norm(candidate)<=2000 ...
            && all(vecnorm(track.seen-candidate,2,2)>1e-6)
        destination = candidate;
    end
end
end

function checks = q4AnchorBlendChecks()
track = struct('anchor',[100,-20],'angle',0,'seen',[100,-20;600,80]);
center = [600,0];
original = q4LegacyPoint(track,center,401,2);
actual = q4LocalPolicyPoint(track,center,401,2,1,[600,80],"anchor_blend");
names = ["blend_uses_positive_anchor_and_next_legacy_point";"blend_without_silence_preserves_legacy";"blend_duplicate_preserves_legacy";"blend_empty_legacy_stays_empty"];
passed = false(4,1);
passed(1) = isequal(actual,(track.anchor+original)/2) && actual(2)<0;
passed(2) = isequal(q4LocalPolicyPoint(track,center,401,2,0,[600,80],"anchor_blend"),original);
track.seen(end+1,:) = actual;
passed(3) = isequal(q4LocalPolicyPoint(track,center,401,2,1,[600,80],"anchor_blend"),original);
track.seen = [600,80;600,-80;600,0;600,160;600,-160];
passed(4) = isempty(q4LocalPolicyPoint(track,center,401,2,1,[600,80],"anchor_blend"));
checks = table(names,passed,'VariableNames',{'Name','Passed'});
end

function [destination,evidence] = q4LocalPoint(track,position,receiver,channel,attempt,settings)
[center,radius] = q4Circle(track.polygon);
legacy = q4LegacyPoint(track,center,radius,attempt);
normal = [-sind(track.angle),cosd(track.angle)];
offset = min(80,0.3*radius);
candidates = unique([legacy;center;center+offset*normal;center-offset*normal],'rows','stable');
keep = all(isfinite(candidates),2) & vecnorm(candidates,2,2)<=2000;
for k = 1:size(candidates,1)
    keep(k) = keep(k) && all(vecnorm(track.seen-candidates(k,:),2,2)>1e-6);
end
candidates = candidates(keep,:);
middle = mean(track.polygon,1);
direction = [cosd(track.firstAngle),sind(track.firstAngle)];
[~,low] = min(track.polygon*direction');
[~,high] = max(track.polygon*direction');
representatives = unique([middle;0.99*track.polygon([low,high],:)+0.01*middle],'rows','stable');
scores = Inf(size(candidates,1),1);
branches = struct('candidate',{},'representative',{},'kind',{},'error',{},'total',{},'costs',{},'clearPoints',{},'clearResults',{},'radius',{},'axis',{});
counts = zeros(size(candidates,1),2);
for k = 1:size(candidates,1)
    at = candidates(k,:);
    for j = 1:size(representatives,1)
        target = representatives(j,:);
        for visible = [false,true]
            [feasible,range,axis] = q4Compatible(track,target,at,visible,settings.angleMargin);
            if ~feasible
                continue
            end
            kinds = "no_signal";
            errors = NaN;
            if visible && norm(target-at)<=5
                kinds = "near";
            elseif visible
                kinds = ["direction","direction","direction"];
                errors = [-1,0,1];
            end
            for m = 1:numel(kinds)
                polygon = track.polygon;
                if kinds(m)=="near"
                    polygon = q4ClipDisk(polygon,at,5,settings.diskSides);
                elseif kinds(m)=="direction"
                    bearing = atan2d(target(2)-at(2),target(1)-at(1))+errors(m);
                    polygon = q4ClipDisk(polygon,at,1500,settings.diskSides);
                    polygon = q4Wedge(polygon,at,bearing,settings.angleMargin);
                end
                if isempty(polygon) || q4DistancePolygon(target,polygon)>1e-5
                    continue
                end
                [costs,clearPoints,clearResults] = q4FinishCost(polygon,track,at,target,settings);
                costs(1) = costs(1)+norm(at-position)/5;
                costs(2:3) = [5,double(receiver~=channel)];
                total = sum(costs);
                branches(end+1) = struct('candidate',k,'representative',j,'kind',kinds(m),'error',errors(m), ...
                    'total',total,'costs',costs,'clearPoints',clearPoints,'clearResults',clearResults,'radius',range,'axis',axis);
                counts(k,1+visible) = counts(k,1+visible)+1;
            end
        end
    end
    rows = [branches.candidate]==k;
    if any(rows)
        scores(k) = max([branches(rows).total]);
    end
end
destination = legacy;
selected = find(vecnorm(candidates-legacy,2,2)<1e-7,1);
fallback = isempty(selected) || any(~isfinite(scores));
if ~fallback
    [~,selected] = min(scores);
    destination = candidates(selected,:);
end
evidence = struct('candidates',candidates,'representatives',representatives,'scores',scores,'counts',counts, ...
    'selected',selected,'usedLegacyFallback',fallback,'branches',branches, ...
    'meaning',"FINITE_COMPATIBLE_CASE_COMPLETION_COST_NOT_GLOBAL_BOUND_OR_EXPECTATION");
end

function [feasible,range,axis] = q4Compatible(track,target,at,visible,margin)
feasible = false;
range = NaN;
axis = NaN;
if norm(target)>1800+1e-7 || q4DistancePolygon(target,track.polygon)>1e-6
    return
end
positive = zeros(0,2);
negative = zeros(0,2);
for k = 1:numel(track.observations)
    item = track.observations(k);
    delta = item.position-target;
    if item.kind=="no_signal"
        negative(end+1,:) = delta;
    else
        positive(end+1,:) = delta;
        if item.kind=="near"
            if norm(delta)>5+1e-7
                return
            end
        else
            angle = atan2d(-delta(2),-delta(1));
            if norm(delta)<=5 || abs(mod(angle-item.bearing+180,360)-180)>min(margin,1.00500001)+1e-8
                return
            end
        end
    end
end
if isempty(positive)
    return
end
range = max([1000;vecnorm(positive,2,2)]);
if visible
    range = max(range,norm(at-target));
    positive(end+1,:) = at-target;
end
if range>1500+1e-7
    return
end
negative = negative(vecnorm(negative,2,2)<=range+1e-7,:);
if ~visible && norm(at-target)<=range+1e-7
    negative(end+1,:) = at-target;
end
if isempty(negative)
    feasible = true;
    return
end
vectors = [positive;negative];
cuts = unique(mod([atan2d(vectors(:,2),vectors(:,1))+90;atan2d(vectors(:,2),vectors(:,1))-90],360));
widths = diff([cuts;cuts(1)+360]);
angles = [cuts;mod(cuts+widths/2,360)];
for k = 1:numel(angles)
    unit = [cosd(angles(k));sind(angles(k))];
    if all(positive*unit>=-1e-8) && all(negative*unit < -1e-8)
        feasible = true;
        axis = angles(k);
        return
    end
end
end

function [costs,points,successes] = q4FinishCost(polygon,track,position,target,settings)
[center,radius] = q4Circle(polygon);
if radius<=settings.clearMargin
    [points,~] = q4SafeClearPoint(polygon,position,center,settings.clearMargin);
    successes = true;
else
    [points,~] = q4OpticalQueue(track.firstAnchor,track.firstAngle,polygon,position);
    found = find(vecnorm(points-target,2,2)<=20+1e-9,1);
    assert(~isempty(found),'Q4:PredictionCover','A compatible representative is not covered by the unchanged optical queue.');
    points = points(1:found,:);
    successes = false(found,1);
    successes(end) = true;
end
travel = sum(vecnorm(diff([position;points],1,1),2,2))/5;
costs = [travel,0,0,5,3*(size(points,1)-1)];
end


function checks = q4LocalChecks()
names = strings(0,1);
passed = false(0,1);
settings = struct('version',"0.3.0",'angleMargin',1.01,'clearMargin',19.5,'diskSides',72, ...
    'localLimit',6,'silenceLimit',2,'layout',"triangle",'seed',2026091204,'strategy',"cost", ...
    'robotId','OFFLINE_LOCAL_CHECK','requestPrefix','local-check');
polygon = q4ClipDisk(q4Disk([0,0],1800,72),[0,0],1500,72);
polygon = q4Wedge(polygon,[0,0],0,1.01);
track = struct('polygon',polygon,'anchor',[0,0],'angle',0,'firstAnchor',[0,0],'firstAngle',0, ...
    'seen',[0,0],'near',false,'observations',struct('position',[0,0],'kind',"direction",'bearing',0));
[silent,range,axis] = q4Compatible(track,[750,0],[800,0],false,1.01);
record("CompatibleSilenceInside1000HasDirectionalWitness",silent && range==1000 && ...
    dot([-750,0],[cosd(axis),sind(axis)])>=-1e-8 && dot([50,0],[cosd(axis),sind(axis)])<0);
record("PositiveMayRequireRadiusAboveMinimum",q4Compatible(track,[750,0],[-600,0],true,1.01));
record("SamePointCannotBePositiveAndSilent",~q4Compatible(track,[750,0],[0,0],false,1.01));
conflict = q4Remember(track,[-500,0],struct('measure_result',"no_signal"));
record("LargerRadiusRechecksHistoricalSilence",~q4Compatible(conflict,[750,0],[-600,0],true,1.01));
record("OutsidePhysicalRegionIsRejected",~q4Compatible(track,[1900,0],[0,0],true,1.01));
past = struct('path',"/measure",'channel',1,'x',-500,'y',0,'result',"no_signal",'bearing',NaN);
pastTrack = track;
pastTrack.observations = [q4PastObservations(past,1),track.observations];
record("PrediscoverySilenceIsRetainedForCompatibility",numel(pastTrack.observations)==2 && ...
    ~q4Compatible(pastTrack,[750,0],[-600,0],true,1.01));
rectangle = [0,-27;1500,-27;1500,27;0,27];
boundary = [0,6.5];
unit = (boundary-[0,-13.5])/20;
[below,belowPoints,~] = q4FinishCost(rectangle,track,[0,0],boundary-5e-8*unit,settings);
[above,abovePoints,~] = q4FinishCost(rectangle,track,[0,0],boundary+5e-8*unit,settings);
record("OpticalPredictionUsesTheActualTwentyMeterBoundary",size(belowPoints,1)==1 && size(abovePoints,1)==2 && ...
    below(5)==0 && above(5)==3 && above(1)>below(1));
before = track;
[destination,evidence] = q4LocalPoint(track,[0,0],2,1,1,settings);
record("PredictionDoesNotMutateObservationTrack",isequaln(before,track));
record("CandidatesRemainFiniteSmallAndUnseen",size(evidence.candidates,1)<=4 && all(isfinite(destination)) && ...
    all(vecnorm(evidence.candidates,2,2)<=2000) && all(vecnorm(evidence.candidates,2,2)>1e-6));
record("ScoreContainsCompatibleNoSignalBranches",any(evidence.counts(:,1)>0));
record("MinimaxSelectsFiniteCompletionCost",~evidence.usedLegacyFallback && ...
    evidence.scores(evidence.selected)==min(evidence.scores) && isequal(destination,evidence.candidates(evidence.selected,:)));
ok = true;
witnesses = true;
for k = 1:numel(evidence.branches)
    item = evidence.branches(k);
    at = evidence.candidates(item.candidate,:);
    segments = diff([[0,0];at;item.clearPoints],1,1);
    travel = sum(hypot(segments(:,1),segments(:,2)))/5;
    cost = travel+5+1+3*sum(~item.clearResults)+5*sum(item.clearResults);
    ok = ok && abs(cost-item.total)<1e-7 && sum(item.clearResults)==1 && item.clearResults(end) && ...
        abs(sum(item.costs)-cost)<1e-7;
    target = evidence.representatives(item.representative,:);
    visible = norm(at-target)<=item.radius+1e-7;
    if isfinite(item.axis)
        visible = visible && dot(at-target,[cosd(item.axis),sind(item.axis)])>=-1e-8;
    end
    witnesses = witnesses && visible==(item.kind~="no_signal");
end
record("PredictionCostsIndependentlyCountAllActions",ok);
record("PredictionVisibilityWitnessesAgree",witnesses);
[destination2,evidence2] = q4LocalPoint(track,[0,0],1,1,1,settings);
record("SwitchCostIsPaidOnlyByMeasurement",isequal(destination,destination2) && ...
    all(abs(evidence.scores-evidence2.scores-1)<1e-7));
[points,triangles,info] = q4Grid("triangle");
[exchange,report] = q4World([1,1700,0,1000,1,0,1]);
solution = q4Solve(exchange,settings,points,triangles,info);
world = report();
audit = q4Audit(solution,[1,1700,0,1000,1,0,1],world);
record("DirectionalSingleSourceCompletesWithActualEmptyChannels",audit.allPassed && ...
    all(solution.status==2 | solution.status==3) && sum(solution.status==2)==1 && all(solution.localMeasures<=6) && all(solution.fallbackAttempts<=152));
unchanged = true;
for k = 1:numel(solution.history)
    item = solution.history(k);
    if item.kind=="no_signal"
        previous = find([solution.history(1:k-1).channel]==item.channel,1,'last');
        unchanged = unchanged && ~isempty(previous) && isequal(item.polygon,solution.history(previous).polygon);
    end
end
record("ActualNoSignalKeepsTheEntirePreviousOuterRegion",unchanged && any([solution.noSignals]>0));
validSilence = true;
for k = 1:numel(solution.decisions)
    validSilence = validSilence && solution.decisions(k).silence<2 && solution.decisions(k).attempt<=6;
end
record("NoMeasurementAfterSilenceOrAttemptBudget",validSilence);
settings.requestPrefix = 'local-near';
[exchange,report] = q4World([1,0,0,1000,0,0,1]);
solution = q4Solve(exchange,settings,points,triangles,info);
world = report();
audit = q4Audit(solution,[1,0,0,1000,0,0,1],world);
record("NearClearsWithoutBearingOrFurtherMeasurements",audit.allPassed && sum(solution.localMeasures)==0 && ...
    numel(solution.certificates)==1 && norm(solution.certificates(1).position)<1e-7);
forged = solution;
forged.certificates(1).polygon(end+1,:) = [100,100];
forgedAudit = q4Audit(forged,[1,0,0,1000,0,0,1],world);
record("IndependentAuditRejectsForgedSmallRadiusCertificate",~forgedAudit.certifiedClears && ~forgedAudit.allPassed);
checks = table(names,passed,'VariableNames',{'Name','Passed'});
    function record(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = isscalar(value) && logical(value);
    end
end


function output = q4LocalStudy(path,settings,config)
assert(isfield(config,'baselinePath') && isfile(fullfile(config.baselinePath,'results.mat')),'Q4:LocalStudyBaseline','Use the fixed previous offline baseline.');
assert(string(settings.layout)=="triangle",'Q4:LocalStudyLayout','Item 2 retains the 37-station triangle layout.');
previous = load(fullfile(config.baselinePath,'results.mat'),'summary','scenarios');
assert(numel(previous.scenarios)==28 && isequaln(previous.scenarios,q4Scenarios(settings.seed)),'Q4:LocalStudyScenarios','The fixed 28 scenarios must match the retained baseline.');
caseIndices = 1:numel(previous.scenarios);
if isfield(config,'caseIndices')
    caseIndices = config.caseIndices;
    assert(isnumeric(caseIndices) && isvector(caseIndices) && ~isempty(caseIndices) && all(isfinite(caseIndices)) && ...
        all(fix(caseIndices)==caseIndices) && all(caseIndices>=1 & caseIndices<=numel(previous.scenarios)) && ...
        numel(unique(caseIndices))==numel(caseIndices),'Q4:LocalStudyCases','Case indices must be distinct valid fixed scenario indices.');
    caseIndices = reshape(caseIndices,1,[]);
end
scenarios = previous.scenarios(caseIndices);
strategies = ["baseline","safe","cost"];
baselineRows = previous.summary(string(previous.summary.Layout)=="triangle",:);
assert(height(baselineRows)==28 && all(baselineRows.FullClearVerified),'Q4:LocalStudyBaseline','The fixed triangle baseline is incomplete.');
[points,triangles,info] = q4Grid("triangle");
assert(size(points,1)==37,'Q4:LocalStudyLayout','The retained triangle layout must have exactly 37 stations.');
[coverageChecks,coverageEvidence] = q4CoverageChecks(points,triangles,info);
geometryPassed = all(coverageChecks.Passed) && coverageEvidence.continuousCoverageSupported;
assert(geometryPassed,'Q4:LocalStudyCoverage','The retained layout lacks continuous directional coverage evidence.');
writetable(coverageChecks,fullfile(path,'coverage_checks.csv'),'Encoding','UTF-8');
q4WriteJson(fullfile(path,'coverage_evidence.json'),coverageEvidence);
studyConfig = struct('strategies',strategies,'layout',"triangle",'stations',37,'seed',settings.seed, ...
    'caseIndices',caseIndices,'scenarioCount',numel(scenarios),'completeFixedSet',numel(scenarios)==28, ...
    'baselinePath',string(config.baselinePath),'baselineResultsSha256',q4FileHash(fullfile(config.baselinePath,'results.mat')), ...
    'baselineSummarySha256',q4FileHash(fullfile(config.baselinePath,'summary.csv')), ...
    'sourceSha256',q4FileHash([mfilename('fullpath') '.m']), ...
    'selectionPolicy',"REPORT_ALL_STRATEGIES_WITHOUT_AUTOMATIC_DEFAULT_CHANGE", ...
    'scope',"ITEM2_LOCAL_MEASUREMENT_AND_SAFE_CLEAR_ONLY", ...
    'evidence',"SELF_CHECKED_CONSTRUCTED_CASES_NOT_HUMAN_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'study_config.json'),studyConfig);
save(fullfile(path,'study_config.mat'),'studyConfig','scenarios','settings','config','points','triangles','info');
references = cell(numel(scenarios),1);
for caseIndex = 1:numel(scenarios)
    scene = scenarios(caseIndex);
    referenceRow = baselineRows(string(baselineRows.Scenario)==string(scene.name),:);
    assert(height(referenceRow)==1,'Q4:LocalStudyPair','Each scenario requires one fixed baseline row.');
    referencePath = fullfile(config.baselinePath,'triangle',scene.name,'run.mat');
    assert(isfile(referencePath),'Q4:LocalStudyBaseline','A fixed baseline run is missing.');
    referenceRun = load(referencePath,'solution','sources');
    assert(isequaln(referenceRun.sources,scene.sources) && referenceRun.solution.complete && ...
        abs(referenceRun.solution.virtualTime-referenceRow.VirtualTime_s)<=1e-7 && ...
        numel(referenceRun.solution.events)==referenceRow.Actions,'Q4:LocalStudyBaseline','Fixed baseline run identity disagrees with its scenario or summary.');
    references{caseIndex} = struct('row',referenceRow,'run',referenceRun,'sha256',q4FileHash(referencePath));
end
details = cell(numel(strategies),numel(scenarios));
records = cell(0,1);
for variant = 1:numel(strategies)
    strategy = strategies(variant);
    for caseIndex = 1:numel(scenarios)
        scene = scenarios(caseIndex);
        reference = references{caseIndex};
        cfg = settings;
        cfg.layout = "triangle";
        cfg.strategy = strategy;
        cfg.robotId = 'OFFLINE_Q4';
        cfg.requestPrefix = sprintf('local-%s-%d',strategy,caseIndices(caseIndex));
        [exchange,report] = q4World(scene.sources);
        timer = tic;
        solution = q4Solve(exchange,cfg,points,triangles,info);
        wallTime = toc(timer);
        world = report();
        runPath = fullfile(path,char(strategy),scene.name);
        mkdir(runPath);
        q4SaveRun(runPath,solution,world,scene.sources,cfg);
        try
            audit = q4Audit(solution,scene.sources,world);
        catch auditError
            audit = struct('allPassed',false,'failureIdentifier',string(auditError.identifier),'failureMessage',string(auditError.message));
        end
        q4WriteJson(fullfile(runPath,'audit.json'),audit);
        [metrics,accounting,stopEvidence] = q4StudyMetrics(solution,world);
        q4WriteJson(fullfile(runPath,'stop_evidence.json'),stopEvidence);
        q4WriteJson(fullfile(runPath,'cost_metrics.json'),metrics);
        writetable(accounting,fullfile(runPath,'action_accounting.csv'),'Encoding','UTF-8');
        q4WriteJson(fullfile(runPath,'certificates.json'),solution.certificates);
        q4WriteJson(fullfile(runPath,'decisions.json'),solution.decisions);
        inputMatch = isequaln(reference.run.sources,scene.sources);
        baselineTimeMatch = strategy~="baseline" || abs(solution.virtualTime-reference.run.solution.virtualTime)<=1e-7;
        baselineActionMatch = strategy~="baseline" || isequaln(solution.events,reference.run.solution.events);
        baselineCostMatch = strategy~="baseline" || all(abs(solution.costs-reference.run.solution.costs)<=1e-7);
        fullClear = solution.complete && all(world.cleared) && audit.allPassed && geometryPassed && ...
            metrics.accountingPassed && stopEvidence.allPassed && inputMatch && baselineTimeMatch && baselineActionMatch && baselineCostMatch;
        delta = solution.virtualTime-reference.row.VirtualTime_s;
        records{end+1,1} = struct('Strategy',strategy,'Scenario',string(scene.name),'CaseIndex',caseIndices(caseIndex), ...
            'Group',string(scene.group),'SourceCount',size(scene.sources,1),'Cleared',sum(world.cleared), ...
            'FullClearVerified',fullClear,'GeometryCoverageValid',geometryPassed,'AuditPassed',audit.allPassed, ...
            'ActualStopEvidence',stopEvidence.allPassed,'AccountingPassed',metrics.accountingPassed, ...
            'BaselineInputMatch',inputMatch,'BaselineTimeMatch',baselineTimeMatch,'BaselineActionMatch',baselineActionMatch, ...
            'BaselineCostMatch',baselineCostMatch,'BaselineRunSha256',reference.sha256, ...
            'StopReason',string(solution.stopReason),'VirtualTime_s',solution.virtualTime, ...
            'BaselineTime_s',reference.row.VirtualTime_s,'DeltaTime_s',delta,'DeltaPercent',100*delta/reference.row.VirtualTime_s, ...
            'MeanClearTime_s',q4MeanTime(solution.virtualTime,sum(world.cleared)),'FirstClear_s',metrics.firstClearTime_s, ...
            'LastClear_s',metrics.lastClearTime_s,'AfterLastClear_s',metrics.afterLastClear_s, ...
            'Move_s',metrics.costs_s(1),'Measure_s',metrics.costs_s(2),'Switch_s',metrics.costs_s(3), ...
            'SuccessClear_s',metrics.costs_s(4),'FailedClear_s',metrics.costs_s(5), ...
            'TailMove_s',metrics.tailCosts_s(1),'TailMeasure_s',metrics.tailCosts_s(2),'TailSwitch_s',metrics.tailCosts_s(3), ...
            'TailSuccessClear_s',metrics.tailCosts_s(4),'TailFailedClear_s',metrics.tailCosts_s(5), ...
            'CoveragePhase_s',metrics.coveragePhase_s,'LocalMeasurePhase_s',metrics.localMeasurePhase_s, ...
            'OpticalPhase_s',metrics.opticalPhase_s,'CertifiedClearPhase_s',metrics.certifiedClearPhase_s, ...
            'Distance_m',metrics.costs_s(1)*5,'Measures',metrics.costs_s(2)/5,'Switches',metrics.costs_s(3), ...
            'FailedClears',metrics.costs_s(5)/3,'OpticalAttempts',sum(solution.fallbackAttempts), ...
            'OpticalSources',sum(solution.fallbackAttempts>0),'LocalMeasures',sum(solution.localMeasures), ...
            'SelectedPredictions',numel(solution.decisions),'CertifiedClears',numel(solution.certificates), ...
            'CoverageMeasures',metrics.coverageMeasures,'VisitedStations',sum(solution.visited), ...
            'AbsentChannels',numel(stopEvidence.absentChannels),'FullyScannedAbsentChannels',stopEvidence.fullyScannedAbsentChannels, ...
            'Actions',numel(solution.events),'WallTime_s',wallTime,'TimeResidual_s',metrics.maximumTimeResidual_s, ...
            'Failure',string(solution.failure.identifier),'FailureMessage',string(solution.failure.message));
        details{variant,caseIndex} = solution;
        summary = struct2table(vertcat(records{:}));
        writetable(summary,fullfile(path,'summary.csv'),'Encoding','UTF-8');
        fprintf('Q4 ITEM2 %s %s: %d/%d T=%.6f delta=%+.6f opticalSources=%d passed=%d\n', ...
            strategy,scene.name,sum(world.cleared),size(scene.sources,1),solution.virtualTime,delta,sum(solution.fallbackAttempts>0),fullClear);
    end
end
summary = struct2table(vertcat(records{:}));
aggregate = q4LocalAggregate(summary,strategies);
writetable(aggregate,fullfile(path,'aggregate.csv'),'Encoding','UTF-8');
slowCases = summary(summary.Strategy~="baseline" & summary.DeltaTime_s>1e-7,:);
writetable(slowCases,fullfile(path,'slow_cases.csv'),'Encoding','UTF-8');
for strategy = strategies(2:end)
    writetable(slowCases(slowCases.Strategy==strategy,:),fullfile(path,char(strategy+"_slow_cases.csv")),'Encoding','UTF-8');
end
failedCases = summary(~summary.FullClearVerified,:);
writetable(failedCases,fullfile(path,'failed_cases.csv'),'Encoding','UTF-8');
save(fullfile(path,'results.mat'),'summary','aggregate','slowCases','failedCases','details','scenarios','settings', ...
    'config','studyConfig','points','triangles','info','coverageEvidence','-v7.3');
output = struct('path',path,'runs',height(summary),'fullClearVerified',sum(summary.FullClearVerified), ...
    'allPassed',all(summary.FullClearVerified),'scenarioIdentityMatch',all(summary.BaselineInputMatch), ...
    'baselineTimeMatch',all(summary.BaselineTimeMatch),'baselineActionMatch',all(summary.BaselineActionMatch), ...
    'baselineCostMatch',all(summary.BaselineCostMatch),'caseIndices',caseIndices,'completeFixedSet',numel(scenarios)==28, ...
    'slowCaseCount',height(slowCases),'failedCaseCount',height(failedCases),'strategies',strategies, ...
    'layout',"triangle",'defaultChanged',false,'sourceSha256',studyConfig.sourceSha256, ...
    'baselineResultsSha256',studyConfig.baselineResultsSha256, ...
    'evidence',"SELF_CHECKED_CONSTRUCTED_CASES_NOT_HUMAN_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'summary.json'),output);
q4LocalFigures(path,summary,aggregate,strategies);
assert(output.allPassed,'Q4:LocalStudyFailure','A local strategy study run failed; all produced evidence has been retained.');
end

function aggregate = q4LocalAggregate(summary,strategies)
baseAll = summary(summary.Strategy=="baseline",:);
groups = ["all_"+string(height(baseAll)),"boundary_"+string(sum(baseAll.Group=="constructed_boundary")), ...
    "random_"+string(sum(baseAll.Group=="constructed_random")),"source_count_16","source_count_below_16"];
records = cell(0,1);
for groupIndex = 1:numel(groups)
    if groupIndex==2
        mask = summary.Group=="constructed_boundary";
    elseif groupIndex==3
        mask = summary.Group=="constructed_random";
    elseif groupIndex==4
        mask = summary.SourceCount==16;
    elseif groupIndex==5
        mask = summary.SourceCount<16;
    else
        mask = true(height(summary),1);
    end
    base = summary(mask & summary.Strategy=="baseline",:);
    for strategy = strategies
        selected = summary(mask & summary.Strategy==strategy,:);
        assert(height(selected)==height(base) && all(selected.Scenario==base.Scenario),'Q4:LocalStudyAggregate','Paired groups must have matching scenarios.');
        worstDelta = NaN;
        worstPercent = NaN;
        if ~isempty(selected)
            worstDelta = max(selected.DeltaTime_s);
            worstPercent = max(selected.DeltaPercent);
        end
        records{end+1,1} = struct('Group',groups(groupIndex),'Strategy',strategy,'Scenarios',height(selected), ...
            'Verified',sum(selected.FullClearVerified),'MeanTime_s',mean(selected.VirtualTime_s), ...
            'BaselineMeanTime_s',mean(base.VirtualTime_s),'MeanDeltaTime_s',mean(selected.DeltaTime_s), ...
            'MeanTimeChangePercent',100*(mean(selected.VirtualTime_s)/mean(base.VirtualTime_s)-1), ...
            'Faster',sum(selected.DeltaTime_s < -1e-7),'Slower',sum(selected.DeltaTime_s>1e-7), ...
            'Equal',sum(abs(selected.DeltaTime_s)<=1e-7),'WorstDeltaTime_s',worstDelta,'WorstDeltaPercent',worstPercent, ...
            'MeanTail_s',mean(selected.AfterLastClear_s),'MeanTailDelta_s',mean(selected.AfterLastClear_s-base.AfterLastClear_s), ...
            'MeanCoveragePhase_s',mean(selected.CoveragePhase_s),'MeanLocalMeasurePhase_s',mean(selected.LocalMeasurePhase_s), ...
            'MeanOpticalPhase_s',mean(selected.OpticalPhase_s),'MeanCertifiedClearPhase_s',mean(selected.CertifiedClearPhase_s), ...
            'MeanMove_s',mean(selected.Move_s),'MeanMeasure_s',mean(selected.Measure_s),'MeanSwitch_s',mean(selected.Switch_s), ...
            'MeanSuccessClear_s',mean(selected.SuccessClear_s),'MeanFailedClear_s',mean(selected.FailedClear_s), ...
            'MeanTailMove_s',mean(selected.TailMove_s),'MeanTailMeasure_s',mean(selected.TailMeasure_s), ...
            'MeanTailSwitch_s',mean(selected.TailSwitch_s),'MeanTailSuccessClear_s',mean(selected.TailSuccessClear_s), ...
            'MeanTailFailedClear_s',mean(selected.TailFailedClear_s),'MeanOpticalAttempts',mean(selected.OpticalAttempts), ...
            'MeanOpticalSources',mean(selected.OpticalSources),'MeanLocalMeasures',mean(selected.LocalMeasures), ...
            'MeanSelectedPredictions',mean(selected.SelectedPredictions),'MeanWallTime_s',mean(selected.WallTime_s));
    end
end
aggregate = struct2table(vertcat(records{:}));
end

function q4LocalFigures(path,summary,aggregate,strategies)
figurePath = fullfile(path,'figures');
mkdir(figurePath);
fontName = 'Microsoft YaHei';
labels = {'原轮换与中心清除','原轮换与最近安全点','完整成本选点与最近安全点'};
base = summary(summary.Strategy=="baseline",:);
caseCount = height(base);
caseLabels = compose('%02d / %d',base.CaseIndex,base.SourceCount);
firstFigure = figure('Visible','off','Color','white','Position',[100,100,1500,900]);
firstCleanup = onCleanup(@() close(firstFigure));
firstLayout = tiledlayout(firstFigure,2,1,'Padding','compact','TileSpacing','compact');
for variant = 2:numel(strategies)
    rows = summary(summary.Strategy==strategies(variant),:);
    assert(height(rows)==caseCount && all(rows.Scenario==base.Scenario),'Q4:LocalFigurePair','Every plotted comparison must use matched cases.');
    axisHandle = nexttile(firstLayout);
    bars = bar(axisHandle,1:caseCount,rows.DeltaPercent,0.68,'FaceColor','flat','EdgeColor',[0.15,0.15,0.15],'LineWidth',0.5);
    colors = repmat([0.72,0.78,0.83],caseCount,1);
    slow = rows.DeltaTime_s>1e-7;
    colors(slow,:) = repmat([0.62,0.22,0.19],sum(slow),1);
    bars.CData = colors;
    hold(axisHandle,'on');
    yline(axisHandle,0,'k-','LineWidth',1.0);
    q4StyleAxes(axisHandle,fontName);
    xlim(axisHandle,[0.4,caseCount+0.6]);
    xticks(axisHandle,1:caseCount);
    xticklabels(axisHandle,cellstr(caseLabels));
    xtickangle(axisHandle,40);
    spread = max(1,max(abs(rows.DeltaPercent)));
    ylim(axisHandle,[min(0,min(rows.DeltaPercent))-0.10*spread,max(0,max(rows.DeltaPercent))+0.20*spread]);
    for rowIndex = find(slow)'
        text(axisHandle,rowIndex,rows.DeltaPercent(rowIndex)+0.025*spread,sprintf('+%.2f',rows.DeltaPercent(rowIndex)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontName',fontName,'FontSize',9,'Color',[0.40,0.10,0.08]);
    end
    xlabel(axisHandle,'固定案例编号 / 源数','FontName',fontName);
    ylabel(axisHandle,'完整T相对原基线变化 / %','FontName',fontName);
    title(axisHandle,sprintf('%s：%d快、%d慢、%d相同；全部慢例均标数',labels{variant}, ...
        sum(rows.DeltaTime_s < -1e-7),sum(slow),sum(abs(rows.DeltaTime_s)<=1e-7)), ...
        'FontName',fontName,'FontSize',13,'FontWeight','normal');
end
title(firstLayout,sprintf('第2项：固定37站、同一组%d场的完整耗时比较',caseCount),'FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(firstLayout,'零线上方为变慢；深色柱逐场标注；有限构造案例不代表官方分布或全局最优', ...
    'FontName',fontName,'FontSize',11);
set(findall(firstFigure,'-property','FontName'),'FontName',fontName);
set(firstFigure,'Renderer','painters','InvertHardcopy','off');
drawnow;
exportgraphics(firstFigure,fullfile(figurePath,'figure01_all_paired_cases.png'),'Resolution',240,'BackgroundColor','white');
savefig(firstFigure,fullfile(figurePath,'figure01_all_paired_cases.fig'));
clear firstCleanup
secondFigure = figure('Visible','off','Color','white','Position',[100,100,1500,900]);
secondCleanup = onCleanup(@() close(secondFigure));
secondLayout = tiledlayout(secondFigure,2,2,'Padding','compact','TileSpacing','compact');
allRows = aggregate(aggregate.Group=="all_"+string(caseCount),:);
assert(height(allRows)==numel(strategies) && all(allRows.Strategy==strategies'),'Q4:LocalFigureAggregate','Aggregate strategy order must match the comparison.');
costs = allRows{:,{'MeanMove_s','MeanMeasure_s','MeanSwitch_s','MeanSuccessClear_s','MeanFailedClear_s'}};
tailCosts = allRows{:,{'MeanTailMove_s','MeanTailMeasure_s','MeanTailSwitch_s','MeanTailSuccessClear_s','MeanTailFailedClear_s'}};
costColors = [0.20,0.40,0.62;0.41,0.63,0.71;0.91,0.67,0.29;0.47,0.61,0.42;0.70,0.39,0.40];
shortLabels = {'原基线','仅最近安全点','成本选点与安全点'};
costAxes = nexttile(secondLayout);
costHandles = bar(costAxes,1:3,costs,'stacked','BarWidth',0.65);
tailAxes = nexttile(secondLayout);
tailHandles = bar(tailAxes,1:3,tailCosts,'stacked','BarWidth',0.65);
for component = 1:5
    set(costHandles(component),'FaceColor',costColors(component,:),'EdgeColor',[0.25,0.25,0.25],'LineWidth',0.45);
    set(tailHandles(component),'FaceColor',costColors(component,:),'EdgeColor',[0.25,0.25,0.25],'LineWidth',0.45);
end
for axisHandle = [costAxes,tailAxes]
    q4StyleAxes(axisHandle,fontName);
    xticks(axisHandle,1:3);
    xticklabels(axisHandle,shortLabels);
    ylabel(axisHandle,'每场平均虚拟时间 / s','FontName',fontName);
end
title(costAxes,'（a）完整任务的五项费用','FontName',fontName,'FontSize',13,'FontWeight','normal');
title(tailAxes,'（b）末次成功清除至退出的尾程','FontName',fontName,'FontSize',13,'FontWeight','normal');
ylim(costAxes,[0,max(1,max(sum(costs,2)))*1.16]);
ylim(tailAxes,[0,max(1,max(sum(tailCosts,2)))*1.16]);
for variant = 1:numel(strategies)
    text(costAxes,variant,sum(costs(variant,:))+max(1,max(sum(costs,2)))*0.025,sprintf('%.1f s',sum(costs(variant,:))), ...
        'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
    text(tailAxes,variant,sum(tailCosts(variant,:))+max(1,max(sum(tailCosts,2)))*0.025,sprintf('%.1f s',sum(tailCosts(variant,:))), ...
        'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
end
opticalAxes = nexttile(secondLayout);
bar(opticalAxes,1:3,allRows.MeanOpticalSources,0.65,'FaceColor',[0.48,0.54,0.60],'EdgeColor',[0.20,0.20,0.20]);
measureAxes = nexttile(secondLayout);
bar(measureAxes,1:3,allRows.MeanLocalMeasures,0.65,'FaceColor',[0.48,0.54,0.60],'EdgeColor',[0.20,0.20,0.20]);
for axisHandle = [opticalAxes,measureAxes]
    q4StyleAxes(axisHandle,fontName);
    xticks(axisHandle,1:3);
    xticklabels(axisHandle,shortLabels);
end
ylabel(opticalAxes,'每场平均源数','FontName',fontName);
ylabel(measureAxes,'每场平均测量次数','FontName',fontName);
title(opticalAxes,'（c）转入原光学退路的源数','FontName',fontName,'FontSize',13,'FontWeight','normal');
title(measureAxes,'（d）局部补测次数','FontName',fontName,'FontSize',13,'FontWeight','normal');
ylim(opticalAxes,[0,max(1,max(allRows.MeanOpticalSources))*1.18]);
ylim(measureAxes,[0,max(1,max(allRows.MeanLocalMeasures))*1.18]);
for variant = 1:numel(strategies)
    text(opticalAxes,variant,allRows.MeanOpticalSources(variant)+max(1,max(allRows.MeanOpticalSources))*0.03, ...
        sprintf('%.2f',allRows.MeanOpticalSources(variant)),'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
    text(measureAxes,variant,allRows.MeanLocalMeasures(variant)+max(1,max(allRows.MeanLocalMeasures))*0.03, ...
        sprintf('%.2f',allRows.MeanLocalMeasures(variant)),'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
end
costLegend = legend(costAxes,costHandles,{'移动','检测','切频','成功清除','失败清除'}, ...
    'NumColumns',5,'Orientation','horizontal','FontName',fontName,'FontSize',11,'Box','off');
costLegend.Layout.Tile = 'south';
title(secondLayout,sprintf('第2项：%d场完整费用、尾程与光学退路统计',caseCount),'FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(secondLayout,'尾程已计入完整T，不重复相加；光学队列保持原定义；SELF_CHECKED，人工终审与正式测试未完成', ...
    'FontName',fontName,'FontSize',11);
set(findall(secondFigure,'-property','FontName'),'FontName',fontName);
set(secondFigure,'Renderer','painters','InvertHardcopy','off');
drawnow;
exportgraphics(secondFigure,fullfile(figurePath,'figure02_costs_tail_and_optical.png'),'Resolution',240,'BackgroundColor','white');
savefig(secondFigure,fullfile(figurePath,'figure02_costs_tail_and_optical.fig'));
clear secondCleanup
end


function [cells,certificate] = q4OpticalCells(anchor,angle,polygon)
assert(isnumeric(anchor) && isequal(size(anchor),[1,2]) && all(isfinite(anchor)) && isscalar(angle) && isfinite(angle) ...
    && isnumeric(polygon) && ~isempty(polygon) && size(polygon,2)==2 && all(isfinite(polygon),'all'),'Q4:OpticalCellInput','Finite optical geometry required.');
rotation = [cosd(angle),sind(angle);-sind(angle),cosd(angle)];
local = (polygon-anchor)*rotation';
assert(all(local(:,1)>=-10-1e-9 & local(:,1)<=1510+1e-9) && all(abs(local(:,2))<=27+1e-9),'Q4:OpticalCellEnvelope','Optical envelope exceeded.');
rectangle = [min(local(:,1)),max(local(:,1)),min(local(:,2)),max(local(:,2))];
span = rectangle(2)-rectangle(1); width = rectangle(4)-rectangle(3);
counts = inf(3,1); columns = zeros(3,1);
for rows = 1:3
    height = width/rows;
    if height>=38.8
        continue
    end
    step = 2*sqrt(19.4^2-(height/2)^2);
    columns(rows) = max(1,ceil(span/step));
    counts(rows) = rows*columns(rows);
end
[originalCount,rows] = min(counts);
columns = columns(rows);
assert(isfinite(originalCount) && originalCount<=152,'Q4:OpticalCellCertificate','Finite adaptive optical cover exceeds budget.');
edgesX = linspace(rectangle(1),rectangle(2),columns+1);
edgesY = linspace(rectangle(3),rectangle(4),rows+1);
cells = struct('id',{},'point',{},'polygon',{});
maximum = 0;
for column = 1:columns
    for row = 1:rows
        bounds = [edgesX(column),edgesX(column+1),edgesY(row),edgesY(row+1)];
        part = q4Plane(local,[1,0],bounds(2));
        part = q4Plane(part,[-1,0],-bounds(1));
        part = q4Plane(part,[0,1],bounds(4));
        part = q4Plane(part,[0,-1],-bounds(3));
        if isempty(part)
            continue
        end
        owner = [mean(bounds(1:2)),mean(bounds(3:4))];
        point = anchor+owner*rotation;
        vertices = anchor+part*rotation;
        bound = max(vecnorm(vertices-point,2,2));
        assert(bound<=19.4+1e-6 && bound<20,'Q4:OpticalCellCertificate','Unsafe adaptive cell.');
        maximum = max(maximum,bound);
        cells(end+1,1) = struct('id',(column-1)*rows+row,'point',point,'polygon',vertices);
    end
end
assert(~isempty(cells),'Q4:OpticalCellCertificate','Empty adaptive cover.');
certificate = struct('rectangle',rectangle,'coverRadius',19.4,'originalCount',originalCount,'retainedCount',numel(cells), ...
    'maximumOwnerBound',maximum,'columns',columns,'rows',rows,'mode',"adaptive_rectangle_cover",'fixedCellDomainCoversPolygon',true);
end

function [kept,removed] = q4PruneCells(cells,failedPoint,failedSerial)
validCells = isstruct(cells) && (isempty(cells) || isvector(cells)) && all(isfield(cells,{'id','point','polygon'}));
validPoint = isnumeric(failedPoint) && isreal(failedPoint) && isequal(size(failedPoint),[1,2]) && all(isfinite(failedPoint));
validSerial = isnumeric(failedSerial) && isreal(failedSerial) && isscalar(failedSerial) && isfinite(failedSerial) ...
    && failedSerial>=1 && failedSerial<=flintmax && failedSerial==fix(failedSerial);
assert(validCells && validPoint && validSerial,'Q4:OpticalCellInput','Valid optical cells, a failed point and a positive action serial are required.');
failedPoint = double(failedPoint);
failedSerial = double(failedSerial);
coverRadius = 19.4;
identifiers = zeros(numel(cells),1);
for index = 1:numel(cells)
    cellItem = cells(index);
    validId = isnumeric(cellItem.id) && isreal(cellItem.id) && isscalar(cellItem.id) && isfinite(cellItem.id) ...
        && cellItem.id>=1 && cellItem.id<=152 && cellItem.id==fix(cellItem.id);
    validOwner = isnumeric(cellItem.point) && isreal(cellItem.point) && isequal(size(cellItem.point),[1,2]) && all(isfinite(cellItem.point));
    validPolygon = isnumeric(cellItem.polygon) && isreal(cellItem.polygon) && ismatrix(cellItem.polygon) ...
        && ~isempty(cellItem.polygon) && size(cellItem.polygon,2)==2 && all(isfinite(cellItem.polygon),'all');
    assert(validId && validOwner && validPolygon,'Q4:OpticalCellInput','Every cell must have a unique original id, finite owner and nonempty polygon.');
    bound = max(hypot(double(cellItem.polygon(:,1))-double(cellItem.point(1)), ...
        double(cellItem.polygon(:,2))-double(cellItem.point(2))));
    assert(isfinite(bound) && bound<=coverRadius+1e-6 && bound<20,'Q4:OpticalCellCertificate','A cell is not covered by its recorded owner.');
    identifiers(index) = double(cellItem.id);
end
assert(numel(unique(identifiers))==numel(identifiers),'Q4:OpticalCellInput','Optical cell ids must be distinct.');
keep = true(size(cells));
removed = struct('id',{},'point',{},'polygon',{},'failedPoint',{},'failedSerial',{},'bound',{});
for index = 1:numel(cells)
    polygon = double(cells(index).polygon);
    bound = max(hypot(polygon(:,1)-failedPoint(1),polygon(:,2)-failedPoint(2)));
    if isfinite(bound) && bound<=20-1e-7
        keep(index) = false;
        removed(end+1,1) = struct('id',cells(index).id,'point',cells(index).point,'polygon',cells(index).polygon, ...
            'failedPoint',failedPoint,'failedSerial',failedSerial,'bound',bound);
    end
end
kept = cells(keep);
end

function checks = q4OpticalCellChecks()
names = strings(0,1);
passed = false(0,1);
domain = [-10,-27;1510,-27;1510,27;-10,27];
[fullCells,certificate] = q4OpticalCells([0,0],0,domain);
points = vertcat(fullCells.point);
record("OpticalCellsKeepAll152OriginalSnakeIds",numel(fullCells)==152 && isequal([fullCells.id],1:152) ...
    && isequal(points(1:4,:),[0,-13.5;0,13.5;20,13.5;20,-13.5]) ...
    && isequal(points(end-1:end,:),[1500,13.5;1500,-13.5]));
bounds = zeros(numel(fullCells),1);
for index = 1:numel(fullCells)
    delta = fullCells(index).polygon-fullCells(index).point;
    bounds(index) = max(hypot(delta(:,1),delta(:,2)));
end
record("OpticalCellsWholeVertexOwnerCoverage",all(bounds<=hypot(10,13.5)+1e-6) && all(bounds<20) ...
    && abs(certificate.maximumOwnerBound-max(bounds))<1e-10 && certificate.fixedCellDomainCoversPolygon);
outer = [1499,-2;1501.4,-2;1501.4,2;1499,2];
[outerCells,~] = q4OpticalCells([0,0],0,outer);
record("OpticalCellsKeepCircumscribedRegionPast1500",numel(outerCells)==2 && max(vertcat(outerCells.polygon),[],'all')>1500 ...
    && all(arrayfun(@(index) containsPoint(outer(index,:),outerCells),1:size(outer,1))));
polygon = [35,3;44,3;44,7;35,7];
[baseCells,~] = q4OpticalCells([0,0],0,polygon);
anchor = [1600,-900];
angle = 73;
rotation = [cosd(angle),sind(angle);-sind(angle),cosd(angle)];
[rotatedCells,~] = q4OpticalCells(anchor,angle,anchor+polygon*rotation);
record("OpticalCellsRotationAndTranslationAgree",numel(baseCells)==1 && numel(rotatedCells)==1 ...
    && baseCells.id==rotatedCells.id && norm(rotatedCells.point-(anchor+baseCells.point*rotation))<1e-8 ...
    && all(vecnorm(rotatedCells.polygon-(anchor+baseCells.polygon*rotation),2,2)<1e-8));
[pointCells,~] = q4OpticalCells([0,0],0,[10,0]);
record("OpticalCellsRetainSharedBoundarySingleton",numel(pointCells)==4 && all(arrayfun(@(item) size(item.polygon,1)==1,pointCells)) ...
    && all(arrayfun(@(item) norm(item.polygon-[10,0])<1e-10,pointCells)));
[lineCells,~] = q4OpticalCells([0,0],0,[1,0;9,0]);
record("OpticalCellsRetainZeroAreaSegments",numel(lineCells)==2 && all(arrayfun(@(item) size(item.polygon,1)==2,lineCells)) ...
    && containsPoint([1,0],lineCells) && containsPoint([9,0],lineCells));
[kept,removed] = q4PruneCells(fullCells,[5000,5000],1);
record("OpticalCellsDistantFailureDoesNotPrune",isequaln(kept,fullCells) && isempty(removed));
narrow = [-8,-1;28,-1;28,1;-8,1];
[narrowCells,~] = q4OpticalCells([0,0],0,narrow);
failedPoint = [0,-13.5];
[kept,removed] = q4PruneCells(narrowCells,failedPoint,17);
record("OpticalCellsFailurePrunesOwnAndCoveredPartner",isequal([removed.id],[1,2]) && isequal([kept.id],[3,4]) ...
    && all([removed.bound]<=20-1e-7) && all([removed.failedSerial]==17) ...
    && all(arrayfun(@(item) isequal(item.failedPoint,failedPoint),removed)));
target = [28,1];
record("OpticalCellsCompatibleTruePointSurvivesPruning",norm(target-failedPoint)>20 ...
    && containsPoint(target,narrowCells) && containsPoint(target,kept) ...
    && any(arrayfun(@(item) norm(target-item.point)<20,kept)));
[partialCells,~] = q4OpticalCells([0,0],0,[10.1,0;29.9,0]);
[partialKept,partialRemoved] = q4PruneCells(partialCells,failedPoint,18);
record("OpticalCellsPartialDiskOverlapIsRetained",norm([10.1,0]-failedPoint)<20 ...
    && isequaln(partialKept,partialCells) && isempty(partialRemoved));
single = struct('id',1,'point',[0,0],'polygon',[0,0]);
boundaryKept = zeros(1,4);
distances = [20-2e-7,20-1e-7,20,20+2e-7];
for index = 1:numel(distances)
    [boundaryCells,~] = q4PruneCells(single,[-distances(index),0],19+index);
    boundaryKept(index) = numel(boundaryCells);
end
record("OpticalCellsPruningRespectsClosedCircleMargin",isequal(boundaryKept,[0,0,1,1]));
forged = struct('id',1,'point',[0,0],'polygon',[-10,0;10,0],'bound',0);
[forgedKept,forgedRemoved] = q4PruneCells(forged,[0,-19.5],25);
record("OpticalCellsIgnoreForgedCachedSmallBound",numel(forgedKept)==1 && isempty(forgedRemoved) ...
    && hypot(10,19.5)>20);
record("OpticalCellsRejectInvalidDomainAndGeometry",rejects(@() q4OpticalCells([0,0],0,[1510.01,0]),"Q4:OpticalCellEnvelope") ...
    && rejects(@() q4OpticalCells([0,0],0,[0,27.01]),"Q4:OpticalCellEnvelope") ...
    && rejects(@() q4OpticalCells([0,0],NaN,polygon),"Q4:OpticalCellInput") ...
    && rejects(@() q4OpticalCells([0,0],0,zeros(0,2)),"Q4:OpticalCellInput") ...
    && rejects(@() q4OpticalCells([0;0],0,polygon),"Q4:OpticalCellInput"));
bad = struct('id',1,'point',[0,0],'polygon',[100,0]);
record("OpticalCellsRejectForgedOwnerAndInvalidFailure",rejects(@() q4PruneCells(bad,[0,0],1),"Q4:OpticalCellCertificate") ...
    && rejects(@() q4PruneCells(single,[NaN,0],1),"Q4:OpticalCellInput") ...
    && rejects(@() q4PruneCells(single,[0,0],0),"Q4:OpticalCellInput") ...
    && rejects(@() q4PruneCells([single;single],[0,0],1),"Q4:OpticalCellInput"));
[again,repeated] = q4PruneCells(kept,failedPoint,26);
[emptyKept,emptyRemoved] = q4PruneCells(narrowCells([]),failedPoint,27);
record("OpticalCellsRepeatedFailureAndEmptySetAreStable",isequaln(again,kept) && isempty(repeated) && isempty(emptyKept) && isempty(emptyRemoved));
checks = table(names,passed,'VariableNames',{'Name','Passed'});

    function record(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = islogical(value) && isscalar(value) && value;
    end

    function value = rejects(action,identifier)
        value = false;
        try
            action();
        catch errorInfo
            value = string(errorInfo.identifier)==identifier;
        end
    end

    function value = containsPoint(point,selected)
        value = false;
        for partIndex = 1:numel(selected)
            part = selected(partIndex).polygon;
            if size(part,1)==1
                distance = norm(point-part);
            else
                edges = part([2:end,1],:)-part;
                weights = sum((point-part).*edges,2)./max(sum(edges.^2,2),realmin);
                nearest = part+max(0,min(1,weights)).*edges;
                distance = min(hypot(nearest(:,1)-point(1),nearest(:,2)-point(2)));
                if size(part,1)>=3
                    [inside,on] = inpolygon(point(1),point(2),part(:,1),part(:,2));
                    if inside || on
                        distance = 0;
                    end
                end
            end
            if distance<=1e-7
                value = true;
                return
            end
        end
    end
end


function audit = q4OpticalAudit(solution,sources)
audit = struct('planBinding',true,'initialTruth',true,'continuousCover',true,'cellGeometry',true, ...
    'certificateFacts',true,'visitBinding',true,'queueOrder',true,'pruneBinding',true,'pruneBounds',true, ...
    'remainingTruth',true,'finiteProgress',true,'successSemantics',true,'skipCount',true, ...
    'legacyPrefix',true,'dataIntegrity',true,'planCount',0,'visitCount',0,'pruneCount',0, ...
    'maximumOwnerBound',0,'maximumPruneBound',0,'failureIdentifier',"",'failureMessage',"");
try
    assert(isstruct(solution) && isscalar(solution) && all(isfield(solution, ...
        {'opticalPlans','opticalVisits','opticalPrunes','opticalSkipped','events','history','fallbackAttempts','complete'})), ...
        'Q4:OpticalAuditInput','The solution must contain optical plans and complete action evidence.');
    assert(isnumeric(sources) && isreal(sources) && size(sources,2)==7 && all(isfinite(sources),'all') ...
        && numel(unique(sources(:,1)))==size(sources,1),'Q4:OpticalAuditInput','Finite distinct constructed source rows are required.');
    plans = solution.opticalPlans;
    visits = solution.opticalVisits;
    prunes = solution.opticalPrunes;
    events = solution.events;
    history = solution.history;
    assert(isstruct(plans) && all(isfield(plans,{'channel','serialBefore','mode','anchor','angle','polygon','queue','cells','certificate','legacyFallback','failureIdentifier'})) ...
        && isstruct(visits) && all(isfield(visits,{'channel','serial','cellId','point','remainingIds','mode'})) ...
        && isstruct(prunes) && all(isfield(prunes,{'id','point','polygon','failedPoint','failedSerial','bound','channel'})), ...
        'Q4:OpticalAuditInput','Optical evidence has an invalid schema.');
    audit.planCount = numel(plans);
    audit.visitCount = numel(visits);
    audit.pruneCount = numel(prunes);
    serials = [events.serial];
    assert(isvector(serials) && all(isfinite(serials)) && all(diff(serials)>0), ...
        'Q4:OpticalAuditInput','Action serials must be finite, unique and ordered.');
    assert(numel(unique([plans.channel]))==numel(plans) && all(diff([plans.serialBefore])>0), ...
        'Q4:OpticalAuditInput','Each optical channel must have exactly one ordered plan.');
    assert(all(diff([visits.serial])>0),'Q4:OpticalAuditInput','Optical visits must be unique and ordered.');
    usedVisits = false(1,numel(visits));
    usedPrunes = false(1,numel(prunes));
    matchedEvents = false(1,numel(events));
    expectedSkipped = zeros(1,20);
    attempts = zeros(1,20);
    for planIndex = 1:numel(plans)
        plan = plans(planIndex);
        channel = plan.channel;
        validChannel = isnumeric(channel) && isreal(channel) && isscalar(channel) && isfinite(channel) ...
            && channel>=1 && channel<=20 && channel==fix(channel);
        assert(validChannel && isscalar(plan.serialBefore) && isfinite(plan.serialBefore) ...
            && ismember(plan.serialBefore,serials) && q4OpticalAuditPoint(plan.anchor) ...
            && isnumeric(plan.angle) && isreal(plan.angle) && isscalar(plan.angle) && isfinite(plan.angle) ...
            && q4OpticalAuditPolygon(plan.polygon),'Q4:OpticalAuditInput','An optical plan has invalid geometry or identity.');
        mode = string(plan.mode);
        assert(isscalar(mode) && ismember(mode,["legacy","cells","nearest"]), ...
            'Q4:OpticalAuditInput','The optical mode is invalid.');
        target = sources(sources(:,1)==channel,2:3);
        assert(size(target,1)==1,'Q4:OpticalAuditInput','Each optical plan requires a discovered source.');
        prior = find([history.channel]==channel & [history.serial]<=plan.serialBefore,1,'last');
        first = find([history.channel]==channel & string({history.kind})=="discovery",1,'first');
        beforeEvent = find(serials==plan.serialBefore,1);
        positionBefore = [events(beforeEvent).x,events(beforeEvent).y];
        boundToHistory = ~isempty(prior) && ~isempty(first);
        if boundToHistory
            firstEvent = find(serials==history(first).serial,1);
            boundToHistory = ~isempty(firstEvent) && isequal(plan.polygon,history(prior).polygon) ...
                && isequal(plan.anchor,history(first).position) && events(firstEvent).path=="/measure" ...
                && events(firstEvent).channel==channel && events(firstEvent).result=="direction" ...
                && isequal(plan.angle,events(firstEvent).bearing);
        end
        audit.planBinding = audit.planBinding && boundToHistory;
        audit.initialTruth = audit.initialTruth && q4OpticalAuditDistance(target,plan.polygon)<=1e-7;
        rotation = [cosd(plan.angle),sind(plan.angle);-sind(plan.angle),cosd(plan.angle)];
        localPolygon = (plan.polygon-plan.anchor)*rotation';
        withinDomain = all(localPolygon(:,1)>=-10-1e-9) && all(localPolygon(:,1)<=1510+1e-9) ...
            && all(localPolygon(:,2)>=-27-1e-9) && all(localPolygon(:,2)<=27+1e-9);
        expectedCells = q4OpticalAuditCells(plan.anchor,rotation,localPolygon);
        audit.continuousCover = audit.continuousCover && withinDomain && ~isempty(expectedCells);
        queue = q4OpticalAuditLegacy(plan.anchor,rotation,plan.polygon,positionBefore);
        queueValid = isnumeric(plan.queue) && isreal(plan.queue) && isequal(size(queue),size(plan.queue)) ...
            && all(isfinite(plan.queue),'all') && all(abs(queue-plan.queue)<=1e-9,'all');
        audit.legacyPrefix = audit.legacyPrefix && queueValid;
        if mode=="legacy"
            audit.cellGeometry = audit.cellGeometry && isempty(plan.cells);
            fallbackValid = islogical(plan.legacyFallback) && isscalar(plan.legacyFallback) ...
                && ((plan.legacyFallback && string(plan.failureIdentifier)=="Q4:OpticalCellEnvelope") ...
                || (~plan.legacyFallback && string(plan.failureIdentifier)==""));
            certificateValid = isstruct(plan.certificate) && isscalar(plan.certificate) ...
                && all(isfield(plan.certificate,{'rectangle','coverRadius','originalCount','retainedCount'}));
            if certificateValid
                certificateValid = isequal(plan.certificate.rectangle,[0,1500,-27,27]) ...
                    && isequal(plan.certificate.originalCount,152) && isequal(plan.certificate.retainedCount,size(queue,1)) ...
                    && abs(plan.certificate.coverRadius-hypot(10,13.5))<=1e-10;
            end
            audit.certificateFacts = audit.certificateFacts && certificateValid && fallbackValid;
            remaining = zeros(1,0);
            planCells = plan.cells;
        else
            planCells = plan.cells;
            assert(isstruct(planCells) && ~isempty(planCells) && all(isfield(planCells,{'id','point','polygon'})), ...
                'Q4:OpticalAuditInput','A cell plan must retain its nonempty cell geometry.');
            expectedIds = [expectedCells.id];
            actualIds = [planCells.id];
            sameIds = isequal(actualIds,expectedIds);
            audit.continuousCover = audit.continuousCover && sameIds;
            assert(sameIds,'Q4:OpticalAuditCells','The plan must preserve every nonempty fixed-cell intersection.');
            maximumOwner = 0;
            for cellIndex = 1:numel(planCells)
                item = planCells(cellIndex);
                expected = expectedCells(cellIndex);
                assert(q4OpticalAuditPoint(item.point) && q4OpticalAuditPolygon(item.polygon), ...
                    'Q4:OpticalAuditInput','A cell has invalid owner coordinates or polygon geometry.');
                ownerBound = max(hypot(item.polygon(:,1)-item.point(1),item.polygon(:,2)-item.point(2)));
                maximumOwner = max(maximumOwner,ownerBound);
                local = (item.polygon-plan.anchor)*rotation';
                insideRectangle = all(local(:,1)>=expected.rectangle(1)-3e-8) ...
                    && all(local(:,1)<=expected.rectangle(2)+3e-8) ...
                    && all(local(:,2)>=expected.rectangle(3)-3e-8) ...
                    && all(local(:,2)<=expected.rectangle(4)+3e-8);
                samePolygon = q4OpticalAuditSetEqual(item.polygon,expected.polygon,2e-8);
                audit.cellGeometry = audit.cellGeometry && norm(item.point-expected.point)<=1e-9 ...
                    && insideRectangle && samePolygon && ownerBound<=19.4+1e-6 && ownerBound<20;
            end
            audit.maximumOwnerBound = max(audit.maximumOwnerBound,maximumOwner);
            certificateValid = isstruct(plan.certificate) && isscalar(plan.certificate) ...
                && all(isfield(plan.certificate,{'rectangle','coverRadius','originalCount','retainedCount','maximumOwnerBound'}));
            if certificateValid
                expectedRectangle = [min(localPolygon(:,1)),max(localPolygon(:,1)),min(localPolygon(:,2)),max(localPolygon(:,2))];
                certificateValid = max(abs(plan.certificate.rectangle-expectedRectangle))<=1e-8 ...
                    && plan.certificate.originalCount<=152 && plan.certificate.originalCount>=numel(planCells) ...
                    && isequal(plan.certificate.retainedCount,numel(planCells)) ...
                    && isscalar(plan.certificate.maximumOwnerBound) && isfinite(plan.certificate.maximumOwnerBound) ...
                    && abs(plan.certificate.maximumOwnerBound-maximumOwner)<=1e-9 ...
                    && abs(plan.certificate.coverRadius-19.4)<=1e-10;
            end
            audit.certificateFacts = audit.certificateFacts && certificateValid && isequal(plan.legacyFallback,false) ...
                && string(plan.failureIdentifier)=="";
            remaining = 1:numel(planCells);
            if norm(planCells(end).point-positionBefore)<norm(planCells(1).point-positionBefore)
                remaining = fliplr(remaining);
            end
            audit.remainingTruth = audit.remainingTruth && q4OpticalAuditInCells(target,expectedCells,remaining);
        end
        visitIndices = find([visits.channel]==channel);
        audit.finiteProgress = audit.finiteProgress && ~isempty(visitIndices) && numel(visitIndices)<=152;
        attempts(channel) = numel(visitIndices);
        usedIds = zeros(1,0);
        succeeded = false;
        for visitOrdinal = 1:numel(visitIndices)
            visitIndex = visitIndices(visitOrdinal);
            visit = visits(visitIndex);
            usedVisits(visitIndex) = true;
            assert(q4OpticalAuditPoint(visit.point) && isscalar(visit.serial) && isfinite(visit.serial), ...
                'Q4:OpticalAuditInput','An optical visit has invalid action coordinates.');
            eventIndex = find(serials==visit.serial,1);
            assert(~isempty(eventIndex),'Q4:OpticalAuditVisit','An optical visit must reference a real action.');
            event = events(eventIndex);
            matchedEvents(eventIndex) = true;
            visitValid = visit.serial==plan.serialBefore+visitOrdinal && event.path=="/clear" ...
                && event.channel==channel && event.phase=="optical_fallback" && string(visit.mode)==mode ...
                && isequal(visit.point,[event.x,event.y]);
            audit.visitBinding = audit.visitBinding && visitValid;
            priorSuccess = any([events(1:eventIndex-1).channel]==channel ...
                & string({events(1:eventIndex-1).path})=="/clear" & string({events(1:eventIndex-1).result})=="success");
            trueSuccess = ~priorSuccess && norm(target-visit.point)<=20+1e-9;
            responseSuccess = event.result=="success";
            audit.successSemantics = audit.successSemantics && trueSuccess==responseSuccess ...
                && ismember(event.result,["success","no_target_in_range"]);
            audit.finiteProgress = audit.finiteProgress && ~succeeded;
            succeeded = succeeded || responseSuccess;
            pruneIndices = find([prunes.failedSerial]==visit.serial);
            if mode=="legacy"
                prefixValid = visitOrdinal<=size(queue,1) && isequal(visit.cellId,0) && isempty(visit.remainingIds) && isempty(pruneIndices);
                if prefixValid
                    prefixValid = norm(visit.point-queue(visitOrdinal,:))<=1e-9;
                end
                audit.legacyPrefix = audit.legacyPrefix && prefixValid;
                continue
            end
            actualRemainingIds = [planCells(remaining).id];
            audit.pruneBinding = audit.pruneBinding && isequal(visit.remainingIds,actualRemainingIds);
            selected = find(actualRemainingIds==visit.cellId,1);
            assert(~isempty(selected),'Q4:OpticalAuditVisit','A visit must select a still retained cell.');
            cellIndex = remaining(selected);
            cellItem = planCells(cellIndex);
            audit.visitBinding = audit.visitBinding && isequal(visit.point,cellItem.point);
            audit.finiteProgress = audit.finiteProgress && ~ismember(visit.cellId,usedIds);
            usedIds(end+1) = visit.cellId;
            if mode=="cells"
                audit.queueOrder = audit.queueOrder && selected==1;
            else
                if eventIndex==1
                    previousPosition = [0,0];
                else
                    previousPosition = [events(eventIndex-1).x,events(eventIndex-1).y];
                end
                distances = vecnorm(vertcat(planCells(remaining).point)-previousPosition,2,2);
                eligible = distances<=min(distances)+1e-9;
                expectedId = min(actualRemainingIds(eligible));
                audit.queueOrder = audit.queueOrder && distances(selected)<=min(distances)+1e-9 && visit.cellId==expectedId;
            end
            if responseSuccess
                audit.pruneBinding = audit.pruneBinding && isempty(pruneIndices);
                continue
            end
            bounds = zeros(1,numel(remaining));
            for remainingIndex = 1:numel(remaining)
                polygon = planCells(remaining(remainingIndex)).polygon;
                bounds(remainingIndex) = max(hypot(polygon(:,1)-visit.point(1),polygon(:,2)-visit.point(2)));
            end
            removedMask = bounds<=20-1e-7;
            removedCells = remaining(removedMask);
            removedIds = [planCells(removedCells).id];
            loggedIds = [prunes(pruneIndices).id];
            audit.pruneBinding = audit.pruneBinding && isequal(loggedIds,removedIds) && ismember(visit.cellId,removedIds);
            audit.finiteProgress = audit.finiteProgress && ~isempty(removedIds) && ismember(visit.cellId,removedIds);
            for pruneIndex = pruneIndices
                item = prunes(pruneIndex);
                usedPrunes(pruneIndex) = true;
                originalIndex = find([planCells.id]==item.id,1);
                assert(~isempty(originalIndex),'Q4:OpticalAuditPrune','A removed cell id must originate in the plan.');
                original = planCells(originalIndex);
                expected = expectedCells(originalIndex);
                binding = item.channel==channel && item.failedSerial==visit.serial && isequal(item.failedPoint,visit.point) ...
                    && isequal(item.point,original.point) && isequal(item.polygon,original.polygon) ...
                    && ismember(originalIndex,remaining) && event.result=="no_target_in_range";
                audit.pruneBinding = audit.pruneBinding && binding;
                bound = max(hypot(original.polygon(:,1)-visit.point(1),original.polygon(:,2)-visit.point(2)));
                expectedBound = max(hypot(expected.polygon(:,1)-visit.point(1),expected.polygon(:,2)-visit.point(2)));
                audit.maximumPruneBound = max(audit.maximumPruneBound,max(bound,expectedBound));
                audit.pruneBounds = audit.pruneBounds && isnumeric(item.bound) && isreal(item.bound) ...
                    && isscalar(item.bound) && isfinite(item.bound) && abs(item.bound-bound)<=1e-10 ...
                    && bound<=20-1e-7+1e-10 && expectedBound<=20-1e-7+1e-9;
            end
            expectedSkipped(channel) = expectedSkipped(channel)+numel(removedCells)-1;
            remaining = remaining(~removedMask);
            audit.remainingTruth = audit.remainingTruth && q4OpticalAuditInCells(target,expectedCells,remaining);
        end
        if solution.complete
            audit.finiteProgress = audit.finiteProgress && succeeded;
        end
    end
    opticalEventMask = string({events.path})=="/clear" & string({events.phase})=="optical_fallback";
    audit.visitBinding = audit.visitBinding && all(usedVisits) && isequal(matchedEvents,opticalEventMask);
    audit.pruneBinding = audit.pruneBinding && all(usedPrunes);
    audit.skipCount = isequal(solution.opticalSkipped,expectedSkipped);
    audit.finiteProgress = audit.finiteProgress && isequal(solution.fallbackAttempts,attempts) && all(attempts<=152);
catch errorInfo
    audit.dataIntegrity = false;
    audit.failureIdentifier = string(errorInfo.identifier);
    audit.failureMessage = string(errorInfo.message);
end
audit.allPassed = audit.planBinding && audit.initialTruth && audit.continuousCover && audit.cellGeometry ...
    && audit.certificateFacts && audit.visitBinding && audit.queueOrder && audit.pruneBinding && audit.pruneBounds ...
    && audit.remainingTruth && audit.finiteProgress && audit.successSemantics && audit.skipCount ...
    && audit.legacyPrefix && audit.dataIntegrity;
end

function value = q4OpticalAuditPoint(point)
value = isnumeric(point) && isreal(point) && isequal(size(point),[1,2]) && all(isfinite(point));
end

function value = q4OpticalAuditPolygon(polygon)
value = isnumeric(polygon) && isreal(polygon) && ismatrix(polygon) && ~isempty(polygon) ...
    && size(polygon,2)==2 && all(isfinite(polygon),'all');
if ~value || size(polygon,1)<=2
    return
end
edges = polygon([2:end,1],:)-polygon;
signedArea = sum(polygon(:,1).*polygon([2:end,1],2)-polygon(:,2).*polygon([2:end,1],1));
orientation = sign(signedArea);
if orientation==0
    extent = max(vecnorm(polygon-polygon(1,:),2,2));
    value = all(abs(edges(:,1).*(polygon(:,2)-polygon(1,2))-edges(:,2).*(polygon(:,1)-polygon(1,1)))<=1e-8*max(1,extent));
    return
end
for index = 1:size(polygon,1)
    offsets = polygon-polygon(index,:);
    cross = edges(index,1)*offsets(:,2)-edges(index,2)*offsets(:,1);
    if any(orientation*cross<-1e-8*max(1,norm(edges(index,:))))
        value = false;
        return
    end
end
end

function cells = q4OpticalAuditCells(anchor,rotation,polygon)
limits = [min(polygon(:,1)),max(polygon(:,1)),min(polygon(:,2)),max(polygon(:,2))];
length = limits(2)-limits(1); height = limits(4)-limits(3);
best = inf; rows = 0; columns = 0;
for rowCount = 1:3
    halfHeight = height/(2*rowCount);
    if halfHeight>=19.4
        continue
    end
    columnCount = max(1,ceil(length/(2*sqrt(19.4^2-halfHeight^2))));
    if rowCount*columnCount<best
        rows = rowCount; columns = columnCount; best = rows*columns;
    end
end
assert(best<=152 && rows>0,'Q4:OpticalAuditCells','Invalid adaptive partition.');
cells = struct('id',{},'point',{},'polygon',{},'rectangle',{});
for column = 1:columns
    for row = 1:rows
        rectangle = [limits(1)+(column-1)*length/columns,limits(1)+column*length/columns, ...
            limits(3)+(row-1)*height/rows,limits(3)+row*height/rows];
        part = polygon;
        halfplanes = [1,0,rectangle(2);-1,0,-rectangle(1);0,1,rectangle(4);0,-1,-rectangle(3)];
        for side = 1:4
            part = q4OpticalAuditClip(part,halfplanes(side,1:2),halfplanes(side,3)+1e-8);
        end
        if ~isempty(part)
            point = anchor+[sum(rectangle(1:2))/2,sum(rectangle(3:4))/2]*rotation;
            cells(end+1) = struct('id',(column-1)*rows+row,'point',point,'polygon',anchor+part*rotation,'rectangle',rectangle);
        end
    end
end
end

function result = q4OpticalAuditClip(polygon,normal,bound)
result = zeros(0,2);
if isempty(polygon)
    return
end
values = polygon*normal'-bound;
for index = 1:size(polygon,1)
    prior = mod(index-2,size(polygon,1))+1;
    firstInside = values(prior)<=0;
    secondInside = values(index)<=0;
    if firstInside~=secondInside
        weight = values(prior)/(values(prior)-values(index));
        result(end+1,:) = (1-weight)*polygon(prior,:)+weight*polygon(index,:);
    end
    if secondInside
        result(end+1,:) = polygon(index,:);
    end
end
result = unique(result,'rows','stable');
end

function distance = q4OpticalAuditDistance(point,polygon)
if isempty(polygon)
    distance = Inf;
    return
end
if size(polygon,1)==1
    distance = norm(point-polygon);
    return
end
next = polygon([2:end,1],:);
edges = next-polygon;
weights = sum((point-polygon).*edges,2)./max(sum(edges.^2,2),realmin);
closest = polygon+max(0,min(1,weights)).*edges;
distance = min(hypot(closest(:,1)-point(1),closest(:,2)-point(2)));
if size(polygon,1)>=3
    [inside,on] = inpolygon(point(1),point(2),polygon(:,1),polygon(:,2));
    if inside || on
        distance = 0;
    end
end
end

function value = q4OpticalAuditSetEqual(first,second,tolerance)
value = true;
for index = 1:size(first,1)
    if q4OpticalAuditDistance(first(index,:),second)>tolerance
        value = false;
        return
    end
end
for index = 1:size(second,1)
    if q4OpticalAuditDistance(second(index,:),first)>tolerance
        value = false;
        return
    end
end
end

function value = q4OpticalAuditInCells(target,cells,indices)
value = false;
for index = indices
    if q4OpticalAuditDistance(target,cells(index).polygon)<=1e-7
        value = true;
        return
    end
end
end

function queue = q4OpticalAuditLegacy(anchor,rotation,polygon,position)
local = zeros(152,2);
for column = 0:75
    heights = [-13.5*(-1)^column,13.5*(-1)^column];
    for row = 1:2
        local(2*column+row,:) = [20*column,heights(row)];
    end
end
points = anchor+local*rotation;
keep = false(152,1);
for index = 1:152
    keep(index) = q4OpticalAuditLegacyDistance(points(index,:),polygon)<=20+1e-6;
end
queue = points(keep,:);
if ~isempty(queue) && norm(queue(end,:)-position)<norm(queue(1,:)-position)
    queue = flipud(queue);
end
end

function distance = q4OpticalAuditLegacyDistance(point,polygon)
if size(polygon,1)==1
    distance = norm(point-polygon);
    return
end
[inside,on] = inpolygon(point(1),point(2),polygon(:,1),polygon(:,2));
if inside || on
    distance = 0;
    return
end
edges = polygon([2:end,1],:)-polygon;
weights = sum((point-polygon).*edges,2)./max(sum(edges.^2,2),realmin);
nearest = polygon+max(0,min(1,weights)).*edges;
distance = min(vecnorm(nearest-point,2,2));
end


function checks = q4OpticalFlowChecks()
names = strings(0,1);
passed = false(0,1);
settings = struct('version',"0.4.0",'angleMargin',1.01,'clearMargin',19.5,'diskSides',72, ...
    'localLimit',6,'silenceLimit',2,'layout',"triangle",'seed',2026091204,'strategy',"safe", ...
    'optical',"legacy",'robotId','OFFLINE_OPTICAL_CHECK','requestPrefix','optical-flow');
[points,triangles,info] = q4Grid("triangle");
sources = [1,1700,0,1000,1,0,1];
policies = ["legacy","cells","nearest"];
solutions = cell(1,3);
worlds = cell(1,3);
audits = cell(1,3);
opticalAudits = cell(1,3);
facts = cell(1,3);
for policyIndex = 1:numel(policies)
    config = settings;
    config.optical = policies(policyIndex);
    config.requestPrefix = char("optical-flow-"+policies(policyIndex));
    [exchange,report] = q4World(sources);
    solutions{policyIndex} = q4Solve(exchange,config,points,triangles,info);
    worlds{policyIndex} = report();
    audits{policyIndex} = q4Audit(solutions{policyIndex},sources,worlds{policyIndex});
    opticalAudits{policyIndex} = q4OpticalAudit(solutions{policyIndex},sources);
    facts{policyIndex} = inspectFlow(solutions{policyIndex});
end
record("OpticalFlowThreePoliciesActuallyComplete",size(points,1)==37 && all(cellfun(@(item) item.complete,solutions)) ...
    && all(cellfun(@(item) all(item.cleared) && ~item.active,worlds)) ...
    && all(cellfun(@(item) sum(item.status==2)==1,solutions)));
record("OpticalFlowMainAndIndependentAuditsPass",all(cellfun(@(item) item.allPassed && item.opticalFeedback.allPassed,audits)) ...
    && all(cellfun(@(item) item.allPassed,opticalAudits)));
record("OpticalFlowAbsentChannelsHaveActualCoverage",all(cellfun(@(item) item.actualDrain,facts)) ...
    && all(cellfun(@(item) item.stopReason=="directional_coverage_and_all_discovered_cleared",solutions)));
record("OpticalFlowRecomputesExactFivePartCosts",all(cellfun(@(item) item.costsAgree,facts)));
record("OpticalFlowClearNeverRetunesReceiver",all(cellfun(@(item) item.receiverAgree,facts)));
record("OpticalFlowNoSignalPreservesRealOuterPolygon",all(cellfun(@(item) item.silencePreserved,facts)) ...
    && any(cellfun(@(item) item.localSilenceObserved,facts)));
record("OpticalFlowRespectsSixTwoAnd152Budgets",all(cellfun(@(item) item.finiteBudgets,facts)));
record("OpticalFlowDoesNotRepeatOpticalLocations",all(cellfun(@(item) item.uniqueVisits,facts)));
record("OpticalFlowFailedOwnerCellIsAlwaysRemoved",all(cellfun(@(item) item.failedOwnersRemoved,facts)) ...
    && sum(cellfun(@(item) item.ownerFailureCount,facts))>0);
record("OpticalFlowEveryPruneHasStrictVertexEvidence",all(cellfun(@(item) item.pruneBoundsAgree,facts)));
record("OpticalFlowActuallyUsesVerifiedQueuePolicies",all(cellfun(@(item) item.opticalVisited,facts)) ...
    && all(cellfun(@(item) item.queueOrder && item.visitBinding && item.finiteProgress,opticalAudits)) ...
    && all(arrayfun(@(index) all(string({solutions{index}.opticalPlans.mode})==policies(index)),1:3)));
fixture = solutions{2};
fixtureWorld = worlds{2};
fixtureSources = sources;
fixtureName = "single_cells";
if isempty(fixture.opticalPrunes)
    fixture = solutions{3};
    fixtureWorld = worlds{3};
    fixtureName = "single_nearest";
end
if isempty(fixture.opticalPrunes)
    scenes = q4Scenarios(2026091204);
    fixtureSources = scenes(4).sources;
    config = settings;
    config.optical = "cells";
    config.requestPrefix = 'optical-flow-fixed-case-04';
    [exchange,report] = q4World(fixtureSources);
    fixture = q4Solve(exchange,config,points,triangles,info);
    fixtureWorld = report();
    fixtureName = "fixed_case_04_cells";
    fprintf('Q4 OPTICAL FLOW: single-source runs had no prune records; added fixed scenario 4 with cells policy.\n');
end
fixtureAudit = q4Audit(fixture,fixtureSources,fixtureWorld);
fixtureAvailable = ~isempty(fixture.opticalPrunes) && any([fixture.opticalVisits.cellId]>0) ...
    && fixture.complete && all(fixtureWorld.cleared) && fixtureAudit.allPassed && fixtureAudit.opticalFeedback.allPassed;
record("OpticalFlowPruneFixtureAvailable_"+fixtureName,fixtureAvailable);
serialRejected = false;
pointRejected = false;
polygonRejected = false;
remainingRejected = false;
if fixtureAvailable
    forged = fixture;
    forged.opticalPrunes(1).failedSerial = max([fixture.events.serial])+100;
    serialRejected = auditRejects(forged,fixtureSources,fixtureWorld);
    forged = fixture;
    forged.opticalPrunes(1).failedPoint = forged.opticalPrunes(1).failedPoint+[100,0];
    pointRejected = auditRejects(forged,fixtureSources,fixtureWorld);
    forged = fixture;
    forged.opticalPrunes(1).polygon(end+1,:) = forged.opticalPrunes(1).failedPoint+[100,100];
    polygonRejected = auditRejects(forged,fixtureSources,fixtureWorld);
    forged = fixture;
    forgedVisitIndex = find([forged.opticalVisits.cellId]>0,1);
    forged.opticalVisits(forgedVisitIndex).remainingIds = [forged.opticalVisits(forgedVisitIndex).remainingIds,153];
    remainingRejected = auditRejects(forged,fixtureSources,fixtureWorld);
end
record("OpticalFlowAuditRejectsNonexistentFailureSerial",serialRejected);
record("OpticalFlowAuditRejectsForgedFailureCoordinates",pointRejected);
record("OpticalFlowAuditRejectsForgedRemovedPolygon",polygonRejected);
record("OpticalFlowAuditRejectsForgedRemainingIds",remainingRejected);
checks = table(names,passed,'VariableNames',{'Name','Passed'});

    function record(name,value)
        names(end+1,1) = string(name);
        passed(end+1,1) = islogical(value) && isscalar(value) && value;
    end

    function value = auditRejects(solution,sourceValues,world)
        value = false;
        try
            outcome = q4Audit(solution,sourceValues,world);
            separate = q4OpticalAudit(solution,sourceValues);
            value = ~outcome.allPassed && ~outcome.opticalFeedback.allPassed && ~separate.allPassed;
        catch
        end
    end

    function value = inspectFlow(solution)
        costs = zeros(1,5);
        position = [0,0];
        receiver = 1;
        time = 0;
        costsAgree = true;
        receiverAgree = true;
        actualSilent = false(size(solution.points,1),20);
        localCounts = zeros(1,20);
        streak = zeros(1,20);
        finiteBudgets = true;
        localSilenceObserved = false;
        opticalCounts = zeros(1,20);
        for eventIndex = 1:numel(solution.events)
            event = solution.events(eventIndex);
            increment = zeros(1,5);
            if ismember(event.path,["/measure","/clear"])
                destination = [event.x,event.y];
                increment(1) = hypot(destination(1)-position(1),destination(2)-position(2))/5;
                position = destination;
                if event.path=="/measure"
                    increment(2) = 5;
                    increment(3) = double(receiver~=event.channel);
                    receiver = event.channel;
                    if event.result=="no_signal"
                        matches = hypot(solution.points(:,1)-position(1),solution.points(:,2)-position(2))<=1e-6;
                        actualSilent(matches,event.channel) = true;
                    end
                    if event.phase=="local_measure"
                        finiteBudgets = finiteBudgets && streak(event.channel)<2 && localCounts(event.channel)<6;
                        localCounts(event.channel) = localCounts(event.channel)+1;
                        if event.result=="no_signal"
                            streak(event.channel) = streak(event.channel)+1;
                            localSilenceObserved = true;
                        else
                            streak(event.channel) = 0;
                        end
                    end
                elseif event.result=="success"
                    increment(4) = 5;
                else
                    increment(5) = 3;
                end
                if event.path=="/clear" && event.phase=="optical_fallback"
                    opticalCounts(event.channel) = opticalCounts(event.channel)+1;
                end
            end
            costs = costs+increment;
            time = time+sum(increment);
            costsAgree = costsAgree && abs(time-event.virtualTime)<=1e-7;
            receiverAgree = receiverAgree && receiver==event.receiver;
        end
        costsAgree = costsAgree && all(abs(costs-solution.costs)<=1e-7) && abs(sum(costs)-solution.virtualTime)<=1e-7;
        absent = find(solution.status==3);
        actualDrain = all(actualSilent(:,absent),'all') && all(solution.coverage(:,absent),'all') ...
            && all(solution.status==2 | solution.status==3);
        finiteBudgets = finiteBudgets && all(localCounts<=6) && all(opticalCounts<=152) ...
            && isequal(localCounts,solution.localMeasures) && isequal(opticalCounts,solution.fallbackAttempts) ...
            && numel(solution.events)<=solution.maximumActions;
        silencePreserved = true;
        for historyIndex = 1:numel(solution.history)
            item = solution.history(historyIndex);
            if item.kind=="no_signal"
                previous = find([solution.history(1:historyIndex-1).channel]==item.channel,1,'last');
                silencePreserved = silencePreserved && ~isempty(previous) && isequal(item.polygon,solution.history(previous).polygon);
            end
        end
        uniqueVisits = true;
        failedOwnersRemoved = true;
        ownerFailureCount = 0;
        for channelIndex = 1:20
            visits = solution.opticalVisits([solution.opticalVisits.channel]==channelIndex);
            if isempty(visits)
                continue
            end
            locations = vertcat(visits.point);
            uniqueVisits = uniqueVisits && size(unique(locations,'rows'),1)==size(locations,1) ...
                && numel(unique([visits.serial]))==numel(visits);
            ids = [visits.cellId];
            ids = ids(ids>0);
            uniqueVisits = uniqueVisits && numel(unique(ids))==numel(ids);
            for channelVisitIndex = 1:numel(visits)
                visit = visits(channelVisitIndex);
                event = solution.events([solution.events.serial]==visit.serial);
                uniqueVisits = uniqueVisits && numel(event)==1 && event.path=="/clear" ...
                    && event.channel==channelIndex && isequal([event.x,event.y],visit.point);
                if visit.cellId>0 && numel(event)==1 && event.result~="success"
                    ownerFailureCount = ownerFailureCount+1;
                    deleted = solution.opticalPrunes([solution.opticalPrunes.failedSerial]==visit.serial ...
                        & [solution.opticalPrunes.channel]==channelIndex);
                    failedOwnersRemoved = failedOwnersRemoved && any([deleted.id]==visit.cellId);
                end
            end
        end
        pruneBoundsAgree = true;
        for pruneIndex = 1:numel(solution.opticalPrunes)
            item = solution.opticalPrunes(pruneIndex);
            bound = max(hypot(item.polygon(:,1)-item.failedPoint(1),item.polygon(:,2)-item.failedPoint(2)));
            event = solution.events([solution.events.serial]==item.failedSerial);
            pruneBoundsAgree = pruneBoundsAgree && isfinite(bound) && bound<=20-1e-7 && abs(bound-item.bound)<=1e-8 ...
                && numel(event)==1 && event.path=="/clear" && event.result~="success" ...
                && event.channel==item.channel && isequal([event.x,event.y],item.failedPoint);
        end
        value = struct('costsAgree',costsAgree,'receiverAgree',receiverAgree,'actualDrain',actualDrain, ...
            'finiteBudgets',finiteBudgets,'silenceNonExpansion',silencePreserved,'localSilenceObserved',localSilenceObserved, ...
            'uniqueVisits',uniqueVisits,'failedOwnersRemoved',failedOwnersRemoved,'ownerFailureCount',ownerFailureCount, ...
            'pruneBoundsAgree',pruneBoundsAgree,'opticalVisited',~isempty(solution.opticalVisits));
    end
end


function output = q4OpticalStudy(path,settings,config)
assert(isfield(config,'baselinePath') && isfile(fullfile(config.baselinePath,'results.mat')),'Q4:OpticalStudyBaseline','Use the fixed previous safe-strategy baseline.');
assert(string(settings.layout)=="triangle",'Q4:OpticalStudyLayout','Item 3 retains the 37-station triangle layout.');
previous = load(fullfile(config.baselinePath,'results.mat'),'summary','scenarios');
assert(numel(previous.scenarios)==28 && isequaln(previous.scenarios,q4Scenarios(settings.seed)),'Q4:OpticalStudyScenarios','The fixed 28 scenarios must match the retained baseline.');
caseIndices = 1:numel(previous.scenarios);
if isfield(config,'caseIndices')
    caseIndices = config.caseIndices;
    assert(isnumeric(caseIndices) && isvector(caseIndices) && ~isempty(caseIndices) && all(isfinite(caseIndices)) && ...
        all(fix(caseIndices)==caseIndices) && all(caseIndices>=1 & caseIndices<=numel(previous.scenarios)) && ...
        numel(unique(caseIndices))==numel(caseIndices),'Q4:OpticalStudyCases','Case indices must be distinct valid fixed scenario indices.');
    caseIndices = reshape(caseIndices,1,[]);
end
scenarios = previous.scenarios(caseIndices);
strategies = ["legacy","cells","nearest"];
baselineRows = previous.summary(string(previous.summary.Strategy)=="safe",:);
assert(height(baselineRows)==28 && all(baselineRows.FullClearVerified),'Q4:OpticalStudyBaseline','The fixed safe-strategy baseline is incomplete.');
[points,triangles,info] = q4Grid("triangle");
assert(size(points,1)==37,'Q4:OpticalStudyLayout','The retained triangle layout must have exactly 37 stations.');
[coverageChecks,coverageEvidence] = q4CoverageChecks(points,triangles,info);
geometryPassed = all(coverageChecks.Passed) && coverageEvidence.continuousCoverageSupported;
assert(geometryPassed,'Q4:OpticalStudyCoverage','The retained layout lacks continuous directional coverage evidence.');
writetable(coverageChecks,fullfile(path,'coverage_checks.csv'),'Encoding','UTF-8');
q4WriteJson(fullfile(path,'coverage_evidence.json'),coverageEvidence);
assert(string(settings.strategy)=="safe",'Q4:OpticalStudyLocalStrategy','Item 3 retains the accepted safe local strategy.');
baselineMetadata = jsondecode(fileread(fullfile(config.baselinePath,'metadata.json')));
studyConfig = struct('strategies',strategies,'localStrategy',"safe",'baselineStrategy',"safe", ...
    'layout',"triangle",'stations',37,'seed',settings.seed, ...
    'caseIndices',caseIndices,'scenarioCount',numel(scenarios),'completeFixedSet',numel(scenarios)==28, ...
    'baselinePath',string(config.baselinePath),'baselineResultsSha256',q4FileHash(fullfile(config.baselinePath,'results.mat')), ...
    'baselineSummarySha256',q4FileHash(fullfile(config.baselinePath,'summary.csv')), ...
    'baselineMetadataSha256',q4FileHash(fullfile(config.baselinePath,'metadata.json')), ...
    'baselineSourceSha256',string(baselineMetadata.sourceSha256), ...
    'sourceSha256',q4FileHash([mfilename('fullpath') '.m']), ...
    'selectionPolicy',"REPORT_ALL_STRATEGIES_WITHOUT_AUTOMATIC_DEFAULT_CHANGE", ...
    'scope',"ITEM3_OPTICAL_FAILURE_FEEDBACK_AND_VISIT_ORDER_ONLY", ...
    'evidence',"SELF_CHECKED_CONSTRUCTED_CASES_NOT_HUMAN_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'study_config.json'),studyConfig);
save(fullfile(path,'study_config.mat'),'studyConfig','scenarios','settings','config','points','triangles','info');
references = cell(numel(scenarios),1);
for caseIndex = 1:numel(scenarios)
    scene = scenarios(caseIndex);
    referenceRow = baselineRows(string(baselineRows.Scenario)==string(scene.name),:);
    assert(height(referenceRow)==1,'Q4:OpticalStudyPair','Each scenario requires one fixed baseline row.');
    referencePath = fullfile(config.baselinePath,'safe',scene.name,'run.mat');
    assert(isfile(referencePath),'Q4:OpticalStudyBaseline','A fixed baseline run is missing.');
    referenceRun = load(referencePath,'solution','sources');
    assert(isequaln(referenceRun.sources,scene.sources) && referenceRun.solution.complete && ...
        abs(referenceRun.solution.virtualTime-referenceRow.VirtualTime_s)<=1e-7 && ...
        numel(referenceRun.solution.events)==referenceRow.Actions,'Q4:OpticalStudyBaseline','Fixed baseline run identity disagrees with its scenario or summary.');
    references{caseIndex} = struct('row',referenceRow,'run',referenceRun,'sha256',q4FileHash(referencePath));
end
details = cell(numel(strategies),numel(scenarios));
records = cell(0,1);
for variant = 1:numel(strategies)
    strategy = strategies(variant);
    for caseIndex = 1:numel(scenarios)
        scene = scenarios(caseIndex);
        reference = references{caseIndex};
        cfg = settings;
        cfg.layout = "triangle";
        cfg.strategy = "safe";
        cfg.optical = strategy;
        cfg.robotId = 'OFFLINE_Q4';
        cfg.requestPrefix = sprintf('optical-%s-%d',strategy,caseIndices(caseIndex));
        [exchange,report] = q4World(scene.sources);
        timer = tic;
        solution = q4Solve(exchange,cfg,points,triangles,info);
        wallTime = toc(timer);
        world = report();
        runPath = fullfile(path,char(strategy),scene.name);
        mkdir(runPath);
        q4SaveRun(runPath,solution,world,scene.sources,cfg);
        try
            audit = q4Audit(solution,scene.sources,world);
        catch auditError
            audit = struct('allPassed',false,'failureIdentifier',string(auditError.identifier),'failureMessage',string(auditError.message));
        end
        q4WriteJson(fullfile(runPath,'audit.json'),audit);
        [metrics,accounting,stopEvidence] = q4StudyMetrics(solution,world);
        q4WriteJson(fullfile(runPath,'stop_evidence.json'),stopEvidence);
        q4WriteJson(fullfile(runPath,'cost_metrics.json'),metrics);
        writetable(accounting,fullfile(runPath,'action_accounting.csv'),'Encoding','UTF-8');
        q4WriteJson(fullfile(runPath,'certificates.json'),solution.certificates);
        q4WriteJson(fullfile(runPath,'optical_plans.json'),solution.opticalPlans);
        q4WriteJson(fullfile(runPath,'optical_prunes.json'),solution.opticalPrunes);
        q4WriteJson(fullfile(runPath,'optical_visits.json'),solution.opticalVisits);
        opticalRows = accounting.Phase=="optical_fallback";
        opticalMove = sum(accounting.Move_s(opticalRows));
        opticalFailures = sum(accounting.FailedClear_s(opticalRows))/3;
        inputMatch = isequaln(reference.run.sources,scene.sources);
        baselineTimeMatch = strategy~="legacy" || abs(solution.virtualTime-reference.run.solution.virtualTime)<=1e-7;
        baselineActionMatch = strategy~="legacy" || isequaln(solution.events,reference.run.solution.events);
        baselineCostMatch = strategy~="legacy" || all(abs(solution.costs-reference.run.solution.costs)<=1e-7);
        fullClear = solution.complete && all(world.cleared) && audit.allPassed && geometryPassed && ...
            metrics.accountingPassed && stopEvidence.allPassed && inputMatch && baselineTimeMatch && baselineActionMatch && baselineCostMatch;
        delta = solution.virtualTime-reference.row.VirtualTime_s;
        records{end+1,1} = struct('Strategy',strategy,'Scenario',string(scene.name),'CaseIndex',caseIndices(caseIndex), ...
            'Group',string(scene.group),'SourceCount',size(scene.sources,1),'Cleared',sum(world.cleared), ...
            'FullClearVerified',fullClear,'GeometryCoverageValid',geometryPassed,'AuditPassed',audit.allPassed, ...
            'ActualStopEvidence',stopEvidence.allPassed,'AccountingPassed',metrics.accountingPassed, ...
            'BaselineInputMatch',inputMatch,'BaselineTimeMatch',baselineTimeMatch,'BaselineActionMatch',baselineActionMatch, ...
            'BaselineCostMatch',baselineCostMatch,'BaselineRunSha256',reference.sha256, ...
            'StopReason',string(solution.stopReason),'VirtualTime_s',solution.virtualTime, ...
            'BaselineTime_s',reference.row.VirtualTime_s,'DeltaTime_s',delta,'DeltaPercent',100*delta/reference.row.VirtualTime_s, ...
            'MeanClearTime_s',q4MeanTime(solution.virtualTime,sum(world.cleared)),'FirstClear_s',metrics.firstClearTime_s, ...
            'LastClear_s',metrics.lastClearTime_s,'AfterLastClear_s',metrics.afterLastClear_s, ...
            'Move_s',metrics.costs_s(1),'Measure_s',metrics.costs_s(2),'Switch_s',metrics.costs_s(3), ...
            'SuccessClear_s',metrics.costs_s(4),'FailedClear_s',metrics.costs_s(5), ...
            'TailMove_s',metrics.tailCosts_s(1),'TailMeasure_s',metrics.tailCosts_s(2),'TailSwitch_s',metrics.tailCosts_s(3), ...
            'TailSuccessClear_s',metrics.tailCosts_s(4),'TailFailedClear_s',metrics.tailCosts_s(5), ...
            'CoveragePhase_s',metrics.coveragePhase_s,'LocalMeasurePhase_s',metrics.localMeasurePhase_s, ...
            'OpticalPhase_s',metrics.opticalPhase_s,'CertifiedClearPhase_s',metrics.certifiedClearPhase_s, ...
            'Distance_m',metrics.costs_s(1)*5,'Measures',metrics.costs_s(2)/5,'Switches',metrics.costs_s(3), ...
            'FailedClears',metrics.costs_s(5)/3,'OpticalAttempts',sum(solution.fallbackAttempts), ...
            'OpticalSources',sum(solution.fallbackAttempts>0),'LocalMeasures',sum(solution.localMeasures), ...
            'OpticalSkipped',sum(solution.opticalSkipped),'OpticalMove_s',opticalMove,'OpticalDistance_m',5*opticalMove, ...
            'OpticalFailedClears',opticalFailures,'OpticalPlanCount',numel(solution.opticalPlans), ...
            'OpticalPruneEvents',numel(solution.opticalPrunes),'OpticalVisits',numel(solution.opticalVisits), ...
            'CertifiedClears',numel(solution.certificates), ...
            'CoverageMeasures',metrics.coverageMeasures,'VisitedStations',sum(solution.visited), ...
            'AbsentChannels',numel(stopEvidence.absentChannels),'FullyScannedAbsentChannels',stopEvidence.fullyScannedAbsentChannels, ...
            'Actions',numel(solution.events),'WallTime_s',wallTime,'TimeResidual_s',metrics.maximumTimeResidual_s, ...
            'Failure',string(solution.failure.identifier),'FailureMessage',string(solution.failure.message));
        details{variant,caseIndex} = solution;
        summary = struct2table(vertcat(records{:}));
        writetable(summary,fullfile(path,'summary.csv'),'Encoding','UTF-8');
        fprintf('Q4 ITEM3 %s %s: %d/%d T=%.6f delta=%+.6f opticalSources=%d passed=%d\n', ...
            strategy,scene.name,sum(world.cleared),size(scene.sources,1),solution.virtualTime,delta,sum(solution.fallbackAttempts>0),fullClear);
    end
end
summary = struct2table(vertcat(records{:}));
aggregate = q4OpticalAggregate(summary,strategies);
writetable(aggregate,fullfile(path,'aggregate.csv'),'Encoding','UTF-8');
slowCases = summary(summary.Strategy~="legacy" & summary.DeltaTime_s>1e-7,:);
writetable(slowCases,fullfile(path,'slow_cases.csv'),'Encoding','UTF-8');
for strategy = strategies(2:end)
    writetable(slowCases(slowCases.Strategy==strategy,:),fullfile(path,char(strategy+"_slow_cases.csv")),'Encoding','UTF-8');
end
failedCases = summary(~summary.FullClearVerified,:);
writetable(failedCases,fullfile(path,'failed_cases.csv'),'Encoding','UTF-8');
save(fullfile(path,'results.mat'),'summary','aggregate','slowCases','failedCases','details','scenarios','settings', ...
    'config','studyConfig','points','triangles','info','coverageEvidence','-v7.3');
output = struct('path',path,'runs',height(summary),'fullClearVerified',sum(summary.FullClearVerified), ...
    'allPassed',all(summary.FullClearVerified),'scenarioIdentityMatch',all(summary.BaselineInputMatch), ...
    'baselineTimeMatch',all(summary.BaselineTimeMatch),'baselineActionMatch',all(summary.BaselineActionMatch), ...
    'baselineCostMatch',all(summary.BaselineCostMatch),'caseIndices',caseIndices,'completeFixedSet',numel(scenarios)==28, ...
    'slowCaseCount',height(slowCases),'failedCaseCount',height(failedCases),'strategies',strategies, ...
    'layout',"triangle",'localStrategy',"safe",'defaultChanged',false,'sourceSha256',studyConfig.sourceSha256, ...
    'baselineResultsSha256',studyConfig.baselineResultsSha256, ...
    'evidence',"SELF_CHECKED_CONSTRUCTED_CASES_NOT_HUMAN_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'summary.json'),output);
q4OpticalFigures(path,summary,aggregate,strategies);
assert(output.allPassed,'Q4:OpticalStudyFailure','An optical strategy study run failed; all produced evidence has been retained.');
end

function aggregate = q4OpticalAggregate(summary,strategies)
baseAll = summary(summary.Strategy=="legacy",:);
groups = ["all_"+string(height(baseAll)),"boundary_"+string(sum(baseAll.Group=="constructed_boundary")), ...
    "random_"+string(sum(baseAll.Group=="constructed_random")),"source_count_16","source_count_below_16"];
records = cell(0,1);
for groupIndex = 1:numel(groups)
    if groupIndex==2
        mask = summary.Group=="constructed_boundary";
    elseif groupIndex==3
        mask = summary.Group=="constructed_random";
    elseif groupIndex==4
        mask = summary.SourceCount==16;
    elseif groupIndex==5
        mask = summary.SourceCount<16;
    else
        mask = true(height(summary),1);
    end
    base = summary(mask & summary.Strategy=="legacy",:);
    for strategy = strategies
        selected = summary(mask & summary.Strategy==strategy,:);
        assert(height(selected)==height(base) && all(selected.Scenario==base.Scenario),'Q4:OpticalStudyAggregate','Paired groups must have matching scenarios.');
        worstDelta = NaN;
        worstPercent = NaN;
        if ~isempty(selected)
            worstDelta = max(selected.DeltaTime_s);
            worstPercent = max(selected.DeltaPercent);
        end
        records{end+1,1} = struct('Group',groups(groupIndex),'Strategy',strategy,'Scenarios',height(selected), ...
            'Verified',sum(selected.FullClearVerified),'MeanTime_s',mean(selected.VirtualTime_s), ...
            'BaselineMeanTime_s',mean(base.VirtualTime_s),'MeanDeltaTime_s',mean(selected.DeltaTime_s), ...
            'MeanTimeChangePercent',100*(mean(selected.VirtualTime_s)/mean(base.VirtualTime_s)-1), ...
            'Faster',sum(selected.DeltaTime_s < -1e-7),'Slower',sum(selected.DeltaTime_s>1e-7), ...
            'Equal',sum(abs(selected.DeltaTime_s)<=1e-7),'WorstDeltaTime_s',worstDelta,'WorstDeltaPercent',worstPercent, ...
            'MeanTail_s',mean(selected.AfterLastClear_s),'MeanTailDelta_s',mean(selected.AfterLastClear_s-base.AfterLastClear_s), ...
            'MeanCoveragePhase_s',mean(selected.CoveragePhase_s),'MeanLocalMeasurePhase_s',mean(selected.LocalMeasurePhase_s), ...
            'MeanOpticalPhase_s',mean(selected.OpticalPhase_s),'MeanCertifiedClearPhase_s',mean(selected.CertifiedClearPhase_s), ...
            'MeanMove_s',mean(selected.Move_s),'MeanMeasure_s',mean(selected.Measure_s),'MeanSwitch_s',mean(selected.Switch_s), ...
            'MeanSuccessClear_s',mean(selected.SuccessClear_s),'MeanFailedClear_s',mean(selected.FailedClear_s), ...
            'MeanTailMove_s',mean(selected.TailMove_s),'MeanTailMeasure_s',mean(selected.TailMeasure_s), ...
            'MeanTailSwitch_s',mean(selected.TailSwitch_s),'MeanTailSuccessClear_s',mean(selected.TailSuccessClear_s), ...
            'MeanTailFailedClear_s',mean(selected.TailFailedClear_s),'MeanOpticalAttempts',mean(selected.OpticalAttempts), ...
            'MeanOpticalSources',mean(selected.OpticalSources),'MeanLocalMeasures',mean(selected.LocalMeasures), ...
            'MeanOpticalSkipped',mean(selected.OpticalSkipped),'MeanOpticalMove_s',mean(selected.OpticalMove_s), ...
            'MeanOpticalDistance_m',mean(selected.OpticalDistance_m), ...
            'MeanOpticalDistanceDelta_m',mean(selected.OpticalDistance_m-base.OpticalDistance_m), ...
            'MeanFailedClears',mean(selected.FailedClears),'MeanOpticalFailedClears',mean(selected.OpticalFailedClears), ...
            'MeanFailedClearsDelta',mean(selected.FailedClears-base.FailedClears),'MeanWallTime_s',mean(selected.WallTime_s));
    end
end
aggregate = struct2table(vertcat(records{:}));
end

function q4OpticalFigures(path,summary,aggregate,strategies)
figurePath = fullfile(path,'figures');
mkdir(figurePath);
fontName = 'Microsoft YaHei';
labels = {'旧光学队列','失败反馈删格','失败反馈删格与就近访问'};
base = summary(summary.Strategy=="legacy",:);
caseCount = height(base);
caseLabels = compose('%02d / %d',base.CaseIndex,base.SourceCount);
firstFigure = figure('Visible','off','Color','white','Position',[100,100,1500,900]);
firstCleanup = onCleanup(@() close(firstFigure));
firstLayout = tiledlayout(firstFigure,2,1,'Padding','compact','TileSpacing','compact');
for variant = 2:numel(strategies)
    rows = summary(summary.Strategy==strategies(variant),:);
    assert(height(rows)==caseCount && all(rows.Scenario==base.Scenario),'Q4:OpticalFigurePair','Every plotted comparison must use matched cases.');
    axisHandle = nexttile(firstLayout);
    bars = bar(axisHandle,1:caseCount,rows.DeltaPercent,0.68,'FaceColor','flat','EdgeColor',[0.15,0.15,0.15],'LineWidth',0.5);
    colors = repmat([0.72,0.78,0.83],caseCount,1);
    slow = rows.DeltaTime_s>1e-7;
    colors(slow,:) = repmat([0.62,0.22,0.19],sum(slow),1);
    bars.CData = colors;
    hold(axisHandle,'on');
    yline(axisHandle,0,'k-','LineWidth',1.0);
    q4StyleAxes(axisHandle,fontName);
    xlim(axisHandle,[0.4,caseCount+0.6]);
    xticks(axisHandle,1:caseCount);
    xticklabels(axisHandle,cellstr(caseLabels));
    xtickangle(axisHandle,40);
    spread = max(1,max(abs(rows.DeltaPercent)));
    ylim(axisHandle,[min(0,min(rows.DeltaPercent))-0.10*spread,max(0,max(rows.DeltaPercent))+0.20*spread]);
    for rowIndex = find(slow)'
        text(axisHandle,rowIndex,rows.DeltaPercent(rowIndex)+0.025*spread,sprintf('+%.2f',rows.DeltaPercent(rowIndex)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontName',fontName,'FontSize',9,'Color',[0.40,0.10,0.08]);
    end
    xlabel(axisHandle,'固定案例编号 / 源数','FontName',fontName);
    ylabel(axisHandle,'完整T相对旧光学队列变化 / %','FontName',fontName);
    title(axisHandle,sprintf('%s：%d快、%d慢、%d相同；全部慢例均标数',labels{variant}, ...
        sum(rows.DeltaTime_s < -1e-7),sum(slow),sum(abs(rows.DeltaTime_s)<=1e-7)), ...
        'FontName',fontName,'FontSize',13,'FontWeight','normal');
end
title(firstLayout,sprintf('第3项：固定37站、同一组%d场的完整耗时比较',caseCount),'FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(firstLayout,'零线上方为变慢；深色柱逐场标注；有限构造案例不代表官方分布或全局最优', ...
    'FontName',fontName,'FontSize',11);
set(findall(firstFigure,'-property','FontName'),'FontName',fontName);
set(firstFigure,'Renderer','painters','InvertHardcopy','off');
drawnow;
exportgraphics(firstFigure,fullfile(figurePath,'figure01_all_paired_cases.png'),'Resolution',240,'BackgroundColor','white');
savefig(firstFigure,fullfile(figurePath,'figure01_all_paired_cases.fig'));
clear firstCleanup
secondFigure = figure('Visible','off','Color','white','Position',[100,100,1500,900]);
secondCleanup = onCleanup(@() close(secondFigure));
secondLayout = tiledlayout(secondFigure,2,2,'Padding','compact','TileSpacing','compact');
allRows = aggregate(aggregate.Group=="all_"+string(caseCount),:);
assert(height(allRows)==numel(strategies) && all(allRows.Strategy==strategies'),'Q4:OpticalFigureAggregate','Aggregate strategy order must match the comparison.');
costs = allRows{:,{'MeanMove_s','MeanMeasure_s','MeanSwitch_s','MeanSuccessClear_s','MeanFailedClear_s'}};
costColors = [0.20,0.40,0.62;0.41,0.63,0.71;0.91,0.67,0.29;0.47,0.61,0.42;0.70,0.39,0.40];
shortLabels = {'旧队列','失败反馈删格','删格与就近访问'};
costAxes = nexttile(secondLayout);
costHandles = bar(costAxes,1:3,costs,'stacked','BarWidth',0.65);
for component = 1:5
    set(costHandles(component),'FaceColor',costColors(component,:),'EdgeColor',[0.25,0.25,0.25],'LineWidth',0.45);
end
q4StyleAxes(costAxes,fontName);
xticks(costAxes,1:3);
xticklabels(costAxes,shortLabels);
ylabel(costAxes,'每场平均虚拟时间 / s','FontName',fontName);
title(costAxes,'（a）完整任务的五项费用','FontName',fontName,'FontSize',13,'FontWeight','normal');
ylim(costAxes,[0,max(1,max(sum(costs,2)))*1.16]);
for variant = 1:numel(strategies)
    text(costAxes,variant,sum(costs(variant,:))+max(1,max(sum(costs,2)))*0.025,sprintf('%.1f s',sum(costs(variant,:))), ...
        'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
end
panelValues = [allRows.MeanOpticalDistance_m,allRows.MeanOpticalFailedClears,allRows.MeanOpticalSources];
panelTitles = {'（b）光学阶段移动路程（含进入转场）','（c）光学清除失败次数','（d）转入光学退路的源数'};
panelUnits = {'每场平均路程 / m','每场平均失败次数','每场平均源数'};
for panelIndex = 1:3
    axisHandle = nexttile(secondLayout);
    values = panelValues(:,panelIndex);
    bar(axisHandle,1:3,values,0.65,'FaceColor',[0.48,0.54,0.60],'EdgeColor',[0.20,0.20,0.20]);
    q4StyleAxes(axisHandle,fontName);
    xticks(axisHandle,1:3);
    xticklabels(axisHandle,shortLabels);
    ylabel(axisHandle,panelUnits{panelIndex},'FontName',fontName);
    title(axisHandle,panelTitles{panelIndex},'FontName',fontName,'FontSize',13,'FontWeight','normal');
    valueScale = max(1,max(values));
    ylim(axisHandle,[0,1.18*valueScale]);
    for variant = 1:numel(strategies)
        text(axisHandle,variant,values(variant)+valueScale*0.03,sprintf('%.2f',values(variant)), ...
            'HorizontalAlignment','center','FontName',fontName,'FontSize',10);
    end
end
costLegend = legend(costAxes,costHandles,{'移动','检测','切频','成功清除','失败清除'}, ...
    'NumColumns',5,'Orientation','horizontal','FontName',fontName,'FontSize',11,'Box','off');
costLegend.Layout.Tile = 'south';
title(secondLayout,sprintf('第3项：%d场完整费用与光学试探统计',caseCount),'FontName',fontName,'FontSize',17,'FontWeight','normal');
subtitle(secondLayout,'37站、原局部补测与最近安全清除保持不变；尾程已计入完整T；SELF_CHECKED，未作人工终审或正式测试', ...
    'FontName',fontName,'FontSize',11);
set(findall(secondFigure,'-property','FontName'),'FontName',fontName);
set(secondFigure,'Renderer','painters','InvertHardcopy','off');
drawnow;
exportgraphics(secondFigure,fullfile(figurePath,'figure02_full_costs_and_optical.png'),'Resolution',240,'BackgroundColor','white');
savefig(secondFigure,fullfile(figurePath,'figure02_full_costs_and_optical.fig'));
clear secondCleanup
end

function output = q4IterationStudy(path,settings,config)
assert(isfield(config,'scenarioFile') && isfile(config.scenarioFile),'Q4:IterationScenarios','A frozen scenario file is required.');
data = load(config.scenarioFile,'scenarios');
scenarios = data.scenarios;
if isfield(config,'caseIndices')
    indices = config.caseIndices;
    assert(isnumeric(indices) && isvector(indices) && ~isempty(indices) && all(isfinite(indices)) && ...
        all(indices==fix(indices)) && all(indices>=1 & indices<=numel(scenarios)) && numel(unique(indices))==numel(indices),'Q4:IterationIndices','Invalid case indices.');
    scenarios = scenarios(indices);
end
hasReference = isfield(config,'referencePath') && strlength(string(config.referencePath))>0;
[points,triangles,info] = q4Grid(settings.layout);
manifest = struct('settings',settings,'config',config,'scenarioFileSha256',q4FileHash(config.scenarioFile), ...
    'sourceSha256',q4FileHash([mfilename('fullpath') '.m']),'scenarioCount',numel(scenarios), ...
    'comparison',"PAIRED_IDENTICAL_CONSTRUCTED_SOURCES",'evidence',"SELF_CHECKED_NOT_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'study_manifest.json'),manifest);
save(fullfile(path,'study_config.mat'),'scenarios','settings','config','manifest');
records = cell(0,1);
for caseIndex = 1:numel(scenarios)
    scene = scenarios(caseIndex);
    referenceTime = NaN;
    referenceHash = "";
    if hasReference
        referenceFile = fullfile(config.referencePath,scene.name,'run.mat');
        ref = load(referenceFile,'solution','sources');
        assert(isequaln(ref.sources,scene.sources) && ref.solution.complete,'Q4:IterationPair','The reference must be complete and use identical sources.');
        referenceTime = ref.solution.virtualTime;
        referenceHash = q4FileHash(referenceFile);
        clear ref
    end
    cfg = settings;
    cfg.robotId = 'OFFLINE_Q4';
    cfg.requestPrefix = sprintf('iteration-%d',caseIndex);
    [exchange,report] = q4World(scene.sources);
    timer = tic;
    solution = q4Solve(exchange,cfg,points,triangles,info);
    wallTime = toc(timer);
    world = report();
    runPath = fullfile(path,scene.name);
    mkdir(runPath);
    q4SaveRun(runPath,solution,world,scene.sources,cfg);
    try
        audit = q4Audit(solution,scene.sources,world);
    catch auditError
        audit = struct('allPassed',false,'failureIdentifier',string(auditError.identifier),'failureMessage',string(auditError.message));
    end
    q4WriteJson(fullfile(runPath,'audit.json'),audit);
    [metrics,accounting,stopEvidence] = q4StudyMetrics(solution,world);
    q4WriteJson(fullfile(runPath,'stop_evidence.json'),stopEvidence);
    q4WriteJson(fullfile(runPath,'cost_metrics.json'),metrics);
    q4WriteJson(fullfile(runPath,'certificates.json'),solution.certificates);
    writetable(accounting,fullfile(runPath,'action_accounting.csv'),'Encoding','UTF-8');
    opportunityAudit = q4OpportunityAudit(solution);
    q4WriteJson(fullfile(runPath,'opportunity_audit.json'),opportunityAudit);
    q4WriteJson(fullfile(runPath,'service_decisions.json'),solution.serviceDecisions);
    passed = solution.complete && all(world.cleared) && audit.allPassed && metrics.accountingPassed && stopEvidence.allPassed && opportunityAudit.allPassed;
    delta = solution.virtualTime-referenceTime;
    records{end+1,1} = struct('Scenario',string(scene.name),'Group',string(scene.group),'SourceCount',size(scene.sources,1), ...
        'Layout',string(settings.layout),'Optical',string(settings.optical),'Strategy',string(settings.strategy), ...
        'Cleared',sum(world.cleared),'FullClearVerified',passed,'AuditPassed',audit.allPassed, ...
        'ActualStopEvidence',stopEvidence.allPassed,'AccountingPassed',metrics.accountingPassed, ...
        'StopReason',string(solution.stopReason),'VirtualTime_s',solution.virtualTime,'BaselineTime_s',referenceTime, ...
        'DeltaTime_s',delta,'DeltaPercent',100*delta/referenceTime,'MeanClearTime_s',solution.virtualTime/sum(world.cleared), ...
        'AfterLastClear_s',metrics.afterLastClear_s,'Move_s',metrics.costs_s(1),'Measure_s',metrics.costs_s(2), ...
        'Switch_s',metrics.costs_s(3),'SuccessClear_s',metrics.costs_s(4),'FailedClear_s',metrics.costs_s(5), ...
        'CoveragePhase_s',metrics.coveragePhase_s,'LocalMeasurePhase_s',metrics.localMeasurePhase_s, ...
        'OpticalPhase_s',metrics.opticalPhase_s,'CertifiedClearPhase_s',metrics.certifiedClearPhase_s, ...
        'CoverageMeasures',metrics.coverageMeasures,'VisitedStations',sum(solution.visited), ...
        'OpticalSources',sum(solution.fallbackAttempts>0),'OpticalAttempts',sum(solution.fallbackAttempts), ...
        'LocalMeasures',sum(solution.localMeasures),'FailedClears',metrics.costs_s(5)/3, ...
        'Actions',numel(solution.events),'WallTime_s',wallTime,'TimeResidual_s',metrics.maximumTimeResidual_s, ...
        'ReferenceRunSha256',referenceHash,'Failure',string(solution.failure.identifier),'FailureMessage',string(solution.failure.message));
    summary = struct2table(vertcat(records{:}));
    writetable(summary,fullfile(path,'summary.csv'),'Encoding','UTF-8');
    fprintf('Q4 ITERATION %s %s %s: %d/%d T=%.6f delta=%+.6f passed=%d\n', ...
        settings.layout,settings.optical,scene.name,sum(world.cleared),size(scene.sources,1),solution.virtualTime,delta,passed);
end
slowCases = summary(summary.DeltaTime_s>1e-7,:);
failedCases = summary(~summary.FullClearVerified,:);
writetable(slowCases,fullfile(path,'slow_cases.csv'),'Encoding','UTF-8');
writetable(failedCases,fullfile(path,'failed_cases.csv'),'Encoding','UTF-8');
save(fullfile(path,'results.mat'),'summary','slowCases','failedCases','scenarios','settings','config','manifest');
output = struct('path',path,'runs',height(summary),'fullClearVerified',sum(summary.FullClearVerified), ...
    'allPassed',all(summary.FullClearVerified),'meanTime_s',mean(summary.VirtualTime_s),'maxTime_s',max(summary.VirtualTime_s), ...
    'mean16_s',mean(summary.VirtualTime_s(summary.SourceCount==16)), ...
    'meanChangePercent',100*(mean(summary.VirtualTime_s)/mean(summary.BaselineTime_s)-1), ...
    'worstChangePercent',max(summary.DeltaPercent),'slowCases',height(slowCases), ...
    'evidence',"SELF_CHECKED_CONSTRUCTED_CASES_NOT_AUDITED_NOT_FORMAL");
q4WriteJson(fullfile(path,'summary.json'),output);
assert(output.allPassed,'Q4:IterationFailure','A run failed; all results have been retained.');
end

function eligible = q4OpportunityEligible(track,position,usedMeasures,usedOpportunity,settings)
eligible = false;
if usedOpportunity || usedMeasures>=settings.localLimit || track.near || ...
        any(vecnorm(track.seen-position,2,2)<=1e-6) || q4DistancePolygon(position,track.polygon)>1500+1e-7
    return
end
[~,radius] = q4Circle(track.polygon);
eligible = radius>settings.clearMargin;
end

function audit = q4OpportunityAudit(solution)
rows = find(string({solution.events.phase})=="opportunistic_measure");
counts = zeros(1,20);
stationary = true;
for index = rows
    event = solution.events(index);
    previous = solution.events(index-1);
    counts(event.channel) = counts(event.channel)+1;
    stationary = stationary && event.path=="/measure" && isequal([event.x,event.y],[previous.x,previous.y]);
end
measures = zeros(1,20);
for event = solution.events
    if ismember(event.phase,["local_measure","opportunistic_measure"])
        measures(event.channel) = measures(event.channel)+1;
    end
end
audit = struct('opportunisticActions',numel(rows),'stationary',stationary,'atMostOnePerChannel',all(counts<=1), ...
    'withinOriginalBudget',all(measures<=6),'countMatches',isequal(measures,solution.localMeasures));
audit.allPassed = audit.stationary && audit.atMostOnePerChannel && audit.withinOriginalBudget && audit.countMatches;
end

function checks = q4OpportunityChecks()
settings = struct('clearMargin',19.5,'localLimit',6);
track = struct('polygon',[90,-20;190,-20;190,20;90,20],'near',false,'seen',[0,0]);
names = "one_stationary_measurement_is_eligible";
values = q4OpportunityEligible(track,[200,50],0,false,settings);
names(end+1,1) = "repeated_location_is_not_eligible";
values(end+1,1) = ~q4OpportunityEligible(track,[0,0],0,false,settings);
names(end+1,1) = "six_measurement_budget_is_shared";
values(end+1,1) = ~q4OpportunityEligible(track,[200,50],6,false,settings);
names(end+1,1) = "second_opportunity_is_forbidden";
values(end+1,1) = ~q4OpportunityEligible(track,[200,50],1,true,settings);
names(end+1,1) = "impossible_reception_has_no_extra_measurement";
values(end+1,1) = ~q4OpportunityEligible(track,[2000,0],0,false,settings);
track.near = true;
names(end+1,1) = "near_source_needs_no_extra_measurement";
values(end+1,1) = ~q4OpportunityEligible(track,[200,50],0,false,settings);
track.near = false;
track.polygon = [97,-3;103,-3;103,3;97,3];
names(end+1,1) = "certifiable_source_needs_no_extra_measurement";
values(end+1,1) = ~q4OpportunityEligible(track,[200,50],0,false,settings);
checks = table(names,values,'VariableNames',{'Name','Passed'});
end

function station = q4NearestStation(position,points,visited)
remaining = find(~visited);
assert(~isempty(remaining),'Q4:NoUnvisitedStation','A coverage decision requires an unvisited station.');
[~,index] = min(vecnorm(points(remaining,:)-position,2,2));
station = remaining(index);
end

function checks = q4CoverageOrderChecks()
points = [0,0;3,0;6,0;3,4];
names = "nearest_selection_excludes_visited_station";
values = q4NearestStation([0,0],points,[true;false;false;false])==2;
names(end+1,1) = "nearest_tie_is_deterministic";
values(end+1,1) = q4NearestStation([3,0],points,[false;true;false;false])==1;
visited = false(4,1);
position = [0,0];
for index = 1:4
    station = q4NearestStation(position,points,visited);
    assert(~visited(station),'Q4:CoverageRepeat','Repeated coverage station.');
    visited(station) = true;
    position = points(station,:);
end
names(end+1,1) = "finite_nearest_route_visits_every_station_once";
values(end+1,1) = all(visited);
rejected = false;
try
    q4NearestStation(position,points,visited);
catch errorInfo
    rejected = string(errorInfo.identifier)=="Q4:NoUnvisitedStation";
end
names(end+1,1) = "empty_remaining_set_is_rejected";
values(end+1,1) = rejected;
checks = table(names,values,'VariableNames',{'Name','Passed'});
end

function evidence = q4TailCoverage(points)
evidence = struct('passed',false,'points',points,'triangles',zeros(0,3),'minimumBoundary_m',NaN,'maximumEdge_m',NaN);
if ~isnumeric(points) || size(points,2)~=2 || any(~isfinite(points),'all') || size(points,1)<3
    return
end

points = unique(points,'rows');
if size(points,1)<3 || rank(points-mean(points,1))<2
    return
end
mesh = delaunayTriangulation(points);
triangles = mesh.ConnectivityList;
lengths = [vecnorm(points(triangles(:,1),:)-points(triangles(:,2),:),2,2), ...
    vecnorm(points(triangles(:,2),:)-points(triangles(:,3),:),2,2), ...
    vecnorm(points(triangles(:,3),:)-points(triangles(:,1),:),2,2)];
triangles = triangles(max(lengths,[],2)<1000-1e-5,:);
if isempty(triangles)
    return
end
edges = sort([triangles(:,[1,2]);triangles(:,[2,3]);triangles(:,[3,1])],2);
[uniqueEdges,~,indices] = unique(edges,'rows');
counts = accumarray(indices,1);
boundary = uniqueEdges(counts==1,:);
start = points(boundary(:,1),:);
vectors = points(boundary(:,2),:)-start;
fraction = min(1,max(0,-sum(start.*vectors,2)./sum(vectors.^2,2)));
distances = vecnorm(start+fraction.*vectors,2,2);
originContained = false;
for k = 1:size(triangles,1)
    vertices = points(triangles(k,:),:);
    coordinates = [vertices';ones(1,3)]\[0;0;1];
    originContained = originContained || all(coordinates>=-1e-12);
end
vertexCoverage = true;
for k = find(vecnorm(points,2,2)<=1800+1e-5)'
    offsets = points-points(k,:);
    near = vecnorm(offsets,2,2)>1e-5 & vecnorm(offsets,2,2)<1000-1e-5;
    angles = sort(atan2(offsets(near,2),offsets(near,1)));
    if isempty(angles) || max(diff([angles;angles(1)+2*pi]))>pi+1e-12
        vertexCoverage = false;
    end
end
evidence = struct('passed',originContained && all(distances>=1800-1e-7) && vertexCoverage && all(counts<=2), ...
    'points',points,'triangles',triangles,'minimumBoundary_m',min(distances), ...
    'maximumEdge_m',max(vecnorm(points(uniqueEdges(:,1),:)-points(uniqueEdges(:,2),:),2,2)));
end


function plan = q4TailPlan(position,points,visited,unknownCount)
required = true(size(points,1),1);
remaining = find(~visited);
[~,initialTravel] = q4OpenRoute(position,points(remaining,:));
travel = initialTravel;
cost = travel/5+6*unknownCount*numel(remaining);
initialCost = cost;
while true
    best = 0;
    bestCost = cost-1e-6;
    bestTravel = travel;
    for index = find(required & ~visited)'
        candidate = required;
        candidate(index) = false;
        certificate = q4TailCoverage(points(candidate,:));
        if ~certificate.passed
            continue
        end
        next = find(candidate & ~visited);
        [~,candidateTravel] = q4OpenRoute(position,points(next,:));
        candidateCost = candidateTravel/5+6*unknownCount*numel(next);
        if candidateCost<bestCost
            best = index;
            bestCost = candidateCost;
            bestTravel = candidateTravel;
        end
    end
    if best==0
        break
    end
    required(best) = false;
    cost = bestCost;
    travel = bestTravel;
end
plan = struct('applied',any(~required),'serialBefore',0,'requiredStations',required, ...
    'removedStations',find(~required),'position',position,'visitedBefore',visited,'unknownCount',unknownCount, ...
    'initialTailEstimate_s',initialCost,'finalTailEstimate_s',cost,'estimatedSaving_s',initialCost-cost, ...
    'certificate',q4TailCoverage(points(required,:)),'actualStopRequiresMeasurements',true);
end

function audit = q4TailAudit(solution)
audit = struct('allPassed',false,'geometry',false,'actualNoSignals',false,'planBinding',false,'statusComplete',false);
if ~isfield(solution,'tailPlan') || ~isfield(solution,'requiredStations') || ~solution.tailPlan.applied
    return
end
required = solution.requiredStations;
if ~islogical(required) || ~isequal(size(required),[size(solution.points,1),1]) || ~any(required)
    return
end
certificate = q4TailCoverage(solution.points(required,:));
absent = find(solution.status==3);
actual = false(size(solution.coverage));
events = solution.events;
for k = 1:numel(events)
    e = events(k);
    if e.path=="/measure" && e.result=="no_signal"
        rows = vecnorm(solution.points-[e.x,e.y],2,2)<=1e-7;
        actual(rows,e.channel) = true;
    end
end
plan = solution.tailPlan;
validSerial = isscalar(plan.serialBefore) && plan.serialBefore>=1 && plan.serialBefore<=numel(events) && plan.serialBefore==fix(plan.serialBefore);
binding = false;
if validSerial && isfield(plan,'visitedBefore') && isequal(size(plan.visitedBefore),size(required)) && islogical(plan.visitedBefore)
    prior = events(1:plan.serialBefore);
    successful = prior(string({prior.path})=="/clear" & string({prior.result})=="success");
    count = numel(unique([successful.channel]));
    minimum = 10;
    if isfield(plan,'minimumClears')
        minimum = plan.minimumClears;
    end
    binding = ismember(minimum,[10,15]) && count>=minimum && count<16 && isequal(required,plan.requiredStations) && ...
        isequal(find(~required),plan.removedStations) && ~any(plan.visitedBefore & ~required) && ...
        isfield(plan,'certificate') && isequal(plan.certificate.points,unique(solution.points(required,:),'rows'));
end
if binding && isfield(plan,'selection') && plan.selection=="ordered_tail"
    prior = events(1:plan.serialBefore);
    lastCoverage = find(string({prior.phase})=="coverage",1,'last');
    station = plan.silentStation;
    binding = isscalar(station) && station>=1 && station<=size(solution.points,1) && ...
        station==fix(station) && ~isempty(lastCoverage);
    if binding
        endEvent = prior(lastCoverage);
        sameStation = vecnorm(solution.points-[endEvent.x,endEvent.y],2,2)<=1e-7;
        group = string({prior.phase})=="coverage" & hypot([prior.x]-endEvent.x,[prior.y]-endEvent.y)<=1e-7;
        binding = sameStation(station) && all(string({prior(group).result})=="no_signal") && ...
            isequal(sort(plan.route(:)),find(required & ~plan.visitedBefore)) && ...
            isequal(plan.route(:),reshape(plan.initialRoute(ismember(plan.initialRoute,plan.route)),[],1));
    end
end
audit = struct('allPassed',false,'geometry',certificate.passed,'actualNoSignals',all(actual(required,absent),'all'), ...
    'planBinding',binding,'statusComplete',all(solution.status==2 | solution.status==3),'absentChannels',absent, ...
    'requiredStations',find(required),'removedStations',find(~required),'certificate',certificate);
audit.allPassed = audit.geometry && audit.actualNoSignals && audit.planBinding && audit.statusComplete && ~isempty(absent);
end

function checks = q4TailChecks(config)
[points,~,~] = q4Grid("triangle");
names = strings(0,1);
passed = false(0,1);
record("TailOriginalSetSupportsContinuousCoverage",q4TailCoverage(points).passed);
record("TailRejectsEmptySet",~q4TailCoverage(zeros(0,2)).passed);
record("TailRejectsNonFiniteSet",~q4TailCoverage([points;NaN,0]).passed);
record("TailRejectsCollinearSet",~q4TailCoverage([(-3:3)',zeros(7,1)]).passed);
record("TailRejectsMissingCentralCoverage",~q4TailCoverage(points(vecnorm(points,2,2)>100,:)).passed);
record("TailRejectsMissingOutwardBoundary",~q4TailCoverage(points(points(:,1)<=900,:)).passed);
plan = q4TailPlan([0,0],points,false(size(points,1),1),5);
record("TailReducedPlanRetainsCoverage",plan.applied && plan.certificate.passed && plan.estimatedSaving_s>0);
marked = false(size(points,1),1);
marked(plan.removedStations(1)) = true;
second = q4TailPlan([0,0],points,marked,5);
record("TailDoesNotDeleteAlreadyVisitedStation",second.requiredStations(plan.removedStations(1)));
q4CheckError(@() problem4('iterationStudy',struct('coveragePolicy',"invalid",'outputPath',tempname)), 'Q4:CoveragePolicy');
record("TailRejectsInvalidPolicy",true);
if isfield(config,'practiceRun')
    data = load(fullfile(config.practiceRun,'run.mat'),'solution');
    solution = data.solution;
    events = solution.events;
    successes = find(string({events.path})=="/clear" & string({events.result})=="success");
    finalClear = successes(end);
    record("FifteenClearsDoNotSatisfySixteenCap",numel(unique([events(successes).channel]))==15);
    at = [events(finalClear).x,events(finalClear).y];
    actual = false(size(points,1),1);
    absent = find(solution.status==3);
    for e = events(1:finalClear)
        if e.path=="/measure" && e.channel==absent(1)
            actual = actual | vecnorm(points-[e.x,e.y],2,2)<=1e-7;
        end
    end
    partial = solution;
    partial.events = events(1:finalClear);
    partial.tailPlan = q4TailPlan(at,points,actual,numel(absent));
    partial.tailPlan.serialBefore = finalClear;
    partial.requiredStations = partial.tailPlan.requiredStations;
    record("TailRejectsFifteenClearPrematureStop",~q4TailAudit(partial).allPassed);
    full = solution;
    full.tailPlan = partial.tailPlan;
    full.requiredStations = partial.requiredStations;
    record("TailBindsRealNoSignalRecords",q4TailAudit(full).allPassed);
    forged = full;
    chosen = find(forged.requiredStations,1);
    for k = 1:numel(forged.events)
        if forged.events(k).channel==absent(1) && norm([forged.events(k).x,forged.events(k).y]-points(chosen,:))<1e-7
            forged.events(k).result = "unobserved";
        end
    end
    record("TailRejectsForgedCoverageMatrix",~q4TailAudit(forged).allPassed);
end
checks = table(names,passed,'VariableNames',{'Name','Passed'});
    function record(name,value)
        names(end+1,1) = name;
        passed(end+1,1) = isscalar(value) && logical(value);
    end
end


function plan = q4OrderedTailPlan(position,points,visited,unknownCount)
assert(isnumeric(unknownCount) && isscalar(unknownCount) && isfinite(unknownCount) && ...
    unknownCount>=1 && unknownCount<=20 && unknownCount==fix(unknownCount),'Q4:TailChannels','A valid unknown-channel count is required.');
assert(islogical(visited) && isequal(size(visited),[size(points,1),1]),'Q4:TailVisited','Invalid visited station mask.');
required = true(size(points,1),1);
remaining = find(~visited);
[order,initialTravel] = q4OpenRoute(position,points(remaining,:));
initialRoute = remaining(order);
route = initialRoute;
cost = initialTravel/5+(6*unknownCount-1)*numel(route);
initialCost = cost;
while ~isempty(route)
    best = 0;
    bestCost = cost-1e-6;
    for index = 1:numel(route)
        candidate = required;
        candidate(route(index)) = false;
        if ~q4TailCoverage(points(candidate,:)).passed
            continue
        end
        next = route;
        next(index) = [];
        travel = sum(vecnorm(diff([position;points(next,:)],1,1),2,2));
        candidateCost = travel/5+(6*unknownCount-1)*numel(next);
        if candidateCost<bestCost
            best = index;
            bestCost = candidateCost;
        end
    end
    if best==0
        break
    end
    required(route(best)) = false;
    route(best) = [];
    cost = bestCost;
end
plan = struct('applied',any(~required),'serialBefore',0,'requiredStations',required, ...
    'removedStations',find(~required),'position',position,'visitedBefore',visited,'unknownCount',unknownCount, ...
    'initialTailEstimate_s',initialCost,'finalTailEstimate_s',cost,'estimatedSaving_s',initialCost-cost, ...
    'certificate',q4TailCoverage(points(required,:)),'actualStopRequiresMeasurements',true, ...
    'selection',"ordered_tail",'initialRoute',initialRoute,'route',route,'silentStation',0);
end

function [result,trace] = q4JointShadow(polygon,positive,negative)
result = polygon;
template = struct('positiveIndex',0,'negativeIndices',[0,0],'status',"",'message',"", ...
    'normals',nan(5,2),'thresholds',nan(5,1),'before',polygon,'after',polygon, ...
    'areaBefore',NaN,'areaAfter',NaN,'radiusBefore',NaN,'radiusAfter',NaN,'buffer',1e-5);
trace = repmat(template,0,1);
if ~q4ShadowValidPoints(polygon,3) || ~q4ShadowValidPoints(positive,0) || ~q4ShadowValidPoints(negative,0)
    template.status="INVALID_INPUT_PRESERVED"; trace=template; return
end
if isempty(positive) || size(negative,1)<2
    return
end
try
    hull = convhull(polygon(:,1),polygon(:,2));
    if polyarea(polygon(:,1),polygon(:,2))<=1e-10 || ...
            abs(polyarea(polygon(hull,1),polygon(hull,2))-polyarea(polygon(:,1),polygon(:,2)))>1e-7
        template.status="NONCONVEX_OR_DEGENERATE_PRESERVED"; trace=template; return
    end
catch caught
    template.status="INVALID_POLYGON_PRESERVED";template.message=string(caught.message);trace=template;return
end
selected = max(1,size(negative,1)-5):size(negative,1);
pairs = nchoosek(selected,2);
for aIndex = 1:size(positive,1)
    a = positive(aIndex,:);
    for pairIndex = 1:size(pairs,1)
        pair = pairs(pairIndex,:);
        item = template;
        item.positiveIndex=aIndex;item.negativeIndices=pair;item.before=result;item.after=result;
        item.areaBefore=polyarea(result(:,1),result(:,2));[~,item.radiusBefore]=q4Circle(result);
        try
            B=negative(pair,:);
            u=B(1,:)-a;v=B(2,:)-a;
            if min([norm(u),norm(v),norm(B(1,:)-B(2,:))])<=1e-5
                item.status="NEAR_OR_DUPLICATE_PRESERVED";
            elseif rcond([u',v'])<=1e-10
                item.status="COLLINEAR_OR_UNCERTAIN_PRESERVED";
            else
                if u(1)*v(2)-u(2)*v(1)<0
                    B=B([2,1],:);pair=pair([2,1]);u=B(1,:)-a;v=B(2,:)-a;
                end
                item.negativeIndices=pair;
                c=[1,1]/[u',v'];
                raw=[-u(2),u(1);v(2),-v(1);c;u;v];
                bounds=[dot(raw(1,:),a);dot(raw(2,:),a);1+dot(c,a); ...
                    dot(u,a)+dot(u,u)/2;dot(v,a)+dot(v,v)/2];
                lengths=vecnorm(raw,2,2);
                item.normals=raw./lengths;
                item.thresholds=bounds./lengths+item.buffer;
                vertices=zeros(0,2);
                for side=1:5
                    vertices=[vertices;q4Plane(result,item.normals(side,:),item.thresholds(side))];
                end
                vertices=unique(vertices,'rows','stable');
                if size(vertices,1)<3 || any(~isfinite(vertices),'all')
                    item.status="EMPTY_OR_DEGENERATE_PRESERVED";
                else
                    order=convhull(vertices(:,1),vertices(:,2));candidate=vertices(order(1:end-1),:);
                    if ~all(inpolygon(candidate(:,1),candidate(:,2),result(:,1),result(:,2))) || ...
                            polyarea(candidate(:,1),candidate(:,2))>item.areaBefore+1e-7
                        item.status="NUMERIC_EXPANSION_PRESERVED";
                    else
                        result=candidate;item.status="APPLIED";
                    end
                end
            end
        catch caught
            result=item.before;item.status="EXCEPTION_PRESERVED";item.message=string(caught.identifier)+": "+string(caught.message);
        end
        item.after=result;item.areaAfter=polyarea(result(:,1),result(:,2));[~,item.radiusAfter]=q4Circle(result);
        trace(end+1,1)=item;
    end
end
end

function valid=q4ShadowValidPoints(points,minimum)
valid=isnumeric(points) && isreal(points) && ismatrix(points) && size(points,2)==2 && ...
    size(points,1)>=minimum && all(isfinite(points),'all') && all(abs(points)<=1e7,'all');
end

function [points,triangles,info] = q4RingLayout()
persistent cachedPoints cachedTriangles cachedInfo
if isempty(cachedPoints)
    innerAngles = (0:6)'*360/7;
    outerAngles = (0:13)'*360/14;
    points = [0,0;990*[cosd(innerAngles),sind(innerAngles)];1850*[cosd(outerAngles),sind(outerAngles)]];
    certificate = q4_cover_certificate(points);
    verification = q4_verify_cover(certificate,points);
    assert(certificate.passed && verification.passed,'Q4:RingCertificate','Continuous ring coverage could not be verified.');
    triangles = delaunay(points(:,1),points(:,2));
    info = struct('kind',"ring22",'stationCount',size(points,1),'cellCount',size(triangles,1), ...
        'domainRadius',1800,'minimumRange',1000,'innerRadius',990,'outerRadius',1850, ...
        'certificateSummary',verification,'certificateCells',certificate.certifiedCells);
    cachedPoints = points;
    cachedTriangles = triangles;
    cachedInfo = info;
else
    points = cachedPoints;
    triangles = cachedTriangles;
    info = cachedInfo;
end
end

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

function decision = q4JointRouteChoice(position,points,remaining,known,tracks,totalKnown,serial,settings,localMeasures,serviceSilence,serviceEverSilent)
centers = zeros(numel(known),2);
for k = 1:numel(known)
    if settings.serviceOrder=="joint_steps"
        centers(k,:) = q4NextServicePoint(tracks{known(k)},position,localMeasures(known(k)),serviceSilence(known(k)),serviceEverSilent(known(k)),settings);
    else
        centers(k,:) = mean(tracks{known(k)}.polygon,1);
    end
end
assert(all(isfinite(centers),'all'),'Q4:JointRouteCenters','Proxy locations must be finite.');
selectedStations = remaining;
if totalKnown==16
    selectedStations = zeros(0,1);
end
nodes = [points(selectedStations,:);centers];
assert(~isempty(nodes),'Q4:JointRouteEmpty','No pending coverage or service task.');
[order,length] = q4OpenRoute(position,nodes);
first = order(1);
if first<=numel(selectedStations)
    type = "coverage";
    selected = selectedStations(first);
else
    type = "service";
    selected = known(first-numel(selectedStations));
end
decision = struct('serialBefore',serial,'position',position,'known',known,'targets',centers, ...
    'remainingStations',selectedStations,'totalKnown',totalKnown,'order',order,'routeLength',length, ...
    'type',type,'selected',selected);
end

function destination = q4NextServicePoint(track,position,used,silence,everSilent,settings)
[center,radius] = q4Circle(track.polygon);
if track.near
    center = track.anchor;
    radius = 5;
end
if radius<=settings.clearMargin
    [destination,~] = q4SafeClearPoint(track.polygon,position,center,settings.clearMargin);
    return
end
if used>=settings.localLimit || silence>=settings.silenceLimit
    destination = position;
    return
end
if settings.localPolicy=="active_clear"
    plan = q4ActivePlan(track,position,used,silence,everSilent,settings);
    destination = plan.destination;
    return
end
attempt = used+1;
destination = q4LegacyPoint(track,center,radius,attempt);
if ismember(settings.localPolicy,["anchor_blend","persistent_anchor_blend"])
    policySilence = silence;
    if settings.localPolicy=="persistent_anchor_blend"
        policySilence = double(everSilent);
    end
    destination = q4LocalPolicyPoint(track,center,radius,attempt,policySilence,position,"anchor_blend");
end
if isempty(destination)
    destination = position;
end
end

function plan = q4ActivePlan(track,position,used,silence,everSilent,settings)
persistent keys values
if isempty(keys)
    keys = strings(0,1);
    values = cell(0,1);
end
key = string(jsonencode(struct('polygon',track.polygon,'observations',track.observations,'used',used,'silence',silence,'everSilent',everSilent)));
index = find(keys==key,1);
if ~isempty(index)
    plan = values{index};
    [opticalCost,opticalPoint] = q4ActiveOpticalCost(track.polygon,track,position,plan.representatives,settings);
    plan.scores(1) = sum(plan.weights.*opticalCost);
    plan.scores(2:end) = vecnorm(plan.candidates-position,2,2)/5+6+plan.radioBaseCosts;
    plan.selected = find(plan.scores<=min(plan.scores)+1e-9,1);
    if plan.selected==1
        plan.type = "optical";
        plan.destination = opticalPoint;
    else
        plan.type = "measure";
        plan.destination = plan.candidates(plan.selected-1,:);
    end
    return
end
[center,radius] = q4Circle(track.polygon);
baseline = q4LocalPolicyPoint(track,center,radius,used+1,double(everSilent),position,"anchor_blend");
[representatives,weights] = q4ActiveRepresentatives(track);
[opticalCost,opticalPoint] = q4ActiveOpticalCost(track.polygon,track,position,representatives,settings);
axis = [cosd(track.angle),sind(track.angle)];
normal = [-axis(2),axis(1)];
projection = (track.polygon-track.anchor)*axis';
low = min(projection); high = max(projection);
span = high-low;
offset = min(80,max(15,0.12*span));
candidates = baseline;
for fraction = [0.2,0.5,0.8]
    for sign = [-1,1]
        candidates(end+1,:) = track.anchor+(low+fraction*span)*axis+sign*offset*normal;
    end
end
for sign = [-1,1]
    candidates(end+1,:) = center+sign*min(200,max(25,0.3*radius))*normal;
end
candidates = unique(candidates,'rows','stable');
valid = vecnorm(candidates,2,2)<=2000 & all(isfinite(candidates),2);
for k = 1:size(candidates,1)
    valid(k) = valid(k) && all(vecnorm(track.seen-candidates(k,:),2,2)>1e-6);
end
candidates = candidates(valid,:);
scores = inf(size(candidates,1)+1,1);
radioBaseCosts = inf(size(candidates,1),1);
scores(1) = sum(weights.*opticalCost);
branchCosts = nan(size(candidates,1),numel(weights),2);
probabilities = nan(size(candidates,1),numel(weights));
for k = 1:size(candidates,1)
    at = candidates(k,:);
    costs = zeros(numel(weights),1);
    for j = 1:numel(weights)
        if weights(j)<=0
            continue
        end
        target = representatives(j,:);
        probability = q4ActiveVisibility(track,target,at);
        probabilities(k,j) = probability;
        if probability>0
            positiveCost = zeros(3,1);
            errors = [-1,0,1];
            for e = 1:3
                polygon = track.polygon;
                if norm(target-at)<=5
                    polygon = q4ClipDisk(polygon,at,5,settings.diskSides);
                else
                    bearing = atan2d(target(2)-at(2),target(1)-at(1))+errors(e);
                    polygon = q4ClipDisk(polygon,at,1500,settings.diskSides);
                    polygon = q4Wedge(polygon,at,bearing,settings.angleMargin);
                end
                positiveCost(e) = q4ActiveOpticalCost(polygon,track,at,target,settings);
            end
            branchCosts(k,j,1) = mean(positiveCost);
            costs(j) = costs(j)+probability*mean(positiveCost);
        end
        if probability<1
            positive = vertcat(track.observations(ismember([track.observations.kind],["direction","near"])).position);
            negative = vertcat(track.observations([track.observations.kind]=="no_signal").position);
            negative = [reshape(negative,[],2);at];
            polygon = q4JointShadow(track.polygon,positive,negative);
            missedCost = q4ActiveOpticalCost(polygon,track,at,target,settings);
            branchCosts(k,j,2) = missedCost;
            costs(j) = costs(j)+(1-probability)*missedCost;
        end
    end
    radioBaseCosts(k) = sum(weights.*costs);
    scores(k+1) = norm(at-position)/5+6+radioBaseCosts(k);
end
selected = find(scores<=min(scores)+1e-9,1);
if selected==1
    type = "optical";
    destination = opticalPoint;
else
    type = "measure";
    destination = candidates(selected-1,:);
end
plan = struct('type',type,'destination',destination,'candidates',candidates,'representatives',representatives, ...
    'weights',weights,'scores',scores,'radioBaseCosts',radioBaseCosts,'selected',selected,'visibilityProbability',probabilities,'branchCosts',branchCosts, ...
    'meaning',"PUBLIC_GEOMETRY_QUADRATURE_ONE_RADIO_THEN_OPTICAL_NOT_CERTIFIED_EXPECTATION");
keys(end+1,1) = key; values{end+1,1} = plan;
if numel(keys)>200
    keys(1) = []; values(1) = [];
end
end

function [representatives,weights] = q4ActiveRepresentatives(track)
polygon = track.polygon;
axis = [cosd(track.firstAngle),sind(track.firstAngle)];
normal = [-axis(2),axis(1)];
u = polygon*axis'; v = polygon*normal';
fractions = [0.05,0.275,0.5,0.725,0.95];
representatives = zeros(0,2); weights = zeros(0,1);
for fraction = fractions
    cut = min(u)+fraction*(max(u)-min(u));
    values = [];
    for k = 1:numel(u)
        next = mod(k,numel(u))+1;
        if abs(u(next)-u(k))<1e-12
            continue
        end
        t = (cut-u(k))/(u(next)-u(k));
        if t>=0 && t<=1
            values(end+1) = v(k)+t*(v(next)-v(k));
        end
    end
    if isempty(values)
        continue
    end
    point = cut*axis+mean([min(values),max(values)])*normal;
    mass = q4ActiveVisibility(track,point,track.anchor);
    if isfinite(mass) && mass>0
        representatives(end+1,:) = point;
        weights(end+1,1) = max(1e-6,max(values)-min(values));
    end
end
if isempty(weights)
    representatives = mean(polygon,1);
    weights = 1;
end
weights = weights/sum(weights);
end

function probability = q4ActiveVisibility(track,target,at)
observations = track.observations;
locations = vertcat(observations.position);
vectors = locations-target;
distances = vecnorm(vectors,2,2);
positive = ismember([observations.kind],["direction","near"])';
if norm(target)>1800+1e-7
    probability = NaN; return
end
for k = find(positive)'
    if observations(k).kind=="direction"
        bearing = atan2d(-vectors(k,2),-vectors(k,1));
        if distances(k)<=5 || abs(mod(bearing-observations(k).bearing+180,360)-180)>1.0050001
            probability = NaN; return
        end
    elseif distances(k)>5+1e-7
        probability = NaN; return
    end
end
minRange = max([1000;distances(positive)]);
if minRange>1500+1e-7
    probability = NaN; return
end
probe = at-target;
allVectors = [vectors;probe];
cuts = unique(mod([atan2d(allVectors(:,2),allVectors(:,1))+90;atan2d(allVectors(:,2),allVectors(:,1))-90;0],360));
widths = diff([cuts;cuts(1)+360]);
directions = mod(cuts+widths/2,360);
projections = vectors*[cosd(directions),sind(directions)]';
probeProjection = probe*[cosd(directions),sind(directions)]';
total = 0; seen = 0;
for range = minRange+(1500-minRange)*[0,0.5,1]
    negativeInside = ~positive & distances<=range+1e-8;
    feasible = all(projections(positive,:)>=0,1) & all(projections(negativeInside,:)<0,1);
    mass = widths'/360;
    total = total+sum(mass(feasible));
    if norm(probe)<=range
        seen = seen+sum(mass(feasible & probeProjection>=0));
    end
    if ~any(negativeInside)
        total = total+1;
        seen = seen+double(norm(probe)<=range);
    end
end
if total<=0
    probability = NaN;
else
    probability = min(1,max(0,seen/total));
end
end

function [costs,first] = q4ActiveOpticalCost(polygon,track,position,targets,settings)
assert(~isempty(polygon),'Q4:ActivePolygon','A forecast polygon is empty.');
[center,radius] = q4Circle(polygon);
if radius<=settings.clearMargin
    [first,~] = q4SafeClearPoint(polygon,position,center,settings.clearMargin);
    costs = repmat(norm(first-position)/5+5,size(targets,1),1);
    return
end
try
    [cells,~] = q4ActiveForecastCells(track.firstAnchor,track.firstAngle,polygon);
catch errorInfo
    if ~strcmp(errorInfo.identifier,'Q4:OpticalCellEnvelope')
        rethrow(errorInfo)
    end
    [queue,~] = q4OpticalQueue(track.firstAnchor,track.firstAngle,polygon,position);
    first = queue(1,:);
    costs = zeros(size(targets,1),1);
    for j = 1:size(targets,1)
        found = find(vecnorm(queue-targets(j,:),2,2)<=20+1e-7,1);
        assert(~isempty(found),'Q4:ActiveForecast','A forecast target is not covered.');
        costs(j) = sum(vecnorm(diff([position;queue(1:found,:)],1,1),2,2))/5+3*(found-1)+5;
    end
    return
end
costs = zeros(size(targets,1),1);
locations = vertcat(cells.point);
distances = vecnorm(locations-position,2,2);
tied = find(distances<=min(distances)+1e-9);
[~,tie] = min([cells(tied).id]);
first = cells(tied(tie)).point;
for j = 1:size(targets,1)
    todo = cells; at = position;
    while ~isempty(todo)
        locations = vertcat(todo.point);
        distances = vecnorm(locations-at,2,2);
        tied = find(distances<=min(distances)+1e-9);
        [~,tie] = min([todo(tied).id]);
        selected = tied(tie);
        point = todo(selected).point;
        costs(j) = costs(j)+norm(point-at)/5;
        at = point;
        if norm(at-targets(j,:))<=20+1e-7
            costs(j) = costs(j)+5;
            break
        end
        costs(j) = costs(j)+3;
        keep = true(numel(todo),1);
        for cellIndex = 1:numel(todo)
            part = todo(cellIndex).polygon;
            keep(cellIndex) = max(hypot(part(:,1)-at(1),part(:,2)-at(2)))>20-1e-7;
        end
        todo = todo(keep);
    end
    assert(~isempty(todo),'Q4:ActiveForecast','A forecast target is not covered.');
end
end

function [cells,certificate] = q4ActiveForecastCells(anchor,angle,polygon)
assert(isnumeric(anchor) && isequal(size(anchor),[1,2]) && all(isfinite(anchor)) && isscalar(angle) && isfinite(angle) ...
    && isnumeric(polygon) && ~isempty(polygon) && size(polygon,2)==2 && all(isfinite(polygon),'all'),'Q4:OpticalCellInput','Finite optical geometry required.');
rotation = [cosd(angle),sind(angle);-sind(angle),cosd(angle)];
local = (polygon-anchor)*rotation';
assert(all(local(:,1)>=-10-1e-9 & local(:,1)<=1510+1e-9) && all(abs(local(:,2))<=27+1e-9),'Q4:OpticalCellEnvelope','Optical envelope exceeded.');
rectangle = [min(local(:,1)),max(local(:,1)),min(local(:,2)),max(local(:,2))];
span = rectangle(2)-rectangle(1); width = rectangle(4)-rectangle(3);
counts = inf(3,1); columns = zeros(3,1);
for rows = 1:3
    height = width/rows;
    if height>=38.8
        continue
    end
    step = 2*sqrt(19.4^2-(height/2)^2);
    columns(rows) = max(1,ceil(span/step));
    counts(rows) = rows*columns(rows);
end
[originalCount,rows] = min(counts);
columns = columns(rows);
assert(isfinite(originalCount) && originalCount<=152,'Q4:OpticalCellCertificate','Finite adaptive optical cover exceeds budget.');
edgesX = linspace(rectangle(1),rectangle(2),columns+1);
edgesY = linspace(rectangle(3),rectangle(4),rows+1);
cells = struct('id',{},'point',{},'polygon',{});
maximum = 0;
for column = 1:columns
    for row = 1:rows
        bounds = [edgesX(column),edgesX(column+1),edgesY(row),edgesY(row+1)];
        part = q4Plane(local,[1,0],bounds(2));
        part = q4Plane(part,[-1,0],-bounds(1));
        part = q4Plane(part,[0,1],bounds(4));
        part = q4Plane(part,[0,-1],-bounds(3));
        if isempty(part)
            continue
        end
        owner = [mean(bounds(1:2)),mean(bounds(3:4))];
        point = anchor+owner*rotation;
        vertices = anchor+part*rotation;
        bound = max(vecnorm(vertices-point,2,2));
        assert(bound<=19.4+1e-6 && bound<20,'Q4:OpticalCellCertificate','Unsafe adaptive cell.');
        maximum = max(maximum,bound);
        cells(end+1,1) = struct('id',(column-1)*rows+row,'point',point,'polygon',vertices);
    end
end
assert(~isempty(cells),'Q4:OpticalCellCertificate','Empty adaptive cover.');
certificate = struct('rectangle',rectangle,'coverRadius',19.4,'originalCount',originalCount,'retainedCount',numel(cells), ...
    'maximumOwnerBound',maximum,'columns',columns,'rows',rows,'mode',"adaptive_rectangle_cover",'fixedCellDomainCoversPolygon',true);
end


