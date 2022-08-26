classdef neo < ndr.reader.base
  properties
  end

  methods
    function obj = neo(varargin)
    end

    function channels = getchannelsepoch(self, epochfiles, epochselect)
      py_channels = py.neo_python.get_channels(epochfiles, 0);

      % Just a simple python=>matlab object conversion
      channels = vlt.data.emptystruct('name', 'type');
      for k = 1:length(py_channels)
        new_channel.type = char(py_channels{k}{'type'});
        new_channel.name = char(py_channels{k}{'name'});
        channels(end + 1) = new_channel;
      end
    end

    % Matlab      Python         Example
    % _________________________________________
    % channeltype channel_type   'anything'
    % channel     channel_ids     [ '0', '1' ]
    % epochfiles  filenames       { '/Users/lakesare/Desktop/NDR-matlab/example_data/example.rhd' }
    % epochselect segment_index   1
    % s0          start_sample    1
    % s1          end_sample      10
    function data = readchannels_epochsamples(self, channeltype, channel, epochfiles, epochselect, s0, s1)
      py_data = py.neo_python.read_channel(channeltype, channel, epochfiles, epochselect, s0, s1);

      % Just a simple python=>matlab object conversion
      data = double(py_data);
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
