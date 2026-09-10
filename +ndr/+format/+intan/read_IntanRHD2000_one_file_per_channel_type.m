function data = read_IntanRHD2000_one_file_per_channel_type(directory_name, channel_type, channel_index, num_channels, s0, s1)
    % READ_INTANRHD2000_ONE_FILE_PER_CHANNEL_TYPE - Read Intan "one file per signal type" data
    %
    %   DATA = READ_INTANRHD2000_ONE_FILE_PER_CHANNEL_TYPE(DIRECTORY_NAME, CHANNEL_TYPE, CHANNEL_INDEX, NUM_CHANNELS, S0, S1)
    %
    %   Reads data from an Intan RHD2000 recording saved in the
    %   "One File Per Signal Type" format, where all channels of a given
    %   signal type share a single .dat file (interleaved sample-by-sample).
    %
    %   DIRECTORY_NAME is the directory containing the data files. Files may
    %   have an optional prefix (Intan's date/time stamp or a lab-specific
    %   prefix such as "febc0_u000_000_"); the reader resolves the prefix
    %   automatically.
    %
    %   CHANNEL_TYPE is an integer specifying the type of data to read:
    %       1: time.dat        (int32 timestamps)
    %       2: amplifier.dat   (int16 amplifier samples)
    %       3: auxiliary.dat   (uint16 auxiliary input samples)
    %       4: supply.dat      (uint16 supply-voltage samples)
    %       5: (temperature is interleaved with supply in this format;
    %           Intan does not write a standalone temperature file here)
    %       6: analogin.dat    (uint16 board ADC samples)
    %       7: digitalin.dat   (uint16 packed digital-input word)
    %       8: digitalout.dat  (uint16 packed digital-output word)
    %
    %   CHANNEL_INDEX is the 1-based position of the channel within the
    %   enabled channels of this type (ignored for digital channels; the
    %   caller extracts the bit from the packed word).
    %   NUM_CHANNELS is the total number of enabled channels of this type.
    %   S0 / S1 are the 1-based inclusive sample range.
    %
    %   For digital channels, DATA is the full 16-bit packed word for each
    %   requested sample; the caller extracts the bit for a specific
    %   channel using that channel's native_order.
    %
    %   Filenames match the Intan-RHX / IntanToNWB / python-neo spec.
    %
    %   See also: NDR.FORMAT.INTAN.READ_INTAN_RHD2000_DIRECTORY

    arguments
        directory_name (1, :) char {mustBeFolder(directory_name)}
        channel_type (1, 1) double {mustBeMember(channel_type, [1 2 3 4 6 7 8])}
        channel_index (1, 1) double {mustBeInteger, mustBePositive}
        num_channels (1, 1) double {mustBeInteger, mustBePositive}
        s0 (1, 1) double {mustBeInteger, mustBePositive}
        s1 (1, 1) double {mustBeInteger, mustBePositive, mustBeGreaterThanOrEqual(s1, s0)}
    end

    sample_size_bytes = [ 4 2 2 2 2 2 2 2];
    sample_precision = { 'int32', 'int16', 'uint16', 'uint16', 'uint16', 'uint16', 'uint16', 'uint16' };

    switch(channel_type)
        case 1
            filename_post = 'time.dat';
        case 2
            filename_post = 'amplifier.dat';
        case 3
            filename_post = 'auxiliary.dat';
        case 4
            filename_post = 'supply.dat';
        case 6
            filename_post = 'analogin.dat';
        case 7
            filename_post = 'digitalin.dat';
        case 8
            filename_post = 'digitalout.dat';
        otherwise
            error(['Unknown channel_type ' int2str(channel_type)]);
    end

    fn = fixdatfilename([directory_name filesep filename_post]);
    if isempty(fn)
        error(['Could not find data file matching *' filename_post ' in ' directory_name '.']);
    end

    fid = fopen(fn,'rb','ieee-le');
    if fid<0
        error(['Could not open ' fn ' for reading.']);
    end

    if channel_type<7
        % interleaved: seek past (s0-1) full sample groups, then past
        % (channel_index-1) samples within the current group, and stride
        % over the other channels on each subsequent read.
        fseek(fid,sample_size_bytes(channel_type)*(num_channels*(s0-1) + channel_index-1),'bof');
        data = fread(fid,s1-s0+1,sample_precision{channel_type},sample_size_bytes(channel_type)*(num_channels-1));
    else
        % digital: one packed 16-bit word per sample; caller extracts bit.
        fseek(fid,sample_size_bytes(channel_type)*(s0-1),'bof');
        data = fread(fid,s1-s0+1,sample_precision{channel_type});
    end

    fclose(fid);

end

function fn = fixdatfilename(filename)
% FIXDATFILENAME - Resolve a signal-type filename that may carry an Intan
% timestamp or lab-specific prefix (e.g., "febc0_u000_000_amplifier.dat").
if isfile(filename)
    fn = filename;
    return;
end
[parentdir,fname,ext] = fileparts(filename);
d = dir([parentdir filesep '*' fname ext]);
if ~isempty(d)
    fn = [parentdir filesep d(1).name];
    return;
end
fn = '';
end
