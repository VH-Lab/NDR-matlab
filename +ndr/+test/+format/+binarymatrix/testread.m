function b = testread()
% TESTREAD - test reading binarymatix format
%
% B = TESTREAD()
%
% Reads information from the test file ndr.test.format.binarymatrix.testfile.bin.
%
% If any test fails, an error with an informative error message is given.
% Otherwise B is 1.
%

b = 1;

filepath = fileparts(mfilename('fullpath'));

filename = fullfile(filepath,'testfile.bin');

A = uint32(1:100); % the actual data

 % assume 10 channels, 10 samples

[data_10,total_samples,s0_out,s1_out] = ndr.format.binarymatrix.read(filename, 10, 1:10, -inf, inf,'dataType','uint32');

data_expected_10 = reshape(A,10,100/10)';

assert(isequal(data_expected_10,data_10),'10 samples of 10 channels test failed');
assert(total_samples==10,'total_samples was not 10 in 10 samples of 10 channels test');
assert(s0_out==1,'10 samples, 10 channels, s0_out was not 1.');
assert(s1_out==10,'10 samples, 10 channels, s1_out was not 10.');

[data_10bw,total_samples,s0_out,s1_out] = ndr.format.binarymatrix.read(filename, 10, 10:-1:1, -inf, inf,'dataType','uint32');

data_expected_10bw = data_expected_10(:,end:-1:1);

assert(isequal(data_expected_10bw,data_10bw),'10 samples of 10 channels backward test failed');
assert(total_samples==10,'total_samples was not 10 in 10 samples of 10 channels test');
assert(s0_out==1,'10 samples, 10 channels, s0_out was not 1.');
assert(s1_out==10,'10 samples, 10 channels, s1_out was not 10.');

[data_5,total_samples,s0_out,s1_out] = ndr.format.binarymatrix.read(filename, 5, 1:5, -inf, inf,'dataType','uint32');

data_expected_5 = reshape(A,5,100/5)';

assert(isequal(data_expected_5,data_5),'20 samples of 5 channels test failed');
assert(total_samples==20,'total_samples was not 20 in 20 samples of 5 channels test');
assert(s0_out==1,'20 samples, 5 channels test, s0_out was not 1.');
assert(s1_out==20,'20 samples, 5 channels test, s1_out was not 20.');

[data_2,total_samples,s0_out,s1_out] = ndr.format.binarymatrix.read(filename, 2, 1:2, -inf, inf,'dataType','uint32');

data_expected_2 = reshape(A,2,100/2)';

assert(isequal(data_expected_2,data_2),'50 samples of 2 channels test failed');
assert(total_samples==50,'total_samples was not 50 in 50 samples of 2 channels test');
assert(s0_out==1,'50 samples, 2 channels test, s0_out was not 1.');
assert(s1_out==50,'50 samples, 2 channels test, s1_out was not 50.');

 % now try reading samples in the middle

[data_10m,total_samples,s0_out,s1_out] = ndr.format.binarymatrix.read(filename, 10, 1:10, 5, 7,'dataType','uint32');

data_expected_10m = data_expected_10(5:7,:);

assert(isequal(data_expected_10,data_10),'samples 5..7 of 10 channels test failed');
assert(total_samples==10,'total_samples was not 10 in 10 samples of 10 channels test');
assert(s0_out==5,'samples 5..7, 10 channels, s0_out was not 5.');
assert(s1_out==7,'samples 5..7, 10 channels, s1_out was not 7.');


