function tests = automatedTest
  tests = functiontests(localfunctions);
end

function disp_channels(channels)
  for i=1:numel(channels),
    disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
  end
end

function path_to_file = get_example(filename)
  ndr.globals();
  example_dir = [ndr_globals.path.path filesep 'example_data'];
  path_to_file = [example_dir filesep filename];
end

function test_getchannelsepoch(testCase)
  filename = get_example('example.rhd');

  % setup intan
  intan_reader = ndr.reader('intan');
  intan_channels = intan_reader.getchannelsepoch({ filename });

  % setup neo
  neo_reader = ndr.reader('neo');
  neo_channels = neo_reader.getchannelsepoch({ filename }, 0);

  % tests
  verifyEqual(testCase, intan_channels(1).name, 'ai1');
  verifyEqual(testCase, neo_channels(1).name, 'Ain1');

  verifyEqual(testCase, numel(intan_channels), 36);
  verifyEqual(testCase, numel(neo_channels), 132);
end



