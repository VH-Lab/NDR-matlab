% --- INSTRUCTIONS ---
% 1. Make sure 'abfload3.m' is in your MATLAB path.
% 2. Replace the placeholder path in the 'abfFilePath' variable below with the full path to your ABF file.
% 3. Run this script. It will print the epoch table to the command window and generate a plot of the DAC waveforms.
% --------------------

% --- CONFIGURATION ---
% IMPORTANT: Please replace the placeholder path below with the actual path to your ABF file.
abfFilePath = '/Users/vanhoosr/data/saya/CNOdata/SHR/SHRNonly/2023_05_11_05_0003.abf'; % <-- SET YOUR FILE PATH HERE

% --- SCRIPT ---
try
    % Check if the file exists
    if ~isfile(abfFilePath)
        error('ABF file not found. Please update the abfFilePath variable.');
    end

    % Call abfload3 to get the data and header
    fprintf('Loading ABF file: %s\n', abfFilePath);
    [d, ~, h] = abfload3(abfFilePath);

    % --- Display Epoch Information ---
    if isfield(h, 'DACEpoch')
        fprintf('\n--- EPOCH TABLE INFORMATION ---\n');
        for i = 1:numel(h.DACEpoch)
            fprintf('\n--- DAC Channel %d ---\n', h.DACEpoch(i).nDACNum);
            fprintf('Epoch | Level\t | Duration (ms)\n');
            fprintf('----------------------------------\n');
            totalDuration = 0;
            for j = 1:numel(h.DACEpoch(i).nEpochType)
                durationMs = (h.DACEpoch(i).lEpochInitDuration(j) * h.nADCNumChannels * h.si) / 1e3;
                fprintf('  %d\t  | %.2f\t | %.2f\n', j, h.DACEpoch(i).fEpochInitLevel(j), durationMs);
                totalDuration = totalDuration + durationMs;
            end
        end
    else
        fprintf('No epoch information found in the header.\n');
    end

    % --- Plot DAC Waveforms ---
    dac0_index = find(strcmp(h.recChNames, 'DAC_0'));
    dac1_index = find(strcmp(h.recChNames, 'DAC_1'));

    if isempty(dac0_index) && isempty(dac1_index)
        error('No DAC channels found in the loaded data.');
    end

    % Create a time vector
    timeVector = (0:h.sweepLengthInPts-1) * h.si / 1e6; % Time in seconds

    % Create a new figure
    figure;
    hold on;

    % Plot DAC_0 if it exists
    if ~isempty(dac0_index)
        plot(timeVector, d(:, dac0_index, 1), 'DisplayName', 'DAC_0');
        fprintf('Plotting DAC_0...\n');
    end

    % Plot DAC_1 if it exists
    if ~isempty(dac1_index)
        plot(timeVector, d(:, dac1_index, 1), 'DisplayName', 'DAC_1');
        fprintf('Plotting DAC_1...\n');
    end

    % Add labels and a legend
    title('DAC Waveforms for the First Sweep');
    xlabel('Time (s)');
    ylabel('Amplitude');
    legend;
    grid on;
    hold off;

    fprintf('\n--- SCRIPT COMPLETED SUCCESSFULLY ---\n');

catch ME
    fprintf('\n--- AN ERROR OCCURRED ---\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Please check the file path and ensure that abfload3.m is in your MATLAB path.\n');
end
