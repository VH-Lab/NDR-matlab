function txt = invoke_text(args)
% INVOKE_TEXT - Run the sonpipe CLI and capture its text (JSON) output
%
%   TXT = invoke_text(ARGS)
%
%   ARGS is the argument string passed to the sonpipe CLI (everything after the
%   executable name). Returns the captured stdout (the JSON payload) as a char
%   row vector. Raises an error if the CLI exits with a nonzero status.
%
%   The CLI's informational/diagnostic messages go to stderr, which is captured
%   to a separate temporary file. Keeping stderr out of the returned text means
%   a warning (or a crash's abort text) can never corrupt the JSON that the
%   caller hands to jsondecode; on failure the captured stderr is included in
%   the error so the reason is visible. If the reader crashes hard (a sonpy
%   assertion/abort, which reads as SIGABRT), set the SONPIPE_LOG environment
%   variable to '1' before the call to get a breadcrumb log pinpointing the
%   crashing sonpy call.
%
%   This is a private helper for the +sonpipe package.

	arguments
		args {mustBeTextScalar}
	end

	exe = ndr.format.ced.sonpipe.executable();
	errfile = [tempname() '.err'];
	cleanerErr = onCleanup(@() deletefile(errfile)); %#ok<NASGU>

	cmd = sprintf('%s %s 2> "%s"', exe, args, errfile);
	[status, txt] = ndr.format.ced.sonpipe.runcmd(cmd);
	if status ~= 0
		stderrTxt = readTextFile(errfile);
		error('sonpipe:cliError', ...
			'sonpipe failed (status %d) for command:\n  %s\n%s', ...
			status, cmd, stderrTxt);
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
