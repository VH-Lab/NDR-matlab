function tf = sonpipe(varargin)
% ndr.setup.sonpipe - Check, install, or configure the sonpipe CLI (non-interactive)
%
%   TF = ndr.setup.sonpipe()
%
%   Returns true if the sonpipe command-line tool is available to NDR, false
%   otherwise. sonpipe is required only for reading 64-bit CED Spike2 files (the
%   son64 format, normally .smrx); 32-bit files (.smr/.son) need nothing extra.
%
%   This function is fully NON-INTERACTIVE: it never prompts. When sonpipe is
%   missing it prints installation guidance to stderr and returns false. It is
%   never called automatically (e.g. from ndr_Init); you run it explicitly.
%
%   Options (name/value):
%
%   ndr.setup.sonpipe('install', true)
%       Install sonpipe non-interactively with pip (headless-safe). Use in
%       controlled/automated environments. On Apple Silicon, pass a 'python'
%       that runs x86_64 (see the sonpipe README) or use sonpipe's install.sh.
%
%   ndr.setup.sonpipe('install', true, 'python', PYCMD)
%       Install into the interpreter invoked by PYCMD (default: auto-detect
%       python3.14 / python3 / python).
%
%   ndr.setup.sonpipe('install', true, 'source', SPEC)
%       pip source to install (default 'sonpipe'; e.g. a
%       'git+https://github.com/VH-Lab/sonpipe.git' spec before a PyPI release).
%
%   ndr.setup.sonpipe('executable', CMD)
%       Record CMD as the command NDR should use to invoke sonpipe (for example
%       '/Users/me/.local/bin/sonpipe' or 'python3 -m sonpipe').
%
%   Licensing: sonpipe itself is open-source (MIT). It installs CED's sonpy
%   (GPL v3, shipped by CED as prebuilt binaries) as a dependency.
%
%   Troubleshooting a crash while reading a file:
%
%   CED's sonpy is a compiled binary that, on some files, fails an internal
%   assertion and aborts its own process. NDR's reader detects a mid-read abort
%   and raises a 'sonpipe:crash'/'sonpipe:truncated' error instead of returning
%   truncated data. To find WHICH sonpy call is responsible, turn on sonpipe's
%   breadcrumb log and re-run the failing read:
%
%       setenv('SONPIPE_LOG', '1');   % or a full path to a log file
%       ... % the read that crashes
%       setenv('SONPIPE_LOG', '');    % turn logging back off
%
%   sonpipe then writes a line before and after every call into sonpy (flushed
%   so it survives the abort) to ~/.local/var/log/sonpipe-<uid>.log; the last
%   line names the crashing call. See the sonpipe README ("Troubleshooting")
%   for how to read the log.
%
%   See also: ndr.format.ced.sonpipe.executable, ndr.format.ced.isSON64

	opts = struct('executable', '', 'install', false, 'source', 'sonpipe', 'python', '');
	i = 1;
	while i <= numel(varargin)
		name = varargin{i};
		if ~ischar(name) || i+1 > numel(varargin)
			error('ndr:setup:sonpipe:badArgs', 'Options must be name/value pairs.');
		end
		val = varargin{i+1};
		switch lower(name)
			case 'executable', opts.executable = val;
			case 'install',    opts.install = logical(val);
			case 'source',     opts.source = val;
			case 'python',     opts.python = val;
			otherwise, error('ndr:setup:sonpipe:badArgs', 'Unknown option: %s', name);
		end
		i = i + 2;
	end

	if ~isempty(opts.executable)
		ndr.format.ced.sonpipe.executable(opts.executable);
	end

	if opts.install
		tf = doInstall(opts);
		return;
	end

	% Detect and report (no install requested).
	[tf, exe] = detect();
	if tf
		fprintf(1, 'sonpipe is available (%s).\n64-bit CED Spike2 (.smrx) reading is enabled.\n', exe);
	else
		printInstructions();
	end
end

function [tf, exe] = detect()
	tf = false; exe = '';
	try
		exe = ndr.format.ced.sonpipe.executable();
		tf = true;
	catch
		tf = false;
	end
end

function py = locatePython()
	py = '';
	for c = {'python3.14', 'python3', 'python'}
		[s, ~] = ndr.format.ced.sonpipe.runcmd([c{1} ' --version']);
		if s == 0, py = c{1}; return; end
	end
end

function tf = doInstall(opts)
	tf = false;
	py = opts.python;
	if isempty(py)
		py = locatePython();
	end
	if isempty(py)
		fprintf(2, 'ndr.setup.sonpipe: no Python interpreter found to install into.\n');
		return;
	end

	fprintf(1, 'ndr.setup.sonpipe: installing sonpipe into "%s" (source: %s) ...\n', ...
		py, opts.source);
	[s, out] = ndr.format.ced.sonpipe.runcmd( ...
		sprintf('%s -m pip install --upgrade %s', py, opts.source));
	if s ~= 0
		fprintf(2, 'ndr.setup.sonpipe: install failed (status %d):\n%s\n', s, out);
		return;
	end

	% Verify the freshly installed CLI runs (this also confirms sonpy imports).
	[s2, ~] = ndr.format.ced.sonpipe.runcmd(sprintf('%s -m sonpipe --version', py));
	if s2 ~= 0
		fprintf(2, ['ndr.setup.sonpipe: sonpipe installed but did not run. On macOS ' ...
			'Apple Silicon, sonpy needs an x86_64 Python; see the sonpipe README.\n']);
		return;
	end

	ndr.format.ced.sonpipe.executable(sprintf('%s -m sonpipe', py));
	fprintf(1, 'ndr.setup.sonpipe: sonpipe installed and available via "%s -m sonpipe".\n', py);
	tf = true;
end

function printInstructions()
	fprintf(2, ['\n' ...
		'sonpipe was not found. NDR needs it to read 64-bit CED Spike2 (.smrx) files.\n' ...
		'(32-bit .smr/.son files do not need sonpipe.)\n' ...
		'\n' ...
		'sonpipe is open-source (MIT); it installs CED''s sonpy (GPL v3) as a dependency.\n' ...
		'\n' ...
		'Install options:\n' ...
		'  - Non-interactive (this function):\n' ...
		'       ndr.setup.sonpipe(''install'', true)\n' ...
		'  - Recommended (isolated venv + PATH + macOS handling), from a clone of\n' ...
		'    https://github.com/VH-Lab/sonpipe :\n' ...
		'       ./install.sh            (Windows PowerShell: ./install.ps1 -AddToPath)\n' ...
		'  - Already installed elsewhere? Point NDR at it:\n' ...
		'       ndr.setup.sonpipe(''executable'', ''/full/path/to/sonpipe'')\n' ...
		'\n' ...
		'Note: sonpy requires Python 3.14; on Apple Silicon use the python.org build\n' ...
		'(x86_64 under Rosetta). See the sonpipe README for platform details.\n' ...
		'\n']);
end
