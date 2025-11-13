classdef intanTest < matlab.unittest.TestCase
    methods (Test)
        function test_intan_readers(testCase)
            % Get the path to the example data
            example_data_path = [ndr.fun.ndrpath() filesep 'example_data' ];

            % Get a list of all .rhd files in the directory
            rhd_files = dir(fullfile(example_data_path, 'intan_test_data.rhd'));

            % Create a temporary directory for the output
            temp_dir = tempname;
            mkdir(temp_dir);

            % Loop over each file
            for i = 1:length(rhd_files)
                filename = fullfile(example_data_path, rhd_files(i).name);

                % Run the manufacturer's code
                cd(temp_dir);
                manufacturer_output = ndr.format.intan.manufacturer.read_Intan_RHD2000_file_var(filename);
                cd ..

                % Run our lab's code
                our_output = ndr.format.intan.read_Intan_RHD2000_datafile(filename);

                % Compare the outputs
                testCase.verifyEqual(our_output.amplifier_data, manufacturer_output.amplifier_data, 'Amplifier data does not match');
                testCase.verifyEqual(our_output.t_amplifier, manufacturer_output.t_amplifier, 'Amplifier time does not match');
            end

            % Clean up the temporary directory
            rmdir(temp_dir, 's');
        end
    end
end
