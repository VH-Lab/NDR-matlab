function data = invoke_binary(args, precision)
% INVOKE_BINARY - Run the sonpipe CLI and capture its raw binary output
%
%   DATA = invoke_binary(ARGS, PRECISION)
%
%   Runs the sonpipe CLI with argument string ARGS, redirecting its (binary)
%   stdout to a temporary file, then reads that file back as a column vector of
%   the given PRECISION (e.g. 'double', 'int16', 'single'). sonpipe writes
%   little-endian bytes, which are read back accordingly, mirroring the
%   "capture the pipe and typecast" pattern with an on-disk buffer (MATLAB's
%   system() mangles binary captured directly to a char array).
%
%   Informational messages from the CLI go to stderr and are captured to a
%   separate temporary file so the binary file stays pure sample bytes while we
%   can still inspect the CLI's diagnostics.
%
%   Crash detection. The underlying sonpy reader is a C++ library that, on some
%   files/channels, fails a runtime assertion and calls abort() (SIGABRT)
%   instead of raising a catchable Python error. That kills the whole reader
%   process mid-stream. Relying on the process exit status alone is not enough
%   to notice this: on Apple Silicon the CLI runs behind an 'arch -x86_64'
%   wrapper, and an intermediate wrapper process does not reliably propagate a
%   signal death as a non-zero status -- so a hard crash can otherwise look like
%   success and return truncated (or empty) data with no error. To catch it, we
%   also require the CLI's completion sentinel: a successful read prints
%   'sonpipe: wrote N ...' to stderr as its final act, and N must match the
%   number of samples we captured. A missing sentinel or a count mismatch means
%   the reader died mid-stream, and we raise an error that reports the exact
%   command and the captured diagnostics. (To find *where* sonpy crashed, set
%   the SONPIPE_LOG environment variable to '1' before the read; the CLI then
%   writes a breadcrumb log whose last line names the crashing sonpy call.)
%
%   This is a private helper for the +sonpipe package.

	arguments
		args      {mustBeTextScalar}
		precision {mustBeTextScalar}
	end

	exe = ndr.format.ced.sonpipe.executable();
	tmp = [tempname() '.bin'];
	errfile = [tempname() '.err'];
	cleaner    = onCleanup(@() deletefile(tmp));     %#ok<NASGU>
	cleanerErr = onCleanup(@() deletefile(errfile)); %#ok<NASGU>

	cmd = sprintf('%s %s > "%s" 2> "%s"', exe, args, tmp, errfile);
	[status, msg] = ndr.format.ced.sonpipe.runcmd(cmd);
	stderrTxt = readTextFile(errfile);
	if isempty(stderrTxt)
		stderrTxt = msg; % fall back to whatever runcmd captured
	end
	if status ~= 0
		error('sonpipe:cliError', ...
			'sonpipe failed (status %d) for command:\n  %s\n%s', ...
			status, cmd, stderrTxt);
	end

	fid = fopen(tmp, 'r', 'l'); % little-endian
	if fid < 0
		error('sonpipe:tmpRead', ...
			'Could not read sonpipe output file: %s', tmp);
	end
	closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
	data = fread(fid, Inf, ['*' precision]);
	data = data(:);

	% Validate against the CLI's completion sentinel to catch a mid-stream crash
	% that the exit status may have hidden (see the crash-detection note above).
	expected = parseWroteCount(stderrTxt);
	if isnan(expected)
		error('sonpipe:crash', ...
			['sonpipe did not report completion for command:\n  %s\n' ...
			 'The reader process appears to have crashed before finishing ' ...
			 '(a sonpy assertion/abort reads as SIGABRT). Captured messages:\n%s'], ...
			cmd, stderrTxt);
	elseif expected ~= numel(data)
		error('sonpipe:truncated', ...
			['sonpipe reported %d value(s) but %d were captured for command:\n  %s\n' ...
			 'The output is truncated -- the reader likely crashed mid-stream. ' ...
			 'Captured messages:\n%s'], ...
			expected, numel(data), cmd, stderrTxt);
	end
end

function n = parseWroteCount(stderrTxt)
% Parse the sample/event count from the CLI's completion sentinel, e.g.
%   "sonpipe: wrote 12345 samples (double) for channel 3"
%   "sonpipe: wrote 0 event times (double) for channel 5"
% Returns NaN if no sentinel is present (i.e. the read did not finish).
	n = NaN;
	if isempty(stderrTxt)
		return;
	end
	tok = regexp(stderrTxt, 'wrote\s+(\d+)\s+(?:samples|event times)', 'tokens', 'once');
	if ~isempty(tok)
		n = str2double(tok{1});
	end
end

function txt = readTextFile(fname)
	txt = '';
	if exist(fname, 'file')
		fid = fopen(fname, 'r');
		if fid >= 0
			txt = fread(fid, Inf, '*char')';
			fclose(fid);
		end
	end
end

function deletefile(fname)
	if exist(fname, 'file')
		delete(fname);
	end
end
