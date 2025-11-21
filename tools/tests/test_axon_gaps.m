function test_axon_gaps(filename)
% TEST_AXON_GAPS - Test samples2times and times2samples with gaps
%
% TEST_AXON_GAPS(FILENAME)
%
% FILENAME should be an ABF file, preferably one with gaps (sweeps).
%

r = ndr.reader('abf');
epoch_select = 1;

% Read full time vector to establish ground truth
disp('Reading full time vector...');
t_all = r.readchannels_epochsamples('time', 1, {filename}, epoch_select, -inf, inf);
t_all = t_all(:); % Ensure column
s_all = (1:numel(t_all))';

disp(['Total samples: ' num2str(numel(t_all))]);
if ~isempty(t_all)
    disp(['Time range: ' num2str(t_all(1)) ' to ' num2str(t_all(end))]);
end

if isempty(t_all)
    error('No time data read!');
end

% Test samples2times with specific samples
s_test = [1, floor(numel(t_all)/2), numel(t_all)];
disp('Testing samples2times with integer samples...');
t_out = r.samples2times('ai', 1, {filename}, epoch_select, s_test);

for i=1:numel(s_test)
    err = abs(t_out(i) - t_all(s_test(i)));
    disp(['Sample ' num2str(s_test(i)) ': Time ' num2str(t_out(i)) ' (Error: ' num2str(err) ')']);
    if err > 1e-5
        warning('High error in samples2times!');
    end
end

% Test interpolation in samples2times
if numel(t_all) > 10
    s_interp = 10.5;
    t_interp = r.samples2times('ai', 1, {filename}, epoch_select, s_interp);
    t_expected = interp1(s_all, t_all, s_interp, 'linear');
    disp(['Interpolation test (s=' num2str(s_interp) '): ' num2str(t_interp) ' (Expected: ' num2str(t_expected) ')']);
end

% Test times2samples
disp('Testing times2samples...');
t_test = t_out; % Use times from previous test
s_out = r.times2samples('ai', 1, {filename}, epoch_select, t_test);

for i=1:numel(s_out)
    err = abs(s_out(i) - s_test(i));
    disp(['Time ' num2str(t_test(i)) ': Sample ' num2str(s_out(i)) ' (Error: ' num2str(err) ')']);
    if err > 0.1
        warning('High error in times2samples!');
    end
end

% Test rounding in times2samples
if numel(t_all) > 10
    t_mid = (t_all(10) + t_all(11)) / 2;
    s_mid = r.times2samples('ai', 1, {filename}, epoch_select, t_mid);
    disp(['Rounding test (t=' num2str(t_mid) '): Sample ' num2str(s_mid)]);
    % Should probably be 10 or 11
end

disp('Done.');
end
