% BASIC EXAMPLE FOR CONNECTION TO PROTEUS USING VISA OR PXI
%==========================================================
% VISA Communications from MATLAB requires the Instrument Control Toolbox

clear;
close all;
clear variables;
clear global;
clc;

% Define IP Address for Target Proteus device descriptor
% VISA "Socket-Based" TCP-IP Device. Socket# = 5025
ipAddr = '127.0.0.1'; % '127.0.0.1' = Local Host, your IP address here
pxiSlot = 0; % Set 0 to select slot from attached modules

% Instrument setup
cType =         "LAN";  %"LAN" = VISA or "DLL" = PXI

if cType == "LAN"
    connPar =       ipAddr; 
else
    connPar =       pxiSlot; % Your stot # here, o for manual selection
end

paranoia_level = 2; % 0, 1 or 2

[inst, admin, idnstr, slotNumber] = ConnecToProteus(cType, connPar, paranoia_level);
fprintf('Connected to: %s, slot: %d\n', idnstr, slotNumber);

% Get options using the standard IEEE-488.2 Command
optstr = getOptions(inst);

for i=1:length(optstr)
    fprintf('\nOption #%d Installed: %s', i, char(optstr(i)));     
end

% Get Number of Channels
numchan = getNumOfChannels(idnstr);
fprintf('\n\nNumber of Channels = %d\n', numchan);

% Get min sampling rate
minsr = getMinSamplingRate(inst);
fprintf('\nMinimum Sample Rate = %d samples/sec\n', minsr);

% Get max sampling rate
maxsr = getMaxSamplingRate(inst);
fprintf('\nMaximum Sample Rate = %d samples/sec\n', maxsr);

% Get granularity
granul = getGranularity(idnstr, optstr, 16);
fprintf('\nGranularity = %d samples\n', granul);

% Get Sample Resolution
dacres = getDacResolution(inst);
fprintf('\nSample Resolution = %d bits\n', dacres);

% Disconnect, close VISA handle and destroy handle  
if cType == "LAN"
    inst.Disconnect();
else
    admin.CloseInstrument(inst.InstrId);    
    admin.Close();
end   
    
clear inst;
clear admin;
close all;

function [  inst,...
            admin,...
            modelName,...
            sId] = ConnecToProteus( cType, ...
                                    connStr, ...
                                    paranoia_level)

% Connection to target Proteus
% cType specifies API. "LAN" for VISA, "DLL" for PXI
% connStr is the slot # as an integer(0 for manual selection) or IP adress
% as an string
% Paranoia Level add additional checks for each transfer. 0 = no checks.
% 1 = send OPC?, 2 = send SYST:ERROR?

% It returns
% inst: handler for the selected instrument
% admin: administrative handler
% modelName: string with model name for selected instrument (i.e. "P9484")
% sId: slot number for selected instrument   
    
    pid = feature('getpid');
    fprintf(1,'\nProcess ID %d\n',pid);
    
    dll_path = 'C:\\Windows\\System32\\TEPAdmin.dll';  
    admin = 0;
    
    if cType == "LAN"
        try            
            connStr = strcat('TCPIP::',connStr,'::5025::SOCKET');
            inst = TEProteusInst(connStr, paranoia_level);
            
            res = inst.Connect();
            assert (res == true);
            modelName = identifyModel(inst);
        catch ME
            rethrow(ME)
        end   
    else
        asm = NET.addAssembly(dll_path);
    
        import TaborElec.Proteus.CLI.*
        import TaborElec.Proteus.CLI.Admin.*
        import System.*
        
        admin = CProteusAdmin(@OnLoggerEvent);
        rc = admin.Open();
        assert(rc == 0);   
        
        try
            slotIds = admin.GetSlotIds();
            numSlots = length(size(slotIds));
            assert(numSlots > 0);
            
            % If there are multiple slots, let the user select one ..
            sId = slotIds(1);
            if numSlots > 1
                fprintf('\n%d slots were found\n', numSlots);
                for n = 1:numSlots
                    sId = slotIds(n);
                    slotInfo = admin.GetSlotInfo(sId);
                    if ~slotInfo.IsSlotInUse
                        modelName = slotInfo.ModelName;
                        if slotInfo.IsDummySlot && connStr == 0
                            fprintf(' * Slot Number:%d Model %s [Dummy Slot].\n', sId, modelName);
                        elseif connStr == 0
                            fprintf(' * Slot Number:%d Model %s.\n', sId, modelName);
                        end
                    end
                end
                pause(0.1);
                if connStr == 0
                    choice = input('Enter SlotId ');
                    fprintf('\n');
                else
                    choice = connStr;
                end                
                sId = uint32(choice);
                slotInfo = admin.GetSlotInfo(sId);
                modelName = slotInfo.ModelName;
                modelName = strtrim(netStrToStr(modelName));
            end
            
            % Connect to the selected instrument ..
            should_reset = true;
            inst = admin.OpenInstrument(sId, should_reset);
            instId = inst.InstrId;
            
        catch ME
            admin.Close();
            rethrow(ME) 
        end    
    end
