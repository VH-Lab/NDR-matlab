function dt = abfTimeToDatetime(uFileStartDate, uFileStartTimeMS)
% ABFTIMETODATETIME Convert ABF file time fields to Matlab datetime
%   dt = abfTimeToDatetime(uFileStartDate, uFileStartTimeMS) converts
%   Axon Binary Format (ABF) file time fields to a Matlab datetime.
%
%   Inputs:
%       uFileStartDate    - ABF file start date in YYYYMMDD format as a double
%       uFileStartTimeMS  - ABF file start time in milliseconds since midnight
%
%   Output:
%       dt              - Matlab datetime representing the date and time
%
%   Example:
%       dt = abfTimeToDatetime(20240218, 43200000)  % Feb 18, 2024 at 12:00:00
%
%   Notes:
%       - uFileStartDate is expected to be a double in YYYYMMDD format where
%         the 8th digit is the first digit of the year
%       - uFileStartTimeMS represents milliseconds since midnight (0-86,399,999)
%
%   Error Conditions:
%       - Throws error if inputs are not numeric
%       - Throws error if uFileStartTimeMS is not in valid range
%       - Throws error if uFileStartDate is not in valid format

    % Input validation
    if ~isnumeric(uFileStartDate) || ~isnumeric(uFileStartTimeMS)
        error('Both inputs must be numeric values');
    end
    
    if uFileStartTimeMS < 0 || uFileStartTimeMS >= 86400000
        error('uFileStartTimeMS must be between 0 and 86,399,999');
    end
    
    % Extract date components
    dateStr = num2str(uFileStartDate, '%08.0f');  % Ensure 8 digits with leading zeros
    if length(dateStr) ~= 8
        error('uFileStartDate must be in YYYYMMDD format');
    end
    
    year = str2double(dateStr(1:4));
    month = str2double(dateStr(5:6));
    day = str2double(dateStr(7:8));
    
    % Validate date components
    if month < 1 || month > 12 || day < 1 || day > 31
        error('Invalid date components in uFileStartDate');
    end
    
    % Convert milliseconds to hours, minutes, seconds, and milliseconds
    hours = floor(uFileStartTimeMS / (60 * 60 * 1000));
    remaining = uFileStartTimeMS - hours * 60 * 60 * 1000;
    
    minutes = floor(remaining / (60 * 1000));
    remaining = remaining - minutes * 60 * 1000;
    
    seconds = floor(remaining / 1000);
    milliseconds = remaining - seconds * 1000;
    
    % Create datetime object
    dt = datetime(year, month, day, ...
                 hours, minutes, seconds, ...
                 milliseconds, ...
                 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
end
