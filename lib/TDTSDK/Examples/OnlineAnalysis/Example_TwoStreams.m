close all; clear all; clc;

% add the PERIOD parameter to slow down the polling timers so there are no
% conflicts
s1 = APIStreamer('GIZMO','Stream1','HISTORY', 5, 'PERIOD', .1);
s2 = APIStreamer('GIZMO','Stream2','HISTORY', 5, 'PERIOD', .1);

h = figure;
%while ~isempty(findobj(h)) % run while the figure is open
while s1.running() % run while Synapse is recording
    [data1, ts1] = s1.get_data();
    [data2, ts2] = s2.get_data();
    subplot(2,1,1)
    plot(ts1, data1);
    axis tight; xlabel('time, s'); ylabel('V')
    subplot(2,1,2)
    plot(ts2, data2);
    axis tight; xlabel('time, s'); ylabel('V')
    
    % force the plots to update
    try
        snapnow
    catch
        drawnow
    end
    
    % for publishing, end early
    if max(ts1) > 30
        t.SYN.setModeStr('Idle'); % set to idle mode
        break
    end
end

% call this if you exit with ctrl+c
s1.stop()
s2.stop()