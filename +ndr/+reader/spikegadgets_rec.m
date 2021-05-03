classdef spikegadgets_rec < ndr.reader.base

% path --> epoch start&end 
properties
end
	
	methods
  	  	function ndr_reader_base_spikegadgets_obj = spikegadgets_rec() % input = filename(?)
		% READER - create a new Neuroscience Data Reader object
		%
		% READER_OBJ = ndr.ndr.reader()
		%
		% Creates an Neuroscence Data Reader object of SpikeGadgets.
		
		end; % READER()
		
		
		function [b,errormsg] = canbereadtogether(ndr_reader_base_spikegadgets_obj, channelstruct)
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

		function channelstruct = daqchannels2internalchannels(ndr_reader_base_spikegadgets_obj, channelprefix, channelnumber, epochfiles, epoch_select)
			% DAQCHANNELS2INTERNALCHANNELS - convert a set of DAQ channel prefixes and channel numbers to an internal structure to pass to internal reading functions
			%
			% CHANNELSTRUCT = DAQCHANNELS2INTERNALCHANNELS(NDR_READER_BASE_OBJ, ...
			%    CHANNELPREFIX, CHANNELNUMBERS, EPOCHFILES, EPOCH_SELECT)
			%
			% Inputs:
			% For a set of CHANNELPREFIX (cell array of channel prefixes that describe channels for
			% this device) and CHANNELNUMBER (array of channel numbers, 1 for each entry in CHANNELPREFIX),
			% and for a given recording epoch (specified by EPOCHSTREAMS and EPOCH_SELECT), this function
			% returns a structure CHANNELSTRUCT describing the channel information that should be passed to
			% READCHANNELS_EPOCHSAMPLES or READEVENTS_EPOCHSAMPLES.
			%
			% EPOCHFILES is a cell array of full path file names or remote
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
        
        % extract times, spikes


		function channels = getchannelsepoch(ndr_reader_base_spikegadgets_obj, epochfiles, epoch_select)
			% GETCHANNELSEPOCH - List the channels that are available on this device for a given epoch
			%
			% CHANNELS = GETCHANNELS(THEDEV, EPOCHFILES)
			%
			% EPOCHFILES is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			% Returns the channel list of acquired channels in this epoch
			%
			%
			% CHANNELS is a structure list of all channels with fields:
			% -------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data stored in the channel
			%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
			%
			%

			filename = ndr_reader_base_spikegadgets_obj.filenamefromepochfiles(epochfiles); 
			fileconfig = [];
			[fileconfig, channels] = ndr.format.spikegadgets.read_rec_config(filename);
		
		
		
			for k=1:length(channels)
				number = 0;
				name = '';
			%Auxiliary
				if strcmp(channels(k).name(1),'A')
				%Input
					if strcmp(channels(k).name(2),'i')
						channels(k).type = 'auxiliary';
						number = sscanf(channels(k).name, 'Ain%d'); 
						name = strcat('axn',num2str(number));
						channels(k).number = number;
						%Output
					else
						channels(k).type = 'auxiliary';
						number = sscanf(channels(k).name, 'Aout%d'); 
						name = strcat('axo',num2str(number));
						channels(k).number = number;
					end
	
						%Digital
					elseif strcmp(channels(k).name(1),'D')
						if strcmp(channels(k).name(2),'i') % Input
							channels(k).type = 'digital_in';
							number = sscanf(channels(k).name, 'Din%d'); 
							name = strcat('di',num2str(number));
							channels(k).number = number;
					else %Output
							channels(k).type = 'digital_out';
							number = sscanf(channels(k).name, 'Dout%d');
							name = strcat('do',num2str(number));
							channels(k).number = number;
					end
					else	%MCU (digital inputs)
						channels(k).type = 'digital_in';
						number = sscanf(channels(k).name, 'MCU_Din%d');
						number = number + 32; % +32 from previous non MCU inputs
						name = strcat('di',num2str(number));
						channels(k).number = number;
					end
					channels(k).name = name;
				end

				%Adds all nTrodes to the list
				for i=1:length(fileconfig.nTrodes)
					for j=1:4 %argument for 4 channels, variable could be used later to deal with this in a more general way
						channelNumber = fileconfig.nTrodes(i).channelInfo(j).packetLocation;
						channels(end+1).name = strcat('ai',num2str(channelNumber+1));
						channels(end).type = 'analog_in';
						channels(end).number = channelNumber+1;
					end
				end

				channels = struct2table(channels);
				channels = sortrows(channels,{'type','number'});
				channels = table2struct(channels);
			
				remove = {'startbyte','bit','number'};
				channels = rmfield(channels, remove);
		end

	
		function sr = samplerate(ndr_reader_base_spikegadgets_obj, epochfiles, epoch_select, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is the list of sample rate from specified channels			
			% EPOCHFILES is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			%
			% CHANNELTYPE and CHANNEL not used in this case since it is the
			% same for all channels in this device

				filename = ndr_reader_base_spikegadgets_obj.filenamefromepochfiles(epochfiles); 

				fileconfig = ndr.format.spikegadgets.read_rec_config(filename);

				%Sampling rate is the same for all channels in Spike Gadgets
				%device so it is returned by checking the file configuration
				sr = str2num(fileconfig.samplingRate);
        	end
        
		function t0t1 = t0_t1(ndr_reader_base_spikegadgets_obj, epochfiles, epoch_select)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_EPOCHSET_OBJ, EPOCHFILES)
			%
			% EPOCHFILES is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
			%
			% The abstract class always returns {[NaN NaN]}.
			%
			% See also: ndi.time.clocktype, EPOCHCLOCK
			%
				filename = ndr_reader_base_spikegadgets_obj.filenamefromepochfiles(epochfiles); 

				[fileconfig, ~] = ndr.format.spikegadgets.read_rec_config(filename);

				headerSizeBytes = str2num(fileconfig.headerSize) * 2; % int16 = 2 bytes
				channelSizeBytes = str2num(fileconfig.numChannels) * 2; % int16 = 2 bytes
				blockSizeBytes = headerSizeBytes + 2 + channelSizeBytes;

				s = dir(filename);

				bytes_present = s.bytes;

				bytes_per_block = blockSizeBytes;

				num_data_blocks = (bytes_present - headerSizeBytes) / bytes_per_block;

				total_samples = num_data_blocks;
				total_time = (total_samples - 1) / str2num(fileconfig.samplingRate); % in seconds

				t0 = 0;
				t1 = total_time;

				t0t1 = {[t0 t1]};
		end % t0t1

		function epochprobemap = getepochprobemap(ndr_reader_base_spikegadgets_obj, epochmapfilename, epochfiles, epoch_select)
		        % GETEPOCHPROBEMAP returns struct with probe information
		        % name, reference, n-trode, channels
			% EPOCHFILES is a cell array of full path file names or remote
			% access streams that comprise the epoch of data
			%
			% EPOCH_SELECT allows one to choose which epoch in the file one wants to access,
			% if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
			%
		        %
				filename = ndr_reader_base_spikegadgets_obj.filenamefromepochfiles(epochfiles);
				fileconfig = ndr.format.spikegadgets.read_rec_config(filename);
				nTrodes = fileconfig.nTrodes;
				%List where epochprobemap objects will be stored
				epochprobemap = [];

				for i=1:length(nTrodes)
					name = strcat('Tetrode', nTrodes(i).id);
					reference = 1;
					type = 'n-trode';
					channels = [];

					for j=1:length(nTrodes(i).channelInfo) %number of channels per nTrode
						%Array with channels of trode
						channels = [channels nTrodes(i).channelInfo(j).packetLocation + 1];
					end
					%Object that deals with channels
					devicestringobject = ndi.daq.daqsystemstring('SpikeGadgets',{'ai','ai','ai','ai'}, channels);
					devicestringstring = devicestringobject.devicestring();
					% FIX: we need some way of specifying the subject, which is not in the file to my knowledge (although maybe it is)
					obj = ndi.daq.metadata.epochprobemap_daqsystem(name,reference,type,devicestringstring,'anteater52@nosuchlab.org');
					%Append each newly made object to end of list
					epochprobemap = [epochprobemap obj];
				end
        	end

		function data = readchannels_epochsamples(ndr_reader_base_spikegadgets_obj, channeltype, channels, epochfiles, epoch_select, s0, s1)
			% FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			% DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES ,S0, S1)
			%
			% CHANNELTYPE is the type of channel to read
			% 'digital_in', 'digital_out', 'analog_in', 'analog_out' or 'auxiliary'
			%
			% CHANNEL is a vector of the channel numbers to
			% read beginning from 1 if 'etrodeftrode' is channeltype,
			% if channeltype is 'analog_in' channel is an array with the
			% string names of analog channels 'Ain1'through 8
			%
			% EPOCH is set of files in the epoch
			%
			% DATA is the channel data (each column contains data from an indvidual channel)
			%
				filename = ndr_reader_base_spikegadgets_obj.filenamefromepochfiles(epochfiles); 

				header = ndr.format.spikegadgets.read_rec_config(filename);

				sr = ndr_reader_base_spikegadgets_obj.samplerate(epochfiles,channeltype,channels);

				detailedchannels = ndr_reader_base_spikegadgets_obj.getchannelsepoch(epochfiles); %error

				byteandbit = [];
                
                		data = [];

                
				%read_SpikeGadgets_trodeChannels(filename,NumChannels, channels,samplingRate,headerSize, configExists)
				%reading from channel 1 in list returned
				%Reads nTrodes
				%WARNING channeltype hard coded, ask Steve
				channeltype
                		if (strcmp(channeltype, 'analog_in') || strcmp(channeltype, 'analog_out'))
					data = ndr.format.spikegadgets.read_rec_trodeChannels(filename,header.numChannels,channels-1,sr, header.headerSize,s0,s1);

                    
				elseif (strcmp(channeltype,'auxiliary') || strcmp(channeltype,'aux')) %Reads analog inputs
					%for every channel in device
					for i=1:length(detailedchannels)
						%based on every channel to read
						for j=1:length(channels)
							%check if channel number and channeltype match
							if (strcmp(detailedchannels(i).type,'auxiliary') && detailedchannels(i).number == channels(j))
								%add startbyte to list of channels to read
								byteandbit(end+1) = str2num(detailedchannels(i).startbyte);
							end
						end
					end
					data = ndr.format.spikegadgets.read_rec_analogChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1);


				elseif (strcmp(channeltype,'digital_in') || strcmp(channeltype, 'digital_out')), %Reads digital inputs
					%for every channel in device
					for i=1:length(detailedchannels)
						%based on every channel to read
						for j=1:length(channels)
							%check if channel number and channeltype match
							if (strcmp(detailedchannels(i).type,channeltype) && detailedchannels(i).number == channels(j))
								%add startbyte to list of channels to read
								byteandbit(end+1,1) = str2num(detailedchannels(i).startbyte);
								byteandbit(end,2) = str2num(detailedchannels(i).bit) + 1;
							end
						end
					end

					data = ndr.format.spikegadgets.read_rec_digitalChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1);
					data = data';

                    
                		elseif strcmp(channeltype,'time')
                    			[dummy,data] = ndr.format.spikegadgets.read_rec_trodeChannels(filename,header.numChannels,channels-1,sr, header.headerSize,s0,s1);
                    			data = data(:);
                		end
                
		end % readchannels_epochsamples

		function filename = filenamefromepochfiles(ndr_reader_base_spikegadgets_obj, filename)
				s1 = ['.*\.rec\>']; % equivalent of *.ext on the command line
				[tf, matchstring, substring] = vlt.string.strcmp_substitution(s1,filename,'UseSubstituteString',0);
				index = find(tf);
				if numel(index)> 1,
					error(['Need only 1 .rec file per epoch.']);
				elseif numel(index)==0,
					error(['Need 1 .rec file per epoch.']);
				else,
					filename = filename{index};
				end
                end % filenamefromepoch

    end % methods

end % classdef
