function tests = automatedTest
  tests = functiontests(localfunctions);
end

function setupOnce(test_case)
  ndr_Init();
end

% Note that if we want to read the event channel e22, we should pass 22 as a channel argument, etc.
%
% Channel found (1/14): ai1 of type analog_in
% Channel found (2/14): mk20 of type mark
% Channel found (3/14): ai21 of type analog_in
% Channel found (4/14): e22 of type event
% Channel found (5/14): e23 of type event
% Channel found (6/14): e24 of type event
% Channel found (7/14): e25 of type event
% Channel found (8/14): e26 of type event
% Channel found (9/14): e27 of type event
% Channel found (10/14): e28 of type event
% Channel found (11/14): e29 of type event
% Channel found (12/14): text30 of type text
% Channel found (13/14): mk31 of type mark
% Channel found (14/14): mk32 of type mark
function test_readevents_epochsamples_native_marker(test_case)
  filename = utils_get_example('example.smr');
  reader = ndr.reader('smr');
 
  % 1. Read 'marker' - many channels
  [timestamps, data] = reader.readevents_epochsamples_native('marker', [30, 31, 32], { filename }, 1, 0, 100);

  verifyEqual(test_case, size(timestamps), [1, 3]);
  verifyEqual(test_case, class(timestamps), 'cell');
  verifyEqual(test_case, size(data), [1, 3]);
  verifyEqual(test_case, class(data), 'cell');

  t = cell([1 3]);
  t{1}=[9.4662600000000001;20.25515;31.027609999999999;41.800109999999997;52.572579999999995;63.353249999999996;74.133929999999992;84.91458999999999;95.678879999999992];
  t{2}=[12.366239999999999;23.146909999999998;33.919399999999996;44.700060000000001;55.472559999999994;66.253209999999996;77.025689999999997;87.806370000000001;98.578849999999989];
  t{3}=[9.4653299999999998;20.239719999999998;31.016109999999998;41.792499999999997;52.568889999999996;63.345279999999995;74.122669999999999;84.899059999999992;95.675449999999998];

  d = cell([1 3]);
  d{1}=reshape(char([49 52 56 49 55 57 54 49 50 50 0 0 49 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]), [9 80]);
  d{2}=uint8([65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0;65 0 0 0]);
  d{3}=uint8([12 0 0 0;4 0 0 0;8 0 0 0;11 0 0 0;7 0 0 0;9 0 0 0;6 0 0 0;1 0 0 0;2 0 0 0]);

  verifyEqual(test_case, timestamps, t);
  verifyEqual(test_case, data, d);

  % 2. Read 'marker' - one channel
  [timestamps, data] = reader.readevents_epochsamples_native('marker', [30], { filename }, 1, 0, 100);

  verifyEqual(test_case, size(timestamps), [9, 1]);
  verifyEqual(test_case, class(timestamps), 'double');
  verifyEqual(test_case, size(data), [9, 80]);
  verifyEqual(test_case, class(data), 'char');

  t = [9.4662600000000001;20.25515;31.027609999999999;41.800109999999997;52.572579999999995;63.353249999999996;74.133929999999992;84.91458999999999;95.678879999999992];
  d = reshape(char([49 52 56 49 55 57 54 49 50 50 0 0 49 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]), [9 80]);
  verifyEqual(test_case, timestamps, t);
  verifyEqual(test_case, data, d);
end

function test_readevents_epochsamples_native_event(test_case)
  filename = utils_get_example('example.smr');
  reader = ndr.reader('smr');

  % 1. Read 'event' - many channels
  [timestamps, data] = reader.readevents_epochsamples_native('event', [22, 23, 28, 29], { filename }, 1, 0, 10);
  verifyEqual(test_case, size(timestamps), [1, 4]);
  verifyEqual(test_case, class(timestamps), 'cell');
  verifyEqual(test_case, size(data), [1, 4]);
  verifyEqual(test_case, class(data), 'cell');

  t = cell([1 4]);
  t{1}=[9.4653299999999998];
  t{2}=[9.4793299999999991;9.4963300000000004;9.5123300000000004;9.5293299999999999;9.5453299999999999;9.5623299999999993;9.5793299999999988;9.5953299999999988;9.61233;9.6283300000000001;9.6453299999999995;9.6613299999999995;9.678329999999999;9.6953300000000002;9.7113300000000002;9.7283399999999993;9.7443399999999993;9.7613399999999988;9.7773399999999988;9.79434;9.8113399999999995;9.8273399999999995;9.844339999999999;9.860339999999999;9.8773400000000002;9.8943399999999997;9.9103399999999997;9.9273399999999992;9.9433399999999992;9.9603400000000004;9.9763400000000004;9.9933399999999999];
  t{3}=[];
  t{4}=[];
  verifyEqual(test_case, timestamps, t);
  verifyEqual(test_case, data, t);

  % 2. Read 'event' - one channel
  [timestamps, data] = reader.readevents_epochsamples_native('event', [23], { filename }, 1, 0, 10);
  t = [9.4793299999999991;9.4963300000000004;9.5123300000000004;9.5293299999999999;9.5453299999999999;9.5623299999999993;9.5793299999999988;9.5953299999999988;9.61233;9.6283300000000001;9.6453299999999995;9.6613299999999995;9.678329999999999;9.6953300000000002;9.7113300000000002;9.7283399999999993;9.7443399999999993;9.7613399999999988;9.7773399999999988;9.79434;9.8113399999999995;9.8273399999999995;9.844339999999999;9.860339999999999;9.8773400000000002;9.8943399999999997;9.9103399999999997;9.9273399999999992;9.9433399999999992;9.9603400000000004;9.9763400000000004;9.9933399999999999];
  verifyEqual(test_case, timestamps, t);
  verifyEqual(test_case, data, t);
end

% Utils

function path_to_file = utils_get_example(filename)
  ndr.globals();
  example_dir = [ndr_globals.path.path filesep 'example_data'];
  path_to_file = [example_dir filesep filename];
end
