% --- INSTRUCTIONS ---
% 1. Make sure 'abfload3.m' is in your MATLAB path.
% 2. Replace the placeholder path in the 'abfFilePath' variable below with the full path to your ABF file.
% 3. Run this script. It will create a file named 'abf_header_info.mat' in your current MATLAB directory.
% 4. Please upload the 'abf_header_info.mat' file for analysis.
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

    % Save the header and data size to a .mat file
    outputFileName = 'abf_header_info.mat';
    fprintf('Saving header info to: %s\n', outputFileName);
    save(outputFileName, 'h', 'd_size');

    fprintf('\n--- DIAGNOSTIC SCRIPT COMPLETED SUCCESSFULLY ---\n');
    fprintf('Please upload the file named ''%s'' for analysis.\n', outputFileName);

catch ME
    fprintf('\n--- AN ERROR OCCURRED ---\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Please check the file path and ensure that abfload3.m is in your MATLAB path.\n');
end
