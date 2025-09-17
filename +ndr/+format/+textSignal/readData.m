function [D, T] = readData(filename, channels, t0, t1, varargin)
% READDATA - Read data from an NDR text signal file
%
% [D, T] = READDATA(FILENAME, CHANNELS, T0, T1, ...)
%
% Reads data from an NDR text signal file.
%
% Arguments:
%   FILENAME - The name of the file to read.
%   CHANNELS - A vector of channel numbers to read.
%   T0, T1 - The start and end times of the data to read. Use -inf for T0
%            to start from the beginning of the file, and inf for T1 to read
%            to the end of the file.
%
% Optional name-value pairs:
%   'dT', value - Resample the data with a time step of 'value'.
%   'timestamps', vector - Return the data evaluated at the given timestamps.
%
% Returns:
%   D - A cell array of data vectors, one for each channel.
%   T - A vector of timestamps, either numeric or datetime.
%

    % Input parser
    p = inputParser;
    addParameter(p, 'dT', NaN, @isnumeric);
    addParameter(p, 'timestamps', [], @isnumeric);
    parse(p, varargin{:});
    dT = p.Results.dT;
    timestamps = p.Results.timestamps;

    % Read header to determine time units
    header = ndr.format.textSignal.readHeader(filename);

    % Read the file and store events
    [events, file_t_start, file_t_end] = read_and_sort_events(filename, header.time_units);

    % Set t0 and t1 if they are infinite
    if isinf(t0) && t0 < 0
        t0 = file_t_start;
    end
    if isinf(t1) && t1 > 0
        t1 = file_t_end;
    end

    % Generate time vector T
    if ~isnan(dT)
        T = t0:dT:t1;
    elseif ~isempty(timestamps)
        T = timestamps;
    else
        % Collect all unique timestamps from the requested channels within the time range
        all_times = [t0, t1];
        for i = 1:numel(channels)
            ch = channels(i);
            if isfield(events, ['ch' num2str(ch)])
                ch_events = events.(['ch' num2str(ch)]);
                for j = 1:numel(ch_events)
                    if ch_events(j).time >= t0 && ch_events(j).time <= t1
                        all_times(end+1) = ch_events(j).time;
                    end
                    if strcmp(ch_events(j).command, 'RAMP')
                         if ch_events(j).endtime >= t0 && ch_events(j).endtime <=t1
                            all_times(end+1) = ch_events(j).endtime;
                         end
                    end
                end
            end
        end
        T = unique(all_times);
        T = T(T>=t0 & T<=t1);
    end

    % Evaluate the signal for each channel
    D = cell(1, numel(channels));
    for i = 1:numel(channels)
        ch = channels(i);
        D{i} = zeros(1, numel(T));
        if isfield(events, ['ch' num2str(ch)])
            ch_events = events.(['ch' num2str(ch)]);
            for j = 1:numel(T)
                t = T(j);
                % Find the last event before or at time t
                last_event_idx = -1;
                for k = 1:numel(ch_events)
                    if ch_events(k).time <= t
                        last_event_idx = k;
                    else
                        break;
                    end
                end

                if last_event_idx ~= -1
                    event = ch_events(last_event_idx);
                    if strcmpi(event.command, 'SET')
                        D{i}(j) = event.value1;
                    elseif strcmpi(event.command, 'RAMP')
                        if t >= event.time && t <= event.endtime
                            if (event.endtime - event.time) > 0
                                fraction = (t - event.time) / (event.endtime - event.time);
                                D{i}(j) = event.value1 + fraction * (event.value2 - event.value1);
                            else % endtime == time
                                D{i}(j) = event.value2;
                            end
                        else % Past the ramp
                            D{i}(j) = event.value2;
                        end
                    elseif strcmpi(event.command, 'NONE')
                        prev_val = 0; % Default to 0 if no prior event
                        if last_event_idx > 1
                            for k=last_event_idx-1:-1:1
                               prev_event = ch_events(k);
                               if ~strcmpi(prev_event.command,'NONE')
                                   if strcmpi(prev_event.command,'SET')
                                       prev_val = prev_event.value1;
                                   elseif strcmpi(prev_event.command,'RAMP')
                                       prev_val = prev_event.value2;
                                   end
                                   break;
                               end
                            end
                        end
                        D{i}(j) = prev_val;
                    end
                end
            end
        end
    end

    if strcmp(header.time_units, 'datestamp')
        T = datetime(T, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    end

end

function [events, file_t_start, file_t_end] = read_and_sort_events(filename, time_units)
    fid = fopen(filename, 'r');
    if fid == -1
        error(['Could not open file ' filename]);
    end

    raw_events = struct();
    file_times = [];

    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            parts = strsplit(line, '\t');

            channel = str2double(parts{1});

            if strcmp(time_units, 'datestamp')
                time = posixtime(datetime(parts{2}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC'));
            else
                time = str2double(parts{2});
            end
            file_times(end+1) = time;

            command = parts{3};

            event = struct('time', time, 'command', command);

            if strcmp(command, 'Set')
                event.value1 = str2double(parts{4});
            elseif strcmp(command, 'RAMP')
                event.value1 = str2double(parts{4});
                event.value2 = str2double(parts{5});
                if strcmp(time_units, 'datestamp')
                    event.endtime = posixtime(datetime(parts{6}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC'));
                else
                    event.endtime = str2double(parts{6});
                end
                file_times(end+1) = event.endtime;
            end

            ch_field = ['ch' num2str(channel)];
            if ~isfield(raw_events, ch_field)
                raw_events.(ch_field) = {};
            end
            raw_events.(ch_field){end+1} = event;
        end
    end

    fclose(fid);

    % Now sort the events
    events = struct();
    fields = fieldnames(raw_events);
    for i = 1:numel(fields)
        ch_field = fields{i};
        ch_events_cell = raw_events.(ch_field);
        ch_events_struct = [ch_events_cell{:}];
        [~, sort_idx] = sort([ch_events_struct.time]);
        events.(ch_field) = ch_events_struct(sort_idx);
    end

    if isempty(file_times)
        file_t_start = -inf;
        file_t_end = inf;
    else
        file_t_start = min(file_times);
        file_t_end = max(file_times);
    end
end
