function test(varargin)
% ndr.test.format.ced.test- test reading from CED format
%
%
% 

plotit = 1;

assign(varargin{:});


ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.smr'];

h = ndr.format.ced.read_SOMSMR_header(filename);

disp(['Read header file.']);

h.fileinfo,

disp(['Now will print channel info:']);

for i=1:numel(h.channelinfo),
	disp(['Channel information ' int2str(i) ' of ' int2str(numel(h.channelinfo))]);
	h.channelinfo(i),
end

  % the next line of code will fail because these variables haven't been defined; Sophie, try to work out what these inputs should be
  % I got the list of inputs and outputs from the first line of ndr.format.ced.read_SOMSMR_datafile.m
  % let's read from time 0 to time 100 
  % by running 'help ndr.format.ced.read_SOMSMR_datafile' you can read the documentation
[data,total_samples,total_time,blockinfo,time] = ndr.format.ced.read_SOMSMR_datafile(filename,h,21,0,100);

%sample_rate = 1/ndr.format.ced.read_SOMSMR_sampleinterval(sampleinterval);
sample_rate = 1/10;

if plotit,
	figure;
	plot(time,data); 
	xlabel('Time(s)');
	ylabel('Data values');
	title(['CED test data']);
end;


 % here, Sophie, add a test of the sampleinterval 