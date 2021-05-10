classdef ced_smr < ndr.reader.base
% CED_SMR - reader class for Cambridge Electronic Design (CED) SMR files
%
% This class reads data from CED Spike2 .SMR or .SON file formats.
%
% It depends on sigTOOL by Malcolm Lidierth (http://sigtool.sourceforge.net).
%
% sigTOOL is also included in the https://github.com/VH-Lab/vhlab-thirdparty-matlab bundle and
% can be installed with instructions at http://code.vhlab.org.
%
	properties
		

	end % properties

	methods
		function obj = ced_smr(varargin)
			% NDR_NDR_READER_CEDSMR - Create a new NDR_NDR_READER_CEDSMR object
			%
			%  N = ndr.reader.ced_smr(NAME,THEFILENAVIGATOR)
			%
			%  Creates a new object for reading Cambridge Electronic Design SMR files. 
			%
		end; % ced_smr() creator

		function channels = getchannelsepoch(ndr_ndr_reader_cedsmr_obj, epochfiles, epochselect)
			% GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELS(THEDEV, EPOCHFILES, EPOCHSELECT)
			%
			%  Returns the channel list of acquired channels in this session
			%
			% CHANNELS is a structure list of all channels with fields:
			% -------------------------------------------------------
			% 'name'             | The name of the channel (e.g., 'ai1')
			% 'type'             | The type of data stored in the channel
			%                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
			%

				if nargin<3,
				    epochselect = 1;
				end;
				if epochselect~=1, 
				    error(['For CED SOM/SMR files, epochselect should be 1.']);
				end;
				channels = vlt.data.emptystruct('name','type');

				% open SMR files, and examine the headers for all channels present
				%   for any new channel that hasn't been identified before,
				%   add it to the list
				filename = ndr_ndr_reader_cedsmr_obj.cedsmrfile(epochfiles);

				header = ndr.format.ced.read_SOMSMR_header(filename);

				if isempty(header.channelinfo),
					channels = struct('name','t1','type','time');
				end;

				for k=1:length(header.channelinfo),
                    header.channelinfo(k).kind
					newchannel.type = ndr.reader.ced_smr.cedsmrheader2readerchanneltype(header.channelinfo(k).kind);
					newchannel.name = [ ndr.reader.base.mfdaq_prefix(newchannel.type) int2str(header.channelinfo(k).number) ];
					channels(end+1) = newchannel;
				end
		end % getchannels()

		function data = readchannels_epochsamples(ndr_ndr_reader_cedsmr_obj, channeltype, channel, epochfiles, epochselect, s0, s1)
			%  FUNCTION READ_CHANNELS - read the data based on specified channels
			%
			%  DATA = READ_CHANNELS(MYDEV, CHANNELTYPE, CHANNEL, EPOCHFILES, S0, S1)
			%
			%  CHANNELTYPE is the type of channel to read
			%
			%  CHANNEL is a vector of the channel numbers to read, beginning from 1
			%
			%  EPOCHFILES is the cell array of full path filenames for this epoch
			%
			%  DATA is the channel data (each column contains data from an indvidual channel) 
			%
				if epochselect~=1, 
					error(['For CED SOM/SMR files, epochselect should be 1.']);
				end;
				filename = ndr_ndr_reader_cedsmr_obj.cedsmrfile(epochfiles);
				sr = ndr_ndr_reader_cedsmr_obj.samplerate(epochfiles, epochselect, channeltype, channel);
				sr_unique = unique(sr); % get all sample rates
				if numel(sr_unique)~=1,
					error(['Do not know how to handle different sampling rates across channels.']);
				end;

				sr = sr_unique;

				t0 = (s0-1)/sr;
				t1 = (s1-1)/sr;

				if isinf(t0) | isinf(t1),
					t0_orig = t0;
					t1_orig = t1;
					t0t1_here = ndr_ndr_reader_cedsmr_obj.t0_t1(epochfiles);
					if isinf(t0_orig),
						if t0_orig<0,
							t0 = t0t1_here{1}(1);
						elseif t0_orig>0,
							t0 = t0t1_here{1}(2);
						end;
					end;
					if isinf(t1_orig),
						if t1_orig<0,
							t1 = t0t1_here{1}(1);
						elseif t1_orig>0
							t2 = t0t1_here{1}(2);
						end;
					end;
				end;

				for i=1:length(channel), % can only read 1 channel at a time
					if strcmpi(channeltype,'time'),
						[dummy,dummy,dummy,dummy,data(:,i)] = ndr.format.ced.read_SOMSMR_datafile(filename,'',channel(i),t0,t1);  % this needs editing, right? No function with that name right now, needs to have the package name
					else,
						[data(:,i)] = ndr.format.ced.read_SOMSMR_datafile(filename,'',channel(i),t0,t1);  % this needs editing, right? No function with that name right now, needs to have the package name
					end
				end

		end % readchannels_epochsamples

		function t0t1 = t0_t1(ndr_ndr_reader_cedsmr_obj, epochfiles, epochselect)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDR_NDR_READER_CEDSMR_OBJ, EPOCHFILES, EPOCHSELECT)
			%
			% Return the beginning (t0) and end (t1) times of the EPOCHFILES that define this
			% epoch in the same units as the ndi.time.clocktype objects returned by EPOCHCLOCK.
			%
			%
			% See also: ndi.time.clocktype, EPOCHCLOCK
			%
				if nargin<3,
				    epochselect = 1;
				end;
				if epochselect~=1, 
				    error(['For CED SOM/SMR files, epochselect should be 1.']);
				end;
				filename = ndr_ndr_reader_cedsmr_obj.cedsmrfile(epochfiles);
				header = ndr.format.ced.read_SOMSMR_header(filename);

				t0 = 0;  % developer note: the time of the first sample in spike2 is not 0 but 0 + 1/4 * sample interval; might be more correct to use this
				t1 = header.fileinfo.dTimeBase * header.fileinfo.maxFTime * header.fileinfo.usPerTime;
				t0t1 = {[t0 t1]};
		end % t0t1

		function [timestamps, data] = readevents_epochsamples_native(ndr_reader_cedsmr_obj, channeltype, channel, epochfiles, epochselect, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels for a specified epoch
			%
			%  [TIMESTAMPS, DATA] = READEVENTS_EPOCHSAMPLES_NATIVE(NDR_READER_CEDSMR_OBJ, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  CHANNELTYPE is the type of channel to read
			%  ('event','marker', 'text')
			%
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%
			%  EPOCH is the set of epoch files
			%
			%  DATA is a multiple-column vector; the first column has the
			%  time of the event. The remaining columns indicate the
			%  marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%
				timestamps = {};
				data = {};
				filename = ndr_reader_cedsmr_obj.cedsmrfile(epochfiles);
				for i=1:numel(channel),
					[data{i},dummy,dummy,dummy,timestamps{i}]= ndr.format.ced.read_SOMSMR_datafile(filename, ... 
						'',channel(i),t0,t1);
				end
				if numel(channel)==1,
					timestamps = timestamps{1};
					data = data{1};
				end;
		end % readevents_epoch()

		function sr = samplerate(ndr_ndr_reader_cedsmr_obj, epochfiles, epochselect, channeltype, channel)
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC EPOCH AND CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is the list of sample rate from specified channels
				if epochselect~=1, 
				    error(['For CED SOM/SMR files, epochselect should be 1.']);
				end;
				filename = ndr_ndr_reader_cedsmr_obj.cedsmrfile(epochfiles);

				sr = [];
				for i=1:numel(channel),
					sr(i) = 1/ndr.format.ced.read_SOMSMR_sampleinterval(filename,[],channel(i)); %   % this needs editing, right? No function with that name right now, needs to have the package name
				end
		end % samplerate()

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
					
				channels = ndr_reader_base_ced_obj.getchannelsepoch(epochfiles, epoch_select);
					
				for i=1:numel(channels),
				        newentry.internal_type = channels.type(epochfiles);
					newentry.internal_number = channels.number(epochfiles);
					newentry.internal_channelname = channels.name(epochfiles);
					newentry.ndr_type = ndr.reader.base.mfdaq_type(internal_type);
					if any(newentry.internalnumber == channelnumbers),
						channelstruct(end+1) = newentry;
					end;
				end;					
		end; % daqchannels2internalchannels

	end % methods

	methods (Static)  % helper functions

		function smrfile = cedsmrfile(filelist)
			% CEDSMRFILE - Identify the .SMR file out of a file list
			% 
			% FILENAME = CEDSMRFILE(FILELIST)
			%
			% Given a cell array of strings FILELIST with full-path file names,
			% this function identifies the first file with an extension '.smr' (case insensitive)
			% and returns the result in FILENAME (full-path file name).
				for k=1:numel(filelist),
					[pathpart,filenamepart,extpart] = fileparts(filelist{k});
					if strcmpi(extpart,'.smr'),
						smrfile = filelist{k}; % assume only 1 file
						return;
					end; % got the .smr file
				end
				error(['Could not find any .smr file in the file list.']);
		end

		function channeltype = cedsmrheader2readerchanneltype(cedsmrchanneltype)
		% CEDSMRHEADER2READERCHANNELTYPE- Convert between Intan headers and the ndr.ndr.reader channel types 
		%
		% CHANNELTYPE = CEDSMRHEADER2READERCHANNELTYPE(CEDSMRCHANNELTYPE)
		% 
		% Given an Intan header file type, returns the standard ndr.ndr.reader channel type

			switch (cedsmrchanneltype),
				case {1,9},
					% 1 is integer, 9 is single precision floating point
					channeltype = 'analog_in';
				case {2,3,4},
					channeltype = 'event'; % event indicator
						% 2 - positive-to-negative transition
						% 3 - negative-to-positive transition
						% 4 - either transition
				case {5,6,7}, % various marker types
					% 5 - generic mark
					% 6 - wavemark, a Spike2-detected event
					% 7 - real-valued marker
					channeltype = 'mark';
				case 8, % text mark
					channeltype = 'text';
				case {11},
					error(['do not know this event yet--programmer should look it up.']);
				otherwise,
					error(['Could not convert channeltype ' cedspike2channeltype '.']);
			end;

		end % readercedsmrheadertype()
	end % methods (Static)
end
