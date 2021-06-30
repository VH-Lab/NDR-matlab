function readertest
% READERTEST - test the functionality of the CED ndr.reader.read function

% setup as before
ndr.globals
example_dir = [ndr_globals.path.path filesep 'example_data'];
filename = [example_dir filesep 'example.smr'];


%then use the new function
r = ndr.reader('smr');

r,

[d,t] = r.read({filename}, 'ai21');

[d_e,t_e] = r.read({filename},'e22');

figure;
plot(t,d);
hold on
plot(t_e,0,'ro');
