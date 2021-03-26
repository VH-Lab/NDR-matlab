function test(varargin)
% ndr.test.format.intan_rhd.test - test reading from Intan RHD format
%
%
% 

plotit = 1;

assign(varargin{:});


ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rhd'];

h = ndr.format.intan.read_Intan_RHD2000_header(filename);

disp(['Read header file. Header entries are as follows:']);

h,

  % will drop word Intan in future versions
t = ndr.format.intan.read_Intan_RHD2000_datafile(filename,h,'time',1,0,100); % read first 100 seconds
d = ndr.format.intan.read_Intan_RHD2000_datafile(filename,h,'amp',1,0,100); % read first 100 seconds

if plotit,
	figure;
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['Intan RHD test data']);
end;
