function [cellID, x, y, contours, obs, meta] = readCellBin(h5adPath, options)
% ndr.format.stereoseq.readCellBin - read a SAW cellbin .h5ad
%
%   [CELLID, X, Y, CONTOURS, OBS, META] = ...
%       ndr.format.stereoseq.READCELLBIN(H5ADPATH)
%   [...] = ndr.format.stereoseq.READCELLBIN(..., 'probeOnly', true)
%
%   Reads a SAW cell segmentation .h5ad and returns one entry per cell:
%   an identifier, a centroid, an optional boundary polygon, and whatever
%   per-cell measurements the file carries.
%
%   This is the raw-format layer. It reads the vendor's file and returns
%   arrays; it creates no documents and knows nothing about NDI. Its
%   outputs are what ndi.fun.doc.gene.makeCells takes.
%
%   READ WITH PLAIN HDF5, NOT WITH anndata. An .h5ad is an HDF5 file with
%   AnnData conventions layered on top, and those conventions are simple
%   enough to read directly: /obs carries an "_index" attribute naming the
%   identifier dataset, numeric columns are datasets, and categorical
%   columns are GROUPS holding "categories" and "codes". Reading it
%   directly is what lets MATLAB and Python do the same thing here; taking
%   a Python-only dependency would leave the two ports on different
%   footings, which is exactly what the bridge exists to prevent.
%
%   Optional Name-Value Arguments:
%   probeOnly (false)          - report what the file contains -- cell
%                                count, available columns, label
%                                candidates, and the contour inferences
%                                below -- without reading centroids or
%                                contours. CELLID, X, Y and CONTOURS come
%                                back empty. For a caller that must show a
%                                file before committing to it.
%   contourReference ('auto')  - 'auto', 'centroid' or 'absolute'. See
%                                THE FILE DOES NOT SAY, below.
%   padValue ('auto')          - 'auto', or a numeric sentinel, or NaN for
%                                none.
%   outputReference('centroid')- frame CONTOURS come back in: 'centroid'
%                                (offsets from each cell's centroid) or
%                                'absolute' (source coordinates).
%                                Centroid-relative is the default because
%                                that is what spatialGeneExpressionCells
%                                stores, and what int16 vertices can hold.
%   obsColumns ({})            - per-cell columns to return; {} returns
%                                every numeric one. A CATEGORICAL column
%                                may be named here too, and comes back as
%                                a cellstr of its decoded category names,
%                                one per cell -- that is how a labeling
%                                gets out of the file and into
%                                ndi.fun.doc.gene.makeCellTypeLabels. It
%                                is not in the {} default because the
%                                default is measurements, and a labeling
%                                is a claim about each cell rather than a
%                                measurement of it: which labeling to
%                                believe is the caller's decision (see
%                                META.labelColumns), so it must be asked
%                                for by name.
%
%   Outputs:
%   CELLID   - cellstr, one per cell, from the AnnData index. TEXT, never
%              numbers: these are commonly 13-14 digit identifiers that
%              lose precision as a double and then no longer match the
%              file they came from.
%   X, Y     - centroid coordinates, one per cell
%   CONTOURS - {nCells x 1} cell array of Vx2 vertices, padding removed,
%              in the frame named by outputReference. A cell with no
%              usable boundary gets a 0x2 -- its ROW IS KEPT, because
%              dropping it would shift every later cell's contour onto the
%              wrong cell, silently.
%   OBS      - struct of the requested per-cell columns, field names made
%              valid for MATLAB. Numeric columns come back as double
%              column vectors; a categorical column comes back as a
%              cellstr of category names, with '' for a cell pandas
%              recorded as missing (code -1), which is a real state -- an
%              unassigned cell -- and not an error.
%   META     - struct describing the file and every inference made; see
%              below.
%
%   THE FILE DOES NOT SAY whether boundary vertices are stored relative to
%   each cell's centroid or in absolute source coordinates, nor what value
%   pads the unused vertex slots. Both have to be INFERRED, and both are
%   recorded as explicit fields on the NDI document precisely so that
%   nothing downstream has to guess again.
%
%   So this reports rather than decides quietly. META.contourReference is
%   the answer; META.contourReferenceSource says whether it was detected
%   or forced by the caller; META.relativeEvidence carries the numbers the
%   decision was made from, so a human can check it. Getting it wrong is
%   silent and total: treat absolute vertices as relative and every
%   outline lands a chip-width away from its cell, with no error.
%
%   The rule: vertices are centroid-relative when the median magnitude of
%   the REAL (non-padding) vertices is under 5% of the centroid scale,
%   where the scale is max(max|x|, max|y|, 1). Padding is excluded first
%   because a sentinel of 32767 would otherwise dominate the median and
%   mask small relative offsets. Two earlier implementations of this test
%   disagreed -- one used median(|centroid|) with a 10% threshold, the
%   other max with 5% -- and agreed only by luck on the data they had run
%   on; consolidating them here is half the reason this function exists.
%   The scale uses max rather than a median because it describes the
%   frame's extent rather than where the tissue happens to sit.
%
%   META fields:
%     nCells, nGenes
%     centroidSource         'obsm/spatial' or 'obs x/y'
%     contoursPresent        logical
%     contourShape           size of obsm/cell_border
%     padValue, padFraction  the sentinel and how much of the array it fills
%     contourReference       'centroid' or 'absolute'
%     contourReferenceSource 'detected' or 'forced'
%     relativeEvidence       struct: realVertexAbsMedian, centroidScale,
%                            ratio, threshold
%     verticesPerCell        [min median max] of REAL vertices
%     raggedVertices         logical
%     nEmptyContours         cells with no usable boundary
%     obsColumns             every column in /obs
%     labelColumns           the categorical ones, with an
%                            isUnsupervisedGuess flag each
%
%   LABEL COLUMNS ARE REPORTED, NOT CHOSEN. A cellbin routinely carries
%   several: transferred atlas calls and unsupervised clusterings side by
%   side. They are not interchangeable -- a clustering carries no
%   biological identity, so reading one of its colours as a cell type is a
%   scientific error rather than a display bug -- and the file does not
%   label which is which. The guess here is from the column NAME alone
%   (leiden, snn_res, cluster*), which is a heuristic and is marked as
%   one. cellTypeLabels has an is_unsupervised field so a human can
%   settle it.
%
%   Example:
%       [~,~,~,~,~,m] = ndr.format.stereoseq.readCellBin(f,'probeOnly',true);
%       fprintf('%d cells, contours %d, reference %s (ratio %.4f)\n', ...
%           m.nCells, m.contoursPresent, m.contourReference, ...
%           m.relativeEvidence.ratio);
%
%   See also: ndi.fun.doc.gene.makeCells, ndr.format.stereoseq.readGEF
%   File layouts and the SAW quirks these work around:
%   docs/notes/stereoseq_formats.md
%
arguments
    h5adPath (1,:) char {mustBeFile}
    options.probeOnly (1,1) logical = false
    options.contourReference (1,:) char {mustBeMember(options.contourReference, ...
        {'auto','centroid','absolute'})} = 'auto'
    options.padValue = 'auto'
    options.outputReference (1,:) char {mustBeMember(options.outputReference, ...
        {'centroid','absolute'})} = 'centroid'
    options.obsColumns cell = {}
