classdef TestSymmetryTestsAreTagged < matlab.unittest.TestCase
    % TESTSYMMETRYTESTSARETAGGED - every symmetry test carries the 'Symmetry' tag.
    %
    % The general test job (tools/tasks/testToolbox.m) excludes tests tagged
    % 'Symmetry', because the cross-language symmetry tests run in the
    % symmetry workflows instead. The exclusion is only as good as the tags:
    % a new symmetry test written without one would quietly run in the
    % general job again. This test fails if any test under ndr.symmetry is
    % untagged, so the tag cannot be forgotten.

    methods (Test)
        function testEverySymmetryTestIsTagged(testCase)
            import matlab.unittest.TestSuite
            suite = TestSuite.fromPackage("ndr.symmetry", "IncludingSubpackages", true);
            testCase.assertNotEmpty(suite, ...
                'No tests found under ndr.symmetry; is tools/tests on the path?');
            isTagged = arrayfun(@(t) any(strcmp(t.Tags, 'Symmetry')), suite);
            untagged = {suite(~isTagged).Name};
            testCase.verifyEmpty(untagged, sprintf( ...
                ['These symmetry tests lack the ''Symmetry'' tag, so the general ' ...
                 'test job would run them: %s. Declare the class as ' ...
                 'classdef (TestTags = {''Symmetry''}) <name> < matlab.unittest.TestCase.'], ...
                strjoin(untagged, ', ')));
        end
    end
end
