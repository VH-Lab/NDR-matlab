function meta = readmeta(metafilename)
%READMETA Read and parse a SpikeGLX .meta file into a structure.
%
%   META = ndr.format.neuropixelsGLX.readmeta(METAFILENAME)
%
%   Reads a SpikeGLX metadata file (.ap.meta or .lf.meta) and returns a
%   structure where each key=value line in the file becomes a field.
%
%   The SpikeGLX .meta file format consists of lines of the form:
%       key=value
%   where key is an alphanumeric string (with possible tildes) and value
%   is a string. This function preserves all values as strings; numeric
%   conversion is left to the caller.
%
%   Inputs:
%       METAFILENAME - Full path to the .meta file (char row vector).
%
%   Outputs:
%       META - A scalar structure whose field names are the keys from the
%              .meta file and whose values are the corresponding value
%              strings.
%
%   Example:
%       meta = ndr.format.neuropixelsGLX.readmeta('/data/run_g0/run_g0_imec0/run_g0_t0.imec0.ap.meta');
%       disp(meta.imSampRate);  % e.g., '30000'
%       disp(meta.nSavedChans); % e.g., '385'
%
%   See also: ndr.format.neuropixelsGLX.header

    arguments
        metafilename (1,:) char {mustBeFile}
    end

    meta = struct();

    fid = fopen(metafilename, 'r');
    if fid == -1
        error('ndr:format:neuropixelsGLX:readmeta:FileOpenError', ...
            'Could not open meta file: %s', metafilename);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        line = strtrim(line);
        if isempty(line)
            continue;
        end

        eqPos = strfind(line, '=');
        if isempty(eqPos)
            continue;
        end

        key = strtrim(line(1:eqPos(1)-1));
        value = strtrim(line(eqPos(1)+1:end));

        % Replace characters that are invalid in MATLAB field names
        key = strrep(key, '~', '_');
        key = strrep(key, '.', '_');

        % Ensure key starts with a letter
        if ~isempty(key) && isvarname(key)
            meta.(key) = value;
        else
            % Try to make it a valid field name
            key = matlab.lang.makeValidName(key);
            meta.(key) = value;
        end
    end

end
