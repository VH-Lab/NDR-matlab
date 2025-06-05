function tests = automatedTest
  tests = functiontests(localfunctions);
end

function setupOnce(test_case)
  ndr.reader.neo.reload_python();
  ndr_Init(); % seems to be needed, perhaps test environment runs with its own global variables?
end

function test_readevents_epochsamples_native_blackrock(test_case)
  filename = utils_get_example('example_1.ns2');
  reader = ndr.reader('neo');

  % 1. Read 'marker' - many channels
  [timestamps, data] = reader.readevents_epochsamples_native('marker',...
    { 'digital_input_port', 'serial_input_port', 'analog_input_channel_1' },...
    { filename }, 1, 0, 100);

  %%%$$ 1. Test data structure
  verifyEqual(test_case, size(timestamps), [1, 3]);
  verifyEqual(test_case, class(timestamps), 'cell');
  verifyEqual(test_case, size(data), [1, 3]);
  verifyEqual(test_case, class(data), 'cell');

  %%%%% 2. Test values
  verifyEqual(test_case, timestamps{1}, [0.1349; 0.1385; 0.1604; 0.5421; 0.9435; 1.2480; 2.2508; 2.4426], "AbsTol", 0.001);
  verifyEqual(test_case, data{1}, ["65280"; "65296"; "65280"; "65344"; "65349"; "65344"; "65350"; "65382"]);

  % 2. Read 'marker' - one channel
  [timestamps, data] = reader.readevents_epochsamples_native('marker',...
    { 'digital_input_port' },...
    { filename }, 1, 0, 100);

  %%%%% 1. Test data structure
  verifyEqual(test_case, size(timestamps), [8, 1]);
  verifyEqual(test_case, class(timestamps), 'double');
  verifyEqual(test_case, size(data), [8, 1]);
  verifyEqual(test_case, class(data), 'string');

  %%%%% 2. Test values
  verifyEqual(test_case, timestamps, [0.1349; 0.1385; 0.1604; 0.5421; 0.9435; 1.2480; 2.2508; 2.4426], "AbsTol", 0.001);
  verifyEqual(test_case, data, ["65280"; "65296"; "65280"; "65344"; "65349"; "65344"; "65350"; "65382"]);

  % 3. Read 'event' - many channels
  [timestamps, data] = reader.readevents_epochsamples_native('event', { 'ch1#0', 'ch1#255' }, { filename }, 1, 0, 0.4);

  %%%%% 1. Test data structure
  verifyEqual(test_case, size(timestamps), [1, 2]);
  verifyEqual(test_case, class(timestamps), 'cell');
  verifyEqual(test_case, size(data), [1, 2]);
  verifyEqual(test_case, class(data), 'cell');

  %%%%% 2. Test values
  verifyEqual(test_case, timestamps{2}, [0.2761; 0.3508], "AbsTol", 0.001);
  verifyEqual(test_case, data{2}, ["1"; "1"]);

  % 4. Read 'event' - one channel
  [timestamps, data] = reader.readevents_epochsamples_native('event', { 'ch1#255' }, { filename }, 1, 0, 0.4);
  verifyEqual(test_case, timestamps, [0.2761; 0.3508], "AbsTol", 0.001);
  verifyEqual(test_case, data, ["1"; "1"]);
end

function test_read_intan(test_case)
  filename = utils_get_example('example.rhd');

  % Set up intan
  intan_reader = ndr.reader('intan');
  [intan_data, intan_time] = intan_reader.read({ filename }, 'A000+A001', { 'useSamples', 1, 's0', 5, 's1', 8 });

  % Set up neo
  neo_reader = ndr.reader('neo');
  [neo_data, neo_time] = neo_reader.read({ filename }, { 'A-000', 'A-001' }, { 'useSamples', 1, 's0', 5, 's1', 8 });

  % Tests
  verifyEqual(test_case, intan_data, neo_data, "AbsTol", 0.001);
  verifyEqual(test_case, intan_time, neo_time, "AbsTol", 0.001);
end

function test_getchannelsepoch_blackrock(test_case)
  filename = utils_get_example('example_2.ns2');

  % Set up neo
  reader = ndr.reader('neo');
  channels = reader.getchannelsepoch({ filename }, 'all');

  % Tests
  verifyEqual(test_case, channels(1), struct('name', 'ainp9',  'type', 'analog_input'));
  verifyEqual(test_case, channels(2), struct('name', 'ainp10', 'type', 'analog_input'));
  verifyEqual(test_case, numel(channels), 6);
