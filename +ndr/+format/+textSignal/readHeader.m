function header = readHeader(filename)
% READHEADER - Read the header of an NDR text signal file
%
% HEADER = READHEADER(FILENAME)
%
% Reads the header information from an NDR text signal file.
%
% The header is a structure with the following fields:
%   num_channels - The number of unique channels in the file.
%   time_units - 'datestamp' or 'numeric'.
%

    fid = fopen(filename, 'r');
    if fid == -1
        error(['Could not open file ' filename]);
    end

    channels = [];
    time_units = '';

    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            parts = strsplit(line, '\t');
            if numel(parts) >= 2
                % Channel
                channel = str2double(parts{1});
                if ~isnan(channel) && ~ismember(channel, channels)
                    channels(end+1) = channel;
                end

                % Time units
                if isempty(time_units)
                    time_str = parts{2};
                    % Regex for YYYY-MM-DDTHH:mm:ss.sssZ
                    if ~isempty(regexp(time_str, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$', 'once'))
                        time_units = 'datestamp';
                    else
                        time_units = 'numeric';
                    end
                end
            end
        end
    end

    fclose(fid);

    header.num_channels = numel(channels);
    header.time_units = time_units;
end
