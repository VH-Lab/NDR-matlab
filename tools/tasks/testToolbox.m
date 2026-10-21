function testToolbox(varargin)
    projectRootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRootDir)
    matbox.installRequirements(fullfile(projectRootDir, 'tools'))
    % The cross-language symmetry tests (tools/tests/+ndr/+symmetry, all
    % tagged 'Symmetry') run in the symmetry workflows, which make the
    % artifacts they read and run them in order. Here they would only
    % repeat that work, with every pythonArtifacts case reported skipped
    % because Python never runs in this job. TestSymmetryTestsAreTagged
    % keeps the tag on every symmetry test, so none slips back in.
    matbox.tasks.testToolbox(projectRootDir, ...
        "SourceFolderName", "+ndr", ...
        "TestsFolderName", fullfile("tools", "tests"), ...
        "ExcludeTags", "Symmetry", ...
        varargin{:})
end
