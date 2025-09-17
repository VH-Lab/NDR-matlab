classdef TestTextSignal < matlab.unittest.TestCase
    properties
        numeric_file
        datestamp_file
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            % Find the project root using the ndr.fun.ndrpath function
            project_root = ndr.fun.ndrpath();
            testCase.numeric_file = fullfile(project_root, 'example_data', 'textSignal', 'example_numeric.tsv');
            testCase.datestamp_file = fullfile(project_root, 'example_data', 'textSignal', 'example_datestamp.tsv');
        end
    end

    methods (Test)
        function testReadHeaderNumeric(testCase)
            header = ndr.format.textSignal.readHeader(testCase.numeric_file);
            testCase.verifyEqual(header.num_channels, 3);
            testCase.verifyEqual(header.time_units, 'numeric');
        end

        function testReadHeaderDatestamp(testCase)
            header = ndr.format.textSignal.readHeader(testCase.datestamp_file);
            testCase.verifyEqual(header.num_channels, 3);
            testCase.verifyEqual(header.time_units, 'datestamp');
        end

        function testReadDataNumericDefault(testCase)
            % Test default behavior, read all data for channel 1
            [D, T] = ndr.format.textSignal.readData(testCase.numeric_file, [1], 0, 5);

            % Expected T should include all event times for Ch 1 between 0 and 5, plus 0 and 5
            % Events for Ch 1: (0, Set 5), (1, RAMP 5->10 @ 2), (2.5, NONE), (5, Set 0)
            % Times: 0, 1, 2, 2.5, 5
            expected_T = [0, 1, 2, 2.5, 5];
            testCase.verifyEqual(T, expected_T);

            % Expected D:
            % t=0: Set 5 -> 5
            % t=1: RAMP start -> 5
            % t=2: RAMP end -> 10
            % t=2.5: NONE, prev value is 10
            % t=5: Set 0 -> 0
            expected_D1 = [5, 5, 10, 10, 0];
            testCase.verifyEqual(D{1}, expected_D1, 'AbsTol', 1e-6);
        end

        function testReadDataNumericRange(testCase)
            % Test reading a specific range for channel 2
            [D, T] = ndr.format.textSignal.readData(testCase.numeric_file, [2], 1, 4.5);
            % Events for Ch 2: (1.5, Set -2), (4, RAMP -2 -> -5 @ 5)
            % Times in range [1, 4.5]: 1, 1.5, 4, 4.5
            expected_T = [1, 1.5, 4, 4.5];
            testCase.verifyEqual(T, expected_T);

            % Expected D:
            % t=1: No event yet -> 0
            % t=1.5: Set -2 -> -2
            % t=4: RAMP start -> -2
            % t=4.5: halfway through ramp -> -3.5
            expected_D2 = [0, -2, -2, -3.5];
            testCase.verifyEqual(D{1}, expected_D2, 'AbsTol', 1e-6);
        end

        function testReadDataRampInterpolation(testCase)
            [D, T] = ndr.format.textSignal.readData(testCase.numeric_file, [1], 1.5, 1.5);
            % At t=1.5, channel 1 is on a ramp from 5 (at t=1) to 10 (at t=2)
            % Value should be 5 + (1.5-1.0)/(2.0-1.0) * (10-5) = 7.5
            testCase.verifyEqual(T, 1.5);
            testCase.verifyEqual(D{1}, 7.5, 'AbsTol', 1e-6);
        end

        function testReadData_dT(testCase)
            [D, T] = ndr.format.textSignal.readData(testCase.numeric_file, [1], 0, 2, 'dT', 0.5);
            expected_T = 0:0.5:2;
            % t=0.0, val=5
            % t=0.5, val=5
            % t=1.0, val=5
            % t=1.5, val=7.5
            % t=2.0, val=10
            expected_D = [5, 5, 5, 7.5, 10];
            testCase.verifyEqual(T, expected_T);
            testCase.verifyEqual(D{1}, expected_D, 'AbsTol', 1e-6);
        end

        function testReadData_timestamps(testCase)
            timestamps = [0.5, 1.5, 2.5, 4.5];
            [D, T] = ndr.format.textSignal.readData(testCase.numeric_file, [1, 2], -inf, inf, 'timestamps', timestamps);

            testCase.verifyEqual(T, timestamps);

            % Channel 1:
            % t=0.5 -> 5 (from Set at t=0)
            % t=1.5 -> 7.5 (from RAMP)
            % t=2.5 -> 10 (NONE, gets value from end of RAMP at t=2)
            % t=4.5 -> 10 (NONE at 2.5 is still the last event)
            expected_D1 = [5, 7.5, 10, 10];
            testCase.verifyEqual(D{1}, expected_D1, 'AbsTol', 1e-6);

            % Channel 2:
            % t=0.5 -> 0 (no events)
            % t=1.5 -> -2 (Set at t=1.5)
            % t=2.5 -> -2 (Set at t=1.5 is last event)
            % t=4.5 -> -3.5 (from RAMP)
            expected_D2 = [0, -2, -2, -3.5];
            testCase.verifyEqual(D{2}, expected_D2, 'AbsTol', 1e-6);
        end

        function testReadDataDatestamp(testCase)
            t0_str = '2024-07-17T12:00:00.000Z';
            t1_str = '2024-07-17T12:00:05.000Z';
            t0 = datetime(t0_str, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC');
            t1 = datetime(t1_str, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'TimeZone', 'UTC');

            [D, T] = ndr.format.textSignal.readData(testCase.datestamp_file, [1], posixtime(t0), posixtime(t1));

            testCase.verifyTrue(isdatetime(T));
            testCase.verifyEqual(numel(T), 5); % t0, t1, and 3 events in between
            testCase.verifyEqual(T(1), t0);
            testCase.verifyEqual(T(end), t1);
        end

    end
end
