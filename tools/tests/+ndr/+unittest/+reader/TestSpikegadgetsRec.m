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

        function testGetChannelsEpochRunsAndListsChannels(testCase)
            % Regression smoke test for the nTrode loop-bound fix: enumerating
            % channels must not crash and must list the time channel plus the
            % analog_in trode channels. (The exact non-tetrode group-size case
            % -- a 2-channel and an 8-channel nTrode -- needs a synthetic full
            % Trodes-XML .rec fixture; add that to assert all 10 channels
            % appear for heterogeneous group sizes.)
            recfile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rec');
            testCase.assumeTrue(isfile(recfile), 'example.rec not available; skipping.');
            reader = ndr.reader.spikegadgets_rec();
            channels = reader.getchannelsepoch({recfile}, 1);
            testCase.verifyNotEmpty(channels);
            types = {channels.type};
            testCase.verifyTrue(any(strcmp(types,'time')), 'expected a time channel');
            testCase.verifyTrue(any(strcmp(types,'analog_in')), 'expected analog_in channels');
        end

        function testT0T1IsFlooredAndConsistent(testCase)
            % Regression for the epoch-duration fix: t0==0, t1 finite/positive,
            % and the implied sample count is an integer (floored).
            recfile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rec');
            testCase.assumeTrue(isfile(recfile), 'example.rec not available; skipping.');
            reader = ndr.reader.spikegadgets_rec();
            t0t1 = reader.t0_t1({recfile}, 1);
            sr = reader.samplerate({recfile}, 1, 'analog_in', 1);
            testCase.verifyEqual(t0t1{1}(1), 0, 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(t0t1{1}(2), 0);
            testCase.verifyTrue(isfinite(t0t1{1}(2)));
            implied = t0t1{1}(2)*sr + 1; % = total_samples
            testCase.verifyEqual(implied, round(implied), 'AbsTol', 1e-6, ...
                'total_samples must be an integer (floored).');
        end
    end
end
