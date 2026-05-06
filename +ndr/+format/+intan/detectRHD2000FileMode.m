function fileMode = detectRHD2000FileMode(filename)
% DETECTRHD2000FILEMODE - Detect whether an RHD file is part of a multi-file recording
%
%  FILEMODE = DETECTRHD2000FILEMODE(FILENAME)
%
%  Returns 'multiFile' when FILENAME follows the Intan
%  '<prefix>_<YYMMDD>_<HHMMSS>.rhd' naming convention and at least one
%  additional sibling file in the same directory shares that prefix and
%  matches the same timestamp pattern. Returns 'singleFile' otherwise.
%
%  See also: GETRHD2000FILELIST, READ_INTAN_RHD2000_HEADER, READ_INTAN_RHD2000_DATAFILE

[dirname, fname, ext] = fileparts(filename);
if isempty(dirname),
    dirname = pwd;
end;

tok = regexp(fname, '^(.*)_(\d{6})_(\d{6})$', 'tokens', 'once');
if isempty(tok),
    fileMode = 'singleFile';
    return;
end;

prefix = tok{1};
prefix_pattern = ['^' regexptranslate('escape', prefix) '_(\d{6})_(\d{6})$'];
d = dir(fullfile(dirname, [prefix '_*_*' ext]));

count = 0;
for i = 1:numel(d),
    [~, name_i, ~] = fileparts(d(i).name);
    if ~isempty(regexp(name_i, prefix_pattern, 'once')),
        count = count + 1;
        if count > 1,
            fileMode = 'multiFile';
            return;
        end;
    end;
end;
fileMode = 'singleFile';
