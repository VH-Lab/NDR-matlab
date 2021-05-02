function [channelnameprefix, channelnumber] = channelstring2channels(channelstring)
% ndr.string.channelstring2channels - convert a channel string to an array of channel prefiex and numbers
%
% [CHANNELNAMEPREFIX, CHANNELNUMBER] = ...
%      ndr.string.channelstring2channels(CHANNELSTRING)
%
% Given a CHANNELSTRING, returns a cell array of channel prefixes and
% an array of channel numbers that correspond to the CHANNELSTRING.
% 
% A CHANNELSTRING is a means of specifying channels that have prefixes and
% numbers. It includes a sequence of letters, followed by numbers to specify
% the channels. One can indicate a sequential range of channels by using a
% dash ('-') and one can enumerate individual channels with a comma (',').
% Different channel prefixes can be specified by placing a plus ('+') between
% sets of channels.
%
% Examples: 
%      [cp, cn] = ndr.string.channelstring2channels('a1,3-5,2')
%      % cp == {'a','a','a','a','a'}'
%      % cn == [1 3 4 5 2]'
%      [cp, cn] = ndr.string.channelstring2channels('ai1-3+b2-4')
%      % cp == {'ai','ai','ai','b','b','b'}'
%      % cn == [ 1 2 3 2 3 4]'

channelstring = strtrim(channelstring); % trim white space

block_separator = '+';

seps = [0 find(channelstring==block_separator) numel(channelstring)+1];

channelnameprefix = {};
channelnumber = [];

for i=2:numel(seps),
	string_here = strtrim(channelstring(seps(i-1)+1:seps(i)-1));
	letters = isletter(string_here);
	first_non_letter = find(letters==0,1,'first');
	if isempty(first_non_letter),
		error(['No numbers provided in channel string segment ' string_here '.']);
	end;
	prefix_here = {string_here(1:first_non_letter-1)};
	numbers_here = ndr.string.str2intseq(string_here(first_non_letter:end));
	channelnameprefix = cat(1,channelnameprefix,repmat(prefix_here,numel(numbers_here),1));
	channelnumber = cat(1,channelnumber(:),numbers_here(:));
end;

