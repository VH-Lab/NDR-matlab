function sample_info = read_SEV_logs(dirname, varargin)
% READ_SEV_LOGS - read the logs for a TDT SEV directory
%
% SAMPLE_INFO = READ_SEV_LOGS(DIRNAME)
%
% Reads the *_log.txt files in the directory DIRNAME that contains
% a TDT SEV recording.
%
%

VERBOSE = 0;

ndr.data.assign(varargin{:});

sample_info = [];

txt_file_list = dir([dirname filesep '*_log.txt']);

n_txtfiles = length(txt_file_list);
if n_txtfiles < 1 && VERBOSE
	fprintf('info: no log files in %s\n', dirname);
else
	for ii = 1:n_txtfiles
		if VERBOSE
			fprintf('info: log file %s\n', txt_file_list(ii).name);
		end

		% get store name
		matches = regexp(txt_file_list(ii).name, '^[^_|-]+(?=_|-)', 'match');
		temp_sample_info = [];
		if ~isempty(matches)
			temp_sample_info.name = matches{1};
			txt_path = [dirname filesep txt_file_list(ii).name];
			fid = fopen(txt_path);
			log_text = fscanf(fid, '%c');
			if VERBOSE, fprintf(log_text); end
			fclose(fid);

			t = regexp(log_text, 'recording started at sample: (\d*)', 'tokens');
			temp_sample_info.start_sample = str2double(t{1}{1});
			t = regexp(txt_file_list(ii).name, '-(\d)h', 'tokens');
			if isempty(t)
				temp_sample_info.hour = 0;
			else
				temp_sample_info.hour = str2double(t{1}{1});
			end

			if temp_sample_info.start_sample > 2 && temp_sample_info.hour == 0
				error('%s store starts on sample %d', temp_sample_info.name, temp_sample_info.start_sample);
			end

			% look for gap info
			temp_sample_info.gaps = [];
			temp_sample_info.gap_text = '';
			gap_text = regexp(log_text, 'gap detected. last saved sample: (\d*), new saved sample: (\d*)', 'match');
			t = regexp(log_text, 'gap detected. last saved sample: (\d*), new saved sample: (\d*)', 'tokens');
			if ~isempty(t)
				temp_sample_info.gaps = reshape(cell2mat(cellfun(@str2double,t,'uniform',0)), 2, []);
				temp_sample_info.gap_text = strjoin(gap_text', '\n   ');
				if temp_sample_info.hour > 0
					error('gaps detected in data set for %s-%dh!\n   %s\nContact TDT for assistance.\n', temp_sample_info.name, temp_sample_info.hour, temp_sample_info.gap_text);
				else
					error('gaps detected in data set for %s!\n   %s\nContact TDT for assistance.\n', temp_sample_info.name, temp_sample_info.gap_text);
				end
			end
			sample_info = [sample_info temp_sample_info];
		end
	end
end



