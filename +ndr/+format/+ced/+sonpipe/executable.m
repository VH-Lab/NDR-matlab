function exe = executable(newvalue)
% SONPIPE.EXECUTABLE - Locate, set, or query the sonpipe command-line tool
%
%   EXE = ndr.format.ced.sonpipe.executable()
%
%   Returns a command string that invokes the sonpipe CLI (for example
%   'sonpipe' or 'python3 -m sonpipe'). The result is cached for the MATLAB
%   session after the first successful lookup.
%
%   ndr.format.ced.sonpipe.executable(NEWVALUE)
%
%   Sets (and caches) the command string to NEWVALUE. Use this if the CLI is
%   installed somewhere that is not on the system PATH, e.g.
%      ndr.format.ced.sonpipe.executable('/opt/venv/bin/sonpipe')
%      ndr.format.ced.sonpipe.executable('python3 -m sonpipe')
%
%   Lookup order when no value is cached:
%     1. the SONPIPE environment variable, if set
%     2. 'sonpipe' on the system PATH
%     3. 'python3 -m sonpipe'
%     4. 'python -m sonpipe'
%
%   Each candidate is verified by running "<candidate> --version".
%
%   See also ndr.format.ced.sonpipe.read_SOMSMR_header

	persistent CACHED

	if nargin >= 1
		CACHED = newvalue;
		exe = CACHED;
		return;
	end

	if ~isempty(CACHED)
		exe = CACHED;
		return;
	end

	candidates = {};
	envval = getenv('SONPIPE');
	if ~isempty(envval)
		candidates{end+1} = envval;
	end
	candidates{end+1} = 'sonpipe';
	candidates{end+1} = 'python3 -m sonpipe';
	candidates{end+1} = 'python -m sonpipe';

	for i = 1:numel(candidates)
		[status, ~] = ndr.format.ced.sonpipe.runcmd([candidates{i} ' --version']);
		if status == 0
			CACHED = candidates{i};
			exe = CACHED;
			return;
		end
	end

	error('ndr:format:ced:sonpipe:executableNotFound', ...
		['Could not locate the sonpipe command-line tool, which NDR uses to read ' ...
		 '64-bit CED Spike2 (.smrx) files. Run ''ndr.setup.sonpipe'' for installation ' ...
		 'instructions, or point NDR at an existing install with ' ...
		 'ndr.format.ced.sonpipe.executable(PATH) or the SONPIPE environment variable.']);
end
