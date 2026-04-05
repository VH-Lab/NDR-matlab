function pg = probeGeometry(metafilename)
%PROBEGEOMETRY Extract probe geometry from a SpikeGLX .meta file.
%
%   PG = ndr.format.neuropixelsGLX.probeGeometry(METAFILENAME)
%
%   Reads a SpikeGLX .meta file and returns a structure whose fields match
%   the NDI probe_geometry document type. Electrode positions are taken
%   from the ~snsGeomMap field if present (SpikeGLX >= 20230202), or
%   computed from the ~imroTbl field and probe type for older files.
%
%   Inputs:
%       METAFILENAME - Full path to a SpikeGLX .meta file (char row vector).
%
%   Outputs:
%       PG - A scalar structure with the following fields:
%           site_locations_leftright : [N x 1] left-right positions in um
%           site_locations_frontback : [N x 1] front-back positions (zeros)
%           site_locations_depth     : [N x 1] depth positions in um
%           probe_model              : Probe model name (char)
%           manufacturer             : 'IMEC' (char)
%           shank_id                 : [N x 1] shank IDs (1-based integer)
%           contact_shape            : 'square' (char)
%           contact_shape_width      : [N x 1] contact widths in um
%           contact_shape_height     : [N x 1] contact heights in um
%           contact_shape_radius     : [N x 1] zeros (not circular)
%           ndim                     : 2 (integer)
%           unit                     : 'um' (char)
%           has_planar_contour       : 0 (integer)
%           contour_x                : [] (empty)
%           contour_y                : [] (empty)
%
%       where N is the number of neural channels (excluding sync).
%
%   Example:
%       pg = ndr.format.neuropixelsGLX.probeGeometry('/data/run_g0_t0.imec0.ap.meta');
%
%   See also: ndr.format.neuropixelsGLX.header, ndr.format.neuropixelsGLX.readmeta

    arguments
        metafilename (1,:) char {mustBeFile}
    end

    meta = ndr.format.neuropixelsGLX.readmeta(metafilename);
    info = ndr.format.neuropixelsGLX.header(metafilename);
    n_neural = info.n_neural_chans;

    % Try snsGeomMap first (available in newer SpikeGLX)
    geom_str = find_meta_field(meta, 'snsGeomMap');

    if ~isempty(geom_str)
        [x, y, shank] = parse_snsGeomMap(geom_str, n_neural);
    else
        % Fall back to computing geometry from imroTbl + probe type
        imro_str = find_meta_field(meta, 'imroTbl');
        if isempty(imro_str)
            error('ndr:format:neuropixelsGLX:probeGeometry:NoGeometry', ...
                'Meta file has neither snsGeomMap nor imroTbl.');
        end
        probe_type = str2double(info.probe_type);
        [x, y, shank] = compute_geometry_from_imro(imro_str, probe_type);
    end

    % Get probe model name and contact size
    probe_type_num = str2double(info.probe_type);
    [model_name, contact_size] = probe_type_info(probe_type_num);

    % Build output structure
    pg = struct();
    pg.site_locations_leftright = x(:);
    pg.site_locations_frontback = zeros(n_neural, 1);
    pg.site_locations_depth = y(:);
    pg.probe_model = model_name;
    pg.manufacturer = 'IMEC';
    pg.shank_id = shank(:);
    pg.contact_shape = 'square';
    pg.contact_shape_width = repmat(contact_size, n_neural, 1);
    pg.contact_shape_height = repmat(contact_size, n_neural, 1);
    pg.contact_shape_radius = zeros(n_neural, 1);
    pg.ndim = 2;
    pg.unit = 'um';
    pg.has_planar_contour = 0;
    pg.contour_x = [];
    pg.contour_y = [];

end


function value = find_meta_field(meta, target)
%FIND_META_FIELD Find a field in the meta struct by partial name match.
%   Handles the fact that readmeta transforms '~' prefixed field names
%   (e.g. ~snsGeomMap becomes x_snsGeomMap via makeValidName).

    value = '';
    fields = fieldnames(meta);
    for i = 1:numel(fields)
        if contains(fields{i}, target, 'IgnoreCase', true)
            value = meta.(fields{i});
            return;
        end
    end

end


