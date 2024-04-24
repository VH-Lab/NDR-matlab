function readertest(filename)
% READERTEST - Test the functionality of the tdt_sev ndr.reader.read function
%
	% Setup as before
	ndr.globals
	%example_dir = [ndr_globals.path.path filesep 'example_data'];
	%filename = [example_dir filesep 'example.rhd'];
    
	% Then use the new function
	r = ndr.reader('tdt_sev');
    
	r,

	[d,t] = r.read({filename}, 'ai1');
    
	figure;
	plot(t,d);
end % ndr.test.reader.tdt_sev.readertest
