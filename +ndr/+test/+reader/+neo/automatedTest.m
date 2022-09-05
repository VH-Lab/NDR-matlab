function tests = automatedTest
  tests = functiontests(localfunctions);
end

function setupOnce(test_case)
  ndr.reader.neo.reload_py();
  ndr_Init();
end

% function test_read(test_case)
%   filename = utils_get_example('example.rhd');
%   intan_reader = ndr.reader('intan');
%   [data, time] = intan_reader.read({ filename }, ['A021+A022'], { 'useSamples', 1, 's0', 1, 's1', 5 });
%   % channelprefix = ['a', 'a'], channelnumber = [21, 22]
%   % disp(data);
%   % disp(time);

%   intan_channels = intan_reader.getchannelsepoch({ filename });
%   utils_disp_channelstruct()
% end

function test_getchannelsepoch(test_case)
  filename = utils_get_example('example.rhd');

  % Setup intan
  intan_reader = ndr.reader('intan');
  intan_channels = intan_reader.getchannelsepoch({ filename }, 1);

  % Setup neo
  neo_reader = ndr.reader('neo');
  neo_channels = neo_reader.getchannelsepoch({ filename }, 'all');

  % Tests
  % 1. Note that intan and neo return different channel names
  verifyEqual(test_case, intan_channels(1).name, 'ai1');
  verifyEqual(test_case, neo_channels(1).name, 'A-000');
  % 2. Note that neo returns a lot more channels!
  verifyEqual(test_case, numel(intan_channels), 36);
  verifyEqual(test_case, numel(neo_channels), 36);
end

function test_readchannels_epochsamples(test_case)
  filename = utils_get_example('example.rhd');

  % Setup intan
  intan_reader = ndr.reader('intan');

  % Setup neo
  neo_reader = ndr.reader('neo');

  % Tests
  intan_data = intan_reader.readchannels_epochsamples('ai', [ 1, 2 ], { filename }, 1, 1, 10);
  neo_data = neo_reader.readchannels_epochsamples('smth', [ '0', '1' ], { filename }, 1, 1, 10);

  verifyEqual(test_case, intan_data, neo_data, "AbsTol", 0.001);
end

% Utils
function utils_disp_channels(channels)
  for i=1:numel(channels),
    disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
  end
end

function utils_disp_channelstruct(channelstruct)
  for i=1:numel(channelstruct),
    channel = channelstruct{1}
    disp([
      'internal_type: ' channel.internal_type...
      'internal_number:' channel.internal_number...
      'internal_channelname:' channel.internal_channelname...
      'ndr_type:' channel.ndr_type...
      'samplerate:' channel.samplerate...
    ])
  end
end

function path_to_file = utils_get_example(filename)
  ndr.globals();
  example_dir = [ndr_globals.path.path filesep 'example_data'];
  path_to_file = [example_dir filesep filename];
end
