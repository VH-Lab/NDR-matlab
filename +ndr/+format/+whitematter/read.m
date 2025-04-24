function [D, t, t0_t1] = read(fname, t0, t1, options)
%READ Reads data from a WhiteMatter LLC (WM) binary data file.
%
%   [D, t, t0_t1] = whitematter.read(FNAME, T0, T1, OPTIONS) reads data from the
%   binary file specified by FNAME. It returns the data in the matrix D,
%   where each row represents a sample and each column represents a channel.
%   By default, all channels are read. Use the 'channels' option to specify
%   a subset of channels.
%   The data is read from time T0 to T1 (inclusive, in seconds).
%   The time vector corresponding to the samples in D is returned in t.
%   The entire recording time window available in the file is returned
%   in t0_t1 as a 1x2 vector [startTime endTime].
%
%   This function utilizes ndr.format.binarymatrix.read for efficient data reading.
%
%   Inputs:
%       FNAME     - Path to the WM data file (char row vector).
%                   The file must exist. It is assumed to contain an
%                   8-byte header followed by interleaved int16 data.
%       T0        - Start time for data reading (in seconds, double scalar).
%                   Use -Inf to start from the beginning of the file.
%       T1        - End time for data reading (in seconds, double scalar).
%                   Use Inf to read until the end of the file.
%
%   OPTIONS:
%       numChans  - Total number of channels interleaved in the data file
%                   (positive integer scalar, default: 64). This must be the
%                   *total* number, even if reading a subset.
%       SR        - Sampling rate of the data in Hz
%                   (positive double scalar, default: 20000).
%       byteOrder - Byte order of the binary data file
%                   ('ieee-le' or 'ieee-be', char row vector, default: 'ieee-le').
%       channels  - Vector of channel indices (1-based) to read. Channels
%                   must be within the range [1, numChans].
%                   (numeric vector, default: [] which means read all channels).
%
%   Outputs:
%       D         - N x C matrix containing the read data, where N is the
%                   number of samples read and C is the number of channels
%                   specified in the 'channels' option (or numChans if 'channels'
%                   is empty). Data is returned as int16.
%       t         - N x 1 vector of time points (in seconds) corresponding
%                   to the samples in D. Returned as double.
%       t0_t1     - 1x2 vector [startTime endTime] indicating the total
%                   time window available for reading in the file (seconds).
%                   Returned as double.
%
%   Examples:
%       % Read all 64 channels from 'mydata_wm.dat' from 10s to 20s
%       [D_all, t_all, time_range_all] = whitematter.read('mydata_wm.dat', 10, 20);
%       disp(['Total time available: ' num2str(time_range_all(2)) ' seconds']);
%       disp(['Data size: ' mat2str(size(D_all))]); % Should be samples x 64
%
%       % Read only channels 1, 5, and 10 from 'mydata_wm.dat' from 10s to 20s
%       [D_sub, t_sub, time_range_sub] = whitematter.read('mydata_wm.dat', 10, 20, 'channels', [1, 5, 10]);
%       disp(['Data size: ' mat2str(size(D_sub))]); % Should be samples x 3
%       figure;
%       plot(t_sub, double(D_sub(:,2))); % Plot channel 5 (second column requested)
%       xlabel('Time (s)'); ylabel('Raw Value (int16)');
%       title('Data Channel 5');
%
%   See also: ndr.format.binarymatrix.read, ndr.time.fun.times2samples, ndr.time.fun.samples2times

% --- Input Argument Validation ---
arguments
    fname (1,:) char {mustBeFile}
    t0 (1,1) double
    t1 (1,1) double
    options.numChans (1,1) {mustBeInteger, mustBePositive} = 64
    options.SR (1,1) {mustBeNumeric, mustBePositive} = 20000
    options.byteOrder (1,:) char {mustBeMember(options.byteOrder,{'ieee-le','ieee-be'})} = 'ieee-le'
    options.channels (1,:) {mustBeNumeric, mustBeInteger, mustBePositive} = [] % Default to empty, meaning all channels
end

% --- Constants and Parameters ---
SR = options.SR;
numChans = options.numChans;
dataType = 'int16'; % Data type of the samples in the file
bytesPerSampleValue = 2; % Bytes per int16 sample value
headerSkipBytes = 8; % Number of header bytes to skip
bytesPerFullSample = bytesPerSampleValue * numChans; % Bytes for one sample across ALL channels

% --- Validate channels option ---
if ~isempty(options.channels)
    if any(options.channels > numChans) || any(options.channels < 1)
         error('Requested channel indices in ''channels'' option must be between 1 and numChans (%d).', numChans);
    end
    channelsToRead = uint32(options.channels);
else
    % Default: read all channels
    channelsToRead = uint32(1:numChans);
end

% --- Calculate Total Time Range ---
fileinfo = dir(fname);
totalDataBytes = fileinfo.bytes - headerSkipBytes;
if totalDataBytes < 0
    error('File size is smaller than the specified header size.');
end
% Calculate based on FULL samples across ALL channels
totalSamplesInFile = totalDataBytes / bytesPerFullSample;
if totalSamplesInFile ~= floor(totalSamplesInFile)
    warning('File size does not correspond to an integer number of full samples across all channels. File might be corrupted.');
    totalSamplesInFile = floor(totalSamplesInFile);
end

% Assume file starts at time 0
file_t_start = 0;
% Use [0 0] as dummy t0_t1 for duration calc, independent of actual start time
file_t_end = ndr.time.fun.samples2times(totalSamplesInFile, [0 0], SR); 
t0_t1 = [file_t_start file_t_end];

% --- Determine Samples to Read ---
% Clamp requested t0/t1 to the available range
t0_req = max(t0, t0_t1(1));
t1_req = min(t1, t0_t1(2));

if t1_req < t0_req
    warning('Requested end time t1=%.4f is before start time t0=%.4f. Returning empty data.', t1, t0);
    D = int16([]); % Return empty int16
    t = [];
    return;
end

% Convert requested times to sample numbers (1-based)
s0_req = ndr.time.fun.times2samples(t0_req, t0_t1, SR);
s1_req = ndr.time.fun.times2samples(t1_req, t0_t1, SR);

% Ensure sample numbers are within the valid range [1, totalSamplesInFile]
s0_req = max(1, s0_req);
s1_req = min(totalSamplesInFile, s1_req);

if s1_req < s0_req
     warning('Calculated end sample %d is before start sample %d. Returning empty data.', s1_req, s0_req);
    D = int16([]); % Return empty int16
    t = [];
    return;
end

% --- Read Data using ndr.format.binarymatrix.read ---
[D, ~, s0_actual, s1_actual] = ndr.format.binarymatrix.read(...
    fname, ...
    uint32(numChans), ...       % Pass the TOTAL number of channels in the file
    channelsToRead, ...         % Pass the specific channels to read
    double(s0_req), ...         % Pass requested start sample
    double(s1_req), ...         % Pass requested end sample
    'dataType', dataType, ...
    'byteOrder', options.byteOrder, ...
    'headerSkip', uint64(headerSkipBytes) ...
    );

% --- Generate Time Vector ---
% Use the actual samples read (s0_actual, s1_actual) to generate the time vector
if ~isempty(D)
    % Time vector corresponds to the samples read, independent of which channels
    t = ndr.time.fun.samples2times( (s0_actual:s1_actual)', t0_t1, SR);
else
    t = []; % No data read
    D = int16([]); % Ensure D is empty int16 if no data was read
end

% Data D is already int16 as returned by ndr.format.binarymatrix.read

end

