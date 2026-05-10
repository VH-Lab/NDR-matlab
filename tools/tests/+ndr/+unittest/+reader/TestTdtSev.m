classdef TestTdtSev < matlab.unittest.TestCase
    % TESTTDTSEV - Unit tests for ndr.reader.tdt_sev
    %
    % These tests cover behaviour that does not require a real TDT
    % recording on disk. Tests needing example data should be added
    % separately.

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % tdt_sev names channels using header(i).chan, the TDT
            % hardware channel number (tdt_sev.m:80), so the convention
            % is 'physical' for every channel type.
            reader = ndr.reader.tdt_sev();
            for t = {'analog_in','time'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'physical', ...
                    sprintf('tdt_sev %s convention should be ''physical''', t{1}));
            end
        end
    end
end
