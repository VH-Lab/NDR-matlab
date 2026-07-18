classdef TestSonpipeIntegration < matlab.unittest.TestCase
% ndr.unittest.format.ced.TestSonpipeIntegration - Real-sonpy .smrx read path
%
%   Reads the checked-in 64-bit CED file example_data/spike2data.smrx through
%   the real sonpipe CLI (and CED's sonpy), exercising ndr.format.ced's 64-bit
%   dispatch, the +ced/+sonpipe adapter, and the ced_smr reader end-to-end.
%
%   Skipped unless a working sonpipe CLI is available (so it does not fail the
%   ordinary matbox test run, where sonpy is not installed). The dedicated
%   test-smrx CI workflow installs sonpipe (non-interactively, via
%   ndr.setup.sonpipe) so this runs there for real.

	properties
		File
		Header
	end

	methods (TestClassSetup)
		function setup(tc)
			here = fileparts(mfilename('fullpath'));
			repo = here;
			for k = 1:6   % .../tools/tests/+ndr/+unittest/+format/+ced -> repo root
				repo = fileparts(repo);
			end
			tc.File = fullfile(repo, 'example_data', 'spike2data.smrx');
			tc.assumeTrue(isfile(tc.File), ...
				sprintf('example_data/spike2data.smrx not found (%s).', tc.File));
			tc.assumeTrue(ndr.format.ced.isSON64(tc.File), ...
				'example_data/spike2data.smrx is not a son64 file.');
			try
				tc.Header = ndr.format.ced.read_SOMSMR_header(tc.File);
			catch ME
				tc.assumeFail(['sonpipe CLI / sonpy not available; skipping real ' ...
					'.smrx integration. (' ME.message ')']);
			end
		end
	end

	methods (Test)
		function testHeaderHasChannels(tc)
			tc.verifyNotEmpty(tc.Header.channelinfo);
			tc.verifyTrue(all(isfinite([tc.Header.channelinfo.number])));
			tc.verifyGreaterThan(tc.Header.fileinfo.dTimeBase, 0);
		end

		function testWaveformRead(tc)
			wf = [];
			for k = 1:numel(tc.Header.channelinfo)
				if any(tc.Header.channelinfo(k).kind == [1 9])
					wf = tc.Header.channelinfo(k);
					break;
				end
			end
			tc.assumeNotEmpty(wf, 'no waveform channel in the example file.');

			si = ndr.format.ced.read_SOMSMR_sampleinterval(tc.File, tc.Header, wf.number);
			tc.verifyGreaterThan(1/si, 0);

			t1 = min(1, wf.max_time);   % read up to 1 s (or the whole channel)
			[d, ~, ~, ~, t] = ndr.format.ced.read_SOMSMR_datafile( ...
				tc.File, tc.Header, wf.number, 0, t1);
			tc.verifyNotEmpty(d);
			tc.verifyTrue(all(isfinite(d)));
			tc.verifyEqual(numel(t), numel(d));
		end

		function testReaderEndToEnd(tc)
			r = ndr.reader.ced_smr();
			channels = r.getchannelsepoch({tc.File}, 1);
			tc.verifyNotEmpty(channels);
		end
	end
end
