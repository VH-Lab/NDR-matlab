% ndr.format.textSignal.about.m
%
% This file contains documentation for the ndr.format.textSignal file format.
%
% The file format is defined as follows:
%
% Each line is tab-delimited text with the following columns:
%
%   channel<tab>time<tab>command<tab>value(s)
%
% 1. channel: An integer representing the channel number.
% 2. time: A real number or a datestamp in UTC format 'YYYY-MM-DDTHH:mm:ss.sssZ'.
%    The time unit must be consistent throughout the file.
% 3. command and value(s): (Commands are case-insensitive)
%    - 'SET X': Sets the channel to the value X at the given time.
%    - 'RAMP X Y ENDTIME': Linearly ramps the channel's value from X at the given
%      time to Y at ENDTIME. ENDTIME has the same format as the time column.
%    - 'NONE': No command, used for timestamping events.
%
% To view this help text, type 'help ndr.format.textSignal.about' at the MATLAB command line.
