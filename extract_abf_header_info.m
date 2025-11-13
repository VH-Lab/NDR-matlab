% --- INSTRUCTIONS ---
% 1. Make sure 'abfload3.m' is in your MATLAB path.
% 2. Replace the placeholder path in the 'abfFilePath' variable below with the full path to your ABF file.
% 3. Run this script.
% 4. Copy the entire text output from the MATLAB command window and paste it back for analysis.
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

    % Call abfload3 to get the header and data
    fprintf('Loading ABF file: %s\n', abfFilePath);
    [d, ~, h] = abfload3(abfFilePath);

    % Get the size of the data array
    d_size = size(d);

    % Display the header and data size
    fprintf('\n--- ABF HEADER INFORMATION ---\n');
    disp(h);

    fprintf('\n--- DATA SIZE ---\n');
    disp(d_size);

    fprintf('\n--- DACEpoch FIELD ---\n');
    if isfield(h, 'DACEpoch')
        disp(h.DACEpoch);
    else
        fprintf('DACEpoch field not found in the header.\n');
    end

    fprintf('\n--- DIAGNOSTIC SCRIPT COMPLETED SUCCESSFULLY ---\n');
    fprintf('Please copy and paste the full text output from the command window for analysis.\n');

catch ME
    fprintf('\n--- AN ERROR OCCURRED ---\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Please check the file path and ensure that abfload3.m is in your MATLAB path.\n');
end
