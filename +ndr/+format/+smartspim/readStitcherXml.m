function xmlData = readStitcherXml(xmlPath)
% ndr.format.smartspim.readStitcherXml - parse a TeraStitcher XML file
%
%   XMLDATA = ndr.format.smartspim.READSTITCHERXML(XMLPATH)
%
%   Parses a TeraStitcher-format XML file (as written by the LifeCanvas
%   SmartSPIM acquisition software: xml_import.xml and xml_merging.xml)
%   into a MATLAB struct. Returned fields:
%
%     voxelDims    struct with fields V, H, D (double, micrometers)
%     dimensions   struct with fields stackRows, stackColumns, stackSlices
%     origin       struct with fields V, H, D (double), or [] if absent
%     stacks       struct array (one per <Stack> element) with fields:
%                    row, col            (double, ROW / COL)
%                    absV, absH, absD    (double, ABS_V, ABS_H, ABS_D --
%                                         positions in pixels)
%                    dirName             (char, DIR_NAME -- always uses
%                                         forward-slash separators)
%                    zRanges             (char, Z_RANGES attribute or '')
%
%   The parser is defensive against the vendor XML pointing at an
%   unreachable DTD (the file's DOCTYPE names a "TeraStitcher.DTD" that
%   is not shipped): the DOCTYPE line is stripped before parsing, and
%   the underlying Xerces parser is invoked with an InputSource so no
%   external entity resolution occurs. External DTD/entity resolution
%   is not enabled anywhere.
%
%   Errors with a specific message on malformed XML (missing
%   voxel_dims, dimensions, STACKS, or per-Stack required attributes).

    if isstring(xmlPath) && isscalar(xmlPath)
        xmlPath = char(xmlPath);
    end
    if ~(ischar(xmlPath) && ~isempty(xmlPath))
        error('ndr:format:smartspim:readStitcherXml:BadInput', ...
            'xmlPath must be a non-empty char or scalar string.');
    end
    if ~isfile(xmlPath)
        error('ndr:format:smartspim:readStitcherXml:MissingFile', ...
            'XML file not found: %s', xmlPath);
    end

    try
        raw = fileread(xmlPath);
    catch ME
        error('ndr:format:smartspim:readStitcherXml:ReadFailed', ...
            'Failed to read %s: %s', xmlPath, ME.message);
    end

    % Strip <!DOCTYPE ...> so the parser never tries to resolve the
    % external "TeraStitcher.DTD" that the acquisition software names
    % but does not ship. This also removes the DTD as an attack surface
    % for external-entity injection from an untrusted acquisition dir.
    strippedXml = regexprep(raw, '<!DOCTYPE[^>]*>', '', 'once');

    try
        reader = java.io.StringReader(strippedXml);
        cleanup = onCleanup(@() reader.close()); %#ok<NASGU>
        source = org.xml.sax.InputSource(reader);
        doc = xmlread(source);
    catch ME
        error('ndr:format:smartspim:readStitcherXml:ParseFailed', ...
            'Failed to parse %s: %s', xmlPath, ME.message);
    end

    rootEl = doc.getDocumentElement();

    xmlData = struct();
    xmlData.voxelDims  = parseTriple(rootEl, 'voxel_dims',  xmlPath);
    xmlData.dimensions = parseDimensions(rootEl, xmlPath);
    xmlData.origin     = parseOriginOptional(rootEl);
    xmlData.stacks     = parseStacks(rootEl, xmlPath);
end

function el = getSingleChild(parent, tagName)
    nodes = parent.getElementsByTagName(tagName);
    if nodes.getLength() == 0
        el = [];
        return;
    end
    el = nodes.item(0);
end

function s = parseTriple(rootEl, tagName, xmlPath)
    el = getSingleChild(rootEl, tagName);
    if isempty(el)
        error('ndr:format:smartspim:readStitcherXml:MissingElement', ...
            '%s: missing <%s> element', xmlPath, tagName);
    end
    s = struct();
    for a = {'V', 'H', 'D'}
        v = getAttr(el, a{1});
        if isempty(v)
            error('ndr:format:smartspim:readStitcherXml:MissingAttribute', ...
                '%s: <%s> missing attribute "%s"', xmlPath, tagName, a{1});
        end
        s.(a{1}) = str2double(v);
    end
end

function origin = parseOriginOptional(rootEl)
    el = getSingleChild(rootEl, 'origin');
    if isempty(el)
        origin = [];
        return;
    end
    origin = struct();
    for a = {'V', 'H', 'D'}
        v = getAttr(el, a{1});
        if isempty(v)
            origin.(a{1}) = 0;
        else
            origin.(a{1}) = str2double(v);
        end
    end
end

function s = parseDimensions(rootEl, xmlPath)
    el = getSingleChild(rootEl, 'dimensions');
    if isempty(el)
        error('ndr:format:smartspim:readStitcherXml:MissingElement', ...
            '%s: missing <dimensions> element', xmlPath);
    end
    s = struct();
    attrs = {'stack_rows', 'stackRows'; ...
             'stack_columns', 'stackColumns'; ...
             'stack_slices', 'stackSlices'};
    for i = 1:size(attrs, 1)
        v = getAttr(el, attrs{i, 1});
        if isempty(v)
            error('ndr:format:smartspim:readStitcherXml:MissingAttribute', ...
                '%s: <dimensions> missing attribute "%s"', ...
                xmlPath, attrs{i, 1});
        end
        s.(attrs{i, 2}) = str2double(v);
    end
end

function stacks = parseStacks(rootEl, xmlPath)
    stacksEl = getSingleChild(rootEl, 'STACKS');
    if isempty(stacksEl)
        error('ndr:format:smartspim:readStitcherXml:MissingElement', ...
            '%s: missing <STACKS> element', xmlPath);
    end
    nodes = stacksEl.getElementsByTagName('Stack');
    n = nodes.getLength();
    if n == 0
        error('ndr:format:smartspim:readStitcherXml:NoStacks', ...
            '%s: no <Stack> elements found', xmlPath);
    end
    stacks = struct('row', {}, 'col', {}, 'absV', {}, 'absH', {}, ...
        'absD', {}, 'dirName', {}, 'zRanges', {});
    required = {'ROW', 'COL', 'ABS_V', 'ABS_H', 'ABS_D', 'DIR_NAME'};
    for i = 0:(n - 1)
        el = nodes.item(i);
        for a = 1:numel(required)
            if isempty(getAttr(el, required{a}))
                error('ndr:format:smartspim:readStitcherXml:MissingAttribute', ...
                    '%s: <Stack> #%d missing attribute "%s"', ...
                    xmlPath, i + 1, required{a});
            end
        end
        stacks(end+1) = struct( ...
            'row',     str2double(getAttr(el, 'ROW')), ...
            'col',     str2double(getAttr(el, 'COL')), ...
            'absV',    str2double(getAttr(el, 'ABS_V')), ...
            'absH',    str2double(getAttr(el, 'ABS_H')), ...
            'absD',    str2double(getAttr(el, 'ABS_D')), ...
            'dirName', getAttr(el, 'DIR_NAME'), ...
            'zRanges', getAttr(el, 'Z_RANGES')); %#ok<AGROW>
    end
end

function v = getAttr(el, name)
    node = el.getAttributeNode(name);
    if isempty(node)
        v = '';
    else
        v = char(node.getValue());
    end
end
