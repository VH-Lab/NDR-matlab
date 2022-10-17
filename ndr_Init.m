function ndr_Init
% NDR_INIT - initalize a global variable ndr_globals with default file paths

myndrpath = fileparts(which('ndr_Init'));

 % remove any paths that have the string 'NDR-matlab' so we don't have stale paths confusing anyone

pathsnow = path;
pathsnow_cell = split(pathsnow,pathsep);
matches = contains(pathsnow_cell, 'NDR-matlab');
pathstoremove = char(strjoin(pathsnow_cell(matches),pathsep));
rmpath(pathstoremove);

  % add everyelement except '.git' directories
pathstoadd = genpath(myndrpath);
pathstoadd_cell = split(pathstoadd,pathsep);
matches=(~contains(pathstoadd_cell,'.git'))&(~contains(pathstoadd_cell,'.ndr_globals'));
pathstoadd = char(strjoin(pathstoadd_cell(matches),pathsep));
addpath(pathstoadd);

ndr.globals;

 % paths

ndr_globals.path = [];

ndr_globals.path.path = myndrpath;
ndr_globals.path.temppath = [tempdir filesep 'ndrtemp'];
ndr_globals.path.testpath = [tempdir filesep 'ndrtestcode'];
ndr_globals.path.filecachepath = [userpath filesep 'Documents' filesep 'NDR' filesep 'NDR-filecache'];
ndr_globals.path.preferences = [userpath filesep 'Preferences' filesep' 'NDR'];

if ~exist(ndr_globals.path.temppath,'dir'),
        mkdir(ndr_globals.path.temppath);
end;

if ~exist(ndr_globals.path.testpath,'dir'),
        mkdir(ndr_globals.path.testpath);
end;

if ~exist(ndr_globals.path.filecachepath,'dir'),
        mkdir(ndr_globals.path.filecachepath);
end;

if ~exist(ndr_globals.path.preferences,'dir'),
        mkdir(ndr_globals.path.preferences);
end;

ndr_globals.debug.verbose = 1;

 % test write access to preferences, testpath, filecache, temppath
paths = {ndr_globals.path.testpath, ndr_globals.path.temppath, ndr_globals.path.filecachepath, ndr_globals.path.preferences};
pathnames = {'NDR test path', 'NDR temporary path', 'NDR filecache path', 'NDR preferences path'};

for i=1:numel(paths),
        fname = [paths{i} filesep 'testfile_' int2str(fix(10000*rand)) '.txt'];
        fid = fopen(fname,'wt');
        if fid<0,
                error(['We do not have write access to the ' pathnames{i} ' at '  paths{i} '.']);
        end;
        fclose(fid);
        delete(fname);
end;

ndr.reader.neo.insert_python_path()


