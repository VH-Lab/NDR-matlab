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
    % epochstreams  { '/Users/Me/NDR-matlab/example_data/example.rhd' }
    % epochselect   1
    function channelstruct = daqchannels2internalchannels(self, channelprefix, channelnumber, epochstreams, epochselect)
        py_channels = py.neo_python.convert_channels_from_neo_to_ndi(channelprefix, channelnumber, epochstreams, epochselect);

        % Formatting objects from python to matlab
        channels = vlt.data.emptystruct('internal_type','internal_number',...
          'internal_channelname','ndr_type','samplerate');
        for k = 1:length(py_channels)
          new_channel.internal_type = char(py_channels{k}{'internal_type'});
          new_channel.internal_number = char(py_channels{k}{'internal_number'});
          new_channel.internal_channelname = char(py_channels{k}{'internal_channelname'});
          new_channel.ndr_type = char(py_channels{k}{'ndr_type'});
          new_channel.samplerate = char(py_channels{k}{'samplerate'});
          channels(end + 1) = new_channel;
        end
    end;

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
