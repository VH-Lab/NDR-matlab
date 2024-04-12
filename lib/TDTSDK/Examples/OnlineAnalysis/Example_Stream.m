%% Stream Data with APIStreamer
%
% <html>
% Stream multi-channel data directly from the APIStreamer gizmo running on
% the hardware<br>
% Good for visualization and online analysis<br>
% </html>

%% Housekeeping
% Clear workspace and close existing figures. Add SDK directories to Matlab
% path.
close all; clc;
[MAINEXAMPLEPATH,name,ext] = fileparts(cd); % \TDTMatlabSDK\Examples
[SDKPATH,name,ext] = fileparts(MAINEXAMPLEPATH); % \TDTMatlabSDK
addpath(genpath(SDKPATH));

%% Variable Setup
% load and run demo experiment
syn = SynapseAPI('localhost');
if syn.setCurrentExperiment('APIStreamerMCDemo') == 0
    error('trouble loading experiment');
end
syn.setModeStr('Preview');

%%
% Setup APIStreamer
s = APIStreamer('GIZMO', 'APIStreamerMC1', 'HISTORY', 1, 'CALLBACK', @my_api_callback);

%% The Main Loop
while 1
    [data, ts] = s.get_data();
    plot(ts, data);
    axis tight; xlabel('time, s'); ylabel('V')
    
    % force the plots to update
    try
        snapnow
    catch
        drawnow
    end
    
    % for publishing, end early
    if max(ts) > 30
        s.stop()
        syn.setModeStr('Idle'); % set to idle mode
        break
    end
end
