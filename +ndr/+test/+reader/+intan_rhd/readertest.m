function readertest
% READERTEST - Test the functionality of the Intan ndr.reader.read function
%
    % Setup as before
    ndr.globals
    example_dir = [ndr_globals.path.path filesep 'example_data'];
    filename = [example_dir filesep 'example.rhd'];
    
    % Then use the new function
    r = ndr.reader('intan');
    
    r,
    
    [d,t] = r.read({filename}, 'A021');
    
    figure;
    plot(t,d);
end % ndr.test.reader.intan_rhd.readertest