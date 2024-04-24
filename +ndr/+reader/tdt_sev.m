% NDR_READER_TDT_SEV - Reader class for Tucker Davis Technologies (TDT) .sev
% file
%
% This class reads data from TDT .SEV file format.
%
% Tucker Davis Technologies: https://www.tdt.com
%

classdef tdt_sev < ndr.reader.base
    
	properties
        
	end % properties
    
	methods
        
		function tdt_sev_obj = tdt_sev()
			% TDT_SEV - Create a new Neuroscience Data Reader object for TDT SEV format
			%
			%  TDT_SEV_OBJ = TDT_SEV()
			%
			%  Creates a Neuroscience Data Reader object of the Tucker Davis Technologies
			%  (TDT) .SEV file format.
			%
		end % ndr.reader.tdt_sev.tdt_sev
			
		function t0t1 = t0_t1(tdt_sev_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - Return the beginning and end epoch times for an
			% epoch
			%
			%  T0T1 = T0_T1(TDT_SEV_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			%  Return the beginning (t0) and end (t1) times of the epoch
			%  EPOCH_NUMBER in the same units as the ndr.time.clocktype objects
			%  returned by EPOCH_NUMBER.
			%
			%  See also: ndr.time.clocktype, EPOCHCLOCK
			%
				[filename] = tdt_sev_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.tdt.read_SEV_header(filename);

				t0 = 0;
				t1 = 0;
				if numel(header)>0,
					indexes = find([header.chan]==header(1).chan);
					header = header(indexes);
					[hours_sorted,hours_sort_index] = sort([header.hour]);
					for i=1:numel(hours_sort_index),
						t1 = t1 + header(hours_sort_index(i)).duration_seconds;
					end;
				end;
				t0t1 = {[t0 t1]};
		end % ndr.reader.tdt_sev.epochclock
		
		function channels = getchannelsepoch(tdt_sev_obj, epochstreams, epoch_select)
			% GETCHANNELS - List the channels that are available on this TDT
			% device for a given set of files
			%
			%  CHANNELS = GETCHANNELSEPOCH(TDT_SEV_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			%  Returns the channel list of acquired channels in this epoch.
			%
			% CHANNELS is a structure list of all channels with fields:
			% ---------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data store in the channel
			%                    |    (e.g., 'analog_in', 'digital_in', 'image', 'timestamp')
			%
				[filename] = tdt_sev_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.tdt.read_SEV_header(filename);
			
				channels = vlt.data.emptystruct('name','type','time_channel');

				if numel(header)>0,
					channels(1) = struct('name','t1','type','time','time_channel',1);
				end;

				for i=1:numel(header),
					if header(i).hour==0,
						channels(end+1) = struct('name',['ai' int2str(header(i).chan)],...
							'type','analog_in', 'time_channel', 1);
					end;
				end;
		end % ndr.reader.tdt_sev.getchannelsepoch
		
		function data = readchannels_epochsamples(tdt_sev_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
			% READCHANNELS_EPOCHSAMPLES - Read the data based on specified channels
			%
			%  DATA = READCHANNELS_EPOCHSAMPLES(TDT_SEV_OBJ, CHANNELTYPE, CHANNEL, EPOCH, S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read (single text string,
			%  such as 'ai','analog_input','time') or a cell array of strings for each channel
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning
			%  from 1.
			%
			%  EPOCH is the epoch number to read from.
			%
			%  DATA will have one column per channel.
			%
				[filename] = tdt_sev_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.tdt.read_SEV_header(filename);

				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channel),1);
				end;

				% we can only read single channels from tdt_sev files at a time

				index = find([[header.chan] == channel(1)] & [[header.hour]==0]);
				if isempty(index),
					error(['Channel ' int2str(channel(1)) ' not recorded in this epoch.']);
				end;

				num_pts = header(index).npts;
				done = 0;
				hour = 1;
				while ~done,
					index = find([[header.chan] == channel(1)] & [[header.hour]==hour]);
					if isempty(index),
						done = 1;
					else,
						num_pts = num_pts + header(index).npts;
					end;
				end;

				s0_ = max(1, s0);
				if isinf(s0_), % could be positive inf
					s0_ = num_pts;
				end;
				s1_ = min(num_pts, s1);
				if isinf(s1_), % could be negative infinity
					s1_ = 1;
				end;

				sr = tdt_sev_obj.samplerate(epochstreams, epoch_select, channeltype, channel);
				sr_unique = unique(sr); % get all sample rates
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;

				data = NaN(s1_-s0_+1,numel(channel));

				for c=1:numel(channel),
					data(:,c) = ndr.format.tdt.read_SEV_channel(filename,header,channeltype,channel(c),s0_,s1_);
				end;

		end % ndr.reader.tdt_sev.readchannels_epochsamples
		
		function sr = samplerate(tdt_sev_obj, epochstreams, epoch_select, channeltype, channel)
			% SAMPLERATE - Get the sample rate for specific channel
			%
			%  SR = SAMPLERATE(TDT_SEV_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
			%
			%  SR is an array of sample rates from the specified channels in samples/sec.
			%
			%  CHANNELTYPE can be either a string or a cell array of strings
			%  the same length as the vector CHANNEL.
			%  If CHANNELTYPE is a single string, then it is assumed that that
			%  CHANNELTYPE applies to every entry of CHANNEL.
			%
				if epoch_select~=1,
					error(['TDT SEV files have 1 epoch per file.']);
				end;
				sr = [];
				filename = tdt_sev_obj.filenamefromepochfiles(epochstreams);
			    
				header = ndr.format.tdt.read_SEV_header(filename);
				header_channels = [header.chan];
				hour0 = [[header.hour]==0];
				for i=1:numel(channel),
					index = find(hour0 & (channel(i)==header_channels));
					if isempty(index),
						error(['Could not find channel ' int2str(channel(i)) ' in epoch.']);
					end;
					sr(i) = header(index).fs;
				end
		end % ndr.reader.tdt_sev.samplerate
		
		function [filename] = filenamefromepochfiles(tdt_sev_obj, filename_array)
			% FILENAMEFROMEPOCHFILES - Return the file name that corresponds to the SEV directory
			%
			%  [FILENAME] = FILENAMEFROMEPOCHFILES(TDT_SEV_OBJ, FILENAME_ARRAY)
			%
			%  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
			%  one is an .SEV data file. FILENAME will be the parent directory where the .SEV files are contained.
			%
				s1 = ['.*\.sev\>']; % equivalent of *.ext on the command line
				[tf, matchstring, substring] = vlt.string.strcmp_substitution(s1,filename_array,'UseSubstituteString',0);
		    
				index = find(tf);
				if numel(index)==0,
					error(['Need at least 1 .sev file per epoch.']);
				else,
					filename = filename_array{index(1)};
					[parentdir, fname, ext] = fileparts(filename);
					filename = parentdir;
				end
		end; % ndr.reader.tdt_sev.filenamefromepochfiles

		function channelstruct = daqchannels2internalchannels(ndr_reader_tdt_sev_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_TDT_SEV_OBJ, ...
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
			% | samplerate                  | The sampling rate of this channel, or NaN if |
			% |                             |   not applicable.                            |
                        % ------------------------------------------------------------------------------
                        %
				channels = ndr_reader_tdt_sev_obj.getchannelsepoch(epochstreams, epoch_select);

				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type','samplerate');

				for i=1:numel(channels),
					newentry.internal_type = channels(i).type;
					[CHANNELNAMEPREFIX, numericchannel] = ndr.string.channelstring2channels(channels(i).name);
					newentry.internal_number = numericchannel;
					newentry.internal_channelname = channels(i).name;
					newentry.ndr_type = ndr.reader.base.mfdaq_type(newentry.internal_type);
					newentry.samplerate = ndr_reader_tdt_sev_obj.samplerate(epochstreams,epoch_select,...
						CHANNELNAMEPREFIX, numericchannel);
					if any(   (newentry.internal_number(:) == channelnumber) & strcmp(channelprefix,CHANNELNAMEPREFIX) ),
						channelstruct(end+1) = newentry;
					end;
				end;
                end; % daqchannels2internalchannels

		
	end % methods
	    
	methods (Static) % helper functions
        
	end % methods (Static)
	    
end % classdef