end

function test_getchannelsepoch_blackrock2(test_case)
  filename = utils_get_example('example_1.ns2');

  % Set up neo
  reader = ndr.reader('neo');
  channels = reader.getchannelsepoch({ filename }, 'all');

  % Tests
  verifyEqual(test_case, channels(1), struct('name', 'ch1#0',   'type', 'event'));
  verifyEqual(test_case, channels(2), struct('name', 'ch1#255', 'type', 'event'));
  verifyEqual(test_case, channels(3), struct('name', 'ch2#0',   'type', 'event'));
  verifyEqual(test_case, channels(325), struct('name', 'digital_input_port',     'type', 'marker'));
  verifyEqual(test_case, channels(326), struct('name', 'serial_input_port',      'type', 'marker'));
  verifyEqual(test_case, channels(327), struct('name', 'analog_input_channel_1', 'type', 'marker'));
  verifyEqual(test_case, numel(channels), 332);
end

function test_readchannels_epochsamples_blackrock(test_case)
  filename = utils_get_example('example_2.ns2');

  % Set up neo
  reader = ndr.reader('neo');

  % Tests
  % 1. Test 'analog_input' channel
  data = reader.readchannels_epochsamples('smth', { 'ainp9', 'ainp10' }, { filename }, 1, 1, 3);
  verifyEqual(test_case, data, [137 761; 125 747; 110 733]);
  % 2. Test 'time' channel
  time = reader.readchannels_epochsamples('time', { 'ainp9', 'ainp10' }, { filename }, 1, 1, 3);
  verifyEqual(test_case, time, [0; 0.001; 0.002], "AbsTol", 0.0000001);
end

function test_getchannelsepoch_intan(test_case)
  filename = utils_get_example('example.rhd');

  % Set up intan
  intan_reader = ndr.reader('intan');
  intan_channels = intan_reader.getchannelsepoch({ filename }, 1);

  % Set up neo
  neo_reader = ndr.reader('neo');
  neo_channels = neo_reader.getchannelsepoch({ filename }, 'all');

  % Tests
  % 1. Note that intan and neo return different channel names
  verifyEqual(test_case, intan_channels(1).name, 'ai1');
  verifyEqual(test_case, neo_channels(1).name, 'A-000');
  % 2. Intan and neo return the same number of channels
  verifyEqual(test_case, numel(intan_channels), 36);
  verifyEqual(test_case, numel(neo_channels), 36);
end

function test_getchannelsepoch_ced(test_case)
  filename = utils_get_example('example.smr');

  % Set up ced
  ced_reader = ndr.reader('smr');
  ced_channels = ced_reader.getchannelsepoch({ filename }, 1);

  % Set up neo
  neo_reader = ndr.reader('neo');
  neo_channels = neo_reader.getchannelsepoch({ filename }, 'all');

  % Tests
  % Note that neo returns a lot fewer channels!
  verifyEqual(test_case, numel(ced_channels), 14);
  verifyEqual(test_case, numel(neo_channels), 3);
end

function test_readchannels_epochsamples_intan(test_case)
  filename = utils_get_example('example.rhd');

  % Set up intan
  intan_reader = ndr.reader('intan');

  % Set up neo
  neo_reader = ndr.reader('neo');

  % Tests
  % 1. Test 'analog_input' channel
  intan_data = intan_reader.readchannels_epochsamples('ai', [ 1, 2 ], { filename }, 1, 1, 10);
  neo_data = neo_reader.readchannels_epochsamples('smth', { 'A-000', 'A-001' }, { filename }, 1, 1, 10);
  verifyEqual(test_case, intan_data, neo_data, "AbsTol", 0.001);
  % 2. Test 'time' channel
  intan_time = intan_reader.readchannels_epochsamples('time', [ 1, 2 ], { filename }, 1, 1, 10);
  neo_time = neo_reader.readchannels_epochsamples('time', { 'A-000', 'A-001' }, { filename }, 1, 1, 10);
  verifyEqual(test_case, intan_time, neo_time, "AbsTol", 0.0000001);
end


% Utils
function utils_disp_channels(channels)
  for i=1:numel(channels)
    disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
  end
end

function utils_disp_channelstruct(channelstruct)
  for i=1:numel(channelstruct)
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
