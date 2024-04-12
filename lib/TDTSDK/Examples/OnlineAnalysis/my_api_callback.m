function result = my_api_callback(s)
%MY_API_CALLBACK APIStreamer callback function
%   This is called during every polling loop after the APIStreamer
%   retrieves new data. It exposes the timer's object data, which includes
%   the following:
%     s.data      array, the current history
%     s.ts        array, current timestamp array
%     s.new_data  array, just the latest retrieved data
%     s.syn       SynapseAPI object, for making SynapseAPI calls
%     s.TD        TDevAccX object, if 'USE_TDEV' was set true, this allows
%                   faster setting of parameter tags. Use with caution.

%clc
fprintf('new data:\t %d samples\n', size(s.new_data, 2));
result = 1;

% DO CUSTOM PROCESSING HERE
% s.new_data is just the newest data, s.data is the current 'history'

% Example 1:
%  Send all values directly back to Synapse to test round-trip latency
% for i = 1:numel(s.new_data)
%     if s.use_tdev
%         if check_server(s.TD)
%             result = s.TD.SetTargetVal([s.tag_prefix 'Feedback'], s.new_data(i));
%         else % fall back to using Synapse API
%             result = s.syn.setParameterValue(s.gizmo, 'Feedback', s.new_data(i));    
%         end
%     else 
%         result = s.syn.setParameterValue(s.gizmo, 'Feedback', s.new_data(i));
%     end
% end

% Example 2:
%  Send just the latest value back to Synapse
% if s.use_tdev
%     if check_server(s)
%         result = s.TD.SetTargetVal([s.tag_prefix 'Feedback'], s.data(end));
%     else % fall back to using Synapse API
%         result = s.syn.setParameterValue(s.gizmo, 'Feedback', s.data(end));
%     end
% else
%     result = s.syn.setParameterValue(s.gizmo, 'Feedback', s.data(end));
% end

end