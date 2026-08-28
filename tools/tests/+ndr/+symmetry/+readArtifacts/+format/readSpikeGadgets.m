classdef readSpikeGadgets < matlab.unittest.TestCase
    % READSPIKEGADGETS - Verify SpikeGadgets format-layer symmetry artifacts.
    %
    % Parameterized over both artifact sources, so one class checks parity in
    % both directions. Skips when the artifact directory for a source is absent.
    %
    % A .rec is a stream of fixed-size packets. Both the offset of the first
    % packet and the stride between packets must be exact; either being wrong
    % yields in-range values and correctly shaped arrays, so only a
    % byte-for-byte comparison against the other port catches it. That is what
    % this class is for. Tolerances are tight for the same reason -- these are
    % int16 codes scaled by a constant, not measurements, so the two ports
    % should agree to floating-point noise and nothing looser.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadSpikeGadgetsArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'format', 'readSpikeGadgets', 'testReadSpikeGadgetsArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            rec_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rec');
            testCase.assumeTrue(isfile(rec_file), ...
                'Example .rec file not available; skipping readArtifacts test.');

            config = ndr.format.spikegadgets.read_rec_config(rec_file);
            samplingRate = str2double(config.samplingRate);

            % --- metadata parity ---
            metaFile = fullfile(artifactDir, 'metadata.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                testCase.verifyEqual(str2double(config.numChannels), ...
                    expectedMeta.numChannels, ...
                    ['numChannels mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(str2double(config.headerSize), ...
                    expectedMeta.headerSize, ...
                    ['headerSize mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(samplingRate, expectedMeta.samplingRate, ...
                    'AbsTol', 1e-9, ...
                    ['samplingRate mismatch against ' SourceType ' artifacts.']);
            end

            % --- sample parity ---
            readFile = fullfile(artifactDir, 'readData.json');
            if ~isfile(readFile)
                disp(['readData.json not found in ' SourceType '. Skipping sample check.']);
                return;
            end
            fid = fopen(readFile, 'r');
            expectedRead = jsondecode(fread(fid, inf, '*char')');
            fclose(fid);

            [data1, ts1] = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 1, samplingRate, config.headerSize, 1, 100);
            testCase.verifyEqual(double(data1(:))', ...
                expectedRead.trode_channel_1_samples_1_100(:)', 'AbsTol', 1e-9, ...
                ['Trode channel 1 samples 1-100 mismatch against ' SourceType '. ' ...
                 'A mismatch here means the two ports disagree on where packet ' ...
                 'data begins or how wide a packet is.']);
            testCase.verifyEqual(double(ts1(:))', ...
                expectedRead.trode_timestamps_samples_1_100(:)', 'AbsTol', 1e-9, ...
                ['Trode timestamps 1-100 mismatch against ' SourceType '.']);

            data2 = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 1, samplingRate, config.headerSize, 1001, 1100);
            testCase.verifyEqual(double(data2(:))', ...
                expectedRead.trode_channel_1_samples_1001_1100(:)', 'AbsTol', 1e-9, ...
                ['Trode channel 1 samples 1001-1100 mismatch against ' SourceType '. ' ...
                 'An error in the seek to s0 scales with s0, so this can fail ' ...
                 'while the read from sample 1 passes.']);

            data3 = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 2, samplingRate, config.headerSize, 1, 100);
            testCase.verifyEqual(double(data3(:))', ...
                expectedRead.trode_channel_2_samples_1_100(:)', 'AbsTol', 1e-9, ...
                ['Trode channel 2 samples 1-100 mismatch against ' SourceType '. ' ...
                 'A stride error that drifts onto a neighbouring channel shows ' ...
                 'up here.']);
        end
    end
end
