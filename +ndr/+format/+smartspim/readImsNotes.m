function notes = readImsNotes(rootDir)
% ndr.format.smartspim.readImsNotes - SmartSPIM's record of which channel is which Ch<k>
%
%   NOTES = ndr.format.smartspim.READIMSNOTES(ROOTDIR)
%
%   Reads ROOTDIR/IMS_Notes.txt, which the SmartSPIM software writes when
%   it converts the stitched All_Channels volume to Imaris, with one line
%   per channel such as
%
%       The folder Ex_561_Em_561F_stitched is represented as Ch0 with a Hex color value of #ff0000
%
%   and returns a struct array, one entry per such line:
%
%     channelName  char, the channel folder (the "<channel>_stitched"
%                  folder named, without "_stitched"), e.g. 'Ex_561_Em_561F'
%     chIndex      double, the k of that channel's All_Channels _Ch<k>
%                  slices (and of Imaris channel k)
%
%   This is the stitcher's own statement of the channel-to-Ch<k> mapping,
%   so ndr.format.smartspim.readAllChannelsInfo prefers it to inferring
%   the mapping from filter-channel numbers. An absent or unreadable file,
%   or one with no such lines, gives an empty struct array; it never errors.
%
%   See also: ndr.format.smartspim.readAllChannelsInfo,
%             ndr.format.smartspim.listChannels

    notes = struct('channelName', {}, 'chIndex', {});
    if isstring(rootDir) && isscalar(rootDir)
        rootDir = char(rootDir);
    end
    if ~ischar(rootDir) || isempty(rootDir)
        return
    end
    p = fullfile(rootDir, 'IMS_Notes.txt');
    if ~isfile(p)
        return
    end
    try
        txt = fileread(p);
    catch
        return
    end
    tok = regexp(txt, ...
        'The folder\s+(\S+?)_stitched\s+is represented as\s+Ch(\d+)', ...
        'tokens', 'ignorecase');
    for i = 1:numel(tok)
        notes(end+1) = struct('channelName', tok{i}{1}, ...
            'chIndex', str2double(tok{i}{2})); %#ok<AGROW>
    end
end
