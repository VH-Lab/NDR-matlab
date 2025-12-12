classdef TestMightHaveTimeGaps < matlab.unittest.TestCase
    methods (Test)
        function testBaseProperty(testCase)
            baseReader = ndr.reader.base();
            testCase.verifyFalse(baseReader.MightHaveTimeGaps);
        end

        function testAxonAbfProperty(testCase)
            axonReader = ndr.reader.axon_abf();
            testCase.verifyTrue(axonReader.MightHaveTimeGaps);
        end

        function testReaderDelegation(testCase)
            % 'abf' maps to ndr.reader.axon_abf
            r_abf = ndr.reader('abf');
            testCase.verifyTrue(r_abf.MightHaveTimeGaps());

            % 'intan' maps to ndr.reader.intan_rhd, which should inherit false
            r_intan = ndr.reader('intan');
            testCase.verifyFalse(r_intan.MightHaveTimeGaps());
        end
    end
end
