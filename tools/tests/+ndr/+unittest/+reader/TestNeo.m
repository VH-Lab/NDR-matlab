classdef TestNeo < matlab.unittest.TestCase
    % TESTNEO - Unit tests for ndr.reader.neo
    %
    % These tests cover behaviour that does not need the Neo Python
    % backend to be reachable (e.g. constructor and the declared
    % channel-labeling convention). Tests that round-trip data through
    % Python should be added separately and gated on Python
    % availability.

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % neo's getchannelsepoch passes the device-native channel
            % name through verbatim from the underlying Neo IO class
            % (neo.m:21), so the convention is 'native' for every type.
            reader = ndr.reader.neo();
            for t = {'analog_in','digital_in','time','event'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'native', ...
                    sprintf('neo %s convention should be ''native''', t{1}));
            end
        end
    end
end
