function files = getRHD2000FileList(filename, fileMode)
% GETRHD2000FILELIST - Get the list of RHD2000 files comprising a recording
%
%  FILES = GETRHD2000FILELIST(FILENAME, FILEMODE)
%
%  Given a single .rhd FILENAME, return a cell array of full-path file names
%  that together make up the recording.
%
%  FILEMODE may be:
%    'singleFile' (default) - The recording is a single .rhd file. Returns a
%       cell array containing just FILENAME.
%    'multiFile'  - The recording is spread across many .rhd files saved by
%       the Intan acquisition software with the same base prefix and a
%       <YYMMDD>_<HHMMSS> timestamp before the extension. Returns the sorted
%       (chronological) list of all files in the same directory matching
%       '<prefix>_<YYMMDD>_<HHMMSS>.rhd', where <prefix> is parsed from
%       FILENAME.
%
%  See also: READ_INTAN_RHD2000_HEADER, READ_INTAN_RHD2000_DATAFILE

if nargin < 2 || isempty(fileMode),
    fileMode = 'singleFile';
end;

switch fileMode,
    case 'singleFile',
        files = {filename};
    case 'multiFile',
        [dirname, fname, ext] = fileparts(filename);
        if isempty(dirname),
            dirname = pwd;
        end;
        % parse <prefix>_YYMMDD_HHMMSS
        tok = regexp(fname, '^(.*)_(\d{6})_(\d{6})$', 'tokens', 'once');
        if isempty(tok),
            error(['Filename ' filename ' does not match the Intan multi-file pattern <prefix>_YYMMDD_HHMMSS' ext '.']);
        end;
        prefix = tok{1};
        d = dir(fullfile(dirname, [prefix '_*_*' ext]));
        keep = false(1, numel(d));
        timestamps = cell(1, numel(d));
        prefix_pattern = ['^' regexptranslate('escape', prefix) '_(\d{6})_(\d{6})$'];
        for i = 1:numel(d),
            [~, name_i, ~] = fileparts(d(i).name);
            t_i = regexp(name_i, prefix_pattern, 'tokens', 'once');
            if ~isempty(t_i),
                keep(i) = true;
                timestamps{i} = [t_i{1} t_i{2}];
            end;
        end;
        d = d(keep);
        timestamps = timestamps(keep);
        if isempty(d),
            error(['No RHD multi-file set found for prefix ' prefix ' in ' dirname '.']);
        end;
        [~, order] = sort(timestamps);
        d = d(order);
        files = cell(1, numel(d));
        for i = 1:numel(d),
            files{i} = fullfile(dirname, d(i).name);
        end;
    otherwise,
        error(['Unknown fileMode: ' fileMode '. Use ''singleFile'' or ''multiFile''.']);
end;
