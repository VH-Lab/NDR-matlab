function h=jvAddFFT(h)
% jvAddFFT addpanel function
% 
% Example:
% h=jvAddFFT(h)
%
% -------------------------------------------------------------------------
% Author: Malcolm Lidierth 11/07
% Copyright � The Author & King's College London 2007-
% -------------------------------------------------------------------------


Height=0.09;
Top=0.75;

h=jvAddPanel(h, 'Title', 'FFT Options',...
    'dimension', 0.75);

try
    [winhandles winlist]=findallwinclasses('nonuserdefined');
    winhandles=cellfun(@str2func, winhandles, 'UniformOutput', false);
catch
    winhandles=@wvHamming;
    winlist={'Hamming'};
end

h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.1 Top 0.8 Height],...
    'DisplayList', {'1' '2' '5' '10' '20'},...
    'ReturnValues',{1, 2 , 5, 10, 20},...
    'Label', 'Window Length (s)',...
    'ToolTipText', 'Data sections length (s)');

h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.1 Top-(2*Height) 0.8 Height],...
    'DisplayList', winlist,...
    'ReturnValues', winhandles,...
    'Label', 'Window',...
    'ToolTipText', 'Available windows');
h{end}.Window.setSelectedIndex(find(strcmp(winlist,'Hamming'))-1);

h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.1 Top-(4*Height) 0.35 Height],...
    'DisplayList', {'0' '25' '50' '75'},...
    'ReturnValues', {0 25 50 75 100},...
    'Label', 'Overlap (%)',...
    'ToolTipText', 'Overlap of successive data sections');
h{end}.Overlap.setSelectedIndex(2);

str=['<HTML>Auto: Continuous channels only<P>',...
    'On: All channels<P>',...
    'Off: None</HTML>'];
h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.55 Top-(4*Height) 0.35 Height],...
    'DisplayList', {'Auto' 'Off' 'On'},...
    'ReturnValues', {'Auto' 'Off' 'On'},...
    'Label', 'Overlap Mode',...
    'ToolTipText', str);

h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.1 Top-(6*Height) 0.8 Height],...
    'DisplayList',  {'Power Spectral Density',...
                    'Linear Power Spectral Density',...
                    'PSD x Hz',...
                    'Power Spectrum',...
                    'Linear Power Spectrum'},...
    'Label', 'Spectrum Mode',...
    'ToolTipText','Result scaling');
%     'ReturnValues', {'Normalized Power Spectral Density',...
%                      'Power Spectrum',...
%                     'Linear Power Spectrum',...
%                     'Power Spectral Density',...
%                     'Linear Power Spectral Density'},...
h=jvElement(h{end},'Component', 'javax.swing.JCheckBox',...
    'Position',[0.1 Top-(8*Height) 0.325 Height],...
    'Label', 'Detrend',...
    'ToolTipText', 'Pre-process: Remove DC & linear trend');

str=['<HTML><CENTER>Pre-process: Apply anti-aliasing filter and downsample by the selected factor<P>',...
    'This may take some time. It will often be better to decimate data to a new<P>',...
    'channel from the main menu and analyses that</CENTER></HTML>'];
h=jvElement(h{end},'Component', 'javax.swing.JComboBox',...
    'Position',[0.55 Top-(8*Height) 0.325 Height],...
    'DisplayList', {'0' '10' '20' '50' '100' '200'},...
    'Label', 'Decimation',...
    'ToolTipText',str );

return
end