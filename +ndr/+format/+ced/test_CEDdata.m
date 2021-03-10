function test(varargin)
% ndr.format.ced.read_SOMSMR_datafile - test reading from CED format
%
%
% 

plotit = 0;

assign(varargin{:});


ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.smr'];

h = ndr.format.ced.read_SOMSMR_datafile(filename);

disp(['Read header file. Header entries are as follows:']);

h,

  % will drop word Intan in future versions
t = ndr.format.ced.read_SOMSMR_datafile(filename,'time',1,0,100); % read first 100 seconds
d = ndr.format.ced.read_SOMSMR_datafile(filename,'amp',1,0,100); % read first 100 seconds

if plotit,
	figure;
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['CED test data']);
end;
