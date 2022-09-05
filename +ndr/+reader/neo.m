classdef neo < ndr.reader.base
  properties
  end

  methods
    function obj = neo(varargin)
    end

    % Get all channels from a file: py.get_channels().
    %
    % getchannelsepoch(epochfiles, 1) - to get channels from epoch 1
    % getchannelsepoch(epochfiles, 'all') - to get all channels
    function channels = getchannelsepoch(self, epochfiles, epochselect)
      py_channels = py.neo_python.get_channels(epochfiles, epochselect);

      % Formatting objects from python to matlab
      channels = vlt.data.emptystruct('name', 'type');
      for k = 1:length(py_channels)
        new_channel.type = char(py_channels{k}{'type'});
        new_channel.name = char(py_channels{k}{'name'});
        channels(end + 1) = new_channel;
      end
    end

    % Read the channel: py.read_channel().
    %
    % Matlab      Python         Example
    % _________________________________________
    % channeltype  channel_type   'anything'
    % channel      channel_ids     [ '0', '1' ]
    % epochfiles   filenames       { '/Users/Me/NDR-matlab/example_data/example.rhd' }
    % epochselect  segment_index   1
    % s0           start_sample    1
    % s1           end_sample      10
    function data = readchannels_epochsamples(self, channeltype, channel, epochfiles, epochselect, s0, s1)
      py_data = py.neo_python.read_channel(channeltype, channel, epochfiles, epochselect, s0, s1);

      % Formatting objects from python to matlab
      data = double(py_data);
    end

    % channelprefix { 'ai', 'ai', 'ai' }
    % channelnumber [ 21, 120, 5 ]
    % epochfiles  { '/Users/Me/NDR-matlab/example_data/example.rhd' }
    % epochselect   1
    function channelstruct = daqchannels2internalchannels(self, channelprefix, channelnumber, epochfiles, epochselect)
        py_channels = py.neo_python.convert_channels_from_neo_to_ndi(channelprefix, channelnumber, epochfiles, epochselect);

        % Formatting objects from python to matlab
        channelstruct = vlt.data.emptystruct('internal_type','internal_number',...
          'internal_channelname','ndr_type','samplerate');
        for k = 1:length(py_channels)
          new_channel.internal_type = char(py_channels{k}{'internal_type'});
          new_channel.internal_number = char(py_channels{k}{'internal_number'});
          new_channel.internal_channelname = char(py_channels{k}{'internal_channelname'});
          new_channel.ndr_type = char(py_channels{k}{'ndr_type'});
          new_channel.samplerate = char(py_channels{k}{'samplerate'});
          channelstruct(end + 1) = new_channel;
        end
    end;

    function [b, errormsg] = canbereadtogether(self, channelstruct)
      % Returns 1 if the NDR_READER_BASE_OBJ can read all of the channels in
      % CHANNELSTRUCT with a single function call. If they cannot be read together,
      % a description is provided in ERRORMSG.
      py_response = py.neo_python.can_be_read_together(channelstruct);

      b = py_response{'b'};
      errormsg = [py_response{'errormsg'}];
    end

    function sr = samplerate(self, epochfiles, epochselect, channeltype, channel)
      % SR is an array of sample rates from the specified channels
      %
      % CHANNELTYPE can be either a string or a cell array of
      % strings the same length as the vector CHANNEL.
      % If CHANNELTYPE is a single string, then it is assumed that
      % that CHANNELTYPE applies to every entry of CHANNEL.
      sr = py.neo_python.get_sample_rates_for_channel_ids(epochfiles, channel);
    end

    function t0t1 = t0_t1(self, epochfiles, epochselect)
      py_t0t1 = py.neo_python.get_t0t1(epochfiles, epochselect);

      % Formatting objects from python to matlab
      t0t1 = {py_t0t1};
      % t0t1 = {[NaN NaN]};
    end
  end

  methods (Static)
    function reload_py()
      warning('off','MATLAB:ClassInstanceExists')
      clear classes
      modd = py.importlib.import_module('neo_python');
      py.importlib.reload(modd);
    end
  end
end
