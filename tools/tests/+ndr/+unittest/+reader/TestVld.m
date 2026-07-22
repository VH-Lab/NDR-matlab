classdef TestVld < matlab.unittest.TestCase
    % TESTVLD - Unit tests for ndr.reader.vld (VH Lab LabView .vld/.vlh)

    methods (Test)
        function testChannelLabelingConvention(testCase)
            % vld builds names with a 1-based loop counter (getchannelsepoch)
            % and inherits the base default of 'indexed'. Lock the contract.
            reader = ndr.reader.vld();
            for t = {'analog_in','time'}
                testCase.verifyEqual( ...
                    reader.channelLabelingConvention(t{1}), 'indexed', ...
                    sprintf('vld %s convention should be ''indexed''', t{1}));
            end
        end

        function testRoundTrip(testCase)
            % Write a small synthetic multiplexed int16 recording and read it
            % back through ndr.reader('vld'), checking channel listing, epoch
            % timing, data values, and the time base.

            num_channels = 3;
            samplerate = 100;
            samples_per_chunk = 100;
            scale = num_channels+1;
            chunk_total = 2;
            output_maxint = 2^15 - 1;

            tempdir_here = tempname();
            mkdir(tempdir_here);
            testCase.addTeardown(@() rmdir(tempdir_here,'s'));

            basename = 'vld_unittest';
            vldfile = fullfile(tempdir_here,[basename '.vld']);
            vlhfile = fullfile(tempdir_here,[basename '.vlh']);

            header.ChannelString = ['channels 1:' int2str(num_channels)];
            header.NumChans = num_channels;
            header.SamplingRate = samplerate;
            header.SamplesPerChunk = samples_per_chunk;
            header.Scale = scale;
            header.precision = 'int16';
            header.Multiplexed = 1;

            % write .vlh
            fn = fieldnames(header);
            fid_h = fopen(vlhfile,'wt');
            testCase.assertGreaterThan(fid_h,0,'Could not open header file for writing.');
            for i=1:numel(fn)
                val = header.(fn{i});
                if ischar(val)
                    fprintf(fid_h,[fn{i} ':\t' val '\n']);
                else
                    fprintf(fid_h,[fn{i} ':\t' mat2str(val) '\n']);
                end
            end
            fclose(fid_h);

            % write .vld (multiplexed, big-endian int16)
            Dexpected = [];
            fid_out = fopen(vldfile,'w','ieee-be');
            testCase.assertGreaterThan(fid_out,0,'Could not open data file for writing.');
            for c=1:chunk_total
                D = repmat((1:num_channels)',1,samples_per_chunk)+(c-1)*(0.1)+...
                    repmat((0:0.001:0.001*(samples_per_chunk-1)),num_channels,1);
                Dout = int16(D*output_maxint/scale);
                fwrite(fid_out,Dout,'int16',0,'ieee-be');
                Dexpected = [Dexpected ; single(Dout')*scale/output_maxint];
            end
            fclose(fid_out);

            total_samples = chunk_total*samples_per_chunk;

            r = ndr.reader('vld');

            % channel listing: time + N analog inputs
            channels = r.getchannelsepoch({vldfile});
            testCase.verifyEqual(numel(channels),num_channels+1);
            testCase.verifyEqual(channels(1).type,'time');
            testCase.verifyEqual(channels(2).name,'ai1');

            % epoch timing
            t0t1 = r.t0_t1({vldfile});
            testCase.verifyEqual(t0t1{1}(1),0,'AbsTol',1e-9);
            testCase.verifyEqual(t0t1{1}(2),(total_samples-1)/samplerate,'AbsTol',1e-9);

            % full read of each analog channel
            for c=1:num_channels
                [d,t] = r.read({vldfile},['ai' int2str(c)]);
                testCase.verifyEqual(numel(d),total_samples);
                testCase.verifyEqual(numel(t),total_samples);
                testCase.verifyLessThan(max(abs(double(d(:))-double(Dexpected(:,c)))),1e-3);
                testCase.verifyLessThan(max(abs(double(t(:))-(0:total_samples-1)'/samplerate)),1e-9);
            end

            % sub-range read using samples
            [d2,t2] = r.read({vldfile},'ai2','useSamples',1,'s0',10,'s1',20);
            testCase.verifyEqual(numel(d2),11);
            testCase.verifyLessThan(max(abs(double(d2(:))-double(Dexpected(10:20,2)))),1e-3);
            testCase.verifyLessThan(max(abs(double(t2(:))-((10:20)'-1)/samplerate)),1e-9);
        end

        function testHeaderValueIsNotEvaluated(testCase)
            % Regression for the .vlh eval() RCE: a header value must NEVER be
            % evaluated. A value that would run code must be stored verbatim
            % (no throw), and an arithmetic expression must be stored as the
            % literal string '1+1' (NOT 2 -- asserting 2 would lock in eval).
            tdir = tempname(); mkdir(tdir);
            testCase.addTeardown(@() rmdir(tdir,'s'));
            vlh = fullfile(tdir,'evil.vlh');
            fid = fopen(vlh,'wt');
            testCase.assertGreaterThan(fid,0);
            fprintf(fid,['NumChans:\t' '3' '\n']);
            fprintf(fid,['Evil:\t' 'error(''should not run'')' '\n']);
            fprintf(fid,['Expr:\t' '1+1' '\n']);
            fprintf(fid,['Name:\t' '/dev/ai0' '\n']);
            fclose(fid);

            s = ndr.format.vld.readvhlvheaderfile(vlh);
            % code was not executed and the payload is stored verbatim
            testCase.verifyEqual(s.Evil, 'error(''should not run'')');
            % an arithmetic expression is a literal string, not its value
            testCase.verifyEqual(s.Expr, '1+1');
            testCase.verifyNotEqual(s.Expr, 2);
            % legitimate numeric/string values still parse identically
            testCase.verifyEqual(s.NumChans, 3);
            testCase.verifyEqual(s.Name, '/dev/ai0');
        end

        function testHeaderRejectsInvalidFieldName(testCase)
            % A header line whose field name is not a valid MATLAB variable
            % name must be rejected with a specific error, not interpolated.
            tdir = tempname(); mkdir(tdir);
            testCase.addTeardown(@() rmdir(tdir,'s'));
            vlh = fullfile(tdir,'badfield.vlh');
            fid = fopen(vlh,'wt');
            testCase.assertGreaterThan(fid,0);
            fprintf(fid,['bad field:\t' '3' '\n']);   % space -> invalid field name
            fclose(fid);
            testCase.verifyError(@() ndr.format.vld.readvhlvheaderfile(vlh), ...
                'ndr:format:vld:invalidFieldName');
        end

        function testTotalSamplesIsFloored(testCase)
            % A byte-truncated .vld must not yield a fractional sample count:
            % t0_t1 must report an integer number of COMPLETE samples.
            num_channels = 3; samplerate = 100; unit_size = 8; % 'double'
            tdir = tempname(); mkdir(tdir);
            testCase.addTeardown(@() rmdir(tdir,'s'));
            basename = 'trunc';
            vld = fullfile(tdir,[basename '.vld']);
            vlh = fullfile(tdir,[basename '.vlh']);
            fid = fopen(vlh,'wt');
            fprintf(fid,['ChannelString:\t' 'channels 1:3' '\n']);
            fprintf(fid,['NumChans:\t' '3' '\n']);
            fprintf(fid,['SamplingRate:\t' '100' '\n']);
            fprintf(fid,['SamplesPerChunk:\t' '100' '\n']);
            fprintf(fid,['Multiplexed:\t' '1' '\n']);
            fclose(fid);
            % 10 complete multiplexed samples (3 doubles each) + 1 stray double
            % so the file size is NOT a whole multiple of NumChans*unit_size.
            fid = fopen(vld,'w','ieee-be');
            fwrite(fid, zeros(num_channels*10 + 1,1), 'double', 0, 'ieee-be');
            fclose(fid);
            r = ndr.reader('vld');
            t0t1 = r.t0_t1({vld});
            nsamp = round(t0t1{1}(2)*samplerate) + 1;
            testCase.verifyEqual(nsamp, 10, ...
                'total_samples must floor to the number of COMPLETE samples');
        end
    end
end
