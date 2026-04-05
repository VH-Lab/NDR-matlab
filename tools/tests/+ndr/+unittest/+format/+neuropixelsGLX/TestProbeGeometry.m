classdef TestProbeGeometry < matlab.unittest.TestCase
%TESTPROBEGEOMETRY Unit tests for ndr.format.neuropixelsGLX.probeGeometry.
%
%   Tests probe geometry extraction from synthetic SpikeGLX .meta files
%   covering all supported code paths:
%     - snsGeomMap parsing (preferred path for newer SpikeGLX)
%     - imroTbl-based computation for NP 1.0 (type 0)
%     - imroTbl-based computation for NP 2.0 single shank (type 21)
%     - imroTbl-based computation for NP 2.0 four shank (type 24)
%
%   Example:
%       results = runtests('ndr.unittest.format.neuropixelsGLX.TestProbeGeometry');

    properties (SetAccess=protected)
        TempDir char = ''
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = fullfile(tempdir, ...
                ['ndr_pg_test_' char(java.util.UUID.randomUUID)]);
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    % --- Helper Methods ---

    methods (Access=private)

        function metafile = writeMetaFile(testCase, filename, fields)
        %WRITEMETAFILE Write a minimal .meta file from a cell array of
        %   {'key','value'; ...} pairs.
            metafile = fullfile(testCase.TempDir, filename);
            fid = fopen(metafile, 'w');
            testCase.assertNotEqual(fid, -1, 'Could not create meta file.');
            for i = 1:size(fields, 1)
                fprintf(fid, '%s=%s\n', fields{i,1}, fields{i,2});
            end
            fclose(fid);
        end

        function metafile = writeNP10Meta(testCase, n_chans, bank_values)
        %WRITENP10META Write a NP 1.0 .meta file with imroTbl (no snsGeomMap).
        %   bank_values is [n_chans x 1] array of bank indices (0,1,2).
            if nargin < 4
                bank_values = zeros(n_chans, 1);
            end
            imro = sprintf('(0,%d)', n_chans);
            for c = 0:(n_chans-1)
                imro = [imro, sprintf('(%d %d 0 500 250 1)', c, bank_values(c+1))]; %#ok<AGROW>
            end
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       num2str(n_chans + 1);
                'snsApLfSy',         sprintf('%d,0,1', n_chans);
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '512';
                'imDatPrb_type',     '0';
                'imDatPrb_sn',       '0000000000';
                'imroTbl',           imro;
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);
        end

        function metafile = writeNP20SSMeta(testCase, n_chans, elec_inds)
        %WRITENP20SSMETA Write a NP 2.0 single-shank .meta file.
        %   elec_inds is [n_chans x 1] array of electrode indices.
            imro = sprintf('(21,%d)', n_chans);
            for c = 0:(n_chans-1)
                imro = [imro, sprintf('(%d 0 0 %d)', c, elec_inds(c+1))]; %#ok<AGROW>
            end
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       num2str(n_chans + 1);
                'snsApLfSy',         sprintf('%d,0,1', n_chans);
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '8192';
                'imDatPrb_type',     '21';
                'imDatPrb_sn',       '0000000000';
                'imroTbl',           imro;
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);
        end

        function metafile = writeNP20_4SMeta(testCase, n_chans, shank_ids, elec_inds)
        %WRITENP20_4SMETA Write a NP 2.0 four-shank .meta file.
            imro = sprintf('(24,%d)', n_chans);
            for c = 0:(n_chans-1)
                imro = [imro, sprintf('(%d %d 0 0 %d)', c, shank_ids(c+1), elec_inds(c+1))]; %#ok<AGROW>
            end
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       num2str(n_chans + 1);
                'snsApLfSy',         sprintf('%d,0,1', n_chans);
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '8192';
                'imDatPrb_type',     '24';
                'imDatPrb_sn',       '0000000000';
                'imroTbl',           imro;
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);
        end

        function metafile = writeGeomMapMeta(testCase, n_chans, geommap_str)
        %WRITEGEOMMAPMETA Write a .meta file with ~snsGeomMap.
            imro = sprintf('(0,%d)', n_chans);
            for c = 0:(n_chans-1)
                imro = [imro, sprintf('(%d 0 0 500 250 1)', c)]; %#ok<AGROW>
            end
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       num2str(n_chans + 1);
                'snsApLfSy',         sprintf('%d,0,1', n_chans);
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '512';
                'imDatPrb_type',     '0';
                'imDatPrb_sn',       '0000000000';
                'imroTbl',           imro;
                '~snsGeomMap',       geommap_str;
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);
        end

    end

    % --- Test Methods ---

    methods (Test)

        % ---- Output structure validation ----

        function testOutputFieldsExist(testCase)
        %TESTOUTPUTFIELDSEXIST Verify all expected fields are present.
            metafile = testCase.writeNP10Meta(8);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            expected_fields = {'site_locations_leftright', ...
                'site_locations_frontback', 'site_locations_depth', ...
                'probe_model', 'manufacturer', 'shank_id', ...
                'contact_shape', 'contact_shape_width', ...
                'contact_shape_height', 'contact_shape_radius', ...
                'ndim', 'unit', 'has_planar_contour', ...
                'contour_x', 'contour_y'};

            for i = 1:numel(expected_fields)
                testCase.verifyTrue(isfield(pg, expected_fields{i}), ...
                    ['Missing field: ' expected_fields{i}]);
            end
        end

        function testOutputVectorSizes(testCase)
        %TESTOUTPUTVECTORSIZES Verify all per-channel fields are N x 1.
            n = 16;
            metafile = testCase.writeNP10Meta(n);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            testCase.verifySize(pg.site_locations_leftright, [n 1]);
            testCase.verifySize(pg.site_locations_frontback, [n 1]);
            testCase.verifySize(pg.site_locations_depth, [n 1]);
            testCase.verifySize(pg.shank_id, [n 1]);
            testCase.verifySize(pg.contact_shape_width, [n 1]);
            testCase.verifySize(pg.contact_shape_height, [n 1]);
            testCase.verifySize(pg.contact_shape_radius, [n 1]);
        end

        function testScalarFieldValues(testCase)
        %TESTSCALARFIELDVALUES Verify constant/scalar fields.
            metafile = testCase.writeNP10Meta(8);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            testCase.verifyEqual(pg.manufacturer, 'IMEC');
            testCase.verifyEqual(pg.contact_shape, 'square');
            testCase.verifyEqual(pg.ndim, 2);
            testCase.verifyEqual(pg.unit, 'um');
            testCase.verifyEqual(pg.has_planar_contour, 0);
            testCase.verifyEmpty(pg.contour_x);
            testCase.verifyEmpty(pg.contour_y);
            testCase.verifyEqual(pg.site_locations_frontback, zeros(8, 1));
            testCase.verifyEqual(pg.contact_shape_radius, zeros(8, 1));
        end

        % ---- NP 1.0 imroTbl path ----

        function testNP10BankZeroPositions(testCase)
        %TESTNP10BANKZEROPOSITIONS Verify NP 1.0 geometry for bank 0.
        %   Channels 0-7, bank 0 → electrodes 0-7.
        %     e0: row=0,col=0 → x=27, y=0   (even row)
        %     e1: row=0,col=1 → x=59, y=0   (even row)
        %     e2: row=1,col=0 → x=11, y=20  (odd row)
        %     e3: row=1,col=1 → x=43, y=20  (odd row)
        %     e4: row=2,col=0 → x=27, y=40  (even row)
        %     e5: row=2,col=1 → x=59, y=40  (even row)
        %     e6: row=3,col=0 → x=11, y=60  (odd row)
        %     e7: row=3,col=1 → x=43, y=60  (odd row)
            metafile = testCase.writeNP10Meta(8);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            expected_x = [27; 59; 11; 43; 27; 59; 11; 43];
            expected_y = [0; 0; 20; 20; 40; 40; 60; 60];

            testCase.verifyEqual(pg.site_locations_leftright, expected_x);
            testCase.verifyEqual(pg.site_locations_depth, expected_y);
        end

        function testNP10BankOnePositions(testCase)
        %TESTNP10BANKONEPOSITIONS Verify NP 1.0 with bank=1.
        %   Channel 0, bank 1 → electrode 384.
        %   e384: row=192,col=0 → row is even → x=27, y=192*20=3840
            banks = [1; 1; 0; 0];
            metafile = testCase.writeNP10Meta(4, banks);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            % chan 0 bank 1 → elec 384: row=192(even), col=0 → x=27, y=3840
            % chan 1 bank 1 → elec 385: row=192(even), col=1 → x=59, y=3840
            % chan 2 bank 0 → elec 2: row=1(odd), col=0 → x=11, y=20
            % chan 3 bank 0 → elec 3: row=1(odd), col=1 → x=43, y=20
            testCase.verifyEqual(pg.site_locations_leftright, [27; 59; 11; 43]);
            testCase.verifyEqual(pg.site_locations_depth, [3840; 3840; 20; 20]);
        end

        function testNP10ContactSize(testCase)
        %TESTNP10CONTACTSIZE Verify NP 1.0 has 12 um square contacts.
            metafile = testCase.writeNP10Meta(4);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            testCase.verifyEqual(pg.contact_shape_width, repmat(12, 4, 1));
            testCase.verifyEqual(pg.contact_shape_height, repmat(12, 4, 1));
            testCase.verifyEqual(pg.probe_model, 'Neuropixels 1.0');
        end

        function testNP10SingleShank(testCase)
        %TESTNP10SINGLESHANK Verify NP 1.0 is single shank (all 1).
            metafile = testCase.writeNP10Meta(8);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            testCase.verifyEqual(pg.shank_id, ones(8, 1));
        end

        % ---- NP 2.0 single shank imroTbl path ----

        function testNP20SSPositions(testCase)
        %TESTNP20SSPOSITIONS Verify NP 2.0 single-shank geometry.
        %   elecInd 0: row=0,col=0 → x=27, y=0
        %   elecInd 1: row=0,col=1 → x=59, y=0
        %   elecInd 2: row=1,col=0 → x=27, y=15
        %   elecInd 3: row=1,col=1 → x=59, y=15
            elec_inds = [0; 1; 2; 3; 10; 11];
            metafile = testCase.writeNP20SSMeta(6, elec_inds);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            expected_x = [27; 59; 27; 59; 27; 59];
            expected_y = [0; 0; 15; 15; 75; 75];

            testCase.verifyEqual(pg.site_locations_leftright, expected_x);
            testCase.verifyEqual(pg.site_locations_depth, expected_y);
            testCase.verifyEqual(pg.probe_model, 'Neuropixels 2.0 Single Shank');
            testCase.verifyEqual(pg.shank_id, ones(6, 1));
        end

        % ---- NP 2.0 four shank imroTbl path ----

        function testNP20FourShankPositions(testCase)
        %TESTNP20FOURSHANKPOSITIONS Verify NP 2.0 four-shank geometry.
            shank_ids = [0; 0; 1; 1; 2; 3];
            elec_inds = [0; 1; 0; 1; 4; 5];
            metafile = testCase.writeNP20_4SMeta(6, shank_ids, elec_inds);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            % shank 0, elec 0: x = 0*250 + 27 = 27, y = 0
            % shank 0, elec 1: x = 0*250 + 59 = 59, y = 0
            % shank 1, elec 0: x = 1*250 + 27 = 277, y = 0
            % shank 1, elec 1: x = 1*250 + 59 = 309, y = 0
            % shank 2, elec 4: row=2,col=0 → x = 2*250 + 27 = 527, y = 30
            % shank 3, elec 5: row=2,col=1 → x = 3*250 + 59 = 809, y = 30
            expected_x = [27; 59; 277; 309; 527; 809];
            expected_y = [0; 0; 0; 0; 30; 30];
            expected_shank = [1; 1; 2; 2; 3; 4];

            testCase.verifyEqual(pg.site_locations_leftright, expected_x);
            testCase.verifyEqual(pg.site_locations_depth, expected_y);
            testCase.verifyEqual(pg.shank_id, expected_shank);
            testCase.verifyEqual(pg.probe_model, 'Neuropixels 2.0 Four Shank');
        end

        % ---- snsGeomMap path ----

        function testGeomMapPreferredOverImroTbl(testCase)
        %TESTGEOMMAPREFERREDOVERIMROTBL Verify snsGeomMap takes precedence.
        %   Write a meta file with both imroTbl and ~snsGeomMap. The
        %   snsGeomMap positions should be used, not computed from imroTbl.
            geommap = '(NP1010,1,0,70)(0:100:200:1)(0:300:400:1)(0:0:0:0)';
            metafile = testCase.writeGeomMapMeta(2, geommap);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            % Should use snsGeomMap values, not imroTbl computation
            testCase.verifyEqual(pg.site_locations_leftright, [100; 300]);
            testCase.verifyEqual(pg.site_locations_depth, [200; 400]);
        end

        function testGeomMapShankIds(testCase)
        %TESTGEOMMAPSHANKIDS Verify snsGeomMap shank IDs are 1-based.
            geommap = '(NP2014,4,250,70)(0:27:0:1)(1:27:0:1)(2:59:15:1)(3:59:30:1)(0:0:0:0)';
            metafile = testCase.writeGeomMapMeta(4, geommap);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            % 0-based shank IDs in snsGeomMap → 1-based in output
            testCase.verifyEqual(pg.shank_id, [1; 2; 3; 4]);
        end

        function testGeomMapExcludesSyncChannel(testCase)
        %TESTGEOMMAPEXCLUDESSYNCCHANNEL Verify sync channel is excluded.
            % 4 neural channels + 1 sync (used=0)
            geommap = '(NP1010,1,0,70)(0:10:20:1)(0:30:40:1)(0:50:60:1)(0:70:80:1)(0:0:0:0)';
            metafile = testCase.writeGeomMapMeta(4, geommap);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            % Should have exactly 4 entries (not 5)
            testCase.verifySize(pg.site_locations_leftright, [4 1]);
            testCase.verifyEqual(pg.site_locations_leftright, [10; 30; 50; 70]);
            testCase.verifyEqual(pg.site_locations_depth, [20; 40; 60; 80]);
        end

        % ---- Error cases ----

        function testErrorNoGeometryInfo(testCase)
        %TESTERRORNOGEOMETRYINFO Verify error when neither field is present.
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       '5';
                'snsApLfSy',         '4,0,1';
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '512';
                'imDatPrb_type',     '0';
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);

            testCase.verifyError(...
                @() ndr.format.neuropixelsGLX.probeGeometry(metafile), ...
                'ndr:format:neuropixelsGLX:probeGeometry:NoGeometry');
        end

        function testErrorUnsupportedProbeType(testCase)
        %TESTERRORUNSUPPORTEDPROBETYPE Verify error for unknown probe type.
            imro = '(9999,2)(0 0 0 500 250 1)(1 0 0 500 250 1)';
            fields = {
                'imSampRate',        '30000';
                'nSavedChans',       '3';
                'snsApLfSy',         '2,0,1';
                'snsSaveChanSubset', 'all';
                'fileSizeBytes',     '0';
                'fileTimeSecs',      '0';
                'imAiRangeMax',      '0.6';
                'imAiRangeMin',      '-0.6';
                'imMaxInt',          '512';
                'imDatPrb_type',     '9999';
                'imroTbl',           imro;
            };
            metafile = testCase.writeMetaFile('test.imec0.ap.meta', fields);

            testCase.verifyError(...
                @() ndr.format.neuropixelsGLX.probeGeometry(metafile), ...
                'ndr:format:neuropixelsGLX:probeGeometry:UnsupportedProbe');
        end

        % ---- NP 1.0 stagger pattern verification ----

        function testNP10StaggerPattern(testCase)
        %TESTNP10STAGGERPATTERN Verify all 4 x-positions appear correctly.
        %   NP 1.0 has 4 distinct x-positions: 11, 27, 43, 59.
            metafile = testCase.writeNP10Meta(8);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            unique_x = sort(unique(pg.site_locations_leftright));
            testCase.verifyEqual(unique_x, [11; 27; 43; 59], ...
                'NP 1.0 should have 4 distinct x-positions.');
        end

        function testNP20NoStagger(testCase)
        %TESTNP20NOSTAGGER Verify NP 2.0 has only 2 x-positions (no stagger).
            elec_inds = (0:7)';
            metafile = testCase.writeNP20SSMeta(8, elec_inds);
            pg = ndr.format.neuropixelsGLX.probeGeometry(metafile);

            unique_x = sort(unique(pg.site_locations_leftright));
            testCase.verifyEqual(unique_x, [27; 59], ...
                'NP 2.0 should have 2 distinct x-positions (no stagger).');
        end

    end % methods (Test)

end % classdef
