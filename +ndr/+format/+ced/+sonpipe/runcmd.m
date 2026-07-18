function [status, out] = runcmd(cmd)
% SONPIPE.RUNCMD - Run a system command with a Python-safe environment
%
%   [STATUS, OUT] = ndr.format.ced.sonpipe.runcmd(CMD)
%
%   Wrapper around SYSTEM that temporarily clears LD_LIBRARY_PATH and
%   DYLD_LIBRARY_PATH before running CMD, then restores them. MATLAB overrides
%   these variables with paths to its own bundled shared libraries; if a child
%   Python process inherits them it may load MATLAB's (often older) libraries
%   instead of its own and fail to start. Clearing them for the duration of the
%   call lets the system/Conda/venv Python run normally.
%
%   On Windows this is a plain passthrough to SYSTEM.
%
%   See also ndr.format.ced.sonpipe.executable

	if ispc
		[status, out] = system(cmd);
		return;
	end

	names = {'LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH'};
	saved = cell(size(names));
	for i = 1:numel(names)
		saved{i} = getenv(names{i});
		setenv(names{i}, '');
	end
	restorer = onCleanup(@() restoreEnv(names, saved)); %#ok<NASGU>

	[status, out] = system(cmd);
end

function restoreEnv(names, saved)
	for i = 1:numel(names)
		setenv(names{i}, saved{i});
	end
end
