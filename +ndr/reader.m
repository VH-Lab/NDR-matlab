classdef reader

    properties (GetAccess=public, SetAccess=protected)
        ndr_reader_base      % The specific ndr.reader.base object that actually reads the files
    end

    methods
        function ndr_reader_obj = reader(ndr_reader_type)
            %READER - Create a new Neuroscience Data Reader (NDR) object.
            %
            %   NDR_READER_OBJ = ndr.reader(NDR_READER_TYPE)
            %
            %   Creates a Neuroscience Data Reader object capable of reading a 
            %   specific data format identified by NDR_READER_TYPE. This object 
            %   acts as a high-level interface, utilizing an underlying specific 
            %   reader object (subclass of ndr.reader.base) to handle the details
            %   of the file format.
            %
            %   Inputs:
            %       NDR_READER_TYPE - A string specifying the data format to read.
            %                         Valid types are defined in 
            %                         'ndr_reader_types.json' and can include
            %                         short names (e.g., 'rhd', 'smr', 'rec', 'abf', 
            %                         'sev', 'neo', 'whitematter') or longer aliases.
            %
            %   Outputs:
            %       NDR_READER_OBJ  - The created ndr.reader object handle.
            %
            %   Example:
            %       % Create a reader for Intan RHD files
            %       intan_reader = ndr.reader('intan'); 
            %
            %       % Create a reader for SpikeGadgets REC files
            %       rec_reader = ndr.reader('rec');
            %
            % See also: ndr.reader.base, ndr.fun.ndrresource, ndr.known_readers
            %
                j = ndr.fun.ndrresource('ndr_reader_types.json');
                match = 0;
                for i=1:numel(j),
                    if any(strcmpi(ndr_reader_type, j(i).type)),
                        match = i;
                        break;
                    end
                end
                if match==0,
                    error(['Do not know how to make a reader of type ''' ndr_reader_type '''.']);
                end
                ndr_reader_obj.ndr_reader_base = feval(j(match).classname);
        end % reader()

        function [data, time] = read(ndr_reader_obj, epochstreams, channelstring, varargin)
            %READ - Read data or time information from specified channels and epoch.
            %
            %   [DATA, TIME] = READ(NDR_READER_OBJ, EPOCHSTREAMS, CHANNELSTRING, Name, Value, ...)
            %
            %   Reads data and corresponding time information from the specified 
            %   channels within a given epoch. This function determines the 
            %   appropriate underlying read method (e.g., readchannels_epochsamples 
            %   or readevents_epochsamples) based on the channel type derived 
            %   from CHANNELSTRING.
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       EPOCHSTREAMS   - A cell array of full path file names or remote
            %                        access streams that comprise the epoch of data.
            %       CHANNELSTRING  - Specifies the channels to read. Format depends
            %                        on the underlying reader:
            %                          - Standard NDR format: A string combining prefixes 
            %                            and numbers (e.g., 'ai1-3,5', 'ai1+di1'). 
            %                            See ndr.string.channelstring2channels.
            %                          - Intan Reader: Accepts standard NDR format OR 
            %                            Intan native names (e.g., 'A000+A001').
            %                          - Neo Reader: Expects a cell array of native 
            %                            channel names (e.g., {'A-000', 'A-001'}).
            %
            %   Name-Value Pair Arguments:
            %       't0' (-Inf)           : Start time for reading (seconds). -Inf reads 
            %                               from the earliest available sample.
            %       't1' (Inf)            : Stop time for reading (seconds). Inf reads 
            %                               to the last available sample.
            %       'epoch_select' (1)    : The epoch index within EPOCHSTREAMS to read.
            %                               Usually 1, as most formats have one epoch per file.
            %       'useSamples' (0)      : If 1, interpret 's0' and 's1' as sample 
            %                               numbers instead of times. (logical).
            %       's0' (NaN)            : Start sample number (1-based) if useSamples is 1.
            %       's1' (NaN)            : Stop sample number (1-based) if useSamples is 1.
            %
            %   Outputs:
            %       DATA - Data read from the specified channels. Format depends on 
            %              channel type:
            %                - Regularly sampled (e.g., 'ai'): N x C matrix (double), 
            %                  where N is samples, C is channels.
            %                - Events/Markers: N x C matrix or cell array, format depends 
            %                  on event type (see readevents_epochsamples).
            %       TIME - N x 1 vector (double) of time points (seconds) corresponding 
            %              to the samples/events in DATA. For events/markers, format
            %              matches DATA (N x C matrix or cell array).
            %
            %   Example:
            %       r = ndr.reader('intan');
            %       filenames = {'/path/to/mydata.rhd'};
            %       % Read analog input channels 1 and 2 from time 10s to 15s
            %       [analogData, timeVec] = r.read(filenames, 'ai1-2', 't0', 10, 't1', 15);
            %       % Read samples 1000 to 2000 for channel 'A000' (Intan specific)
            %       [sampleData, sampleTime] = r.read(filenames, 'A000', 'useSamples', 1, 's0', 1000, 's1', 2000); 
            %
            % See also: ndr.reader/readchannels_epochsamples, ndr.reader/readevents_epochsamples, 
            %           ndr.string.channelstring2channels, ndr.reader.base/daqchannels2internalchannels
            %
                t0 = -Inf;
                t1 = Inf;
                epoch_select = 1;
                useSamples = 0;
                s0 = NaN;
                s1 = NaN;

                ndr.data.assign(varargin{:});

                is_neo = strcmp(class(ndr_reader_obj.ndr_reader_base), 'ndr.reader.neo');

                if is_neo,
                    channelstruct = daqchannels2internalchannels(ndr_reader_obj.ndr_reader_base, {}, channelstring, epochstreams, epoch_select);
                else,
                    [channelprefix, channelnumber] = ndr.string.channelstring2channels(channelstring);
                    channelstruct = daqchannels2internalchannels(ndr_reader_obj.ndr_reader_base, channelprefix, channelnumber, epochstreams, epoch_select);
                end

                [b, errormsg] = ndr_reader_obj.ndr_reader_base.canbereadtogether(channelstruct);

                if b,
                    switch (channelstruct(1).ndr_type),
                        % readchannels_epochsamples
                        case {'analog_input','analog_output','analog_in','analog_out','ai','ao'},
                            if ~useSamples, % must compute the samples to be read
                                s0 = round(1+t0*channelstruct(1).samplerate);
                                s1 = round(1+t1*channelstruct(1).samplerate);
                            end

                            if is_neo,
                                channels = channelstring;
                            else,
                                channels = [channelstruct.internal_number];
                            end

                            data = ndr_reader_obj.readchannels_epochsamples(channelstruct(1).internal_type, channels, epochstreams, epoch_select, s0, s1);
                            time = ndr_reader_obj.readchannels_epochsamples('time', channels, epochstreams, epoch_select, s0, s1);
                        % readevents_epochsamples
                        otherwise,
                            if is_neo,
                                channels = channelstring;
                            else,
                                channels = channelstruct.internal_number;
                            end

                            [data, time] = ndr_reader_obj.readevents_epochsamples({channelstruct.internal_type}, channels, epochstreams, epoch_select, t0, t1);
                    end
                else, % we can't do it, report an error
                    error(['Specified channels cannot be read in a single function call. Please split channel reading by similar channel types. ' errormsg]);
                end
        end % read() 

        function ec = epochclock(ndr_reader_obj, epochstreams, epoch_select)
            %EPOCHCLOCK - Return the ndr.time.clocktype objects for an epoch.
            %
            %   EC = EPOCHCLOCK(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns the clock types available for the specified epoch as a 
            %   cell array of ndr.time.clocktype objects (or subclasses). 
            %   This function calls the corresponding method of the underlying 
            %   specific reader object (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index (default: 1).
            %
            %   Outputs:
            %       EC             - Cell array of ndr.time.clocktype objects.
            %
            % See also: ndr.time.clocktype, ndr.reader.base/epochclock
            %   
                if nargin<3,
                    epoch_select = 1;
                end
                ec = ndr_reader_obj.ndr_reader_base.epochclock(epochstreams, epoch_select);
        end % epochclock

        function t0t1 = t0_t1(ndr_reader_obj, epochstreams, epoch_select)
            %T0_T1 - Return the beginning and end times for an epoch.
            %
            %   T0T1 = T0_T1(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns the beginning (t0) and end (t1) times (in seconds) of 
            %   the epoch defined by EPOCHSTREAMS and EPOCH_SELECT, relative to 
            %   the clock type specified by EPOCHCLOCK. This function calls the 
            %   corresponding method of the underlying specific reader object 
            %   (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index (default: 1).
            %
            %   Outputs:
            %       T0T1           - Cell array containing a 1x2 vector [t0 t1] 
            %                        for each clock type returned by EPOCHCLOCK.
            %
            % See also: ndr.reader/epochclock, ndr.reader.base/t0_t1
            %
                if nargin<3,
                    epoch_select = 1;
                end
                t0t1 = ndr_reader_obj.ndr_reader_base.t0_t1(epochstreams, epoch_select);
        end % t0_t1()

        function channels = getchannelsepoch(ndr_reader_obj, epochstreams, epoch_select)
            %GETCHANNELSEPOCH - List the channels available for a given epoch.
            %
            %   CHANNELS = GETCHANNELSEPOCH(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
            %
            %   Returns a structure list of all channels available in the specified epoch.
            %   This function calls the corresponding method of the underlying 
            %   specific reader object (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index (default: 1).
            %
            %   Outputs:
            %       CHANNELS       - Structure array with fields:
            %         'name'         : Channel name (e.g., 'ai1', 't1').
            %         'type'         : Channel type (e.g., 'analog_in', 'time').
            %         'time_channel' : (Optional) Index of the associated time channel.
            %
            % See also: ndr.reader.base/getchannelsepoch
            %
                if nargin<3,
                    epoch_select = 1; % most devices have only a single epoch per file
                end
                channels = ndr_reader_obj.ndr_reader_base.getchannelsepoch(epochstreams, epoch_select);
        end % getchannelsepoch()

        function [datatype,p,datasize] = underlying_datatype(ndr_reader_obj, epochstreams, epoch_select, channeltype, channel)
            %UNDERLYING_DATATYPE - Get the native data type for specified channels.
            %
            %   [DATATYPE, P, DATASIZE] = UNDERLYING_DATATYPE(NDR_READER_OBJ, ...
            %       EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns information about the underlying data type as stored in the file
            %   for the specified channels. This function calls the corresponding 
            %   method of the underlying specific reader object (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index.
            %       CHANNELTYPE    - String specifying the type of channels (e.g., 'ai').
            %       CHANNEL        - Vector of channel numbers.
            %
            %   Outputs:
            %       DATATYPE       - String representing the native data type (e.g., 
            %                        'int16', 'float32'). Suitable for FREAD/FWRITE.
            %       P              - Polynomial coefficients [offset scale] for converting 
            %                        raw data to the units returned by readchannels. 
            %                        Typically [0 1] if raw data is returned.
            %       DATASIZE       - Size of the data type in bits (e.g., 16, 32, 64).
            %
            % See also: ndr.reader.base/underlying_datatype, fread, fwrite
            %
                [datatype,p,datasize] = ndr_reader_obj.ndr_reader_base.underlying_datatype(epochstreams, epoch_select, channeltype, channel);
        end % underlying_datatype()

        function data = readchannels_epochsamples(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            %READCHANNELS_EPOCHSAMPLES - Read regularly sampled data channels.
            %
            %   DATA = READCHANNELS_EPOCHSAMPLES(NDR_READER_OBJ, CHANNELTYPE, ...
            %       CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, S0, S1)
            %
            %   Reads data for regularly sampled channels (e.g., analog, digital) 
            %   between sample S0 and sample S1 (inclusive, 1-based). This function 
            %   calls the corresponding method of the underlying specific reader 
            %   object (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       CHANNELTYPE    - String specifying the type (e.g., 'ai', 'di', 'time').
            %       CHANNEL        - Vector of channel numbers.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index.
            %       S0             - Start sample number (1-based).
            %       S1             - End sample number (1-based).
            %
            %   Outputs:
            %       DATA           - N x C matrix of data (double or native type), or 
            %                        N x 1 vector for 'time'.
            %
            % See also: ndr.reader.base/readchannels_epochsamples
            %
                data = ndr_reader_obj.ndr_reader_base.readchannels_epochsamples(channeltype, channel, epochstreams, epoch_select, s0, s1);
        end % readchannels_epochsamples()

        function [timestamps, data] = readevents_epochsamples(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
            %READEVENTS_EPOCHSAMPLES - Read event/marker data or derive events from digital channels.
            %
            %   [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES(NDR_READER_OBJ, ...
            %       CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
            %
            %   Reads event or marker data occurring between time T0 and T1 (seconds). 
            %   This function handles both reading native event/marker channel types 
            %   (like 'event', 'marker', 'text') by calling 
            %   `readevents_epochsamples_native`, and deriving events from digital 
            %   channels (types 'dep', 'den', 'dimp', 'dimn') by reading the 
            %   digital data and detecting transitions.
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       CHANNELTYPE    - Cell array of strings specifying the type for each 
            %                        channel in CHANNEL. Valid types include:
            %                          'event': Timestamps of occurrences (data is 1).
            %                          'marker': Timestamps and associated marker codes (double).
            %                          'text': Timestamps and associated text (cellstr).
            %                          'dep': Events at positive digital transitions (0->1).
            %                          'den': Events at negative digital transitions (1->0).
            %                          'dimp': Events at positive impulses (0->1->0).
            %                          'dimn': Events at negative impulses (1->0->1).
            %       CHANNEL        - Vector of channel numbers corresponding to CHANNELTYPE.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index.
            %       T0             - Start time (seconds).
            %       T1             - End time (seconds).
            %
            %   Outputs:
            %       TIMESTAMPS     - Timestamps of events/markers (seconds). Format matches DATA.
            %                        If 1 channel, N x 1 double vector.
            %                        If >1 channel, 1 x C cell array of N x 1 double vectors.
            %       DATA           - Data associated with events/markers. Format depends on type.
            %                        If 1 channel, N x D matrix or N x 1 cellstr.
            %                        If >1 channel, 1 x C cell array.
            %
            % See also: ndr.reader/readevents_epochsamples_native, ndr.reader.base/readevents_epochsamples_native
            %
                 % Step 1: check to see if the user is requesting a "native" type of event (event,marker,text) or a "derived" type of event
                 %       (like dep, den, dimp, dimn, which are derived from the data of sampled digital channels)
                 %       If the user does request a derived event type, then compute it
 
                if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
                    timestamps = {};
                    data = {};
                    for i=1:numel(channel),
                        % optimization speed opportunity
                        srd = ndr_reader_obj.samplerate(epochfiles,{'di'}, channel(i)); % Note: This assumes samplerate works with cell type
                        s0d = 1+round(srd*t0);
                        s1d = 1+round(srd*t1);
                        data_here = ndr_reader_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochstreams,epoch_select,s0d,s1d); % Pass epoch_select
                        time_here = ndr_reader_obj.readchannels_epochsamples(repmat({'time'},1,numel(channel(i))),channel(i),epochstreams,epoch_select,s0d,s1d); % Pass epoch_select
                        if any(strcmp(channeltype{i},{'dep','dimp'})), % look for 0 to 1 transitions
                            transitions_on_samples = find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
                            if strcmp(channeltype{i},'dimp'),
                                transitions_off_samples = 1+ find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
                            else
                                transitions_off_samples = [];
                            end
                        elseif any(strcmp(channeltype{i},{'den','dimn'})), % look for 1 to 0 transitions
                            transitions_on_samples = find( (data_here(1:end-1)==1) & (data_here(2:end) == 0));
                            if strcmp(channeltype{i},'dimp'), % Should be 'dimn' for neg impulse off? Check logic. Assuming 'dimn' means 0->1 is off.
                                transitions_off_samples = 1+ find( (data_here(1:end-1)==0) & (data_here(2:end) == 1));
                            else
                                transitions_off_samples = [];
                            end
                        end
                        timestamps{i} = [ndr.data.colvec(time_here(transitions_on_samples)); ndr.data.colvec(time_here(transitions_off_samples)) ]; 
                        data{i} = [ones(numel(transitions_on_samples),1); -ones(numel(transitions_off_samples),1) ];
                        if ~isempty(transitions_off_samples),
                            [~,order] = sort(timestamps{i}(:,1)); % Use ~ for unused output
                            timestamps{i} = timestamps{i}(order,:);
                            data{i} = data{i}(order,:); % sort by on/off
                        end
                    end

                    if numel(channel)==1,
                        timestamps = timestamps{1};
                        data = data{1};
                    end
                else
                    % if the user doesn't want a derived channel, we need to read it from the file natively (using the class's reader function)
                    [timestamps, data] = ndr_reader_obj.readevents_epochsamples_native(channeltype, ...
                        channel, epochstreams, epoch_select, t0, t1); % abstract class
                end
        end % readevents_epochsamples()

        function [timestamps, data] = readevents_epochsamples_native(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
            %READEVENTS_EPOCHSAMPLES_NATIVE - Read native event/marker channels.
            %
            %   [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(NDR_READER_OBJ, ...
            %       CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
            %
            %   Reads event or marker data directly as stored in the file format, 
            %   occurring between time T0 and T1 (seconds). This function calls the 
            %   corresponding method of the underlying specific reader object 
            %   (`ndr_reader_base`). It cannot handle derived event types 
            %   ('dep', 'den', 'dimp', 'dimn'); use `readevents_epochsamples` for those.
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       CHANNELTYPE    - Cell array of strings specifying the native type 
            %                        for each channel ('event', 'marker', 'text').
            %       CHANNEL        - Vector of channel numbers.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index.
            %       T0             - Start time (seconds).
            %       T1             - End time (seconds).
            %
            %   Outputs:
            %       TIMESTAMPS     - Timestamps of events/markers (seconds). Format matches DATA.
            %       DATA           - Data associated with events/markers. Format depends on type.
            %
            % See also: ndr.reader/readevents_epochsamples, ndr.reader.base/readevents_epochsamples_native
            %
                [timestamps,data] = ndr_reader_obj.ndr_reader_base.readevents_epochsamples_native(channeltype, channel, epochstreams, epoch_select, t0, t1);
        end % readevents_epochsamples_native()

        function sr = samplerate(ndr_reader_obj, epochstreams, epoch_select, channeltype, channel)
            %SAMPLERATE - Get the sample rate for specific regularly-sampled channels.
            %
            %   SR = SAMPLERATE(NDR_READER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            %   Returns the sampling rate(s) in Hz for the specified regularly-sampled 
            %   channels. This function calls the corresponding method of the 
            %   underlying specific reader object (`ndr_reader_base`).
            %
            %   Inputs:
            %       NDR_READER_OBJ - The ndr.reader object.
            %       CHANNELTYPE    - Cell array of strings specifying the channel type 
            %                        (e.g., {'ai','ai'}, {'di'}). Must be a regularly-sampled type.
            %       CHANNEL        - Vector of channel numbers.
            %       EPOCHSTREAMS   - Cell array of filenames for the epoch.
            %       EPOCH_SELECT   - The epoch index.
            %
            %   Outputs:
            %       SR             - Vector of sampling rates (Hz) corresponding to each 
            %                        channel requested. Returns NaN for channels that are 
            %                        not regularly sampled (e.g., events).
            %
            % See also: ndr.reader.base/samplerate
            %
                sr = ndr_reader_obj.ndr_reader_base.samplerate(epochstreams, epoch_select, channeltype, channel);
        end % samplerate()

        function t = samples2times(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, s)
            %SAMPLES2TIMES - convert sample numbers to time
            %
            %   T = SAMPLES2TIMES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, S)
            %
            %   Given sample numbers S, returns the time T of these samples.
            %
            %   This function calls the samples2times method of the ndr.reader.base object.
            %
            %   See also: ndr.reader.base/samples2times
            %
            t = ndr_reader_obj.ndr_reader_base.samples2times(channeltype, channel, epochstreams, epoch_select, s);
        end % samples2times()

        function s = times2samples(ndr_reader_obj, channeltype, channel, epochstreams, epoch_select, t)
            %TIMES2SAMPLES - convert time to sample numbers
            %
            %   S = TIMES2SAMPLES(NDR_READER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T)
            %
            %   Given sample times T, returns the sample numbers S of these samples.
            %
            %   This function calls the times2samples method of the ndr.reader.base object.
            %
            %   See also: ndr.reader.base/times2samples
            %
            s = ndr_reader_obj.ndr_reader_base.times2samples(channeltype, channel, epochstreams, epoch_select, t);
        end % times2samples()

    end % methods
end % classdef