function [x, y, shank] = parse_snsGeomMap(geommap_str, n_neural)
%PARSE_SNSGEOMMAP Parse the snsGeomMap string for electrode positions.
%
%   Format: (header)(shank:x:y:used)(shank:x:y:used)...
%   Header: (probePN,nShanks,shankSep,shankWidth) — skipped.
%   Each channel entry has colon-separated integers: shank:x:y:used.

    tokens = regexp(geommap_str, '\(([^)]+)\)', 'tokens');

    if numel(tokens) < 1 + n_neural
        error('ndr:format:neuropixelsGLX:probeGeometry:BadGeomMap', ...
            'snsGeomMap has %d entries but expected at least %d (header + %d neural).', ...
            numel(tokens), 1 + n_neural, n_neural);
    end

    x = zeros(n_neural, 1);
    y = zeros(n_neural, 1);
    shank = zeros(n_neural, 1);

    % Skip the first token (header), parse channel entries
    for i = 1:n_neural
        parts = sscanf(tokens{i + 1}{1}, '%d:%d:%d:%d');
        if numel(parts) < 4
            error('ndr:format:neuropixelsGLX:probeGeometry:BadGeomMapEntry', ...
                'Could not parse snsGeomMap entry %d: "%s".', i, tokens{i+1}{1});
        end
        shank(i) = parts(1) + 1; % Convert 0-based to 1-based
        x(i) = parts(2);
        y(i) = parts(3);
    end

end


function [x, y, shank] = compute_geometry_from_imro(imroTbl_str, probe_type)
%COMPUTE_GEOMETRY_FROM_IMRO Compute electrode positions from imroTbl.
%
%   Supported probe types:
%       0          — Neuropixels 1.0 (staggered 2-column, 20 um pitch)
%       21, 2003,
%       2004       — Neuropixels 2.0 single shank (2-column, 15 um pitch)
%       24, 2013,
%       2014       — Neuropixels 2.0 four shank (2-column, 15 um pitch)

    tokens = regexp(imroTbl_str, '\(([^)]+)\)', 'tokens');
    if numel(tokens) < 2
        error('ndr:format:neuropixelsGLX:probeGeometry:BadImroTbl', ...
            'Could not parse imroTbl: too few parenthesized groups.');
    end

    n_chans = numel(tokens) - 1; % First token is the header
    x = zeros(n_chans, 1);
    y = zeros(n_chans, 1);
    shank = ones(n_chans, 1);

    switch probe_type
        case 0
            % Neuropixels 1.0
            % Entry format: (chanIdx bank refIdx apGain lfGain apHiPass)
            % Electrode ID = chanIdx + bank * 384
            % Staggered 2-column layout, 20 um vertical pitch
            for i = 1:n_chans
                vals = sscanf(tokens{i + 1}{1}, '%d %d %d %d %d %d');
                elec_id = vals(1) + vals(2) * 384;
                row = floor(elec_id / 2);
                col = mod(elec_id, 2);
                y(i) = row * 20;
                if mod(row, 2) == 0
                    x(i) = 27 + col * 32;
                else
                    x(i) = 11 + col * 32;
                end
            end

        case {21, 2003, 2004}
            % Neuropixels 2.0 single shank
            % Entry format: (chanIdx bankMask refIdx elecInd)
            % 2-column layout, 15 um vertical pitch
            for i = 1:n_chans
                vals = sscanf(tokens{i + 1}{1}, '%d %d %d %d');
                elec_ind = vals(4);
                row = floor(elec_ind / 2);
                col = mod(elec_ind, 2);
                y(i) = row * 15;
                x(i) = 27 + col * 32;
            end

        case {24, 2013, 2014}
            % Neuropixels 2.0 four shank
            % Entry format: (chanIdx shankIdx bankMask refIdx elecInd)
            % 2-column layout per shank, 15 um pitch, 250 um shank spacing
            for i = 1:n_chans
                vals = sscanf(tokens{i + 1}{1}, '%d %d %d %d %d');
                shank_idx = vals(2);
                elec_ind = vals(5);
                row = floor(elec_ind / 2);
                col = mod(elec_ind, 2);
                y(i) = row * 15;
                x(i) = shank_idx * 250 + 27 + col * 32;
                shank(i) = shank_idx + 1;
            end

        otherwise
            error('ndr:format:neuropixelsGLX:probeGeometry:UnsupportedProbe', ...
                ['Probe type %d is not supported for geometry computation from ' ...
                 'imroTbl. Use a SpikeGLX version that writes ~snsGeomMap ' ...
                 'to the .meta file.'], probe_type);
    end

end


function [model_name, contact_size] = probe_type_info(probe_type)
%PROBE_TYPE_INFO Return probe model name and contact size for a probe type.

    switch probe_type
        case 0
            model_name = 'Neuropixels 1.0';
            contact_size = 12;
        case {21, 2003, 2004}
            model_name = 'Neuropixels 2.0 Single Shank';
            contact_size = 12;
        case {24, 2013, 2014}
            model_name = 'Neuropixels 2.0 Four Shank';
            contact_size = 12;
        case {1100, 1110}
            model_name = 'Neuropixels Ultra';
            contact_size = 6;
        otherwise
            model_name = sprintf('Neuropixels (type %d)', probe_type);
            contact_size = 12;
    end

end
