function readertest(varargin)
% ndr.test.reader.spikegadgets_rec.readertest - test reading using NDR reader
%

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rec'];

r = ndr.reader('rec'); % open a rec reader

[d,t] = r.read({filename}, 'ai120');

if plotit
	figure (1);
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['Spikegadgets Example Data']);
end

