function output = problem3(mode,config)
if nargin == 0
    mode = "offline";
end
if nargin < 2
    config = struct;
end
mode = string(mode);
if mode == "research_api"
    settings = struct('version',"0.12.0-work-study",'angleMargin',1.01,'clearMargin',19.5,'diskSides',72,'maxActions',2000,'robotId','OFFLINE_SYNTHETIC','requestPrefix','research');
    output = struct('solve',@solveRoute,'world',@makeWorld,'settings',coverageSettings(settings,"release"),'history',@checkHistory,'absence',@independentAbsenceCover,'search',@verifySearchEvidence,'decisions',@verifyRouteDecisions,'probes',@verifyRouteProbes,'layout',@verifyLayoutDecision,'next',@nextLocalizationPoint,'update',@updateTrack,'mobile',@verifyMobileHistory,'clear',@safeClearPoint,'scenarios',@buildScenarios,'disk',@diskPolygon,'range',@rangeDominancePolygon);
    return
end

assert(isscalar(mode) && ismember(mode,["offline","validate","practice","formal","validate_http","validate_artifacts","search_study","validate_search","route_study","validate_route","improvement_study","validate_improvement","validate_group2","coverage_study","validate_group3","validate_layout"]), ...
    'Q3:UnsupportedMode','Only documented modes with current GUI confirmation are supported.');
root = fileparts(mfilename('fullpath'));
settings = struct('version',"0.12.0-work-study",'angleMargin',1.01,'clearMargin',19.5,'diskSides',72, ...
    'maxActions',2000,'robotId','OFFLINE_SYNTHETIC','requestPrefix','offline');
if mode == "validate_layout"
    output = validateLayout(root,settings);
    return
elseif mode == "coverage_study"
    output = runCoverageStudy(root,settings,config);
    return
elseif mode == "validate_group3"
    output = validateGroup3(root,settings);
    return
elseif mode == "validate_group2"
    output = validateGroup2(root,settings);
    return
elseif mode == "improvement_study"
    output = runImprovementStudy(root,settings,config);
    return
elseif mode == "validate_improvement"
    output = validateImprovement(root,settings);
    return
elseif mode == "route_study"
    output = runRouteStudy(root,settings,config);
    return
elseif mode == "validate_route"
    output = validateRoute(root,settings);
    return
elseif mode == "search_study"
    output = runSearchStudy(root,settings,config);
    return
elseif mode == "validate_search"
    output = validateSearch(root,settings);
    return
elseif ismember(mode,["practice","formal"])
    config = validatePracticeConfig(config,root,mode);
    output = runPractice(config,settings);
    return
elseif mode == "validate_http"
    output = runHttpValidation(root,config);
    return
elseif mode == "validate_artifacts"
    [checks,outputPath] = validatePersistence(settings);
    output = struct('path',outputPath,'checks',checks,'version',settings.version);
    assert(all(checks.Passed),'Q3:ArtifactValidation','An artifact persistence check failed.');
    return
end
outputPath = fullfile(root,'运行结果',char(mode+"_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
mkdir(outputPath);
checks = validateCore(settings);
protocolConfig = struct('robotId','LOCAL_PROTOCOL_TEST','requestPrefix','local-test', ...
    'baseUrl','http://127.0.0.1:2334','maxAttempts',3,'requestTimeoutSec',5,'retryPauseSec',0, ...
    'exitReserveSec',30,'recoveryAttempts',3,'recoveryWindowSec',15,'finalExitReserveSec',5);
transportChecks = validateTransportExtended(protocolConfig);
snapshotChecks = validateSnapshots(settings);
batchChecks = validateBatch(settings);
checks = [checks;transportChecks(:,{'Check','Passed'});snapshotChecks(:,{'Check','Passed'});batchChecks];
save(fullfile(outputPath,'验证明细.mat'),'transportChecks','snapshotChecks','batchChecks');
writetable(checks,fullfile(outputPath,'必要验证.csv'),'Encoding','UTF-8');
if mode == "validate"
    output = struct('path',outputPath,'checks',checks,'version',settings.version);
    assert(all(checks.Passed),'Q3:Validation','A required validation failed.');
    return
end
output = runOffline(root,settings,checks,outputPath);
end

function config = validatePracticeConfig(config,root,expectedMode)
if nargin < 3
    expectedMode = "practice";
end
if expectedMode == "formal"
    assert(isfield(config,'formalAuthorization') && strcmp(config.formalAuthorization,'20260913_K28A_ALGORITHM_THREE_Q3_FORMAL') && isfield(config,'authorizedFormalRun') && validScalar(config.authorizedFormalRun,1,3) && fix(config.authorizedFormalRun) == config.authorizedFormalRun,'Q3:FormalAuthorization','This entry requires the recorded authorization for one of three problem 3 formal runs.');
end
required = {'robotId','caseCode','baseUrl','confirmedProblem','confirmedMode','confirmedAtIso'};
assert(isstruct(config) && isscalar(config) && all(isfield(config,required)), ...
    'Q3:PracticeConfig','Practice requires explicit current GUI confirmation and all required configuration fields.');
assert(isequal(config.confirmedProblem,3) && isscalar(string(config.confirmedMode)) ...
    && string(config.confirmedMode) == expectedMode,'Q3:PracticeConfig','Current problem 3 GUI mode must match the requested live mode.');
config.robotId = char(string(config.robotId));
config.caseCode = char(string(config.caseCode));
config.baseUrl = char(string(config.baseUrl));
assert(isrow(config.robotId) && ~isempty(regexp(config.robotId,'^[A-Za-z0-9_-]{1,64}$','once')), ...
    'Q3:PracticeConfig','Invalid robotId.');
assert(isrow(config.caseCode) && ~isempty(regexp(config.caseCode,'^[A-Za-z0-9-]{1,80}$','once')), ...
    'Q3:PracticeConfig','Invalid caseCode.');
portToken = regexp(config.baseUrl,'^http://127\.0\.0\.1:([0-9]{1,5})$','tokens','once');
assert(~isempty(portToken) && str2double(portToken{1}) >= 1 && str2double(portToken{1}) <= 65535, ...
    'Q3:PracticeConfig','baseUrl must be an exact IPv4 loopback HTTP URL with a valid port.');
stamp = char(string(config.confirmedAtIso));
assert(isrow(stamp) && ~isempty(regexp(stamp,'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$','once')), ...
    'Q3:PracticeConfig','confirmedAtIso must use UTC yyyy-MM-ddTHH:mm:ssZ or ss.SSSZ.');
try
    stampFormat = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
    if contains(stamp,'.')
        stampFormat = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
    end
    confirmedTime = datetime(stamp,'InputFormat',stampFormat,'TimeZone','UTC');
catch
    error('Q3:PracticeConfig','Invalid UTC confirmation time.');
end
age = seconds(datetime('now','TimeZone','UTC')-confirmedTime);
assert(isfinite(age) && age >= -5 && age <= 300,'Q3:PracticeConfig','GUI confirmation must be no more than five minutes old.');
defaults = struct('requestTimeoutSec',5,'maxAttempts',3,'retryPauseSec',0.25,'exitReserveSec',30,'recoveryAttempts',3,'recoveryWindowSec',15,'showProgressWindow',true);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(config,names{index})
        config.(names{index}) = defaults.(names{index});
    end
end
assert(validScalar(config.requestTimeoutSec,1,20) && validScalar(config.maxAttempts,1,3) ...
    && fix(config.maxAttempts) == config.maxAttempts && validScalar(config.retryPauseSec,0,1) ...
    && validScalar(config.exitReserveSec,10,120),'Q3:PracticeConfig','Invalid bounded transport or exit settings.');
assert(islogical(config.showProgressWindow) && isscalar(config.showProgressWindow),'Q3:PracticeConfig','showProgressWindow must be logical.');
assert(validScalar(config.recoveryAttempts,0,5) && fix(config.recoveryAttempts) == config.recoveryAttempts ...
    && validScalar(config.recoveryWindowSec,0,60),'Q3:PracticeConfig','Invalid bounded recovery settings.');
if ~isfield(config,'outputPath') || strlength(string(config.outputPath)) == 0
    config.outputPath = fullfile(root,'运行结果',char("practice_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
end
rootFile = java.io.File(root);
outputFile = java.io.File(char(string(config.outputPath)));
rootPath = char(rootFile.getCanonicalPath());
config.outputPath = char(outputFile.getCanonicalPath());
assert(startsWith(lower(string(config.outputPath)),lower(string(rootPath)+filesep)) ...
    && ~isfolder(config.outputPath) && ~isfile(config.outputPath), ...
    'Q3:PracticeConfig','Practice output must be a new directory inside this problem 3 package.');
config.confirmationLimit = 'Local fields record current GUI confirmation; the HTTP protocol cannot verify the test mode.';
end

function value = validScalar(value,lowerBound,upperBound)
value = isnumeric(value) && isscalar(value) && isfinite(value) && value >= lowerBound && value <= upperBound;
end

function output = runPractice(config,settings)
liveMode = string(config.confirmedMode);
evidenceLabel = "OFFICIAL_PRACTICE_PUBLIC_HTTP_NOT_FORMAL";
if liveMode == "formal"
    evidenceLabel = "OFFICIAL_FORMAL_PUBLIC_HTTP";
end
[created,message] = mkdir(config.outputPath);
assert(created,'Q3:Output','Cannot create practice output directory: %s',message);
settings = coverageSettings(settings,"release");
if isfield(config,'flexPolicy')
    settings.flexPolicy = config.flexPolicy;
end
if isfield(config,'mobileMode')
    settings.mobileMode = config.mobileMode;
end
if isfield(config,'workPolicy')
    settings.workPolicy = config.workPolicy;
end
settings.robotId = config.robotId;
settings.requestPrefix = char("q3-"+liveMode+"-"+string(datetime('now','Format','yyyyMMddHHmmssSSS')));
config.version = settings.version;
config.variant = settings.variant;
config.search = settings.search;
config.route = settings.route;
config.improvement = settings.improvement;
config.regionForecast = settings.regionForecast;
config.coverageTuning = settings.coverageTuning;
config.emptyOriginLayout = settings.emptyOriginLayout;
config.requestPrefix = settings.requestPrefix;
writeJson(fullfile(config.outputPath,'config.json'),config);
eventPath = fullfile(config.outputPath,'request_response.jsonl');
[exchange,report,emergencyExit] = makeTransport(config,@postJson,@(event) appendJson(eventPath,event));
[progress,closeProgress] = makeProgress(config);
progressCleanup = onCleanup(closeProgress);
runtimeSettings = settings;
runtimeSettings.progressFcn = progress;
runtimeSettings.decisionFcn = @(event) appendJson(fullfile(config.outputPath,'decisions.jsonl'),event);
runtimeSettings.snapshotFcn = @(snapshot) saveSnapshot(fullfile(config.outputPath,'checkpoint.mat'),snapshot);
[solution,failure] = solveRoute(exchange,runtimeSettings);
if ~isempty(failure.identifier)
    emergencyExit();
end
state = report();
count = numel(state.clearedChannels);
complete = practiceComplete(solution,failure,state);
if isempty(failure.identifier) && ~complete
    failure = struct('identifier','Q3:CompletionInvariant','message','Completion evidence, source count, callbacks, or transport state is inconsistent.','stack',struct('file',{},'name',{},'line',{}));
end
meanTime = NaN;
if count > 0
    meanTime = state.virtualTime/count;
end
timeResidual = abs(state.confirmedCosts(1)/5+sum(state.confirmedCosts(2:5))-state.virtualTime);
timeTolerance = (state.acceptedActions+1)*1e-6+1e-7;
if timeResidual > timeTolerance
    complete = false;
    if isempty(failure.identifier)
        failure.identifier = 'Q3:TimeAccounting';
        failure.message = 'Independent action costs disagree with simulator time.';
    end
end
status = upper(liveMode)+"_INCOMPLETE";
if complete
    status = upper(liveMode)+"_COMPLETED";
end
result = struct('status',status,'complete',complete,'mode',char(liveMode),'problem',3,'version',settings.version, ...
    'caseCode',config.caseCode,'variant',settings.variant,'clearedCount',count,'virtualTime_s',state.virtualTime, ...
    'meanClearTime_s',meanTime,'clientProgramElapsed_s',state.programElapsed,'acceptedActions',state.acceptedActions, ...
    'timeResidual_s',timeResidual,'timeTolerance_s',timeTolerance,'unresolved',state.unresolved, ...
    'failure',failure,'logErrors',state.logErrors,'callbackErrors',solution.callbackErrors, ...
    'path',config.outputPath,'evidence',char(evidenceLabel));
result = persistPracticeOutputs(solution,state,result,config,settings);
output = result;
fprintf('%s\n',practiceSummary(result,solution));
if ~result.complete
    error('Q3:PracticeIncomplete','Practice was not completed. Confirmed clear count: %d. Inspect %s',count,config.outputPath);
end
end

function [exchange,report,emergencyExit] = makeTransport(config,sender,logger,clock)
timer = tic;
if nargin < 4
    clock = struct('now',@() toc(timer),'sleep',@(duration) pause(duration),'utc',@utcStamp);
end
assert(isstruct(clock) && all(isfield(clock,{'now','sleep','utc'})), ...
    'Q3:Clock','A transport clock requires now, sleep, and utc function handles.');
defaults = struct('recoveryAttempts',3,'recoveryWindowSec',15, ...
    'finalExitReserveSec',min(5,min(config.exitReserveSec,config.requestTimeoutSec)));
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(config,names{index})
        config.(names{index}) = defaults.(names{index});
    end
end
assert(validScalar(config.recoveryAttempts,0,5) && fix(config.recoveryAttempts) == config.recoveryAttempts ...
    && validScalar(config.recoveryWindowSec,0,60) ...
    && validScalar(config.finalExitReserveSec,0.1,min(config.exitReserveSec,config.requestTimeoutSec)), ...
    'Q3:TransportConfig','Invalid bounded recovery or exit settings.');
entered = false;
closed = false;
blocked = false;
needsStop = false;
stopReason = '';
pending = [];
lastUnsent = [];
virtualTime = 0;
maxVirtual = 360000;
deadline = Inf;
enterStarted = NaN;
programEnded = NaN;
position = [0,0];
receiver = 1;
clearedChannels = zeros(1,0);
confirmedCosts = zeros(1,5);
acceptedActions = 0;
rows = cell(256,10);
accountingRows = cell(256,10);
accountingResiduals = zeros(256,1);
logErrors = struct('event',{},'timestampUtc',{},'clientElapsed_s',{},'identifier',{},'message',{});
fallbackEvents = cell(0,1);
cache = containers.Map('KeyType','char','ValueType','any');
exchange = @dispatch;
report = @snapshot;
emergencyExit = @finish;

    function response = dispatch(path,payload,attemptLimit)
        if nargin < 3
            attemptLimit = config.maxAttempts;
        end
        assert(validScalar(attemptLimit,1,config.maxAttempts) && fix(attemptLimit) == attemptLimit, ...
            'Q3:TransportConfig','Invalid finite attempt limit.');
        path = string(path);
        validateRequest(path,payload,config.robotId);
        key = char(string(payload.request_id));
        body = jsonencode(payload);
        signature = char(path+"|"+string(body));
        if isKey(cache,key)
            previous = cache(key);
            assert(strcmp(previous.signature,signature),'Q3:Conflict','A completed ID was reused with different content.');
            response = previous.response;
            return
        end
        assert(~blocked && isempty(pending) && ~closed,'Q3:Pending', ...
            'No new action is allowed after an unresolved request or closed session.');
        assert(~needsStop || path == "/exit",'Q3:TransportStopped', ...
            'New actions stopped after a confirmed runtime fault: %s',stopReason);
        if path == "/enter"
            assert(~entered && isnan(enterStarted),'Q3:State','Only one entry is permitted.');
            normalDeadline = clock.now()+attemptLimit*(config.requestTimeoutSec+config.retryPauseSec);
        else
            assert(entered,'Q3:State','The practice session has not been entered.');
            if path == "/exit"
                normalDeadline = deadline;
            else
                normalDeadline = deadline-config.exitReserveSec;
                assert(clock.now() < normalDeadline-0.1,'Q3:RealBudget', ...
                    'Stopping new actions to preserve exit time.');
                destination = [payload.position.x,payload.position.y];
                predicted = norm(destination-position)/5+5;
                if path == "/measure"
                    predicted = predicted+double(receiver ~= payload.channel);
                end
                assert(virtualTime+predicted < maxVirtual,'Q3:VirtualBudget', ...
                    'The next action would exhaust the virtual budget.');
            end
        end
        prepared = struct('path',path,'payload',payload,'body',body,'requestId',key, ...
            'stage','prepared_not_sent','attempt',0,'phase','normal','sentAt_s',NaN);
        recoveryDeadline = NaN;
        totalAttempts = attemptLimit+config.recoveryAttempts;
        for attempt = 1:totalAttempts
            phase = 'normal';
            attemptDeadline = normalDeadline;
            if attempt > attemptLimit
                phase = 'recovery';
                if isnan(recoveryDeadline)
                    recoveryDeadline = clock.now()+config.recoveryWindowSec;
                    if entered
                        if path == "/exit"
                            recoveryDeadline = min(recoveryDeadline,deadline);
                        else
                            recoveryDeadline = min(recoveryDeadline,deadline-config.finalExitReserveSec);
                        end
                    end
                end
                attemptDeadline = recoveryDeadline;
            end
            allowance = attemptDeadline-clock.now();
            if allowance <= 0.1
                if attempt <= attemptLimit && ~isempty(pending) && config.recoveryAttempts > 0
                    continue
                end
                if isempty(pending)
                    lastUnsent = prepared;
                    error('Q3:RealBudget','The request was not sent because its real-time budget expired.');
                end
                blocked = true;
                error('Q3:Unresolved','No safe time remains to resolve the pending request.');
            end
            timeout = min(config.requestTimeoutSec,allowance-0.01);
            logged = safeLog(struct('event','request','path',path,'payload',payload,'body',body, ...
                'attempt',attempt,'phase',phase,'timeoutSec',timeout));
            if ~logged && isempty(pending) && path ~= "/exit"
                lastUnsent = prepared;
                error('Q3:Log','The request was not sent because its request ledger could not be persisted.');
            end
            allowance = attemptDeadline-clock.now();
            if allowance <= 0.1
                if isempty(pending)
                    lastUnsent = prepared;
                    error('Q3:RealBudget','The request was not sent because logging exhausted its real-time budget.');
                end
                if attempt <= attemptLimit && config.recoveryAttempts > 0
                    continue
                end
                blocked = true;
                error('Q3:Unresolved','The pending request reached its recovery deadline before a retry.');
            end
            timeout = min(config.requestTimeoutSec,allowance-0.01);
            if path == "/enter" && isnan(enterStarted)
                enterStarted = clock.now();
            end
            if isempty(pending)
                pending = prepared;
            end
            pending.stage = 'sent_unresolved';
            pending.attempt = attempt;
            pending.phase = phase;
            pending.sentAt_s = clock.now();
            sendStarted = clock.now();
            try
                packet = sender(config.baseUrl,path,body,timeout);
            catch errorInfo
                safeLog(struct('event','transport_error','requestId',key,'attempt',attempt,'phase',phase, ...
                    'durationSec',clock.now()-sendStarted,'identifier',errorInfo.identifier,'message',errorInfo.message));
                if attempt == totalAttempts
                    blocked = true;
                    error('Q3:Unresolved','The same request could not be resolved within its bounded recovery: %s',key);
                end
                sleepBudget = max(0,attemptDeadline-clock.now()-0.1);
                if config.retryPauseSec > 0 && sleepBudget > 0
                    clock.sleep(min(config.retryPauseSec,sleepBudget));
                end
                continue
            end
            pending.stage = 'response_received_unconfirmed';
            pending.packet = packet;
            safeLog(struct('event','response','requestId',key,'attempt',attempt,'phase',phase, ...
                'durationSec',clock.now()-sendStarted,'httpStatus',packet.httpStatus,'response',packet.body));
            response = packet.body;
            if packet.httpStatus == 409
                blocked = true;
                error('Q3:Conflict','HTTP 409: stop and inspect the saved request ledger.');
            end
            if packet.httpStatus ~= 200
                if isstruct(response) && isscalar(response) && isfield(response,'accepted') ...
                        && isequal(response.accepted,false) && ismember(packet.httpStatus,[400,404,405,413,415])
                    pending = [];
                else
                    blocked = true;
                end
                error('Q3:HttpStatus','HTTP %d stopped the practice client.',packet.httpStatus);
            end
            try
                assert(isstruct(response) && isscalar(response) && isfield(response,'accepted') ...
                    && islogical(response.accepted) && isscalar(response.accepted),'Q3:Response', ...
                    'Malformed response; execution status remains unresolved.');
                if response.accepted
                    validateResponse(path,response,virtualTime);
                end
            catch errorInfo
                blocked = true;
                rethrow(errorInfo)
            end
            if ~response.accepted
                pending = [];
                error('Q3:Rejected','The request was rejected; confirmed state was not updated.');
            end
            stepCosts = zeros(1,5);
            result = "entered";
            bearing = NaN;
            channel = NaN;
            if path == "/enter"
                entered = true;
                maxVirtual = response.max_virtual_duration_s;
                deadline = enterStarted+response.remaining_real_duration_s;
            elseif path == "/exit"
                closed = true;
                programEnded = clock.now();
                result = string(response.exit_reason);
            else
                destination = [payload.position.x,payload.position.y];
                stepCosts(1) = norm(destination-position);
                position = destination;
                channel = payload.channel;
                if path == "/measure"
                    stepCosts(2) = double(receiver ~= channel);
                    stepCosts(3) = 5;
                    receiver = channel;
                    response.measure_result = string(response.measure_result);
                    result = response.measure_result;
                    if result == "direction"
                        bearing = response.svd_deg;
                    end
                else
                    response.clear_result = string(response.clear_result);
                    result = response.clear_result;
                    if result == "success"
                        stepCosts(5) = 5;
                        clearedChannels = unique([clearedChannels,channel]);
                    else
                        stepCosts(4) = 3;
                    end
                end
            end
            stepSeconds = stepCosts(1)/5+sum(stepCosts(2:5));
            expectedTime = (round(virtualTime*1e6)+round(stepSeconds*1e6))/1e6;
            residual = response.virtual_time_s-expectedTime;
            timeValid = abs(residual) <= 2e-6+8*eps(max(1,abs(expectedTime)));
            confirmedCosts = confirmedCosts+stepCosts;
            virtualTime = response.virtual_time_s;
            acceptedActions = acceptedActions+1;
            if acceptedActions > size(rows,1)
                expanded = 2*size(rows,1);
                expandedRows = cell(expanded,size(rows,2));
                expandedRows(1:size(rows,1),:) = rows;
                rows = expandedRows;
                expandedAccounting = cell(expanded,size(accountingRows,2));
                expandedAccounting(1:size(accountingRows,1),:) = accountingRows;
                accountingRows = expandedAccounting;
                expandedResiduals = zeros(expanded,1);
                expandedResiduals(1:numel(accountingResiduals)) = accountingResiduals;
                accountingResiduals = expandedResiduals;
            end
            rows(acceptedActions,:) = {string(key),path,position(1),position(2),channel,result,bearing,virtualTime,receiver,true};
            accountingRows(acceptedActions,:) = {string(key),path,stepCosts(1),sum(stepCosts(2:5)), ...
                stepSeconds,expectedTime,virtualTime,residual,timeValid,clock.now()};
            accountingResiduals(acceptedActions) = residual;
            cache(key) = struct('signature',signature,'response',response);
            pending = [];
            if ~timeValid
                needsStop = true;
                stopReason = 'Q3:TimeAccounting';
                safeLog(struct('event','time_accounting_error','requestId',key, ...
                    'expectedTime_s',expectedTime,'reportedTime_s',virtualTime,'residual_s',residual));
            end
            return
        end
        blocked = ~isempty(pending);
        error('Q3:Unresolved','The pending request exhausted its bounded normal and recovery stages.');
    end

    function success = safeLog(event)
        event.timestampUtc = clock.utc();
        event.clientElapsed_s = clock.now();
        success = true;
        try
            logger(event);
        catch errorInfo
            success = false;
            needsStop = true;
            if isempty(stopReason)
                stopReason = 'Q3:Log';
            end
            fallbackEvents{end+1,1} = event;
            logErrors(end+1) = struct('event',char(string(event.event)),'timestampUtc',event.timestampUtc, ...
                'clientElapsed_s',event.clientElapsed_s,'identifier',errorInfo.identifier,'message',errorInfo.message);
        end
    end

    function value = snapshot()
        elapsed = NaN;
        if ~isnan(enterStarted)
            ended = programEnded;
            if isnan(ended)
                ended = clock.now();
            end
            elapsed = ended-enterStarted;
        end
        names = {'RequestId','Path','X_m','Y_m','Channel','Result','Bearing_deg','VirtualTime_s','Receiver','Accepted'};
        accountingNames = {'RequestId','Path','Movement_m','FixedCost_s','Increment_s', ...
            'ExpectedTime_s','ReportedTime_s','Residual_s','Passed','ClientElapsed_s'};
        value = struct('entered',entered,'closed',closed,'unresolved',blocked || ~isempty(pending), ...
            'pending',pending,'lastUnsent',lastUnsent,'virtualTime',virtualTime,'position',position,'receiver',receiver, ...
            'clearedChannels',clearedChannels,'acceptedActions',acceptedActions,'programElapsed',elapsed, ...
            'log',cell2table(rows(1:acceptedActions,:),'VariableNames',names), ...
            'needsStop',needsStop,'stopReason',stopReason,'logErrors',logErrors,'fallbackEvents',{fallbackEvents}, ...
            'confirmedCosts',confirmedCosts,'accountingResiduals',accountingResiduals(1:acceptedActions), ...
            'accountingDetails',cell2table(accountingRows(1:acceptedActions,:),'VariableNames',accountingNames), ...
            'remainingRealSec',max(0,deadline-clock.now()),'deadline_s',deadline);
    end

    function success = finish()
        success = false;
        if ~entered || closed || blocked || ~isempty(pending) || clock.now() >= deadline
            return
        end
        exitPayload = struct('arena_id','default','robot_id',config.robotId, ...
            'request_id',[char(config.requestPrefix),'-recovery-exit']);
        try
            response = dispatch("/exit",exitPayload);
            success = response.accepted && closed;
        catch errorInfo
            safeLog(struct('event','recovery_exit_failed','identifier',errorInfo.identifier,'message',errorInfo.message));
        end
    end
end

function validateRequest(path,payload,robotId)
assert(isscalar(path) && ismember(path,["/enter","/measure","/clear","/exit"]), ...
    'Q3:Request','Only the four published exact paths are permitted.');
fields = {'arena_id';'robot_id';'request_id'};
if path == "/measure" || path == "/clear"
    fields = [fields;{'position';'channel'}];
end
assert(isstruct(payload) && isscalar(payload) && isequal(sort(fieldnames(payload)),sort(fields)), ...
    'Q3:Request','Unexpected or missing request fields.');
assert(strcmp(payload.arena_id,'default') && strcmp(payload.robot_id,robotId),'Q3:Request','Request identity mismatch.');
id = char(string(payload.request_id));
assert(isrow(id) && ~isempty(regexp(id,'^[A-Za-z0-9-]{1,128}$','once')),'Q3:Request','Invalid request ID.');
if isfield(payload,'position')
    assert(isstruct(payload.position) && isscalar(payload.position) ...
        && isequal(sort(fieldnames(payload.position)),{'x';'y'}) ...
        && validScalar(payload.position.x,-2e6,2e6) && validScalar(payload.position.y,-2e6,2e6) ...
        && validScalar(payload.channel,1,20) && fix(payload.channel) == payload.channel, ...
        'Q3:Request','Invalid position or channel.');
end
end

function validateResponse(path,response,previousTime)
assert(isfield(response,'virtual_time_s') && validScalar(response.virtual_time_s,previousTime-1e-6,Inf) ...
    && isfield(response,'real_timestamp_ms') && validScalar(response.real_timestamp_ms,0,Inf), ...
    'Q3:Response','Invalid response clocks; the request remains unresolved.');
if path == "/enter"
    fields = {'max_virtual_duration_s','max_real_duration_s','remaining_real_duration_s'};
    assert(all(isfield(response,fields)) && validScalar(response.max_virtual_duration_s,1,Inf) ...
        && validScalar(response.max_real_duration_s,1,Inf) ...
        && validScalar(response.remaining_real_duration_s,0,response.max_real_duration_s), ...
        'Q3:Response','Invalid entry time budget.');
elseif path == "/measure"
    assert(isfield(response,'measure_result') && isscalar(string(response.measure_result)) ...
        && ismember(string(response.measure_result),["no_signal","near","direction"]), ...
        'Q3:Response','Invalid measurement result.');
    if string(response.measure_result) == "direction"
        assert(isfield(response,'svd_deg') && validScalar(response.svd_deg,0,360) && response.svd_deg < 360, ...
            'Q3:Response','A direction response requires a finite bearing in [0,360).');
    end
elseif path == "/clear"
    assert(isfield(response,'clear_result') && isscalar(string(response.clear_result)) ...
        && ismember(string(response.clear_result),["success","no_target_in_range"]), ...
        'Q3:Response','Invalid clearing result.');
else
    assert(isfield(response,'exit_reason') && isscalar(string(response.exit_reason)) ...
        && string(response.exit_reason) == "user_exit",'Q3:Response','Invalid exit result.');
end
end

function packet = postJson(baseUrl,path,bodyText,timeout)
sendTimer = tic;
persistent netReady
if isempty(netReady)
    NET.addAssembly('System.Net.Http');
    netReady = true;
end
assert(validScalar(timeout,0.01,Inf),'Q3:RequestTimeout','A finite positive total HTTP timeout is required.');
httpHandler = System.Net.Http.HttpClientHandler;
httpHandler.UseProxy = false;
httpHandler.AllowAutoRedirect = false;
httpHandler.UseCookies = false;
httpClient = System.Net.Http.HttpClient(httpHandler);
clientCleanup = onCleanup(@() httpClient.Dispose());
httpClient.MaxResponseContentBufferSize = int64(1048576);
cancellation = System.Threading.CancellationTokenSource;
cancelCleanup = onCleanup(@() cancellation.Dispose());
content = System.Net.Http.StringContent(char(bodyText),System.Text.Encoding.UTF8,'application/json');
contentCleanup = onCleanup(@() content.Dispose());
try
    remaining = timeout-toc(sendTimer);
    if remaining <= 0.01
        error('Q3:RequestTimeout','HTTP setup exhausted the total request budget before sending.');
    end
    httpClient.Timeout = System.TimeSpan.FromSeconds(remaining);
    cancellation.CancelAfter(int32(max(1,floor(1000*remaining))));
    responseTask = httpClient.PostAsync([char(baseUrl),char(path)],content,cancellation.Token);
    while ~responseTask.IsCompleted
        remaining = timeout-toc(sendTimer);
        if remaining <= 0
            cancellation.Cancel();
            error('Q3:RequestTimeout','The complete HTTP request exceeded its total wall-clock timeout.');
        end
        pause(min(0.01,remaining));
    end
    response = responseTask.Result;
    responseCleanup = onCleanup(@() response.Dispose());
    textTask = response.Content.ReadAsStringAsync();
    responseText = char(textTask.Result);
    data = jsondecode(responseText);
    packet = struct('httpStatus',double(response.StatusCode),'body',data);
catch errorInfo
    cancellation.Cancel();
    rethrow(errorInfo)
end
end

function value = utcStamp()
value = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function appendJson(path,value)
bytes = unicode2native([jsonencode(value),newline],'UTF-8');
handle = fopen(path,'a','n','UTF-8');
assert(handle >= 0,'Q3:Log','Cannot open the request ledger.');
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
    'Q3:Log','Cannot persist the complete request ledger entry: %s',message);
end

function writeJson(path,value)
writeText(path,string(jsonencode(value,'PrettyPrint',true))+newline);
end

function [solution,failure] = solveRoute(exchange,config)
returnFailure = nargout >= 2;
workPolicy = "none";
if isfield(config,'workPolicy')
    workPolicy = string(config.workPolicy);
end
assert(isscalar(workPolicy) && ismember(workPolicy,["none","terminal","shared","terminal_shared","sensing","joint","joint_work","scout","scout_joint","hub","hub_scout","hub_joint","macro","macro_joint","macro_belief","range","joint_range","macro_range","scan_forecast","macro_scan"]),'Q3:WorkConfig','Unknown remaining-work policy.');
terminalWork = contains(workPolicy,"terminal");
sharedWork = contains(workPolicy,"shared");
mobileExact = false;
scoutActive = contains(workPolicy,"scout");
hubActive = startsWith(workPolicy,"hub");
hubCount = 0;
macroWork = startsWith(workPolicy,"macro");
mobileInformation = ismember(workPolicy,["scan_forecast","macro_scan"]);
config.rangeDominance = contains(workPolicy,"range");
scoutCounts = zeros(1,20);
retirementHistory = repmat(struct('serialBefore',0,'channel',0,'station',0,'futureSlots',[],'futureCenters',[],'negativeBefore',[],'certificate',struct,'promisedOnly',true),140,1);
retirementCount = 0;
config.workSensing = ismember(workPolicy,["sensing","joint","joint_work","scout_joint","hub_joint","macro_joint","macro_belief","joint_range","macro_range","macro_scan"]);
config.workJoint = ismember(workPolicy,["joint","joint_work","scout_joint","hub_joint","macro_joint","macro_belief","joint_range","macro_range","macro_scan"]);
config.workStations = zeros(0,2);
config.workCredits = zeros(0,1);
scanWork = zeros(1,0);
mobileMode = "none";
if isfield(config,'mobileMode')
    mobileMode = string(config.mobileMode);
end
assert(isscalar(mobileMode) && ismember(mobileMode,["none","incoming","through"]),'Q3:MobileConfig','Unknown mobile coverage policy.');
mobileHistory = struct([]);
mobileInitialPoints = zeros(0,2);
flexPolicy = "baseline";
if isfield(config,'flexPolicy')
    flexPolicy = string(config.flexPolicy);
end
assert(isscalar(flexPolicy) && ismember(flexPolicy,["baseline","step","free","step_free","try_clear","step_try_clear"]),'Q3:FlexConfig','Unknown research policy.');
flexStep = startsWith(flexPolicy,"step");
flexFree = contains(flexPolicy,"free");
flexTry = contains(flexPolicy,"try_clear");
flexAttempts = zeros(1,20);
flexTrialCounts = zeros(1,20);
flexProbeCounts = zeros(1,20);
config.flexFree = flexFree;
config.flexAllowance = false;
search = searchPolicy("legacy");
if isfield(config,'search')
    search = validateSearchPolicy(config.search);
end
route = "v040";
if isfield(config,'route')
    route = string(config.route);
end
assert(isscalar(route) && ismember(route,["v040","immediate_return","immediate_resume","batch_adaptive","batch_resume","joint_route","target_route","sweep_route","sweep_probe","joint_probe","path_probe"]), ...
    'Q3:RouteConfig','Unknown route policy.');
assert(route == "v040" || (search.enabled && config.variant == "seven_geometry"), ...
    'Q3:RouteConfig','Adaptive routes require the current seven-station search and geometry.');
tuning = coverageTuning("v070");
if isfield(config,'coverageTuning')
    tuning = validateCoverageTuning(config.coverageTuning);
end
emptyOriginLayout = "none";
if isfield(config,'emptyOriginLayout')
    emptyOriginLayout = string(config.emptyOriginLayout);
end
assert(isscalar(emptyOriginLayout) && ismember(emptyOriginLayout,["none","baseline","outer","middle"]), ...
    'Q3:LayoutPolicy','Unknown origin-feedback layout policy.');
layoutDecision = struct('policy',emptyOriginLayout,'applied',false,'serial',0, ...
    'reason',"Initial layout retained",'radius',search.radius,'rotation',search.rotation);
retiredCoverage = false(0,20);
decisions = struct([]);
decisionReason = "";
plannedStations = zeros(1,0);
estimatedStationDistance = 0;
plannerEvidence = struct;
negativePoints = repmat({zeros(0,2)},1,20);
observationPositions = repmat({zeros(0,2)},1,20);
routeProbeMeasures = 0;
forecastRejections = 0;
absenceReason = strings(1,20);
absenceProof = cell(1,20);
searchMeasures = 0;
opportunisticMeasures = 0;
points = zeros(0,2);
status = zeros(1,20);
coverage = false(0,20);
tracks = cell(1,20);
position = [0,0];
receiver = 1;
virtualTime = 0;
serial = 0;
costs = zeros(1,5);
localMoves = zeros(1,20);
localMeasures = zeros(1,20);
history = struct('channel',{},'anchor',{},'bound',{},'polygon',{});
phase = "initializing";
failureStage = "";
currentCoveragePoint = 0;
currentChannel = 0;
entered = false;
exited = false;
complete = false;
failure = struct('identifier','','message','','stack',struct('file',{},'name',{},'line',{}));
callbackErrors = struct('callback',{},'identifier',{},'message',{},'phase',{},'serial',{});
lastAction = struct('serial',0,'phase',phase,'path',"",'payload',struct, ...
    'response',struct,'accepted',false,'observationIntegrated',false);
lastAcceptedAction = lastAction;
try
    if config.variant == "grid_fold"
        points = zeros(16,2);
        rowValues = [-1800,-600,600,1800];
        for row = 1:4
            x = rowValues;
            if mod(row,2) == 0
                x = fliplr(x);
            end
            points((row-1)*4+(1:4),:) = [x',repmat(rowValues(row),4,1)];
        end
    else
        angle = (0:5)'*60;
        radius = 1500;
        if search.enabled
            angle = angle+search.rotation;
            radius = search.radius;
        end
        points = [0,0;radius*cosd(angle),radius*sind(angle)];
    end
    mobileInitialPoints = points;
    coverage = false(size(points,1),20);
    retiredCoverage = false(size(points,1),20);
    phase = "entering";
    act("/enter",[],[]);
    phase = "searching";
    checkpoint(true);
    if route == "v040"
    for pointIndex = 1:size(points,1)
        if search.enabled
            certifyUnseen();
            if all(status == 2 | status == 3)
                break
            end
        end
        currentCoveragePoint = pointIndex;
        phase = "searching";
        unseen = find(status == 0);
        unseen = scanOrder(unseen,receiver,search.enabled && search.alternateChannels);
        for channel = unseen
            if search.enabled && search.countLimit && sum(status == 1 | status == 2) == 16
                certifyUnseen();
                break
            end
            currentChannel = channel;
            response = act("/measure",points(pointIndex,:),channel);
            coverage(pointIndex,channel) = true;
            searchMeasures = searchMeasures+1;
            integrateSearch(channel,response);
            checkpoint(false);
        end
        while any(status == 1)
            phase = "selecting_target";
            pending = find(status == 1);
            estimates = zeros(numel(pending),2);
            for index = 1:numel(pending)
                track = tracks{pending(index)};
                if track.near
                    estimates(index,:) = track.anchor;
                elseif ~isempty(track.polygon)
                    estimates(index,:) = localCircle(track.polygon,config);
                else
                    estimates(index,:) = track.anchor + track.bound/2*[cosd(track.angle),sind(track.angle)];
                end
            end
            [~,nearest] = min(vecnorm(estimates-position,2,2));
            channel = pending(nearest);
            currentChannel = channel;
            serviceTarget(channel);
            if search.enabled
                certifyUnseen();
                reuseStop();
            end
        end
    end
    else
        adaptiveRoute();
    end
    phase = "certifying";
    if search.enabled
        certifyUnseen();
    else
        status(status == 0 & all(coverage,1)) = 3;
        absenceReason(status == 3) = "fixed_stations";
    end
    assert(all(status == 2 | status == 3),'Q3:Incomplete','Unresolved channels remain.');
    phase = "exiting";
    currentChannel = 0;
    act("/exit",[],[]);
    complete = true;
    phase = "completed";
    checkpoint(true);
    solution = snapshot();
catch errorInfo
    failureStage = phase;
    phase = "failed";
    complete = false;
    failure = struct('identifier',errorInfo.identifier,'message',errorInfo.message,'stack',errorInfo.stack);
    if isempty(failure.identifier)
        failure.identifier = 'Q3:UnidentifiedFailure';
    end
    commitDecision(false);
    notifyProgress();
    runCallback('snapshotFcn',snapshot());
    solution = snapshot();
    if ~returnFailure
        rethrow(errorInfo)
    end
end

    function adaptiveRoute()
        resumeHere = false;
        while any(status == 0 | status == 1)
            certifyUnseen();
            adaptEmptyOrigin();
            if all(status == 2 | status == 3)
                break
            end
            if ismember(route,["sweep_probe","joint_probe","path_probe"])
                probeHere();
            end
            if hubActive && hubCount < 4 && informationHub()
                continue
            end
            if scoutActive
                scoutHere();
                certifyUnseen();
                if all(status == 2 | status == 3)
                    break
                end
            end
            if config.workJoint
                updateWorkContext();
            end
            selectedStation = 0;
            selectedTarget = 0;
            if config.workJoint && any(status == 0)
                requiredAt = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
                matchingAt = requiredAt(vecnorm(points(requiredAt,:)-position,2,2) <= 1e-8);
                if ~isempty(matchingAt)
                    selectedStation = matchingAt(1);
                end
            end
            if sharedWork && any(status == 0) && serial > 21
                requiredHere = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
                requiredHere(requiredHere == 1) = [];
                [~,nearOrder] = sort(vecnorm(points(requiredHere,:)-position,2,2));
                mobileExact = true;
                for slot = requiredHere(nearOrder)
                    [~,sharedPlacement] = mobileStation(slot,zeros(0,2));
                    if ~isempty(sharedPlacement)
                        selectedStation = slot;
                        plannerEvidence = struct('kind',"shared_actual_stop",'mobileStation',sharedPlacement,'usesOnlyObservedState',true);
                        break
                    end
                end
                mobileExact = false;
            end
            if selectedStation > 0
                plannedStations = selectedStation;
            elseif startsWith(route,"sweep") && any(status == 0)
                required = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
                [order,estimatedStationDistance] = shortestStationPath(position,points(required,:));
                plannedStations = required(order);
                selectedStation = plannedStations(1);
                plannerEvidence = struct('kind',"finish_discovery_route",'requiredStations',required, ...
                    'order',plannedStations,'travel_m',estimatedStationDistance);
            elseif any(status == 1) && ismember(route,["joint_route","target_route","sweep_route","sweep_probe","joint_probe","path_probe"])
                pending = find(status == 1);
                required = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
                entry = zeros(numel(pending),2);
                exitPoint = zeros(numel(pending),2);
                for k = 1:numel(pending)
                    track = tracks{pending(k)};
                    if track.near
                        center = track.anchor;
                        boundRadius = 5;
                    else
                        [center,boundRadius] = localCircle(track.polygon,config);
                    end
                    exitPoint(k,:) = center;
                    if track.near || track.bound <= config.clearMargin
                        entry(k,:) = track.anchor;
                    elseif boundRadius <= config.clearMargin
                        entry(k,:) = center;
                    else
                        entry(k,:) = track.anchor+track.bound/(2*cosd(config.angleMargin))*[cosd(track.angle),sind(track.angle)];
                    end
                end
                if flexStep
                    for k = 1:numel(pending)
                        localConfig = config;
                        localConfig.flexAllowance = flexAttempts(pending(k)) < 2 && localMoves(pending(k)) < 8;
                        point = safeClearPoint(tracks{pending(k)},position,localConfig);
                        if isempty(point)
                            point = nextLocalizationPoint(tracks{pending(k)},position,localConfig);
                        end
                        entry(k,:) = point;
                        if ~terminalWork
                            exitPoint(k,:) = point;
                        elseif ~isempty(safeClearPoint(tracks{pending(k)},position,localConfig))
                            exitPoint(k,:) = point;
                        end
                    end
                end
                routeBeliefs = struct;
                if macroWork
                    representatives = cell(numel(pending)+numel(required),1);
                    for mk = 1:numel(pending)
                        macroTrack = tracks{pending(mk)};
                        if macroTrack.near
                            center = macroTrack.anchor;
                            representatives{mk} = center;
                        else
                            center = regionCentroid(macroTrack.polygon);
                            direction = [cosd(macroTrack.angle),sind(macroTrack.angle)];
                            [~,lo] = min(macroTrack.polygon*direction');
                            [~,hi] = max(macroTrack.polygon*direction');
                            representatives{mk} = [center;0.5*(center+macroTrack.polygon(lo,:));0.5*(center+macroTrack.polygon(hi,:))];
                        end
                        entry(mk,:) = center;
                        exitPoint(mk,:) = center;
                    end
                    for mk = 1:numel(required)
                        representatives{numel(pending)+mk} = points(required(mk),:);
                    end
                    if workPolicy == "macro_belief"
                        routeBeliefs = regionRouteGraph(position,representatives);
                    end
                end
                [eventOrder,estimatedStationDistance] = planServiceRoute(position, ...
                    [entry;points(required,:)],[exitPoint;points(required,:)],numel(pending),route == "target_route",scanWork,routeBeliefs);
                plannerEvidence = struct('kind',"estimated_service_route",'targetChannels',pending, ...
                    'requiredStations',required,'entryPoints',[entry;points(required,:)], ...
                    'exitEstimates',[exitPoint;points(required,:)],'eventOrder',eventOrder, ...
                    'estimatedTravel_m',estimatedStationDistance,'globalOptimalityProven',false);
                plannedStations = required(eventOrder(eventOrder > numel(pending))-numel(pending));
                if eventOrder(1) <= numel(pending)
                    selectedTarget = pending(eventOrder(1));
                else
                    selectedStation = required(eventOrder(1)-numel(pending));
                end
            end
            if any(status == 1) && selectedStation == 0
                pending = find(status == 1);
                estimates = zeros(numel(pending),2);
                for k = 1:numel(pending)
                    track = tracks{pending(k)};
                    if track.near
                        estimates(k,:) = track.anchor;
                    else
                        estimates(k,:) = localCircle(track.polygon,config);
                    end
                end
                [~,nearest] = min(vecnorm(estimates-position,2,2));
                currentChannel = pending(nearest);
                decisionReason = "Select the nearest current target estimate; finish this channel before selecting another task.";
                if selectedTarget > 0
                    currentChannel = selectedTarget;
                    decisionReason = "Select the next known target by the estimated open route through remaining service entries, exits, and required stations.";
                end
                if flexStep
                    decisionReason = "Plan the next actual action jointly with remaining stations; replan after each integrated feedback unless the finite fallback is locked.";
                    plannerEvidence.actionGranularity = "one_actual_action";
                end
                serviceTarget(currentChannel);
                certifyUnseen();
                reuseCoverageStop();
                resumeHere = ismember(route,["immediate_resume","batch_resume"]);
                if ~resumeHere || any(status == 1)
                    continue
                end
            end
            if resumeHere
                destination = position;
                currentCoveragePoint = 0;
                candidates = find(status == 0);
                take = false(size(candidates));
                for k = 1:numel(candidates)
                    observed = negativePoints{candidates(k)};
                    take(k) = isempty(observed) || ~any(vecnorm(observed-position,2,2) <= 1e-8);
                end
                candidates = candidates(take);
                decisionReason = "Resume scanning at the actual clear position; no return trip and no repeated negative at this point.";
            else
                required = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
                assert(~isempty(required),'Q3:RouteProgress','No remaining station for unresolved channels.');
                if selectedStation > 0
                    remaining = required(required ~= selectedStation);
                    [order,~] = shortestStationPath(points(selectedStation,:),points(remaining,:));
                    plannedStations = [selectedStation,remaining(order)];
                elseif route == "immediate_return"
                    plannedStations = required;
                    estimatedStationDistance = routeDistance(position,points(required,:));
                else
                    [order,estimatedStationDistance] = shortestStationPath(position,points(required,:));
                    plannedStations = required(order);
                    plannerEvidence = struct('kind',"exact_remaining_station_route",'requiredStations',required, ...
                        'order',plannedStations,'travel_m',estimatedStationDistance,'fixedStationOptimalityProven',true);
                end
                currentCoveragePoint = plannedStations(1);
                destination = points(currentCoveragePoint,:);
                candidates = find(status == 0 & ~coverage(currentCoveragePoint,:) & ~retiredCoverage(currentCoveragePoint,:));
                decisionReason = "Complete missing measured coverage at the next station of the shortest remaining open station route.";
                if selectedStation > 0
                    decisionReason = "Use the next fixed station chosen jointly with known targets; scan only unresolved channels at the actual station.";
                end
                if route == "immediate_return"
                    decisionReason = "Return to the first incomplete fixed station after the detected channel has been cleared.";
                end
            end
            if mobileMode ~= "none" && currentCoveragePoint > 1
                successor = zeros(0,2);
                if selectedStation > 0 && isfield(plannerEvidence,'eventOrder') && numel(plannerEvidence.eventOrder) > 1
                    successor = plannerEvidence.entryPoints(plannerEvidence.eventOrder(2),:);
                elseif numel(plannedStations) > 1
                    successor = points(plannedStations(2),:);
                end
                if mobileMode == "incoming"
                    successor = zeros(0,2);
                end
                [destination,placement] = mobileStation(currentCoveragePoint,successor);
                if ~isempty(placement)
                    plannerEvidence.mobileStation = placement;
                    decisionReason = decisionReason+" Relocate this remaining scan slot only after every affected channel retains certified continuous coverage using its real negatives and remaining planned observations.";
                end
            end
            nextChannels = zeros(1,0);
            if numel(plannedStations) > 1
                nextChannels = find(status == 0 & ~coverage(plannedStations(2),:) & ~retiredCoverage(plannedStations(2),:));
            end
            candidates = coverageScanOrder(candidates,receiver,nextChannels,tuning.scanMode);
            resumeHere = false;
            for candidate = candidates
                if status(candidate) ~= 0
                    continue
                end
                phase = "searching";
                currentChannel = candidate;
                response = act("/measure",destination,candidate);
                matched = vecnorm(points-position,2,2) <= 1e-8;
                coverage(matched,candidate) = true;
                searchMeasures = searchMeasures+1;
                if currentCoveragePoint == 0
                    opportunisticMeasures = opportunisticMeasures+1;
                end
                integrateSearch(candidate,response);
                certifyUnseen();
                checkpoint(false);
                if ~config.workJoint && ~tuning.finishStation && status(candidate) == 1 && (startsWith(route,"immediate") || ismember(route,["joint_route","joint_probe","path_probe"]))
                    break
                end
            end
        end
    end

    function moved = informationHub()
        moved = false;
        pendingHub = find(status == 1 & flexProbeCounts < 12 & localMoves < 8);
        if numel(pendingHub) < 3
            return
        end
        centersHub = zeros(numel(pendingHub),2);
        informative = false(1,numel(pendingHub));
        for hk = 1:numel(pendingHub)
            track = tracks{pendingHub(hk)};
            if track.near
                centersHub(hk,:) = track.anchor;
            else
                centersHub(hk,:) = regionCentroid(track.polygon);
                [~,radius] = minimumCircle(track.polygon);
                informative(hk) = radius > config.clearMargin;
            end
        end
        if sum(informative) < 3
            return
        end
        requiredHub = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
        allHub = [centersHub;points(requiredHub,:)];
        orderHub = planServiceRoute(position,allHub,allHub,numel(pendingHub),false);
        firstHub = allHub(orderHub(1),:);
        anglesHub = (0:7)'*45;
        directionsHub = [cosd(anglesHub),sind(anglesHub)];
        candidatesHub = [position+250*directionsHub;position+500*directionsHub;position+[0.25;0.5;0.75]*(firstHub-position)];
        forecastConfig = config;
        forecastConfig.workSensing = false;
        forecastConfig.flexFree = false;
        forecastConfig.flexAllowance = false;
        forecastConfig.improvement.nextPoint = false;
        forecastConfig.regionForecast = false;
        winnerHub = 0;
        winnerChannel = 0;
        bestNet = 0;
        bestEvidence = struct;
        for hi = 1:size(candidatesHub,1)
            at = candidatesHub(hi,:);
            if norm(at-position) < 5
                continue
            end
            gains = zeros(1,numel(pendingHub));
            for hk = find(informative)
                hubChannel = pendingHub(hk);
                track = tracks{hubChannel};
                if any(vecnorm(observationPositions{hubChannel}-at,2,2) <= 1e-8)
                    continue
                end
                estimate = centersHub(hk,:);
                if norm(estimate-at) > 1000
                    continue
                end
                before = estimatedServiceTime(track,at,receiver,hubChannel,estimate,forecastConfig);
                updated = track;
                updated.bound = min(1500,max(vecnorm(track.polygon-at,2,2))+1e-7);
                try
                    updated = updateTrack(updated,estimatedBearing(at,estimate),at,forecastConfig);
                    after = estimatedServiceTime(updated,at,hubChannel,hubChannel,estimate,forecastConfig);
                catch forecastFailure
                    if ismember(string(forecastFailure.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
                        continue
                    end
                    rethrow(forecastFailure)
                end
                if isfinite(before) && isfinite(after)
                    gains(hk) = max(0,before-after-7);
                end
            end
            extra = (norm(at-position)+norm(at-firstHub)-norm(firstHub-position))/5;
            net = sum(gains)-extra;
            if nnz(gains>0) >= 2 && net > bestNet+1e-8
                bestNet = net;
                winnerHub = hi;
                [~,bestChannel] = max(gains);
                winnerChannel = pendingHub(bestChannel);
                bestEvidence = struct('kind',"shared_information_hub",'channels',pendingHub,'sourceEstimates',centersHub, ...
                    'predictedIndividualSavings_s',gains,'insertionTravel_s',extra,'netHeuristic_s',net,'nextRoutePoint',firstHub, ...
                    'usesOnlyObservedRegion',true,'jointSavingsAdditivityUnproven',true,'hubBudgetBefore',hubCount);
            end
        end
        if winnerHub == 0
            return
        end
        hubChannel = winnerChannel;
        currentChannel = hubChannel;
        phase = "information_hub";
        plannerEvidence = bestEvidence;
        decisionReason = "Move to a bounded shared sensing stop when region-based predicted savings across multiple observed channels exceed insertion travel; integrate only the returned observation and replan.";
        response = act("/measure",candidatesHub(winnerHub,:),hubChannel);
        hubCount = hubCount+1;
        flexProbeCounts(hubChannel) = flexProbeCounts(hubChannel)+1;
        routeProbeMeasures = routeProbeMeasures+1;
        if response.measure_result == "no_signal"
            negativePoints{hubChannel}(end+1,:) = position;
            tracks{hubChannel} = applyNegativeHistory(tracks{hubChannel},negativePoints{hubChannel},config);
        else
            track = tracks{hubChannel};
            track.bound = min(1500,max(vecnorm(track.polygon-position,2,2))+1e-7);
            tracks{hubChannel} = updateTrack(track,response,position,config);
        end
        recordTrack(hubChannel);
        checkpoint(false);
        moved = true;
    end

    function scoutHere()
        if serial <= 21 || ~any(status == 0) || any(vecnorm(points-position,2,2) <= 1e-8)
            return
        end
        unknownScout = find(status == 0 & scoutCounts < 8);
        requiredScout = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
        if isempty(unknownScout) || isempty(requiredScout)
            return
        end
        [~,travelScout] = shortestStationPath(position,points(requiredScout,:));
        missingWork = sum(~coverage(:,unknownScout) & ~retiredCoverage(:,unknownScout),'all');
        totalWork = travelScout/5+6*missingWork;
        [sx,sy] = meshgrid(-1750:250:1750);
        cells = [sx(:),sy(:)];
        cells = cells(vecnorm(cells,2,2) <= 1800,:);
        added = vecnorm(cells-position,2,2) <= 1000;
        values = zeros(1,numel(unknownScout));
        for si = 1:numel(unknownScout)
            scoutChannel = unknownScout(si);
            old = negativePoints{scoutChannel};
            if any(vecnorm(old-position,2,2) <= 1e-8)
                continue
            end
            uncovered = true(size(cells,1),1);
            for ni = 1:size(old,1)
                uncovered = uncovered & vecnorm(cells-old(ni,:),2,2) > 1000;
            end
            values(si) = sum(uncovered & added)/max(1,sum(uncovered))*totalWork/numel(unknownScout);
        end
        chosenScout = unknownScout(values > 6);
        if isempty(chosenScout)
            return
        end
        orderedScout = scanOrder(chosenScout,receiver,true);
        scoutingPoint = position;
        for scoutChannel = orderedScout
            if status(scoutChannel) ~= 0
                continue
            end
            phase = "workload_scout";
            currentChannel = scoutChannel;
            plannerEvidence = struct('kind',"marginal_remaining_coverage_work",'unknownChannels',unknownScout,'marginalValues_s',values, ...
                'remainingWorkEstimate_s',totalWork,'quadratureSpacing_m',250,'notAnAbsenceProof',true,'budgetBefore',scoutCounts(scoutChannel));
            decisionReason = "At an already reached stop, buy bounded additional real scoutChannel observations when their geometric reduction of remaining scan work exceeds measurement cost; forecasts never establish absence.";
            response = act("/measure",scoutingPoint,scoutChannel);
            scoutCounts(scoutChannel) = scoutCounts(scoutChannel)+1;
            integrateSearch(scoutChannel,response);
            certifyUnseen();
            checkpoint(false);
        end
        retireCoveredWork();
    end

    function retireCoveredWork()
        for retireChannel = find(status == 0)
            requiredRetire = find(~coverage(:,retireChannel) & ~retiredCoverage(:,retireChannel))';
            [~,retireOrder] = sort(vecnorm(points(requiredRetire,:)-position,2,2),'descend');
            for station = requiredRetire(retireOrder)
                future = find(~coverage(:,retireChannel) & ~retiredCoverage(:,retireChannel))';
                future(future == station) = [];
                centers = unique([negativePoints{retireChannel};points(future,:)],'rows');
                [covered,certificate] = certifyNoSignalDiskCover(centers,1800,998,10,8192);
                if ~covered
                    continue
                end
                event = struct('serialBefore',serial,'channel',retireChannel,'station',station,'futureSlots',future, ...
                    'futureCenters',points(future,:),'negativeBefore',negativePoints{retireChannel},'certificate',certificate,'promisedOnly',true);
                retirementCount = retirementCount+1;
                retirementHistory(retirementCount) = event;
                retiredCoverage(station,retireChannel) = true;
            end
        end
    end

    function updateWorkContext()
        requiredWork = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
        config.workStations = points(requiredWork,:);
        config.workCredits = zeros(numel(requiredWork),1);
        pendingWork = find(status == 1);
        centersWork = zeros(numel(pendingWork),2);
        for wk = 1:numel(pendingWork)
            workTrack = tracks{pendingWork(wk)};
            if workTrack.near
                centersWork(wk,:) = workTrack.anchor;
            else
                centersWork(wk,:) = regionCentroid(workTrack.polygon);
            end
        end
        combinedWork = [centersWork;config.workStations];
        if ~isempty(combinedWork)
            orderWork = planServiceRoute(position,combinedWork,combinedWork,numel(pendingWork),false);
            pathWork = [position;combinedWork(orderWork,:)];
            for wk = 1:numel(requiredWork)
                offset = find(orderWork == numel(pendingWork)+wk,1)+1;
                credit = norm(pathWork(offset,:)-pathWork(offset-1,:));
                if offset < size(pathWork,1)
                    credit = credit+norm(pathWork(offset,:)-pathWork(offset+1,:))-norm(pathWork(offset-1,:)-pathWork(offset+1,:));
                end
                config.workCredits(wk) = max(0,credit)/5;
            end
        end
        scanWork = zeros(1,0);
        if workPolicy == "joint_work" && ~isempty(requiredWork)
            scanWork = remainingScanWork(negativePoints,status,coverage,retiredCoverage,points,requiredWork);
        end
    end

    function adaptEmptyOrigin()
        if emptyOriginLayout == "none" || layoutDecision.applied || ~all(coverage(1,:))
            return
        end
        allNegative = all(cellfun(@(centers)any(vecnorm(centers,2,2) <= 1e-8),negativePoints));
        if ~allNegative
            return
        end
        assert(all(status == 0) && ~any(coverage(2:end,:),'all') && norm(position) <= 1e-8, ...
            'Q3:LayoutState','Origin-only layout change must precede every outer-station observation.');
        if emptyOriginLayout == "baseline"
            search.radius = 1500;
            search.rotation = 30;
        elseif emptyOriginLayout == "outer"
            search.radius = 1500;
            search.rotation = 0;
        else
            search.radius = 1400;
            search.rotation = 0;
        end
        search = validateSearchPolicy(search);
        angle = (0:5)'*60+search.rotation;
        points = [0,0;search.radius*cosd(angle),search.radius*sind(angle)];
        mobileInitialPoints = points;
        layoutDecision = struct('policy',emptyOriginLayout,'applied',true,'serial',serial, ...
            'reason',"All twenty actual origin measurements returned no signal; choose the prevalidated outer layout before measuring any outer station.", ...
            'radius',search.radius,'rotation',search.rotation);
    end

    function probeHere()
        while true
            bestSaving = 0;
            winner = 0;
            evidence = struct;
            for probeChannel = find(status == 1)
                track = tracks{probeChannel};
                if (flexPolicy ~= "baseline" && flexProbeCounts(probeChannel) >= 12) || track.near || isempty(track.polygon) ...
                        || any(vecnorm(observationPositions{probeChannel}-position,2,2) <= 1e-8)
                    continue
                end
                [~,radius] = localCircle(track.polygon,config);
                if radius <= config.clearMargin
                    continue
                end
                estimate = mean(track.polygon,1);
                if norm(estimate-position) > 1000
                    continue
                end
                beforeTime = estimatedServiceTime(track,position,receiver,probeChannel,estimate,config);
                if ~isfinite(beforeTime)
                    forecastRejections = forecastRejections+1;
                    continue
                end
                updated = track;
                updated.bound = min(1500,max(vecnorm(track.polygon-position,2,2))+1e-7);
                hypothetical = estimatedBearing(position,estimate);
                try
                    updated = updateTrack(updated,hypothetical,position,config);
                catch forecastError
                    if ismember(string(forecastError.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
                        forecastRejections = forecastRejections+1;
                        continue
                    end
                    rethrow(forecastError)
                end
                afterTime = estimatedServiceTime(updated,position,probeChannel,probeChannel,estimate,config);
                if ~isfinite(afterTime)
                    forecastRejections = forecastRejections+1;
                    continue
                end
                probeCost = 5+double(receiver ~= probeChannel)+1;
                saving = beforeTime-afterTime-probeCost;
                if saving > bestSaving+1e-8
                    bestSaving = saving;
                    winner = probeChannel;
                    evidence = struct('kind',"stationary_information_probe",'channel',probeChannel, ...
                        'sourceEstimate',estimate,'estimatedServiceBefore_s',beforeTime, ...
                        'estimatedServiceAfter_s',afterTime,'probeAndExtraSwitchCost_s',probeCost, ...
                        'estimatedNetSaving_s',saving,'usesOnlyObservedRegion',true, ...
                        'expectedPositiveGuaranteed',all(vecnorm(track.polygon-position,2,2) <= 1000), ...
                        'globalOptimalityProven',false);
                end
            end
            if winner == 0
                break
            end
            currentChannel = winner;
            phase = "route_probe";
            plannerEvidence = evidence;
            decisionReason = "At this already required stop, remeasure a known uncleared channel only when region-based predicted service savings exceed the measurement and extra switching cost; preserve the valid anchor and bearing after no signal and apply conservative negative-history constraints when enabled.";
            response = act("/measure",position,winner);
            routeProbeMeasures = routeProbeMeasures+1;
            flexProbeCounts(winner) = flexProbeCounts(winner)+1;
            coverage(vecnorm(points-position,2,2) <= 1e-8,winner) = true;
            if response.measure_result == "no_signal"
                negativePoints{winner}(end+1,:) = position;
                tracks{winner} = applyNegativeHistory(tracks{winner},negativePoints{winner},config);
                recordTrack(winner);
            else
                track = tracks{winner};
                track.bound = min(1500,max(vecnorm(track.polygon-position,2,2))+1e-7);
                tracks{winner} = updateTrack(track,response,position,config);
                recordTrack(winner);
            end
            checkpoint(false);
        end
    end

    function serviceTarget(channel)
        currentChannel = channel;
            finishLocked = localMoves(channel) >= 8;
            for localStep = 1:16
                finishLocked = finishLocked || localMoves(channel) >= 8;
                phase = "localizing";
                track = tracks{channel};
                clearPoint = safeClearPoint(track,position,config);
                if ~isempty(clearPoint)
                    phase = "clearing";
                    response = act("/clear",clearPoint,channel);
                    localMoves(channel) = localMoves(channel)+1;
                    assert(response.clear_result == "success",'Q3:ClearFailed','A certified clear failed.');
                    status(channel) = 2;
                    checkpoint(true);
                    break
                end
                if flexTry && flexTrialCounts(channel) == 0 && ~finishLocked
                    [trialCenter,trialRadius] = localCircle(track.polygon,config);
                    if trialRadius <= 45
                        flexTrialCounts(channel) = 1;
                        trialPoint = trialCenter;
                        phase = "trial_clear";
                        response = act("/clear",trialPoint,channel);
                        localMoves(channel) = localMoves(channel)+1;
                        checkpoint(true);
                        if response.clear_result == "success"
                            status(channel) = 2;
                            break
                        end
                    end
                end
                localConfig = config;
                localConfig.flexAllowance = flexAttempts(channel) < 2 && ~finishLocked;
                [destination,nextBound,stepEvidence] = nextLocalizationPoint(track,position,localConfig);
                if isfield(stepEvidence,'exploratory') && stepEvidence.exploratory
                    flexAttempts(channel) = flexAttempts(channel)+1;
                end
                plannerEvidence.localizationStep = stepEvidence;
                if nextBound <= config.clearMargin
                    phase = "clearing";
                    response = act("/clear",destination,channel);
                    localMoves(channel) = localMoves(channel)+1;
                    assert(response.clear_result == "success",'Q3:ClearFailed','A contraction clear failed.');
                    status(channel) = 2;
                    checkpoint(true);
                    break
                end
                response = act("/measure",destination,channel);
                localMoves(channel) = localMoves(channel)+1;
                localMeasures(channel) = localMeasures(channel)+1;
                assert(response.measure_result ~= "no_signal",'Q3:SignalLost','A guaranteed reception step lost its signal.');
                track.bound = nextBound;
                tracks{channel} = updateTrack(track,response,position,config);
                recordTrack(channel);
                checkpoint(false);
                if flexStep && ~finishLocked
                    return
                end
                if route == "path_probe" && ~finishLocked
                    targetReason = decisionReason;
                    targetEvidence = plannerEvidence;
                    probeHere();
                    if tuning.duringLocalization
                        reuseCoverageStop();
                    end
                    currentChannel = channel;
                    decisionReason = targetReason;
                    plannerEvidence = targetEvidence;
                end
            end
            assert(status(channel) == 2,'Q3:LocalBudget','Local contraction exceeded its finite bound.');
    end

    function response = act(path,destination,channel)
        assert(serial == 0 || lastAction.observationIntegrated,'Q3:FeedbackOrder','Previous feedback has not been integrated.');
        basedOnRequestId = "";
        if serial > 0
            basedOnRequestId = string(lastAcceptedAction.payload.request_id);
        end
        serial = serial+1;
        lastAction = struct('serial',serial,'phase',phase,'path',path,'payload',struct, ...
            'response',struct,'accepted',false,'observationIntegrated',false);
        assert(serial <= config.maxActions,'Q3:ActionBudget','Action budget exceeded.');
        payload = struct('arena_id','default','robot_id',config.robotId, ...
            'request_id',sprintf('%s-%06d',config.requestPrefix,serial));
        if ~isempty(destination)
            payload.position = struct('x',destination(1),'y',destination(2));
            payload.channel = channel;
        end
        lastAction.payload = payload;
        reason = decisionReason;
        if phase == "localizing"
            reason = reason+" Use the latest conservative region and a certified finite contraction step; retain the original bearing step as fallback.";
        elseif phase == "clearing"
            reason = reason+" Latest near feedback, distance bound, or whole-region covering certificate verifies the configured clear margin.";
        elseif path == "/enter"
            reason = "Enter the current confirmed problem 3 case before issuing any measurement.";
        elseif path == "/exit"
            reason = "Every channel is either successfully cleared or has retained absence evidence.";
        elseif strlength(reason) == 0
            reason = "Complete the current fixed-station scan under the v0.4.0 baseline schedule.";
        end
        decisionRecord = struct('serial',serial,'requestId',string(payload.request_id), ...
            'basedOnRequestId',basedOnRequestId,'route',route,'phase',phase,'reason',reason, ...
            'request',payload,'path',path,'response',struct,'accepted',false,'integrated',false, ...
            'statusBefore',status,'statusAfter',status,'positionBefore',position,'positionAfter',position, ...
            'receiverBefore',receiver,'receiverAfter',receiver,'virtualBefore_s',virtualTime,'virtualAfter_s',virtualTime, ...
            'costsBefore',costs,'costsAfter',costs,'coverageAfter',coverage,'retiredCoverageAfter',retiredCoverage, ...
            'negativeCountsBefore',cellfun(@(x)size(x,1),negativePoints), ...
            'absenceReasonAfter',absenceReason,'plannedStations',plannedStations, ...
            'estimatedStationDistance_m',estimatedStationDistance,'plannerEvidence',plannerEvidence,'layoutDecision',layoutDecision);
        decisionRecord.trackBefore = [];
        if ~isempty(channel)
            decisionRecord.trackBefore = tracks{channel};
        end
        decisionRecord.trackAfter = decisionRecord.trackBefore;
        if isempty(decisions)
            decisions = decisionRecord;
        else
            decisions(serial) = decisionRecord;
        end
        runCallback('decisionFcn',struct('event',"decision",'record',decisions(serial)));
        response = exchange(path,payload);
        decisions(serial).response = response;
        decisions(serial).accepted = response.accepted;
        lastAction.response = response;
        assert(response.accepted,'Q3:Rejected','An action was rejected; state was not updated.');
        lastAction.accepted = true;
        lastAcceptedAction = lastAction;
        if ~isempty(destination)
            costs(1) = costs(1)+norm(destination-position);
            position = destination;
        end
        if path == "/measure"
            costs(2) = costs(2)+(receiver ~= channel);
            costs(3) = costs(3)+5;
            receiver = channel;
            observationPositions{channel}(end+1,:) = position;
            coverage(vecnorm(points-position,2,2) <= 1e-8,channel) = true;
        elseif path == "/clear"
            if response.clear_result == "success"
                costs(5) = costs(5)+5;
                status(channel) = 2;
            else
                costs(4) = costs(4)+3;
            end
        elseif path == "/enter"
            entered = true;
        elseif path == "/exit"
            exited = true;
        end
        virtualTime = response.virtual_time_s;
        lastAcceptedAction = lastAction;
    end

    function recordTrack(channel)
        track = tracks{channel};
        history(end+1) = struct('channel',channel,'anchor',track.anchor,'bound',track.bound,'polygon',track.polygon);
    end

    function integrateSearch(channel,response)
        if response.measure_result == "no_signal"
            negativePoints{channel}(end+1,:) = position;
        else
            status(channel) = 1;
            track = struct('anchor',position,'angle',NaN,'bound',1500,'polygon',[],'near',false);
            tracks{channel} = updateTrack(track,response,position,config);
            tracks{channel} = applyNegativeHistory(tracks{channel},negativePoints{channel},config);
            recordTrack(channel);
        end
    end

    function certifyUnseen()
        known = find(status == 1 | status == 2);
        assert(numel(known) <= 16,'Q3:SourceCount','More than sixteen source channels were observed.');
        for candidate = find(status == 0)
            if search.countLimit && numel(known) == 16
                status(candidate) = 3;
                absenceReason(candidate) = "count_limit";
                absenceProof{candidate} = struct('channels',known);
            elseif all(coverage(:,candidate)) && mobileMode == "none"
                status(candidate) = 3;
                absenceReason(candidate) = "fixed_stations";
            elseif search.observedCoverage && size(negativePoints{candidate},1) >= 6
                [covered,proof] = certifyNoSignalDiskCover(negativePoints{candidate});
                if covered
                    status(candidate) = 3;
                    absenceReason(candidate) = "observed_cover";
                    absenceProof{candidate} = proof;
                end
            end
        end
    end

    function [destination,placement] = mobileStation(station,successor)
        destination = points(station,:);
        placement = struct([]);
        channels = find(status == 0 & ~coverage(station,:) & ~retiredCoverage(station,:));
        if isempty(channels)
            return
        end
        otherCenters = cell(1,numel(channels));
        futureSlots = cell(1,numel(channels));
        futureCenters = cell(1,numel(channels));
        groups = cell(1,numel(channels));
        groupCount = 0;
        membership = zeros(1,numel(channels));
        for k = 1:numel(channels)
            mobileChannel = channels(k);
            remaining = find(~coverage(:,mobileChannel) & ~retiredCoverage(:,mobileChannel))';
            remaining(remaining == station) = [];
            futureSlots{k} = remaining;
            futureCenters{k} = points(remaining,:);
            otherCenters{k} = unique([negativePoints{mobileChannel};points(remaining,:)],'rows');
            match = find(cellfun(@(x)isequal(x,otherCenters{k}),groups(1:groupCount)),1);
            if isempty(match)
                groupCount = groupCount+1;
                groups{groupCount} = otherCenters{k};
                match = groupCount;
            end
            membership(k) = match;
        end
        groups = groups(1:groupCount);
        original = destination;
        goals = position;
        if ~isempty(successor)
            segment = successor-position;
            projection = position;
            if dot(segment,segment) > 1e-12
                fraction = min(1,max(0,dot(original-position,segment)/dot(segment,segment)));
                projection = position+fraction*segment;
            end
            goals = unique([projection;position;successor;0.5*(position+successor)],'rows','stable');
        end
        if mobileInformation
            orientation = atan2d(original(2),original(1));
            radii = [1100;1300;1500;1650;1730];
            directions = orientation+[-8,0,8];
            [candidateRadius,candidateAngle] = ndgrid(radii,directions);
            goals = unique([goals;original+[0.25;0.5;0.75]*(position-original);candidateRadius(:).*cosd(candidateAngle(:)),candidateRadius(:).*sind(candidateAngle(:))],'rows','stable');
        end
        bestCost = planningCost(original);
        initialCost = bestCost;
        bestProofs = cell(1,0);
        for goalIndex = 1:size(goals,1)
            goal = goals(goalIndex,:);
            if planningCost(goal) >= bestCost-1e-6 || norm(goal-original) < 1e-6
                continue
            end
            [valid,proofs] = promisedCover(goal);
            at = original;
            if valid
                at = goal;
            elseif ~mobileExact
                lower = 0;
                upper = 1;
                proofs = cell(1,0);
                for refinement = 1:6
                    fraction = 0.5*(lower+upper);
                    candidate = original+fraction*(goal-original);
                    [valid,certificate] = promisedCover(candidate);
                    if valid
                        lower = fraction;
                        at = candidate;
                        proofs = certificate;
                    else
                        upper = fraction;
                    end
                end
            end
            score = planningCost(at);
            if score < bestCost-1e-6 && ~isempty(proofs)
                destination = at;
                bestCost = score;
                bestProofs = proofs;
            end
        end
        if norm(destination-original) <= 1e-8
            return
        end
        points(station,:) = destination;
        placement = struct('serialBefore',serial,'station',station,'original',original, ...
            'destination',destination,'predecessor',position,'successor',successor,'channels',channels, ...
            'negativeBefore',{negativePoints(channels)},'futureSlots',{futureSlots}, ...
            'futureCenters',{futureCenters},'certificates',{bestProofs},'membership',membership, ...
            'promisedOnly',true,'oldLocalTravel_m',travelCost(original),'newLocalTravel_m',travelCost(destination), ...
            'forecastActive',mobileInformation,'planningObjectiveBefore',initialCost,'planningObjectiveAfter',bestCost, ...
            'guaranteedReceptionRadius_m',1000,'certificateRadius_m',998);
        if isempty(mobileHistory)
            mobileHistory = placement;
        else
            mobileHistory(end+1) = placement;
        end

        function cost = travelCost(at)
            cost = norm(at-position);
            if ~isempty(successor)
                cost = cost+norm(successor-at);
            end
        end

        function cost = planningCost(at)
            if ~mobileInformation
                cost = travelCost(at);
                return
            end
            slots = find(any(~coverage(:,status == 0) & ~retiredCoverage(:,status == 0),2))';
            slots(slots == station) = [];
            if isempty(slots)
                orderedSlots = station;
                futureTravel = 0;
            else
                [forecastOrder,futureTravel] = shortestStationPath(at,points(slots,:));
                orderedSlots = [station,slots(forecastOrder)];
            end
            forecastRoute = [at;points(orderedSlots(2:end),:)];
            cost = (norm(at-position)+futureTravel)/5;
            knownCount = sum(status == 1 | status == 2);
            presentCount = (max(0,10-knownCount)+max(0,16-knownCount))/2;
            occupancy = min(1,presentCount/max(1,sum(status == 0)));
            [fx,fy] = meshgrid(-1750:250:1750);
            samplePoints = [fx(:),fy(:)];
            samplePoints = samplePoints(vecnorm(samplePoints,2,2) <= 1800,:);
            for fcChannel = channels
                oldNegative = negativePoints{fcChannel};
                keep = true(size(samplePoints,1),1);
                for fn = 1:size(oldNegative,1)
                    keep = keep & vecnorm(samplePoints-oldNegative(fn,:),2,2) > 1000;
                end
                samples = samplePoints(keep,:);
                active = find(~coverage(orderedSlots,fcChannel) & ~retiredCoverage(orderedSlots,fcChannel));
                if isempty(samples)
                    cost = cost+6*numel(active);
                    continue
                end
                first = zeros(size(samples,1),1);
                detour = zeros(size(samples,1),1);
                for fa = 1:numel(active)
                    forecastIndex = active(fa);
                    found = first == 0 & vecnorm(samples-forecastRoute(forecastIndex,:),2,2) <= 1000;
                    first(found) = fa;
                    arrival = vecnorm(samples(found,:)-forecastRoute(forecastIndex,:),2,2);
                    if forecastIndex < size(forecastRoute,1)
                        arrival = arrival+vecnorm(samples(found,:)-forecastRoute(forecastIndex+1,:),2,2)-norm(forecastRoute(forecastIndex,:)-forecastRoute(forecastIndex+1,:));
                    end
                    detour(found) = arrival;
                end
                first(first == 0) = numel(active);
                cost = cost+6*((1-occupancy)*numel(active)+occupancy*mean(first))+occupancy*mean(detour)/5;
            end
        end

        function [valid,proofs] = promisedCover(at)
            valid = true;
            proofs = cell(1,numel(groups));
            for groupIndex = 1:numel(groups)
                [covered,certificate] = certifyNoSignalDiskCover([groups{groupIndex};at],1800,998,10,8192);
                if ~covered
                    valid = false;
                    proofs = cell(1,0);
                    return
                end
                proofs{groupIndex} = certificate;
            end
        end
    end

    function reuseCoverageStop()
        if tuning.reuse == "none" || any(vecnorm(points-position,2,2) <= 1e-8)
            return
        end
        channels = coverageScanOrder(find(status == 0),receiver,zeros(1,0),tuning.scanMode);
        for candidate = channels
            if status(candidate) ~= 0
                continue
            end
            previous = negativePoints{candidate};
            if any(vecnorm(previous-position,2,2) <= 1e-8)
                continue
            end
            required = find(~coverage(:,candidate) & ~retiredCoverage(:,candidate))';
            [station,proof,future] = coverageReplacement(previous,position,points,required,tuning.reuse);
            if station < 0
                continue
            end
            phase = "opportunistic_search";
            currentChannel = candidate;
            plannerEvidence = struct('kind',"actual_stop_coverage_reuse",'retireStation',station, ...
                'negativeBefore',previous,'futureStations',future,'prospectiveCover',proof, ...
                'forecastOnly',true,'expectedMeasurementCost_s',5+double(receiver ~= candidate));
            decisionReason = "Measure an unresolved channel at the actual required stop. Only a real no-signal response can replace a future station measurement; planned stations are never actual absence evidence.";
            response = act("/measure",position,candidate);
            searchMeasures = searchMeasures+1;
            opportunisticMeasures = opportunisticMeasures+1;
            integrateSearch(candidate,response);
            if response.measure_result == "no_signal" && station > 0
                retiredCoverage(station,candidate) = true;
            end
            certifyUnseen();
            checkpoint(false);
        end
    end

    function reuseStop()
        if search.reuseMode == "none"
            return
        end
        channels = scanOrder(find(status == 0),receiver,search.alternateChannels);
        for candidate = channels
            if status(candidate) ~= 0
                continue
            end
            previous = negativePoints{candidate};
            if isempty(previous) || any(vecnorm(previous-position,2,2) < 1e-6)
                continue
            end
            takeMeasure = false;
            if search.reuseMode == "frontier"
                takeMeasure = min(vecnorm(previous-position,2,2)) >= search.separation;
            elseif size(previous,1) >= 5
                takeMeasure = certifyNoSignalDiskCover([previous;position]);
            end
            if ~takeMeasure
                continue
            end
            phase = "opportunistic_search";
            currentChannel = candidate;
            response = act("/measure",position,candidate);
            searchMeasures = searchMeasures+1;
            opportunisticMeasures = opportunisticMeasures+1;
            integrateSearch(candidate,response);
            certifyUnseen();
            checkpoint(false);
        end
    end

    function checkpoint(critical)
        lastAction.observationIntegrated = true;
        lastAcceptedAction = lastAction;
        commitDecision(true);
        notifyProgress();
        if critical && isfield(config,'snapshotFcn') && ~isempty(config.snapshotFcn)
            runCallback('snapshotFcn',snapshot());
        end
    end

    function commitDecision(integrated)
        if serial < 1 || numel(decisions) < serial
            return
        end
        decisions(serial).integrated = integrated;
        decisions(serial).statusAfter = status;
        decisions(serial).positionAfter = position;
        decisions(serial).receiverAfter = receiver;
        decisions(serial).virtualAfter_s = virtualTime;
        decisions(serial).costsAfter = costs;
        decisions(serial).coverageAfter = coverage;
        decisions(serial).retiredCoverageAfter = retiredCoverage;
        decisions(serial).absenceReasonAfter = absenceReason;
        if isfield(lastAction.payload,'channel')
            decisions(serial).trackAfter = tracks{lastAction.payload.channel};
        end
        runCallback('decisionFcn',struct('event',"feedback",'record',decisions(serial)));
    end

    function value = snapshot()
        value = struct('status',status,'coverage',coverage,'points',points,'costs',costs, ...
            'localMoves',localMoves,'localMeasures',localMeasures,'history',history,'virtualTime',virtualTime);
        value.tracks = tracks;
        value.position = position;
        value.receiver = receiver;
        value.serial = serial;
        value.phase = phase;
        value.failureStage = failureStage;
        value.currentCoveragePoint = currentCoveragePoint;
        value.currentChannel = currentChannel;
        value.entered = entered;
        value.exited = exited;
        value.complete = complete;
        value.lastAction = lastAction;
        value.lastAcceptedAction = lastAcceptedAction;
        value.failure = failure;
        value.callbackErrors = callbackErrors;
        value.search = search;
        value.layoutDecision = layoutDecision;
        value.coverageTuning = tuning;
        value.retiredCoverage = retiredCoverage;
        value.route = route;
        if isfield(config,'improvement')
            value.improvement = config.improvement;
        end
        value.decisions = decisions;
        value.negativePoints = negativePoints;
        value.absenceReason = absenceReason;
        value.absenceProof = absenceProof;
        value.searchMeasures = searchMeasures;
        value.opportunisticMeasures = opportunisticMeasures;
        value.routeProbeMeasures = routeProbeMeasures;
        value.forecastRejections = forecastRejections;
        value.hubCount = hubCount;
        value.scoutCounts = scoutCounts;
        value.retirementHistory = retirementHistory(1:retirementCount);
        value.workPolicy = workPolicy;
        value.flexPolicy = flexPolicy;
        value.flexAttempts = flexAttempts;
        value.flexTrialCounts = flexTrialCounts;
        value.flexProbeCounts = flexProbeCounts;
        value.mobileMode = mobileMode;
        value.mobileHistory = mobileHistory;
        value.mobileInitialPoints = mobileInitialPoints;
    end

    function notifyProgress()
        if ~isfield(config,'progressFcn') || isempty(config.progressFcn)
            return
        end
        progress = struct('phase',phase,'failureStage',failureStage,'position',position,'receiver',receiver, ...
            'virtualTime',virtualTime,'costs',costs,'status',status,'clearedCount',sum(status == 2), ...
            'detectedCount',sum(status == 1),'absentCount',sum(status == 3),'unseenCount',sum(status == 0), ...
            'currentCoveragePoint',currentCoveragePoint,'currentChannel',currentChannel, ...
            'serial',serial,'entered',entered,'exited',exited,'complete',complete, ...
            'lastAction',lastAction,'lastAcceptedAction',lastAcceptedAction,'failure',failure, ...
            'callbackErrors',callbackErrors);
        runCallback('progressFcn',progress);
    end

    function runCallback(name,value)
        if ~isfield(config,name) || isempty(config.(name))
            return
        end
        try
            callback = config.(name);
            assert(isa(callback,'function_handle'),'Q3:Callback','A configured callback must be a function handle.');
            callback(value);
        catch callbackError
            callbackErrors(end+1) = struct('callback',name,'identifier',callbackError.identifier, ...
                'message',callbackError.message,'phase',phase,'serial',serial);
        end
    end
end

function track = updateTrack(track,response,position,config)
track.anchor = position;
if isfield(config,'rangeDominance') && config.rangeDominance
    if ~isfield(track,'positiveCenters')
        track.positiveCenters = position;
    else
        track.positiveCenters = unique([track.positiveCenters;position],'rows','stable');
    end
end
track.near = response.measure_result == "near";
if track.near
    track.bound = min(track.bound,5);
    return
end
track.angle = response.svd_deg;
if config.variant ~= "seven_geometry"
    return
end
if isempty(track.polygon)
    track.polygon = diskPolygon([0,0],1800,config.diskSides);
end
track.polygon = clipDisk(track.polygon,position,track.bound,config.diskSides);
track.polygon = clipWedge(track.polygon,position,track.angle,config.angleMargin);
assert(~isempty(track.polygon),'Q3:EmptyRegion','A positive observation produced an empty conservative region.');
track.bound = min(track.bound,max(vecnorm(track.polygon-position,2,2))+1e-7);
if isfield(track,'negativeCenters')
    track = applyNegativeHistory(track,track.negativeCenters,config);
end
end

function polygon = diskPolygon(center,radius,sides)
angle = ((0:sides-1)' + 0.5)*360/sides;
polygon = center + radius/cosd(180/sides)*[cosd(angle),sind(angle)];
end

function polygon = clipDisk(polygon,center,radius,sides)
for angle = (0:sides-1)*360/sides
    normal = [cosd(angle),sind(angle)];
    polygon = clipPlane(polygon,normal,dot(normal,center)+radius);
end
end

function polygon = clipWedge(polygon,anchor,angle,delta)
lower = [cosd(angle-delta),sind(angle-delta)];
upper = [cosd(angle+delta),sind(angle+delta)];
normal = [lower(2),-lower(1)];
polygon = clipPlane(polygon,normal,dot(normal,anchor));
normal = [-upper(2),upper(1)];
polygon = clipPlane(polygon,normal,dot(normal,anchor));
end

function result = clipPlane(polygon,normal,bound)
if isempty(polygon)
    result = polygon;
    return
end
tolerance = 1e-8;
bound = bound+tolerance;
values = polygon*normal'-bound;
result = zeros(2*size(polygon,1),2);
count = 0;
previous = size(polygon,1);
for current = 1:size(polygon,1)
    insideCurrent = values(current) <= 0;
    insidePrevious = values(previous) <= 0;
    if insideCurrent ~= insidePrevious
        ratio = values(previous)/(values(previous)-values(current));
        count = count+1;
        result(count,:) = polygon(previous,:)+ratio*(polygon(current,:)-polygon(previous,:));
    end
    if insideCurrent
        count = count+1;
        result(count,:) = polygon(current,:);
    end
    previous = current;
end
result = result(1:count,:);
end

function [center,radius] = boxCircle(polygon)
center = (min(polygon,[],1)+max(polygon,[],1))/2;
radius = max(vecnorm(polygon-center,2,2));
end

function [exchange,report] = makeWorld(sources)
assert(size(sources,2) == 5 && size(sources,1) >= 1 && size(sources,1) <= 20,'Q3:Input','Invalid source matrix.');
assert(all(isfinite(sources),'all') && numel(unique(sources(:,1))) == size(sources,1),'Q3:Input','Invalid source values.');
assert(all(sources(:,1) >= 1 & sources(:,1) <= 20 & fix(sources(:,1)) == sources(:,1)),'Q3:Input','Invalid channels.');
assert(all(vecnorm(sources(:,2:3),2,2) <= 1800+1e-8) && all(sources(:,4) >= 1000 & sources(:,4) <= 1500),'Q3:Input','Invalid geometry.');
position = [0,0];
receiver = 1;
virtualTime = 0;
active = false;
closed = false;
cleared = false(size(sources,1),1);
cache = containers.Map('KeyType','char','ValueType','any');
logRows = cell(0,10);
exchange = @dispatch;
report = @snapshot;

    function response = dispatch(path,payload)
        path = string(path);
        key = char(string(payload.request_id));
        signature = char(path + "|" + string(jsonencode(payload)));
        if isKey(cache,key)
            stored = cache(key);
            assert(strcmp(stored.signature,signature),'Q3:Conflict','The request ID was reused with different content.');
            response = stored.response;
            return
        end
        assert(~closed,'Q3:Closed','The offline session is closed.');
        response = struct('accepted',true,'real_timestamp_ms',0,'virtual_time_s',virtualTime);
        bearing = NaN;
        channel = NaN;
        if path == "/enter"
            assert(~active,'Q3:State','Already entered.');
            active = true;
            response.max_virtual_duration_s = 360000;
            response.max_real_duration_s = 1200;
            response.remaining_real_duration_s = 1200;
            result = "entered";
        elseif path == "/exit"
            assert(active,'Q3:State','Not entered.');
            active = false;
            closed = true;
            response.exit_reason = "user_exit";
            result = "user_exit";
        else
            assert(active && ismember(path,["/measure","/clear"]),'Q3:State','Invalid action.');
            destination = [payload.position.x,payload.position.y];
            channel = payload.channel;
            assert(all(isfinite(destination)) && all(abs(destination) <= 2e6),'Q3:Input','Invalid position.');
            assert(isscalar(channel) && isfinite(channel) && channel >= 1 && channel <= 20 && fix(channel) == channel,'Q3:Input','Invalid channel.');
            travel = sqrt(sum((destination-position).^2));
            position = destination;
            sourceIndex = find(sources(:,1) == channel & ~cleared,1);
            distance = Inf;
            if ~isempty(sourceIndex)
                distance = sqrt(sum((sources(sourceIndex,2:3)-position).^2));
            end
            if path == "/measure"
                virtualTime = virtualTime+travel/5+double(receiver ~= channel)+5;
                receiver = channel;
                result = "no_signal";
                if ~isempty(sourceIndex) && distance <= sources(sourceIndex,4)
                    if distance <= 5
                        result = "near";
                    else
                        result = "direction";
                        offset = spatialError(position,channel,sources(sourceIndex,5));
                        direction = atan2d(sources(sourceIndex,3)-position(2),sources(sourceIndex,2)-position(1));
                        bearing = mod(round(mod(direction+offset,360),2),360);
                        response.svd_deg = bearing;
                    end
                end
                response.measure_result = result;
            else
                success = ~isempty(sourceIndex) && distance <= 20;
                virtualTime = virtualTime+travel/5+3+2*success;
                result = "no_target_in_range";
                if success
                    cleared(sourceIndex) = true;
                    result = "success";
                end
                response.clear_result = result;
            end
        end
        response.virtual_time_s = virtualTime;
        assert(virtualTime <= 360000,'Q3:VirtualBudget','Virtual budget exceeded.');
        cache(key) = struct('signature',signature,'response',response);
        logRows(end+1,:) = {string(key),path,position(1),position(2),channel,result,bearing,virtualTime,receiver,true};
    end

    function value = snapshot()
        names = {'RequestId','Path','X_m','Y_m','Channel','Result','Bearing_deg','VirtualTime_s','Receiver','Accepted'};
        value = struct('cleared',cleared,'time',virtualTime,'receiver',receiver,'log',cell2table(logRows,'VariableNames',names));
    end
end

function value = spatialError(position,channel,mode)
if mode == 1
    value = 1;
elseif mode == -1
    value = -1;
elseif mode == 2
    value = sign(sin(position(1)*0.017+position(2)*0.023+channel));
elseif mode == 3
    value = 0;
else
    value = sin(position(1)*0.013+channel)*cos(position(2)*0.019-channel*0.2);
end
end

function scenarios = buildScenarios()
previous = rng;
cleanup = onCleanup(@() rng(previous));
rng(20260911,'twister');
scenarios = struct('name',{},'sources',{});
for index = 1:14
    count = 10+mod(index-1,7);
    channels = sort(randperm(20,count))';
    angle = 360*rand(count,1);
    radius = 1800*sqrt(rand(count,1));
    reach = 1000+500*rand(count,1);
    errorMode = zeros(count,1);
    if index == 1
        angle = 30+(0:count-1)'*360/count;
        radius(:) = 1800;
        reach(:) = 1000;
        errorMode(:) = 1;
    elseif index == 2
        angle = (0:count-1)'*360/count;
        radius(:) = 1799.99;
        reach(:) = 1000;
        errorMode(:) = -1;
    elseif index == 3
        radius = linspace(0,1800,count)';
        angle(:) = 359.99;
        errorMode(:) = 2;
    elseif index == 4
        radius(:) = 900;
        reach(:) = 1500;
        errorMode(:) = 3;
    elseif index == 5
        radius(1:4) = [0;5;5.001;20];
        reach(:) = 1000;
    elseif index == 6
        angle(:) = 60;
        radius = linspace(500,1750,count)';
        errorMode(:) = 1;
    elseif index == 7
        reach(:) = 1000;
        errorMode(:) = 2;
    end
    scenarios(index).name = sprintf('S%02d',index);
    scenarios(index).sources = [channels,radius.*cosd(angle),radius.*sind(angle),reach,errorMode];
end
end

function [boundValid,polygonValid] = checkHistory(history,sources)
boundValid = true;
polygonValid = true;
for index = 1:numel(history)
    entry = history(index);
    target = sources(sources(:,1) == entry.channel,2:3);
    boundValid = boundValid && norm(target-entry.anchor) <= entry.bound+1e-6;
    if ~isempty(entry.polygon)
        polygon = entry.polygon;
        next = polygon([2:end,1],:);
        edge = next-polygon;
        relative = target-polygon;
        crossValue = edge(:,1).*relative(:,2)-edge(:,2).*relative(:,1);
        polygonValid = polygonValid && all(crossValue >= -1e-5);
    end
end
end

function checks = validateCore(settings)
names = strings(0,1);
values = false(0,1);
factor = 1/(2*cosd(settings.angleMargin));
add("Contraction factor below one",factor < 1);
add("First contracted step guarantees reception",1500*factor < 1000);
add("Seven steps suffice with clear margin",1500*factor^7 < settings.clearMargin);
add("Six steps alone are insufficient",1500*factor^6 > 20);
distance = linspace(0,1500,10001)';
angle = linspace(-settings.angleMargin,settings.angleMargin,17);
step = 1500*factor;
newDistance = sqrt(max(0,distance.^2+step^2-2*distance*step.*cosd(angle)));
add("Contraction endpoint and interior verification",max(newDistance,[],'all') <= step+1e-9);
coverBound = max(1500/sqrt(3),sqrt(1800^2+1500^2-2*1800*1500*cosd(30)));
add("Seven-point analytic reception bound",coverBound < 1000);
add("Sixteen-point analytic reception bound",600*sqrt(2) < 1000);
polygon = diskPolygon([0,0],1800,settings.diskSides);
add("Circumscribed polygon contains circular boundary",min(vecnorm(polygon,2,2)) > 1800);
polygon = clipWedge(polygon,[0,0],359.99,settings.angleMargin);
testPoint = 1000*[cosd(0.99),sind(0.99)];
[inside,on] = inpolygon(testPoint(1),testPoint(2),polygon(:,1),polygon(:,2));
add("Bearing wrap-around includes endpoint",inside || on);
triangle = [0,0;40,0;20,20*sqrt(3)];
[~,radius] = boxCircle(triangle);
add("Diameter 40 does not trigger guaranteed clear",radius > 20);
sources = [1,0,0,1000,1;2,1000,0,1000,-1;3,1500,0,1500,0];
[exchange,report] = makeWorld(sources);
exchange("/enter",payload('t-enter',[],[]));
r = exchange("/measure",payload('t-near',[0,0],1));
add("Near at zero distance has no bearing",r.measure_result == "near" && ~isfield(r,'svd_deg'));
r = exchange("/measure",payload('t-r1000',[0,0],2));
add("Reception radius endpoint 1000",r.measure_result == "direction");
r = exchange("/measure",payload('t-r1500',[0,0],3));
add("Reception radius endpoint 1500",r.measure_result == "direction");
r = exchange("/measure",payload('t-out',[-0.01,0],3));
add("Beyond reception radius is no_signal",r.measure_result == "no_signal");
exchange("/measure",payload('t-same',[0,0],2));
r1 = exchange("/measure",payload('t-repeat',[0,0],2));
r2 = exchange("/measure",payload('t-repeat',[0,0],2));
add("Identical request retry has no extra time",r1.virtual_time_s == r2.virtual_time_s);
r3 = exchange("/measure",payload('t-fresh',[0,0],2));
add("Repeated location has fixed error and detection cost",r1.svd_deg == r3.svd_deg && abs(r3.virtual_time_s-r1.virtual_time_s-5) < 1e-10);
r = exchange("/clear",payload('t-fail',[20.001,0],1));
add("Clear outside 20 fails",r.clear_result == "no_target_in_range");
r = exchange("/clear",payload('t-clear',[20,0],1));
state = report();
add("Clear at 20 succeeds and preserves receiver",r.clear_result == "success" && state.receiver == 2);
expectedTime = 5+6+6+0.01/5+5+0.01/5+6+5+5+20.001/5+3+0.001/5+5;
add("Independent mixed-action time accounting",abs(state.time-expectedTime) < 1e-9);
badChannel = false;
try
    exchange("/measure",payload('t-invalid',[0,0],21));
catch errorInfo
    badChannel = strcmp(errorInfo.identifier,'Q3:Input');
end
add("Illegal channel is rejected",badChannel);
idConflict = false;
try
    exchange("/measure",payload('t-repeat',[1,0],2));
catch errorInfo
    idConflict = strcmp(errorInfo.identifier,'Q3:Conflict');
end
add("Changed body with reused ID is rejected",idConflict);
rejectionHandled = false;
config = settings;
config.variant = "seven_fold";
try
    solveRoute(@(~,~) struct('accepted',false,'virtual_time_s',0),config);
catch errorInfo
    rejectionHandled = strcmp(errorInfo.identifier,'Q3:Rejected');
end
add("Rejected actions stop the strategy",rejectionHandled);
onlineBlocked = false;
try
    problem3("practice");
catch errorInfo
    onlineBlocked = strcmp(errorInfo.identifier,'Q3:PracticeConfig');
end
add("Practice without GUI confirmation is rejected before I/O",onlineBlocked);
formalBlocked = false;
try
    problem3("formal");
catch errorInfo
    formalBlocked = strcmp(errorInfo.identifier,'Q3:FormalAuthorization');
end
add("Formal mode without recorded authorization is rejected before I/O",formalBlocked);
practiceConfig = struct('robotId','LOCAL_PROTOCOL_TEST','caseCode','LOCAL-ONLY', ...
    'baseUrl','http://127.0.0.1:2026','confirmedProblem',3,'confirmedMode','practice', ...
    'confirmedAtIso',utcStamp());
badUrl = false;
practiceConfig.baseUrl = 'http://example.com:2026';
try
    validatePracticeConfig(practiceConfig,fileparts(mfilename('fullpath')));
catch errorInfo
    badUrl = strcmp(errorInfo.identifier,'Q3:PracticeConfig');
end
add("Non-loopback practice URL is rejected before I/O",badUrl);
practiceConfig.baseUrl = 'http://127.0.0.1:2026';
practiceConfig = validatePracticeConfig(practiceConfig,fileparts(mfilename('fullpath')));
practiceConfig.requestPrefix = 'local-test';
practiceConfig.retryPauseSec = 0;
practiceConfig.recoveryAttempts = 0;
transportChecks = validateTransport(practiceConfig);
for index = 1:height(transportChecks)
    add(transportChecks.Check(index),transportChecks.Passed(index));
end
checks = table(names,values,'VariableNames',{'Check','Passed'});

    function add(name,value)
        names(end+1,1) = name;
        values(end+1,1) = value;
    end
end

function checks = validateTransport(config)
tests = ["retry","reject","conflict","unresolved"];
names = strings(numel(tests),1);
passed = false(numel(tests),1);
fault = "";
faultCalls = 0;
signatures = strings(0,1);
backend = [];
for testIndex = 1:numel(tests)
    test = tests(testIndex);
    fault = test;
    faultCalls = 0;
    signatures = strings(0,1);
    [backend,worldReport] = makeWorld([1,0,0,1000,1;2,1000,0,1000,-1]);
    [exchange,report,finish] = makeTransport(config,@sendMock,@(~) []);
    exchange("/enter",localPayload('test-enter',[],[]));
    first = exchange("/measure",localPayload('test-first',[0,0],2));
    caught = "";
    try
        response = exchange("/measure",localPayload('test-fault',[0,0],2));
    catch errorInfo
        caught = string(errorInfo.identifier);
    end
    state = report();
    if test == "retry"
        world = worldReport();
        value = caught == "" && faultCalls == 2 && isscalar(unique(signatures)) ...
            && response.virtual_time_s == first.virtual_time_s+5 && state.acceptedActions == 3 ...
            && state.virtualTime == world.time && ~state.unresolved;
        names(testIndex) = "Lost-response retry preserves body and ID and counts once";
    elseif test == "reject"
        recovered = finish();
        after = report();
        value = caught == "Q3:Rejected" && state.virtualTime == first.virtual_time_s ...
            && state.acceptedActions == 2 && ~state.unresolved && recovered && after.closed;
        names(testIndex) = "Business rejection preserves confirmed clock and allows one exit";
    elseif test == "conflict"
        recovered = finish();
        value = caught == "Q3:Conflict" && state.unresolved && ~recovered && faultCalls == 1;
        names(testIndex) = "HTTP 409 stops without issuing a new recovery action";
    else
        recovered = finish();
        value = caught == "Q3:Unresolved" && state.unresolved && ~recovered ...
            && faultCalls == config.maxAttempts && isscalar(unique(signatures)) ...
            && state.virtualTime == first.virtual_time_s;
        names(testIndex) = "Exhausted retries retain pending request and block a new exit";
    end
    passed(testIndex) = value;
end
checks = table(names,passed,'VariableNames',{'Check','Passed'});

    function value = localPayload(id,position,channel)
        value = payload(id,position,channel);
        value.robot_id = config.robotId;
    end

    function packet = sendMock(~,path,body,~)
        request = jsondecode(body);
        if strcmp(request.request_id,'test-fault')
            faultCalls = faultCalls+1;
            signatures(end+1,1) = string(path)+"|"+string(body);
            if fault == "reject" || fault == "conflict"
                code = 200;
                if fault == "conflict"
                    code = 409;
                end
                packet = struct('httpStatus',code,'body',struct('accepted',false,'real_timestamp_ms',0,'virtual_time_s',0));
                return
            end
            response = backend(path,request);
            if fault == "unresolved" || faultCalls == 1
                error('Q3:SimulatedResponseLoss','Offline-only injected response loss.');
            end
        else
            response = backend(path,request);
        end
        packet = struct('httpStatus',200,'body',response);
    end
end

function value = payload(id,position,channel)
value = struct('arena_id','default','robot_id','OFFLINE_SYNTHETIC','request_id',id);
if ~isempty(position)
    value.position = struct('x',position(1),'y',position(2));
    value.channel = channel;
end
end

function makeFigures(outputPath,summary,scenarios,details,settings)
fontName = 'Microsoft YaHei';
figureOne = figure('Visible','off','Color','w','Position',[100,100,1100,460]);
layout = tiledlayout(figureOne,1,2,'Padding','compact','TileSpacing','compact');
axesOne = nexttile(layout);
angles = linspace(0,2*pi,361);
hold(axesOne,'on');
points = details{1,3}.solution.points;
for index = 1:7
    plot(axesOne,points(index,1)+1000*cos(angles),points(index,2)+1000*sin(angles),'Color',[0.68,0.78,0.86],'LineWidth',0.8);
end
plot(axesOne,1800*cos(angles),1800*sin(angles),'k-','LineWidth',1.5);
plot(axesOne,points(:,1),points(:,2),'o','MarkerFaceColor',[0.12,0.4,0.65],'MarkerEdgeColor','k');
axis(axesOne,'equal');
grid(axesOne,'on');
xlabel(axesOne,'东向坐标 / m');
ylabel(axesOne,'北向坐标 / m');
title(axesOne,'七点发现覆盖：最坏最近距离 901.93 m 以下');
axesTwo = nexttile(layout);
factor = 1/(2*cosd(settings.angleMargin));
semilogy(axesTwo,0:7,1500*factor.^(0:7),'o-','LineWidth',1.6);
hold(axesTwo,'on');
yline(axesTwo,20,'--','清除半径 20 m','LabelHorizontalAlignment','left');
grid(axesTwo,'on');
xlabel(axesTwo,'保证前进步数');
ylabel(axesTwo,'相对当前点的距离上界 / m');
title(axesTwo,'折半逼近的解析上界');
set(findall(figureOne,'-property','FontName'),'FontName',fontName);
exportgraphics(figureOne,fullfile(outputPath,'图1_覆盖与有限定位.png'),'Resolution',160);
savefig(figureOne,fullfile(outputPath,'图1_覆盖与有限定位.fig'));
close(figureOne);
figureTwo = figure('Visible','off','Color','w','Position',[100,100,1200,490]);
layout = tiledlayout(figureTwo,1,2,'Padding','compact','TileSpacing','compact');
axesOne = nexttile(layout);
times = reshape(summary.VirtualTime_s,3,[])';
bar(axesOne,times);
xlabel(axesOne,'自建案例编号');
ylabel(axesOne,'总虚拟时间 / s');
title(axesOne,'相同自建场景的三种策略对照');
legend(axesOne,{'16点＋折半','7点＋折半','7点＋几何提前清除'},'Location','northoutside');
grid(axesOne,'on');
axesTwo = nexttile(layout);
trajectory = details{1,3}.world.log;
hold(axesTwo,'on');
plot(axesTwo,1800*cos(angles),1800*sin(angles),'k--');
pathHandle = plot(axesTwo,trajectory.X_m,trajectory.Y_m,'-','Color',[0.2,0.45,0.7],'LineWidth',1);
sources = scenarios(1).sources;
truthHandle = scatter(axesTwo,sources(:,2),sources(:,3),48,'k','x','LineWidth',1.5);
success = trajectory.Result == "success";
clearHandle = scatter(axesTwo,trajectory.X_m(success),trajectory.Y_m(success),55,'o','MarkerEdgeColor',[0.75,0.2,0.15]);
axis(axesTwo,'equal');
grid(axesTwo,'on');
xlabel(axesTwo,'东向坐标 / m');
ylabel(axesTwo,'北向坐标 / m');
title(axesTwo,'自建 S01：真值仅用于事后核验');
legend(axesTwo,[pathHandle,truthHandle,clearHandle],{'行动轨迹','自建源真值','清除位置'},'Location','northoutside');
set(findall(figureTwo,'-property','FontName'),'FontName',fontName);
exportgraphics(figureTwo,fullfile(outputPath,'图2_自建对照与轨迹.png'),'Resolution',160);
savefig(figureTwo,fullfile(outputPath,'图2_自建对照与轨迹.fig'));
close(figureTwo);
end

function result = persistPracticeOutputs(solution,state,result,config,settings)
saveErrors = struct('artifact',{},'identifier',{},'message',{});
if isfield(solution,'route') || isfield(solution,'decisions')
    persist('逐步决策.csv',@() writetable(routeDecisionTable(solution),fullfile(config.outputPath,'逐步决策.csv'),'Encoding','UTF-8'));
end
if isfield(solution,'layoutDecision')
    persist('布局决策.json',@() writeJson(fullfile(config.outputPath,'布局决策.json'), ...
        struct('decision',solution.layoutDecision,'actualSearch',solution.search,'actualPoints',solution.points)));
end
persist('actions.csv',@() writetable(state.log,fullfile(config.outputPath,'actions.csv'),'Encoding','UTF-8'));
persist('逐步计费.csv',@() writetable(state.accountingDetails,fullfile(config.outputPath,'逐步计费.csv'),'Encoding','UTF-8'));
persist('频道核验.csv',@() writetable(channelCertificate(solution,state),fullfile(config.outputPath,'频道核验.csv'),'Encoding','UTF-8'));
persist('覆盖证书.csv',@() writetable(array2table(solution.coverage,'VariableNames',cellstr("Channel"+(1:20))),fullfile(config.outputPath,'覆盖证书.csv'),'Encoding','UTF-8'));
persist('清除证书.csv',@() writetable(clearCertificate(solution,state),fullfile(config.outputPath,'清除证书.csv'),'Encoding','UTF-8'));
result.saveErrors = saveErrors;
if ~isempty(saveErrors)
    result.complete = false;
    result.status = upper(string(result.mode))+"_INCOMPLETE";
end
persist('solution.mat',@() savePracticeMat(fullfile(config.outputPath,'solution.mat'),solution,state,result,config,settings));
result.saveErrors = saveErrors;
if ~isempty(saveErrors)
    result.complete = false;
    result.status = upper(string(result.mode))+"_INCOMPLETE";
end
persist('结果摘要.md',@() writeText(fullfile(config.outputPath,'结果摘要.md'),practiceSummary(result,solution)));
result.saveErrors = saveErrors;
if ~isempty(saveErrors)
    result.complete = false;
    result.status = upper(string(result.mode))+"_INCOMPLETE";
end
try
    writeJson(fullfile(config.outputPath,'result.json'),result);
catch errorInfo
    result.complete = false;
    result.status = upper(string(result.mode))+"_INCOMPLETE";
    result.saveErrors(end+1) = struct('artifact','result.json','identifier',errorInfo.identifier,'message',errorInfo.message);
    fprintf(2,'结果JSON保存失败，最后已确认清除数为%d，模拟时间%.6f秒。\n',result.clearedCount,state.virtualTime);
    try
        savePracticeMat(fullfile(config.outputPath,'emergency-result.mat'),solution,state,result,config,settings);
    catch backupError
        fprintf(2,'备用结果保存失败：%s\n',backupError.message);
    end
end
    function persist(name,operation)
        try
            operation();
        catch errorInfo
            saveErrors(end+1) = struct('artifact',name,'identifier',errorInfo.identifier,'message',errorInfo.message);
        end
    end
end

function complete = practiceComplete(solution,failure,state)
count = numel(state.clearedChannels);
complete = isempty(failure.identifier) && solution.complete && state.closed && ~state.unresolved ...
    && ~state.needsStop && isempty(state.logErrors) && isempty(solution.callbackErrors) ...
    && count >= 10 && count <= 16 && all(solution.status == 2 | solution.status == 3) ...
    && isequal(sort(find(solution.status == 2)),sort(state.clearedChannels));
if complete && isfield(solution,'search') && solution.search.enabled
    complete = isfield(state,'log') && verifySearchEvidence(solution,state.log);
end
if complete && isfield(solution,'route') && solution.route ~= "v040"
    complete = verifyRouteDecisions(solution,state.log);
end
if complete && isfield(solution,'coverageTuning') && isfield(solution,'search') && solution.search.enabled
    complete = isfield(state,'log') && verifyCoverageDecisions(solution,state.log) && independentAbsenceCover(solution,state.log) && verifyLayoutDecision(solution,state.log);
end
end

function savePracticeMat(path,solution,state,result,config,settings)
executionRecord = result;
executionRecord.executionChecksPassed = result.complete;
executionRecord = rmfield(executionRecord,{'complete','status'});
executionRecord.recordType = 'EXECUTION_EVIDENCE_SNAPSHOT';
executionRecord.completionAuthority = 'Only result.json complete=true establishes final saved completion. If absent or unreadable, the saved result is incomplete.';
save(path,'solution','state','executionRecord','config','settings');
end

function saveSnapshot(path,snapshot)
assert(~isfolder(path),'Q3:Snapshot','Snapshot path is a directory: %s',path);
parent = fileparts(path);
temporary = [tempname(parent),'.mat'];
save(temporary,'snapshot');
assert(~isfolder(path),'Q3:Snapshot','Snapshot path became a directory: %s',path);
[ok,message] = movefile(temporary,path,'f');
assert(ok && isfile(path),'Q3:Snapshot','Cannot commit checkpoint: %s',message);
end

function value = channelCertificate(solution,state)
channel = (1:20)';
confirmedClear = ismember(channel,state.clearedChannels);
solverStatus = solution.status(:);
stationsMeasured = sum(solution.coverage,1)';
statusText = strings(20,1);
statusText(:) = "尚未排除";
statusText(solverStatus == 1) = "已发现待清除";
statusText(solverStatus == 3) = "实际覆盖排除";
if isfield(solution,'absenceReason')
    statusText(solution.absenceReason(:) == "count_limit") = "已知16源上限排除";
    statusText(solution.absenceReason(:) == "observed_cover") = "实际无信号连续覆盖排除";
end
statusText(confirmedClear) = "清除回执成功";
value = table(channel,confirmedClear,solverStatus,stationsMeasured,statusText, ...
    'VariableNames',{'Channel','ConfirmedCleared','SolverStatus','StationsMeasured','Evidence'});
end

function value = clearCertificate(solution,state)
channels = state.clearedChannels(:);
radius = NaN(numel(channels),1);
clearPoint = NaN(numel(channels),2);
method = strings(numel(channels),1);
for index = 1:numel(channels)
    channel = channels(index);
    row = find(state.log.Path == "/clear" & state.log.Channel == channel & state.log.Result == "success",1,'last');
    clearPoint(index,:) = [state.log.X_m(row),state.log.Y_m(row)];
    track = solution.tracks{channel};
    if isempty(track)
        method(index) = "回执成功，求解器几何尚未同步";
    elseif track.near
        radius(index) = norm(clearPoint(index,:)-track.anchor)+track.bound;
        method(index) = "near距离界";
    elseif ~isempty(track.polygon)
        radius(index) = max(vecnorm(track.polygon-clearPoint(index,:),2,2));
        method(index) = "候选区域顶点距离上界";
        radialBound = norm(clearPoint(index,:)-track.anchor)+track.bound;
        if radialBound < radius(index)
            radius(index) = radialBound;
            method(index) = "已证距离界覆盖";
        end
        step = track.bound/(2*cosd(1.01));
        contractedPoint = track.anchor+step*[cosd(track.angle),sind(track.angle)];
        if norm(clearPoint(index,:)-contractedPoint) <= 1e-7 && step+1e-7 < radius(index)
            radius(index) = step+2e-7;
            method(index) = "有限收缩距离上界";
        end
    else
        method(index) = "有限收缩距离界，见轨迹记录";
    end
end
value = table(channels,clearPoint(:,1),clearPoint(:,2),radius,method, ...
    'VariableNames',{'Channel','ClearX_m','ClearY_m','GeometricUpperBound_m','Evidence'});
end

function text = practiceSummary(result,solution)
modeLabel = '演练';
if string(result.mode) == "formal"
    modeLabel = '正式测试';
end
verdict = "检查发现异常，需查看最终状态记录";
if result.complete
    verdict = "执行检查通过；最终保存状态以result.json为准";
end
text = sprintf('问题3%s结果：%s\n\n案例：%s\n\n已确认清除：%d个（按不同频道成功回执统计）\n\n模拟总时间：%.6f秒\n\n平均每源模拟时间：%.6f秒\n\n客户端现实运行时间：%.6f秒\n\n已覆盖排除频道：%d个\n\n只有同目录result.json中的complete=true表示结果完整保存；缺失或不可读均按记录不完整处理。\n\n本摘要不包含未知的源总数；正式测试不披露真值总数，不能填写未知分母。\n', ...
    modeLabel,verdict,result.caseCode,result.clearedCount,result.virtualTime_s,result.meanClearTime_s, ...
    result.clientProgramElapsed_s,sum(solution.status == 3));
if ~isempty(result.failure.identifier)
    text = [text,sprintf('\n异常：%s — %s\n',result.failure.identifier,result.failure.message)];
end
end

function [update,finish] = makeProgress(config)
lastCleared = zeros(1,0);
lastSerial = -1;
window = [];
label = [];
if config.showProgressWindow
    try
        window = figure('Name','问题3演练进度','NumberTitle','off','MenuBar','none','ToolBar','none', ...
            'Color',[0.96,0.97,0.99],'Position',[70,80,560,320]);
        label = uicontrol(window,'Style','text','Units','normalized','Position',[0.06,0.08,0.88,0.84], ...
            'HorizontalAlignment','left','FontName','Microsoft YaHei','FontSize',15,'BackgroundColor',[0.96,0.97,0.99], ...
            'String',{'问题3演练','准备进入；成功数量以模拟器回执为准。'});
        drawnow;
    catch errorInfo
        fprintf(2,'进度窗口不可用，改用日志和进度文件：%s\n',errorInfo.message);
    end
end
update = @refresh;
finish = @closeWindow;

    function refresh(progress)
        cleared = find(progress.status == 2);
        newlyCleared = setdiff(cleared,lastCleared);
        for channel = newlyCleared
            fprintf('清除成功：频道%d；累计已清除%d个；模拟耗时%.3f秒。\n',channel,numel(cleared),progress.virtualTime);
        end
        lastCleared = cleared;
        if progress.serial == lastSerial && progress.phase ~= "failed"
            return
        end
        lastSerial = progress.serial;
        lines = {sprintf('问题3演练 · %s',config.caseCode),sprintf('已确认清除：%d个',numel(cleared)), ...
            sprintf('模拟耗时：%.3f秒',progress.virtualTime),sprintf('当前指令序号：%d',progress.serial), ...
            sprintf('待定位：%d个；已排空：%d个频道',progress.detectedCount,progress.absentCount), ...
            '数量只按成功回执增加；没有使用隐藏源总数。'};
        if ~isempty(label) && isgraphics(label)
            set(label,'String',lines);
            drawnow limitrate;
        end
        writeJson(fullfile(config.outputPath,'实时进度.json'),progress);
        writeText(fullfile(config.outputPath,'实时进度.md'),strjoin(lines,sprintf('\n\n')));
    end

    function closeWindow()
        if ~isempty(window) && isgraphics(window)
            close(window);
        end
    end
end

function writeText(path,value)
assert(~isfolder(path),'Q3:Output','Output path is a directory: %s',path);
bytes = unicode2native(char(value),'UTF-8');
temporary = [tempname(fileparts(path)),'.tmp'];
handle = fopen(temporary,'wb');
assert(handle >= 0,'Q3:Output','Cannot open output: %s',temporary);
cleanup = onCleanup(@() quietClose(handle));
count = fwrite(handle,bytes,'uint8');
closeStatus = fclose(handle);
assert(count == numel(bytes) && closeStatus == 0,'Q3:Output','Incomplete output write: %s',temporary);
assert(~isfolder(path),'Q3:Output','Output path became a directory: %s',path);
[ok,message] = movefile(temporary,path,'f');
assert(ok && isfile(path),'Q3:Output','Cannot commit output: %s',message);
end

function quietClose(handle)
try
    fclose(handle);
catch
end
end

function output = runOffline(root,settings,checks,outputPath,scenarios,variants,actionBudgets,strict)
if nargin < 5
    scenarios = buildScenarios();
    variants = ["grid_fold","seven_fold","seven_geometry"];
    actionBudgets = repmat(settings.maxActions,numel(scenarios),numel(variants));
    strict = true;
end
assert(isfolder(root) && isfolder(outputPath),'Q3:Output','An existing task output directory is required.');
records = cell(numel(scenarios)*numel(variants),1);
details = cell(numel(scenarios),numel(variants));
for sceneIndex = 1:numel(scenarios)
    scene = scenarios(sceneIndex);
    sourceTable = array2table(scene.sources,'VariableNames',{'Channel','X_m','Y_m','Radius_m','ErrorMode'});
    writetable(sourceTable,fullfile(outputPath,sprintf('自建场景_%02d.csv',sceneIndex)),'Encoding','UTF-8');
    for variantIndex = 1:numel(variants)
        config = settings;
        config.variant = variants(variantIndex);
        config.maxActions = actionBudgets(sceneIndex,variantIndex);
        [exchange,report] = makeWorld(scene.sources);
        timer = tic;
        [solution,failure] = solveRoute(exchange,config);
        runSucceeded = isempty(failure.identifier);
        elapsed = toc(timer);
        world = report();
        sourceChannels = scene.sources(:,1);
        fullClear = runSucceeded && all(world.cleared) && all(solution.status(sourceChannels) == 2);
        absenceValid = all(solution.status(setdiff(1:20,sourceChannels)) == 3);
        [boundValid,polygonValid] = checkHistory(solution.history,scene.sources);
        timeResidual = abs(solution.costs(1)/5 + sum(solution.costs(2:5)) - world.time);
        certificateValid = verifySearchEvidence(solution,world.log);
        localLimitsValid = all(solution.localMoves <= 7) && all(solution.localMeasures <= 6);
        record = struct('Scenario',string(scene.name),'Variant',config.variant,'SourceCount',height(sourceTable), ...
            'Cleared',sum(world.cleared),'ClearRatio',sum(world.cleared)/height(sourceTable), ...
            'VirtualTime_s',world.time,'MeanClearTime_s',world.time/sum(world.cleared), ...
            'LocalWallTime_s',elapsed,'Distance_m',solution.costs(1),'Switches',solution.costs(2), ...
            'Measures',solution.costs(3)/5,'FailedClears',solution.costs(4)/3, ...
            'SuccessClears',solution.costs(5)/5,'Actions',height(world.log), ...
            'FullClear',fullClear,'AbsenceValid',absenceValid,'BoundValid',boundValid, ...
            'PolygonValid',polygonValid,'CertificateValid',certificateValid, ...
            'LocalLimitsValid',localLimitsValid,'TimeResidual_s',timeResidual, ...
            'RunSucceeded',runSucceeded,'FailureIdentifier',string(failure.identifier),'FailureMessage',string(failure.message));
        records{(sceneIndex-1)*numel(variants)+variantIndex} = record;
        details{sceneIndex,variantIndex} = struct('solution',solution,'world',world,'failure',failure);
        writetable(world.log,fullfile(outputPath,sprintf('动作_%02d_%s.csv',sceneIndex,config.variant)),'Encoding','UTF-8');
        writetable(array2table(solution.coverage,'VariableNames',cellstr("Channel"+(1:20))), ...
            fullfile(outputPath,sprintf('覆盖证书_%02d_%s.csv',sceneIndex,config.variant)),'Encoding','UTF-8');
        save(fullfile(outputPath,sprintf('现场_%02d_%s.mat',sceneIndex,config.variant)),'solution','world','failure');
        fprintf('%s | %s | %d/%d | %.3f s\n',scene.name,config.variant,sum(world.cleared),height(sourceTable),world.time);
    end
end
summary = struct2table(vertcat(records{:}));
passed = all(summary.RunSucceeded & summary.FullClear & summary.AbsenceValid & summary.BoundValid & summary.PolygonValid ...
    & summary.CertificateValid & summary.LocalLimitsValid & summary.TimeResidual_s < 1e-7);
checks = [checks; table("All synthetic strategy runs",passed,'VariableNames',{'Check','Passed'})];
writetable(checks,fullfile(outputPath,'必要验证.csv'),'Encoding','UTF-8');
writetable(summary,fullfile(outputPath,'自建案例结果总表.csv'),'Encoding','UTF-8');
aggregate = table(variants',NaN(numel(variants),1),NaN(numel(variants),1),NaN(numel(variants),1),NaN(numel(variants),1),NaN(numel(variants),1), ...
    'VariableNames',{'Variant','MeanVirtualTime_s','MinVirtualTime_s','MaxVirtualTime_s','MeanPerSourceTime_s','MaxLocalWallTime_s'});
for index = 1:numel(variants)
    rows = summary.Variant == variants(index) & summary.RunSucceeded & summary.FullClear;
    if ~any(rows)
        continue
    end
    aggregate.MeanVirtualTime_s(index) = mean(summary.VirtualTime_s(rows));
    aggregate.MinVirtualTime_s(index) = min(summary.VirtualTime_s(rows));
    aggregate.MaxVirtualTime_s(index) = max(summary.VirtualTime_s(rows));
    aggregate.MeanPerSourceTime_s(index) = mean(summary.MeanClearTime_s(rows));
    aggregate.MaxLocalWallTime_s(index) = max(summary.LocalWallTime_s(rows));
end
comparison = table;
if isequal(variants,["grid_fold","seven_fold","seven_geometry"])
    times = reshape(summary.VirtualTime_s,3,[])';
    comparison = table(string({scenarios.name})',times(:,2),times(:,3),100*(times(:,2)-times(:,3))./times(:,2), ...
        'VariableNames',{'Scenario','SevenFold_s','SevenGeometry_s','GeometryReduction_pct'});
end
writetable(aggregate,fullfile(outputPath,'策略汇总.csv'),'Encoding','UTF-8');
if ~isempty(comparison)
    writetable(comparison,fullfile(outputPath,'几何改进逐例对照.csv'),'Encoding','UTF-8');
end
save(fullfile(outputPath,'完整结果.mat'),'settings','scenarios','summary','aggregate','comparison','details','checks');
if passed && numel(variants) == 3 && strict
    makeFigures(outputPath,summary,scenarios,details,settings);
end
output = struct('path',outputPath,'summary',summary,'checks',checks,'version',settings.version);
if strict
    assert(all(checks.Passed),'Q3:Validation','A required validation failed; partial cases and batch results were saved.');
end
fprintf('OFFLINE_RECORDED | %d/%d checks | %s\n',sum(checks.Passed),height(checks),outputPath);
end

function checks = validateBatch(settings)
root = fileparts(mfilename('fullpath'));
outputPath = fullfile(root,'运行结果',char("batch_failure_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
mkdir(outputPath);
sources = [(1:10)',zeros(10,2),1000*ones(10,1),zeros(10,1)];
scenarios = struct('name',{'EXPECTED_FAILURE','FOLLOWING_SUCCESS'},'sources',{sources,sources});
emptyChecks = table(strings(0,1),false(0,1),'VariableNames',{'Check','Passed'});
result = runOffline(root,settings,emptyChecks,outputPath,scenarios,"seven_geometry",[22;2000],false);
summary = result.summary;
saved = load(fullfile(outputPath,'现场_01_seven_geometry.mat'));
names = ["Failed batch case preserves its partial clear";"Independent case continues after a failed case";"Failed batch is never marked as all passed";"Failed case action and snapshot evidence exist"];
passed = [~summary.RunSucceeded(1) && summary.Cleared(1) == 1 && sum(saved.solution.status == 2) == 1; ...
    summary.RunSucceeded(2) && summary.Cleared(2) == 10; ...
    ~all(result.checks.Passed); ...
    isfile(fullfile(outputPath,'动作_01_seven_geometry.csv')) && strcmp(saved.failure.identifier,'Q3:ActionBudget')];
checks = table(names,passed,'VariableNames',{'Check','Passed'});
writetable(checks,fullfile(outputPath,'批次异常核验.csv'),'Encoding','UTF-8');
end

function checks = validateTransportExtended(config)
testIds = ["request_log","clear_log","cleanup_log","late_recovery","enter_loss", ...
    "clear_loss","exit_loss","exit_unresolved","short_budget","zero_budget", ...
    "retry_deadline","recovery_window","accounting","expand","http400", ...
    "http500","bad_body","http200_reject","http409","failed_clear","logging_deadline", ...
    "client_timing"];
names = ["Request log failure occurs before sending and creates no pending action", ...
    "Confirmed clear survives response log failure and permits safe exit", ...
    "Recovery logger failure preserves the original error and confirmed state", ...
    "Recovery after three losses preserves the original body and counts once", ...
    "Lost enter response retries the same entry and enters exactly once", ...
    "Lost clear responses preserve one successful clear and one action cost", ...
    "Recoverable lost exit response closes once with the original exit ID", ...
    "Unresolved exit never triggers a different recovery exit", ...
    "Short remaining window refuses a new action while retaining safe exit", ...
    "Zero remaining window causes no measure or late exit request", ...
    "Repeated timeouts retain one pending request within finite recovery deadlines", ...
    "Recovery duration limit stops retries before the total attempt ceiling", ...
    "Clock discrepancy preserves confirmed clear and stops only subsequent new actions", ...
    "Accepted action and accounting logs retain all rows beyond capacity 256", ...
    "HTTP 400 rejection preserves confirmed state and permits safe exit", ...
    "HTTP 500 remains unresolved without retrying or issuing a new exit", ...
    "Malformed accepted body remains unresolved without inventing confirmed state", ...
    "HTTP 200 rejection does not replace a nonzero confirmed clock with zero", ...
    "HTTP 409 is never retried even when recovery attempts are enabled", ...
    "Failed clear uses three seconds and preserves the receiving channel", ...
    "Slow request logging can expire the send budget without creating pending state", ...
    "Client millisecond timestamps and monotonic durations are recorded separately"];
passed = false(numel(testIds),1);
details = strings(numel(testIds),1);
for testIndex = 1:numel(testIds)
    try
        runCase(testIds(testIndex));
        passed(testIndex) = true;
        details(testIndex) = "All stated state, count, identity, and budget invariants passed.";
    catch errorInfo
        details(testIndex) = string(errorInfo.identifier)+": "+string(errorInfo.message);
        fprintf('Extended transport check failed: %s | %s\n',testIds(testIndex),details(testIndex));
    end
end
checks = table(names',passed,details,'VariableNames',{'Check','Passed','Details'});

    function runCase(testId)
        if testId == "request_log"
            [exchange,report,finish,inspect] = fixture(struct('logMode',"request_enter"));
            expectError(@() exchange("/enter",makePayload('ext-enter',[],[])),"Q3:Log");
            state = report();
            probe = inspect();
            require(probe.sentCount == 0 && state.acceptedActions == 0 && ~state.entered ...
                && ~state.unresolved && isempty(state.pending) && ~isempty(state.lastUnsent) ...
                && state.needsStop && isscalar(state.logErrors) && ~finish(), ...
                'A failed pre-send log must not send, enter, or invent a pending action.');
        elseif testId == "clear_log"
            [exchange,report,finish,inspect] = fixture(struct('logMode',"fault_response"));
            exchange("/enter",makePayload('ext-enter',[],[]));
            response = exchange("/clear",makePayload('ext-fault',[0,0],1));
            state = report();
            before = inspect();
            require(string(response.clear_result) == "success" && isequal(state.clearedChannels,1) ...
                && state.acceptedActions == 2 && state.virtualTime == 5 && state.confirmedCosts(5) == 5 ...
                && state.needsStop && ~state.unresolved && isempty(state.pending) ...
                && isscalar(state.logErrors) && isscalar(state.fallbackEvents), ...
                'A valid clear response must be confirmed even when its log cannot be saved.');
            expectError(@() exchange("/measure",makePayload('ext-next',[0,0],1)),"Q3:TransportStopped");
            after = inspect();
            require(after.sentCount == before.sentCount && finish(), ...
                'A log fault must refuse new business actions but permit a safe exit.');
            state = report();
            require(state.closed && state.acceptedActions == 3 && state.needsStop ...
                && isequal(state.clearedChannels,1),'Closing must not erase the logging fault or clear count.');
        elseif testId == "cleanup_log"
            [exchange,report,finish,inspect] = fixture(struct('faultType',"cleanup_failure", ...
                'logMode',"recovery_failure"));
            exchange("/enter",makePayload('ext-enter',[],[]));
            original = expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),"Q3:HttpStatus");
            recovered = finish();
            state = report();
            probe = inspect();
            require(original == "Q3:HttpStatus" && ~recovered && state.acceptedActions == 1 ...
                && state.virtualTime == 0 && state.unresolved && ~state.closed ...
                && isscalar(state.logErrors) && probe.sentCount == 3 ...
                && string(state.pending.path) == "/exit", ...
                'Cleanup failures must not throw over the first failure or change confirmed actions.');
        elseif testId == "late_recovery"
            [exchange,report,~,inspect] = fixture(struct('faultType',"drop",'drops',4));
            exchange("/enter",makePayload('ext-enter',[],[]));
            request = makePayload('ext-fault',[0,0],1);
            response = exchange("/measure",request);
            state = report();
            before = inspect();
            repeated = exchange("/measure",request);
            after = inspect();
            require(before.faultCalls == 5 && allSameFault(before) && state.acceptedActions == 2 ...
                && height(before.world.log) == 2 && state.virtualTime == 5 && before.world.time == 5 ...
                && ~state.unresolved && repeated.virtual_time_s == response.virtual_time_s ...
                && after.sentCount == before.sentCount && before.recoveryEvents >= 1, ...
                'Recovery and completed-cache reuse must preserve one logical action and one cost.');
        elseif ismember(testId,["enter_loss","clear_loss","exit_loss"])
            faultPath = "/enter";
            faultId = 'ext-enter';
            losses = 1;
            if testId == "clear_loss"
                faultPath = "/clear";
                faultId = 'ext-fault';
                losses = 2;
            elseif testId == "exit_loss"
                faultPath = "/exit";
                faultId = 'ext-exit';
            end
            [exchange,report,~,inspect] = fixture(struct('faultType',"drop",'faultPath',faultPath, ...
                'faultId',faultId,'drops',losses));
            exchange("/enter",makePayload('ext-enter',[],[]));
            if testId == "clear_loss"
                exchange("/clear",makePayload('ext-fault',[0,0],1));
            elseif testId == "exit_loss"
                exchange("/exit",makePayload('ext-exit',[],[]));
            end
            state = report();
            probe = inspect();
            require(probe.faultCalls == losses+1 && allSameFault(probe) ...
                && state.acceptedActions == height(probe.world.log) && ~state.unresolved ...
                && state.virtualTime == probe.world.time,'Lost responses must retry identical logical actions.');
            if testId == "enter_loss"
                require(state.entered && state.acceptedActions == 1 && state.virtualTime == 0, ...
                    'Lost entry response must not cause a second entry or extra virtual time.');
            elseif testId == "clear_loss"
                require(isequal(state.clearedChannels,1) && sum(probe.world.cleared) == 1 ...
                    && state.virtualTime == 5 && state.confirmedCosts(5) == 5, ...
                    'Successful clear retries must count only one source and one clearing cost.');
            else
                require(state.closed && state.acceptedActions == 2 && state.virtualTime == 0, ...
                    'A recovered exit response must close without introducing another action.');
            end
        elseif testId == "exit_unresolved"
            [exchange,report,finish,inspect] = fixture(struct('faultType',"drop",'faultPath',"/exit", ...
                'faultId','ext-exit','drops',Inf));
            exchange("/enter",makePayload('ext-enter',[],[]));
            expectError(@() exchange("/exit",makePayload('ext-exit',[],[])),"Q3:Unresolved");
            before = inspect();
            require(~finish(),'An unresolved exit must not create a new recovery-exit ID.');
            state = report();
            after = inspect();
            require(state.unresolved && ~state.closed && state.acceptedActions == 1 ...
                && after.sentCount == before.sentCount && allSameFault(before) ...
                && sum(before.world.log.Path == "/exit") == 1, ...
                'An unconfirmed exit must preserve ambiguity while the backend records at most one exit.');
        elseif testId == "short_budget" || testId == "zero_budget"
            remaining = 15;
            if testId == "zero_budget"
                remaining = 0;
            end
            [exchange,report,finish,inspect] = fixture(struct('remaining',remaining));
            exchange("/enter",makePayload('ext-enter',[],[]));
            expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),"Q3:RealBudget");
            before = inspect();
            state = report();
            require(before.sentCount == 1 && state.acceptedActions == 1 && isempty(state.pending) ...
                && ~state.unresolved,'An insufficient action budget must stop before sending.');
            recovered = finish();
            after = inspect();
            state = report();
            if remaining == 0
                require(~recovered && after.sentCount == 1 && ~state.closed, ...
                    'No exit may be sent after the zero-second deadline.');
            else
                require(recovered && after.sentCount == 2 && state.closed, ...
                    'A short but unexpired window must still permit the reserved exit.');
            end
        elseif testId == "retry_deadline" || testId == "recovery_window"
            settings = struct('faultType',"drop",'drops',Inf,'consumeTimeout',true,'remaining',35);
            if testId == "recovery_window"
                settings.remaining = 100;
                settings.requestTimeoutSec = 1;
                settings.recoveryWindowSec = 2;
            end
            [exchange,report,finish,inspect] = fixture(settings);
            exchange("/enter",makePayload('ext-enter',[],[]));
            expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),"Q3:Unresolved");
            before = inspect();
            state = report();
            require(state.unresolved && state.acceptedActions == 1 && state.virtualTime == 0 ...
                && allSameFault(before) && before.faultCalls <= before.attemptCeiling ...
                && before.elapsed <= before.remaining-before.finalExitReserveSec+1e-8 ...
                && before.recoveryEvents >= 1 && before.lastRecoveryEnd <= before.firstRecoveryStart+before.recoveryWindowSec+1e-8, ...
                'Retries must keep one pending request and remain inside the finite rescue budget.');
            require(~finish(),'An unresolved retry sequence must not issue a fresh exit.');
            after = inspect();
            require(after.sentCount == before.sentCount,'Recovery exhaustion must not trigger another send.');
            if testId == "recovery_window"
                require(before.faultCalls < before.attemptCeiling, ...
                    'The duration limit must be able to stop retries before the attempt-count limit.');
            end
        elseif testId == "accounting"
            [exchange,report,finish,inspect] = fixture(struct('faultType',"accounting",'faultPath',"/clear"));
            exchange("/enter",makePayload('ext-enter',[],[]));
            response = exchange("/clear",makePayload('ext-fault',[0,0],1));
            state = report();
            require(response.accepted && string(response.clear_result) == "success" ...
                && isequal(state.clearedChannels,1) && state.acceptedActions == 2 ...
                && state.virtualTime == 5.25 && state.confirmedCosts(5) == 5 ...
                && state.needsStop && strcmp(state.stopReason,'Q3:TimeAccounting') ...
                && ~state.unresolved && isempty(state.pending) && abs(state.accountingResiduals(2)-0.25) < 1e-10, ...
                'The confirmed discrepant response must return for the solver snapshot and remain inspectable.');
            before = inspect();
            expectError(@() exchange("/measure",makePayload('ext-next',[0,0],1)),"Q3:TransportStopped");
            after = inspect();
            require(before.sentCount == after.sentCount && finish(), ...
                'Accounting failure must stop new business actions while allowing confirmed-state exit.');
            state = report();
            require(state.closed && state.needsStop && isequal(state.clearedChannels,1), ...
                'Closing may not erase the discrepancy or successful clear.');
        elseif testId == "expand"
            [exchange,report,~,inspect] = fixture(struct);
            exchange("/enter",makePayload('ext-enter',[],[]));
            for actionIndex = 1:260
                exchange("/measure",makePayload(sprintf('ext-measure-%03d',actionIndex),[0,0],1));
            end
            exchange("/exit",makePayload('ext-exit',[],[]));
            state = report();
            probe = inspect();
            require(state.acceptedActions == 262 && height(state.log) == 262 ...
                && height(state.accountingDetails) == 262 && numel(state.accountingResiduals) == 262 ...
                && state.log.RequestId(1) == "ext-enter" && state.log.RequestId(257) == "ext-measure-256" ...
                && state.log.RequestId(end) == "ext-exit" && state.closed && state.virtualTime == 1300 ...
                && all(abs(state.accountingResiduals) < 1e-8) && height(probe.world.log) == 262, ...
                'Expansion must preserve every action and independent accounting row without truncation.');
        elseif ismember(testId,["http400","http500","bad_body","http409"])
            [exchange,report,finish,inspect] = fixture(struct('faultType',testId));
            exchange("/enter",makePayload('ext-enter',[],[]));
            expected = "Q3:HttpStatus";
            if testId == "bad_body"
                expected = "Q3:Response";
            elseif testId == "http409"
                expected = "Q3:Conflict";
            end
            expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),expected);
            state = report();
            before = inspect();
            require(state.acceptedActions == 1 && state.virtualTime == 0 && before.faultCalls == 1, ...
                'A rejected or unconfirmed packet must not update confirmed state or trigger blind retries.');
            recovered = finish();
            after = inspect();
            if testId == "http400"
                state = report();
                require(recovered && ~state.unresolved && state.closed && state.acceptedActions == 2, ...
                    'A definite HTTP 400 rejection must allow safe cleanup.');
            else
                require(~recovered && state.unresolved && ~isempty(state.pending) ...
                    && after.sentCount == before.sentCount, ...
                    'An unresolved or conflicting response must block all new cleanup actions.');
            end
        elseif testId == "http200_reject"
            [exchange,report,finish,~] = fixture(struct('faultType',"http200_reject"));
            exchange("/enter",makePayload('ext-enter',[],[]));
            exchange("/measure",makePayload('ext-first',[0,0],1));
            expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),"Q3:Rejected");
            state = report();
            require(state.virtualTime == 5 && state.acceptedActions == 2 && ~state.unresolved ...
                && isempty(state.pending) && finish(), ...
                'A rejection clock of zero is not the current confirmed clock.');
        elseif testId == "failed_clear"
            [exchange,report,finish,~] = fixture(struct);
            exchange("/enter",makePayload('ext-enter',[],[]));
            exchange("/measure",makePayload('ext-first',[0,0],2));
            response = exchange("/clear",makePayload('ext-fault',[21,0],1));
            state = report();
            require(string(response.clear_result) == "no_target_in_range" && state.receiver == 2 ...
                && isempty(state.clearedChannels) && abs(state.virtualTime-13.2) < 1e-8 ...
                && isequal(state.confirmedCosts,[21,1,5,3,0]) && ~state.needsStop ...
                && all(abs(state.accountingResiduals) < 1e-8) && finish(), ...
                'A failed clear must cost movement plus three seconds and must not switch the receiver.');
        elseif testId == "logging_deadline"
            [exchange,report,finish,inspect] = fixture(struct('remaining',35,'logMode',"slow_fault_request"));
            exchange("/enter",makePayload('ext-enter',[],[]));
            expectError(@() exchange("/measure",makePayload('ext-fault',[0,0],1)),"Q3:RealBudget");
            state = report();
            probe = inspect();
            require(probe.sentCount == 1 && state.acceptedActions == 1 && ~state.unresolved ...
                && isempty(state.pending) && ~isempty(state.lastUnsent) && finish(), ...
                'Budget expiration during logging must remain a known unsent request.');
        else
            [exchange,report,~,inspect] = fixture(struct('normalDelaySec',0.125));
            exchange("/enter",makePayload('ext-enter',[],[]));
            exchange("/measure",makePayload('ext-first',[0,0],1));
            state = report();
            probe = inspect();
            events = probe.events;
            clientTimes = cellfun(@(event) event.clientElapsed_s,events);
            responseEvents = events(cellfun(@(event) string(event.event) == "response",events));
            require(all(diff(clientTimes) >= 0) && all(cellfun(@(event) ...
                ~isempty(regexp(event.timestampUtc,'\.\d{3}Z$','once')),events)) ...
                && all(cellfun(@(event) abs(event.durationSec-0.125) < 1e-10,responseEvents)) ...
                && state.virtualTime == 5 && abs(probe.elapsed-0.25) < 1e-10, ...
                'Client elapsed time and response duration must not advance virtual time.');
        end
    end

    function [exchange,report,finish,inspect] = fixture(overrides)
        options = struct('faultType',"none",'faultPath',"/measure",'faultId','ext-fault', ...
            'drops',0,'remaining',1200,'consumeTimeout',false,'normalDelaySec',0, ...
            'logMode',"none",'requestTimeoutSec',5,'recoveryWindowSec',15);
        fields = fieldnames(overrides);
        for optionIndex = 1:numel(fields)
            options.(fields{optionIndex}) = overrides.(fields{optionIndex});
        end
        fixtureConfig = config;
        fixtureConfig.requestPrefix = 'extended';
        fixtureConfig.requestTimeoutSec = options.requestTimeoutSec;
        fixtureConfig.maxAttempts = 3;
        fixtureConfig.retryPauseSec = 0.25;
        fixtureConfig.exitReserveSec = 30;
        fixtureConfig.finalExitReserveSec = min(5,fixtureConfig.requestTimeoutSec);
        fixtureConfig.recoveryAttempts = 3;
        fixtureConfig.recoveryWindowSec = options.recoveryWindowSec;
        [backend,worldReport] = makeWorld([1,0,0,1000,1;2,1000,0,1000,-1]);
        elapsed = 0;
        faultCalls = 0;
        sentCount = 0;
        eventCount = 0;
        sentRows = cell(1024,5);
        events = cell(2048,1);
        serverOffset = 0;
        mismatchInjected = false;
        clock = struct('now',@readClock,'sleep',@advance,'utc',@clockStamp);
        [exchange,report,finish] = makeTransport(fixtureConfig,@sendMock,@logMock,clock);
        inspect = @inspectFixture;

        function value = readClock()
            value = elapsed;
        end

        function advance(duration)
            elapsed = elapsed+duration;
        end

        function stamp = clockStamp()
            stamp = sprintf('2026-09-11T00:00:%02d.%03dZ',floor(mod(elapsed,60)), ...
                min(999,floor(1000*(elapsed-floor(elapsed)))));
        end

        function packet = sendMock(~,path,body,timeout)
            request = jsondecode(body);
            sentCount = sentCount+1;
            sentRows(sentCount,:) = {string(path),string(request.request_id),string(body),timeout,elapsed};
            isFault = string(path) == string(options.faultPath) && strcmp(request.request_id,options.faultId);
            if isFault
                faultCalls = faultCalls+1;
            end
            if options.faultType == "cleanup_failure" && (isFault || string(path) == "/exit")
                code = 400;
                if string(path) == "/exit"
                    code = 500;
                end
                packet = rejected(code);
                return
            end
            if isFault && ismember(options.faultType,["http400","http500","http409","http200_reject"])
                code = 200;
                if options.faultType == "http400"
                    code = 400;
                elseif options.faultType == "http500"
                    code = 500;
                elseif options.faultType == "http409"
                    code = 409;
                end
                packet = rejected(code);
                return
            end
            response = backend(path,request);
            if string(path) == "/enter"
                response.remaining_real_duration_s = options.remaining;
            end
            if isFault && options.faultType == "drop" && faultCalls <= options.drops
                if options.consumeTimeout
                    advance(timeout);
                else
                    advance(0.01);
                end
                error('Q3:InjectedResponseLoss','The backend accepted the original action but its response was lost.');
            end
            if isFault && options.faultType == "accounting" && ~mismatchInjected
                mismatchInjected = true;
                serverOffset = 0.25;
            end
            response.virtual_time_s = response.virtual_time_s+serverOffset;
            if isFault && options.faultType == "bad_body"
                response = rmfield(response,'measure_result');
            end
            advance(options.normalDelaySec);
            packet = struct('httpStatus',200,'body',response);
        end

        function packet = rejected(code)
            packet = struct('httpStatus',code,'body', ...
                struct('accepted',false,'real_timestamp_ms',0,'virtual_time_s',0));
        end

        function logMock(event)
            eventCount = eventCount+1;
            events{eventCount} = event;
            isFaultRequest = string(event.event) == "request" ...
                && strcmp(event.payload.request_id,options.faultId);
            if options.logMode == "slow_fault_request" && isFaultRequest
                advance(6);
            end
            shouldFail = options.logMode == "request_enter" && string(event.event) == "request" ...
                && string(event.path) == "/enter";
            shouldFail = shouldFail || (options.logMode == "fault_response" && string(event.event) == "response" ...
                && strcmp(event.requestId,options.faultId));
            shouldFail = shouldFail || (options.logMode == "recovery_failure" ...
                && string(event.event) == "recovery_exit_failed");
            if shouldFail
                error('Q3:InjectedLoggerFailure','The injected ledger write failed.');
            end
        end

        function value = inspectFixture()
            actualEvents = events(1:eventCount);
            recoveryRequests = actualEvents(cellfun(@(event) string(event.event) == "request" ...
                && isfield(event,'phase') && strcmp(event.phase,'recovery'),actualEvents));
            firstRecoveryStart = NaN;
            lastRecoveryEnd = NaN;
            if ~isempty(recoveryRequests)
                firstRecoveryStart = recoveryRequests{1}.clientElapsed_s;
                lastRecoveryEnd = elapsed;
            end
            value = struct('world',worldReport(),'faultCalls',faultCalls,'sentCount',sentCount, ...
                'sent',cell2table(sentRows(1:sentCount,:),'VariableNames',{'Path','RequestId','Body','TimeoutSec','StartedSec'}), ...
                'events',{actualEvents},'elapsed',elapsed,'remaining',options.remaining, ...
                'finalExitReserveSec',fixtureConfig.finalExitReserveSec, ...
                'attemptCeiling',fixtureConfig.maxAttempts+fixtureConfig.recoveryAttempts, ...
                'recoveryEvents',numel(recoveryRequests),'firstRecoveryStart',firstRecoveryStart, ...
                'lastRecoveryEnd',lastRecoveryEnd,'recoveryWindowSec',fixtureConfig.recoveryWindowSec, ...
                'faultId',string(options.faultId));
        end
    end

    function request = makePayload(id,position,channel)
        request = struct('arena_id','default','robot_id',config.robotId,'request_id',id);
        if ~isempty(position)
            request.position = struct('x',position(1),'y',position(2));
            request.channel = channel;
        end
    end

    function identifier = expectError(action,expected)
        identifier = "";
        try
            action();
        catch errorInfo
            identifier = string(errorInfo.identifier);
        end
        require(identifier == expected,"Expected "+expected+" but received "+identifier+".");
    end

    function value = allSameFault(probe)
        faultRows = probe.sent(probe.sent.RequestId == probe.faultId,:);
        value = height(faultRows) >= 1 && isscalar(unique(faultRows.Body)) ...
            && isscalar(unique(faultRows.Path)) && all(faultRows.TimeoutSec > 0);
    end

    function require(condition,message)
        assert(isscalar(condition) && logical(condition),'Q3:ExtendedTransportCheck','%s',message);
    end
end

function [checks,outputPath] = validateSnapshots(settings)
root = fileparts(mfilename('fullpath'));
resultRoot = fullfile(root,'运行结果');
if ~isfolder(resultRoot)
    [ok,message] = mkdir(resultRoot);
    assert(ok,'Q3:SnapshotTestOutput','Cannot create test parent: %s',message);
end
[~,token] = fileparts(tempname(resultRoot));
outputPath = fullfile(resultRoot,char("snapshot_validation_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))+"_"+string(token)));
[ok,message] = mkdir(outputPath);
assert(ok,'Q3:SnapshotTestOutput','Cannot create test output: %s',message);
names = strings(40,1);
values = false(40,1);
checkCount = 0;
config = settings;
config.variant = "seven_geometry";
config.robotId = 'SNAPSHOT_SYNTHETIC';
config.requestPrefix = 'snapshot-check';
if isfield(config,'progressFcn')
    config = rmfield(config,'progressFcn');
end
if isfield(config,'snapshotFcn')
    config = rmfield(config,'snapshotFcn');
end
angles = (0:8)'*40;
positions = [0,0;600*cosd(angles),600*sind(angles)];
sources = [(1:10)',positions,1000*ones(10,1),zeros(10,1)];
[baseExchange,baseReport] = makeWorld(sources);
[baseSolution,baseFailure] = solveRoute(baseExchange,config);
baseWorld = baseReport();
add("Snapshot baseline clears ten synthetic channels",isempty(baseFailure.identifier) && baseSolution.complete ...
    && all(baseWorld.cleared) && sum(baseSolution.status == 2) == 10);
add("Snapshot baseline has no callback errors",isempty(baseSolution.callbackErrors));
capturedProgress = cell(config.maxActions+2,1);
capturedSnapshots = cell(config.maxActions+2,1);
progressCount = 0;
snapshotCount = 0;
callbackInvariant = true;
[callbackExchange,callbackReport] = makeWorld(sources);
callbackConfig = config;
callbackConfig.progressFcn = @captureProgress;
callbackConfig.snapshotFcn = @captureSnapshot;
[callbackSolution,callbackFailure] = solveRoute(callbackExchange,callbackConfig);
callbackWorld = callbackReport();
add("Callbacks preserve the complete accepted action sequence",isempty(callbackFailure.identifier) ...
    && callbackSolution.complete && isequaln(baseWorld.log,callbackWorld.log));
add("Progress follows every fully integrated accepted action",progressCount == height(callbackWorld.log));
add("Progress and snapshots agree with independent world state",callbackInvariant && isempty(callbackSolution.callbackErrors));
add("Full snapshots occur at enter clear and exit",snapshotCount == 12 ...
    && capturedSnapshots{1}.entered && capturedSnapshots{snapshotCount}.exited);
capturedProgress = capturedProgress(1:progressCount);
capturedSnapshots = capturedSnapshots(1:snapshotCount);
[faultExchange,faultReport] = snapshotFaultWorld(sources);
[failedSolution,failedResult] = solveRoute(faultExchange,config);
faultState = faultReport();
confirmedChannels = sources(faultState.world.cleared,1)';
add("Two-output solver returns an injected post-clear failure",strcmp(failedResult.identifier,'Q3:SnapshotInjected') ...
    && ~failedSolution.complete && failedSolution.phase == "failed" && faultState.injected);
add("Failure preserves earlier success and geometric history",isequal(find(failedSolution.status == 2),confirmedChannels) ...
    && isscalar(confirmedChannels) && ~isempty(failedSolution.history));
add("Failure preserves confirmed position receiver and costs", ...
    isequal(failedSolution.position,[faultState.world.log.X_m(end),faultState.world.log.Y_m(end)]) ...
    && failedSolution.receiver == faultState.world.receiver ...
    && abs(failedSolution.virtualTime-faultState.world.time) < 1e-9 ...
    && abs(failedSolution.costs(1)/5+sum(failedSolution.costs(2:5))-faultState.world.time) < 1e-7);
add("Failure separates attempted and previously accepted actions",~failedSolution.lastAction.accepted ...
    && failedSolution.lastAction.path == "/measure" && failedSolution.lastAcceptedAction.accepted ...
    && failedSolution.lastAcceptedAction.path == "/clear" ...
    && failedSolution.lastAcceptedAction.observationIntegrated ...
    && failedSolution.serial == faultState.attempts);
singlePath = fullfile(outputPath,'single_output_checkpoint.mat');
singleConfig = config;
singleConfig.snapshotFcn = @(value) saveSnapshot(singlePath,value);
[singleExchange,singleReport] = snapshotFaultWorld(sources);
singleCaught = false;
try
    solveRoute(singleExchange,singleConfig);
catch errorInfo
    singleCaught = strcmp(errorInfo.identifier,'Q3:SnapshotInjected');
end
singleState = singleReport();
add("Single-output solver rethrows the original failure",singleCaught && singleState.injected);
saved = load(singlePath,'snapshot');
singleSnapshot = saved.snapshot;
add("Single-output failure saves the confirmed clear before throwing",singleSnapshot.phase == "failed" ...
    && sum(singleSnapshot.status == 2) == 1 && ~singleSnapshot.complete ...
    && strcmp(singleSnapshot.failure.identifier,'Q3:SnapshotInjected'));
geometryConfig = config;
geometryConfig.diskSides = 0;
[geometryExchange,geometryReport] = makeWorld(sources);
[geometrySolution,geometryFailure] = solveRoute(geometryExchange,geometryConfig);
geometryWorld = geometryReport();
add("Accepted measure survives an injected geometry failure",strcmp(geometryFailure.identifier,'Q3:EmptyRegion') ...
    && geometrySolution.lastAcceptedAction.accepted ...
    && geometrySolution.lastAcceptedAction.path == "/measure" ...
    && geometrySolution.lastAcceptedAction.response.measure_result == "direction" ...
    && ~geometrySolution.lastAcceptedAction.observationIntegrated);
add("Geometry failure keeps coverage observation and confirmed costs",geometrySolution.coverage(1,2) ...
    && geometrySolution.status(2) == 1 && geometrySolution.receiver == 2 ...
    && isequal(geometrySolution.position,[0,0]) ...
    && abs(geometrySolution.virtualTime-geometryWorld.time) < 1e-9 ...
    && abs(geometrySolution.costs(1)/5+sum(geometrySolution.costs(2:5))-geometryWorld.time) < 1e-7);
errorConfig = config;
errorConfig.progressFcn = @(value) error('Q3:ProgressInjected','Injected progress failure at action %d.',value.serial);
errorConfig.snapshotFcn = @(value) error('Q3:SnapshotCallbackInjected','Injected snapshot failure at action %d.',value.serial);
[errorExchange,errorReport] = makeWorld(sources);
[errorSolution,errorFailure] = solveRoute(errorExchange,errorConfig);
errorWorld = errorReport();
errorCallbacks = string({errorSolution.callbackErrors.callback});
add("Throwing callbacks preserve all confirmed successful clears",isempty(errorFailure.identifier) ...
    && errorSolution.complete && sum(errorSolution.status == 2) == 10 ...
    && any(errorCallbacks == "progressFcn") && any(errorCallbacks == "snapshotFcn"));
add("Throwing callbacks do not alter accepted physical actions",isequaln(baseWorld.log,errorWorld.log));
emptyFailure = baseFailure;
gateState = struct('clearedChannels',1:10,'closed',true,'unresolved',false,'needsStop',false, ...
    'logErrors',struct('identifier',{},'message',{}));
add("Practice completion rejects callback persistence errors",~practiceComplete(errorSolution,emptyFailure,gateState));
gateCounts = [0;10;16;17];
gateExpected = [false;true;true;false];
gateActual = false(4,1);
for index = 1:numel(gateCounts)
    count = gateCounts(index);
    gateSolution = baseSolution;
    gateSolution.status = 3*ones(1,20);
    gateSolution.status(1:count) = 2;
    gateSolution.coverage = true(7,20);
    gateSolution.complete = true;
    gateState.clearedChannels = 1:count;
    gateActual(index) = practiceComplete(gateSolution,emptyFailure,gateState);
    add("Practice completion count gate "+string(count),gateActual(index) == gateExpected(index));
end
gateState.clearedChannels = 1:10;
gateSolution = baseSolution;
badState = gateState;
badState.clearedChannels = [1:9,11];
add("Practice completion rejects mismatched confirmed channels",~practiceComplete(gateSolution,emptyFailure,badState));
badState = gateState;
badState.unresolved = true;
add("Practice completion rejects an unresolved request",~practiceComplete(gateSolution,emptyFailure,badState));
badState = gateState;
badState.closed = false;
add("Practice completion requires confirmed exit",~practiceComplete(gateSolution,emptyFailure,badState));
badState = gateState;
badState.needsStop = true;
add("Practice completion rejects a transport stop condition",~practiceComplete(gateSolution,emptyFailure,badState));
badState = gateState;
badState.logErrors = struct('identifier','Q3:LogInjected','message','Synthetic persistence error');
add("Practice completion rejects raw-log errors",~practiceComplete(gateSolution,emptyFailure,badState));
add("Practice completion rejects a nonempty solver failure",~practiceComplete(gateSolution,failedResult,gateState));
badSolution = gateSolution;
badSolution.status(20) = 1;
add("Practice completion rejects a pending discovered channel",~practiceComplete(badSolution,emptyFailure,gateState));
badSolution = gateSolution;
badSolution.complete = false;
add("Practice completion rejects an incomplete solver",~practiceComplete(badSolution,emptyFailure,gateState));
displayPath = fullfile(outputPath,'display_replay');
[ok,message] = mkdir(displayPath);
assert(ok,'Q3:SnapshotTestOutput','Cannot create display evidence output: %s',message);
displayConfig = struct('showProgressWindow',false,'caseCode','SYNTHETIC-SNAPSHOT-TEST','outputPath',displayPath);
[progressFn,finishProgress] = makeProgress(displayConfig);
displayCleanup = onCleanup(finishProgress);
first = struct('status',zeros(1,20),'serial',1,'phase',"clearing",'virtualTime',105, ...
    'detectedCount',2,'absentCount',0,'clearedCount',1,'failure',emptyFailure);
first.status(1) = 2;
second = first;
second.status(2) = 2;
second.serial = 2;
second.virtualTime = 211;
second.clearedCount = 2;
second.detectedCount = 1;
failedProgress = second;
failedProgress.phase = "failed";
failedProgress.failure = failedResult;
displayText = evalc('replayDisplay();');
writeText(fullfile(displayPath,'captured_console.txt'),displayText);
add("Progress replay prints one success per newly confirmed channel",numel(strfind(displayText,'清除成功：')) == 2 ...
    && isscalar(strfind(displayText,'频道1；')) && isscalar(strfind(displayText,'频道2；')));
add("Progress replay shows Chinese cumulative counts without duplicates",contains(displayText,'累计已清除1个') ...
    && contains(displayText,'累计已清除2个') && ~contains(displayText,'累计已清除3个'));
displayJson = jsondecode(fileread(fullfile(displayPath,'实时进度.json')));
displayMarkdown = fileread(fullfile(displayPath,'实时进度.md'));
add("Progress JSON preserves failure and two unique confirmed clears",string(displayJson.phase) == "failed" ...
    && sum(displayJson.status == 2) == 2 && displayJson.clearedCount == 2 && displayJson.serial == 2 ...
    && strcmp(displayJson.failure.identifier,'Q3:SnapshotInjected'));
add("Progress Markdown reports the actual confirmed cumulative count",contains(displayMarkdown,'已确认清除：2个') ...
    && contains(displayMarkdown,'模拟耗时：211.000秒') && contains(displayMarkdown,'SYNTHETIC-SNAPSHOT-TEST'));
gateResults = table(gateCounts,gateExpected,gateActual,'VariableNames',{'Count','Expected','Actual'});
checks = table(names(1:checkCount),values(1:checkCount),'VariableNames',{'Check','Passed'});
writetable(checks,fullfile(outputPath,'必要验证.csv'),'Encoding','UTF-8');
writetable(gateResults,fullfile(outputPath,'完成数量门.csv'),'Encoding','UTF-8');
save(fullfile(outputPath,'snapshot_validation.mat'),'config','sources','baseSolution','baseFailure','baseWorld', ...
    'callbackSolution','callbackFailure','callbackWorld','capturedProgress','capturedSnapshots', ...
    'failedSolution','failedResult','faultState','singleSnapshot','singleState', ...
    'geometryConfig','geometrySolution','geometryFailure','geometryWorld','errorSolution','errorFailure','errorWorld', ...
    'gateResults','displayConfig','displayText','displayJson','displayMarkdown','checks','outputPath');
writeText(fullfile(outputPath,'验证说明.md'),sprintf('快照与显示验证，全部使用自建10源场景、内存世界及本地文件。\n\n未连接官方模拟器，未创建界面窗口。\n\naccepted测量后的几何失败使用测试专用diskSides=0注入；该配置不属于正常算法。\n\n成功计数边界使用人工构造的完成状态，仅验证完成判据。\n\n显示重放为两次不同频道成功、各自重复状态和最后失败，终态仍应为累计2个。\n\n检查结果：%d/%d。完整证据见snapshot_validation.mat。\n',sum(checks.Passed),height(checks)));

    function add(name,value)
        checkCount = checkCount+1;
        assert(checkCount <= numel(names),'Q3:SnapshotTestCapacity','Snapshot test capacity exceeded.');
        names(checkCount) = name;
        values(checkCount) = isscalar(value) && logical(value);
    end

    function replayDisplay()
        progressFn(first);
        progressFn(first);
        progressFn(second);
        progressFn(second);
        progressFn(failedProgress);
    end

    function captureProgress(progress)
        progressCount = progressCount+1;
        capturedProgress{progressCount} = progress;
        observed = callbackReport();
        expectedChannels = sources(observed.cleared,1)';
        callbackInvariant = callbackInvariant && isequal(find(progress.status == 2),expectedChannels) ...
            && isequal(progress.position,[observed.log.X_m(end),observed.log.Y_m(end)]) ...
            && progress.receiver == observed.receiver && abs(progress.virtualTime-observed.time) < 1e-9 ...
            && abs(progress.costs(1)/5+sum(progress.costs(2:5))-observed.time) < 1e-7 ...
            && progress.lastAction.accepted && progress.lastAction.observationIntegrated ...
            && ~isfield(progress,'tracks') && ~isfield(progress,'history');
    end

    function captureSnapshot(value)
        snapshotCount = snapshotCount+1;
        capturedSnapshots{snapshotCount} = value;
        observed = callbackReport();
        expectedChannels = sources(observed.cleared,1)';
        callbackInvariant = callbackInvariant && isequal(find(value.status == 2),expectedChannels) ...
            && abs(value.virtualTime-observed.time) < 1e-9 && value.lastAction.observationIntegrated;
    end
end

function [exchange,report] = snapshotFaultWorld(sources)
[worldExchange,worldReport] = makeWorld(sources);
attempts = 0;
confirmedClears = 0;
injected = false;
exchange = @dispatch;
report = @snapshot;

    function response = dispatch(path,request)
        attempts = attempts+1;
        if path == "/measure" && confirmedClears >= 1
            injected = true;
            error('Q3:SnapshotInjected','Synthetic fault before action %d after a confirmed successful clear.',attempts);
        end
        response = worldExchange(path,request);
        if path == "/clear" && response.accepted && response.clear_result == "success"
            confirmedClears = confirmedClears+1;
        end
    end

    function value = snapshot()
        value = struct('world',worldReport(),'attempts',attempts,'confirmedClears',confirmedClears,'injected',injected);
    end
end

function output = runHttpValidation(root,config)
assert(isstruct(config) && isscalar(config) && isfield(config,'localFaultServer') ...
    && isequal(config.localFaultServer,true) && isfield(config,'baseUrl'), ...
    'Q3:HttpTestConfig','Local HTTP validation requires localFaultServer=true and an explicit loopback URL.');
baseUrl = char(string(config.baseUrl));
portToken = regexp(baseUrl,'^http://127\.0\.0\.1:([0-9]{1,5})$','tokens','once');
assert(~isempty(portToken) && str2double(portToken{1}) >= 1 ...
    && str2double(portToken{1}) <= 65535 && str2double(portToken{1}) ~= 2026, ...
    'Q3:HttpTestConfig','The local fault fixture must use an IPv4 loopback port other than 2026.');
if isfield(config,'outputPath') && strlength(string(config.outputPath)) > 0
    outputPath = char(string(config.outputPath));
else
    outputPath = fullfile(root,'运行结果',char("validate_http_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
end
rootFile = java.io.File(root);
outputFile = java.io.File(outputPath);
rootPath = char(rootFile.getCanonicalPath());
outputPath = char(outputFile.getCanonicalPath());
assert(startsWith(lower(string(outputPath)),lower(string(rootPath)+filesep)) ...
    && ~isfolder(outputPath) && ~isfile(outputPath),'Q3:HttpTestConfig', ...
    'HTTP validation output must be a new directory inside the problem package.');
warmTimer = tic;
identityPacket = postJson(baseUrl,"/__control",jsonencode(struct('scenario','ok')),15);
warmupElapsed = toc(warmTimer);
assert(identityPacket.httpStatus == 200 && isstruct(identityPacket.body) ...
    && isfield(identityPacket.body,'serviceId') ...
    && string(identityPacket.body.serviceId) == "Q3_LOCAL_FAULT_SERVER" ...
    && isfield(identityPacket.body,'serverNonce') && strlength(string(identityPacket.body.serverNonce)) > 0, ...
    'Q3:HttpTestIdentity','The endpoint did not identify itself as the local Q3 fault fixture.');
serverIdentity = struct('serviceId',identityPacket.body.serviceId, ...
    'serverNonce',identityPacket.body.serverNonce,'pid',identityPacket.body.pid, ...
    'baseUrl',baseUrl,'warmupElapsed_s',warmupElapsed,'evidence','LOCAL_HTTP_FIXTURE_NOT_OFFICIAL');
[created,message] = mkdir(outputPath);
assert(created,'Q3:Output','Cannot create HTTP validation output: %s',message);
writeJson(fullfile(outputPath,'server_identity.json'),serverIdentity);
writeJson(fullfile(outputPath,'initial_server_state.json'),identityPacket.body);
checkNames = strings(64,1);
checkPassed = false(64,1);
checkDuration = NaN(64,1);
checkErrorId = strings(64,1);
checkErrorMessage = strings(64,1);
checkEvidence = strings(64,1);
checkCount = 0;
testRecords = cell(20,1);
testCount = 0;
probeNames = ["ok","chunked","slow_headers","slow_chunks","bad_json","http_400","http_429","http_500"];
for probeIndex = 1:numel(probeNames)
    probe = probeNames(probeIndex);
    caseName = sprintf('probe_%02d_%s',probeIndex,probe);
    options = struct('scenario','ok','header_delay_s',8,'chunk_delay_s',0.1,'chunk_count',80);
    resetFixture(options);
    timeout = 3;
    if ismember(probe,["slow_headers","slow_chunks"])
        timeout = 0.9;
    end
    packet = [];
    caught = struct('identifier','','message','');
    requestTimer = tic;
    try
        packet = postJson(baseUrl,"/"+probe,'{}',timeout);
    catch errorInfo
        caught = struct('identifier',errorInfo.identifier,'message',errorInfo.message);
    end
    duration = toc(requestTimer);
    if ismember(probe,["ok","chunked"])
        passed = isempty(caught.identifier) && isstruct(packet) && packet.httpStatus == 200 ...
            && isstruct(packet.body) && isequal(packet.body.accepted,true) ...
            && string(packet.body.measure_result) == "near";
    elseif ismember(probe,["slow_headers","slow_chunks"])
        timeoutText = lower(string(caught.identifier)+" "+string(caught.message));
        isTimeout = string(caught.identifier) == "Q3:RequestTimeout" ...
            || any(contains(timeoutText,["timeout","timed out","cancel","超时","取消"]));
        passed = ~isempty(caught.identifier) && isTimeout && duration >= 0.6 && duration < 3;
    elseif probe == "bad_json"
        passed = ~isempty(caught.identifier) ...
            && contains(lower(string(caught.identifier)+" "+string(caught.message)),"json");
    else
        expectedStatus = str2double(extractAfter(probe,"http_"));
        passed = isempty(caught.identifier) && isstruct(packet) && packet.httpStatus == expectedStatus ...
            && isstruct(packet.body) && isequal(packet.body.accepted,false);
    end
    [fixture,snapshotError] = captureFixture(caseName);
    passed = passed && isempty(snapshotError.identifier) && ~isempty(fixture) ...
        && fixture.execution_count == 0 && fixture.attempt_count == 1;
    meta = struct('caseName',caseName,'probe',probe,'timeout_s',timeout,'elapsed_s',duration, ...
        'passed',passed,'failure',caught,'snapshotFailure',snapshotError,'packet',packet, ...
        'evidence','LOCAL_HTTP_FIXTURE_NOT_OFFICIAL');
    writeJson(fullfile(outputPath,[caseName,'_meta.json']),meta);
    addCheck("HTTP probe "+probe,passed,duration,caught,string(caseName)+"_meta.json");
    remember(meta);
    fprintf('LOCAL_HTTP | %s | %d | %.3f s\n',caseName,passed,duration);
end
sessionNames = ["ok","drop_after_enter","drop_after_clear","drop_after_exit","bad_json"];
for sessionIndex = 1:numel(sessionNames)
    scenario = sessionNames(sessionIndex);
    caseName = sprintf('session_%02d_%s',sessionIndex,scenario);
    options = struct('scenario',char(scenario),'fault_on','/clear','fault_count',1, ...
        'source_count',10,'remaining_real_duration_s',1200);
    resetFixture(options);
    sessionConfig = struct('baseUrl',baseUrl,'robotId','Q3_HTTP_FIXTURE', ...
        'requestPrefix',strrep(caseName,'_','-'),'requestTimeoutSec',1,'maxAttempts',2,'retryPauseSec',0.01, ...
        'exitReserveSec',30,'recoveryAttempts',1,'recoveryWindowSec',3,'finalExitReserveSec',1);
    eventPath = fullfile(outputPath,[caseName,'_events.jsonl']);
    [exchange,report,finish] = makeTransport(sessionConfig,@postJson,@(event) appendJson(eventPath,event));
    caught = struct('identifier','','message','');
    cacheResponse = [];
    sessionTimer = tic;
    clearOne = request('clear_one',[0,0],1);
    try
        exchange("/enter",request('enter',[],[]));
        exchange("/measure",request('measure_far',[300,400],2));
        exchange("/clear",clearOne);
        exchange("/measure",request('measure_near',[0,0],2));
        exchange("/clear",request('clear_fail',[20.001,0],4));
        exchange("/clear",request('clear_three',[0,0],3));
        exchange("/measure",request('measure_same_receiver',[0,0],2));
        exchange("/exit",request('exit',[],[]));
        cacheResponse = exchange("/clear",clearOne);
    catch errorInfo
        caught = struct('identifier',errorInfo.identifier,'message',errorInfo.message);
        finish();
    end
    duration = toc(sessionTimer);
    clientState = report();
    [fixture,snapshotError] = captureFixture(caseName);
    if isempty(snapshotError.identifier) && ~isempty(fixture)
        expectedAttempts = 8+double(scenario ~= "ok");
        identityValid = fixture.execution_count == 8 && fixture.attempt_count == expectedAttempts;
        repeatValid = httpFixtureRetryValid(fixture,scenario);
        cleared = reshape(double(fixture.cleared_channels),1,[]);
        clearValid = isequal(sort(cleared),[1,3]) && isequal(sort(clientState.clearedChannels),[1,3]) ...
            && fixture.receiver == 2 && clientState.receiver == 2;
        independentTime = 100+1+5+100+5+5+20.001/5+3+20.001/5+5+5;
        timeValid = abs(fixture.virtual_time_s-independentTime) < 2e-6 ...
            && abs(clientState.virtualTime-fixture.virtual_time_s) < 2e-6 ...
            && all(clientState.accountingDetails.Passed) ...
            && height(clientState.accountingDetails) == 8;
    else
        identityValid = false;
        repeatValid = false;
        clearValid = false;
        timeValid = false;
        independentTime = 237.0004;
    end
    completed = isempty(caught.identifier) && clientState.closed && ~clientState.unresolved ...
        && clientState.acceptedActions == 8 && height(clientState.log) == 8;
    cacheValid = isstruct(cacheResponse) && isfield(cacheResponse,'clear_result') ...
        && string(cacheResponse.clear_result) == "success" && identityValid ...
        && clientState.acceptedActions == 8;
    writetable(clientState.log,fullfile(outputPath,[caseName,'_actions.csv']),'Encoding','UTF-8');
    writetable(clientState.accountingDetails,fullfile(outputPath,[caseName,'_accounting.csv']),'Encoding','UTF-8');
    save(fullfile(outputPath,[caseName,'_client.mat']),'clientState','sessionConfig','caught');
    meta = struct('caseName',caseName,'scenario',scenario,'elapsed_s',duration, ...
        'complete',completed,'uniqueExecutionValid',identityValid,'retryValid',repeatValid, ...
        'clearAndReceiverValid',clearValid,'timeValid',timeValid,'clientCacheValid',cacheValid, ...
        'independentExpectedTime_s',independentTime,'failure',caught,'snapshotFailure',snapshotError, ...
        'evidence','LOCAL_HTTP_FIXTURE_NOT_OFFICIAL');
    writeJson(fullfile(outputPath,[caseName,'_meta.json']),meta);
    evidence = string(caseName)+"_meta.json";
    addCheck("Session "+scenario+" completes",completed && identityValid,duration,caught,evidence);
    addCheck("Session "+scenario+" preserves retry ID and body",repeatValid,duration,caught,evidence);
    addCheck("Session "+scenario+" clears once and preserves receiver",clearValid,duration,caught,evidence);
    addCheck("Session "+scenario+" matches independent microsecond clock",timeValid,duration,caught,evidence);
    addCheck("Session "+scenario+" returns cached completed request",cacheValid,duration,caught,evidence);
    remember(meta);
    fprintf('LOCAL_HTTP | %s | %d | %.3f s\n',caseName,completed && identityValid && repeatValid && clearValid && timeValid && cacheValid,duration);
end
checks = table(checkNames(1:checkCount),checkPassed(1:checkCount),checkDuration(1:checkCount), ...
    checkErrorId(1:checkCount),checkErrorMessage(1:checkCount),checkEvidence(1:checkCount), ...
    'VariableNames',{'Check','Passed','Elapsed_s','ErrorIdentifier','ErrorMessage','Evidence'});
testRecords = testRecords(1:testCount);
writetable(checks,fullfile(outputPath,'HTTP必要验证.csv'),'Encoding','UTF-8');
save(fullfile(outputPath,'http_validation.mat'),'checks','serverIdentity','testRecords','config');
output = struct('path',outputPath,'checks',checks,'serverIdentity',serverIdentity, ...
    'evidence','LOCAL_HTTP_FIXTURE_NOT_OFFICIAL','passed',all(checks.Passed));
writeJson(fullfile(outputPath,'http_validation_summary.json'),struct('passed',all(checks.Passed), ...
    'passedChecks',sum(checks.Passed),'totalChecks',height(checks),'serverIdentity',serverIdentity, ...
    'evidence','LOCAL_HTTP_FIXTURE_NOT_OFFICIAL'));
fprintf('SELF_CHECKED_LOCAL_HTTP | %d/%d checks | %s\n',sum(checks.Passed),height(checks),outputPath);
assert(all(checks.Passed),'Q3:HttpValidation','A local HTTP validation failed; inspect the preserved per-case evidence.');

    function resetFixture(options)
        packet = postJson(baseUrl,"/__control",jsonencode(options),5);
        assert(packet.httpStatus == 200 && isstruct(packet.body) && isfield(packet.body,'serviceId') ...
            && string(packet.body.serviceId) == "Q3_LOCAL_FAULT_SERVER" ...
            && isfield(packet.body,'serverNonce') ...
            && string(packet.body.serverNonce) == string(serverIdentity.serverNonce), ...
            'Q3:HttpTestIdentity','The local fixture identity changed between cases.');
    end

    function [fixture,caught] = captureFixture(caseName)
        fixture = [];
        caught = struct('identifier','','message','');
        try
            fixture = webread([baseUrl,'/__state'],weboptions('Timeout',5,'ContentType','json'));
            assert(isstruct(fixture) && isfield(fixture,'serviceId') ...
                && string(fixture.serviceId) == "Q3_LOCAL_FAULT_SERVER" ...
                && string(fixture.serverNonce) == string(serverIdentity.serverNonce), ...
                'Q3:HttpTestIdentity','The fixture state did not match its confirmed identity.');
            writeJson(fullfile(outputPath,[caseName,'_server.json']),fixture);
        catch errorInfo
            caught = struct('identifier',errorInfo.identifier,'message',errorInfo.message);
            writeJson(fullfile(outputPath,[caseName,'_snapshot_failure.json']),caught);
        end
    end

    function value = request(suffix,position,channel)
        value = struct('arena_id','default','robot_id',sessionConfig.robotId, ...
            'request_id',[sessionConfig.requestPrefix,'-',strrep(suffix,'_','-')]);
        if ~isempty(position)
            value.position = struct('x',position(1),'y',position(2));
            value.channel = channel;
        end
    end

    function addCheck(name,passed,duration,caught,evidence)
        checkCount = checkCount+1;
        assert(checkCount <= numel(checkNames),'Q3:HttpTestCapacity','HTTP check capacity exceeded.');
        checkNames(checkCount) = name;
        checkPassed(checkCount) = logical(passed);
        checkDuration(checkCount) = duration;
        checkErrorId(checkCount) = string(caught.identifier);
        checkErrorMessage(checkCount) = string(caught.message);
        checkEvidence(checkCount) = evidence;
    end

    function remember(value)
        testCount = testCount+1;
        assert(testCount <= numel(testRecords),'Q3:HttpTestCapacity','HTTP case capacity exceeded.');
        testRecords{testCount} = value;
    end
end

function valid = httpFixtureRetryValid(fixture,scenario)
attempts = fixture.attempts;
executions = fixture.executions;
if isempty(attempts) || isempty(executions)
    valid = false;
    return
end
attemptIds = string({attempts.request_id});
executionIds = string({executions.request_id});
valid = numel(unique(executionIds)) == 8 && numel(unique(attemptIds)) == 8;
ids = unique(attemptIds);
repeated = strings(numel(ids),1);
repeatedCount = 0;
for index = 1:numel(ids)
    matching = attemptIds == ids(index);
    valid = valid && sum(executionIds == ids(index)) == 1;
    if sum(matching) > 1
        repeatedCount = repeatedCount+1;
        repeated(repeatedCount) = ids(index);
        selected = attempts(matching);
        valid = valid && sum(matching) == 2 && isscalar(unique(string({selected.body_sha256}))) ...
            && isscalar(unique(string({selected.body_utf8}))) && isscalar(unique(string({selected.path})));
    end
end
repeated = repeated(1:repeatedCount);
if scenario == "ok"
    valid = valid && isempty(repeated);
else
    expectedSuffix = "clear-one";
    if scenario == "drop_after_enter"
        expectedSuffix = "enter";
    elseif scenario == "drop_after_exit"
        expectedSuffix = "exit";
    end
    valid = valid && isscalar(repeated) && endsWith(repeated,"-"+expectedSuffix);
end
end

function [checks,outputPath] = validatePersistence(settings)
root = fileparts(mfilename('fullpath'));
resultRoot = fullfile(root,'运行结果');
if ~isfolder(resultRoot)
    [ok,message] = mkdir(resultRoot);
    assert(ok,'Q3:PersistenceTestOutput','Cannot create test parent: %s',message);
end
[~,token] = fileparts(tempname(resultRoot));
outputPath = fullfile(resultRoot,char("persistence_validation_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))+"_"+string(token)));
[ok,message] = mkdir(outputPath);
assert(ok,'Q3:PersistenceTestOutput','Cannot create test output: %s',message);
names = strings(32,1);
values = false(32,1);
checkCount = 0;
[solution,state,seedResult] = persistenceFixture(settings);
normalConfig = newCase('normal');
normalInput = seedResult;
normalInput.path = normalConfig.outputPath;
normalOutput = persistPracticeOutputs(solution,state,normalInput,normalConfig,settings);
normalJson = jsondecode(fileread(fullfile(normalConfig.outputPath,'result.json')));
normalMat = load(fullfile(normalConfig.outputPath,'solution.mat'));
normalSummary = fileread(fullfile(normalConfig.outputPath,'结果摘要.md'));
expectedArtifacts = {'actions.csv','逐步计费.csv','频道核验.csv','覆盖证书.csv','清除证书.csv', ...
    'solution.mat','结果摘要.md','result.json'};
add("Normal persistence commits all expected files",all(cellfun(@(name) isfile(fullfile(normalConfig.outputPath,name)),expectedArtifacts)));
add("Normal final JSON alone reports completed saved output",normalOutput.complete && normalJson.complete ...
    && string(normalJson.status) == "PRACTICE_COMPLETED" && isempty(normalJson.saveErrors));
add("Normal MAT has an execution record without a final complete flag",persistenceRecordSeparated(normalMat) ...
    && normalMat.executionRecord.executionChecksPassed);
add("Normal persisted evidence retains ten confirmed successful channels",normalJson.clearedCount == 10 ...
    && normalMat.executionRecord.clearedCount == 10 && sum(normalMat.solution.status == 2) == 10 ...
    && isequal(normalMat.state.clearedChannels,1:10));
add("Summary explicitly defers completion to readable result JSON",contains(normalSummary,'只有同目录result.json中的complete=true') ...
    && contains(normalSummary,'缺失或不可读均按记录不完整处理'));
summaryConfig = newCase('summary_blocked');
summaryBlock = fullfile(summaryConfig.outputPath,'结果摘要.md');
[ok,message] = mkdir(summaryBlock);
assert(ok,'Q3:PersistenceTestOutput','Cannot create summary blocker: %s',message);
summaryInput = seedResult;
summaryInput.path = summaryConfig.outputPath;
summaryOutput = persistPracticeOutputs(solution,state,summaryInput,summaryConfig,settings);
summaryJson = jsondecode(fileread(fullfile(summaryConfig.outputPath,'result.json')));
summaryMat = load(fullfile(summaryConfig.outputPath,'solution.mat'));
summaryArtifacts = string({summaryOutput.saveErrors.artifact});
add("Summary write failure makes final JSON incomplete",~summaryOutput.complete && ~summaryJson.complete ...
    && string(summaryJson.status) == "PRACTICE_INCOMPLETE" && any(summaryArtifacts == "结果摘要.md"));
add("Summary failure keeps the accepted clear count",summaryOutput.clearedCount == 10 ...
    && summaryJson.clearedCount == 10 && summaryMat.executionRecord.clearedCount == 10 ...
    && sum(summaryMat.solution.status == 2) == 10);
add("Earlier MAT cannot advertise stale final completion",persistenceRecordSeparated(summaryMat) ...
    && contains(summaryMat.executionRecord.completionAuthority,'result.json'));
add("Summary directory blocker is preserved without a moved temporary file",isfolder(summaryBlock) ...
    && ~isfile(summaryBlock) && persistenceDirectoryEmpty(summaryBlock));
jsonConfig = newCase('json_blocked');
jsonBlock = fullfile(jsonConfig.outputPath,'result.json');
[ok,message] = mkdir(jsonBlock);
assert(ok,'Q3:PersistenceTestOutput','Cannot create JSON blocker: %s',message);
jsonInput = seedResult;
jsonInput.path = jsonConfig.outputPath;
jsonOutput = persistPracticeOutputs(solution,state,jsonInput,jsonConfig,settings);
jsonArtifacts = string({jsonOutput.saveErrors.artifact});
jsonMat = load(fullfile(jsonConfig.outputPath,'solution.mat'));
backupMat = load(fullfile(jsonConfig.outputPath,'emergency-result.mat'));
jsonSummary = fileread(fullfile(jsonConfig.outputPath,'结果摘要.md'));
add("Final JSON write failure cannot return completed output",~jsonOutput.complete ...
    && string(jsonOutput.status) == "PRACTICE_INCOMPLETE" && any(jsonArtifacts == "result.json") ...
    && ~isfile(jsonBlock));
add("Final JSON failure preserves its directory blocker",isfolder(jsonBlock) && persistenceDirectoryEmpty(jsonBlock));
add("JSON failure preserves confirmed clear count in returned and MAT evidence",jsonOutput.clearedCount == 10 ...
    && jsonMat.executionRecord.clearedCount == 10 && backupMat.executionRecord.clearedCount == 10 ...
    && sum(backupMat.solution.status == 2) == 10 && isequal(backupMat.state.clearedChannels,1:10));
add("Emergency MAT records the failed save without a stale completion flag",persistenceRecordSeparated(backupMat) ...
    && ~backupMat.executionRecord.executionChecksPassed ...
    && any(string({backupMat.executionRecord.saveErrors.artifact}) == "result.json"));
add("Earlier MAT and summary cannot override the missing final JSON",persistenceRecordSeparated(jsonMat) ...
    && contains(jsonSummary,'缺失或不可读均按记录不完整处理') ...
    && ~contains(jsonSummary,'程序正常完成'));
guardConfig = newCase('directory_guards');
textBlock = fullfile(guardConfig.outputPath,'must_be_a_file.txt');
checkpointBlock = fullfile(guardConfig.outputPath,'checkpoint.mat');
[ok,message] = mkdir(textBlock);
assert(ok,'Q3:PersistenceTestOutput','Cannot create text blocker: %s',message);
[ok,message] = mkdir(checkpointBlock);
assert(ok,'Q3:PersistenceTestOutput','Cannot create checkpoint blocker: %s',message);
textRejected = false;
try
    writeText(textBlock,'Synthetic directory-target rejection test');
catch errorInfo
    textRejected = startsWith(string(errorInfo.identifier),"Q3:");
end
add("Atomic text writer rejects a directory destination",textRejected && isfolder(textBlock) ...
    && persistenceDirectoryEmpty(textBlock));
checkpointRejected = false;
try
    saveSnapshot(checkpointBlock,solution);
catch errorInfo
    checkpointRejected = startsWith(string(errorInfo.identifier),"Q3:");
end
add("Checkpoint writer rejects a directory destination",checkpointRejected && isfolder(checkpointBlock) ...
    && persistenceDirectoryEmpty(checkpointBlock));
baselinePath = fullfile(root,'官方演练','RJMF-ZQTG-A9BW-D7RV','actions.csv');
assert(isfile(baselinePath),'Q3:PersistenceReplaySource','The dedicated historical replay source is unavailable: %s',baselinePath);
baseline = readtable(baselinePath,'TextType','string','VariableNamingRule','preserve');
successRows = find(baseline.Path == "/clear" & baseline.Result == "success" & baseline.Accepted == 1);
baselineChannels = sort(baseline.Channel(successRows))';
add("Historical display replay reads fifteen unique accepted clear receipts",numel(successRows) == 15 ...
    && numel(unique(baselineChannels)) == 15);
replayConfig = newCase('official_baseline_display_replay');
replayConfig.caseCode = 'REPLAY-RJMF-ZQTG-A9BW-D7RV';
[updateBaseline,closeBaseline] = makeProgress(replayConfig);
replayCleanup = onCleanup(closeBaseline);
baselineProgress = struct('status',zeros(1,20),'serial',0,'phase',"clearing",'virtualTime',0, ...
    'detectedCount',0,'absentCount',0,'clearedCount',0,'failure',seedResult.failure, ...
    'recordType','HISTORICAL_DISPLAY_REPLAY_NOT_A_NEW_PRACTICE');
replayText = evalc('replayBaseline();');
writeText(fullfile(replayConfig.outputPath,'captured_console.txt'),replayText);
replayJson = jsondecode(fileread(fullfile(replayConfig.outputPath,'实时进度.json')));
replayMarkdown = fileread(fullfile(replayConfig.outputPath,'实时进度.md'));
add("Replaying every clear twice still prints exactly fifteen success lines",numel(strfind(replayText,'清除成功：')) == 15 ...
    && isscalar(strfind(replayText,'累计已清除15个')) && ~contains(replayText,'累计已清除16个'));
add("Historical replay final JSON retains exactly the original clear channels",replayJson.clearedCount == 15 ...
    && isequal(reshape(find(replayJson.status == 2),1,[]),baselineChannels) ...
    && replayJson.serial == successRows(end) ...
    && abs(replayJson.virtualTime-baseline.VirtualTime_s(successRows(end))) < 1e-9);
add("Historical replay report is marked as replay and shows fifteen",contains(replayMarkdown,'已确认清除：15个') ...
    && contains(replayMarkdown,'REPLAY-RJMF-ZQTG-A9BW-D7RV') ...
    && string(replayJson.recordType) == "HISTORICAL_DISPLAY_REPLAY_NOT_A_NEW_PRACTICE");
checks = table(names(1:checkCount),values(1:checkCount),'VariableNames',{'Check','Passed'});
writetable(checks,fullfile(outputPath,'必要验证.csv'),'Encoding','UTF-8');
save(fullfile(outputPath,'persistence_validation.mat'),'settings','solution','state','seedResult', ...
    'normalOutput','normalJson','normalMat','normalSummary','summaryOutput','summaryJson','summaryMat', ...
    'jsonOutput','jsonMat','backupMat','jsonSummary','textRejected','checkpointRejected', ...
    'baselinePath','successRows','baselineChannels','replayText','replayJson','replayMarkdown','checks','outputPath');
writeText(fullfile(outputPath,'验证说明.md'),sprintf('结果保存与历史显示重放专项验证。\n\n保存测试使用人为构造的最小状态夹具，只检查文件提交、最终状态口径和已确认数量保留，不是模型或官方演练成绩。\n\n目录故障均由本测试在全新输出目录创建，不修改权限、不删除文件、不碰未知目录。\n\n历史显示重放只读RJMF-ZQTG-A9BW-D7RV的actions.csv，将15条已接受成功清除各显示两遍；不向模拟器发送请求，不形成新的演练。\n\n本专项依赖该历史证据文件，不应作为缺少历史案例的通用最简运行前提。\n\n检查结果：%d/%d。证据见persistence_validation.mat与各子目录。\n',sum(checks.Passed),height(checks)));

    function add(name,value)
        checkCount = checkCount+1;
        assert(checkCount <= numel(names),'Q3:PersistenceTestCapacity','Persistence test capacity exceeded.');
        names(checkCount) = name;
        values(checkCount) = isscalar(value) && logical(value);
    end

    function config = newCase(name)
        path = fullfile(outputPath,name);
        [created,message] = mkdir(path);
        assert(created,'Q3:PersistenceTestOutput','Cannot create case output: %s',message);
        config = struct('outputPath',path,'caseCode','SYNTHETIC-PERSISTENCE-CASE','showProgressWindow',false, ...
            'robotId','PERSISTENCE_SYNTHETIC','variant','seven_geometry','version',settings.version);
    end

    function replayBaseline()
        for rowIndex = successRows'
            channel = baseline.Channel(rowIndex);
            baselineProgress.status(channel) = 2;
            baselineProgress.serial = rowIndex;
            baselineProgress.virtualTime = baseline.VirtualTime_s(rowIndex);
            baselineProgress.clearedCount = sum(baselineProgress.status == 2);
            updateBaseline(baselineProgress);
            updateBaseline(baselineProgress);
        end
    end
end

function [solution,state,result] = persistenceFixture(settings)
channels = (1:10)';
failure = struct('identifier','','message','','stack',struct('file',{},'name',{},'line',{}));
errors = struct('identifier',{},'message',{});
solution = struct('status',[2*ones(1,10),3*ones(1,10)],'coverage',true(7,20),'complete',true, ...
    'position',[0,0],'receiver',1,'virtualTime',50,'costs',[0,0,0,0,50],'callbackErrors',errors);
solution.tracks = cell(1,20);
for channel = channels'
    solution.tracks{channel} = struct('near',true,'anchor',[0,0],'bound',5,'polygon',[],'angle',NaN);
end
requestIds = "persistence-"+compose("%02d",(1:12)');
paths = ["/enter";repmat("/clear",10,1);"/exit"];
results = ["entered";repmat("success",10,1);"user_exit"];
times = [0;5*channels;50];
fixedCosts = [0;5*ones(10,1);0];
log = table(requestIds,paths,zeros(12,1),zeros(12,1),[NaN;channels;NaN],results,NaN(12,1), ...
    times,ones(12,1),true(12,1),'VariableNames', ...
    {'RequestId','Path','X_m','Y_m','Channel','Result','Bearing_deg','VirtualTime_s','Receiver','Accepted'});
accounting = table(requestIds,paths,zeros(12,1),fixedCosts,fixedCosts,times,times,zeros(12,1), ...
    true(12,1),(0:11)'/1000,'VariableNames', ...
    {'RequestId','Path','Movement_m','FixedCost_s','Increment_s','ExpectedTime_s','ReportedTime_s','Residual_s','Passed','ClientElapsed_s'});
state = struct('clearedChannels',1:10,'virtualTime',50,'programElapsed',0.011,'acceptedActions',12, ...
    'unresolved',false,'closed',true,'needsStop',false,'logErrors',errors,'confirmedCosts',[0,0,0,0,50], ...
    'log',log,'accountingDetails',accounting);
result = struct('status',"PRACTICE_COMPLETED",'complete',true,'mode','practice','problem',3,'version',settings.version, ...
    'caseCode','SYNTHETIC-PERSISTENCE-CASE','variant','seven_geometry','clearedCount',10,'virtualTime_s',50, ...
    'meanClearTime_s',5,'clientProgramElapsed_s',0.011,'acceptedActions',12,'timeResidual_s',0, ...
    'timeTolerance_s',13.1e-6,'unresolved',false,'failure',failure,'logErrors',errors,'callbackErrors',errors, ...
    'path','','evidence','SYNTHETIC_PERSISTENCE_FIXTURE_NOT_OFFICIAL');
end

function valid = persistenceRecordSeparated(value)
valid = isfield(value,'executionRecord') && ~isfield(value,'result');
if valid
    record = value.executionRecord;
    valid = ~isfield(record,'complete') && ~isfield(record,'status') ...
        && isfield(record,'executionChecksPassed') && isfield(record,'completionAuthority') ...
        && contains(record.completionAuthority,'result.json');
end
end

function empty = persistenceDirectoryEmpty(path)
entries = dir(path);
empty = isempty(entries(~ismember({entries.name},{'.','..'})));
end

function search = searchPolicy(name)
name = string(name);
if name == "release"
    name = "r1500_rot30";
end
search = struct('enabled',name ~= "legacy",'radius',1500,'rotation',0, ...
    'countLimit',name ~= "legacy",'observedCoverage',false,'reuseMode',"none", ...
    'separation',600,'alternateChannels',false);
if name == "legacy" || name == "cap"
    return
end
parts = split(name,"_");
assert(numel(parts) <= 2 && ismember(parts(1),["r1200","r1300","r1400","r1500"]),'Q3:SearchProfile','Unknown search profile.');
search.radius = str2double(extractAfter(parts(1),1));
search.observedCoverage = true;
if numel(parts) > 1
    suffix = parts(2);
    assert(ismember(suffix,["finish","frontier","alt","rot30"]),'Q3:SearchProfile','Unknown search suffix.');
    if suffix == "finish"
        search.reuseMode = "finish_only";
    elseif suffix == "frontier"
        search.reuseMode = "frontier";
    elseif suffix == "alt"
        search.alternateChannels = true;
    elseif suffix == "rot30"
        search.rotation = 30;
    end
end
search = validateSearchPolicy(search);
end

function search = validateSearchPolicy(search)
names = {'enabled','radius','rotation','countLimit','observedCoverage','reuseMode','separation','alternateChannels'};
assert(isstruct(search) && isscalar(search) && isequal(sort(fieldnames(search)),sort(names(:))), ...
    'Q3:SearchConfig','Search settings must contain exactly the published fields.');
for name = ["enabled","countLimit","observedCoverage","alternateChannels"]
    value = search.(name);
    assert(islogical(value) && isscalar(value),'Q3:SearchConfig','Search flags must be logical scalars.');
end
assert(validScalar(search.radius,1150,1700) && validScalar(search.rotation,0,360) ...
    && validScalar(search.separation,100,1500),'Q3:SearchConfig','Search geometry is out of range.');
bound = max(search.radius/sqrt(3),sqrt(1800^2+search.radius^2-3600*search.radius*cosd(30)));
assert(bound < 1000-1e-6,'Q3:SearchConfig','Station layout lacks a conservative continuous coverage guarantee.');
search.reuseMode = string(search.reuseMode);
assert(isscalar(search.reuseMode) && ismember(search.reuseMode,["none","finish_only","frontier"]), ...
    'Q3:SearchConfig','Unknown stop reuse policy.');
assert(search.reuseMode == "none" || search.observedCoverage,'Q3:SearchConfig','Stop reuse requires observed-coverage accounting.');
end

function ordered = scanOrder(channels,receiver,alternate)
if alternate && ~isempty(channels) && receiver > median(channels)
    channels = fliplr(channels);
end
ordered = [channels(channels == receiver),channels(channels ~= receiver)];
end

function valid = verifySearchEvidence(solution,log)
valid = false;
if ~isequal(size(solution.status),[1,20]) || ~all(solution.status == 2 | solution.status == 3) ...
        || ~isequal(size(solution.absenceReason),[1,20]) || ~isequal(size(solution.absenceProof),[1,20]) ...
        || isempty(solution.points) || size(solution.points,2) ~= 2 || any(~isfinite(solution.points),'all') ...
        || ~isequal(size(solution.coverage),[size(solution.points,1),20]) || ~islogical(solution.coverage)
    return
end
clears = unique(log.Channel(log.Path == "/clear" & log.Result == "success" & log.Accepted))';
positive = unique(log.Channel(log.Path == "/measure" & ismember(log.Result,["direction","near"]) & log.Accepted));
if ~isequal(sort(clears),find(solution.status == 2)) || ~all(ismember(positive,clears))
    return
end
if any(solution.absenceReason(solution.status == 3) == "fixed_stations")
    [covered,fixedProof] = certifyNoSignalDiskCover(solution.points);
    if ~covered || ~verifySquareCover(fixedProof)
        return
    end
end
for channel = find(solution.status == 3)
    rows = log.Path == "/measure" & log.Channel == channel & log.Result == "no_signal" & log.Accepted;
    observed = [log.X_m(rows),log.Y_m(rows)];
    reason = solution.absenceReason(channel);
    if reason == "count_limit"
        proof = solution.absenceProof{channel};
        if numel(clears) ~= 16 || isempty(proof) || numel(unique(proof.channels)) ~= 16 ...
                || ~all(ismember(proof.channels,clears))
            return
        end
    elseif reason == "fixed_stations"
        if ~all(solution.coverage(:,channel))
            return
        end
        for k = 1:size(solution.points,1)
            if ~any(vecnorm(observed-solution.points(k,:),2,2) <= 1e-8)
                return
            end
        end
    elseif reason == "observed_cover"
        proof = solution.absenceProof{channel};
        if isempty(proof) || ~verifySquareCover(proof)
            return
        end
        for k = 1:size(proof.centers,1)
            if ~any(vecnorm(observed-proof.centers(k,:),2,2) <= 1e-8)
                return
            end
        end
    else
        return
    end
end
valid = true;
end

function valid = verifySquareCover(certificate,receptionRadius)
if nargin < 2
    receptionRadius = 1000;
end
valid = false;
if ~isnumeric(receptionRadius) || ~isscalar(receptionRadius) || ~isreal(receptionRadius) || ~isfinite(receptionRadius) || receptionRadius <= 0 || receptionRadius > 1000
    return
end
if ~isstruct(certificate) || ~certificate.covered || certificate.targetRadius ~= 1800 ...
        || certificate.receptionRadius ~= receptionRadius || isempty(certificate.proof)
    return
end
leaves = certificate.proof;
centers = certificate.centers;
if any(~isfinite(leaves),'all') || any(~isfinite(centers),'all') || size(leaves,2) ~= 4 ...
        || size(centers,2) ~= 2 || any(leaves(:,3) <= 0) || any(leaves(:,4) < 1) ...
        || any(leaves(:,4) > size(centers,1)) || any(fix(leaves(:,4)) ~= leaves(:,4))
    return
end
queue = zeros(32768,4);
queue(1,:) = [0,0,1800,0];
head = 0;
tail = 1;
used = false(size(leaves,1),1);
while head < tail
    head = head+1;
    cellCenter = queue(head,1:2);
    width = queue(head,3);
    depth = queue(head,4);
    lower = max(abs(cellCenter)-width,0);
    if norm(lower) > 1800+1e-6
        continue
    end
    matches = find(all(leaves(:,1:3) == [cellCenter,width],2));
    if numel(matches) > 1
        return
    elseif isscalar(matches)
        k = matches;
        corners = cellCenter+width*[-1,-1;-1,1;1,-1;1,1];
        anchor = centers(leaves(k,4),:);
        if any(vecnorm(corners-anchor,2,2) > receptionRadius-1e-6)
            return
        end
        used(k) = true;
        continue
    end
    if depth >= 10 || tail+4 > size(queue,1)
        return
    end
    childWidth = width/2;
    offsets = childWidth*[-1,-1;1,-1;-1,1;1,1];
    queue(tail+(1:4),:) = [cellCenter+offsets,repmat([childWidth,depth+1],4,1)];
    tail = tail+4;
end
valid = all(used);
end


function [covered,certificate] = certifyNoSignalDiskCover(centers,targetRadius,receptionRadius,maxDepth,maxNodes)
if nargin < 2
    targetRadius = 1800;
end
if nargin < 3
    receptionRadius = 1000;
end
if nargin < 4
    maxDepth = 10;
end
if nargin < 5
    maxNodes = 8192;
end
covered = false;
certificate = struct('covered',false,'method',"continuous_square_quadtree", ...
    'reason',"invalid_input",'targetRadius',targetRadius,'receptionRadius',receptionRadius, ...
    'maxDepth',maxDepth,'maxNodes',maxNodes,'margin',NaN,'processedNodes',0, ...
    'coveredLeaves',0,'outsideLeaves',0,'deepestLevel',0,'proof',zeros(0,4), ...
    'witness',zeros(0,2),'centers',centers);
if ~isnumeric(centers) || ~isreal(centers) || size(centers,2) ~= 2 ...
        || any(~isfinite(centers),'all') || any(abs(centers) > 1e6,'all')
    return
end
inputs = {targetRadius,receptionRadius,maxDepth,maxNodes};
if ~all(cellfun(@(value) isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value),inputs))
    return
end
if targetRadius <= 0 || receptionRadius <= 0 ...
        || targetRadius > 1e6 || receptionRadius > 1e6 ...
        || maxDepth < 0 || maxDepth > 20 || maxDepth ~= floor(maxDepth) ...
        || maxNodes < 1 || maxNodes > 1e6 || maxNodes ~= floor(maxNodes)
    return
end
if isempty(centers)
    certificate.reason = "no_observations";
    return
end
scale = max([1;targetRadius;receptionRadius;abs(centers(:))]);
margin = 1e-6+64*eps(scale);
certificate.margin = margin;
innerRadius = receptionRadius-margin;
if innerRadius <= 0
    certificate.reason = "no_positive_conservative_radius";
    return
end
nodes = zeros(maxNodes,4);
nodes(1,:) = [0,0,targetRadius,0];
proof = zeros(maxNodes,4);
tail = 1;
head = 0;
coveredLeaves = 0;
outsideLeaves = 0;
while head < tail
    head = head+1;
    center = nodes(head,1:2);
    halfWidth = nodes(head,3);
    depth = nodes(head,4);
    certificate.processedNodes = head;
    certificate.deepestLevel = max(certificate.deepestLevel,depth);
    minimumDistance = hypot(max(abs(center(1))-halfWidth,0),max(abs(center(2))-halfWidth,0));
    if minimumDistance > targetRadius+margin
        outsideLeaves = outsideLeaves+1;
        continue
    end
    maximumDistances = hypot(abs(centers(:,1)-center(1))+halfWidth, ...
        abs(centers(:,2)-center(2))+halfWidth);
    winner = find(maximumDistances <= innerRadius,1);
    if ~isempty(winner)
        coveredLeaves = coveredLeaves+1;
        proof(coveredLeaves,:) = [center,halfWidth,winner];
        continue
    end
    if hypot(center(1),center(2)) <= targetRadius-margin ...
            && all(hypot(centers(:,1)-center(1),centers(:,2)-center(2)) > innerRadius)
        certificate.reason = "not_certified_point";
        certificate.witness = center;
        finish();
        return
    end
    if depth >= maxDepth
        certificate.reason = "depth_limit";
        finish();
        return
    end
    if tail+4 > maxNodes
        certificate.reason = "node_limit";
        finish();
        return
    end
    childHalfWidth = halfWidth/2;
    offsets = childHalfWidth*[-1,-1;1,-1;-1,1;1,1];
    nodes(tail+(1:4),:) = [center+offsets,repmat([childHalfWidth,depth+1],4,1)];
    tail = tail+4;
end
covered = true;
certificate.covered = true;
certificate.reason = "certified";
finish();

    function finish()
        certificate.coveredLeaves = coveredLeaves;
        certificate.outsideLeaves = outsideLeaves;
        certificate.proof = proof(1:coveredLeaves,:);
    end
end

function scenarios = boundedSearchScenarios(partition)
partition = string(partition);
assert(isscalar(partition) && ismember(partition,["development","holdout"]), ...
    'Q3:TestPartition','Use development or holdout.');
previous = rng;
cleanup = onCleanup(@() rng(previous));
if partition == "development"
    seed = 2026091102;
    familyCount = 4;
    prefix = 'D';
    rotation = 0;
else
    seed = 2026091103;
    familyCount = 6;
    prefix = 'H';
    rotation = 7.5;
end
rng(seed,'twister');
scenarios = repmat(struct('name','','sources',zeros(0,5)),familyCount*7,1);
errorChoices = [-1,0,1,2,3];
for family = 1:familyCount
    for count = 10:16
        index = (family-1)*7+count-9;
        channels = sort(randperm(20,count))';
        reach = 1000+500*rand(count,1);
        errorMode = errorChoices(1+mod((0:count-1)'+family,5));
        errorMode = errorMode(:);
        angle = 360*rand(count,1);
        radius = 1800*sqrt(rand(count,1));
        if family == 1
            angle = rotation+30+60*mod((0:count-1)',6);
            perturbation = repmat([-1e-7;0;1e-7],ceil(count/3),1);
            angle = angle+perturbation(1:count);
            radius(:) = 1800;
            radius(2:3:end) = 1799.999999;
            reach(:) = 1000;
        elseif family == 2
            radius = 450*sqrt(rand(count,1));
            reach(:) = 1000;
            if count < 16
                if ~ismember(20,channels)
                    channels(end) = 20;
                end
                radius(end) = 1800;
                angle(end) = 330+rotation;
            end
            radius(1:3) = [0;5;5.001];
        elseif family == 3
            if partition == "development"
                angle = rotation+(0:count-1)'*360/count;
                radius = 850+850*mod((0:count-1)',2);
                reach(1:2:end) = 1000;
                reach(2:2:end) = 1500;
            else
                angle(:) = 359.995+rotation;
                angle(2:2:end) = angle(2:2:end)+180;
                radius = linspace(1000-1e-6,1800,count)';
                reach(:) = 1000;
            end
        elseif family == 4
            if partition == "holdout"
                cluster = mod((0:count-1)',2);
                centers = [1150*cosd(rotation+45),1150*sind(rotation+45); ...
                    1150*cosd(rotation+225),1150*sind(rotation+225)];
                displacement = 200*sqrt(rand(count,1));
                position = centers(cluster+1,:)+displacement.*[cosd(angle),sind(angle)];
                radius = vecnorm(position,2,2);
                angle = atan2d(position(:,2),position(:,1));
                reach(:) = 1000;
            end
        elseif family == 5
            reach(1:3:end) = 1000;
            reach(2:3:end) = 1500;
        elseif family == 6
            angle = rotation+360*rand(count,1);
            radius = 1500+300*rand(count,1);
            reach(:) = 1000;
            errorMode(:) = 2;
            if count == 16
                if ~ismember(20,channels)
                    channels(end) = 20;
                end
                radius(end) = 1800;
                angle(end) = 330+rotation;
            end
        end
        sources = [channels,radius.*cosd(angle),radius.*sind(angle),reach,errorMode];
        assert(size(sources,1) == count && size(sources,2) == 5 ...
            && numel(unique(channels)) == count && all(isfinite(sources),'all') ...
            && all(vecnorm(sources(:,2:3),2,2) <= 1800+1e-8) ...
            && all(reach >= 1000 & reach <= 1500),'Q3:TestSources','Invalid synthetic scene.');
        scenarios(index).name = sprintf('%s%02d_N%02d',prefix,index,count);
        scenarios(index).sources = sources;
    end
end
end

function output = runSearchStudy(root,settings,config)
assert(isstruct(config) && isscalar(config) && isfield(config,'partition'), ...
    'Q3:SearchStudyConfig','A study partition is required.');
partition = string(config.partition);
assert(isscalar(partition) && ismember(partition,["development","holdout","regression"]), ...
    'Q3:SearchStudyConfig','Invalid study partition.');
if ~isfield(config,'profiles')
    assert(partition == "development",'Q3:SearchStudyConfig', ...
        'Holdout and regression require explicitly frozen profiles.');
    config.profiles = ["legacy","cap","r1200","r1300","r1400","r1500", ...
        "r1200_finish","r1300_finish","r1400_finish","r1500_finish", ...
        "r1300_frontier","r1500_frontier"];
end
profiles = reshape(string(config.profiles),1,[]);
assert(~isempty(profiles) && numel(unique(profiles)) == numel(profiles) ...
    && all(strlength(profiles) > 0) && ismember("legacy",profiles), ...
    'Q3:SearchStudyConfig','Use unique profiles including legacy.');
if ~isfield(config,'writeActionCsv')
    config.writeActionCsv = true;
end
assert(islogical(config.writeActionCsv) && isscalar(config.writeActionCsv), ...
    'Q3:SearchStudyConfig','writeActionCsv must be scalar logical.');
policies = cell(numel(profiles),1);
for profileIndex = 1:numel(profiles)
    assert(~isempty(regexp(char(profiles(profileIndex)),'^[A-Za-z0-9_]+$','once')), ...
        'Q3:SearchStudyConfig','Invalid profile name.');
    policies{profileIndex} = searchPolicy(profiles(profileIndex));
end
if partition == "regression"
    scenarios = buildScenarios();
else
    scenarios = boundedSearchScenarios(partition);
end
outputPath = fullfile(root,'运行结果',char("search_study_"+partition+"_" ...
    +string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(outputPath),'Q3:Output','Study output already exists.');
mkdir(outputPath);
save(fullfile(outputPath,'研究配置.mat'),'settings','config','profiles','policies','scenarios');
records = cell(numel(scenarios)*numel(profiles),1);
for sceneIndex = 1:numel(scenarios)
    scene = scenarios(sceneIndex);
    sourceTable = array2table(scene.sources,'VariableNames', ...
        {'Channel','X_m','Y_m','Radius_m','ErrorMode'});
    writetable(sourceTable,fullfile(outputPath,sprintf('场景_%03d_%s.csv', ...
        sceneIndex,scene.name)),'Encoding','UTF-8');
    for profileIndex = 1:numel(profiles)
        routeConfig = settings;
        routeConfig.variant = "seven_geometry";
        routeConfig.search = policies{profileIndex};
        [exchange,report] = makeWorld(scene.sources);
        timer = tic;
        [solution,failure] = solveRoute(exchange,routeConfig);
        elapsed = toc(timer);
        world = report();
        verificationFailure = "";
        try
            evidenceValid = verifySearchEvidence(solution,world.log);
            assert(islogical(evidenceValid) && isscalar(evidenceValid), ...
                'Q3:SearchEvidence','Search verifier must return a scalar logical.');
            [boundValid,polygonValid] = checkHistory(solution.history,scene.sources);
            historyValid = boundValid && polygonValid;
        catch errorInfo
            evidenceValid = false;
            historyValid = false;
            verificationFailure = string(errorInfo.identifier)+": "+string(errorInfo.message);
        end
        runSucceeded = isempty(failure.identifier) && solution.complete;
        fullClear = runSucceeded && all(world.cleared) ...
            && all(solution.status(scene.sources(:,1)) == 2);
        absentChannels = setdiff(1:20,scene.sources(:,1));
        absenceValid = all(solution.status(absentChannels) == 3);
        confirmed = unique(world.log.Channel(world.log.Path == "/clear" ...
            & world.log.Result == "success"));
        countValid = numel(confirmed) == sum(world.cleared) ...
            && isequal(sort(confirmed(:)),sort(scene.sources(world.cleared,1)));
        timeResidual = abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time);
        localLimitsValid = all(solution.localMoves <= 7) && all(solution.localMeasures <= 6);
        moveCount = sum(vecnorm(diff([0,0;world.log{:,{'X_m','Y_m'}}]),2,2) > 1e-9);
        lastClear = find(world.log.Path == "/clear" & world.log.Result == "success",1,'last');
        afterLastClear = NaN;
        if ~isempty(lastClear)
            afterLastClear = world.time-world.log.VirtualTime_s(lastClear);
        end
        opportunisticMeasures = NaN;
        opportunisticCountAvailable = isfield(solution,'opportunisticMeasures');
        if opportunisticCountAvailable
            opportunisticMeasures = solution.opportunisticMeasures;
            opportunisticCountAvailable = isscalar(opportunisticMeasures) ...
                && isfinite(opportunisticMeasures) && opportunisticMeasures >= 0 ...
                && fix(opportunisticMeasures) == opportunisticMeasures;
        end
        searchMeasures = NaN;
        if isfield(solution,'searchMeasures')
            searchMeasures = solution.searchMeasures;
        end
        meanClearTime = NaN;
        if any(world.cleared)
            meanClearTime = world.time/sum(world.cleared);
        end
        record = struct('Partition',partition,'Scenario',string(scene.name), ...
            'Profile',profiles(profileIndex),'SourceCount',height(sourceTable), ...
            'Cleared',sum(world.cleared),'ClearRatio',sum(world.cleared)/height(sourceTable), ...
            'RunSucceeded',runSucceeded,'FullClear',fullClear,'AbsenceValid',absenceValid, ...
            'EvidenceValid',evidenceValid,'HistoryValid',historyValid,'CountValid',countValid, ...
            'LocalLimitsValid',localLimitsValid,'VirtualTime_s',world.time, ...
            'MeanClearTime_s',meanClearTime, ...
            'Distance_m',solution.costs(1),'Moves',moveCount,'Switches',solution.costs(2), ...
            'Measures',solution.costs(3)/5,'SearchMeasures',searchMeasures, ...
            'OpportunisticMeasures',opportunisticMeasures, ...
            'OpportunisticCountAvailable',opportunisticCountAvailable, ...
            'FailedClears',solution.costs(4)/3,'SuccessClears',solution.costs(5)/5, ...
            'Actions',height(world.log),'AfterLastClear_s',afterLastClear, ...
            'LocalWallTime_s',elapsed,'TimeResidual_s',timeResidual, ...
            'FailureIdentifier',string(failure.identifier),'FailureMessage',string(failure.message), ...
            'VerificationFailure',verificationFailure);
        records{(sceneIndex-1)*numel(profiles)+profileIndex} = record;
        stem = sprintf('%03d_%s_%s',sceneIndex,scene.name,profiles(profileIndex));
        save(fullfile(outputPath,['现场_',stem,'.mat']),'solution','world','failure','routeConfig');
        if config.writeActionCsv
            writetable(world.log,fullfile(outputPath,['动作_',stem,'.csv']),'Encoding','UTF-8');
        end
        fprintf('%s | %s | %d/%d | %.3f s | evidence=%d | failure=%s\n', ...
            scene.name,profiles(profileIndex),sum(world.cleared),height(sourceTable), ...
            world.time,evidenceValid,failure.identifier);
    end
end
summary = struct2table(vertcat(records{:}));
summary.LegacyTime_s = NaN(height(summary),1);
summary.Savings_s = NaN(height(summary),1);
summary.SavingsPercent = NaN(height(summary),1);
summary.PairedValid = false(height(summary),1);
valid = summary.RunSucceeded & summary.FullClear & summary.AbsenceValid ...
    & summary.EvidenceValid & summary.HistoryValid & summary.CountValid ...
    & summary.LocalLimitsValid & summary.FailedClears == 0 & summary.TimeResidual_s < 1e-7;
for sceneIndex = 1:numel(scenarios)
    rows = find(summary.Scenario == string(scenarios(sceneIndex).name));
    baseline = rows(summary.Profile(rows) == "legacy");
    assert(isscalar(baseline),'Q3:SearchStudy','Each scenario requires exactly one legacy row.');
    summary.LegacyTime_s(rows) = summary.VirtualTime_s(baseline);
    paired = valid(rows) & valid(baseline);
    selected = rows(paired);
    summary.PairedValid(selected) = true;
    summary.Savings_s(selected) = summary.VirtualTime_s(baseline)-summary.VirtualTime_s(selected);
    summary.SavingsPercent(selected) = 100*summary.Savings_s(selected)/summary.VirtualTime_s(baseline);
end
summary.ChecksPassed = valid;
writetable(summary,fullfile(outputPath,'搜索配对结果.csv'),'Encoding','UTF-8');
save(fullfile(outputPath,'研究结果.mat'),'summary','settings','config','profiles','policies','scenarios');
output = struct('path',outputPath,'summary',summary,'partition',partition, ...
    'profiles',profiles,'allPassed',all(valid),'automaticSelection',false);
end

function output = validateSearch(root,settings)
path = fullfile(root,'运行结果',char("validate_search_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
mkdir(path);
names = strings(0,1);
passed = false(0,1);
policy = searchPolicy("r1300_frontier");
add("Frontier profile is active",policy.reuseMode == "frontier");
policy = searchPolicy("r1300_finish");
add("Finish-only profile is active",policy.reuseMode == "finish_only");
policy = searchPolicy("r1300_alt");
add("Alternate scan profile is active",policy.alternateChannels);
policy = searchPolicy("r1300_rot30");
add("Rotation profile is active",policy.rotation == 30);
for radius = [1200,1300,1400,1500]
    angles = (0:5)'*60;
    points = [0,0;radius*cosd(angles),radius*sind(angles)];
    [covered,proof] = certifyNoSignalDiskCover(points);
    add("Continuous coverage radius "+radius,covered && verifySquareCover(proof));
    for removed = 1:7
        subset = points;
        subset(removed,:) = [];
        add("Missing station is not falsely certified "+radius+"-"+removed,~certifyNoSignalDiskCover(subset));
    end
end
add("Empty observations do not certify",~certifyNoSignalDiskCover(zeros(0,2)));
add("Invalid observations do not certify",~certifyNoSignalDiskCover([NaN,0]));
add("Node budget exhaustion cannot certify",~certifyNoSignalDiskCover(points,1800,1000,10,1));
add("Depth budget exhaustion cannot certify",~certifyNoSignalDiskCover(points,1800,1000,0,8192));
[~,proof] = certifyNoSignalDiskCover(points);
bad = proof;
bad.proof(1,:) = [];
add("Independent verifier rejects missing proof leaf",~verifySquareCover(bad));
bad = proof;
bad.proof(end+1,:) = bad.proof(1,:);
add("Independent verifier rejects duplicate proof leaf",~verifySquareCover(bad));
bad = proof;
bad.centers(:) = 0;
add("Independent verifier rejects false covering circles",~verifySquareCover(bad));
config = settings;
config.variant = "seven_geometry";
for count = [10,15,16]
    sources = [(1:count)',zeros(count,2),1000*ones(count,1),zeros(count,1)];
    if count < 16
        sources(end,1:3) = [20,1800*cosd(330),1800*sind(330)];
    end
    config.search = searchPolicy("legacy");
    [exchange,report] = makeWorld(sources);
    [old,oldFailure] = solveRoute(exchange,config);
    oldWorld = report();
    bad = old;
    bad.points = zeros(0,2);
    bad.coverage = false(0,20);
    add("Empty station certificate rejected "+count,~verifySearchEvidence(bad,oldWorld.log));
    bad = old;
    bad.points(:) = 0;
    add("Noncovering station certificate rejected "+count,~verifySearchEvidence(bad,oldWorld.log));
    bad = old;
    bad.status(end) = [];
    add("Malformed terminal status rejected "+count,~verifySearchEvidence(bad,oldWorld.log));
    badLog = oldWorld.log;
    absent = find(old.status == 3,1);
    row = find(badLog.Path == "/measure" & badLog.Channel == absent,1);
    badLog.Result(row) = "direction";
    add("Uncleared positive observation rejected "+count,~verifySearchEvidence(old,badLog));
    for profile = ["cap","r1300_finish","r1300_frontier","r1300_alt"]
        config.search = searchPolicy(profile);
        [exchange,report] = makeWorld(sources);
        [solution,failure] = solveRoute(exchange,config);
        world = report();
        add("Full clear "+count+" "+profile,isempty(failure.identifier) && all(world.cleared));
        add("Accepted evidence "+count+" "+profile,verifySearchEvidence(solution,world.log));
        add("Confirmed exit "+count+" "+profile,solution.exited && world.log.Path(end) == "/exit");
        if count < 16
            add("No upper limit shortcut below sixteen "+count+" "+profile,~any(solution.absenceReason == "count_limit"));
            if profile == "r1300_frontier"
                add("Frontier performs charged observations "+count,solution.opportunisticMeasures > 0 ...
                    && sum(world.log.Path == "/measure" & world.log.Accepted) >= solution.searchMeasures);
            end
        else
            add("Upper limit ends without fabricated station scans "+profile, ...
                all(solution.absenceReason(solution.status == 3) == "count_limit") ...
                && ~all(solution.coverage,'all') && world.time <= oldWorld.time && isempty(oldFailure.identifier) && old.complete);
        end
        save(fullfile(path,char("case_"+count+"_"+profile+".mat")),'solution','world','failure','sources');
    end
end
previous = rng;
dev = boundedSearchScenarios("development");
add("Development generator restores RNG",isequal(previous,rng));
holdout = boundedSearchScenarios("holdout");
add("Balanced independent scene partitions",numel(dev) == 28 && numel(holdout) == 42 ...
    && all(arrayfun(@(n) sum(arrayfun(@(s)size(s.sources,1),dev) == n),10:16) == 4));
config.search = searchPolicy("cap");
config.search.radius = 1100;
try
    [exchange,~] = makeWorld(dev(1).sources);
    [~,failure] = solveRoute(exchange,config);
    badInput = ~isempty(failure.identifier);
catch errorInfo
    badInput = strcmp(errorInfo.identifier,'Q3:SearchConfig');
end
add("Invalid search layout rejected",badInput);
checks = table(names,passed,'VariableNames',{'Check','Passed'});
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks);
assert(all(passed),'Q3:SearchValidation','Search validation failed; results were saved.');
    function add(name,value)
        names(end+1,1) = name;
        passed(end+1,1) = isscalar(value) && logical(value);
    end
end


function distance = routeDistance(position,points)
distance = sum(vecnorm(diff([position;points]),2,2));
end

function [order,distance] = shortestStationPath(position,points)
n = size(points,1);
assert(n <= 7 && size(points,2) == 2 && all(isfinite([position;points]),'all'), ...
    'Q3:StationRoute','An open route requires at most seven finite stations.');
if n == 0
    order = zeros(1,0);
    distance = 0;
    return
end
persistent orders
if isempty(orders)
    orders = cell(1,7);
end
if isempty(orders{n})
    orders{n} = sortrows(perms(1:n));
end
paths = orders{n};
lengths = vecnorm(points(paths(:,1),:)-position,2,2);
for k = 2:n
    lengths = lengths+vecnorm(points(paths(:,k),:)-points(paths(:,k-1),:),2,2);
end
minimum = min(lengths);
winner = find(lengths <= minimum+1e-8,1);
order = paths(winner,:);
distance = lengths(winner);
end

function tableValue = routeDecisionTable(solution)
records = solution.decisions;
n = numel(records);
serial = zeros(n,1);
requestId = strings(n,1);
basedOn = strings(n,1);
phase = strings(n,1);
reason = strings(n,1);
path = strings(n,1);
channel = NaN(n,1);
result = strings(n,1);
accepted = false(n,1);
integrated = false(n,1);
before = zeros(n,1);
after = zeros(n,1);
distance = zeros(n,1);
changed = strings(n,1);
for k = 1:n
    d = records(k);
    serial(k) = d.serial;
    requestId(k) = d.requestId;
    basedOn(k) = d.basedOnRequestId;
    phase(k) = d.phase;
    reason(k) = d.reason;
    path(k) = d.path;
    if isfield(d.request,'channel')
        channel(k) = d.request.channel;
    end
    if isfield(d.response,'measure_result')
        result(k) = string(d.response.measure_result);
    elseif isfield(d.response,'clear_result')
        result(k) = string(d.response.clear_result);
    elseif isfield(d.response,'exit_reason')
        result(k) = string(d.response.exit_reason);
    elseif d.accepted
        result(k) = "entered";
    end
    accepted(k) = d.accepted;
    integrated(k) = d.integrated;
    before(k) = d.virtualBefore_s;
    after(k) = d.virtualAfter_s;
    distance(k) = d.costsAfter(1)-d.costsBefore(1);
    ids = find(d.statusBefore ~= d.statusAfter);
    changed(k) = strjoin(string(ids)+":"+string(d.statusBefore(ids))+">"+string(d.statusAfter(ids)),";");
end
tableValue = table(serial,requestId,basedOn,phase,reason,path,channel,result,accepted,integrated, ...
    before,after,distance,changed,'VariableNames',{'Serial','RequestId','BasedOnRequestId','Phase', ...
    'Reason','Path','Channel','Result','Accepted','Integrated','Before_s','After_s','Distance_m','StateChanges'});
end

function valid = verifyRouteDecisions(solution,log)
valid = numel(solution.decisions) == height(log) && verifyMobileHistory(solution,log);
if ~valid
    return
end
actualCoverage = false(size(solution.coverage));
activePoints = solution.points;
mobileCursor = 1;
mobileActive = isfield(solution,'mobileMode') && solution.mobileMode ~= "none";
if mobileActive
    activePoints = solution.mobileInitialPoints;
end
negative = repmat({zeros(0,2)},1,20);
for k = 1:height(log)
    d = solution.decisions(k);
    if mobileActive && mobileCursor <= numel(solution.mobileHistory) && solution.mobileHistory(mobileCursor).serialBefore == k-1
        e = solution.mobileHistory(mobileCursor);
        activePoints(e.station,:) = e.destination;
        mobileCursor = mobileCursor+1;
    end
    if d.requestId ~= log.RequestId(k) || d.path ~= log.Path(k) || ~d.accepted || ~d.integrated ...
            || strlength(d.reason) == 0 || d.virtualAfter_s ~= log.VirtualTime_s(k) ...
            || d.response.virtual_time_s ~= log.VirtualTime_s(k) || ~d.response.accepted
        valid = false;
        return
    end
    if k > 1
        previous = solution.decisions(k-1);
        changed = find(d.statusBefore ~= previous.statusAfter);
        proofUpdates = all(previous.statusAfter(changed) == 0 & d.statusBefore(changed) == 3);
        if d.basedOnRequestId ~= previous.requestId || d.virtualBefore_s ~= previous.virtualAfter_s ...
                || ~isequal(d.positionBefore,previous.positionAfter) || ~proofUpdates
            valid = false;
            return
        end
    end
    if d.path == "/measure"
        channel = d.request.channel;
        if d.statusBefore(channel) >= 2 || d.response.measure_result ~= log.Result(k)
            valid = false;
            return
        end
        if d.response.measure_result == "direction" && d.response.svd_deg ~= log.Bearing_deg(k)
            valid = false;
            return
        end
        at = [d.request.position.x,d.request.position.y];
        if log.Result(k) == "no_signal"
            if any(vecnorm(negative{channel}-at,2,2) <= 1e-8)
                valid = false;
                return
            end
            negative{channel}(end+1,:) = at;
        end
        matches = vecnorm(activePoints-at,2,2) <= 1e-8;
        actualCoverage(matches,channel) = true;
    end
    if any(d.coverageAfter & ~actualCoverage,'all')
        valid = false;
        return
    end
end
end

function scenarios = routeScenarios(partition)
partition = string(partition);
if ismember(partition,["development","holdout"])
    scenarios = boundedSearchScenarios(partition);
elseif partition == "regression"
    scenarios = buildScenarios();
else
    assert(ismember(partition,["fresh","fresh_next","group2_fresh","group3_fresh","group3_final"]),'Q3:RoutePartition','Unknown route study partition.');
    previous = rng;
    cleanup = onCleanup(@() rng(previous));
    if partition == "group3_final"
        rng(2026091207,'twister');
    elseif partition == "group3_fresh"
        rng(2026091203,'twister');
    elseif partition == "group2_fresh"
        rng(2026091162,'twister');
    elseif partition == "fresh_next"
        rng(2026091131,'twister');
    else
        rng(2026091121,'twister');
    end
    scenarios = repmat(struct('name','','sources',zeros(0,5)),70,1);
    for family = 1:10
        for count = 10:16
            index = 7*(family-1)+count-9;
            channels = sort(randperm(20,count))';
            angle = 360*rand(count,1);
            radius = 1800*sqrt(rand(count,1));
            reach = 1000+500*rand(count,1);
            mode = [-1,0,1,2,3];
            errors = mode(randi(5,count,1));
            if family == 2
                radius = 1700+100*rand(count,1);
                reach(:) = 1000;
            elseif family == 3
                radius = 350*sqrt(rand(count,1));
                radius(end) = 1800;
                reach(:) = 1000;
            elseif family == 4
                angle = 14+60*mod((0:count-1)',6)+1e-6*randn(count,1);
                radius(:) = 1800;
                reach(:) = 1000;
            elseif family == 5
                angle = 360*rand+180*mod((0:count-1)',2)+5*randn(count,1);
                radius = 900+900*rand(count,1);
                reach(:) = 1000;
            elseif family == 6
                angle = 360*rand+20*randn(count,1);
                radius = 600+1200*rand(count,1);
            elseif family == 7
                radius(1:3) = [0;5;5.001];
                reach(:) = 1000;
            elseif family == 8
                radius(:) = 1800;
                reach(:) = 1500;
            elseif family == 9
                reach(:) = 1000;
                errors(:) = 2;
            end
            scenarios(index).name = sprintf('F%02d_N%02d',index,count);
            scenarios(index).sources = [channels,radius.*cosd(angle),radius.*sind(angle),reach,errors(:)];
        end
    end
end
end

function output = runRouteStudy(root,settings,config)
assert(isstruct(config) && isscalar(config) && all(isfield(config,{'partition','profiles'})), ...
    'Q3:RouteStudy','A partition and explicit profiles are required.');
profiles = reshape(string(config.profiles),1,[]);
assert(numel(unique(profiles)) == numel(profiles) && ismember("v040",profiles), ...
    'Q3:RouteStudy','A paired v0.4.0 release baseline is required.');
scenarios = routeScenarios(config.partition);
path = fullfile(root,'运行结果',char("route_study_"+string(config.partition)+"_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Study output already exists.');
mkdir(path);
save(fullfile(path,'研究配置.mat'),'settings','config','scenarios');
records = cell(numel(scenarios)*numel(profiles),1);
for i = 1:numel(scenarios)
    scene = scenarios(i);
    writetable(array2table(scene.sources,'VariableNames',{'Channel','X_m','Y_m','Radius_m','ErrorMode'}), ...
        fullfile(path,sprintf('场景_%03d_%s.csv',i,scene.name)),'Encoding','UTF-8');
    for j = 1:numel(profiles)
        routeConfig = settings;
        routeConfig.variant = "seven_geometry";
        routeConfig.search = searchPolicy("release");
        routeConfig.route = profiles(j);
        [exchange,report] = makeWorld(scene.sources);
        timer = tic;
        [solution,failure] = solveRoute(exchange,routeConfig);
        elapsed = toc(timer);
        world = report();
        [boundValid,polygonValid] = checkHistory(solution.history,scene.sources);
        evidence = verifySearchEvidence(solution,world.log);
        decisionValid = verifyRouteDecisions(solution,world.log) && verifyRouteProbes(solution);
        fullClear = all(world.cleared) && solution.complete && isempty(failure.identifier);
        clearRows = find(world.log.Path == "/clear" & world.log.Result == "success");
        firstClear = NaN;
        tail = NaN;
        if ~isempty(clearRows)
            firstClear = world.log.VirtualTime_s(clearRows(1));
            tail = world.time-world.log.VirtualTime_s(clearRows(end));
        end
        residual = abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time);
        valid = fullClear && evidence && decisionValid && boundValid && polygonValid ...
            && residual < 1e-7 && solution.costs(4) == 0 && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6);
        records{(i-1)*numel(profiles)+j} = struct('Partition',string(config.partition), ...
            'Scenario',string(scene.name),'Profile',profiles(j),'SourceCount',size(scene.sources,1), ...
            'Cleared',sum(world.cleared),'FullClear',fullClear,'EvidenceValid',evidence, ...
            'DecisionValid',decisionValid,'HistoryValid',boundValid && polygonValid,'ChecksPassed',valid, ...
            'VirtualTime_s',world.time,'MeanClearTime_s',world.time/max(1,sum(world.cleared)), ...
            'FirstClear_s',firstClear,'AfterLastClear_s',tail,'Distance_m',solution.costs(1), ...
            'Switches',solution.costs(2),'Measures',solution.costs(3)/5,'SearchMeasures',solution.searchMeasures, ...
            'ResumeMeasures',solution.opportunisticMeasures,'FailedClears',solution.costs(4)/3, ...
            'RouteProbeMeasures',solution.routeProbeMeasures, ...
            'Actions',height(world.log),'WallTime_s',elapsed,'TimeResidual_s',residual, ...
            'FailureIdentifier',string(failure.identifier),'FailureMessage',string(failure.message));
        stem = sprintf('%03d_%s_%s',i,scene.name,profiles(j));
        save(fullfile(path,['现场_',stem,'.mat']),'solution','world','routeConfig','failure');
        writetable(world.log,fullfile(path,['动作_',stem,'.csv']),'Encoding','UTF-8');
        writetable(routeDecisionTable(solution),fullfile(path,['决策_',stem,'.csv']),'Encoding','UTF-8');
        fprintf('%s | %s | %d/%d | %.3f s | checks=%d | %s\n',scene.name,profiles(j), ...
            sum(world.cleared),size(scene.sources,1),world.time,valid,failure.identifier);
    end
end
summary = struct2table(vertcat(records{:}));
summary.BaselineTime_s = zeros(height(summary),1);
summary.Savings_s = zeros(height(summary),1);
summary.SavingsPercent = zeros(height(summary),1);
for i = 1:numel(scenarios)
    rows = summary.Scenario == string(scenarios(i).name);
    base = summary.VirtualTime_s(rows & summary.Profile == "v040");
    summary.BaselineTime_s(rows) = base;
    paired = rows & summary.ChecksPassed;
    baselineValid = summary.ChecksPassed(rows & summary.Profile == "v040");
    summary.Savings_s(rows) = NaN;
    summary.SavingsPercent(rows) = NaN;
    if baselineValid
        summary.Savings_s(paired) = base-summary.VirtualTime_s(paired);
        summary.SavingsPercent(paired) = 100*summary.Savings_s(paired)/base;
    end
end
writetable(summary,fullfile(path,'路线配对结果.csv'),'Encoding','UTF-8');
save(fullfile(path,'研究结果.mat'),'summary','config','settings');
if isfield(config,'makeFigures') && isequal(config.makeFigures,true)
    makeRouteFigures(summary,path);
end
output = struct('path',path,'allPassed',all(summary.ChecksPassed),'summary',summary);
end

function output = validateRoute(root,settings)
path = fullfile(root,'运行结果',char("validate_route_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
mkdir(path);
checks = table(strings(0,1),false(0,1),'VariableNames',{'Check','Passed'});
add("Empty open route",isempty(shortestStationPath([0,0],zeros(0,2))));
[order,distance] = shortestStationPath([0,0],[1,0;2,0;3,0]);
add("Known open route optimum",isequal(order,[1,2,3]) && abs(distance-3) < 1e-12);
add("No implicit return to origin",distance == 3);
entry = [0,2;3,1;1,-3;4,4];
exitPoints = entry+[0.3,-0.4;-0.5,0.2;0.1,0.1;-0.2,0.4];
for constrained = [false,true]
    [order,distance] = planServiceRoute([0,0],entry,exitPoints,2,constrained);
    alternatives = perms(1:4);
    lengths = Inf(size(alternatives,1),1);
    for row = 1:size(alternatives,1)
        permutation = alternatives(row,:);
        if constrained && ~all(permutation(1:2) <= 2)
            continue
        end
        trajectory = zeros(9,2);
        for eventIndex = 1:4
            event = permutation(eventIndex);
            trajectory(2*eventIndex:2*eventIndex+1,:) = [entry(event,:);exitPoints(event,:)];
        end
        lengths(row) = sum(vecnorm(diff(trajectory),2,2));
    end
    add("Small directed service route independently enumerated "+constrained, ...
        abs(distance-min(lengths)) < 1e-8 && numel(unique(order)) == 4);
end
previous = rng;
scenes = routeScenarios("fresh");
add("Fresh generator restores random state",isequal(rng,previous));
add("Fresh scenes have balanced legal counts",numel(scenes) == 70 && all(arrayfun(@(x)size(x.sources,1),scenes) >= 10));
for count = [10,16]
    sources = [(1:count)',zeros(count,2),1000*ones(count,1),zeros(count,1)];
    if count == 10
        sources(end,1:3) = [20,-1800,0];
    end
    for profile = ["immediate_return","immediate_resume","batch_adaptive","batch_resume","joint_route","target_route","sweep_route","sweep_probe","joint_probe","path_probe"]
        cfg = settings;
        cfg.variant = "seven_geometry";
        cfg.search = searchPolicy("release");
        cfg.route = profile;
        [exchange,report] = makeWorld(sources);
        [solution,failure] = solveRoute(exchange,cfg);
        world = report();
        if ~isempty(failure.identifier)
            disp(failure);
            disp(failure.stack);
        end
        tag = count+" "+profile;
        add("Full clear "+tag,all(world.cleared) && isempty(failure.identifier) && solution.complete);
        add("Evidence and actual positions "+tag,verifySearchEvidence(solution,world.log));
        add("Feedback order and retired channel exclusion "+tag,verifyRouteDecisions(solution,world.log));
        if count == 10
            rows = find(world.log.Channel == 20 & string(world.log.Path) == "/measure");
            add("Initially silent channel is found later "+tag,~isempty(rows) && world.log.Result(rows(1)) == "no_signal" && any(world.log.Result(rows) ~= "no_signal"));
            add("No count shortcut below sixteen "+tag,~any(solution.absenceReason == "count_limit"));
        else
            add("Sixteen source shortcut keeps actual coverage "+tag,all(solution.absenceReason(solution.status == 3) == "count_limit") && ~all(solution.coverage,'all'));
        end
        bad = solution;
        row = find(arrayfun(@(d)d.path == "/measure",bad.decisions),1);
        if isempty(row)
            continue
        end
        bad.decisions(row).basedOnRequestId = "fabricated";
        add("Reject broken feedback chain "+tag,~verifyRouteDecisions(bad,world.log));
        bad = solution;
        bad.decisions(row).coverageAfter(:) = true;
        add("Reject invented fixed coverage "+tag,~verifyRouteDecisions(bad,world.log));
        save(fullfile(path,char("case_"+count+"_"+profile+".mat")),'solution','world','failure','sources');
    end
end
cfg.route = "unknown";
try
    solveRoute(exchange,cfg);
    rejected = false;
catch info
    rejected = strcmp(info.identifier,'Q3:RouteConfig');
end
add("Invalid route rejected before dispatch",rejected);
cfg.route = "joint_route";
sources = [(1:9)',zeros(9,2),1000*ones(9,1),zeros(9,1);20,-1800,0,1000,0];
[exchange,report] = snapshotFaultWorld(sources);
[solution,failure] = solveRoute(exchange,cfg);
fault = report();
add("Joint route preserves confirmed clears after transport failure", ...
    strcmp(failure.identifier,'Q3:SnapshotInjected') && sum(solution.status == 2) == fault.confirmedClears ...
    && fault.confirmedClears >= 1 && ~solution.complete && ~solution.exited);
add("Unanswered action cannot advance route state", ...
    solution.lastAction.accepted == false && solution.decisions(end).accepted == false ...
    && solution.lastAcceptedAction.serial < solution.serial ...
    && isequal(solution.decisions(end).statusBefore,solution.decisions(end).statusAfter) ...
    && solution.decisions(end).virtualBefore_s == solution.decisions(end).virtualAfter_s);
save(fullfile(path,'joint_route_fault.mat'),'solution','fault','failure');
probeScenes = routeScenarios("development");
for sceneIndex = [11,13,28]
    sources = probeScenes(sceneIndex).sources;
    cfg.route = "path_probe";
    [exchange,report] = makeWorld(sources);
    [solution,failure] = solveRoute(exchange,cfg);
    world = report();
    tag = string(probeScenes(sceneIndex).name);
    add("Probe full clear and unchanged geometry "+tag, ...
        all(world.cleared) && isempty(failure.identifier) && solution.complete && ...
        all(solution.localMoves <= 7) && all(solution.localMeasures <= 6));
    add("Probe feedback, cost gate and zero travel "+tag,verifyRouteProbes(solution));
    add("Probe retains measured coverage and absence proof "+tag,verifySearchEvidence(solution,world.log));
    add("Probe has a finite accepted action bound "+tag,solution.serial <= 1206 && solution.routeProbeMeasures <= 952);
    probeRows = find(arrayfun(@(d)d.phase == "route_probe",solution.decisions));
    negativeRows = probeRows(arrayfun(@(i)solution.decisions(i).response.measure_result == "no_signal",probeRows));
    add("Probe fixture actually exercises extra observations "+tag,~isempty(probeRows));
    if sceneIndex ~= 28
        add("Probe no signal preserves the previous conservative track "+tag,~isempty(negativeRows) && ...
            all(arrayfun(@(i)isequaln(solution.decisions(i).trackBefore,solution.decisions(i).trackAfter),negativeRows)));
    end
    bad = solution;
    bad.decisions(probeRows(1)).positionAfter = bad.decisions(probeRows(1)).positionAfter+[1,0];
    add("Reject a probe charged with hidden movement "+tag,~verifyRouteProbes(bad));
    bad = solution;
    bad.decisions(probeRows(1)).plannerEvidence.estimatedNetSaving_s = -1;
    add("Reject a probe without predicted net savings "+tag,~verifyRouteProbes(bad));
    save(fullfile(path,char("probe_"+tag+".mat")),'solution','world','failure','sources');
end
cfg.route = "path_probe";
[exchange,report] = snapshotFaultWorld(sources);
[solution,failure] = solveRoute(exchange,cfg);
fault = report();
add("Probe policy preserves confirmed state after transport failure", ...
    strcmp(failure.identifier,'Q3:SnapshotInjected') && ~solution.complete && ~solution.exited ...
    && sum(solution.status == 2) == fault.confirmedClears && ~solution.lastAction.accepted);
save(fullfile(path,'path_probe_fault.mat'),'solution','failure','fault');
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks,'allPassed',all(checks.Passed));
assert(output.allPassed,'Q3:RouteValidation','Required route checks failed.');
    function add(name,value)
        checks(end+1,:) = {string(name),logical(value)};
    end
end

function valid = verifyRouteProbes(solution)
probes = find(arrayfun(@(d)d.phase == "route_probe",solution.decisions));
valid = numel(probes) == solution.routeProbeMeasures;
for index = probes
    record = solution.decisions(index);
    channel = record.request.channel;
    gate = record.plannerEvidence;
    valid = valid && record.path == "/measure" && record.statusBefore(channel) == 1 ...
        && record.statusAfter(channel) == 1 && record.accepted && record.integrated ...
        && isequal(record.positionBefore,record.positionAfter) && gate.usesOnlyObservedRegion ...
        && isfinite(gate.estimatedNetSaving_s) && gate.estimatedNetSaving_s > 0 ...
        && abs(gate.estimatedNetSaving_s-(gate.estimatedServiceBefore_s ...
            -gate.estimatedServiceAfter_s-gate.probeAndExtraSwitchCost_s)) < 1e-8;
    if record.response.measure_result == "no_signal"
        if isfield(solution,'improvement') && solution.improvement.negativeHistory
            valid = valid && isequal(record.trackBefore.anchor,record.trackAfter.anchor) ...
                && record.trackBefore.angle == record.trackAfter.angle ...
                && record.trackAfter.bound <= record.trackBefore.bound+1e-8 ...
                && ~isempty(record.trackAfter.polygon);
        else
            valid = valid && isequaln(record.trackBefore,record.trackAfter);
        end
    end
end
end

function response = estimatedBearing(position,estimate)
if norm(position-estimate) <= 5
    response = struct('measure_result',"near");
else
    response = struct('measure_result',"direction", ...
        'svd_deg',mod(atan2d(estimate(2)-position(2),estimate(1)-position(1)),360));
end
end

function value = estimatedServiceTime(track,position,receiver,channel,estimate,config)
value = 0;
for k = 1:8
    destination = safeClearPoint(track,position,config);
    if ~isempty(destination)
        value = value+norm(destination-position)/5+5;
        return
    end
    [destination,nextBound] = nextLocalizationPoint(track,position,config);
    value = value+norm(destination-position)/5+5;
    if nextBound <= config.clearMargin
        return
    end
    value = value+double(receiver ~= channel);
    receiver = channel;
    position = destination;
    track.bound = nextBound;
    try
        track = updateTrack(track,estimatedBearing(position,estimate),position,config);
    catch forecastError
        if ismember(string(forecastError.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
            value = Inf;
            return
        end
        rethrow(forecastError)
    end
end
value = Inf;
end

function [bestOrder,bestDistance] = planServiceRoute(position,entry,exitPoint,targetCount,targetsFirst,scanWork,routeBeliefs)
if nargin < 6
    scanWork = zeros(1,0);
end
n = size(entry,1);
assert(n >= 1 && n <= 23 && isequal(size(entry),size(exitPoint)) && size(entry,2) == 2 ...
    && all(isfinite([position;entry;exitPoint]),'all'),'Q3:ServiceRoute','Invalid service route geometry.');
startCost = vecnorm(entry-position,2,2);
edges = hypot(exitPoint(:,1)-entry(:,1)',exitPoint(:,2)-entry(:,2)');
if nargin >= 7 && isfield(routeBeliefs,'edges')
    startCost = routeBeliefs.startCost;
    edges = routeBeliefs.edges;
end
if targetsFirst
    startCost(targetCount+1:end) = Inf;
    edges(targetCount+1:end,1:targetCount) = Inf;
end
greedy = zeros(1,n);
remaining = true(1,n);
cost = startCost';
for k = 1:n
    cost(~remaining) = Inf;
    [~,winner] = min(cost);
    greedy(k) = winner;
    remaining(winner) = false;
    cost = edges(winner,:);
end
bestOrder = greedy;
bestDistance = evaluate(greedy);
for initial = 1:2
    order = greedy;
    if initial == 2
        order = 1:n;
    end
    distance = evaluate(order);
    for pass = 1:30
        nextOrder = order;
        nextDistance = distance;
        for i = 1:n
            for j = 1:n
                if i == j
                    continue
                end
                candidate = order;
                item = candidate(i);
                candidate(i) = [];
                candidate = [candidate(1:j-1),item,candidate(j:end)];
                value = evaluate(candidate);
                if value < nextDistance-1e-8
                    nextOrder = candidate;
                    nextDistance = value;
                end
                if j > i
                    candidate = order;
                    candidate(i:j) = fliplr(candidate(i:j));
                    value = evaluate(candidate);
                    if value < nextDistance-1e-8
                        nextOrder = candidate;
                        nextDistance = value;
                    end
                end
            end
        end
        if nextDistance >= distance-1e-8
            break
        end
        order = nextOrder;
        distance = nextDistance;
    end
    if distance < bestDistance-1e-8
        bestOrder = order;
        bestDistance = distance;
    end
end
bestDistance = bestDistance+sum(vecnorm(entry-exitPoint,2,2));
    function distance = evaluate(order)
        distance = startCost(order(1));
        if n > 1
            distance = distance+sum(edges(sub2ind([n,n],order(1:end-1),order(2:end))));
        end
        if ~isempty(scanWork)
            visitedMask = 0;
            for workNode = order
                if workNode > targetCount
                    workSlot = workNode-targetCount;
                    distance = distance+5*scanWork(visitedMask+1,workSlot);
                    visitedMask = bitset(visitedMask,workSlot);
                end
            end
        end
    end
end

function makeRouteFigures(summary,path)
base = summary(summary.Profile == "v040",:);
candidateProfile = "joint_route";
candidateLabel = 'v0.5.0';
if any(summary.Profile == "path_probe")
    candidateProfile = "path_probe";
    candidateLabel = 'v0.6.0';
end
candidate = summary(summary.Profile == candidateProfile,:);
assert(height(base) == height(candidate) && all(base.Scenario == candidate.Scenario),'Q3:FigurePairing','Figure rows must be paired.');
figureHandle = figure('Visible','off','Color','white','Position',[80,80,1300,540]);
cleanup = onCleanup(@() close(figureHandle));
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
plot(1:height(base),base.VirtualTime_s,'k--','LineWidth',1.2);
hold on;
plot(1:height(candidate),candidate.VirtualTime_s,'b-','LineWidth',1.2);
xlabel('Synthetic scenario');
ylabel('Total virtual time (s)');
title(['Paired v0.4.0 and ',candidateLabel,' route policy']);
legend('v0.4.0',candidateLabel,'Location','best');
grid on;
nexttile;
data = [mean(base.Distance_m)/5,5*mean(base.Measures),mean(base.Switches),5*mean(base.Cleared); ...
    mean(candidate.Distance_m)/5,5*mean(candidate.Measures),mean(candidate.Switches),5*mean(candidate.Cleared)];
bar(data,'stacked');
xticks([1,2]);
xticklabels({'v0.4.0',candidateLabel});
ylabel('Mean virtual time (s)');
title('Every charged action is included');
legend('Movement','Measurement','Channel change','Successful clear','Location','northoutside','NumColumns',2);
grid on;
exportgraphics(figureHandle,fullfile(path,'路线同场对比.png'),'Resolution',160);
savefig(figureHandle,fullfile(path,'路线同场对比.fig'));
[~,worst] = min(candidate.SavingsPercent);
scene = candidate.Scenario(worst);
baselineData = load(fullfile(path,sprintf('现场_%03d_%s_v040.mat',worst,scene)));
candidateData = load(fullfile(path,sprintf('现场_%03d_%s_%s.mat',worst,scene,candidateProfile)));
routeFigure = figure('Visible','off','Color','white','Position',[80,80,1200,560]);
cleanupRoute = onCleanup(@() close(routeFigure));
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
for k = 1:2
    if k == 1
        record = baselineData;
        label = 'v0.4.0';
    else
        record = candidateData;
        label = candidateLabel;
    end
    nexttile;
    theta = linspace(0,2*pi,361);
    plot(1800*cos(theta),1800*sin(theta),'k:');
    hold on;
    plot(record.world.log.X_m,record.world.log.Y_m,'b-','LineWidth',0.9);
    plot(record.solution.points(:,1),record.solution.points(:,2),'ks','MarkerSize',7);
    clearRows = record.world.log.Path == "/clear" & record.world.log.Result == "success";
    plot(record.world.log.X_m(clearRows),record.world.log.Y_m(clearRows),'ro','MarkerSize',5);
    axis equal;
    xlim([-2050,2050]);
    ylim([-2050,2050]);
    grid on;
    xlabel('East (m)');
    ylabel('North (m)');
    title(sprintf('%s | %s | %.1f s',scene,label,record.world.time),'Interpreter','none');
    legend('Source domain','Actual path','Fixed search station','Successful clear','Location','southoutside','NumColumns',2);
end
exportgraphics(routeFigure,fullfile(path,'最差退化路线.png'),'Resolution',160);
savefig(routeFigure,fullfile(path,'最差退化路线.fig'));
end

function policy = improvementPolicy(name)
name = string(name);
assert(isscalar(name) && ismember(name,["v060","mec","nearest","next","negative","combined"]), ...
    'Q3:ImprovementPolicy','Unknown localization study policy.');
policy = struct('name',name,'minimumCircle',name ~= "v060", ...
    'nearestClear',ismember(name,["nearest","next","negative","combined"]), ...
    'nextPoint',ismember(name,["next","combined"]), ...
    'negativeHistory',ismember(name,["negative","combined"]));
end

function [center,radius] = localCircle(polygon,config)
if isfield(config,'improvement') && config.improvement.minimumCircle
    [center,radius] = minimumCircle(polygon);
else
    assert(~isempty(polygon) && all(isfinite(polygon),'all'),'Q3:EmptyRegion','A circle requires a nonempty finite region.');
    [center,radius] = boxCircle(polygon);
end
end

function [center,radius] = minimumCircle(points)
assert(isnumeric(points) && ismatrix(points) && size(points,2) == 2 && ~isempty(points) ...
    && all(isfinite(points),'all'),'Q3:CircleInput','Circle vertices must be a nonempty finite two-column matrix.');
points = unique(points,'rows','stable');
if size(points,1) == 1
    center = points(1,:);
    radius = 0;
    return
end
distance2 = (points(:,1)-points(:,1)').^2+(points(:,2)-points(:,2)').^2;
[~,index] = max(distance2(:));
[i,j] = ind2sub(size(distance2),index);
center = (points(i,:)+points(j,:))/2;
radius = max(vecnorm(points-center,2,2));
if radius <= sqrt(distance2(i,j))/2+1e-9
    radius = radius+1e-8;
    return
end
for i = 1:size(points,1)-2
    for j = i+1:size(points,1)-1
        for k = j+1:size(points,1)
            u = points(j,:)-points(i,:);
            v = points(k,:)-points(i,:);
            crossValue = u(1)*v(2)-u(2)*v(1);
            if abs(crossValue) <= 1e-13*max(1,norm(u)*norm(v))
                continue
            end
            relative = [dot(u,u)*v(2)-dot(v,v)*u(2), ...
                u(1)*dot(v,v)-v(1)*dot(u,u)]/(2*crossValue);
            candidate = points(i,:)+relative;
            candidateRadius = norm(relative);
            if candidateRadius >= radius || ~all(isfinite(candidate))
                continue
            end
            distances = vecnorm(points-candidate,2,2);
            if all(distances <= candidateRadius+1e-8)
                center = candidate;
                radius = max(distances);
            end
        end
    end
end
radius = max(vecnorm(points-center,2,2))+1e-8;
end

function [destination,radius] = safeClearPoint(track,position,config)
destination = [];
radius = Inf;
nearest = isfield(config,'improvement') && config.improvement.nearestClear;
if track.near || track.bound <= config.clearMargin
    destination = track.anchor;
    if nearest
        destination = projectDisk(position,track.anchor,max(0,config.clearMargin-track.bound-1e-7));
    end
    radius = norm(destination-track.anchor)+track.bound;
elseif config.variant == "seven_geometry"
    [center,bound] = localCircle(track.polygon,config);
    if bound <= config.clearMargin
        destination = center;
        if nearest
            destination = closestCoverPoint(track.polygon,position,config.clearMargin-1e-7,center);
        end
        radius = max(vecnorm(track.polygon-destination,2,2));
    end
end
assert(isempty(destination) || (all(isfinite(destination)) && radius <= config.clearMargin+1e-8), ...
    'Q3:ClearCertificate','The entire conservative region must be covered by the clear point.');
end

function point = projectDisk(position,center,radius)
distance = norm(position-center);
point = position;
if distance > radius
    point = center+radius*(position-center)/distance;
end
end

function [point,certificate] = closestCoverPoint(vertices,position,radius,fallback)
assert(~isempty(vertices) && size(vertices,2) == 2 && all(isfinite(vertices),'all') ...
    && all(isfinite(position)) && isscalar(radius) && isfinite(radius) && radius > 0 ...
    && all(isfinite(fallback)),'Q3:ProjectionInput','Invalid cover projection input.');
if all(vecnorm(vertices-position,2,2) <= radius)
    point = position;
    certificate = struct('activeCount',0,'distance',0);
    return
end
point = fallback;
best = norm(point-position);
assert(all(vecnorm(vertices-point,2,2) <= radius+1e-8),'Q3:ProjectionInfeasible','The fallback does not cover the region.');
activeCount = -1;
for i = 1:size(vertices,1)
    candidate = projectDisk(position,vertices(i,:),radius);
    accept(candidate,1);
    for j = i+1:size(vertices,1)
        vector = vertices(j,:)-vertices(i,:);
        distance = norm(vector);
        if distance <= 1e-12 || distance > 2*radius
            continue
        end
        middle = (vertices(i,:)+vertices(j,:))/2;
        normal = [-vector(2),vector(1)]/distance;
        height = sqrt(max(0,radius^2-distance^2/4));
        accept(middle+height*normal,2);
        accept(middle-height*normal,2);
    end
end
certificate = struct('activeCount',activeCount,'distance',best);

    function accept(candidate,count)
        travel = norm(candidate-position);
        if travel < best+1e-10 && all(vecnorm(vertices-candidate,2,2) <= radius+1e-9)
            point = candidate;
            best = travel;
            activeCount = count;
        end
    end
end

function output = validateImprovement(root,settings)
path = fullfile(root,'运行结果',char("validate_improvement_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Validation directory already exists.');
mkdir(path);
names = strings(0,1);
values = false(0,1);
triangle = [0,0;38,0;19,19*sqrt(3)];
[center,radius] = minimumCircle(triangle);
add("38 m equilateral triangle requires radius greater than 20",abs(radius-38/sqrt(3)) < 1e-6 && radius > 20);
add("Equilateral circumcenter is correct",norm(center-[19,19/sqrt(3)]) < 1e-8);
[center,radius] = minimumCircle([0,0;4,0;1,0;4,0]);
add("Repeated collinear vertices",norm(center-[2,0]) < 1e-9 && abs(radius-2) < 1e-7);
[center,radius] = minimumCircle([2,3]);
add("Single point",isequal(center,[2,3]) && radius == 0);
for bad = {zeros(0,2),[NaN,0],[Inf,2],ones(2,3)}
    rejected = false;
    try
        minimumCircle(bad{1});
    catch e
        rejected = strcmp(e.identifier,'Q3:CircleInput');
    end
    add("Illegal circle input "+numel(names),rejected);
end
oldRng = rng;
cleanup = onCleanup(@()rng(oldRng));
rng(2026091140,'twister');
for trial = 1:40
    points = randn(8,2).*[10^(mod(trial,4)),1]+[1500,-900];
    if mod(trial,5) == 0
        points(:,2) = -900+1e-10*(1:8)';
    end
    [c,r] = minimumCircle(points);
    [~,reference] = independentCircle(points);
    add("Circle independent support enumeration "+trial,abs(r-reference) < 1e-5 ...
        && all(vecnorm(points-c,2,2) <= r));
end
vertices = [-10,0;10,0;0,6];
[c,~] = minimumCircle(vertices);
[point,proof] = closestCoverPoint(vertices,[100,30],19.5,c);
angles = (0:7200)'*360/7201;
reference = Inf;
for i = 1:size(vertices,1)
    candidates = vertices(i,:)+19.5*[cosd(angles),sind(angles)];
    valid = true(size(angles));
    for j = 1:size(vertices,1)
        valid = valid & vecnorm(candidates-vertices(j,:),2,2) <= 19.5+1e-8;
    end
    reference = min(reference,min(vecnorm(candidates(valid,:)-[100,30],2,2)));
end
add("Nearest safe clear covers every vertex",all(vecnorm(vertices-point,2,2) <= 19.5+1e-8));
add("Nearest safe clear beats independent dense boundary search",proof.distance <= reference+1e-8 && reference-proof.distance < 0.03);
add("Nearest safe clear reduces travel",norm(point-[100,30]) < norm(c-[100,30]));
[point,~] = closestCoverPoint(vertices,[0,0],19.5,c);
add("Already safe position needs zero movement",isequal(point,[0,0]));
checks = table(names,values,'VariableNames',{'Check','Passed'});
checks = [checks;validateAdvancedGeometry(settings)];
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks,'allPassed',all(checks.Passed));
assert(output.allPassed,'Q3:ImprovementValidation','A localization validation failed.');

    function add(name,value)
        names(end+1,1) = name;
        values(end+1,1) = value;
    end
end

function [center,radius] = independentCircle(points)
count = size(points,1);
centers = zeros(count+count*(count-1)/2+count*(count-1)*(count-2)/6,2);
centers(1:count,:) = points;
for i = 1:size(points,1)-1
    for j = i+1:size(points,1)
        count = count+1;
        centers(count,:) = (points(i,:)+points(j,:))/2;
        for k = j+1:size(points,1)
            offsets = points([j,k],:)-points(i,:);
            if rcond(offsets) < 1e-13
                continue
            end
            count = count+1;
            centers(count,:) = points(i,:)+(2*offsets\sum(offsets.^2,2))';
        end
    end
end
centers = centers(1:count,:);
radii = zeros(size(centers,1),1);
for i = 1:size(centers,1)
    radii(i) = max(vecnorm(points-centers(i,:),2,2));
end
[radius,index] = min(radii);
center = centers(index,:);
end

function output = runImprovementStudy(root,settings,config)
assert(isstruct(config) && isscalar(config) && all(isfield(config,{'partition','profiles'})), ...
    'Q3:RouteStudy','A partition and explicit profiles are required.');
profiles = reshape(string(config.profiles),1,[]);
assert(numel(unique(profiles)) == numel(profiles) && ismember("v060",profiles), ...
    'Q3:RouteStudy','A paired v0.6.0 release baseline is required.');
scenarios = routeScenarios(config.partition);
path = fullfile(root,'运行结果',char("improvement_study_"+string(config.partition)+"_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Study output already exists.');
mkdir(path);
save(fullfile(path,'研究配置.mat'),'settings','config','scenarios');
records = cell(numel(scenarios)*numel(profiles),1);
for i = 1:numel(scenarios)
    scene = scenarios(i);
    writetable(array2table(scene.sources,'VariableNames',{'Channel','X_m','Y_m','Radius_m','ErrorMode'}), ...
        fullfile(path,sprintf('场景_%03d_%s.csv',i,scene.name)),'Encoding','UTF-8');
    for j = 1:numel(profiles)
        routeConfig = settings;
        routeConfig.variant = "seven_geometry";
        routeConfig.search = searchPolicy("release");
        routeConfig.route = "path_probe";
        if profiles(j) == "release"
            routeConfig = group2Settings(routeConfig);
        else
            routeConfig.improvement = improvementPolicy(profiles(j));
        end
        [exchange,report] = makeWorld(scene.sources);
        timer = tic;
        [solution,failure] = solveRoute(exchange,routeConfig);
        elapsed = toc(timer);
        world = report();
        [boundValid,polygonValid] = checkHistory(solution.history,scene.sources);
        evidence = verifySearchEvidence(solution,world.log);
        decisionValid = verifyRouteDecisions(solution,world.log) && verifyRouteProbes(solution);
        fullClear = all(world.cleared) && solution.complete && isempty(failure.identifier);
        clearRows = find(world.log.Path == "/clear" & world.log.Result == "success");
        firstClear = NaN;
        tail = NaN;
        if ~isempty(clearRows)
            firstClear = world.log.VirtualTime_s(clearRows(1));
            tail = world.time-world.log.VirtualTime_s(clearRows(end));
        end
        residual = abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time);
        valid = fullClear && evidence && decisionValid && boundValid && polygonValid ...
            && residual < 1e-7 && solution.costs(4) == 0 && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6);
        records{(i-1)*numel(profiles)+j} = struct('Partition',string(config.partition), ...
            'Scenario',string(scene.name),'Profile',profiles(j),'SourceCount',size(scene.sources,1), ...
            'Cleared',sum(world.cleared),'FullClear',fullClear,'EvidenceValid',evidence, ...
            'DecisionValid',decisionValid,'HistoryValid',boundValid && polygonValid,'ChecksPassed',valid, ...
            'VirtualTime_s',world.time,'MeanClearTime_s',world.time/max(1,sum(world.cleared)), ...
            'FirstClear_s',firstClear,'AfterLastClear_s',tail,'Distance_m',solution.costs(1), ...
            'Switches',solution.costs(2),'Measures',solution.costs(3)/5,'SearchMeasures',solution.searchMeasures, ...
            'ResumeMeasures',solution.opportunisticMeasures,'FailedClears',solution.costs(4)/3, ...
            'RouteProbeMeasures',solution.routeProbeMeasures,'ForecastRejections',solution.forecastRejections, ...
            'Actions',height(world.log),'WallTime_s',elapsed,'TimeResidual_s',residual, ...
            'FailureIdentifier',string(failure.identifier),'FailureMessage',string(failure.message));
        stem = sprintf('%03d_%s_%s',i,scene.name,profiles(j));
        save(fullfile(path,['现场_',stem,'.mat']),'solution','world','routeConfig','failure');
        writetable(world.log,fullfile(path,['动作_',stem,'.csv']),'Encoding','UTF-8');
        certificate = clearCertificate(solution,struct('clearedChannels',scene.sources(world.cleared,1),'log',world.log));
        writetable(certificate,fullfile(path,['清除证书_',stem,'.csv']),'Encoding','UTF-8');
        writetable(routeDecisionTable(solution),fullfile(path,['决策_',stem,'.csv']),'Encoding','UTF-8');
        fprintf('%s | %s | %d/%d | %.3f s | checks=%d | %s\n',scene.name,profiles(j), ...
            sum(world.cleared),size(scene.sources,1),world.time,valid,failure.identifier);
    end
end
summary = struct2table(vertcat(records{:}));
summary.BaselineTime_s = zeros(height(summary),1);
summary.Savings_s = zeros(height(summary),1);
summary.SavingsPercent = zeros(height(summary),1);
for i = 1:numel(scenarios)
    rows = summary.Scenario == string(scenarios(i).name);
    base = summary.VirtualTime_s(rows & summary.Profile == "v060");
    summary.BaselineTime_s(rows) = base;
    paired = rows & summary.ChecksPassed;
    baselineValid = summary.ChecksPassed(rows & summary.Profile == "v060");
    summary.Savings_s(rows) = NaN;
    summary.SavingsPercent(rows) = NaN;
    if baselineValid
        summary.Savings_s(paired) = base-summary.VirtualTime_s(paired);
        summary.SavingsPercent(paired) = 100*summary.Savings_s(paired)/base;
    end
end
writetable(summary,fullfile(path,'提升配对结果.csv'),'Encoding','UTF-8');
save(fullfile(path,'研究结果.mat'),'summary','config','settings');
if isfield(config,'makeFigures') && isequal(config.makeFigures,true)
    makeRouteFigures(summary,path);
end
output = struct('path',path,'allPassed',all(summary.ChecksPassed),'summary',summary);
end


function [destination,nextBound,evidence] = boundedLocalizationPoint(track,position,config)
step = track.bound/(2*cosd(config.angleMargin));
destination = track.anchor+step*[cosd(track.angle),sind(track.angle)];
nextBound = step+1e-7;
evidence = struct('method',"bearing_contraction",'bound',nextBound,'referenceBound',nextBound, ...
    'candidateCount',1,'predictedCost_s',NaN,'wholePolygonBound',false);
if ~isfield(config,'improvement') || ~config.improvement.nextPoint || isempty(track.polygon) ...
        || nextBound <= config.clearMargin
    return
end
[center,radius] = minimumCircle(track.polygon);
if radius > step-1e-6
    return
end
nearest = closestCoverPoint(track.polygon,position,step-1e-6,center);
axis = [cosd(track.angle),sind(track.angle)];
normal = [-axis(2),axis(1)];
slack = max(0,step-radius-1e-6);
candidates = [destination;center;nearest;center+0.5*slack*normal;center-0.5*slack*normal];
if isfield(config,'regionForecast') && config.regionForecast
    candidates = [destination;center;nearest;center+[-1;-0.75;-0.25;0.25;0.75;1]*slack*normal];
end
estimate = mean(track.polygon,1);
forecastConfig = config;
forecastConfig.improvement.nextPoint = false;
best = Inf;
for i = 1:size(candidates,1)
    at = candidates(i,:);
    bound = max(vecnorm(track.polygon-at,2,2))+1e-7;
    if i == 1
        bound = step+1e-7;
    elseif bound > step+1e-7 || bound >= 1000-1e-6
        continue
    end
    if bound <= config.clearMargin
        score = norm(at-position)/5+5;
    else
        forecast = track;
        forecast.bound = bound;
        try
            forecast = updateTrack(forecast,estimatedBearing(at,estimate),at,forecastConfig);
            if isfield(config,'regionForecast') && config.regionForecast
                score = norm(at-position)/5+5+regionServiceScore(track,forecast,at,bound,estimate,forecastConfig);
            else
            score = norm(at-position)/5+5+estimatedServiceTime(forecast,at,1,1,estimate,forecastConfig);
            end
        catch forecastError
            if strcmp(forecastError.identifier,'Q3:EmptyRegion') || strcmp(forecastError.identifier,'Q3:NegativeRegion')
                continue
            end
            rethrow(forecastError)
        end
    end
    if score < best-1e-8
        best = score;
        destination = at;
        nextBound = bound;
        evidence = struct('method',"bounded_region_candidate",'bound',bound,'referenceBound',step+1e-7, ...
            'candidateCount',size(candidates,1),'predictedCost_s',score,'wholePolygonBound',i ~= 1);
    end
end
assert(nextBound <= step+2e-7 && nextBound < 1000,'Q3:ContractionCertificate','Candidate violates finite contraction or reception bound.');
end

function track = applyNegativeHistory(track,centers,config)
if ~isfield(config,'improvement') || ~config.improvement.negativeHistory || track.near
    return
end
track.negativeCenters = centers;
polygon = track.polygon;
assert(~isempty(polygon),'Q3:NegativeRegion','Negative constraints require a nonempty positive-observation region.');
normals = [cosd((0:71)'*5),sind((0:71)'*5)];
apothem = (1000-1e-6)*cosd(2.5);
for j = 1:size(centers,1)
    center = centers(j,:);
    if all(vecnorm(polygon-center,2,2) >= 1000)
        continue
    end
    buffer = zeros(144*size(polygon,1),2);
    count = 0;
    for i = 1:72
        normal = normals(i,:);
        if max((polygon-center)*normal') < apothem-1e-8
            continue
        end
        piece = clipPlane(polygon,-normal,-dot(normal,center)-apothem);
        amount = size(piece,1);
        buffer(count+(1:amount),:) = piece;
        count = count+amount;
    end
    assert(count > 0,'Q3:NegativeRegion','Actual positive and negative observations have an empty conservative region.');
    vertices = unique(buffer(1:count,:),'rows');
    if size(vertices,1) >= 3 && rank(vertices-vertices(1,:),1e-10) == 2
        indices = convhull(vertices(:,1),vertices(:,2));
        polygon = vertices(indices(1:end-1),:);
    else
        polygon = vertices;
    end
end
if isfield(config,'rangeDominance') && config.rangeDominance && isfield(track,'positiveCenters')
    polygon = rangeDominancePolygon(polygon,track.positiveCenters,centers);
end
track.polygon = polygon;
track.bound = min(track.bound,max(vecnorm(polygon-track.anchor,2,2))+1e-7);
end

function checks = validateAdvancedGeometry(settings)
names = strings(0,1);
values = false(0,1);
config = settings;
config.variant = "seven_geometry";
config.improvement = improvementPolicy("combined");
base = struct('anchor',[0,0],'angle',0,'bound',1500,'polygon',[],'near',false);
base = updateTrack(base,struct('measure_result',"direction",'svd_deg',0),[0,0],config);
negative = applyNegativeHistory(base,[0,0]+[-200,0],config);
add("Negative history tightens a front-clipped wedge",min(negative.polygon(:,1)) > min(base.polygon(:,1))+100);
[xx,yy] = meshgrid(linspace(0,1500,201),linspace(-30,30,81));
points = [xx(:),yy(:)];
inside = inpolygon(points(:,1),points(:,2),base.polygon(:,1),base.polygon(:,2));
legal = inside & vecnorm(points-[-200,0],2,2) >= 1000;
retained = inpolygon(points(legal,1),points(legal,2),negative.polygon(:,1),negative.polygon(:,2));
add("Every sampled compatible location survives negative clipping",all(retained) && nnz(legal) > 100);
unchanged = applyNegativeHistory(base,[-2000,0],config);
add("Irrelevant negative disk preserves the region",isequal(unchanged.polygon,base.polygon));
contradiction = false;
try
    small = base;
    small.polygon = [1,-1;2,-1;2,1;1,1];
    applyNegativeHistory(small,[0,0],config);
catch e
    contradiction = strcmp(e.identifier,'Q3:NegativeRegion');
end
add("Contradictory negative history fails closed",contradiction);
for angle = [0,59.99,179.99,359.99]
    track = struct('anchor',[0,0],'angle',angle,'bound',1500,'polygon',[],'near',false);
    track = updateTrack(track,struct('measure_result',"direction",'svd_deg',angle),[0,0],config);
    [point,bound,proof] = nextLocalizationPoint(track,[100,-80],config);
    distance = linspace(5.001,1500,1501)';
    bearings = angle+[-1.005,-1,0,1,1.005];
    compatibleX = distance.*cosd(bearings);
    compatibleY = distance.*sind(bearings);
    remaining = hypot(compatibleX-point(1),compatibleY-point(2));
    add("Next point covers continuous-wedge samples "+angle,max(remaining,[],'all') <= bound+1e-6);
    add("Next point preserves original shrink and reception "+angle,bound <= proof.referenceBound+1e-8 && bound < 1000);
end
forecastConfig = config;
forecastConfig.improvement.nextPoint = false;
forecastTrack = base;
forecastTrack.polygon = clipPlane(base.polygon,[-1,0],-900);
add("Incompatible predicted target returns infinite cost without changing real track", ...
    isinf(estimatedServiceTime(forecastTrack,[0,0],1,1,[-1000,0],forecastConfig)));
checks = table(names,values,'VariableNames',{'Check','Passed'});

    function add(name,value)
        names(end+1,1) = name;
        values(end+1,1) = value;
    end
end

function settings = group2Settings(settings)
settings.variant = "seven_geometry";
settings.search = searchPolicy("release");
settings.route = "path_probe";
settings.improvement = improvementPolicy("combined");
end

function output = validateGroup2(root,settings)
path = fullfile(root,'运行结果',char("validate_group2_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Group-two validation output exists.');
mkdir(path);
checks = table(strings(0,1),false(0,1),'VariableNames',{'Check','Passed'});
config = group2Settings(settings);
add("Group two preserves released search layout and scan settings", ...
    isequal(config.search,searchPolicy("release")) && config.search.radius == 1500 ...
    && config.search.rotation == 30 && ~config.search.alternateChannels && config.search.reuseMode == "none");
add("Group two preserves angle and clear margins",config.angleMargin == 1.01 && config.clearMargin == 19.5 && config.diskSides == 72);
scenarios = routeScenarios("development");
for index = [11,13,28]
    sources = scenarios(index).sources;
    [exchange,report] = makeWorld(sources);
    [solution,failure] = solveRoute(exchange,config);
    world = report();
    [boundValid,polygonValid] = checkHistory(solution.history,sources);
    tag = string(scenarios(index).name);
    add("Group two complete with legal confirmed state "+tag,all(world.cleared) && solution.complete && isempty(failure.identifier));
    add("Group two conservative bound and polygon history "+tag,boundValid && polygonValid);
    add("Group two actual coverage and sequential feedback "+tag,verifySearchEvidence(solution,world.log) ...
        && verifyRouteDecisions(solution,world.log) && verifyRouteProbes(solution));
    add("Group two finite local and global action bounds "+tag,solution.serial <= 1206 ...
        && solution.routeProbeMeasures <= 952 && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6));
    certificate = clearCertificate(solution,struct('clearedChannels',sources(world.cleared,1),'log',world.log));
    add("Every clear has a conservative whole-set certificate "+tag, ...
        all(isfinite(certificate.GeometricUpperBound_m)) && all(certificate.GeometricUpperBound_m <= 19.5+1e-6));
    add("No failed clear and independent aggregate cost "+tag,solution.costs(4) == 0 ...
        && abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time) < 1e-7);
    writetable(certificate,fullfile(path,char("clear_"+tag+".csv")),'Encoding','UTF-8');
    save(fullfile(path,char("scene_"+tag+".mat")),'config','sources','solution','world','failure');
end
sources = [(1:9)',zeros(9,2),1000*ones(9,1),zeros(9,1);20,-1800,0,1000,0];
[exchange,report] = snapshotFaultWorld(sources);
config.snapshotFcn = @(snapshot)saveSnapshot(fullfile(path,'injected_fault_checkpoint.mat'),snapshot);
[solution,failure] = solveRoute(exchange,config);
state = report();
add("Confirmed clears survive a transport failure",strcmp(failure.identifier,'Q3:SnapshotInjected') ...
    && sum(solution.status == 2) == state.confirmedClears && state.confirmedClears >= 1);
add("Unanswered action cannot fabricate completion",~solution.complete && ~solution.exited ...
    && ~solution.lastAction.accepted && ~solution.decisions(end).accepted);
add("Failure saves a recoverable actual scene",isfile(fullfile(path,'injected_fault_checkpoint.mat')) && isempty(solution.callbackErrors));
saved = load(fullfile(path,'injected_fault_checkpoint.mat'));
add("Saved snapshot agrees with confirmed failure state",isequal(saved.snapshot.status,solution.status) ...
    && saved.snapshot.serial == solution.serial && ~saved.snapshot.complete);
save(fullfile(path,'injected_fault.mat'),'solution','failure','state');
bad = struct('anchor',[0,0],'angle',0,'bound',1500,'near',false, ...
    'polygon',[1000,-5;1100,-5;1100,5;1000,5]);
closed = false;
try
    updateTrack(bad,struct('measure_result',"direction",'svd_deg',180),[0,0],config);
catch errorInfo
    closed = strcmp(errorInfo.identifier,'Q3:EmptyRegion');
end
add("Contradictory actual bearing still fails closed",closed);
vertices = [-10,0;10,0;0,6];
[center,~] = minimumCircle(vertices);
for receiverPosition = [100,30;-100,40;0,-100;0,0]'
    position = receiverPosition';
    [point,proof] = closestCoverPoint(vertices,position,19.5,center);
    add("Safe projection covers every point of the polygon "+height(checks), ...
        all(vecnorm(vertices-point,2,2) <= 19.5+1e-8) && proof.activeCount >= 0);
end
track = struct('anchor',[0,0],'angle',0,'bound',1500,'near',false, ...
    'polygon',[100,1;1100,1;1100,10;100,10]);
[point,bound,proof] = nextLocalizationPoint(track,[0,0],config);
add("Optimized next point retains original contraction bound",bound <= proof.referenceBound+1e-8);
add("Next point certificate covers all vertices when polygon based",~proof.wholePolygonBound ...
    || all(vecnorm(track.polygon-point,2,2) <= bound));
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks,'allPassed',all(checks.Passed));
assert(output.allPassed,'Q3:Group2Validation','Group-two validation failed.');

    function add(name,value)
        checks(end+1,:) = {string(name),logical(value)};
    end
end

function output = runCoverageStudy(root,settings,config)
assert(isstruct(config) && isscalar(config) && all(isfield(config,{'partition','profiles'})), ...
    'Q3:RouteStudy','A partition and explicit profiles are required.');
profiles = reshape(string(config.profiles),1,[]);
assert(numel(unique(profiles)) == numel(profiles) && ismember("v070",profiles), ...
    'Q3:RouteStudy','A paired v0.7.0 release baseline is required.');
scenarios = routeScenarios(config.partition);
path = fullfile(root,'运行结果',char("coverage_study_"+string(config.partition)+"_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Study output already exists.');
mkdir(path);
save(fullfile(path,'研究配置.mat'),'settings','config','scenarios');
records = cell(numel(scenarios)*numel(profiles),1);
for i = 1:numel(scenarios)
    scene = scenarios(i);
    writetable(array2table(scene.sources,'VariableNames',{'Channel','X_m','Y_m','Radius_m','ErrorMode'}), ...
        fullfile(path,sprintf('场景_%03d_%s.csv',i,scene.name)),'Encoding','UTF-8');
    for j = 1:numel(profiles)
        routeConfig = coverageSettings(settings,profiles(j));
        [exchange,report] = makeWorld(scene.sources);
        timer = tic;
        [solution,failure] = solveRoute(exchange,routeConfig);
        elapsed = toc(timer);
        world = report();
        [boundValid,polygonValid] = checkHistory(solution.history,scene.sources);
        evidence = verifySearchEvidence(solution,world.log);
        decisionValid = verifyRouteDecisions(solution,world.log) && verifyRouteProbes(solution) && verifyCoverageDecisions(solution,world.log) && independentAbsenceCover(solution,world.log) && verifyLayoutDecision(solution,world.log);
        fullClear = all(world.cleared) && solution.complete && isempty(failure.identifier);
        clearRows = find(world.log.Path == "/clear" & world.log.Result == "success");
        firstClear = NaN;
        tail = NaN;
        if ~isempty(clearRows)
            firstClear = world.log.VirtualTime_s(clearRows(1));
            tail = world.time-world.log.VirtualTime_s(clearRows(end));
        end
        residual = abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time);
        valid = fullClear && evidence && decisionValid && boundValid && polygonValid ...
            && residual < 1e-7 && solution.costs(4) == 0 && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6) && solution.serial <= 1226 && solution.searchMeasures <= 160;
        records{(i-1)*numel(profiles)+j} = struct('Partition',string(config.partition), ...
            'Scenario',string(scene.name),'Profile',profiles(j),'SourceCount',size(scene.sources,1), ...
            'Cleared',sum(world.cleared),'FullClear',fullClear,'EvidenceValid',evidence, ...
            'DecisionValid',decisionValid,'HistoryValid',boundValid && polygonValid,'ChecksPassed',valid, ...
            'VirtualTime_s',world.time,'MeanClearTime_s',world.time/max(1,sum(world.cleared)), ...
            'FirstClear_s',firstClear,'AfterLastClear_s',tail,'Distance_m',solution.costs(1), ...
            'Switches',solution.costs(2),'Measures',solution.costs(3)/5,'SearchMeasures',solution.searchMeasures, ...
            'LayoutFallback',solution.layoutDecision.applied,'ActualRadius_m',solution.search.radius,'ActualRotation_deg',solution.search.rotation, ...
            'ResumeMeasures',solution.opportunisticMeasures,'RetiredStations',sum(solution.retiredCoverage,'all'),'FailedClears',solution.costs(4)/3, ...
            'RouteProbeMeasures',solution.routeProbeMeasures,'ForecastRejections',solution.forecastRejections, ...
            'Actions',height(world.log),'WallTime_s',elapsed,'TimeResidual_s',residual, ...
            'FailureIdentifier',string(failure.identifier),'FailureMessage',string(failure.message));
        stem = sprintf('%03d_%s_%s',i,scene.name,profiles(j));
        save(fullfile(path,['现场_',stem,'.mat']),'solution','world','routeConfig','failure');
        writetable(world.log,fullfile(path,['动作_',stem,'.csv']),'Encoding','UTF-8');
        certificate = clearCertificate(solution,struct('clearedChannels',scene.sources(world.cleared,1),'log',world.log));
        writetable(certificate,fullfile(path,['清除证书_',stem,'.csv']),'Encoding','UTF-8');
        writetable(routeDecisionTable(solution),fullfile(path,['决策_',stem,'.csv']),'Encoding','UTF-8');
        fprintf('%s | %s | %d/%d | %.3f s | checks=%d | %s\n',scene.name,profiles(j), ...
            sum(world.cleared),size(scene.sources,1),world.time,valid,failure.identifier);
    end
end
summary = struct2table(vertcat(records{:}));
summary.BaselineTime_s = zeros(height(summary),1);
summary.Savings_s = zeros(height(summary),1);
summary.SavingsPercent = zeros(height(summary),1);
for i = 1:numel(scenarios)
    rows = summary.Scenario == string(scenarios(i).name);
    base = summary.VirtualTime_s(rows & summary.Profile == "v070");
    summary.BaselineTime_s(rows) = base;
    paired = rows & summary.ChecksPassed;
    baselineValid = summary.ChecksPassed(rows & summary.Profile == "v070");
    summary.Savings_s(rows) = NaN;
    summary.SavingsPercent(rows) = NaN;
    if baselineValid
        summary.Savings_s(paired) = base-summary.VirtualTime_s(paired);
        summary.SavingsPercent(paired) = 100*summary.Savings_s(paired)/base;
    end
end
writetable(summary,fullfile(path,'覆盖配对结果.csv'),'Encoding','UTF-8');
save(fullfile(path,'研究结果.mat'),'summary','config','settings');
if isfield(config,'makeFigures') && isequal(config.makeFigures,true)
    makeRouteFigures(summary,path);
end
output = struct('path',path,'allPassed',all(summary.ChecksPassed),'summary',summary);
end


function tuning = coverageTuning(name)
tuning = struct('reuse',"none",'duringLocalization',false,'finishStation',false,'scanMode',"legacy");
name = string(name);
if contains(name,"finishreuse")
    tuning.reuse = "finish";
elseif contains(name,"replace")
    tuning.reuse = "replace";
end
tuning.duringLocalization = contains(name,"path");
tuning.finishStation = contains(name,"batch");
if contains(name,"alternate")
    tuning.scanMode = "alternate";
elseif contains(name,"endpoints")
    tuning.scanMode = "endpoints";
end
end

function tuning = validateCoverageTuning(tuning)
names = {'reuse','duringLocalization','finishStation','scanMode'};
assert(isstruct(tuning) && isscalar(tuning) && isequal(sort(fieldnames(tuning)),sort(names(:))), ...
    'Q3:CoverageConfig','Coverage tuning requires exactly the published fields.');
assert(islogical(tuning.duringLocalization) && isscalar(tuning.duringLocalization) ...
    && islogical(tuning.finishStation) && isscalar(tuning.finishStation),'Q3:CoverageConfig','Coverage flags must be logical.');
tuning.reuse = string(tuning.reuse);
tuning.scanMode = string(tuning.scanMode);
assert(isscalar(tuning.reuse) && ismember(tuning.reuse,["none","finish","replace"]) ...
    && isscalar(tuning.scanMode) && ismember(tuning.scanMode,["legacy","alternate","endpoints"]), ...
    'Q3:CoverageConfig','Unknown coverage or scan mode.');
end

function config = coverageSettings(settings,name)
name = string(name);
useRegionForecast = name == "release";
if useRegionForecast
    name = "r1200_rot0_originouter";
end
allowed = ["v070","r1200","r1300","r1400","r1200_rot0","r1300_rot0","r1400_rot0","r1500_rot0", ...
    "r1200_rot0_batch_endpoints","r1200_batch", ...
    "r1200_alternate","r1200_endpoints","r1200_finishreuse_path", ...
    "r1200_replace","r1200_replace_path","r1200_replace_path_endpoints", ...
    "r1300_replace_path_endpoints","r1400_replace_path_endpoints","r1500_replace_path_endpoints", ...
    "r1200_replace_path_batch_endpoints","r1200_rot0_originbaseline", ...
    "r1200_rot0_originouter","r1200_rot0_originmiddle"];
assert(isscalar(name) && ismember(name,allowed),'Q3:CoverageProfile','Unknown coverage study profile.');
config = group2Settings(settings);
config.regionForecast = useRegionForecast;
if name ~= "v070"
    config.search.radius = str2double(extractBetween(name,2,5));
end
if contains(name,"rot0")
    config.search.rotation = 0;
end
config.emptyOriginLayout = "none";
for policy = ["baseline","outer","middle"]
    if contains(name,"origin"+policy)
        config.emptyOriginLayout = policy;
    end
end
config.coverageTuning = validateCoverageTuning(coverageTuning(name));
config.search = validateSearchPolicy(config.search);
end

function ordered = coverageScanOrder(channels,receiver,nextChannels,mode)
ordered = scanOrder(channels,receiver,mode == "alternate");
if mode ~= "endpoints" || numel(ordered) < 2
    return
end
available = ordered(ordered ~= receiver & ismember(ordered,nextChannels));
if ~isempty(available)
    last = available(end);
    ordered = [ordered(ordered ~= last),last];
end
end

function [station,proof,future] = coverageReplacement(previous,position,points,required,mode)
station = -1;
proof = struct;
future = zeros(1,0);
if isempty(required) || size(previous,1)+numel(required) < 6
    return
end
if mode == "finish"
    if size(previous,1) < 5
        return
    end
    [covered,proof] = certifyNoSignalDiskCover([previous;position]);
    if covered
        station = 0;
    end
    return
end
[~,order] = sort(vecnorm(points(required,:)-position,2,2));
for index = order'
    candidate = required(index);
    planned = required(required ~= candidate);
    [covered,certificate] = certifyNoSignalDiskCover([previous;position;points(planned,:)]);
    if covered
        station = candidate;
        proof = certificate;
        future = planned;
        return
    end
end
end

function valid = verifyCoverageDecisions(solution,log)
retired = false(size(solution.coverage));
actual = false(size(solution.coverage));
negative = repmat({zeros(0,2)},1,20);
for k = 1:height(log)
    d = solution.decisions(k);
    if d.path == "/measure"
        channel = d.request.channel;
        position = [d.request.position.x,d.request.position.y];
        if d.phase == "opportunistic_search" && isfield(d.plannerEvidence,'kind') ...
                && d.plannerEvidence.kind == "actual_stop_coverage_reuse"
            e = d.plannerEvidence;
            expected = [negative{channel};position;solution.points(e.futureStations,:)];
            required = find(~actual(:,channel) & ~retired(:,channel))';
            if e.retireStation > 0
                expectedFuture = required(required ~= e.retireStation);
                if ~ismember(e.retireStation,required) || ~isequal(e.futureStations,expectedFuture)
                    valid = false;
                    return
                end
            elseif ~isempty(e.futureStations)
                valid = false;
                return
            end
            if d.statusBefore(channel) ~= 0 || norm(position-d.positionBefore) > 1e-8 ...
                    || ~isequal(e.negativeBefore,negative{channel}) || ~isequal(e.prospectiveCover.centers,expected) ...
                    || ~verifySquareCover(e.prospectiveCover)
                valid = false;
                return
            end
            if d.response.measure_result == "no_signal" && e.retireStation > 0
                if retired(e.retireStation,channel)
                    valid = false;
                    return
                end
                retired(e.retireStation,channel) = true;
            end
        end
        if d.response.measure_result == "no_signal"
            negative{channel}(end+1,:) = position;
        end
        actual(vecnorm(solution.points-position,2,2) <= 1e-8,channel) = true;
    end
    if ~isequal(d.retiredCoverageAfter,retired)
        valid = false;
        return
    end
end
valid = isequal(solution.retiredCoverage,retired);
end

function output = validateGroup3(root,settings)
path = fullfile(root,'运行结果',char("validate_group3_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','Validation output exists.');
mkdir(path);
checks = table(strings(0,1),false(0,1),'VariableNames',{'Check','Passed'});
released = coverageSettings(settings,"release");
add("Selected release changes only feedback-based station geometry",released.search.radius == 1200 && released.search.rotation == 0 ...
    && released.emptyOriginLayout == "outer" ...
    && isequal(released.coverageTuning,coverageTuning("v070")) && isequal(released.improvement,improvementPolicy("combined")) ...
    && released.angleMargin == 1.01 && released.clearMargin == 19.5 && released.diskSides == 72);
for radius = [1200,1300,1400,1500]
    angle = (0:5)'*60+30;
    points = [0,0;radius*cosd(angle),radius*sind(angle)];
    bound = max(radius/sqrt(3),sqrt(1800^2+radius^2-3600*radius*cosd(30)));
    [covered,proof] = certifyNoSignalDiskCover(points);
    [independent,maximum] = independentDiskCover(points);
    add("Analytic and independent continuous cover radius "+radius,bound < 1000 && covered && verifySquareCover(proof) && independent && abs(bound-maximum) < 1e-5);
end
channels = [2,4,7,11];
for receiver = [1,2,7,11]
    for future = {[4,11],[2,7],zeros(1,0)}
        order = coverageScanOrder(channels,receiver,future{1},"endpoints");
        actual = double(receiver ~= order(1))+sum(diff(order) ~= 0);
        allOrders = perms(channels);
        costs = double(allOrders(:,1) ~= receiver)+sum(diff(allOrders,1,2) ~= 0,2);
        if ~isempty(future{1})
            actual = actual+double(~ismember(order(end),future{1}));
            costs = costs+double(~ismember(allOrders(:,end),future{1}));
        end
        add("Scan endpoints independent exhaustive switch optimum "+height(checks),actual == min(costs) && isequal(sort(order),channels));
    end
end
angle = (0:5)'*60+30;
points = [0,0;1200*cosd(angle),1200*sind(angle)];
[station,proof,future] = coverageReplacement(points(1,:),points(2,:)+[1,1],points,2:7,"replace");
add("Actual stop can substitute a necessary future station",station > 0 && verifySquareCover(proof) && numel(future) == 5);
[station,~,~] = coverageReplacement(points(1,:),[0,0],points,2:7,"replace");
add("Central repeat cannot replace missing outer coverage",station == -1);
[covered,~] = certifyNoSignalDiskCover(points(1:6,:));
add("Six incomplete fixed observations are not full coverage",~covered);
add("Independent Voronoi boundary enumeration detects missing coverage",~independentDiskCover(points(1:6,:)));
bad = coverageTuning("v070");
bad.duringLocalization = 1;
rejected = false;
try
    validateCoverageTuning(bad);
catch errorInfo
    rejected = strcmp(errorInfo.identifier,'Q3:CoverageConfig');
end
add("Invalid coverage setting rejected",rejected);
scenarios = routeScenarios("regression");
for index = 1:numel(scenarios)
    config = coverageSettings(settings,"release");
    [exchange,report] = makeWorld(scenarios(index).sources);
    [solution,failure] = solveRoute(exchange,config);
    world = report();
    [boundValid,polygonValid] = checkHistory(solution.history,scenarios(index).sources);
    tag = string(scenarios(index).name);
    add("Current group three clears all sources "+tag,all(world.cleared) && solution.complete && isempty(failure.identifier));
    add("Actual per-channel absence and sequential decisions "+tag,verifySearchEvidence(solution,world.log) ...
        && verifyRouteDecisions(solution,world.log) && verifyRouteProbes(solution) && verifyCoverageDecisions(solution,world.log) ...
        && verifyLayoutDecision(solution,world.log) && independentAbsenceCover(solution,world.log));
    add("Conservative geometry and bounded actions "+tag,boundValid && polygonValid ...
        && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6) && solution.searchMeasures <= 140 ...
        && solution.routeProbeMeasures <= 952 && solution.serial <= 1206);
    add("Full cost and no failed clears "+tag,abs(solution.costs(1)/5+sum(solution.costs(2:5))-world.time) < 1e-7 && solution.costs(4) == 0);
    save(fullfile(path,char("scene_"+tag+".mat")),'config','solution','world','failure');
    if index == 1
        badSolution = solution;
        badSolution.retiredCoverage(1,1) = ~badSolution.retiredCoverage(1,1);
        add("Invented retired station ledger rejected",~verifyCoverageDecisions(badSolution,world.log));
        badSolution = solution;
        unresolved = find(solution.status == 3,1);
        badSolution.absenceReason(unresolved) = "observed_cover";
        badSolution.absenceProof{unresolved} = proof;
        add("Planned station certificate cannot certify actual absence",~verifySearchEvidence(badSolution,world.log));
    end
end
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks,'allPassed',all(checks.Passed));
assert(output.allPassed,'Q3:Group3Validation','Group-three checks failed.');
    function add(name,value)
        checks(end+1,:) = {string(name),logical(value)};
    end
end

function [covered,maximum] = independentDiskCover(centers)
centers = unique(centers,'rows');
if isempty(centers)
    covered = false;
    maximum = Inf;
    return
end
radius = 1800;
count = size(centers,1);
points = zeros(2+count+count*(count-1)+count*(count-1)*(count-2)/6,2);
points(1:2,:) = [0,0;radius,0];
used = 2;
for i = 1:size(centers,1)
    a = centers(i,:);
    if norm(a) > 1e-10
        used = used+1;
        points(used,:) = -radius*a/norm(a);
    end
    for j = i+1:size(centers,1)
        b = centers(j,:);
        normal = b-a;
        value = (dot(b,b)-dot(a,a))/2;
        foot = value/dot(normal,normal)*normal;
        if norm(foot) <= radius
            side = sqrt(max(0,radius^2-dot(foot,foot)))*[-normal(2),normal(1)]/norm(normal);
            points(used+(1:2),:) = [foot+side;foot-side];
            used = used+2;
        end
        for k = j+1:size(centers,1)
            c = centers(k,:);
            matrix = 2*[b-a;c-a];
            if abs(det(matrix)) < 1e-8
                continue
            end
            center = (matrix\[dot(b,b)-dot(a,a);dot(c,c)-dot(a,a)])';
            if norm(center) <= radius
                used = used+1;
                points(used,:) = center;
            end
        end
    end
end
points = points(1:used,:);
nearest = Inf(size(points,1),1);
for i = 1:size(centers,1)
    nearest = min(nearest,vecnorm(points-centers(i,:),2,2));
end
maximum = max(nearest);
covered = maximum <= 1000+1e-6;
end

function valid = independentAbsenceCover(solution,log)
valid = true;
for channel = find(solution.status == 3)
    if solution.absenceReason(channel) == "count_limit"
        valid = valid && numel(unique(log.Channel(log.Path == "/clear" & log.Result == "success" & log.Accepted))) == 16;
    else
        selected = log.Path == "/measure" & log.Result == "no_signal" & log.Channel == channel & log.Accepted;
        valid = valid && independentDiskCover([log.X_m(selected),log.Y_m(selected)]);
    end
end
end

function valid = verifyLayoutDecision(solution,log)
if ~isfield(solution,'layoutDecision') || ~solution.layoutDecision.applied
    valid = true;
    return
end
d = solution.layoutDecision;
valid = d.serial == 21 && height(log) > 21 && log.Path(1) == "/enter";
if ~valid
    return
end
initial = log(2:d.serial,:);
valid = all(initial.Path == "/measure" & initial.Result == "no_signal" & initial.Accepted) ...
    && all(hypot(initial.X_m,initial.Y_m) <= 1e-8) && numel(unique(initial.Channel)) == 20;
if d.policy == "baseline"
    valid = valid && d.radius == 1500 && d.rotation == 30;
elseif d.policy == "outer"
    valid = valid && d.radius == 1500 && d.rotation == 0;
elseif d.policy == "middle"
    valid = valid && d.radius == 1400 && d.rotation == 0;
else
    valid = false;
end
angles = (0:5)'*60+d.rotation;
expected = [0,0;d.radius*cosd(angles),d.radius*sind(angles)];
comparisonPoints = solution.points;
if isfield(solution,'mobileMode') && solution.mobileMode ~= "none"
    comparisonPoints = solution.mobileInitialPoints;
end
valid = valid && isequal(comparisonPoints,expected) && solution.search.radius == d.radius ...
    && solution.search.rotation == d.rotation && independentDiskCover(expected);
end

function output = validateLayout(root,settings)
path = fullfile(root,'运行结果',char("validate_layout_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
assert(~isfolder(path),'Q3:Output','New layout validation output required.');
mkdir(path);
checks = table(strings(0,1),false(0,1),'VariableNames',{'Check','Passed'});
for count = [10,13,16]
    angle = 17+(0:count-1)'*360/count;
    sources = [(1:count)',1800*cosd(angle),1800*sind(angle),1000*ones(count,1),ones(count,1)];
    baseline = coverageSettings(settings,"v070");
    [exchange,report] = makeWorld(sources);
    oldSolution = solveRoute(exchange,baseline);
    oldWorld = report();
    for policy = ["baseline","outer","middle"]
        config = coverageSettings(settings,"r1200_rot0_origin"+policy);
        [exchange,report] = makeWorld(sources);
        [solution,failure] = solveRoute(exchange,config);
        world = report();
        tag = policy+" N"+count;
        add("Complete normal all-outer scene "+tag,all(world.cleared) && solution.complete && isempty(failure.identifier));
        add("Layout changes only after twenty real negative origin replies "+tag,solution.layoutDecision.applied && verifyLayoutDecision(solution,world.log));
        add("Independent actual absence and route evidence "+tag,verifySearchEvidence(solution,world.log) ...
            && independentAbsenceCover(solution,world.log) && verifyRouteDecisions(solution,world.log) && verifyCoverageDecisions(solution,world.log));
        add("Original finite action and contraction bounds "+tag,solution.serial <= 1206 ...
            && solution.routeProbeMeasures <= 952 && solution.searchMeasures <= 140 ...
            && all(solution.localMoves <= 7) && all(solution.localMeasures <= 6));
        if policy == "baseline"
            add("Fallback exactly matches published baseline physical actions N"+count,isequaln(world.log,oldWorld.log) && solution.virtualTime == oldSolution.virtualTime);
        end
        bad = solution;
        bad.layoutDecision.serial = 20;
        add("Nineteen negatives cannot trigger layout fallback "+tag,~verifyLayoutDecision(bad,world.log));
        invalid = world.log;
        invalid.Result(2) = "direction";
        add("Any positive origin response rejects the empty-origin branch "+tag,~verifyLayoutDecision(solution,invalid));
        save(fullfile(path,char(policy+"_N"+count+".mat")),'solution','world','config','failure');
    end
    sources(1,2:3) = [1,1];
    config = coverageSettings(settings,"r1200_rot0_originbaseline");
    [exchange,report] = makeWorld(sources);
    solution = solveRoute(exchange,config);
    world = report();
    add("Positive origin scene retains short layout N"+count,all(world.cleared) && ~solution.layoutDecision.applied ...
        && solution.search.radius == 1200 && solution.search.rotation == 0 && verifySearchEvidence(solution,world.log));
end
writetable(checks,fullfile(path,'必要验证.csv'),'Encoding','UTF-8');
output = struct('path',path,'checks',checks,'allPassed',all(checks.Passed));
assert(output.allPassed,'Q3:LayoutValidation','Origin layout validation failed.');
    function add(name,value)
        checks(end+1,:) = {string(name),logical(value)};
    end
end


function value = regionServiceScore(track,meanForecast,at,bound,estimate,config)
axis = [cosd(track.angle),sind(track.angle)];
projection = track.polygon*axis';
[~,low] = min(projection);
[~,high] = max(projection);
estimates = [estimate;0.5*(estimate+track.polygon(low,:));0.5*(estimate+track.polygon(high,:))];
weights = [0.5;0.25;0.25];
scores = zeros(3,1);
scores(1) = estimatedServiceTime(meanForecast,at,1,1,estimate,config);
for sampleIndex = 2:3
    forecast = track;
    forecast.bound = bound;
    try
        forecast = updateTrack(forecast,estimatedBearing(at,estimates(sampleIndex,:)),at,config);
        scores(sampleIndex) = estimatedServiceTime(forecast,at,1,1,estimates(sampleIndex,:),config);
    catch errorInfo
        if ismember(string(errorInfo.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
            scores(sampleIndex) = Inf;
        else
            rethrow(errorInfo)
        end
    end
end
value = sum(weights.*scores);
end

function [destination,nextBound,evidence] = nextLocalizationPoint(track,position,config)
if isfield(config,'workSensing') && config.workSensing && isfield(config,'flexAllowance') && config.flexAllowance && ~isempty(track.polygon)
    [destination,nextBound,evidence] = workLocalizationPoint(track,position,config);
    return
end
[destination,nextBound,evidence] = boundedLocalizationPoint(track,position,config);
if ~isfield(config,'flexFree') || ~config.flexFree || ~isfield(config,'flexAllowance') || ~config.flexAllowance || nextBound <= config.clearMargin || isempty(track.polygon)
    return
end
[center,~] = minimumCircle(track.polygon);
axis = [cosd(track.angle),sind(track.angle)];
normal = [-axis(2),axis(1)];
candidates = [destination;center;center+[-300;-150;-50;50;150;300]*normal;position+0.5*(center-position);position+0.75*(center-position)];
estimate = mean(track.polygon,1);
forecastConfig = config;
forecastConfig.flexFree = false;
forecastConfig.flexAllowance = false;
forecastConfig.improvement.nextPoint = false;
best = Inf;
originalBound = nextBound;
for i = 1:size(candidates,1)
    at = candidates(i,:);
    bound = max(vecnorm(track.polygon-at,2,2))+1e-7;
    if i == 1
        bound = originalBound;
    elseif bound >= 1000-1e-5 || norm(at-position) <= 1e-6
        continue
    end
    if bound <= config.clearMargin
        score = norm(at-position)/5+5;
    else
        forecast = track;
        forecast.bound = bound;
        try
            forecast = updateTrack(forecast,estimatedBearing(at,estimate),at,forecastConfig);
            score = norm(at-position)/5+5+regionServiceScore(track,forecast,at,bound,estimate,forecastConfig);
        catch failure
            if ismember(string(failure.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
                continue
            end
            rethrow(failure)
        end
    end
    if score < best-1e-8
        best = score;
        destination = at;
        nextBound = bound;
        evidence = struct('method',"finite_free_sensing",'bound',bound,'referenceBound',originalBound,'candidateCount',size(candidates,1),'predictedCost_s',score,'wholePolygonBound',i~=1,'exploratory',i~=1 && bound>originalBound+2e-7);
    end
end
assert(nextBound < 1000,'Q3:FreeReception','Free sensing must preserve whole-region reception.');
end

function valid = verifyMobileHistory(solution,log)
valid = true;
if ~isfield(solution,'mobileMode') || solution.mobileMode == "none"
    return
end
try
    initial = [0,0;solution.search.radius*cosd((0:5)'*60+solution.search.rotation),solution.search.radius*sind((0:5)'*60+solution.search.rotation)];
    assert(isequal(solution.mobileInitialPoints,initial));
    retired = false(7,20);
    retireHistory = struct([]);
    if isfield(solution,'retirementHistory')
        retireHistory = solution.retirementHistory;
    end
    retireCursor = 1;
    actual = false(7,20);
    negative = repmat({zeros(0,2)},1,20);
    points = initial;
    history = solution.mobileHistory;
    cursor = 1;
    for k = 1:height(log)
        d = solution.decisions(k);
        while retireCursor <= numel(retireHistory) && retireHistory(retireCursor).serialBefore == k-1
            event = retireHistory(retireCursor);
            channel = event.channel;
            station = event.station;
            assert(~actual(station,channel) && ~retired(station,channel));
            assert(isequal(event.negativeBefore,negative{channel}));
            future = find(~actual(:,channel) & ~retired(:,channel))';
            future(future == station) = [];
            assert(isequal(event.futureSlots,future) && isequal(event.futureCenters,points(future,:)));
            expected = unique([negative{channel};points(future,:)],'rows');
            assert(event.promisedOnly && isequal(event.certificate.centers,expected) && verifySquareCover(event.certificate,998));
            retired(station,channel) = true;
            retireCursor = retireCursor+1;
        end
        if cursor <= numel(history) && history(cursor).serialBefore == k-1
            e = history(cursor);
            station = e.station;
            assert(isscalar(station) && station >= 2 && station <= 7 && fix(station) == station);
            assert(isequal(e.original,points(station,:)) && all(isfinite(e.destination)));
            assert(e.promisedOnly && e.certificateRadius_m == 998 && e.guaranteedReceptionRadius_m == 1000);
            channels = find(d.statusBefore == 0 & ~actual(station,:) & ~retired(station,:));
            assert(isequal(channels,e.channels));
            for j = 1:numel(channels)
                channel = channels(j);
                future = find(~actual(:,channel) & ~retired(:,channel))';
                future(future == station) = [];
                assert(isequal(e.negativeBefore{j},negative{channel}));
                assert(isequal(e.futureSlots{j},future) && isequal(e.futureCenters{j},points(future,:)));
                expected = [unique([negative{channel};points(future,:)],'rows');e.destination];
                proof = e.certificates{e.membership(j)};
                assert(isequal(proof.centers,expected) && proof.receptionRadius == 998 && proof.targetRadius == 1800);
                assert(verifySquareCover(proof,998));
            end
            improved = e.newLocalTravel_m < e.oldLocalTravel_m;
            if isfield(e,'forecastActive') && e.forecastActive
                improved = e.planningObjectiveAfter < e.planningObjectiveBefore;
            end
            assert(improved && isequal(e.predecessor,d.positionBefore));
            points(station,:) = e.destination;
            cursor = cursor+1;
        end
        if d.path == "/measure"
            channel = d.request.channel;
            at = [d.request.position.x,d.request.position.y];
            actual(vecnorm(points-at,2,2) <= 1e-8,channel) = true;
            if log.Result(k) == "no_signal"
                negative{channel}(end+1,:) = at;
            end
        end
        assert(isequal(actual,d.coverageAfter) && isequal(retired,d.retiredCoverageAfter));
    end
    assert(retireCursor == numel(retireHistory)+1 && isequal(retired,solution.retiredCoverage));
    assert(cursor == numel(history)+1 && isequal(points,solution.points) && isequal(actual,solution.coverage));
catch
    valid = false;
end
end

function center = regionCentroid(polygon)
next = polygon([2:end,1],:);
cross = polygon(:,1).*next(:,2)-next(:,1).*polygon(:,2);
area = sum(cross);
if abs(area) > 1e-10
    center = sum((polygon+next).*cross,1)/(3*area);
else
    center = mean(polygon,1);
end
end

function [destination,nextBound,evidence] = workLocalizationPoint(track,position,config)
plain = config;
plain.workSensing = false;
[base,baseBound,baseEvidence] = nextLocalizationPoint(track,position,plain);
if baseBound <= config.clearMargin
    destination = base;
    nextBound = baseBound;
    evidence = baseEvidence;
    return
end
center = regionCentroid(track.polygon);
axis = [cosd(track.angle),sind(track.angle)];
normal = [-axis(2),axis(1)];
projection = track.polygon*axis';
[~,lo] = min(projection);
[~,hi] = max(projection);
left = track.polygon(lo,:);
right = track.polygon(hi,:);
along = left+[0.35;0.55;0.7;0.85]*(right-left);
candidates = [base;center;along;center+[-150;-75;75;150]*normal];
credits = zeros(size(candidates,1),1);
if config.workJoint
    candidates = [candidates;config.workStations];
    credits = [credits;config.workCredits];
end
representatives = [center;0.5*(center+left);0.5*(center+right)];
weights = [0.5;0.25;0.25];
forecastConfig = plain;
forecastConfig.flexFree = false;
forecastConfig.flexAllowance = false;
forecastConfig.improvement.nextPoint = false;
best = Inf;
destination = base;
nextBound = baseBound;
evidence = baseEvidence;
scores = Inf(size(candidates,1),1);
for wi = 1:size(candidates,1)
    at = candidates(wi,:);
    bound = max(vecnorm(track.polygon-at,2,2))+1e-7;
    if wi == 1
        bound = baseBound;
    elseif bound >= 1000-1e-5 || norm(at-position) <= 1e-6
        continue
    end
    costs = zeros(3,1);
    for ri = 1:3
        forecast = track;
        forecast.bound = bound;
        try
            forecast = updateTrack(forecast,estimatedBearing(at,representatives(ri,:)),at,forecastConfig);
            costs(ri) = estimatedServiceTime(forecast,at,1,1,representatives(ri,:),forecastConfig);
        catch failure
            if ismember(string(failure.identifier),["Q3:EmptyRegion","Q3:NegativeRegion"])
                costs(ri) = Inf;
            else
                rethrow(failure)
            end
        end
    end
    score = norm(at-position)/5+5+sum(weights.*costs)-credits(wi);
    scores(wi) = score;
    if score < best-1e-8
        best = score;
        destination = at;
        nextBound = bound;
        evidence = struct('method',"remaining_work_sensing",'bound',bound,'referenceBound',track.bound/(2*cosd(config.angleMargin))+1e-7, ...
            'candidateCount',size(candidates,1),'predictedCost_s',score,'wholePolygonBound',wi~=1 || baseEvidence.wholePolygonBound, ...
            'exploratory',bound>track.bound/(2*cosd(config.angleMargin))+3e-7,'scanRouteCredit_s',credits(wi), ...
            'representatives',representatives,'weights',weights,'distributionAssumed',false,'scorePurpose',"heuristic_ranking_only");
    end
end
evidence.candidates = candidates;
evidence.scores = scores;
assert(nextBound < 1000,'Q3:WorkReception','Whole-region reception required.');
end

function costs = remainingScanWork(negativePoints,status,coverage,retired,points,required)
count = numel(required);
costs = zeros(2^count,count);
unknown = find(status == 0);
known = sum(status == 1 | status == 2);
occupancy = min(1,(max(0,10-known)+max(0,16-known))/(2*max(1,numel(unknown))));
[gx,gy] = meshgrid(-1750:250:1750);
samples = [gx(:),gy(:)];
samples = samples(vecnorm(samples,2,2) <= 1800,:);
for channel = unknown
    admissible = true(size(samples,1),1);
    negatives = negativePoints{channel};
    for ni = 1:size(negatives,1)
        admissible = admissible & vecnorm(samples-negatives(ni,:),2,2) > 1000;
    end
    remaining = samples(admissible,:);
    if isempty(remaining)
        costs = costs+6*double(~coverage(required,channel)' & ~retired(required,channel)');
        continue
    end
    visible = false(size(remaining,1),count);
    for station = 1:count
        visible(:,station) = vecnorm(remaining-points(required(station),:),2,2) <= 1000;
    end
    for mask = 0:2^count-1
        seen = false(size(remaining,1),1);
        for station = 1:count
            if bitget(mask,station)
                seen = seen | visible(:,station);
            end
        end
        survival = 1-occupancy*mean(seen);
        costs(mask+1,:) = costs(mask+1,:)+6*survival*double(~coverage(required,channel)' & ~retired(required,channel)');
    end
end
end

function graph = regionRouteGraph(position,representatives)
n = numel(representatives);
graph = struct('startCost',zeros(n,1),'edges',zeros(n,n));
for i = 1:n
    left = representatives{i};
    leftWeights = ones(size(left,1),1)/size(left,1);
    if size(left,1) == 3
        leftWeights = [0.5;0.25;0.25];
    end
    graph.startCost(i) = sum(vecnorm(left-position,2,2).*leftWeights);
    for j = 1:n
        right = representatives{j};
        rightWeights = ones(size(right,1),1)/size(right,1);
        if size(right,1) == 3
            rightWeights = [0.5;0.25;0.25];
        end
        pairwise = hypot(left(:,1)-right(:,1)',left(:,2)-right(:,2)');
        graph.edges(i,j) = leftWeights'*pairwise*rightWeights;
    end
end
end

function polygon = rangeDominancePolygon(polygon,positive,negative)
for ni = 1:size(negative,1)
    noPoint = negative(ni,:);
    for pi = 1:size(positive,1)
        yesPoint = positive(pi,:);
        normal = noPoint-yesPoint;
        bound = (dot(noPoint,noPoint)-dot(yesPoint,yesPoint))/2;
        polygon = clipPlane(polygon,normal,bound+1e-6*max(1,norm(normal)));
        assert(~isempty(polygon),'Q3:RangeRegion','Fixed reception radius constraints have no compatible region.');
    end
end
end

