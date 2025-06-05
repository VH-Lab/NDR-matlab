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
		end % ndr.reader.intan_rhd.intan_rhd
			
		function channelstruct = daqchannels2internalchannels(intan_rhd_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - Convert a set of DAQ channel
			% prefixes and channel numbers to an internal structure to pass to
			% internal reading functions
			%
			%  CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(INTAN_RHD_OBJ, ...
			%     CHANNELPREFIX, CHANNELNUMBERS, EPOCHSTREAMS, EPOCH_SELECT)
			%
			%  Inputs:
			%  For a set of CHANNELPREFIX (cell array of channel prefixes that
			%  describe channels for this device) and CHANNELNUMBER (array of
			%  of channel numbers, 1 for each entry in CHANNELPREFIX), and for
			%  a given recording epoch (specified by EPOCHSTREAMS and
			%  EPOCH_SELECT), this function returns a structure CHANNELSTRUCT
			%  describing the channel information that should be passed to
			%  READCHANNELS_EPOCHSAMPLES or READEVENTS_EPOCHSAMPLES.
			%
			%  EPOCHSTREAMS is a cell array of full path file names or remote
			%  access streams that comprise the epoch of data.
			%
			%  EPOCH_SELECT allows one to choose which epoch in the file one
			%  wants to access, if the file(s) has more than epoch contained.
			%  For most devices, EPOCH_SELECT is always 1.
			%
			% Output: CHANNELSTRUCT is a structure with the following fields:
			% ------------------------------------------------------------------------------
			% | Parameter                   | Description                                  |
			% |-----------------------------|----------------------------------------------|
			% | internal_type               | Internal channel type; the type of channel as|
			% |                             |   it is known to the device. This is the type|
			% |                             |   that readepoch_samples takes               |
			% | internal_number             | Internal channel number, as known to device  |
			% | internal_channelname        | Internal channel name, as known to the device|
			% | ndr_type                    | The NDR type of channel; should be one of the|
			% |                             |   types returned by                          |
			% |                             |   ndr.reader.base.mfdaq_type                 |
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.                            |
			% ------------------------------------------------------------------------------
			%
			% Examples for Intan. Channels can be specified by either absolute reference
			% (for example, A-000 means the first channel in bank A) or in relative reference
			% (for example, ai1 means the first channel that was turned on; the one that appears
			% first in the header file).
			%
			% Example: 
			%   % absolute reference
			%   channelstruct_1 = daqchannels2internalchannels(intan_rhd_obj, 'A', 0, epochstreams, epoch_select)
			%   % channelstruct_1.internal_type = 'ai';
			%   % channelstruct_1.internal_number = 1; % assuming A-000 is the first channel acquired
			%   % channelstruct_1.internal_channelname = 'A-000'; 
			%   % channelstruct_1.ndr_type = 'ai'; % analog input
			%   % channelstruct_1.samplerate = 20000;
			%
			%   % relative reference
			%   channelstruct_2 = daqchannels2internalchannels(intan_rhd_obj, 'ai', 1, epochstreams, epoch_select)
			%   % channelstruct_2.internal_type = 'ai';
			%   % channelstruct_2.internal_number = 1; % we asked for the first internal/relative channel
			%   % channelstruct_2.internal_channelname = 'A-000'; % assuming A-000 is the first channel acquired 
			%   % channelstruct_2.ndr_type = 'ai'; % analog input
			%   % channelstruct_2.samplerate = 20000;
			%   
			%
				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type','samplerate');
			    
				filename = intan_rhd_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.intan.read_Intan_RHD2000_header(filename);
			    
				% make sure that the fields are in the correct order
				channelstruct_here.internal_type = [];
				channelstruct_here.internal_number = [];
				channelstruct_here.internal_channelname = [];
				channelstruct_here.ndr_type = [];
				channelstruct_here.samplerate = [];
			    
				for c=1:numel(channelnumber)
					[intan_type,absolute] = ndr.reader.intan_rhd.intananychannelname2intanchanneltype(channelprefix{c});
					channelstruct_here.internal_type = ndr.reader.intan_rhd.intanchanneltype2mfdaqchanneltype(intan_type);
					channelstruct_here.ndr_type = ndr.reader.intan_rhd.intanchanneltype2mfdaqchanneltype(intan_type);
					header_name = ndr.reader.intan_rhd.mfdaqchanneltype2intanheadertype(channelstruct_here.ndr_type);
					header_chunk = getfield(header,header_name);
					if ~absolute % relative reference
						channelstruct_here.internal_number = channelnumber;
						native_names = {header_chunk.native_channel_name};
						channelstruct_here.internal_channelname = native_names{channelstruct_here.internal_number};
						channelstruct_here.samplerate = intan_rhd_obj.samplerate(epochstreams,epoch_select,channelprefix,channelnumber);
					elseif absolute % absolute reference
						channelstruct_here.internal_channelname = [channelprefix{c} '-' sprintf('%.3d',channelnumber(c))];
						index = find(strcmp(channelstruct_here.internal_channelname,{header_chunk.native_channel_name}));
						if isempty(index)
							error(['Requested channel ' channelstruct_here.internal_channelname ' was not recorded in this file.']);
						end
						channelstruct_here.internal_number = index; % make sure to fix index line above
						channelstruct_here.samplerate = intan_rhd_obj.samplerate(epochstreams,epoch_select,...
							channelstruct_here.ndr_type,channelstruct_here.internal_number);
					end % switch
					channelstruct(end+1) = channelstruct_here;
				end
		end % ndr.reader.intan_rhd.daqchannels2internalchannels
		
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
				
				if ~isdirectory
					[blockinfo, bytes_per_block, bytes_present, num_data_blocks] = ndr.format.intan.Intan_RHD2000_blockinfo(filename, header);
					total_samples = 60 * num_data_blocks;
				else
					finfo = dir([parentdir filesep 'time.dat']);
					if isempty(finfo)
						error(['File time.dat necessary in directory ' parentdir ' but it was not found.']);
					end
					total_samples = finfo.bytes / 4;
				end
			    
				total_time = total_samples / header.frequency_parameters.amplifier_sample_rate; % in seconds
				t0 = 0;
				t1 = total_time-1/header.frequency_parameters.amplifier_sample_rate;
			    
				t0t1 = {[t0 t1]};
				% developer note: in the Intan acquisition software, one can define a time offset; right now we aren't considering that
		end % ndr.reader.intan_rhd.epochclock
		
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
					if isfield(header,intan_channel_types{k})
						channel_type_entry = intan_rhd_obj.intanheadertype2mfdaqchanneltype(...
					intan_channel_types{k});
					channel = getfield(header, intan_channel_types{k});
					num = numel(channel); % number of channels with specific type
					for p=1:numel(channel)
						newchannel.type = channel_type_entry;
						newchannel.name = intan_rhd_obj.intanname2mfdaqname(...
							intan_rhd_obj,...
							channel_type_entry,...
							channel(p).native_channel_name);
						channels(end+1) = newchannel;
					end
				end
			end
		end % ndr.reader.intan_rhd.getchannelsepoch

        function [datatype,p,datasize] = underlying_datatype(intan_rhd_obj, epochstreams, epoch_select, channeltype, channel)
            % UNDERLYING_DATATYPE - get the underlying data type for a channel in an epoch
            %
            % [DATATYPE,P,DATASIZE] = UNDERLYING_DATATYPE(INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
            %
            % Return the underlying datatype for the requested channel.
            %
            % DATATYPE is a type that is suitable for passing to FREAD or FWRITE
            %  (e.g., 'float64', 'uint16', etc. See help fread.)
            %
            % P is a polynomial that converts between the double data that is returned by
            % READCHANNEL. RETURNED_DATA = (RAW_DATA+P(1))*P(2)+(RAW_DATA+P(1))*P(3) ...
            %
            % DATASIZE is the sample size in bits.
            %
            % CHANNELTYPE must be a string. It is assumed that
            % that CHANNELTYPE applies to every entry of CHANNEL.
            %
            
            switch(channeltype)
                case {'analog_in','analog_out'}
                    % For the abstract class, keep the data in doubles. This will always work but may not
                    % allow for optimal compression if not overridden
                    datatype = 'uint16';
                    datasize = 16;
                    p = [32768 0.195];
                case {'auxiliary_in'}
                    datatype = 'uint16';
                    datasize = 16;
                    p = [0 3.7400e-05];
                case {'time'}
                    datatype = 'float64';
                    datasize = 64;
                    p = [0 1];
                case {'digital_in','digital_out'}
                    datatype = 'char';
                    datasize = 8;
                    p = [0 1];
                case {'eventmarktext','event','marker','text'}
                    datatype = 'float64';
                    datasize = 64;
                    p = [0 1];
                otherwise
                    error(['Unknown channel type ' channeltype '.']);
            end
        end

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
				if numel(sr_unique)~=1
					error(['Do not know how to handle different sampling rates across channels.']);
				end

				sr = sr_unique;

				t0 = (s0-1)/sr;
				t1 = (s1-1)/sr;

				if strcmp(intanchanneltype,'time')
					channel = 1; % time only has 1 channel in Intan RHD
				end

				if ~isdirectory
					data = ndr.format.intan.read_Intan_RHD2000_datafile(filename,'',intanchanneltype,channel,t0,t1);
				else
					data = ndr.format.intan.read_Intan_RHD2000_directory(parentdir,'',intanchanneltype,channel,t0,t1);
				end
		end % ndr.reader.intan_rhd.readchannels_epochsamples
		
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
				if epoch_select~=1
					error(['Intan RHD files have 1 epoch per file.']);
				end
				sr = [];
				filename = intan_rhd_obj.filenamefromepochfiles(epochstreams);
			    
				head = ndr.format.intan.read_Intan_RHD2000_header(filename);
				for i=1:numel(channel)
					channeltype_here = vlt.data.celloritem(channeltype,i);
					freq_fieldname = intan_rhd_obj.mfdaqchanneltype2intanfreqheader(channeltype_here);
					sr(i) = getfield(head.frequency_parameters,freq_fieldname);
				end
		end % ndr.reader.intan_rhd.samplerate
		
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
				if numel(index)>1
					error(['Need only 1 .rhd file per epoch.']);
				elseif numel(index)==0
					error(['Need 1 .rhd file per epoch.']);
				else
					filename = filename_array{index};
					[parentdir, fname, ext] = fileparts(filename);
					if strcmp(fname,'info')
						s2 = ['time\.dat\>']; % equivalent of *.ext on the command line
						tf2 = vlt.string.strcmp_substitution(s2,filename_array,'UseSubstituteString',0);
						if any(tf)
							% we will call it a directory
							isdirectory = 1;
						end
					end
				end
		end % ndr.reader.intan_rhd.filenamefromepochfiles
		
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
			switch (channeltype)
				case {'analog_in','ai'}
					intanchanheadertype = 'amplifier_channels';
				case {'digital_in','di'}
					intanchanheadertype = 'board_dig_in_channels';
				case {'digital_out','do'}
					intanchanheadertype = 'board_dig_out_channels';
				case {'auxiliary','aux','ax','auxiliary_in','auxiliary_input'}
					intanchanheadertype = 'aux_input_channels';
				otherwise
					error(['Could not convert channeltype ' channeltype '.']);
			end
		end % ndr.reader.mfdaqchanneltype2intanheadertype
		
		function channeltype = intanheadertype2mfdaqchanneltype(intanchanneltype)
			% INTANHEADERTYPE2MFDAQCHANNELTYPE - Convert between Intan headers and the ndr.ndr.reader.mfdaq channel types
			%
			%  CHANNELTYPE = INTANHEADERTYPE2MFDAQCHANNELTYPE(INTANCHANNELTYPE)
			%
			%  Given an Intan header file type, returns the standard ndi.ndr.reader.mfdaq channel type.
			%
				switch (intanchanneltype)
					case {'amplifier_channels'}
						channeltype = 'analog_in';
					case {'board_dig_in_channels'}
						channeltype = 'digital_in';
					case {'board_dig_out_channels'}
						channeltype = 'digital_out';
					case {'aux_input_channels'}
						channeltype = 'auxiliary_in';
					otherwise
						error(['Could not convert channeltype ' intanchanneltype '.']);
				end
		end % ndr.reader.intan_rhd.intanheadertype2mfdaqchanneltype
		
		function intanchanneltype = mfdaqchanneltype2intanchanneltype(channeltype)
			% MFDAQCHANNELTYPE2INTANCHANNELTYPE - Convert the channel type from generic format of multifuncdaqchannel
			%                                       to the specific Intan channel type
			%
			%  INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
			%
			%  The intanchanneltype is a string of the specific channel type for Intan.
			%
				switch lower(channeltype)
					case {'analog_in','ai'}
						intanchanneltype = 'amp';
					case {'digital_in','di'}
						intanchanneltype = 'din';
					case {'digital_out','do'}
						intanchanneltype = 'dout';
					case {'time','timestamp'}
						intanchanneltype = 'time';
					case {'auxiliary','aux','auxiliary_input','auxiliary_in'}
						intanchanneltype = 'aux';
					otherwise
						error(['Do not know how to convert channel type ' channeltype '.']);
				end
		end % ndr.reader.intan_rhd.mfdaqchanneltype2intanchanneltype

		function mfdaqchanneltype = intanchanneltype2mfdaqchanneltype(channeltype)
			% INTANCHANNELTYPE2MFDAQCHANNELTYPE - Convert the channel type to generic format of multifuncdaqchannel
			%                                       from the specific Intan channel type
			%
			%  INTANCHANNELTYPE = MFDAQCHANNELTYPE2INTANCHANNELTYPE(CHANNELTYPE)
			%
			%  The intanchanneltype is a string of the specific channel type for Intan.
			%
				switch lower(channeltype)
					case 'amp'
						mfdaqchanneltype = 'ai';
					case 'din'
						mfdaqchanneltype = 'di';
					case 'dout'
						mfdaqchanneltype = 'do';
					case 'time'
						mfdaqchanneltype = 'time';
					case 'aux'
						mfdaqchanneltype = 'ai';
					otherwise
						error(['Do not know how to convert channel type ' channeltype '.']);
				end
		end % ndr.reader.intan_rhd.intanchanneltype2mfdaqchanneltype()
	
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
		end % ndr.reader.intan_rhd.intanname2mfdaqname
		
		function headername = mfdaqchanneltype2intanfreqheader(channeltype)
			% MFDAQCHANNELTYPE2INTANFREQHEADER - Return header name with frequency information for channel type
			%
			%  HEADERNAME = MFDAQCHANNELTYPE2INTANFREQHEADER(CHANNELTYPE)
			%
			%  Given an ndr.ndr.mfdaq channel type string, this function returns the associated fieldname.
			%
				switch lower(channeltype)
					case {'analog_in','ai'}
					    headername = 'amplifier_sample_rate';
					case {'digital_in','di'}
					    headername = 'board_dig_in_sample_rate';
					case {'time','timestamp'}
					    headername = 'amplifier_sample_rate';
					case{'auxiliary','aux'}
					    headername = 'aux_input_sample_rate';
					otherwise
					    error(['Do not know frequency header for channel type ' channeltype '.']);
				end
		end % ndr.reader.intan_rhd.mfdaqchanneltype2intanfreqheader
		
		function [intanchanneltype,absolute] = intananychannelname2intanchanneltype(intananychannelname)
			% INTANANYCHANNELNAME2INTANCHANNELTYPE- Converts a channel bank from Intan native format or relative format to the appropriate Intan channel type
			%
			%  [INTANCHANNELTYPE,ABSOLUTE] = INTANANYCHANNELNAME2INTANCHANNELTYPE(INTANANYCHANNELNAME)
			%
			%  Converts any channel name into the type needed to call ndr.format.intan.readfile. If the channel was specified
			%  as an absolute reference (that is, 'A', 'B', etc), then ABSOLUTE is 1. Otherwise, if the reference is relative,
			%  then ABSOLUTE is 0.
			%
			%  Examples:
			%        intanchanneltype = ndr.reader.intan_rhd.intananychannelname2intanchanneltype('ai') % returns 'amp', 0
			%        intanchanneltype = ndr.reader.intan_rhd.intananychannelname2intanchanneltype('A') % returns 'amp', 1
			%        intanchanneltype = ndr.reader.intan_rhd.intananychannelname2intanchanneltype('DIN') % returns 'din', 0
			%
				absolute = 0;
				try
					intanchanneltype = ndr.reader.intan_rhd.mfdaqchanneltype2intanchanneltype(intananychannelname);
					% if we got it, we are done
					return;
				end
				% if we are still here, we did not get an answer and need to see if it is Intan channel format

				absolute = 1;
				switch lower(intananychannelname)
					case {'a','b','c','d'}
					    intanchanneltype = 'amp';
					case {'aaux','baux','caux','daux'}
					    intanchanneltype = 'aux';
					case {'avdd1','bvdd1','cbdd1','dvdd1'}
					    intanchanneltype = 'supply';
					otherwise
						error(['Do not know how to convert channel bank ' intananychannelname'.']);
				end
		end % ndr.reader.intan_rhd.intanchannelbank2intanchanneltype
		
	end % methods (Static)
	    
end % classdef
