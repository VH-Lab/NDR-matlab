function tf = isSmartSPIM(rootDir)
% ndr.format.smartspim.isSmartSPIM - is this a SmartSPIM acquisition directory?
%
%   TF = ndr.format.smartspim.ISSMARTSPIM(ROOTDIR)
%
%   Cheap non-throwing probe: returns TRUE if ROOTDIR is a directory that
%   looks like a LifeCanvas SmartSPIM raw acquisition, FALSE otherwise.
%
%   The probe requires:
%     * ROOTDIR is a folder
%     * ROOTDIR/metadata.json exists and parses as JSON
%     * ROOTDIR contains at least one channel directory whose name
%       matches "Ex_<digits>_Em_<chars>_Ch<digits>"
%
%   Any read/parse failure returns FALSE rather than raising, so callers
%   can use this to decide whether to attempt the SmartSPIM code path at
%   all. It does not validate the whole acquisition -- the discovery
%   functions themselves error with specific messages when their input
%   is malformed.

    tf = false;

    if ~(ischar(rootDir) || (isstring(rootDir) && isscalar(rootDir)))
        return;
    end
    rootDir = char(rootDir);

    if ~isfolder(rootDir)
        return;
    end

    metaPath = fullfile(rootDir, 'metadata.json');
    if ~isfile(metaPath)
        return;
    end

    try
        raw = fileread(metaPath);
        jsondecode(raw);
    catch
        return;
    end

    entries = dir(rootDir);
    for i = 1:numel(entries)
        e = entries(i);
        if ~e.isdir
            continue;
        end
        if ~isempty(regexp(e.name, '^Ex_\d+_Em_\w+_Ch\d+$', 'once'))
            tf = true;
            return;
        end
    end
end
