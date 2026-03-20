function [data, t, t0_t1] = read(binfilename, t0, t1, options)
%READ Read data from a SpikeGLX Neuropixels binary (.bin) file.
%
%   [DATA, T, T0_T1] = ndr.format.neuropixelsGLX.read(BINFILENAME, T0, T1, OPTIONS)
%
%   Reads neural data from a SpikeGLX binary file. The binary file contains
%   interleaved int16 samples with no header. Channel count and sample rate
%   are provided via options or read from the companion .meta file.
%
%   This function uses ndr.format.binarymatrix.read for efficient binary
%   data access, supporting both full and partial channel reads.
%
%   Inputs:
%       BINFILENAME - Full path to the .bin file (char row vector).
%       T0          - Start time for reading in seconds (double scalar).
%                     Use -Inf to start from the beginning.
%       T1          - End time for reading in seconds (double scalar).
%                     Use Inf to read to the end.
%
%   Options:
%       numChans    - Total number of channels in the file, including the
%                     sync channel (positive integer, default: from .meta).
%       SR          - Sampling rate in Hz (positive double, default: from .meta).
%       channels    - 1-based vector of channel indices to read (default: []
%                     meaning all channels). Must be within [1, numChans].
%
%   Outputs:
%       DATA   - N x C int16 matrix, where N is the number of time samples
%                and C is the number of channels read.
%       T      - N x 1 double vector of time points in seconds.
%       T0_T1  - 1x2 double vector [startTime endTime] for the full file.
%
%   Example:
%       % Read all channels from 10s to 20s
%       [D, t, range] = ndr.format.neuropixelsGLX.read('run_g0_t0.imec0.ap.bin', 10, 20);
%
%       % Read only channels 1-10 (first 10 neural channels)
%       [D, t, range] = ndr.format.neuropixelsGLX.read('run_g0_t0.imec0.ap.bin', 0, 5, ...
%           'channels', 1:10);
%
%   See also: ndr.format.neuropixelsGLX.header, ndr.format.binarymatrix.read

    arguments
        binfilename (1,:) char {mustBeFile}
        t0 (1,1) double
        t1 (1,1) double
        options.numChans (1,1) {mustBeInteger, mustBePositive} = 0
        options.SR (1,1) {mustBeNumeric, mustBePositive} = 0
        options.channels (1,:) {mustBeNumeric, mustBeInteger, mustBePositive} = []
    end

    % If numChans or SR not provided, read from companion .meta file
    if options.numChans == 0 || options.SR == 0
        metafilename = [binfilename(1:end-3) 'meta'];
        if ~isfile(metafilename)
            error('ndr:format:neuropixelsGLX:read:NoMetaFile', ...
                'No .meta file found at %s and numChans/SR not specified.', metafilename);
        end
        info = ndr.format.neuropixelsGLX.header(metafilename);
        if options.numChans == 0
            options.numChans = info.n_saved_chans;
        end
        if options.SR == 0
            options.SR = info.sample_rate;
        end
    end

    SR = options.SR;
    numChans = options.numChans;
    dataType = 'int16';
    bytesPerSample = 2;
    bytesPerFullSample = bytesPerSample * numChans;

    % Validate channels
    if ~isempty(options.channels)
        if any(options.channels > numChans) || any(options.channels < 1)
            error('ndr:format:neuropixelsGLX:read:BadChannels', ...
                'Channel indices must be between 1 and %d.', numChans);
        end
        channelsToRead = uint32(options.channels);
    else
        channelsToRead = uint32(1:numChans);
    end

    % Calculate total time range (no header in SpikeGLX .bin files)
    fileinfo = dir(binfilename);
    totalDataBytes = fileinfo.bytes;
    totalSamplesInFile = floor(totalDataBytes / bytesPerFullSample);

    file_t_start = 0;
    file_t_end = ndr.time.fun.samples2times(totalSamplesInFile, [0 0], SR);
    t0_t1 = [file_t_start file_t_end];

    % Clamp requested times
    t0_req = max(t0, t0_t1(1));
    t1_req = min(t1, t0_t1(2));

    if t1_req < t0_req
        data = int16([]);
        t = [];
        return;
    end

    % Convert times to samples
    s0_req = ndr.time.fun.times2samples(t0_req, t0_t1, SR);
    s1_req = ndr.time.fun.times2samples(t1_req, t0_t1, SR);
    s0_req = max(1, s0_req);
    s1_req = min(totalSamplesInFile, s1_req);

    if s1_req < s0_req
        data = int16([]);
        t = [];
        return;
    end

    % Read using binarymatrix
    [data, ~, s0_actual, s1_actual] = ndr.format.binarymatrix.read(...
        binfilename, ...
        uint32(numChans), ...
        channelsToRead, ...
        double(s0_req), ...
        double(s1_req), ...
        'dataType', dataType, ...
        'byteOrder', 'ieee-le', ...
        'headerSkip', uint64(0));

    % Generate time vector
    if ~isempty(data)
        t = ndr.time.fun.samples2times((s0_actual:s1_actual)', t0_t1, SR);
    else
        t = [];
        data = int16([]);
    end

end
