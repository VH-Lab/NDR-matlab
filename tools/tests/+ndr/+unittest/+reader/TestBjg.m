classdef TestBjg < matlab.unittest.TestCase
    % TESTBJG - Unit tests for ndr.reader.bjg

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % bjg builds names with a 1-based loop counter (bjg.m:68)
            % and inherits the base default of 'indexed'. Lock the
            % contract.
            reader = ndr.reader.bjg();
            for t = {'analog_in','time'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'indexed', ...
                    sprintf('bjg %s convention should be ''indexed''', t{1}));
            end
        end
    end
end
