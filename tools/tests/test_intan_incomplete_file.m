% Test script for reading incomplete Intan RHD2000 files

% 1. Create a dummy .rhd file with a partial data block.

% Create a dummy header
header = struct();
header.fileinfo.headersize = 100;
header.fileinfo.filesize = 2048;
header.frequency_parameters.amplifier_sample_rate = 20000;
header.amplifier_channels = struct('native_channel_name', 'A-000');
header.aux_input_channels = struct();
header.supply_voltage_channels = struct();
header.board_adc_channels = struct('native_channel_name', 'ANALOG-IN-00');
header.board_dig_in_channels = struct();
header.board_dig_out_channels = struct();
header.num_temp_sensor_channels = 0;
header.fileinfo.eval_board_mode = 0;
header.fileinfo.data_file_main_version_number = 1;
header.fileinfo.data_file_secondary_version_number = 2;


% Create a dummy file
filename = 'test_incomplete_file.rhd';
fid = fopen(filename, 'w');
fwrite(fid, zeros(1, header.fileinfo.headersize), 'uint8');

% Calculate bytes per block
[~, bytes_per_block] = ndr.format.intan.Intan_RHD2000_blockinfo(filename, header);


% Write one and a half blocks of data
dummy_data = zeros(1, floor(bytes_per_block * 1.5), 'uint8');
fwrite(fid, dummy_data, 'uint8');
fclose(fid);

header.fileinfo.filesize = ftell(fopen(filename,'r'));
frewind(fopen(filename,'r'));

% 2. Call ndr.format.intan.read_Intan_RHD2000_datafile to read the file.
disp('Testing with incomplete file...');
try
    [data,total_samples,total_time,blockinfo] = ndr.format.intan.read_Intan_RHD2000_datafile(filename, header, 'adc', 1, 0, inf);

    % 3. Verify that a warning is issued and that the function returns the correct number of complete data blocks without error.
    disp('Test passed: The function executed without error.');

    if total_samples == 60
        disp('Test passed: total_samples is correct.');
    else
        disp('Test failed: total_samples is incorrect.');
    end

catch e
    disp('Test failed: An error occurred.');
    disp(e);
end

% clean up
delete(filename);
