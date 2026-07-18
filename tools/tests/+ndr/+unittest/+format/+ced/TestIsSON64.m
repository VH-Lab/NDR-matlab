classdef TestIsSON64 < matlab.unittest.TestCase
% ndr.unittest.format.ced.TestIsSON64 - Tests for ndr.format.ced.isSON64
%
%   Pure-MATLAB tests (no CLI / Python required) that the son64 vs son32
%   discriminator reads the file's leading magic bytes correctly.

	methods (Test)
		function testSON64Detected(tc)
			f = [tempname() '.smrx'];
			fid = fopen(f, 'w', 'l');
			fwrite(fid, uint8('S64pl'), 'uint8');
			fwrite(fid, zeros(1, 16, 'uint8'), 'uint8');
			fclose(fid);
			cleaner = onCleanup(@() delete(f)); %#ok<NASGU>
			tc.verifyTrue(ndr.format.ced.isSON64(f));
		end

		function testSON32NotDetected(tc)
			% A legacy son32 file begins with a small integer systemID, not 'S64'.
			f = [tempname() '.smr'];
			fid = fopen(f, 'w', 'l');
			fwrite(fid, int16(1), 'int16');
			fwrite(fid, zeros(1, 64, 'uint8'), 'uint8');
			fclose(fid);
			cleaner = onCleanup(@() delete(f)); %#ok<NASGU>
			tc.verifyFalse(ndr.format.ced.isSON64(f));
		end

		function testShortFileNotDetected(tc)
			% Fewer than 3 bytes cannot match the 'S64' magic.
			f = [tempname() '.dat'];
			fid = fopen(f, 'w', 'l');
			fwrite(fid, uint8('S6'), 'uint8');
			fclose(fid);
			cleaner = onCleanup(@() delete(f)); %#ok<NASGU>
			tc.verifyFalse(ndr.format.ced.isSON64(f));
		end

		function testMissingFileErrors(tc)
			tc.verifyError(@() ndr.format.ced.isSON64('/no/such/file.smrx'), ...
				'ndr:format:ced:isSON64:cannotOpen');
		end
	end
end
