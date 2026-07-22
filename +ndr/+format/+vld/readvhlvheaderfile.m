function mystruct = readvhlvheaderfile(myfilename)
% READVHLVHEADERFILE - Read VHLV (VH Lab LabView) header file format
%
%  HEADERSTRUCT = ndr.format.vld.readvhlvheaderfile(MYFILENAME)
%
%   Reads the header file format for the VHLAB LabView
%   multichannel acquisition system.
%
%   It expects MYFILENAME to be the name of a text file (extension '.vlh'),
%   where each line begins with a field name followed by a colon ':' and then
%   a tab, followed by the value. The expected fields are 'ChannelString', which
%   indicates the channel names that were acquired in the LabView system, 'NumChans',
%   the number of channels that were acquired, 'SamplingRate', the sampling rate of
%   each channel in Hz, and 'SamplesPerChunk', which indicates how many samples were
%   written to disk in each burst of recording.  'Multiplexed' indicates
%   whether adjacent samples are from different channels (1) or if
%   the channel data is loaded in groups of SamplesPerChunk (0).
%
%   The channel numbers correspond to the inputs described in 'ChannelString'.
%   For example, if ChannelString is '/dev/ai0', then there is just 1 channel
%   and it corresponds to analog input 0 on the acquisition device.
%
%   Use ndr.format.vld.readvhlvdatafile to read the data.
%
%   Example:
%     headerstruct = ndr.format.vld.readvhlvheaderfile('vhlvanaloginput.vlh')
%
%     headerstruct =
%         ChannelString: [1x26 char]
%              NumChans: 17
%          SamplingRate: 25000
%       SamplesPerChunk: 25000
%           Multiplexed: 0
%
%
%  See also: STRUCT, ndr.format.vld.readvhlvdatafile
%

 % step 1) create an empty field
mystruct.emptyfield = 0; % make a new struct
mystruct = rmfield(mystruct,'emptyfield'); % make it have no fields

 % step 2) read in the text from the header file
 %         we have no expectation that this will be large, so
 %         let's read the whole business at once

[~,~,myext] = fileparts(myfilename);
if strcmpi(myext,'.vld'),
	error(['It appears you are trying to open a data file ' myfilename ' with the code that reads the header.']);
end;

fid = fopen(myfilename,'rt');

if fid<0, error(['Could not open file ' myfilename '.']); end; % handle any errors nicely

textfromfile = fread(fid,Inf,'char');
fclose(fid);  % close the file

 % step 3) parse the text;

text = [sprintf('\n') ; textfromfile(:) ]'; % add line feeds to beginning of the file

if text(end)~=sprintf('\n'),  % make sure the last line ends in a line feed
	text(end+1) = sprintf('\n');
end;

  % remove any carriage returns, which are redundent with line feeds
inds = find(text~=sprintf('\r'));
text = text(inds);

  % now loop through, looking for the existence of a colon followed by a tab
  % the presence of a colon/tab indicates that everything to the left of the colon/tab on that
  % line is the header.  The contents will be everything to the right of the tab
  % until the next line that has a tab.

separators = strfind(text,sprintf(':\t'));
linefeeds = find(text==sprintf('\n'));

for i=2:length(linefeeds),  % parse each line, starting from 2nd
	z = find(separators>linefeeds(i-1) & separators<linefeeds(i)); % does this line have a colon plus tab in it?
	if ~isempty(z),
		% the field name is the text between the beginning of the line and the colon
		field_name = text(linefeeds(i-1)+1:separators(z)-1);
		field_value_start = separators(z)+2; % there are 2 characters in the separator

		% now we have to find where the end is
		% let's find the next colon plus tab, if it exists
		z2 = find(separators>separators(z),1); % find at most 1 of these
		if ~isempty(z2),
			next_linefeed = find(linefeeds<separators(z2),1,'last'); % find the last linefeed before the colon tab
			field_value_end = linefeeds(next_linefeed)-1;
		else, % read from here until the end of the document
			field_value_end = linefeeds(end)-1;
		end;
		field_value_string = text(field_value_start:field_value_end);

		% Validate the field name before using it as a dynamic struct field.
		% This, together with the eval-free value parsing below, prevents a
		% malicious .vlh file from executing arbitrary code (previously the
		% value text was interpolated straight into eval()).
		if ~isvarname(field_name),
			error('ndr:format:vld:invalidFieldName', ...
				['Invalid header field name ''' field_name ''' in file ' myfilename '.']);
		end;

		% Add the field.  First try to interpret the value as a number with
		% str2double (which does NOT evaluate expressions); if that yields NaN
		% (i.e. the text is not a plain number) store the raw string instead.
		% This mirrors the eval-free NDR-python implementation
		% (readvhlvheaderfile.py:_coerce) and reproduces the same values for
		% all legitimate (literal) header entries.
		field_value_numeric = str2double(field_value_string);
		if ~isnan(field_value_numeric),
			mystruct = setfield(mystruct,field_name,field_value_numeric);
		else,
			mystruct = setfield(mystruct,field_name,field_value_string);
		end;
	end;
end;
