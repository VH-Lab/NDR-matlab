function pyExe = setup(options)
% ndr.util.blosc.setup - install (or verify) the private Blosc/Zstd venv.
%
%   PYEXE = ndr.util.blosc.setup()
%   PYEXE = ndr.util.blosc.setup('python', '/path/to/python3')
%   PYEXE = ndr.util.blosc.setup('wheelDir', '/path/to/wheels')
%   PYEXE = ndr.util.blosc.setup('force', true)
%
%   Creates a private virtualenv at <NDR-matlab>/private_env/blosc and
%   pip-installs `numcodecs` into it. Idempotent: when the venv already
%   has numcodecs importable, does nothing and returns the exe path.
%
%   Optional Name-Value:
%     python   - char, path to the python3 to bootstrap the venv from.
%                Empty (default) means "find python3 on PATH". Once the
%                venv exists this argument is not used.
%     wheelDir - char, a directory of pre-downloaded wheels for offline
%                installs (numcodecs + numpy). Empty means fetch from
%                PyPI over the network.
%     force    - logical, delete an existing venv and rebuild it.
%                Default false.
%
%   Returns the absolute path to the venv's python executable.
%
%   Design note (sonpipe pattern):
%     MATLAB's pyenv can only point at one Python at a time, and
%     changing it prompts a restart. Customers routinely have pyenv
%     wired to their analysis environment. This function installs into a
%     directory NDR owns and never calls `pyenv`; every invocation of
%     the Blosc tool goes through `system()` against the venv's own
%     python. The customer's Python setup is not touched.
%
%   Requirements:
%     * A `python3` on PATH the first time this runs, OR the `python`
%       Name-Value pointing at one. Python 3.9+.
%     * Network access to PyPI on that first run, OR a wheel directory
%       via 'wheelDir'.
%
%   See also: ndr.util.blosc.pythonExe, ndr.util.blosc.version.

    arguments
        options.python (1,:) char = ''
        options.wheelDir (1,:) char = ''
        options.force (1,1) logical = false
    end

    venvDir = ndr.util.blosc.venvDir();
    pyExe = venvExe(venvDir);

    if options.force && isfolder(venvDir)
        rmdir(venvDir, 's');
    end

    if isfile(pyExe) && ~options.force && importable(pyExe)
        return;
    end

    boot = resolveBootstrapPython(options.python);
    parent = fileparts(venvDir);
    if ~isfolder(parent)
        mkdir(parent);
    end

    cmd = sprintf('%s -m venv %s', shellQuote(boot), shellQuote(venvDir));
    [s, out] = system(cmd);
    if s ~= 0
        error('ndr:util:blosc:setup:VenvCreateFailed', ...
            ['Could not create Python venv at %s (bootstrap: %s).\n' ...
             'Output: %s'], venvDir, boot, strtrim(out));
    end
    if ~isfile(pyExe)
        error('ndr:util:blosc:setup:VenvMissingExe', ...
            'venv created but python executable is not at %s.', pyExe);
    end

    installArgs = 'numcodecs';
    if ~isempty(options.wheelDir)
        if ~isfolder(options.wheelDir)
            error('ndr:util:blosc:setup:WheelDirNotFound', ...
                'wheelDir %s does not exist.', options.wheelDir);
        end
        installArgs = sprintf('--no-index --find-links %s %s', ...
            shellQuote(options.wheelDir), installArgs);
    end
    cmd = sprintf('%s -m pip install --disable-pip-version-check --quiet %s', ...
        shellQuote(pyExe), installArgs);
    [s, out] = system(cmd);
    if s ~= 0
        error('ndr:util:blosc:setup:PipInstallFailed', ...
            'pip install failed (exit %d):\n%s', s, strtrim(out));
    end

    if ~importable(pyExe)
        error('ndr:util:blosc:setup:ImportFailed', ...
            ['pip reported success but `import numcodecs` failed in the ' ...
             'new venv at %s.'], venvDir);
    end
end

function p = venvExe(venvDir)
    if ispc
        p = fullfile(venvDir, 'Scripts', 'python.exe');
    else
        p = fullfile(venvDir, 'bin', 'python');
    end
end

function boot = resolveBootstrapPython(userSpec)
    if ~isempty(userSpec)
        if ~isfile(userSpec)
            error('ndr:util:blosc:setup:BootstrapNotFound', ...
                'Bootstrap Python not found at %s.', userSpec);
        end
        boot = userSpec;
        return;
    end
    if ispc
        [s, out] = system('where python3');
        if s ~= 0
            [s, out] = system('where python');
        end
    else
        [s, out] = system('command -v python3');
        if s ~= 0
            [s, out] = system('command -v python');
        end
    end
    if s ~= 0 || isempty(strtrim(out))
        error('ndr:util:blosc:setup:BootstrapMissing', ...
            ['No `python3` (or `python`) on PATH. Install Python 3.9+ ' ...
             '(brew install python, apt install python3-venv, or the ' ...
             'python.org installer on Windows) and re-run, or pass ' ...
             '''python'' pointing at an interpreter.']);
    end
    lines = strsplit(strtrim(out), newline);
    boot = strtrim(lines{1});
end

function tf = importable(pyExe)
    cmd = sprintf('%s -c "import numcodecs" 2>&1', shellQuote(pyExe));
    [s, ~] = system(cmd);
    tf = (s == 0);
end

function s = shellQuote(p)
    if ispc
        s = ['"' p '"'];
    else
        s = ['''' strrep(p, '''', '''\''''') ''''];
    end
end
