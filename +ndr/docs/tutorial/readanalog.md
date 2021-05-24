# H1 NDR

Neuroscience Data Readers - A Matlab conglomerative package for reading neuroscience data files

## H2 Availability
A mature prototype of NDR is available in [Matlab](https://github.com/VH-Lab/NDR-matlab/tree/main) and a version for Python is well under construction.

## H2 Installation
Check out the [Installation Guide](https://vh-lab.github.io/NDI-matlab/installation/).

## H2 Help and Support
Use the [issue tracker](https://github.com/VH-Lab/NDR-matlab/issues) to submit questions, bugs, and issues.

## H2 Financial Support
Supported by the [NIH BRAIN Initiative informatics group](https://braininitiative.nih.gov/brain-programs/informatics), grant MH114678.


# H1  Tutorial 1: Introduction
[introductory tutorial of the NDR](https://github.com/VH-Lab/NDR-matlab/blob/main/README.md)


# H1  Tutorial 2: reading you neuroscience data files with NDR

## H2 2.1 Reading an example data file
We will start with learning to read an example dataset into NDR. We assume you have already installed [NDR](https://github.com/VH-Lab/NDR-matlab/tree/main) 
and taken the [introductory tutorial of the NDR](https://github.com/VH-Lab/NDR-matlab/blob/main/README.md). These package  is focused around a central object 
called [ndr.reader](https://github.com/VH-Lab/NDR-matlab/blob/main/%2Bndr/reader.m), You can put the package anywhere, but we will assume that you put them 
in your MATLAB/Documents/NDR folder, where MATLAB is your normal user path in Matlab (usually /Users/username/Documents/MATLAB on a Mac). Normally, we'd use 
some helper functions to open our data to make this process even easier, but this tutorial takes the user through the full manual process for training purposes.

### H3 2.1.1 Introduction to the experiment

### H3 2.1.2 Introduction to the supporting files 
There are three [example files](https://github.com/VH-Lab/NDR-matlab/tree/main/example_data), and we will need `ndr.reader('emample format')` to open the 
correspoding reader, and the [supporting formats](https://github.com/VH-Lab/NDR-matlab/blob/main/resource/ndr_reader_types.json) are listed below:

-ndr.reader.intan_rhd: "intan", "RHD", "intanRHD"
-ndr.reader.ced_smr: "ced-smr", "smr", "son"
-ndr.reader.spikegadgets_rec: "SpikeGadgets", "SpikeGadgetsREC","rec"

### H3 2.1.3 Introduction to the data

Taking SpikeGadgets format as an example.

First, setup path to your data and openning rec reader.  
## H2 Code block 2.1.3.1. Type this in to Matlab:
`assign(varargin{:});
ndr.globals
example_dir = [ndr_globals.path.path filesep 'example_data'];
filename = [example_dir filesep 'example.rec'];
r = ndr.reader('rec');`

We setup `getchannelsepoch`function to list the channels that are available on your device for a given epoch.

## H2 Code block 2.1.3.2. Type this in to Matlab:
`channels = r.getchannelsepoch({filename});`

If you need to view every channel number and type in your data,  
## H2 Code block 2.1.3.3. Type this in to Matlab:
`for i=1:numel(channels),
  
  disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);

end`

You need to choose which epoch in the file you wants to access, if the file(s) has more than one epoch contained. For most devices, EPOCH_SELECT is always 1.
## H2 Code block 2.1.3.4. Type this in to Matlab:
 `epoch_select = 1; `

If you want to view the beginning and end epoch times and clock type for an epoch: 
## H2 Code block 2.1.3.5. Type this in to Matlab:
 `ec = r.epochclock({filename}, epoch_select);
 t0t1 = r.t0_t1({filename}, epoch_select);

 disp(['These are the clocktypes we know and how long the recording lasted:'])
 	for i=1:numel(ec),
		disp(['On clock of type ' ec{i}.ndr_clocktype2char() ' the recording started at ' num2str(t0t1{i}(1)) ' and ended at ' num2str(t0t1{i}(2)) '.']);
	end;`
  
Then, using `readchannels_epochsamples` function to read events, markers, and digital events of specified channels for a specified epoch. 
Taking 'analog_in' as an example, if you want to reading from channel ai1 and read samples 1 through 10000
## H2 Code block 2.1.3.6. Type this in to Matlab:
`channel = 1;
t0=1;
t1=10000;
data = r.readchannels_epochsamples('analog_in',channel,{filename},epoch_select,t0,t1);
time = r.readchannels_epochsamples('time',channel,{filename},epoch_select,t0,t1);`

To read your channel prefixes and channel numbers in a stanard way, using `daqchannels2internalchannels` to convert a set of DAQ channel prefixes and channel 
numbers to an internal structure to pass to internal reading functions.
Taking 'analog_in' as an example,
## H2 Code block 2.1.3.7. Type this in to Matlab:
`channelstruct = r.ndr_reader_base.daqchannels2internalchannels('ai', channel, {filename}, epoch_select);`



