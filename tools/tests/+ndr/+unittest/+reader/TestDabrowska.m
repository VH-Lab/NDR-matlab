classdef TestDabrowska < matlab.unittest.TestCase
    % TESTDABROWSKA - Unit tests for ndr.reader.dabrowska

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % dabrowska hard-codes ai1/ao1 (dabrowska.m:148-154) and
            % inherits the base default of 'indexed'. Lock the contract.
            reader = ndr.reader.dabrowska();
            for t = {'analog_in','analog_out','time'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'indexed', ...
                    sprintf('dabrowska %s convention should be ''indexed''', t{1}));
            end
        end
    end
end