end

function model = identifyModel(inst)
    idnStr = inst.SendScpi('*IDN?');
    idnStr = strtrim(netStrToStr(idnStr.RespStr));
    idnStr = split(idnStr, ',');    

    if length(idnStr) > 2
        model = idnStr(2);
    else
        model ='P9484M';
    end

%     model = idnStr;
end

function options = getOptions(inst)
    optStr = inst.SendScpi('*OPT?');  
    optStr = strtrim(netStrToStr(optStr.RespStr));
    options = split(optStr, ',');  
end

function minSr = getMinSamplingRate(inst)
    minSr = inst.SendScpi(':FREQ:RAST MIN?');  
    minSr = strtrim(netStrToStr(minSr.RespStr));
    minSr = str2double(minSr);
end

function maxSr = getMaxSamplingRate(inst)
    maxSr = inst.SendScpi(':FREQ:RAST MAX?');  
    maxSr = strtrim(netStrToStr(maxSr.RespStr));
    maxSr = str2double(maxSr);
end

function granularity = getGranularity(model, options, dacMode)

    flagLowGranularity = false;

    for i = 1:length(options)
        if contains(options(i), 'G1') || contains(options(i), 'G2')
            flagLowGranularity = true;
        end        
    end   

    granularity = 32;

    if contains(model, 'P258')
        granularity = 32;    
        if flagLowGranularity
            granularity = 16;
        end
    elseif contains(model, 'P128')
        granularity = 32;    
        if flagLowGranularity
            granularity = 16;
        end
    elseif contains(model, 'P948')
        if dacMode == 16
            granularity = 32;    
            if flagLowGranularity
                granularity = 16;
            end
        else
            granularity = 64;    
            if flagLowGranularity
                granularity = 32;
            end
        end
    elseif contains(model, 'P908')
        granularity = 64;    
        if flagLowGranularity
            granularity = 32;
        end
    end
end

function dacRes = getDacResolution(inst)  

    dacRes = inst.SendScpi(':TRAC:FORM?');
    dacRes = strtrim(netStrToStr(dacRes.RespStr));

    if contains(dacRes, 'U8')
        dacRes = 8;
    else
        dacRes = 16;
    end
end

function numOfChannels = getNumOfChannels(model)

    numOfChannels = 4;
    
    if contains(model, 'P9082')
        numOfChannels = 2;
    elseif contains(model, 'P9482')
        numOfChannels = 2;
    elseif contains(model, 'P1282')
        numOfChannels = 2;
    elseif contains(model, 'P2582')
        numOfChannels = 2;
    elseif contains(model, 'P9086')
        numOfChannels = 6;
    elseif contains(model, 'P9486')
        numOfChannels = 6;
    elseif contains(model, 'P1286')
        numOfChannels = 6;
    elseif contains(model, 'P2586')
        numOfChannels = 6;
    elseif contains(model, 'P9488')
        numOfChannels = 8;
    elseif contains(model, 'P1288')
        numOfChannels = 8;
    elseif contains(model, 'P2588')
        numOfChannels = 8;    
    elseif contains(model, 'P94812')
        numOfChannels = 12;
    elseif contains(model, 'P12812')
        numOfChannels = 12;
    elseif contains(model, 'P25812')
        numOfChannels = 12;
    end
end
function [str] = netStrToStr(netStr)
    try
        str = convertCharsToStrings(char(netStr));
    catch        
        str = '';
    end
end
