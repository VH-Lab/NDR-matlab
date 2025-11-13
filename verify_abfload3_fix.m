% Test script to verify the fix for abfload3.m

% --- INSTRUCTIONS ---
% 1. Make sure 'abfload3.m' is in your MATLAB path.
% 2. Change the 'abfFilePath' variable below to the full path of your ABF file.
% 3. Run this script.
% --------------------

% --- CONFIGURATION ---
% IMPORTANT: Please replace the placeholder path below with the actual path to your ABF file.
% Example: abfFilePath = 'C:\Users\YourUser\Documents\data\your_file.abf';
abfFilePath = 'path/to/your/abf/file.abf'; % <-- SET YOUR FILE PATH HERE

% --- SCRIPT ---
try
    % Check if the file exists
    if ~isfile(abfFilePath)
        error('ABF file not found at: %s', abfFilePath);
    end

    % Call abfload3
    fprintf('Loading ABF file: %s\n', abfFilePath);
    [d, si, h] = abfload3(abfFilePath);

    % Verification
    fprintf('Verifying output...\n');

    % Check for digital channel names in the header
    digitalChannelsFound = false;
    if isfield(h, 'recChNames') && iscell(h.recChNames)
        for i = 1:numel(h.recChNames)
            if startsWith(h.recChNames{i}, 'DIGITAL_OUT_')
                digitalChannelsFound = true;
                break;
            end
        end
    end

    % Check that the data dimensions are correct
    expectedNumChans = numel(h.recChNames);
    actualNumChans = size(d, 2);

    if digitalChannelsFound && (expectedNumChans == actualNumChans)
        fprintf('\n--- VERIFICATION SUCCESSFUL ---\n');
        fprintf('Digital channel data was found in the output.\n');
        fprintf('The ''h.recChNames'' field contains digital channel names, and the dimensions of the data array ''d'' are correct.\n');
        disp('Header fields:');
        disp(h);
    else
        fprintf('\n--- VERIFICATION FAILED ---\n');
        if ~digitalChannelsFound
            fprintf('Digital channel names were NOT found in the ''h.recChNames'' field.\n');
        end
        if (expectedNumChans ~= actualNumChans)
            fprintf('The number of channels in the data array ''d'' (%d) does not match the number of channel names in the header (%d).\n', actualNumChans, expectedNumChans);
        end
        disp('Header fields:');
        disp(h);
    end

catch ME
    fprintf('\n--- AN ERROR OCCURRED ---\n');
    fprintf('Error identifier: %s\n', ME.identifier);
    fprintf('Error message: %s\n', ME.message);
    fprintf('Please check the file path and ensure that abfload3.m is accessible.\n');
end
