function tf = sonpipe(varargin)
% ndr.setup.sonpipe - Check for, or get instructions to install, the sonpipe CLI
%
%   TF = ndr.setup.sonpipe()
%
%   Returns true if the sonpipe command-line tool is available to NDR, and
%   false otherwise. sonpipe is required only for reading 64-bit CED Spike2
%   files (the son64 format, normally .smrx); 32-bit files (.smr/.son) are read
%   with the built-in sigTOOL reader and need nothing extra.
%
%   When sonpipe is not found, this prints step-by-step installation
%   instructions rather than attempting a silent install (installing sonpipe
%   pulls in CED's sonpy, and choosing to obtain it should be the user's
%   explicit action).
%
%   ndr.setup.sonpipe('executable', CMD)
%
%   Records CMD as the command NDR should use to invoke sonpipe (for example
%   '/Users/me/.local/bin/sonpipe' or 'python3 -m sonpipe'), then reports
%   availability. This is forwarded to ndr.format.ced.sonpipe.executable.
%
%   Licensing: sonpipe itself is open-source (MIT). It installs CED's sonpy
%   (GPLv3, distributed as prebuilt binaries) as a dependency.
%
%   See also: ndr.format.ced.sonpipe.executable, ndr.format.ced.isSON64

	if nargin>=2 && ischar(varargin{1}) && strcmpi(varargin{1},'executable'),
		ndr.format.ced.sonpipe.executable(varargin{2});
	end

	tf = false;
	exe = '';
	try
		exe = ndr.format.ced.sonpipe.executable();
		tf = true;
	catch
		tf = false;
	end

	if tf,
		fprintf(1, ['sonpipe is available (%s).\n' ...
			'64-bit CED Spike2 (.smrx) file reading is enabled.\n'], exe);
		return;
	end

	fprintf(2, ['\n' ...
		'sonpipe was not found. NDR needs it to read 64-bit CED Spike2 (.smrx) files.\n' ...
		'(32-bit .smr/.son files do not need sonpipe.)\n' ...
		'\n' ...
		'sonpipe is open-source (MIT); it installs CED''s sonpy (GPLv3) as a dependency.\n' ...
		'\n' ...
		'To install:\n' ...
		'  1. Get sonpipe from https://github.com/VH-Lab/sonpipe and run its installer:\n' ...
		'       git clone https://github.com/VH-Lab/sonpipe.git\n' ...
		'       cd sonpipe\n' ...
		'       ./install.sh                 (Windows PowerShell: ./install.ps1 -AddToPath)\n' ...
		'  2. If the ''sonpipe'' command is not on your PATH, tell NDR where it is:\n' ...
		'       ndr.setup.sonpipe(''executable'', ''/full/path/to/sonpipe'')\n' ...
		'\n' ...
		'Note: sonpy requires Python 3.14; on Apple Silicon Macs use the python.org\n' ...
		'build (x86_64 under Rosetta). See the sonpipe README for platform details.\n' ...
		'\n']);
end
