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
        
        function t0t1 = t0_t1(intan_rhd_obj, epochstreams, epoch_select)
        % EPOCHCLOCK - Return the beginning and end epoch times for an
        % epoch
        %
        %  T0T1 = T0_T1(INTAN_RHD_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
        %
        %  Return the beginning (t0) and end (t1) times of the epoch
        %  EPOCH_NUMBER in the same units as the ndr.time.clocktype objects
        %  returned by EPOCH_NUMBER.
        %
        %  The abstract class always return {[NaN NaN]}.
        %
        %  See also: ndr.time.clocktype, EPOCHCLOCK
        %
            [filename,parentdir,isdirectory] = intan_rhd_obj.filenamefromepochfiles(epochstreams);
            header = ndr.format.intan.read_Intan_RHD2000_header(filename);
            
            if ~isdirectory,
                [blockinfo, bytes_per_block, bytes_present, num_data_blocks] = ndr.format.intan.Intan_RHD2000_blockinfo(filename, header);
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
            
            t0t1 = {[t0 t1]};
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
            
            multifunctiondaq_channel_types = ndr.reader.base.mfdaq_channeltypes;
            
            % open .RHD files, and examine the headers for all channels present
            %   for any new channel that hasn't been identified before,
            %   add it to the list

            filename = intan_rhd_obj.filenamefromepochfiles(epochstreams);
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
        %  CHANNELTYPE is the type of channel to read (single text string,
        %  such as 'ai','analog_input','time')
        %
        %  CHANNEL is a vector of the channel numbers to read, beginning
        %  from 1.
        %
        %  EPOCH is the epoch number to read from.
        %
        %  DATA will have one column per channel.
        %
            [filename,parentdir,isdirectory] = intan_rhd_obj.filenamefromepochfiles(epochstreams);
            
            intanchanneltype = intan_rhd_obj.mfdaqchanneltype2intanchanneltype(channeltype);
            
            sr = intan_rhd_obj.samplerate(epochstreams, epoch_select, channeltype, channel);
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
        
        function sr = samplerate(intan_rhd_obj, epochstreams, epoch_select, channeltype, channel)
        % SAMPLERATE - Get the sample rate for specific channel
        %
        %  SR = SAMPLERATE(INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
        %
        %  SR is an array of sample rates from the specified channels.
        %
        %  CHANNELTYPE can be either a string or a cell array of strings
        %  the same length as the vector CHANNEL.
        %  If CHANNELTYPE is a single string, then it is assumed that that
        %  CHANNELTYPE applies to every entry of CHANNEL.
        %
        	if epoch_select~=1,
            	error(['Intan RHD files have 1 epoch per file.']);
        	end;
            sr = [];
            filename = intan_rhd_obj.filenamefromepochfiles(epochstreams);
            
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
        %  one is an .RHD data file. If the 1-file-per-channel mode is used, then PARENTDIR is the name of the directory
        %  that holds the data files and ISDIRECTORY is 1.
        %
            s1 = ['.*\.rhd\>']; % equivalent of *.ext on the command line
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
            channame = [ndr.reader.base.mfdaq_prefix(type) int2str(chan)];
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
        function [b,errormsg] = canbereadtogether(ndr_reader_base_obj, channelstruct)
			% CANBEREADTOGETHER - can the channels in a channel struct be read in a single function call?
			% 
			% [B,ERRORMSG] = CANBEREADTOGETHER(NDR_READER_BASE_OBJ, CHANNELSTRUCT)
			%
			% Returns 1 if the NDR_READER_BASE_OBJ can read all of the channels in
			% CHANNELSTRUCT with a single function call. If they cannot be read together,
			% a description is provided in ERRORMSG.
			%
			% In the abstract class, this returns 1 if all of the samplerate values are
			% the same and none are NaNs.
			%
			% CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.
			% ------------------------------------------------------------------------------
			%
				% in the abstract class, this returns 1 if all the samplerates are the same
				% and none are NaNs
				b  = 1;
				errormsg = '';

				sr = [channelstruct.samplerate];
				if ~all(isnan(sr)),
					% if all are not NaN, then none can be
					if any(isnan(sr)),
						b = 0;
						errormsg = ['All samplerates must either be the same number or they must all be NaN, indicating they are all not regularly sampled channels.'];
					else,
						sr_ = uniquetol(sr)
						if numel(sr_)~=1,
							b = 0;
							errormsg = ['All sample rates must be the same for all requested regularly-sampled channels for a single function call.'];
						end;
					end;
				end;

		end; % canbereadtogether()

		function channelstruct = daqchannels2internalchannels(ndr_reader_base_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_BASE_OBJ, ...
			%    CHANNELPREFIX, CHANNELNUMBERS, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Inputs:
			% For a set of CHANNELPREFIX (cell array of channel prefixes that describe channels for
			% this device) and CHANNELNUMBER (array of channel numbers, 1 for each entry in CHANNELPREFIX),
			% and for a given recording epoch (specified by EPOCHSTREAMS and EPOCH_SELECT), this function
			% returns a structure CHANNELSTRUCT describing the channel information that should be passed to
			% READCHANNELS_EPOCHSAMPLES or READEVENTS_EPOCHSAMPLES.
			%
			% EPOCHSTREAMS is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			% Output: CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% ------------------------------------------------------------------------------
			%
				% abstract class returns empty
				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type');
		end; % daqchannels2internalchannels
        
        function [b,errormsg] = canbereadtogether(ndr_reader_base_obj, channelstruct)
			% CANBEREADTOGETHER - can the channels in a channel struct be read in a single function call?
			% 
			% [B,ERRORMSG] = CANBEREADTOGETHER(NDR_READER_BASE_OBJ, CHANNELSTRUCT)
			%
			% Returns 1 if the NDR_READER_BASE_OBJ can read all of the channels in
			% CHANNELSTRUCT with a single function call. If they cannot be read together,
			% a description is provided in ERRORMSG.
			%
			% In the abstract class, this returns 1 if all of the samplerate values are
			% the same and none are NaNs.
			%
			% CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.
			% ------------------------------------------------------------------------------
			%
				% in the abstract class, this returns 1 if all the samplerates are the same
				% and none are NaNs
				b  = 1;
				errormsg = '';

				sr = [channelstruct.samplerate];
				if ~all(isnan(sr)),
					% if all are not NaN, then none can be
					if any(isnan(sr)),
						b = 0;
						errormsg = ['All samplerates must either be the same number or they must all be NaN, indicating they are all not regularly sampled channels.'];
					else,
						sr_ = uniquetol(sr)
						if numel(sr_)~=1,
							b = 0;
							errormsg = ['All sample rates must be the same for all requested regularly-sampled channels for a single function call.'];
						end;
					end;
				end;

		end; % canbereadtogether()

		function channelstruct = daqchannels2internalchannels(ndr_reader_base_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_BASE_OBJ, ...
			%    CHANNELPREFIX, CHANNELNUMBERS, EPOCHSTREAMS, EPOCH_SELECT)
			%
			% Inputs:
			% For a set of CHANNELPREFIX (cell array of channel prefixes that describe channels for
			% this device) and CHANNELNUMBER (array of channel numbers, 1 for each entry in CHANNELPREFIX),
			% and for a given recording epoch (specified by EPOCHSTREAMS and EPOCH_SELECT), this function
			% returns a structure CHANNELSTRUCT describing the channel information that should be passed to
			% READCHANNELS_EPOCHSAMPLES or READEVENTS_EPOCHSAMPLES.
			%
			% EPOCHSTREAMS is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			% Output: CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device.                 |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% ------------------------------------------------------------------------------
			%
				% abstract class returns empty
				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type');
		end; % daqchannels2internalchannels
        
    end % methods (Static)
    
end % classdef
