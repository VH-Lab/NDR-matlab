classdef MockDerivedReader < ndr.reader
    % MOCKDERIVEDREADER - Mock ndr.reader for testing derived digital events.
    %
    % Overrides samplerate and readchannels_epochsamples so that the REAL
    % ndr.reader/readevents_epochsamples derived-event logic (dep/den/dimp/dimn)
    % runs against a synthetic digital square wave, with no file on disk.

    properties
        Digital  % column vector of 0/1 digital samples
        SR       % sample rate (Hz)
    end

    methods
        function obj = MockDerivedReader(digital, sr)
            obj@ndr.reader('rec'); % any registered type; underlying base is unused
            obj.Digital = digital(:);
            obj.SR = sr;
        end

        function sr = samplerate(obj, epochstreams, epoch_select, channeltype, channel) %#ok<INUSD>
            sr = obj.SR;
        end

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1) %#ok<INUSD>
            if iscell(channeltype), ctype = channeltype{1}; else, ctype = channeltype; end
            n = numel(obj.Digital);
            s0 = max(1,s0); s1 = min(n,s1);
            idx = s0:s1;
            if strcmp(ctype,'time')
                data = (idx(:)-1)/obj.SR; % sample 1 occurs at t==0
            else % 'di'
                data = obj.Digital(idx);
            end
        end
    end
end
