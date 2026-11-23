function result = checkMexResolution()
% ndr.util.blosc.checkMexResolution - is the resolving +blosc backed by a MEX?
%
%   RESULT = ndr.util.blosc.checkMexResolution()
%
%   Checks that the blosc-matlab wrappers NDR calls (blosc.encode,
%   blosc.encodeChunk, blosc.decode) resolve on the current MATLAB path
%   AND that each resolves to a +blosc folder with the compiled MEX
%   (private/blosc_mex.<mexext>) next to it. A wrapper only sees the
%   private/ folder of the +blosc folder it lives in, so a +blosc
%   package without the MEX (for example a source checkout of
%   blosc-matlab) that is ahead on the path -- or in the current folder
%   -- makes every call fail with "Undefined function 'blosc_mex'",
%   even if a working install is also on the path.
%
%   This is cheap (one WHICH and one ISFILE per wrapper) and is called
%   by ndr.util.blosc.ensureMex on every call.
%
%   Returns a struct with:
%     ok     - logical; true if every wrapper resolves to a +blosc
%              folder that has private/blosc_mex.<mexext>.
%     folder - char; the +blosc folder blosc.encode resolves to (or the
%              first offending folder when ok is false); '' if nothing
%              resolves.
%     reason - char; empty when ok, otherwise a diagnostic naming the
%              offending wrapper and folder.
%
%   See also ndr.util.blosc.ensureMex.

    result = struct('ok', false, 'folder', '', 'reason', '');
    mexName = ['blosc_mex.' mexext];
    wrappers = {'blosc.encode', 'blosc.encodeChunk', 'blosc.decode'};

    for i = 1:numel(wrappers)
        wrapperPath = which(wrappers{i});
        if isempty(wrapperPath)
            result.reason = sprintf( ...
                '%s does not resolve on the MATLAB path.', wrappers{i});
            return;
        end
        wrapperFolder = fileparts(wrapperPath);
        if i == 1
            result.folder = wrapperFolder;
        end
        if ~isfile(fullfile(wrapperFolder, 'private', mexName))
            result.folder = wrapperFolder;
            result.reason = sprintf(['%s resolves to %s, which has no ' ...
                'private/%s (a blosc-matlab copy without its compiled ' ...
                'MEX, such as a source checkout, is shadowing the ' ...
                'installed one).'], wrappers{i}, wrapperFolder, mexName);
            return;
        end
    end

    result.ok = true;
end
