function tf = hasAllChannels(rootDir)
% ndr.format.smartspim.hasAllChannels - does this acquisition have a usable All_Channels volume?
%
%   TF = ndr.format.smartspim.HASALLCHANNELS(ROOTDIR)
%
%   Cheap non-throwing probe: returns TRUE if ROOTDIR/All_Channels holds
%   SmartSPIM's stitched, flat-field-corrected slices for EVERY channel
%   of the acquisition, FALSE otherwise (folder missing, no slices, a
%   channel's _ch<k> slices missing, unreadable input).
%
%   Only file names are inspected; no TIFF header is opened. Readers use
%   this to prefer the stitched All_Channels volume and to fall back to
%   the per-tile Ex_* layout for acquisitions where AutoStitch has not
%   been run (or All_Channels was not restored from the archive).
%
%   See also: ndr.format.smartspim.readAllChannelsInfo

    arguments
        rootDir
    end

    tf = false;
    if ~(ischar(rootDir) || (isstring(rootDir) && isscalar(rootDir)))
        return;
    end
    rootDir = char(rootDir);
    if isempty(rootDir) || ~isfolder(fullfile(rootDir, 'All_Channels'))
        return;
    end
    try
        ndr.format.smartspim.readAllChannelsInfo(rootDir, 'ReadHeader', false);
        tf = true;
    catch
        tf = false;
    end
end
