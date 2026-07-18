classdef TestSonpipeRead < matlab.unittest.TestCase
% ndr.unittest.format.ced.TestSonpipeRead - 64-bit CED read path via a fake CLI
%
%   Exercises the ndr.format.ced 64-bit dispatch and the +ced/+sonpipe adapter
%   end-to-end by pointing ndr.format.ced.sonpipe.executable at a self-contained
%   fake sonpipe CLI (fake_sonpipe.py, standard-library Python only). No CED
%   binaries, sonpy, or numpy are required. Tests are skipped if a Python 3
%   interpreter is not available.

	properties
		File   % temporary son64 file (first bytes 'S64...'); content served by the fake
	end

	methods (TestClassSetup)
		function configureFakeCli(tc)
			here = fileparts(mfilename('fullpath'));
			fake = fullfile(here, 'fake_sonpipe.py');

			py = '';
			for c = {'python3', 'python'}
				[s, ~] = ndr.format.ced.sonpipe.runcmd([c{1} ' --version']);
				if s == 0, py = c{1}; break; end
			end
			tc.assumeFalse(isempty(py), ...
				'Python 3 not found; skipping sonpipe adapter read tests.');

			cmd = sprintf('%s "%s"', py, fake);
			[s, ~] = ndr.format.ced.sonpipe.runcmd([cmd ' --version']);
			tc.assumeEqual(s, 0, 'fake sonpipe CLI not runnable; skipping.');

			ndr.format.ced.sonpipe.executable(cmd);

			% A file whose leading bytes make ndr.format.ced.isSON64 return true.
			tc.File = [tempname() '.smrx'];
			fid = fopen(tc.File, 'w', 'l');
			fwrite(fid, uint8('S64pl'), 'uint8');
			fwrite(fid, zeros(1, 64, 'uint8'), 'uint8');
			fclose(fid);
		end
	end

	methods (TestClassTeardown)
		function cleanupFile(tc)
			if ~isempty(tc.File) && exist(tc.File, 'file')
				delete(tc.File);
			end
			% Reset the cached executable so the fake CLI does not leak into
			% other tests (e.g. TestSonpipeIntegration, which needs the real one).
			ndr.format.ced.sonpipe.executable('');
		end
	end

	methods (Test)
		function testDispatchDetectsSON64(tc)
			tc.verifyTrue(ndr.format.ced.isSON64(tc.File));
		end

		function testHeader(tc)
			h = ndr.format.ced.read_SOMSMR_header(tc.File);
			tc.verifyEqual([h.channelinfo.number], [1 4 6]);
			tc.verifyEqual(h.fileinfo.dTimeBase, 1e-6, 'RelTol', 1e-9);
			tc.verifyEqual(h.fileinfo.maxFTime, 100000);
			ci = ndr.format.ced.sonpipe.channelinfo(h, 1);
			tc.verifyEqual(ci.kind, 1);
			tc.verifyEqual(ci.samplerate, 10000, 'RelTol', 1e-6);
		end

		function testSampleInterval(tc)
			[si, ns, tt] = ndr.format.ced.read_SOMSMR_sampleinterval(tc.File, [], 1);
			tc.verifyEqual(si, 1e-4, 'RelTol', 1e-6);
			tc.verifyEqual(ns, 1000);
			tc.verifyEqual(tt, 0.1, 'RelTol', 1e-6);
		end

		function testEventIntervalIsNaN(tc)
			si = ndr.format.ced.read_SOMSMR_sampleinterval(tc.File, [], 4);
			tc.verifyTrue(isnan(si));
		end

		function testWaveformRead(tc)
			[d, ts, tt, bi, t] = ndr.format.ced.read_SOMSMR_datafile(tc.File, [], 1, 0, Inf);
			tc.verifyEqual(numel(d), 1000);
			tc.verifyEqual(size(d, 2), 1);           % column
			tc.verifyEqual(d(1), 0, 'AbsTol', 1e-9);  % fake emits value == sample index
			tc.verifyEqual(d(2), 1, 'AbsTol', 1e-9);
			tc.verifyEqual(t(1), 0, 'AbsTol', 1e-12);
			tc.verifyEqual(t(2), 1e-4, 'RelTol', 1e-6);
			tc.verifyEmpty(bi);
			tc.verifyEqual(ts, 1000);
		end

		function testWaveformTimeWindow(tc)
			[d, ~, ~, ~, ~] = ndr.format.ced.read_SOMSMR_datafile(tc.File, [], 1, 0, 0.005);
			tc.verifyGreaterThanOrEqual(numel(d), 50);
			tc.verifyLessThanOrEqual(numel(d), 52);
		end

		function testEventRead(tc)
			[d, ~, ~, ~, t] = ndr.format.ced.read_SOMSMR_datafile(tc.File, [], 4, 0, Inf);
			tc.verifyEqual(d, t);                     % events: data == time
			tc.verifyEqual(d(1), 0, 'AbsTol', 1e-12);
			tc.verifyEqual(d(2), 1e-4, 'RelTol', 1e-6);
		end

		function testTextMarkerRead(tc)
			[d, ~, ~, ~, t] = ndr.format.ced.read_SOMSMR_datafile(tc.File, [], 6, 0, Inf);
			tc.verifyTrue(ischar(d));
			tc.verifyEqual(size(d, 1), numel(t));
		end

		function testReaderEndToEnd(tc)
			% The ced_smr reader should transparently read the son64 file.
			r = ndr.reader.ced_smr();
			channels = r.getchannelsepoch({tc.File}, 1);
			names = {channels.name};
			tc.verifyTrue(any(strcmp(names, 'ai1')));   % analog_in channel 1
			d = r.readchannels_epochsamples('ai', 1, {tc.File}, 1, 1, 100);
			tc.verifyEqual(numel(d), 100);
			tc.verifyEqual(d(1), 0, 'AbsTol', 1e-9);
		end
	end
end
