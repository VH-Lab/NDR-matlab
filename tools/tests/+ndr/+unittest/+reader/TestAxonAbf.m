classdef TestAxonAbf < matlab.unittest.TestCase
    % TESTAXONABF - Unit tests for ndr.reader.axon_abf
    %
    % Verifies the functionality of samples2times and times2samples
    % using a mock reader to simulate gaps in recording.

    methods (Test)
        function testSamples2Times(testCase)
            % Define a time vector with a gap (simulating concatenated sweeps)
            % Sweep 1: 0, 0.1, 0.2
            % Sweep 2: 0.4, 0.5 (Gap of 0.2 between 0.2 and 0.4, assuming dt=0.1)
            t_vec = [0 0.1 0.2 0.4 0.5]';
            reader = ndr.unittest.reader.MockAxonAbf(t_vec);

            % Test exact samples
            s = [1 2 3 4 5];
            t = reader.samples2times('ai', 1, {}, 1, s);

            % Ensure expected has same shape as output/input (interp1 respects input shape)
            expected_t = t_vec(s);
            % Force shape match to be robust
            expected_t = reshape(expected_t, size(s));

            testCase.verifyEqual(t, expected_t, 'AbsTol', 1e-9);

            % Test interpolation within a sweep
            s_interp = 1.5; % Between sample 1 (0.0) and 2 (0.1)
            t_interp = reader.samples2times('ai', 1, {}, 1, s_interp);
            expected = 0.05;
            testCase.verifyEqual(t_interp, expected, 'AbsTol', 1e-9);

            % Test interpolation across gap
            % s=3 is t=0.2, s=4 is t=0.4
            % s=3.5 should linearly interpolate to 0.3
            t_gap = reader.samples2times('ai', 1, {}, 1, 3.5);
            testCase.verifyEqual(t_gap, 0.3, 'AbsTol', 1e-9);
        end

        function testTimes2Samples(testCase)
            t_vec = [0 0.1 0.2 0.4 0.5]';
            reader = ndr.unittest.reader.MockAxonAbf(t_vec);

            % Test exact times
            t = [0 0.1 0.2 0.4 0.5];
            s = reader.times2samples('ai', 1, {}, 1, t);
            expected_s = [1 2 3 4 5];
            % Verify s matches expected_s (row vector)
            testCase.verifyEqual(s, expected_s);

            % Test interpolation & rounding
            % t=0.05 -> s=1.5 -> round to 2
            s_round = reader.times2samples('ai', 1, {}, 1, 0.05);
            testCase.verifyEqual(s_round, 2);

            % t=0.04 -> s=1.4 -> round to 1
            s_round = reader.times2samples('ai', 1, {}, 1, 0.04);
            testCase.verifyEqual(s_round, 1);

            % Test across gap
            % t=0.3 -> s=3.5 -> round to 4
            s_gap = reader.times2samples('ai', 1, {}, 1, 0.3);
            testCase.verifyEqual(s_gap, 4);
        end
    end
end
