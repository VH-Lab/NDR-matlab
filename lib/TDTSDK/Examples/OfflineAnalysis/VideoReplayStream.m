%% Video Replay with Streaming Data
%
%  Import video and stream data into Matlab
%  Plot the video and stream
%  Good for replay analysis

%% Housekeeping
% Clear workspace and close existing figures. Add SDK directories to Matlab
% path.
close all; clear all; clc;
[MAINEXAMPLEPATH,name,ext] = fileparts(cd); % \TDTMatlabSDK\Examples
DATAPATH = fullfile(MAINEXAMPLEPATH, 'ExampleData'); % \TDTMatlabSDK\Examples\ExampleData
[SDKPATH,name,ext] = fileparts(MAINEXAMPLEPATH); % \TDTMatlabSDK
addpath(genpath(SDKPATH));

%% Importing the Data
% This example assumes you downloaded our
% <https://www.tdt.com/files/examples/TDTExampleData.zip example data sets>
% and extracted it into the \TDTMatlabSDK\Examples\ directory. To import your own data, replace
% 'BLOCKPATH' with the path to your own data block.
%
% In Synapse, you can find the block path in the database. Go to Menu --> History. 
% Find your block, then Right-Click --> Copy path to clipboard.
BLOCKPATH           = fullfile(DATAPATH,'Subject1-211115-094936');

% Settings
STREAM_STORE        = 'x465A';   % single channel stream store name
VID_STORE           = 'Cam1';    % video store name
START_FRAME         = 1;         % first frame index (use 1 for beginning of video)
END_FRAME           = -1;        % last frame index (use -1 for end of video)
ROLLING             = -1;        % rolling window, in seconds (use -1 for none)
CREATE_OUTPUT_VIDEO = 1;         % set to 0 to skip writing the output video
VIDEO_OUTPUT_PATH   = BLOCKPATH; % where the output video should go

% Read data
data = TDTbin2mat(BLOCKPATH);

%%
% Read video file.
vvv = dir([BLOCKPATH filesep '*' VID_STORE '.avi']);
vid_filename = [vvv.folder filesep vvv.name];
fprintf('reading file %s\n', vid_filename);
myvideo = VideoReader(vid_filename);

%%
% Get data specs.
max_frames = length(data.epocs.(VID_STORE).onset);
if END_FRAME < 1
    END_FRAME = max_frames;
end
max_ts = data.epocs.(VID_STORE).onset(end);
expected_fps = max_frames / max_ts;
max_x = max(size(data.streams.(STREAM_STORE).data));

%%
% Make array of images if we're outputting a video.
if CREATE_OUTPUT_VIDEO
     M(END_FRAME-START_FRAME+1) = struct('cdata',[],'colormap',[]);
end

%%
% Create figure.
h = figure;
h.Position = [500 500 560 560];

%%
% The main loop.

tic
ct = 1;
for k = START_FRAME:END_FRAME
    % grab one image
    im = read(myvideo, k);
    
    subplot(3,1,[1 2])

    % plot it
    image(im)
    if ct == 1
        % hide x and y pixel axes
        set(gca,'xtick',[])
        set(gca,'ytick',[])
        set(gca,'nextplot','replacechildren')
    end
    recording_ts = data.epocs.(VID_STORE).onset(k);

    % set title
    title_text = sprintf('%s frame %d of %d, t = %.2fs', VID_STORE, k, END_FRAME, recording_ts);
    title(title_text);
    
    % plot stream in another subplot
    subplot(3,1,3)

    stream_ind = round(recording_ts * data.streams.(STREAM_STORE).fs);
    if ct == 1
        start_ind = stream_ind;
        end_ind = round(data.epocs.(VID_STORE).onset(END_FRAME) * data.streams.(STREAM_STORE).fs);
    end
    
    if ROLLING > 0
        stream_ind = round(recording_ts * data.streams.(STREAM_STORE).fs);
        max_ts = data.epocs.(VID_STORE).onset(k);
        start_ind = max(round(max(recording_ts - ROLLING, 0) * data.streams.(STREAM_STORE).fs), 1);
        t = max_ts .* (start_ind:stream_ind) / stream_ind;
    else
        t = max_ts .* (start_ind:stream_ind) ./ max_x;
    end
    
    plot(t, data.streams.(STREAM_STORE).data(start_ind:stream_ind), 'b', 'LineWidth', 2)
    if ct == 1
        t1 = max_ts .* start_ind / max_x;
        t2 = max_ts .* end_ind / max_x;
        y1 = 0;
        y2 = max(data.streams.(STREAM_STORE).data(start_ind:end_ind));
        axis([t1, t2, y1, y2])
        grid on;
        title(STREAM_STORE)
        xlabel('time, s')
        ylabel('mV')
        set(gca,'nextplot','replacechildren') % maintains the axis properties next time, improves speed
    end
    if ROLLING > 0
        t1 = t(1);
        t2 = max(t(end), ROLLING);
        axis([t1, t2, y1, y2]);
    end

    % force the plot to update
    drawnow;
    
    if CREATE_OUTPUT_VIDEO
        M(ct) = getframe(gcf); % get the whole figure
    end

    % slow down to match video fps
    expected_el = ct / expected_fps;
    ddd = expected_el - toc;
    if ddd > 0, pause(ddd); end
    ct = ct + 1;
end

disp('done playing')

%%
% Create the output video file of figure with same FPS as original.
if CREATE_OUTPUT_VIDEO
    out_file = [VIDEO_OUTPUT_PATH filesep strrep(vvv.name, '.avi', '_output.avi')];
    fprintf('writing video file %s\n', out_file);
    out_video = VideoWriter(out_file);
    out_video.FrameRate = expected_fps;
    open(out_video);
    for k = 1:length(M)
        writeVideo(out_video, M(k));
    end
    close(out_video)
end
