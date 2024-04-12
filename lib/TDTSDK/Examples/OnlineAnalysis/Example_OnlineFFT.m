%% Spectrum Analyzer
%
% <html>
% Read a single channel and plot the power spectrum over time
% <br>
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
if syn.setCurrentExperiment('APIStreamer1ChDemo') == 0
    error('trouble loading experiment');
end
syn.setModeStr('Preview');
pause(4);

%%
% Setup APIStreamer
s = APIStreamer('GIZMO', 'APIStreamer1Ch1','HISTORY', 30, 'DO_FFT', 1, 'WINSIZE', 1, 'FREQ', [1 20]);

h = figure;
set(gcf, 'Position', [800, 200, 600, 900])

%% The Main Loop
while size(findobj(h)) > 0 % run while the figure is open

    [fft_data, ts, fft_freq] = s.get_data();
    if ~any(fft_data(:)), continue, end

    psdx = fft_data/(s.fs*size(fft_data,2));
    %20*log10(fft_data) for power in dB
    
    last_psd = psdx(:,end);
    
    spectral_peak = max(last_psd);
    peak_freq = fft_freq(last_psd == spectral_peak);

    % calculate power and normalize color bar
    Power = fft_data;

    if any(isinf(Power(:))), continue, end

    Z_STD = 6 * std(Power(:));
    Z_MEAN = mean(Power(:));

    % plot it
    subplot(2,1,1);
    plot(fft_freq, last_psd);
    grid on
    title('Periodogram Using FFT')
    xlabel('Frequency (Hz)')
    ylabel('Energy/Frequency (1/Hz)')

    subplot(2,1,2);
    imagesc(ts, fft_freq, Power, [Z_MEAN-Z_STD, Z_MEAN+Z_STD]);
    h_colorbar = colorbar;
    colormap(jet);
    set(gca,'fontsize',12);
    xlabel('Time (s)','fontsize',15);
    ylabel('Frequency (Hz)','fontsize',15);
    ylabel(h_colorbar,'Energy','Rotation',-90,'fontsize',15,'VerticalAlignment','baseline');
    title(sprintf('Spectrogram'))
    axis xy;

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
