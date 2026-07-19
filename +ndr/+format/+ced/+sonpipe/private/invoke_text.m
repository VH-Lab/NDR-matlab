function txt = invoke_text(args)
% INVOKE_TEXT - Run the sonpipe CLI and capture its text (JSON) output
%
%   TXT = invoke_text(ARGS)
%
%   ARGS is the argument string passed to the sonpipe CLI (everything after the
%   executable name). Returns the captured stdout as a char row vector. Raises
%   an error if the CLI exits with a nonzero status.
%
%   This is a private helper for the +sonpipe package.

	arguments
		args {mustBeTextScalar}
	end

	exe = ndr.format.ced.sonpipe.executable();
	cmd = [exe ' ' args];
	[status, txt] = ndr.format.ced.sonpipe.runcmd(cmd);
	if status ~= 0
		error('sonpipe:cliError', ...
			'sonpipe failed (status %d) for command:\n  %s\n%s', ...
			status, cmd, txt);
	end
end
