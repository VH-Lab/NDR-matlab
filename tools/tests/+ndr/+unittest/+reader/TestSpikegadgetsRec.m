classdef TestSpikegadgetsRec < matlab.unittest.TestCase
    % TESTSPIKEGADGETSREC - Unit tests for ndr.reader.spikegadgets_rec
    %
    % These tests cover behaviour that does not require a real .rec file
    % on disk. Tests needing example data should be added separately.

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % spikegadgets_rec parses a hardware index out of the native
            % 'Ain%d'/'Din%d'/etc. identifier and uses it as the channel
            % suffix (spikegadgets_rec.m:56,62,72), so it declares
            % 'physical' for every channel type.
            reader = ndr.reader.spikegadgets_rec();
            for t = {'analog_in','analog_out','digital_in','digital_out','time'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'physical', ...
                    sprintf('spikegadgets_rec %s convention should be ''physical''', t{1}));
            end
        end
    end
end
