classdef TestSpikegadgetsRecConfig < matlab.unittest.TestCase
    % TESTSPIKEGADGETSRECCONFIG - Regression tests for
    % ndr.format.spikegadgets.read_rec_config temp-file handling.
    %
    % The parser previously extracted the .rec XML header to a predictable
    % randi()-derived name in a shared temp directory and deleted it only on
    % success, leaking a file on any parse error. The fix parses the XML from
    % memory and touches no disk. These tests assert that neither a successful
    % parse nor a forced parse failure leaves any residue in the test path.

    methods (Static)
        function names = snapshotTestpath()
            ndr.globals;
            global ndr_globals; %#ok<GVMIS>
            p = ndr_globals.path.testpath;
            if isfolder(p)
                d = dir(p);
                names = sort({d(~[d.isdir]).name});
            else
                names = {};
            end
        end
    end

    methods (Test)
        function testConfigLeavesNoTempFileOnSuccess(testCase)
            % A successful parse of the checked-in example.rec must not create
            % any file in the test path.
            recfile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rec');
            testCase.assumeTrue(isfile(recfile), ...
                'example.rec not available; skipping.');
            before = TestSpikegadgetsRecConfig.snapshotTestpath();
            ndr.format.spikegadgets.read_rec_config(recfile);
            after = TestSpikegadgetsRecConfig.snapshotTestpath();
            testCase.verifyEqual(after, before, ...
                'read_rec_config left a file in the test path on success.');
        end

        function testConfigLeavesNoTempFileOnParseError(testCase)
            % A malformed config must raise AND leave no residue (previously the
            % temp file leaked because delete() ran only after a good parse).
            d = fullfile(tempdir, ['ndr_sg_cfg_' char(java.util.UUID.randomUUID)]);
            mkdir(d);
            testCase.addTeardown(@() rmdir(d,'s'));
            badrec = fullfile(d,'bad.rec');
            fid = fopen(badrec,'w');
            % mismatched tags + trailing content -> not well-formed XML
            fwrite(fid, ['<junk></Configuration>XXXX'], 'char');
            fclose(fid);

            before = TestSpikegadgetsRecConfig.snapshotTestpath();
            testCase.verifyError( ...
                @() ndr.format.spikegadgets.read_rec_config(badrec), ?MException);
            after = TestSpikegadgetsRecConfig.snapshotTestpath();
            testCase.verifyEqual(after, before, ...
                'read_rec_config leaked a temp file after a parse error.');
        end
    end
end
