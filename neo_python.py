import neo
from neo.io.cedio import CedIO
from neo.io.spikegadgetsio import SpikeGadgetsIO
from neo.rawio.cedrawio import CedRawIO
from neo.rawio.spikegadgetsrawio import SpikeGadgetsRawIO
import quantities as pq
import numpy as np

# print(get_channels("/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"));
# getchannelsepoch(epochfiles, epochselect)
# => [{ type: '', name, '' }, ~]
def get_channels(filename, segment_index):
  # => e.g. CedRawIO or SpikeGadgetsRawIO
  Klass = neo.rawio.get_rawio_class(filename)
  reader = Klass(filename=filename)
  reader.parse_header()
  # return {
  #   'signal_channels': reader.header['signal_channels'],
  #   'spike_channels':  reader.header['spike_channels'],
  #   'event_channels':  reader.header['event_channels']
  # }
  # print(reader.header['signal_channels'].dtype)
  # print(reader.header['signal_channels'])

  signal_channels = reader.header['signal_channels']
  mapped = list(map(lambda channel: { 'name': channel['name'], 'type': 'hi' }, signal_channels))
  return mapped



# get_channels("/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec", 0);

def from_channel_ids_to_stream_index(reader, channel_ids):
  '''
  => a single stream_index that all passed channels belong to, or
  => throws an exception if not all channels belong to a single stream. 

  Neo helps us by grouping all analogsignals into a single signal_stream when these analogsignals have the same: "sampling_rate, start_time, length, sample dtype".
  That is, it only makes sense to retrieve channels from a single stream!
  
  Neo docs: "A stream thus has multiple channels which all have the same sampling rate and are on the same clock, have the same sections with t_starts and lengths, and the same data type for their samples. The samples in a stream can thus be retrieved as an Numpy array, a chunk of samples."
  '''
  reader.parse_header()

  all_channels = reader.header['signal_channels']
  channels = list(filter(lambda channel: channel['id'] in channel_ids, all_channels))

  stream_ids = list(map(lambda channel: channel['stream_id'], channels))

  unique_stream_ids = np.unique(stream_ids)

  if (len(unique_stream_ids) != 1):
    error_message = ''
    for channel in channels:
      error_message += (f"\nChannel_id: '{channel['id']}', stream_id: '{channel['stream_id']}'.")
    raise ValueError(f"All of your channels should belong to a single signal_stream in Neo.\n{error_message}\n")
  else:
    stream_id = unique_stream_ids[0]
    all_streams = reader.header['signal_streams']
    for index, stream in enumerate(all_streams):
      if stream_id == stream['id']: return index

def get_reader(filenames):
  # NDI passes an array of strings, however Neo always expects a single string, even for multi-file readers.
  filename = filenames[0]
  Klass = neo.rawio.get_rawio_class(filename)
  if (Klass.rawmode == 'one-file' or Klass.rawmode == 'multi-file'):
    reader = Klass(filename=filename)
  elif (Klass.rawmode == 'one-dir'):
    reader = Klass(dirname=filename)
  return reader

# readchannels_epochsamples(channeltype, channel, epochfiles, epochselect, s0, s1)
# Additional arguments: block_index
def read_channel(channel_type, channel_ids, filenames, segment_index, start_sample, end_sample, block_index=0):
  reader = get_reader(filenames)

  stream_index = from_channel_ids_to_stream_index(reader, channel_ids)
  raw = reader.get_analogsignal_chunk(
    block_index=block_index, seg_index=segment_index,
    i_start=start_sample, i_stop=end_sample,
    channel_ids=channel_ids,
    stream_index=stream_index
  )
  rescaled = reader.rescale_signal_raw_to_float(raw, stream_index=stream_index, channel_ids=channel_ids)
  return rescaled

# data = read_channel("smth", ['0'], ["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rhd"], segment_index=0, start_sample=1, end_sample=10)
# print(data)


# samplerate(epochstreams, epoch_select, channeltype, channel)
def sample_rate(filename, epoch_select, channel_type, channel_index):
  reader = neo.io.get_io(filename)
  blocks = reader.read(lazy=True)
  for block in blocks:
    segment = block.segments[epoch_select - 1]
    for analog_signal in segment.analogsignals:
      mm = analog_signal.load(channel_indexes=[channel_index])
      # How do we use channel_type here?
      return mm.sampling_rate

# t0_t1(epochfiles, epochselect)
# When did this epoch begin, and when did it end?
def t0_t1(filename, epoch_select):
  reader = neo.io.get_io(filename)
  blocks = reader.read(lazy=True)
  for block in blocks:
    segment = block.segments[epoch_select - 1]
    return segment.end_time # TODO find how to find segment end_time in Neo




# Google [x]: cell array
# Google [x]: what's "{[t0 t1]};" object in Matlab
# Google [x]: how to use : (colon) in Matlab, e.g. "time(:)"
# Google [x]: ced_smr determines time by "dTimeBase * maxFTime * usPerTime". What are these?
# Google [x]: what's "{ 'analog_in', 'aux_in', 'analog_out', 'digital_in', 'digital_out', 'marker', 'event', 'time' };" object in Matlab
# Google [x]: what's the "case {2,3,4}," object in Matlab
# Google [x]: what's numel in Matlab "for i=1:numel(channel),"
# Google [x]: what's ... in Matlab
#     [data] = SONGetEventChannel(fid,header.channelinfo(channel_index).number,...
#              block_start,block_end);





