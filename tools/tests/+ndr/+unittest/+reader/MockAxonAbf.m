classdef MockAxonAbf < ndr.reader.axon_abf
    % MOCKAXONABF - Mock class for testing ndr.reader.axon_abf
    %
    % This class inherits from ndr.reader.axon_abf and overrides
    % readchannels_epochsamples to return a predefined time vector.
    % This allows testing samples2times and times2samples without a real file.

    properties
        TimeVector
    end

    methods
        function obj = MockAxonAbf(t_vec)
            % Constructor
            % t_vec: Column vector of time points
            obj.TimeVector = t_vec;
        end

        function data = readchannels_epochsamples(obj, channeltype, channel, epochstreams, epoch_select, s0, s1)
            % Mock implementation returns TimeVector for 'time' channel

            % Check channeltype
            if iscell(channeltype)
                ctype = channeltype{1};
            else
                ctype = channeltype;
            end

            if strcmp(ctype, 'time')
                % Return the full time vector (ignoring s0, s1 as samples2times calls with -inf, inf)
                % In a real scenario, we would slice, but for testing the gap logic,
                % samples2times requests everything.
                data = obj.TimeVector(:);
            else
                error('MockAxonAbf only supports reading time channel.');
            end
        end
    end
end