end

RELATIVE_THRESHOLD = 0.05;

info = h5info(h5adPath);
if ~localHasGroup(info, '/obs')
    error('NDR:stereoseq:readCellBin:notAnH5ad', ...
        '%s has no /obs group; this does not look like an .h5ad.', h5adPath);
end

% -- identifiers --------------------------------------------------------
indexName = localAttrChar(h5adPath, '/obs', '_index');
if isempty(indexName), indexName = '_index'; end
cellID = localReadStrings(h5adPath, ['/obs/' indexName]);
nCells = numel(cellID);

meta = struct();
meta.nCells = nCells;
meta.nGenes = localVarCount(h5adPath, info);

% -- what columns exist -------------------------------------------------
obsGroup = localGroup(info, '/obs');
[numericCols, labelCols] = localClassifyObs(obsGroup, indexName);
meta.obsColumns = [numericCols(:); {labelCols.name}'];
meta.labelColumns = labelCols;

% -- centroids ----------------------------------------------------------
[cenSource, hasSpatial] = localCentroidSource(info, numericCols);
meta.centroidSource = cenSource;

% -- contour presence and shape (metadata only) -------------------------
cbPath = '/obsm/cell_border';
meta.contoursPresent = localHasDataset(info, cbPath);
meta.contourShape = [];
meta.padValue = NaN;
meta.padFraction = NaN;
meta.contourReference = '';
meta.contourReferenceSource = '';
meta.relativeEvidence = struct('realVertexAbsMedian', NaN, ...
    'centroidScale', NaN, 'ratio', NaN, 'threshold', RELATIVE_THRESHOLD);
meta.verticesPerCell = [NaN NaN NaN];
meta.raggedVertices = false;
meta.nEmptyContours = NaN;

if ~meta.contoursPresent
    obsmGroup = localGroup(info, '/obsm');
    if isempty(obsmGroup)
        meta.obsmKeys = {};
    else
        meta.obsmKeys = localDatasetNames(obsmGroup);
    end
end

% Centroids are needed even under probeOnly: the relative/absolute
% inference is a comparison AGAINST them, so reporting it without them
% would be reporting a guess with no evidence.
if meta.contoursPresent || ~options.probeOnly
    [x, y] = localCentroids(h5adPath, cenSource, hasSpatial, nCells);
else
    x = []; y = [];
end

contours = {};
obs = struct();

if meta.contoursPresent
    cb = localCellBorder(h5adPath, nCells);      % nCells x V x 2
    meta.contourShape = size(cb);

    [padValue, padFraction] = localPad(cb, options.padValue);
    meta.padValue = padValue;
    meta.padFraction = padFraction;

    [ref, refSource, evid] = localReference(cb, padValue, x, y, ...
        options.contourReference, RELATIVE_THRESHOLD);
    meta.contourReference = ref;
    meta.contourReferenceSource = refSource;
    meta.relativeEvidence = evid;

    [contours, vpc] = localPolygons(cb, padValue, ref, x, y, ...
        options.outputReference);
    meta.verticesPerCell = [min(vpc) median(vpc) max(vpc)];
    meta.raggedVertices = min(vpc) ~= max(vpc);
    meta.nEmptyContours = sum(vpc == 0);

    if options.probeOnly
        contours = {};
    end
end

if options.probeOnly
    cellID = {}; x = []; y = [];
    return;
end

% -- per-cell measurements ----------------------------------------------
if isempty(options.obsColumns)
    want = numericCols;
else
    want = options.obsColumns;
end
labelNames = {};
if ~isempty(labelCols), labelNames = {labelCols.name}; end
for i = 1:numel(want)
    c = want{i};
    fn = matlab.lang.makeValidName(c);
    if ismember(c, numericCols)
        obs.(fn) = double(h5read(h5adPath, ['/obs/' c]));
    elseif ismember(c, labelNames)
        obs.(fn) = localReadCategorical(h5adPath, c, nCells);
    else
        error('NDR:stereoseq:readCellBin:noSuchColumn', ...
            'No /obs column %s; available: {%s}.', ...
            c, strjoin([numericCols(:); labelNames(:)]', ', '));
    end
end

end % readCellBin

% =======================================================================

function [x, y] = localCentroids(f, src, hasSpatial, nCells)
if hasSpatial
    % h5py writes (nCells, 2); MATLAB's h5read returns dimensions in the
    % REVERSE order, so this arrives as 2 x nCells and must be transposed.
    % Getting this wrong silently swaps x and y on a near-square section.
    s = h5read(f, '/obsm/spatial');
    if size(s, 1) == nCells && size(s, 2) >= 2
        x = double(s(:, 1)); y = double(s(:, 2));
    else
        x = double(s(1, :)).'; y = double(s(2, :)).';
    end
else
    [xk, yk] = localXYNames(src);
    x = double(h5read(f, ['/obs/' xk]));
    y = double(h5read(f, ['/obs/' yk]));
end
x = x(:); y = y(:);
end

function [xk, yk] = localXYNames(src)
parts = strsplit(strrep(src, 'obs ', ''), '/');
xk = parts{1}; yk = parts{2};
end

function cb = localCellBorder(f, nCells)
% h5py writes (nCells, V, 2); MATLAB h5read reverses the dimension order,
% so this arrives as 2 x V x nCells. Permute back rather than reshape:
% a reshape would reinterpret the same bytes and quietly scramble the
% vertices instead of failing.
raw = h5read(f, '/obsm/cell_border');
d = size(raw);
if numel(d) == 3 && d(1) == nCells
    cb = double(raw);
elseif numel(d) == 3 && d(3) == nCells
    cb = permute(double(raw), [3 2 1]);
else
    error('NDR:stereoseq:readCellBin:badBorderShape', ...
        ['obsm/cell_border has shape [%s], which is not (nCells=%d, ' ...
         'vertices, 2) in either dimension order.'], ...
        strjoin(string(d), ' '), nCells);
end
if size(cb, 3) ~= 2
    error('NDR:stereoseq:readCellBin:badBorderShape', ...
        'obsm/cell_border last dimension is %d, expected 2 (x,y).', size(cb,3));
end
end

function [padValue, padFraction] = localPad(cb, requested)
flat = reshape(cb, [], 2);
if isnumeric(requested)
    padValue = double(requested);
else
    % The sentinel is whatever value fills most slots, but only if it
    % actually dominates -- a file with no padding must not have its most
    % common real coordinate mistaken for one.
    v = flat(:, 1);
    v = v(isfinite(v));
    if isempty(v)
        padValue = NaN;
    else
        [vals, ~, idx] = unique(v);
        counts = accumarray(idx, 1);
        [top, k] = max(counts);
        if top > 0.25 * numel(v)
            padValue = vals(k);
        else
            padValue = NaN;
        end
    end
end
if isnan(padValue)
    padFraction = 0;
else
    padFraction = mean(all(flat == padValue, 2));
end
end

function [ref, refSource, evid] = localReference(cb, padValue, x, y, requested, thresh)
flat = reshape(cb, [], 2);
if ~isnan(padValue)
    flat = flat(~all(flat == padValue, 2), :);
end
if isempty(flat)
    realMed = NaN;
else
    realMed = median(abs(flat(:)), 'omitnan');
end
scale = max([max(abs(x)), max(abs(y)), 1]);
ratio = realMed / scale;
evid = struct('realVertexAbsMedian', realMed, 'centroidScale', scale, ...
    'ratio', ratio, 'threshold', thresh);

switch requested
    case 'auto'
        if isnan(ratio)
            ref = 'absolute';
        elseif ratio < thresh
            ref = 'centroid';
        else
            ref = 'absolute';
        end
        refSource = 'detected';
    otherwise
        ref = requested;
        refSource = 'forced';
end
end

function [polys, vpc] = localPolygons(cb, padValue, ref, x, y, outputRef)
n = size(cb, 1);
polys = cell(n, 1);
vpc = zeros(n, 1);
relative = strcmp(ref, 'centroid');
for i = 1:n
    v = squeeze(cb(i, :, :));
    if size(v, 2) ~= 2, v = v.'; end
    keep = all(isfinite(v), 2);
    if ~isnan(padValue)
        keep = keep & ~all(v == padValue, 2);
    end
    if relative
        % When vertices are centroid-relative, (0,0) IS the centroid and
        % never a real boundary point, so it is padding whatever the
        % sentinel search concluded.
        keep = keep & ~all(v == 0, 2);
    end
    v = v(keep, :);
    if size(v, 1) >= 2      % drop repeats, including a closing vertex
        dup = all(v == circshift(v, 1, 1), 2);
        v = v(~dup, :);
    end
    if size(v, 1) < 3
        polys{i} = zeros(0, 2);
        vpc(i) = 0;
        continue;
    end
    % Convert into the requested frame.
    if relative && strcmp(outputRef, 'absolute')
        v = v + [x(i) y(i)];
    elseif ~relative && strcmp(outputRef, 'centroid')
        v = v - [x(i) y(i)];
    end
    polys{i} = v;
    vpc(i) = size(v, 1);
end
end

function [numericCols, labelCols] = localClassifyObs(obsGroup, indexName)
numericCols = {};
labelCols = struct('name', {}, 'nCategories', {}, 'isUnsupervisedGuess', {});
if isempty(obsGroup), return; end
if ~isempty(obsGroup.Datasets)
    for i = 1:numel(obsGroup.Datasets)
        nm = obsGroup.Datasets(i).Name;
        if strcmp(nm, indexName) || strcmp(nm, '_index'), continue; end
        numericCols{end+1} = nm; %#ok<AGROW>
    end
end
% AnnData stores a categorical column as a GROUP of categories + codes.
if ~isempty(obsGroup.Groups)
    for i = 1:numel(obsGroup.Groups)
        parts = strsplit(obsGroup.Groups(i).Name, '/');
        nm = parts{end};
        members = {};
        if ~isempty(obsGroup.Groups(i).Datasets)
            members = {obsGroup.Groups(i).Datasets.Name};
        end
        if ismember('categories', members) && ismember('codes', members)
            k = numel(labelCols) + 1;
            labelCols(k).name = nm;
            % The COUNT comes from the dataspace, not from reading the
            % category strings: the size is metadata, and the strings are
            % variable-length, which is the awkward case (see
            % localReadStrings).
            labelCols(k).nCategories = localDatasetLength( ...
                obsGroup.Groups(i), 'categories');
            labelCols(k).isUnsupervisedGuess = localUnsupervised(nm);
        end
    end
end
end

function tf = localUnsupervised(name)
% A guess from the NAME, and marked as one. An unsupervised clustering
% carries no biological identity; a transferred atlas call is an inference
% about each cell. The file does not distinguish them, and treating one as
% the other is a scientific error rather than a display bug.
l = lower(name);
tf = contains(l, 'leiden') || contains(l, 'louvain') || ...
     contains(l, 'snn_res') || startsWith(l, 'cluster');
end

function [src, hasSpatial] = localCentroidSource(info, numericCols)
hasSpatial = localHasDataset(info, '/obsm/spatial');
if hasSpatial
    src = 'obsm/spatial';
    return;
end
pairs = {'x','y'; 'spatial_x','spatial_y'; 'X','Y'};
for i = 1:size(pairs, 1)
    if ismember(pairs{i,1}, numericCols) && ismember(pairs{i,2}, numericCols)
        src = sprintf('obs %s/%s', pairs{i,1}, pairs{i,2});
        return;
    end
end
error('NDR:stereoseq:readCellBin:noCentroids', ...
    'No centroids: need obsm/spatial or an obs x/y pair.');
end

function n = localVarCount(f, info)
n = NaN;
try
    g = localGroup(info, '/var');
    if isempty(g), return; end
    nm = localAttrChar(f, '/var', '_index');
    if isempty(nm), nm = '_index'; end
    n = localDatasetLength(g, nm);
catch
    n = NaN;
end
end

function n = localDatasetLength(g, name)
% Element count of a dataset, from h5info rather than by reading it.
n = NaN;
if isempty(g) || isempty(g.Datasets), return; end
hit = find(strcmp({g.Datasets.Name}, name), 1);
if isempty(hit), return; end
sz = g.Datasets(hit).Dataspace.Size;
if isempty(sz), n = 1; else, n = prod(sz); end
end

function c = localReadStrings(f, dsetPath)
% Read a string dataset as a cellstr.
%
% h5read handles AnnData's variable-length utf-8 strings; what it returns
% for them is a STRING ARRAY, not a cell or a char matrix, which is the
% case localToCellstr has to get right.
c = localToCellstr(h5read(f, dsetPath));
end

function v = localReadCategorical(f, name, nCells)
% Decode an AnnData categorical /obs column into a cellstr, one per cell.
%
% The column is a GROUP, not a dataset: 'categories' holds the distinct
% strings and 'codes' holds a ZERO-BASED index into them, one per cell.
% pandas writes -1 for a value it has no category for, and that is a
% meaningful state rather than a defect -- a cell the labeling never
% assigned -- so it becomes '', which is exactly what
% ndi.fun.doc.gene.makeCellTypeLabels documents an empty label to mean.
%
% Both bounds are CHECKED rather than trusted. A code array of the wrong
% length or reaching past the categories would otherwise put a real
% category name on the wrong cell, and nothing downstream could tell:
% every label would still be a legal label.
cats  = localReadStrings(f, ['/obs/' name '/categories']);
codes = double(h5read(f, ['/obs/' name '/codes']));
codes = codes(:);
if numel(codes) ~= nCells
    error('NDR:stereoseq:readCellBin:codeLength', ...
        '/obs/%s/codes has %d entries but the file has %d cells.', ...
        name, numel(codes), nCells);
end
if any(codes > numel(cats) - 1)
    error('NDR:stereoseq:readCellBin:codeRange', ...
        '/obs/%s/codes reaches category %d but only %d are defined.', ...
        name, max(codes), numel(cats));
end
if any(codes < -1)
    error('NDR:stereoseq:readCellBin:codeRange', ...
        '/obs/%s/codes holds %d; the only negative code pandas writes is -1.', ...
        name, min(codes));
end
v = repmat({''}, nCells, 1);
assigned = codes >= 0;
v(assigned) = cats(codes(assigned) + 1);
end

function g = localGroup(info, path)
g = [];
parts = strsplit(regexprep(path, '^/+|/+$', ''), '/');
cur = info;
for i = 1:numel(parts)
    if isempty(cur.Groups), return; end
    names = {cur.Groups.Name};
    hit = find(strcmp(names, ['/' strjoin(parts(1:i), '/')]), 1);
    if isempty(hit), return; end
    cur = cur.Groups(hit);
end
g = cur;
end

function tf = localHasGroup(info, path)
tf = ~isempty(localGroup(info, path));
end

function tf = localHasDataset(info, path)
parts = strsplit(regexprep(path, '^/+|/+$', ''), '/');
g = localGroup(info, ['/' strjoin(parts(1:end-1), '/')]);
tf = ~isempty(g) && ismember(parts{end}, localDatasetNames(g));
end

function names = localDatasetNames(g)
if isempty(g) || isempty(g.Datasets)
    names = {};
else
    names = {g.Datasets.Name};
end
end

function s = localAttrChar(f, loc, name)
try
    a = h5readatt(f, loc, name);
    if iscell(a), a = a{1}; end
    s = strtrim(char(a(:)'));
catch
    s = '';
end
end

function c = localToCellstr(v)
% Normalise whatever h5read returns for a string dataset into a cellstr.
%
% There are three shapes to cover, and which one arrives depends on the
% dataset, not on anything the caller can see:
%   string array  - what h5read gives for VARIABLE-LENGTH utf-8, which is
%                   how AnnData writes the obs index and every
%                   categorical's categories. cellstr converts it directly;
%                   going via char() pads the elements into a matrix and
%                   loses which characters belong to which entry.
%   cell of char  - the usual variable-length case in older releases.
%   char matrix   - FIXED-width strings, one per column, which is how SAW
%                   writes a .gef gene table.
if isstring(v)
    c = cellstr(v(:));
elseif iscell(v)
    c = cell(numel(v), 1);
    for i = 1:numel(v)
        c{i} = localOneString(v{i});
    end
elseif ischar(v)
    if size(v, 1) == 1
        c = {v};
    else
        c = cellstr(v);
    end
elseif isnumeric(v)
    c = cell(size(v, 2), 1);
    for k = 1:size(v, 2)
        c{k} = char(double(v(:, k))');
    end
else
    error('NDR:stereoseq:readCellBin:stringShape', ...
        ['Cannot convert a %s of size [%s] to text. This is what h5read ' ...
         'returned for a string dataset; the reader handles string, cell, ' ...
         'char and numeric.'], class(v), strjoin(string(size(v)), ' '));
end
c = c(:);
for i = 1:numel(c)
    s = c{i};
    s(s == 0) = [];
    c{i} = strtrim(s);
end
end

function s = localOneString(e)
if isstring(e)
    s = char(e);
elseif ischar(e)
    s = e(:)';
else
    s = char(double(e(:))');
end
end
