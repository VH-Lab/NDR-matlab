% NDR_READER_INTAN_RHD - Reader class for Intan Technologies .RHD
% file
%
% This class reads data from Intan Technologies .RHD file format.
%
% Intan Technologies: http://intantech.com
%

classdef intan_rhd < ndr.reader.base
    
    properties
        
    end % properties
    
    methods
        
        function intan_rhd_obj = intan_rhd()
        % INTANREADER - Create a new Neuroscience Data Reader object
        %
        %  INTAN_RHD_OBJ = INTAN_RHD()
        %
        %  Creates a Neuroscience Data Reader object of the Intan
        %  Technologies .RHD file format.
        %
        end % ndr.reader.intan_rhd
        
        function ec = epochclock(intan_rhd_obj, epochstreams, epoch_select)
        % EPOCHCLOCK - Return the beginning and end epoch times for an
        % epoch
        %
        %  EC = EPOCHCLOCK(INTAN_RHD_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
        %
        %  Return the beginning (t0) and end (t1) times of the epoch
        %  EPOCH_NUMBER in the same units as the ndr.time.clocktype objects
        %  returned by EPOCH_NUMBER.
        %
        %  The abstract class always return {[NaN NaN]}.
        %
        %  See also: ndr.time.clocktype, EPOCHCLOCK
        %
            [filename,parentdir,isdirectory] = intan_rhd_obj.filenamefromepochfiles(epochfiles);
            header = ndr.format.intan.read_Intan_RHD2000_header(filename);
            
            if ~isdirectory,
                [blockinfo, bytes_per_block, bytes_present, num_data_blocks] = ndr.ndr.intan.Intan_RHD2000_blockinfo(filename, header);
                total_samples = 60 * num_data_blocks;
            else,
                finfo = dir([parentdir filesep 'time.dat']);
                if isempty(finfo),
                    error(['File time.dat necessary in directory ' parentdir ' but it was not found.']);
                end;
                total_samples = finfo.bytes / 4;
            end;
            
            total_time = total_samples / header.frequency_parameters.amplifier_sample_rate; % in seconds
            t0 = 0;
            t1 = total_time-1/header.frequency_parameters.amplifier_sample_rate;
            
            ec = {[t0 t1]};
                % developer note: in the Intan acquisition software, one can define a time offset; right now we aren't considering that
        end % ndr.reader.epochclock
        
        function channels = getchannelsepoch(intan_rhd_obj, epochstreams, epoch_select)
        % GETCHANNELS - List the channels that are available on this Intan
        % device for a given set of files
        %
        %  CHANNELS = GETCHANNELSEPOCH(INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
        %
        %  Returns the channel list of acquired channels in this epoch.
        %
        % CHANNELS is a structure list of all channels with fields:
        % ---------------------------------------------------------
        % 'name'             | The name of the channel (e.g., 'ai1')
        % 'type'             | The type of data store in the channel
        %                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
        %
            channels = vlt.data.emptystruct('name','type');
            
            intan_channel_types = {
                'amplifier_channels'
                'aux_input_channels'
                'board_dig_in_channels'
                'board_dig_out_channels'};
            
            multifunctiondaq_channel_types = ndr.system.mfdaq.mfdaq_channeltypes;
            
            % open RHD files, and examine the headers for all channels present
            %   for any new channel that hasn't been identified before,
            %   add it to the list
            
            filename = intan_rhd_obj.filenamefromepochfiles(epochfiles);
            header = ndr.format.intan.read_Intan_RHD2000_header(filename);
            
            for k=1:length(intan_channel_types)
                if isfield(header,intan_channel_types{k}),
                    channel_type_entry = intan_rhd_obj.intanheadertype2mfdaqchanneltype(...
                        intan_channel_types{k});
                    channel = getfield(header, intan_channel_types{k});
                    num = numel(channel); % number of channels with specific type
                    for p=1:numel(channel),
                        newchannel.type = channel_type_entry;
                        newchannel.name = intan_rhd_obj.intanname2mfdaqname(...
                            intan_rhd_obj,...
                            channel_type_entry,...
                            channel(p).native_channel_name);
                        channels(end+1) = newchannel;
                    end
                end
            end
        end % ndr.reader.getchannelsepoch
        
        function data = readchannels_epochsamples(intan_rhd_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
        % READCHANNELS_EPOCHSAMPLES - Read the data based on specified channels
        %
        %  DATA = READCHANNELS_EPOCHSAMPLES(INTANREADER_OBJ, CHANNELTYPE, CHANNEL, EPOCH, S0, S1)
        %
        %  CHANNELTYPE is the type of channel to read (cell array of
        %  strings, one per channel).
        %
        %  CHANNEL is a vector of the channel numbers to read, beginning
        %  from 1.
        %
        %  EPOCH is the epoch number to read from.
        %
        %  DATA will have one column per channel.
        %
            [filename,parentdir,isdirectory] = intan_rhd_obj.filenamefromepochfiles(epochfiles);
            
            uniquechannel = unique(channeltype);
            if numel(uniquechannel)~=1,
                error(['Only one type of channel may be read per function call at present.']);
            end
            intanchanneltype = intan_rhd_obj.mfdaqchanneltype2intanchanneltype(uniquechannel{1});
            
            sr = intan_rhd_obj.samplerate(epochfiles, channeltype, channel);
            sr_unique = unique(sr); % get all sample rates
            if numel(sr_unique)~=1,
                error(['Do not know how to handle different sampling rates across channels.']);
            end;
            
            sr = sr_unique;
            
            t0 = (s0-1)/sr;
            t1 = (s1-1)/sr;
            
            if strcmp(intanchanneltype,'time'),
                channel = 1; % time only has 1 channel in Intan RHD
            end;
            
            if ~isdirectory,
                data = ndr.format.intan.read_Intan_RHD2000_datafile(filename,'',intanchanneltype,channel,t0,t1);
            else,
                data = ndr.format.intan.read_Intan_RHD2000_directory(parentdir,'',intanchanneltype,channel,t0,t1);
            end;
        end % ndr.reader.readchannels_epochsamples
        
        function [data] = readevents_epochsamples(intan_rhd_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
        % READEVENTS_EPOCHSAMPLES - Read events, markers, and digital
        % events of specified channels for a specified epoch
        %
        %  [DATA] = READEVENTS_EPOCHSAMPLES(INTANREADER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
        %
        %  CHANNLETYPE is the type of channel to read
        %  ('event','marker','dep','dimp','dimn', etc.). It must be a cell
        %  array for strings.
        %
        %  CHANNEL is a vector with the identity of the channel(s) to be
        %  read.
        %
        %  EPOCH is the epoch number of epochID.
        %
        %  DATA is a two-column vector; the first column has the time of
        %  the event. The second column indicates the marker code. In the
        %  case of 'events', this is just 1. If more than one channel is
        %  requested, DATA is returned as a cell array, one entry per
        %  channel.
        %
            if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
                data = {};
                for i=1:numel(channel),
                    % optimization speed opportunity
                    srd = intan_rhd_obj.samplerate(epochfiles,{'di'},channel(i));
                    s0d = 1+round(srd*t0);
                    s1d = 1+round(srd*t1);
                    data_here = intan_rhd_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
                    time_here = intan_rhd_obj.readchannels_epochsamples(repmate({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
                    if any(strcmp(channeltype{i},{'dep','dimp'})), % look for 0 to 1 transitions
                        transitions_on_samples = find((data_here(1:end-1)==0) & (data_here(2:end)==1));
                        if strcmp(channeltype{i},'dimp'),
                            transitions_off_samples = 1+ find((data_here(1:end-1)==1) & (data_here(2:end)==0));
                        else,
                            transitions_off_samples = [];
                        end;
                    elseif any(strcmp(channeltype{i},{'den','dimn'})), % look for 1 to 0 transitions
                        transitions_on_samples = ginf((data_here(1:end-1)==1) & (data_here(2:end)==0));
                        if strcmp(channeltype{i},'dimp'),
                            transitions_off_samples = 1+ find((data_here(1:end-1)==0) & (data_here(2:end)==1));
                        else,
                            transitions_off_samples = [];
                        end;
                    end;
                    data{i} = [[vlt.data.colvec(time_here(transitions_on_samples)); vlt.data.colvec(time_here(transitions_off_samples))] ...
                        [ones(numel(transitions_on_samples),1); -ones(numel(transitions_off_samples),1)]];
                    if ~isempty(transitions_off_samples),
                        [dummy,order] = sort(data{i}(:,1));
                        data{i} = data{i}(order,:); % sort by on/off
                    end;
                end;
                
                if numel(channel)==1,
                    data = data{1};
                end;
            else,
                data = intan_rhd_obj.readevents_epochsamples_native(channeltype, ...
                    channel, epochfiles, t0, t1); % abstract class
            end;
        end % ndr.reader.readevents_epochsamples
        
        function sr = samplerate(intan_rhd_obj, epochstreams, epoch_select, channeltype, channel)
        % SAMPLERATE - Get the sample rate for specific channel
        %
        %  SR = SAMPLEREADER(INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
        %
        %  SR is an array of sample rates from the specified channels.
        %
        %  CHANNELTYPE can be either a string or a cell array of strings
        %  the same length as the vector CHANNEL.
        %  If CHANNELTYPE is a single string, then it is assumed that that
        %  CHANNELTYPE applies to every entry of CHANNEL.
        %
            sr = [];
            filename = intan_rhd_obj.filenamefromepochfiles(epochfiles);
            
            head = ndr.format.intan.read_Intan_RHD2000_header(filename);
            for i=1:numel(channel),
                channeltype_here = vlt.data.celloritem(channeltype,i);
                freq_fieldname = intan_rhd_obj.mfdaqchanneltype2intanfreqheader(channeltype_here);
                sr(i) = getfield(head.frequency_parameters,freq_fieldname);
            end
        end % ndr.reader.samplerate
        
        function [filename, parentdir, isdirectory] = filenamefromepochfiles(intan_rhd_obj, filename_array)
        % FILENAMEFROMEPOCHFILES - Return the file name that corresponds to the .RHD file, or directory in case of directory
        %
        %  [FILENAME, PARENTDIR, ISDIRECTORY] = FILENAMEFROMEPOCHFILES(NDR_NDRREADER_INTANREADER_OBJ, FILENAME_ARRAY)
        %
        %  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
        %  one is an RHD data file. If the 1-file-per-channel mode is used, then PARENTDIR is the name of the directory
        %  that holds the data files and ISDIRECTORY is 1.
        %
            s1 = ['.*/.rhd\>']; % equivalent of *.ext on the command line
            [tf, matchstring, substring] = vlt.string.strcmp_substitution(s1,filename_array,'UseSubstituteString',0);
            parentdir = '';
            isdirectory = 0;
            
            index = find(tf);
            if numel(index)>1,
                error(['Need only 1 .rhd file per epoch.']);
            elseif numel(index)==0,
                error(['Need 1 .rhd file per epoch.']);
            else,
                filename = filename_array{index};
                [parentdir, fname, ext] = fileparts(filename);
                if strcmp(fname,'info'),
                    s2 = ['time\.dat\>']; % equivalent of *.ext on the command line
                    tf2 = vlt.string.strcmp_substitution(s2,filename_array,'UseSubstituteString',0);
                    if any(tf),
                        % we will call it a directory
                        isdirectory = 1;
                    end;
                end;
            end
        end % ndr.reader.filenamefromepochfiles
        
    end % methods
    
    methods (Static) % helper functions
        
        function intanchanheadertype = mfdaqchanneltype2intanheadertype(channeltype)
        % MFDAQCHANNELTYPE@INTANHEADERTYPE - Convert between the ndr.ndr.reader.mfdaq channel types and Intan headers
        %
        %  INTANCHANHEADERTYPE = MFDAQCHANNELTYPE2INTANHEADERTYPE(CHANNELTYPE)
        %
        %  Given a standard ndr.ndr.reader.mfdaq channel type, returns the name of the type as
        %  indicated in Intan header files.
        %
            switch (channeltype),
                case {'analog_in','ai'},
                    intanchanheadertype = 'amplifier_channels';
                case {'digital_in','di'},
                    intanchanheadertype = 'board_dig_in_channels';
                case {'digital_out','do'},
                    intanchanheadertype = 'board_dig_out_channels';
                case {'auxiliary','aux','ax','auxiliary_in','auxiliary_input'},
                    intanchanheadertype = 'aux_input_channels';
                otherwise,
                    error(['Could not convert channeltype ' channeltype '.']);
            end;
        end % ndr.reader.mfdaqchanneltype2intanheadertype
        
        function channeltype = intanheadertype2mfdaqchanneltype(intanchanneltype)
        % INTANHEADERTYPE2MFDAQCHANNELTYPE - Convert between Intan headers and the ndr.ndr.reader.mfdaq channel types
        %
        %  CHANNELTYPE = INTANHEADERTYPE2MFDAQCHANNELTYPE(INTANCHANNELTYPE)
        %
        %  Given an Intan header file type, returns the standard ndi.ndr.reader.mfdaq channel type.
        %
            switch (intanchanneltype)
                case {'amplifier_channels'},
                    channeltype = 'analog_in';
                case {'board_dig_in_channels'},
                    channeltype = 'digital_in';
                case {'board_dig_out_channels'},
                    channeltype = 'digital_out';
                case {'aux_input_channels'},
                    channeltype = 'auxiliary_in';
                otherwise,
                    error(['Could not convert channeltype ' intanchanneltype '.']);
            end;
        end % ndr.reader.intanheadertype2mfdaqchanneltype
        
        function intanchanneltype = mfdaqchanneltype2intanchanneltype(channeltype)
        % MFDAQCHANNELTYPE2INTANCHANNELTYPE - Convert the channel type from generic format of multifuncdaqchannel
        %                                       to the specific Intan channel type
        %
        %  INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
        %
        %  The intanchanneltype is a string of the specific channel type for Intan.
        %
            switch channeltype,
                case {'analog_in','ai'},
                    intanchanneltype = 'amp';
                case {'digital_in','di'},
                    intanchanneltype = 'din';
                case {'digital_out','do'},
                    intanchanneltype = 'dout';
                case {'time','timestamp'},
                    intanchanneltype = 'time';
                case {'auxiliary','aux','auxiliary_input','auxiliary_in'},
                    intanchanneltype = 'aux';
                otherwise,
                    error(['Do not know how to convert channel type ' channeltype '.']);
            end;
        end % ndr.reader.mfdaqchanneltype2intanchanneltype
        
        function [channame] = intanname2mfdaqname(intan_rhd_obj, type, name)
        % INTANNAME2MFDAQNAME - Converts a channel name from Intan native format to ndr.ndr.reader.mfdaq format
        %
        %  [CHANNAME] = INTANNAME2MFDAQNAME(NDR_NDRREADER_INTANREADER_OBJ, TYPE, NAME)
        %
        %  Given an Intan native channel name (e.g., 'A-000') in NAME and an
        %  ndr.ndr.reader.mfdaq channel type string (see NDI_DEVICE_MFDAQ), this function
        %  produces an ndr.ndr.reader.mfdaq channel name (e.g., 'ai1').
        %
            sep = find(name=='-');
            chan_intan = str2num(name(sep+1:end));
            chan = chan_intan + 1; % Intan numbers from 0
            channame = [ndr.system.mfdaq.mfdaq_prefix(type) int2str(chan)];
        end % ndr.reader.intanname2mfdaqname
        
        function headername = mfdaqchanneltype2intanfreqheader(channeltype)
        % MFDAQCHANNELTYPE2INTANFREQHEADER - Return header name with frequency information for channel type
        %
        %  HEADERNAME = MFDAQCHANNELTYPE2INTANFREQHEADER(CHANNELTYPE)
        %
        %  Given an ndr.ndr.mfdaq channel type string, this function returns the associated fieldname.
        %
            switch channeltype,
                case {'analog_in','ai'},
                    headername = 'amplifier_sample_rate';
                case {'digital_in','di'},
                    headername = 'board_dig_in_sample_rate';
                case {'time','timestamp'},
                    headername = 'amplifier_sample_rate';
                case{'auxiliary','aux'},
                    headername = 'aux_input_sample_rate';
                otherwise,
                    error(['Do not know frequency header for channel type ' channeltype '.']);
            end;
        end % ndr.reader.mfdaqchanneltype2intanfreqheader
        
    end % methods (Static)
    
end % classdef
