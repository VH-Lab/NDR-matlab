function readertest(filename)
% READERTEST - Test the functionality of the axon_abf ndr.reader.read function
%
	% Setup as before
	ndr.globals
    
	% Then use the new function
	r = ndr.reader('axon_abf');
    
	r,

	[d,t] = r.read({filename}, 'ai1');
    
	figure;
	plot(t,d);
end % ndr.test.reader.tdt_sev.readertest
