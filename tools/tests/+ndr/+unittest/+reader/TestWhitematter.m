classdef TestWhitematter < matlab.unittest.TestCase
    methods (Test)
        function testFunctionExists(testCase)
            % Test that the read function exists
            testCase.verifyTrue(exist('ndr.format.whitematter.read', 'file') == 2, ...
                'The ndr.format.whitematter.read function should exist.');
        end
    end
end
