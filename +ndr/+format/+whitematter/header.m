function H = header(filename)
%HEADER Reads header information embedded within a WhiteMatter LLC binary filename.
%   H = ndr.format.whitematter.header(FILENAME)
%
%   Parses a WhiteMatter LLC binary data filename to extract metadata about
%   the recording session. The filename is expected to follow a specific
%   convention, typically including format, date, time, duration, device type,
%   channel count, and sampling rate, separated by double underscores ('__').
%
%   Expected Filename Format Examples:
%       HSW_2025_01_14__12_43_33__03min_46sec__hsamp_64ch_20000sps.bin
%       HSW_2025_01_14__12_43_33__03min_46sec__mmx_imu_10ch_20000sps.bin
%
%   Inputs:
%       FILENAME  - The full path or relative path to the WhiteMatter LLC
%                   binary data file (e.g., ending in '.bin').
%                   (char row vector). The file must exist.
%
%   Outputs:
%       H         - A structure containing the extracted header information:
%           .filename         : The base name of the input file (string).
%           .filepath         : The directory path of the input file (string).
%           .file_format      : The format identifier (e.g., 'HSW') (string).
%           .start_time_iso   : The recording start date and time in ISO 8601
%                               format ('YYYY-MM-DDTHH:MM:SS') (string).
%           .duration_seconds : The recording duration in seconds (double).
%           .device_type      : The identifier for the recording device
%                               (e.g., 'hsamp', 'mmx_imu') (string).
%           .num_channels     : The number of channels recorded (double).
%           .sampling_rate    : The sampling rate in samples per second (Hz)
%                               (double).
%
%   Errors:
%       - Throws an error if the input filename does not exist.
%       - Throws an error if the filename does not conform to the expected
%         parsing format (e.g., incorrect number of '__' separators or
%         unparsable components).
%
%   See also: fileparts, strsplit, regexp, sscanf, datetime

% --- Input Argument Validation ---
arguments
    filename (1,:) char {mustBeFile}
end

% --- Parse Filename ---
[filepath, name, ext] = fileparts(filename);
H.filename = [name ext]; % Store original filename with extension
H.filepath = filepath;

% Split the base filename by the double underscore delimiter
parts = strsplit(name, '__');

% Validate the number of parts obtained
expected_parts = 4; % Corrected expected parts
if numel(parts) ~= expected_parts
    error('ndr:format:whitematter:header:InvalidFilenameFormat', ...
          'Filename "%s" does not match the expected format. Expected %d parts separated by "__", but found %d.', ...
          H.filename, expected_parts, numel(parts));
end

% --- Extract Information from Parts ---
try
    % Part 1: File Format and Date (e.g., "HSW_2025_01_14")
    part1 = parts{1};
    % Corrected logic: Find the FIRST underscore to separate format and date
    first_underscore_idx = find(part1 == '_', 1, 'first'); 
    if isempty(first_underscore_idx) || first_underscore_idx == numel(part1)
         error('Could not separate file format from date in part "%s". Expected format like "FORMAT_YYYY_MM_DD".', part1);
    end
    H.file_format = part1(1:first_underscore_idx-1); % Get part before first underscore
    date_part_underscores = part1(first_underscore_idx+1:end); % Get part after first underscore
    date_part = strrep(date_part_underscores, '_', '-'); % Replace remaining underscores with hyphens
     if isempty(H.file_format)
        error('File format part is empty after parsing "%s".', part1);
     end
     % Add a check for expected date format after replacement
     if ~regexp(date_part, '^\d{4}-\d{2}-\d{2}$')
        error('Parsed date part "%s" from "%s" does not match YYYY-MM-DD format.', date_part, part1);
     end

    % Part 2: Time (e.g., "12_43_33")
    time_part_underscores = parts{2};
    time_part = strrep(time_part_underscores, '_', ':'); % HH:MM:SS

    % Combine Date and Time -> ISO 8601 String
    H.start_time_iso = [date_part 'T' time_part];
    % Validate datetime format implicitly by trying to convert
    try
        datetime(H.start_time_iso, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    catch ME_dt
        % Use the corrected date_part in the error message
        error('Could not parse date part "%s" (from "%s") and time part "%s" into datetime. Reason: %s', date_part, part1, time_part_underscores, ME_dt.message);
    end

    % Part 3: Duration (e.g., "03min_46sec")
    duration_str = parts{3};
    duration_parts = sscanf(duration_str, '%dmin_%dsec');
    if numel(duration_parts) ~= 2
        error('Could not parse duration part "%s". Expected format like "XXmin_YYsec".', duration_str);
    end
    H.duration_seconds = double(duration_parts(1) * 60 + duration_parts(2));

    % Part 4: Device Info (Type, Channels, Sampling Rate) (e.g., "hsamp_64ch_20000sps")
    device_info_str = parts{4};
    % Use regexp for more robust parsing of the last part
    % Matches: (device_type)_(num_channels)ch_(sampling_rate)sps
    % Note: \d matches digits, + means one or more, ? makes the preceding quantifier lazy
    tokens = regexp(device_info_str, '^([a-zA-Z0-9_]+?)_(\d+)ch_(\d+)sps$', 'tokens');
    if isempty(tokens) || numel(tokens{1}) ~= 3
         error('Could not parse device info part "%s". Expected format like "devicetype_XXch_YYYYsps".', device_info_str);
    end
    H.device_type = tokens{1}{1};
    H.num_channels = str2double(tokens{1}{2});
    H.sampling_rate = str2double(tokens{1}{3});

    if isnan(H.num_channels) || isnan(H.sampling_rate)
        error('Could not convert channel count or sampling rate to numbers in part "%s".', device_info_str);
    end

catch ME
    % Add context to any parsing error
    new_error = MException('ndr:format:whitematter:header:ParsingError', ...
        'Error parsing filename "%s": %s', H.filename, ME.message);
    new_error = new_error.addCause(ME);
    throw(new_error);
end

end % function header

