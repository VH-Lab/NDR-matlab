% NDR_READER_AXON_ABF - Reader class for Axon Instruments (ABF) .abf
% file
%
% This class reads data from Axon .ABF file format.
%
%

classdef axon_abf < ndr.reader.base
    
	properties
        
	end % properties
    
	methods
        
		function axon_abf_obj = axon_abf()
			% AXON_ABF - Create a new Neuroscience Data Reader object for Axon ABF format
			%
			%  AXON_ABF_OBJ = AXON_ABF()
			%
			%  Creates a Neuroscience Data Reader object of the Axon Instruments
			%  ABF file format.
			%
		end % ndr.reader.axon_abf.axon_abf
			
		function t0t1 = t0_t1(axon_abf_obj, epochstreams, epoch_select)
			% EPOCHCLOCK - Return the beginning and end epoch times for an
			% epoch
			%
			%  T0T1 = T0_T1(AXON_ABF_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			%  Return the beginning (t0) and end (t1) times of the epoch
			%  EPOCH_NUMBER in the same units as the ndr.time.clocktype objects
			%  returned by EPOCH_NUMBER.
			%
			%  See also: ndr.time.clocktype, EPOCHCLOCK
			%
				[filename] = axon_abf_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.axon.read_abf_header(filename);

				t0t1 = axon_abf_obj.get_t0_t1_from_header(header);
		end % ndr.reader.axon_abf.epochclock

		function channels = getchannelsepoch(axon_abf_obj, epochstreams, epoch_select)
			% GETCHANNELS - List the channels that are available from this ABF
			% file for a given set of files
			%
			%  CHANNELS = GETCHANNELSEPOCH(AXON_ABF_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
			%
			%  Returns the channel list of acquired channels in this epoch.
			%
			% CHANNELS is a structure list of all channels with fields:
			% ---------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data store in the channel
			%                    |    (e.g., 'analog_in', 'digital_in', 'image', 'timestamp')
			%
				[filename] = axon_abf_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.axon.read_abf_header(filename);
			
				channels = vlt.data.emptystruct('name','type','time_channel');

				channels(1) = struct('name','t1','type','time','time_channel',1);

				for i=1:numel(header.recChNames),
					channels(end+1) = struct('name',['ai' int2str(i)],...
							'type','analog_in', 'time_channel', 1);
				end;
		end % ndr.reader.axon_abf.getchannelsepoch
		
		function data = readchannels_epochsamples(axon_abf_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
			% READCHANNELS_EPOCHSAMPLES - Read the data based on specified channels
			%
			%  DATA = READCHANNELS_EPOCHSAMPLES(AXON_ABF_OBJ, CHANNELTYPE, CHANNEL, EPOCH, S0, S1)
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
				[filename] = axon_abf_obj.filenamefromepochfiles(epochstreams);
				header = ndr.format.axon.read_abf_header(filename);

				if ~iscell(channeltype),
					channeltype = repmat({channeltype},numel(channel),1);
				end;
                maxSamples = header.lActualAcqLength / header.nADCNumChannels;
				s0_ = max(1, s0);
				if isinf(s0_), % could be positive inf
					s0_ = maxSamples;
				end;
				s1_ = min(maxSamples, s1);
				if isinf(s1_), % could be negative infinity
					s1_ = 1;
				end;

				sr = axon_abf_obj.get_samplerate_from_header(header, channel);
				sr_unique = unique(sr); % get all sample rates
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;

				t0t1 = axon_abf_obj.get_t0_t1_from_header(header);
				T = ndr.time.fun.samples2times([s0_ s1_], t0t1{1}, sr_unique);

				% in abfread, the reader reads up to s1 -1 instead of s1
				data = ndr.format.axon.read_abf(filename,header,channeltype{1},channel,T(1),T(2));

		end % ndr.reader.axon_abf.readchannels_epochsamples
		
		function sr = samplerate(axon_abf_obj, epochstreams, epoch_select, channeltype, channel)
			% SAMPLERATE - Get the sample rate for specific channel
			%
			%  SR = SAMPLERATE(AXON_ABF_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
			%
			%  SR is an array of sample rates from the specified channels in samples/sec.
			%
			%  CHANNELTYPE can be either a string or a cell array of strings
			%  the same length as the vector CHANNEL.
			%  If CHANNELTYPE is a single string, then it is assumed that that
			%  CHANNELTYPE applies to every entry of CHANNEL.
			%
				if epoch_select~=1,
					error(['ABF files have 1 epoch per file.']);
				end;
				
				filename = axon_abf_obj.filenamefromepochfiles(epochstreams);
			    
				header = ndr.format.axon.read_abf_header(filename);
				sr = axon_abf_obj.get_samplerate_from_header(header, channel);
		end % ndr.reader.axon_abf.samplerate

		function [filename] = filenamefromepochfiles(axon_abf_obj, filename_array)
			% FILENAMEFROMEPOCHFILES - Return the file name that corresponds to the ABF file
			%
			%  [FILENAME] = FILENAMEFROMEPOCHFILES(AXON_ABF_OBJ, FILENAME_ARRAY)
			%
			%  Examines the list of filenames in FILENAME_ARRAY (cell array of full path file strings) and determines which
			%  one is an .ABF data file. 
			%
				s1 = ['.*\.abf\>']; % equivalent of *.ext on the command line
				[tf, matchstring, substring] = vlt.string.strcmp_substitution(s1,filename_array,'UseSubstituteString',0);
		    
				index = find(tf);
				if numel(index)==0,
					error(['Need at least 1 .abf file per epoch.']);
				else,
					filename = filename_array{index(1)};
				end
		end; % ndr.reader.axon_abf.filenamefromepochfiles

		function channelstruct = daqchannels2internalchannels(ndr_reader_axon_abf_obj, channelprefix, channelnumber, epochstreams, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_AXON_ABF_OBJ, ...
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
				channels = ndr_reader_axon_abf_obj.getchannelsepoch(epochstreams, epoch_select);

				channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
					'internal_channelname','ndr_type','samplerate');

				for i=1:numel(channels),
					newentry.internal_type = channels(i).type;
					[CHANNELNAMEPREFIX, numericchannel] = ndr.string.channelstring2channels(channels(i).name);
					newentry.internal_number = numericchannel;
					newentry.internal_channelname = channels(i).name;
					newentry.ndr_type = ndr.reader.base.mfdaq_type(newentry.internal_type);
					newentry.samplerate = ndr_reader_axon_abf_obj.samplerate(epochstreams,epoch_select,...
						CHANNELNAMEPREFIX, numericchannel);
					if any(   (newentry.internal_number(:) == channelnumber) & strcmp(channelprefix,CHANNELNAMEPREFIX) ),
						channelstruct(end+1) = newentry;
					end;
				end;
                end; % daqchannels2internalchannels

		
	end % methods
	
    methods (Static, Access = private)
        function t0t1 = get_t0_t1_from_header(header)
			t0 = 0;
			t1 = diff(header.recTime)-header.si*1e-6; 
			t0t1 = {[t0 t1]};
        end

        function sr = get_samplerate_from_header(header, channel)
			sr = 1./(header.si*1e-6 * ones(numel(channel),1));
        end
    end

	methods (Static) % helper functions
        
	end % methods (Static)
	    
end % classdef
