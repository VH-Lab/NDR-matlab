function [recData, timestamps] = read_SpikeGadgets_analogChannels(filename,NumChannels, channels, samplingRate,headerSize,s0,s1, configExists)

% [recData, timestamps] = read_SpikeGadgets_analogChannels(filename,NumChannels, channels, samplingRate,headerSize, configExists) )
% Imports digital channel data in matlab from the raw data file
%
% INPUTS
% filename-- a string containing the name of the .dat file (raw file from SD card)
% NumChannels-- the number of channels in the recording (i.e., 32,64,96...)
% channels-- the analog channels you want to extract, designated by the byte location (1-based), i.e., [3 5 7]
% samplingRate-- the sampling rate of the recording, i.e 30000
% headerSize--the size, in int16's, of the header block of the data
% (contains DIO channels and aux analog channels).
%
% OUTPUTS
% timestamps--the system clock when each sample was taken
% recData-- an N by M matrix with N data points and M channels (M is equal to the number of channels in the input)

configsize = 0;
if (nargin < 8)
    configExists = 1;
end

fid = fopen(filename,'r');

%Store config text
if (configExists)
    junk = fread(fid,30000,'char');
    configsize = strfind(junk','</Configuration>')+16;
end

%Number of bytes we will read
headerSizeBytes = str2num(headerSize) * 2; %int16 = 2 bytes
channelSizeBytes = str2num(NumChannels) * 2; %int16 = 2 bytes
blockSizeBytes = headerSizeBytes + 2 + channelSizeBytes;

%One sample occupies [header][4-byte uint32 timestamp][channel data], so the
%stride from one sample to the next is headerSizeBytes + 4 + channelSizeBytes.
%blockSizeBytes is deliberately 2 less than that: it is the skip argument to
%fread, which advances AFTER reading 2 bytes. Use it only there. Any explicit
%fseek to a sample boundary must use sampleStrideBytes instead -- using
%blockSizeBytes lands 2 bytes short per sample skipped, so the error grows
%with s0 and the read silently returns the wrong samples.
sampleStrideBytes = headerSizeBytes + 4 + channelSizeBytes;

%get the timestamps
%junk = fread(fid,configsize,'char');
%junk = fread(fid,headerSize,'int16');
fseek(fid,configsize,'bof'); %seek to configsize length from beginning of file
fseek(fid,headerSizeBytes,'cof'); %seek to headerSizeBytes length from current position in file
fseek(fid,(s0-1)*sampleStrideBytes,'cof'); %advance to sample s0
%Read only the requested span. This used to read [1,inf] -- every timestamp
%in the file, starting at sample 1 -- so the timestamps did not line up with
%the data returned alongside them whenever s0 > 1.
timestamps = fread(fid,s1-s0+1,'1*uint32=>uint32',(headerSizeBytes)+(channelSizeBytes))';
timestamps = double(timestamps)/samplingRate;


bytesToRead = channels; %find the list of unique bytes to read in
recData = [];
for i = 1:length(bytesToRead)
    %junk = fread(fid,configsize,'char'); %skip config
    %junk = fread(fid,bytesToRead(i)-1,'char'); %skip bytes in header block up to the correct byte
    fseek(fid,configsize,'bof'); %seek to configsize length from beginning of file
    fseek(fid,bytesToRead(i)-1,'cof'); %seek to the channel's byte within the block
    fseek(fid,(s0-1)*sampleStrideBytes,'cof'); %advance to sample s0
    %Read actual data for desired size from sample numbers inputed s1-s0+1, skipping block each time
    tmpData = fread(fid,s1-s0+1,'1*int16=>int16',blockSizeBytes)'; %transposed from vertical to horizontal

    recData = [recData; tmpData]; %append in a new row to recData

end

fclose(fid);

end
