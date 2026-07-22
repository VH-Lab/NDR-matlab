classdef TestDerivedEvents < matlab.unittest.TestCase
    % TESTDERIVEDEVENTS - Regression tests for ndr.reader/readevents_epochsamples
    % derived digital events (dep/den/dimp/dimn).
    %
    % Before the fix the derived-event branch referenced an undefined variable
    % ('epochfiles') and called samplerate with the wrong arity, so it always
    % threw; rising edges were reported one sample early; and 'dimn' silently
    % degraded to 'den' (its off-transition test checked 'dimp'). These tests
    % use a synthetic square wave via MockDerivedReader to lock in the contract.

    methods (Static)
        function [r, sr, n] = makeReader()
            % Square wave: two positive pulses.
            %   index:  1 2 3 4 5 6 7 8 9 10
            %   value:  0 0 1 1 0 0 1 1 0 0
            d  = [0 0 1 1 0 0 1 1 0 0];
            sr = 1000;
            n  = numel(d);
            r  = MockDerivedReader(d, sr);
        end
    end

    methods (Test)
        function testDepReachableAndFirstOneIndex(testCase)
            % dep must be reachable (no throw) and report the FIRST '1' sample
            % of each 0->1 transition (indices 3 and 7 -> t = 0.002, 0.006).
            [r, sr, n] = TestDerivedEvents.makeReader();
            [ts, data] = r.readevents_epochsamples({'dep'}, 1, {'x'}, 1, 0, (n-1)/sr);
            testCase.verifyEqual(ts(:), [0.002; 0.006], 'AbsTol', 1e-9);
            testCase.verifyEqual(data(:), [1; 1]);
        end

        function testDepEqualsDimpOnTimes(testCase)
            % dep on-times must equal dimp's on (+1) times: both are the first
            % sample of the 0->1 transition.
            [r, sr, n] = TestDerivedEvents.makeReader();
            [tsDep, ~]    = r.readevents_epochsamples({'dep'},  1, {'x'}, 1, 0, (n-1)/sr);
            [tsDimp, dDimp] = r.readevents_epochsamples({'dimp'}, 1, {'x'}, 1, 0, (n-1)/sr);
            onTimes = tsDimp(dDimp==1);
            testCase.verifyEqual(sort(onTimes(:)), sort(tsDep(:)), 'AbsTol', 1e-9);
        end

        function testDimpOnOffConsistentConvention(testCase)
            % dimp (positive impulse 0->1->0) must emit an on (+1) at each 0->1
            % first-'1' sample and an off (-1) at each 1->0 first-'0' sample,
            % using the SAME "first sample at the new level" convention.
            [r, sr, n] = TestDerivedEvents.makeReader();
            [ts, data] = r.readevents_epochsamples({'dimp'}, 1, {'x'}, 1, 0, (n-1)/sr);
            % on at indices 3,7 (t=0.002,0.006); off at indices 5,9 (t=0.004,0.008)
            testCase.verifyEqual(ts(data==1),  [0.002; 0.006], 'AbsTol', 1e-9);
            testCase.verifyEqual(ts(data==-1), [0.004; 0.008], 'AbsTol', 1e-9);
        end

        function testDimnReturnsBothEdgesAndDiffersFromDen(testCase)
            % dimn (negative impulse) must return BOTH edges (this is the
            % line-368 copy-paste fix). den returns only the 1->0 edges, so
            % dimn must NOT equal den.
            [r, sr, n] = TestDerivedEvents.makeReader();
            [tsDimn, dDimn] = r.readevents_epochsamples({'dimn'}, 1, {'x'}, 1, 0, (n-1)/sr);
            [tsDen,  ~]     = r.readevents_epochsamples({'den'},  1, {'x'}, 1, 0, (n-1)/sr);
            % dimn emits 4 events (2 on + 2 off); den emits 2.
            testCase.verifyEqual(numel(tsDimn), 4);
            testCase.verifyEqual(numel(tsDen), 2);
            testCase.verifyTrue(any(dDimn==-1), 'dimn must emit off (-1) transitions');
            testCase.verifyNotEqual(numel(tsDimn), numel(tsDen));
        end

        function testDenOnTimes(testCase)
            % den (negative edge) on-times are the 1->0 transition samples
            % (indices 4 and 8 -> t = 0.003, 0.007).
            [r, sr, n] = TestDerivedEvents.makeReader();
            [ts, data] = r.readevents_epochsamples({'den'}, 1, {'x'}, 1, 0, (n-1)/sr);
            testCase.verifyEqual(ts(:), [0.003; 0.007], 'AbsTol', 1e-9);
            testCase.verifyEqual(data(:), [1; 1]);
        end
    end
end
