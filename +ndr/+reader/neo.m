% example_dir = [ndr_globals.path.path filesep 'example_data'];
% filename = [example_dir filesep 'example.smr'];
%
% 1. If the file has a format 'spike2', or 'igor pro', etc.
% 2. We call the r = ndr.reader('neo');
% 3. channels = r.getchannelsepoch({filename});
% 3.1 We tell neo to open the file 'filename', and return channels object
% 3.2
%     from neo.io.cedio import CedIO
%     srcfile = CedIo(filename=filename)
%     srcfile.read_all_blocks()

classdef neo < ndr.reader.base
  properties
  end

  methods

    function obj = neo(varargin)
    end

    function channels = getchannelsepoch(ndr_reader_cedsmr_obj, epochfiles, epochselect)
      % channels = vlt.data.emptystruct('name', 'type');
      % % We map NEO channel.type to NDR channel.type for each format
      % for k=1:length(header.channelinfo),
      %   % new_channel.type = ndr.reader.ced_smr.cedsmrheader2readerchanneltype(header.channelinfo(k).kind);
      %   % new_channel.name = [ ndr.reader.base.mfdaq_prefix(newchannel.type) int2str(header.channelinfo(k).number) ];
      %   new_channel.type = "hello_type";
      %   new_channel.name = "hi_nammme";
      %   channels(end+1) = newchannel;
      % end
      filename = "/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"



      py_channels = py.neo_python.get_channels(filename)




      % Now we need some way to turn:
      %   from ('Ain1', 'Ain1', 30000., 'int16', '', 1., 0., 'ECU')
      %   to   { type: 'analog_in', name: 'ain1' }
    end

    function check(self)
      filename = "/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"
      epoch_select = 1;
      % channel = 120;
      channel = 11;
      time = self.readchannels_epochsamples('time', channel, filename, epoch_select, 1, 666);
      data = self.readchannels_epochsamples('analog_in', channel, filename, epoch_select, 1, 666);

      if plotit,
        figure;
        plot(time, data);
        xlabel('Time(s)');
        ylabel('Data values');
        title(['SpikeGadgets Example Data']);
      end;
    end

    % channeltype channel_type: 'analog_in'
    % channel     channel_id:   120
    % epochfiles  filename:     { filename }
    % epochselect epoch_id:     1
    % s0          time_from:    0
    % s1          time_to:      16000
    function data = readchannels_epochsamples(self, channeltype, channel, epochfiles, epochselect, s0, s1)
      data = py.neo_python.read_channel(channeltype, channel, epochfiles, epochselect, s0, s1)
    end

    
  end

  methods (Static)
    function reloadPy()
      warning('off','MATLAB:ClassInstanceExists')
      clear classes
      modd = py.importlib.import_module('neo_python');
      py.importlib.reload(modd);
    end
  end
end
