
function test(varargin)
% ndr.test.format.spikegadgets.test - test reading from SpikeGadgets format
%
%
% 

plotit = 0;

assign(varargin{:});


ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rec'];

h = ndr.format.spikegadgets.read_rec_config(filename);

disp(['Read header file. Header entries are as follows:']);

h,

  % will drop word SpikeGadgets in future versions
  
  [fileconfig, channels] = ndr.format.spikegadgets.read_rec_config(filename,1,0,100) % read first 100 seconds
  
  sr = str2num(fileconfig.samplingRate); 
  
  data = read_rec_trodeChannels(filename,header.numChannels,channels-1,sr, header.headerSize,s0,s1);
  data = read_rec_analogChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1)
  data = read_SpikeGadgets_digitalChannels(filename,header.numChannels,byteandbit,sr,header.headerSize,s0,s1)
  

if plotit,
	figure;
	plot(time,data);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets test data']);
end;
