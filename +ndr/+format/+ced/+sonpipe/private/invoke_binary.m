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
%   Informational messages from the CLI go to stderr and are not captured here,
%   so the temporary file contains pure sample bytes.
%
%   This is a private helper for the +sonpipe package.

	arguments
		args      {mustBeTextScalar}
		precision {mustBeTextScalar}
	end

	exe = ndr.format.ced.sonpipe.executable();
	tmp = [tempname() '.bin'];
	cleaner = onCleanup(@() deletefile(tmp));

	cmd = sprintf('%s %s > "%s"', exe, args, tmp);
	[status, msg] = ndr.format.ced.sonpipe.runcmd(cmd);
	if status ~= 0
		error('sonpipe:cliError', ...
			'sonpipe failed (status %d) for command:\n  %s\n%s', ...
			status, cmd, msg);
	end

	fid = fopen(tmp, 'r', 'l'); % little-endian
	if fid < 0
		error('sonpipe:tmpRead', ...
			'Could not read sonpipe output file: %s', tmp);
	end
	closer = onCleanup(@() fclose(fid));
	data = fread(fid, Inf, ['*' precision]);
	data = data(:);
end

function deletefile(fname)
	if exist(fname, 'file')
		delete(fname);
	end
end
