function test(varargin)
% ndr.test.reader.spikegadgets_rec.test- test reading using NDR reader with spikegadgets_rec format
%

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];
% same as format.test: Dot indexing is not supported for variables of this type.

filename = [example_dir filesep 'example.rec'];

r = ndr.reader('rec')
  
for i=1:numel(channels),
  
  disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);

end
  
 epoch_select = 1; 
 channel = 120; 

[data,time]=r.read({'filename.rec'},'ai2');

if plotit, 
	figure;
	plot(time,data);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets Example Data']);
end;
