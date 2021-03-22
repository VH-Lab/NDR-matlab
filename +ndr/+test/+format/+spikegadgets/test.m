
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
t = ndr.format.spikegadgets.read_SpikeGadgets_config(filename,'time',1,0,100); % read first 100 seconds
d = ndr.format.spikegadgets.read_SpikeGadgets_config(filename,'amp',1,0,100); % read first 100 seconds

if plotit,
	figure;
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets test data']);
end;
