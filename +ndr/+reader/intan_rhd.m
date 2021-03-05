% NDR_NDRREADER_INTANREADER - Reader class for Intan Technologies .RHD
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
        function intanreader_obj = intan_rhd()
        % INTANREADER - Create a new Neuroscience Data Reader object
        %
        %  D = ndr.reader.intan_rhd()
        %
        %  Creates a Neuroscience Data Reader object of the Intan
        %  Technologies .RHD file format.
        %
        end % ndr.ndr.reader.intanreader
        
        function ec = epochclock(intanreader_obj, epochstreams, epoch_select)
        % EPOCHCLOCK - Return the beginning and end epoch times for an
        % epoch
        %
        %  EC = EPOCHCLOCK(INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
        %
        %  Return the beginning (t0) and end (t1) times of the epoch
        %  EPOCH_NUMBER in the same units as the ndr.time.clocktype objects
        %  returned by EPOCH_NUMBER.
        %
        %  The abstract class always return {[NaN NaN]}.
        %
        %  See also: ndr.time.clocktype, EPOCHCLOCK
        %
            [filename,parentdir,isdirectory] = ndr_ndrreader_intanreader_obj.filenamefromepochfiles(epochfiles);
            header = ndr.ndr.intan.read_Intan_RHD2000_header(filename);
            
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
        end % ndr.ndr.reader.epochclock
        
        function channels = getchannelsepoch(ndr_ndrreader_intanreader_obj, epochstreams, epoch_select)
        % GETCHANNELS - List the channels that are available on this Intan
        % device for a given set of files
        %
        %  CHANNELS = GETCHANNELSEPOCH(NDR_NDRREADER_INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT)
        %
        %  Returns the channel list of acquired channels in this epoch.
        %
        % CHANNELS is a structure list of all channels with fields:
        % ---------------------------------------------------------
        % 'name'             | The name of the channel (e.g., 'ai1')
        % 'type'             | The type of data store in the channel
        %                    |    (e.g., 'analogin', 'digitalin', 'image', 'timestamp')
        %
            channels = struct('name',[],'type',[]);
            channels = channels([]);
        end % ndr.ndr.reader.getchannelsepoch
        
        function data = readchannels_epochsamples(ndr_ndrreader_intanreader_obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
        % READCHANNELS_EPOCHSAMPLES - Read the data based on specified channels
        %
        %  DATA = READCHANNELS_EPOCHSAMPLES(NDR_NDRREADER_INTANREADER_OBJ, CHANNELTYPE, CHANNEL, EPOCH, S0, S1)
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
            data = []; % abstract class
        end % ndr.ndr.reader.readchannels_epochsamples
        
        function [data] = readevents_epochsamples(ndr_ndrreader_intanreader_obj, channeltype, channel, epochstreams, epoch_select, t0, t1)
        % READEVENTS_EPOCHSAMPLES - Read events, markers, and digital
        % events of specified channels for a specified epoch
        %
        %  [DATA] = READEVENTS_EPOCHSAMPLES(NDR_NDRREADER_INTANREADER_OBJ, CHANNELTYPE, CHANNEL, EPOCHSTREAMS, EPOCH_SELECT, T0, T1)
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
            if ~isempty(intersect(channeltype,{'dep','den','dimp','dimn'})),
                data = {};
                for i=1:numel(channel),
                    % optimization speed opportunity
                    srd = ndr_ndrreader_intanreader_obj.samplerate(epochfiles,{'di'},channel(i));
                    s0d = 1+round(srd*t0);
                    s1d = 1+round(srd*t1);
                    data_here = ndr_ndrreader_intanreader_obj.readchannels_epochsamples(repmat({'di'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
                    time_here = ndr_ndrreader_intanreader_obj.readchannels_epochsamples(repmate({'time'},1,numel(channel(i))),channel(i),epochfiles,s0d,s1d);
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
                data = ndr_ndrreader_intanreader_obj.readevents_epochsamples_native(channeltype, ...
                    channel, epochfiles, t0, t1); % abstract class
            end;
        end % ndr.ndr.reader.readevents_epochsamples
        
        function sr = samplerate(ndr_ndrreader_intanreader_obj, epochstreams, epoch_select, channeltype, channel)
        % SAMPLERATE - Get the sample rate for specific channel
        %
        %  SR = SAMPLEREADER(NDR_NDRREADER_INTANREADER_OBJ, EPOCHSTREAMS, EPOCH_SELECT, CHANNELTYPE, CHANNEL)
        %
        %  SR is an array of sample rates from the specified channels.
        %
        %  CHANNELTYPE can be either a string or a cell array of strings
        %  the same length as the vector CHANNEL.
        %  If CHANNELTYPE is a single string, then it is assumed that that
        %  CHANNELTYPE applies to every entry of CHANNEL.
            sr = []; % abstract class;
        end % ndr.ndr.reader.samplerate
        
    end % methods
end % classdef
