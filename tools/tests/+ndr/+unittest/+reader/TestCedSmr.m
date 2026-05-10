classdef TestCedSmr < matlab.unittest.TestCase
    % TESTCEDSMR - Unit tests for ndr.reader.ced_smr
    %
    % These tests cover behaviour that does not require a real .smr file
    % on disk (e.g. the declared channel-labeling convention). Tests
    % needing example data should be added separately.

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % ced_smr names channels using the Spike2 channel number from
            % the file header (ced_smr.m:61), so it must declare
            % 'physical' for every channel type.
            reader = ndr.reader.ced_smr();
            for t = {'analog_in','digital_in','time','event','marker'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'physical', ...
                    sprintf('ced_smr %s convention should be ''physical''', t{1}));
            end
        end
    end
end
