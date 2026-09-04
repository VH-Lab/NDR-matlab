classdef TestReadCellBin < matlab.unittest.TestCase
    % TestReadCellBin - readCellBin against synthetic cellbin .h5ad files.
    %
    % The fixtures are written by the REAL anndata library, via
    % bscholl-genomics-python/cloudFriendly/make_cellbin_conformance_fixtures.py,
    % and read here by plain HDF5. That asymmetry is the point: NDR reads
    % .h5ad with raw HDF5 in both languages, so the fixtures must be
    % genuine AnnData output rather than our idea of the layout. If
    % anndata changes how it lays out categoricals or the obs index, these
    % fail and say so.
    %
    % Every fixture holds the same 5 cells with ragged real-vertex counts
    % (3, 4, 5, 8) and one cell with NONE, so a reader that assumes a
    % fixed count, or drops empty cells rather than keeping their row,
    % shifts every later cell's contour onto the wrong cell.
    %
    % cellbin_unlabeled.h5ad exists for one byte the others cannot hold: a
    % categorical code of -1, which pandas writes for a cell the labeling
    % never assigned and which cannot be produced by naming a category.
    %
    % MATLAB's h5read returns dimensions in the REVERSE of the order h5py
    % wrote them, so obsm/spatial arrives 2 x nCells and obsm/cell_border
    % arrives 2 x V x nCells. That transposition is silent on a near-square
    % section -- it swaps x and y and everything still looks plausible --
    % which is why the fixture's x and y ranges differ and why the vertex
    % offsets are distinct in x and y.

    properties
        dir
    end

    methods (TestClassSetup)
        function locate(testCase)
            testCase.dir = fileparts(mfilename('fullpath'));
        end
    end

    methods (Test)

        function testReadsCellsCentroidsAndColumns(testCase)
            [cid, x, y, ~, obs, meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'));

            testCase.verifyEqual(meta.nCells, 5);
            testCase.verifyEqual(cid, testCase.expectedIDs());
            testCase.verifyEqual(meta.centroidSource, 'obsm/spatial');
            testCase.verifyEqual(x(1), 10000);
            testCase.verifyEqual(y(1), 20000);
            testCase.verifyTrue(isfield(obs, 'area'));
            testCase.verifyEqual(obs.area(:)', [10 20 30 40 50]);
        end

        function testCellIDsStayText(testCase)
            % 13-digit identifiers lose precision as doubles and then no
            % longer match the file they came from.
            cid = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            testCase.verifyClass(cid, 'cell');
            testCase.verifyEqual(cid{1}, '9000000000000');
        end

        function testCentroidRelativeIsDetected(testCase)
            [~,~,~,~,~,meta] = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            testCase.verifyEqual(meta.contourReference, 'centroid');
            testCase.verifyEqual(meta.contourReferenceSource, 'detected');
            testCase.verifyLessThan(meta.relativeEvidence.ratio, ...
                meta.relativeEvidence.threshold);
        end

        function testAbsoluteIsDetected(testCase)
            [~,~,~,~,~,meta] = ndr.format.stereoseq.readCellBin(testCase.cb('absolute'));
            testCase.verifyEqual(meta.contourReference, 'absolute');
            testCase.verifyGreaterThan(meta.relativeEvidence.ratio, ...
                meta.relativeEvidence.threshold);
        end

        function testBothEncodingsNormaliseToTheSamePolygons(testCase)
            % The property that matters, and the one a threshold bug breaks.
            % cellbin_basic and cellbin_absolute hold the SAME polygons, one
            % stored centroid-relative and one absolute. Read into a common
            % frame they must be identical. A wrong relative/absolute call
            % puts every outline a chip-width from its cell without raising
            % anything, so this is the test that catches it.
            for frame = ["centroid" "absolute"]
                [~,~,~,rel] = ndr.format.stereoseq.readCellBin( ...
                    testCase.cb('basic'), 'outputReference', char(frame));
                [~,~,~,abso] = ndr.format.stereoseq.readCellBin( ...
                    testCase.cb('absolute'), 'outputReference', char(frame));
                testCase.verifyEqual(numel(rel), 5);
                for i = 1:5
                    testCase.verifyEqual(rel{i}, abso{i}, 'AbsTol', 1e-9, ...
                        sprintf('frame %s, cell %d', frame, i));
                end
            end
        end

        function testPaddingIsDetectedAndReported(testCase)
            [~,~,~,~,~,meta] = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            testCase.verifyEqual(meta.padValue, 32767);
            testCase.verifyGreaterThan(meta.padFraction, 0);
            testCase.verifyLessThan(meta.padFraction, 1);
        end

        function testEmptyContourKeepsItsRow(testCase)
            % Dropping it would shift every later contour onto the wrong cell.
            [~,~,~,contours,~,meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'));
            n = cellfun(@(c) size(c,1), contours);
            testCase.verifyEqual(n(:)', [3 4 5 8 0]);
            testCase.verifyEqual(size(contours{5}), [0 2]);
            testCase.verifyEqual(meta.nEmptyContours, 1);
            testCase.verifyTrue(meta.raggedVertices);
        end

        function testCentroidsFromObsXY(testCase)
            [~, x, y, ~, ~, meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('obsxy'));
            testCase.verifyEqual(meta.centroidSource, 'obs x/y');
            testCase.verifyEqual(x(1), 10000);
            testCase.verifyEqual(y(1), 20000);
        end

        function testMissingContoursReportedWithWhatIsThere(testCase)
            [~,~,~,contours,~,meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('nocontours'));
            testCase.verifyFalse(meta.contoursPresent);
            testCase.verifyEmpty(contours);
            testCase.verifyTrue(ismember('spatial', meta.obsmKeys));
        end

        function testLabelColumnsAreReportedNotChosen(testCase)
            % Both kinds appear, flagged, because the file does not say which.
            [~,~,~,~,~,meta] = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            names = {meta.labelColumns.name};
            testCase.verifyTrue(ismember('leiden', names));
            testCase.verifyTrue(ismember('subclass_nn_column', names));
            testCase.verifyTrue(meta.labelColumns(strcmp(names,'leiden')).isUnsupervisedGuess);
            testCase.verifyFalse( ...
                meta.labelColumns(strcmp(names,'subclass_nn_column')).isUnsupervisedGuess);
            testCase.verifyEqual( ...
                meta.labelColumns(strcmp(names,'subclass_nn_column')).nCategories, 3);
        end

        function testReferenceCanBeForcedAndSaysSo(testCase)
            [~,~,~,forced,~,meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'contourReference', 'absolute');
            testCase.verifyEqual(meta.contourReferenceSource, 'forced');
            [~,~,~,auto] = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            testCase.verifyNotEqual(forced{1}, auto{1});
        end

        function testProbeOnlyReportsWithoutReturningCells(testCase)
            [cid, x, y, contours, obs, meta] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'probeOnly', true);

            testCase.verifyEmpty(cid); testCase.verifyEmpty(x);
            testCase.verifyEmpty(y);   testCase.verifyEmpty(contours);
            testCase.verifyEmpty(fieldnames(obs));

            % The counts and every inference are still exact: a caller can
            % show what is in a file before committing to reading it.
            testCase.verifyEqual(meta.nCells, 5);
            testCase.verifyEqual(meta.contourReference, 'centroid');
            testCase.verifyEqual(meta.padValue, 32767);
            testCase.verifyEqual(numel(meta.labelColumns), 2);
        end

        function testObsColumnsCanBeSelected(testCase)
            [~,~,~,~,obs] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'obsColumns', {'area'});
            testCase.verifyEqual(fieldnames(obs), {'area'});
        end

        function testLabelValuesComeBackWhenAskedForByName(testCase)
            % meta.labelColumns says a labeling EXISTS; this is how its
            % per-cell values get out of the file, and without it
            % ndi.fun.doc.gene.makeCellTypeLabels has nothing to be given.
            [~,~,~,~,obs] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'obsColumns', {'subclass_nn_column'});
            testCase.verifyClass(obs.subclass_nn_column, 'cell');
            testCase.verifyEqual(obs.subclass_nn_column(:)', ...
                {'L2/3 IT','Pvalb','L2/3 IT','Astro','Pvalb'});
        end

        function testLabelsAreNotReturnedByDefault(testCase)
            % The default is measurements. A labeling is a claim about each
            % cell and which one to believe is the caller's decision, so it
            % is asked for by name rather than swept up.
            [~,~,~,~,obs] = ndr.format.stereoseq.readCellBin(testCase.cb('basic'));
            testCase.verifyFalse(isfield(obs, 'subclass_nn_column'));
            testCase.verifyFalse(isfield(obs, 'leiden'));
            testCase.verifyTrue(isfield(obs, 'area'));
        end

        function testNumericAndLabelColumnsMixInOneCall(testCase)
            [~,~,~,~,obs] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'obsColumns', {'area','leiden'});
            testCase.verifyEqual(sort(fieldnames(obs))', {'area','leiden'});
            testCase.verifyEqual(obs.leiden(:)', {'0','1','0','2','1'});
        end

        function testMissingCategoryBecomesUnlabeledNotAWrongLabel(testCase)
            % pandas writes code -1 for a cell the labeling never assigned.
            % A zero-based lookup that does not special-case it silently
            % hands that cell the LAST category -- a real, plausible label
            % on a cell that has none, which nothing downstream can catch.
            [~,~,~,~,obs] = ndr.format.stereoseq.readCellBin( ...
                testCase.cb('unlabeled'), 'obsColumns', {'subclass_nn_column'});
            testCase.verifyEqual(obs.subclass_nn_column(:)', ...
                {'L2/3 IT','','L2/3 IT','','Pvalb'});
        end

        function testUnknownObsColumnNamesWhatIsThere(testCase)
            testCase.verifyError(@() ndr.format.stereoseq.readCellBin( ...
                testCase.cb('basic'), 'obsColumns', {'nosuchcolumn'}), ...
                'NDR:stereoseq:readCellBin:noSuchColumn');
        end

        function testUnknownColumnMessageListsLabelsToo(testCase)
            % The available list must name the categorical columns as well,
            % now that they can be asked for; a message that omits them
            % sends the caller looking for a reader that already exists.
            try
                ndr.format.stereoseq.readCellBin( ...
                    testCase.cb('basic'), 'obsColumns', {'nosuchcolumn'});
                testCase.verifyFail('expected an error');
            catch ME
                testCase.verifySubstring(ME.message, 'subclass_nn_column');
                testCase.verifySubstring(ME.message, 'area');
            end
        end

        function testNotAnH5adIsNamed(testCase)
            testCase.verifyError(@() ndr.format.stereoseq.readCellBin( ...
                fullfile(testCase.dir, 'gef_basic.gef')), ...
                'NDR:stereoseq:readCellBin:notAnH5ad');
        end

    end

    methods (Access = private)
        function f = cb(testCase, which)
            f = fullfile(testCase.dir, ['cellbin_' which '.h5ad']);
            testCase.assertTrue(isfile(f), sprintf( ...
                ['%s is missing; regenerate the fixtures with bscholl ' ...
                 'cloudFriendly/make_cellbin_conformance_fixtures.py.'], f));
        end

        function ids = expectedIDs(~)
            ids = cell(5,1);
            for i = 1:5
                ids{i} = sprintf('%d', 9000000000000 + i - 1);
            end
        end
    end
end
