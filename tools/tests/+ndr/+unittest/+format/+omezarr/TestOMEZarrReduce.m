classdef TestOMEZarrReduce < matlab.unittest.TestCase
    % TestOMEZarrReduce - block-reduction helper used by pyramid builders
    %
    % Self-contained: no fixture, no toolbox required.

    methods (Test)
        function testMeanScalarFactor(testCase)
            a = [1 2; 3 4];
            r = ndr.format.omezarr.reduce(a, 2, 'mean');
            testCase.verifyEqual(size(r), [1 1]);
            testCase.verifyEqual(r(1,1), 2.5, 'AbsTol', 1e-12);
        end

        function testMaxScalarFactor(testCase)
            a = uint16([1 2; 3 4]);
            r = ndr.format.omezarr.reduce(a, 2, 'max');
            testCase.verifyEqual(size(r), [1 1]);
            testCase.verifyEqual(r(1,1), uint16(4));
            testCase.verifyClass(r, 'uint16');
        end

        function testMeanPromotesToDouble(testCase)
            a = uint8([1 2; 3 4]);
            r = ndr.format.omezarr.reduce(a, 2, 'mean');
            testCase.verifyClass(r, 'double');
        end

        function testTrailingPartialBlockKept(testCase)
            % An axis of length 5 with factor 2 must produce 3 samples
            % (blocks of 2, 2, 1). Matches how the lab's NGFF writers
            % size coarser levels.
            a = 1:5;
            r = ndr.format.omezarr.reduce(a, 2, 'max');
            testCase.verifyEqual(size(r), [1 3]);
            testCase.verifyEqual(r, [2 4 5]);
        end

        function testPerAxisFactorVector(testCase)
            % 4x6 with factors [2 3] -> 2x2 output. Mean case.
            a = reshape(1:24, 4, 6);
            r = ndr.format.omezarr.reduce(a, [2 3], 'mean');
            testCase.verifyEqual(size(r), [2 2]);
        end

        function testWrongFactorArityErrors(testCase)
            a = zeros(3, 4);
            testCase.verifyError( ...
                @() ndr.format.omezarr.reduce(a, [2 2 2], 'mean'), ...
                'ndr:format:omezarr:reduce:BadFactor');
        end

        function testFactorMustBePositiveInteger(testCase)
            a = zeros(4);
            testCase.verifyError( ...
                @() ndr.format.omezarr.reduce(a, 0, 'mean'), ...
                'MATLAB:validators:mustBePositive');
        end

        function testReductionMustBeMember(testCase)
            a = zeros(4);
            testCase.verifyError( ...
                @() ndr.format.omezarr.reduce(a, 2, 'median'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testFactorOnePassesThrough(testCase)
            % Factor 1 on every axis should reproduce the input (mean
            % returns double, max preserves dtype).
            a = uint16([1 2 3; 4 5 6]);
            r = ndr.format.omezarr.reduce(a, 1, 'max');
            testCase.verifyEqual(r, a);
        end
    end
end
