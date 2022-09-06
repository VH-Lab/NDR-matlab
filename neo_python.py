import neo
from neo.io.cedio import CedIO
from neo.io.spikegadgetsio import SpikeGadgetsIO
from neo.rawio.cedrawio import CedRawIO
from neo.rawio.spikegadgetsrawio import SpikeGadgetsRawIO
import quantities as pq
import numpy as np

class Utils:
  def get_header_channels(filenames):
    raw_reader = Utils.get_reader(filenames)
    raw_reader.parse_header()
    header = raw_reader.header
    aa = []
    for _type in ['signal_channels', 'spike_channels', 'event_channels']:
      numpy_channels = header[_type]
      python_channels = [dict(zip(numpy_channels.dtype.names,x)) for x in numpy_channels]
      for python_channel in python_channels:
        python_channel['_type'] = _type
        aa.append(python_channel)
    return aa

  # a = get_channels_from_segment(["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"], 1, 1)
  # print(a)
  def get_channels_from_segment(filenames, segment_index, block_index=1):
    io_reader = neo.io.get_io(filenames[0])
    blocks = io_reader.read(lazy=True)
    block = blocks[int(block_index) - 1]
    segment = block.segments[int(segment_index) - 1]

    signals = segment.analogsignals + segment.spiketrains + segment.irregularlysampledsignals
    channel_names = []
    for signal in signals:
      channel_names += signal.array_annotations['channel_names'].tolist()

    header_channels = Utils.get_header_channels(filenames)
    our_channels = list(filter(lambda channel: channel['name'] in channel_names, header_channels))
    return our_channels

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
    channel = list(filter(lambda channel: channel['id'] == channel_ids[0], all_channels))[0]
    stream_id = channel['stream_id']

    all_streams = reader.header['signal_streams']
    for index, stream in enumerate(all_streams):
      if stream_id == stream['id']: return index

  def get_reader(filenames):
    # NDI passes an array of strings, however Neo always expects a single string, even for multi-file readers.
    filename = filenames[0]

    # Ced can't find the CedRawIO class via get_rawio_class() for some reason
    if filename.endswith('.smr'):
      return CedRawIO(filename=filename)

    # => e.g. CedRawIO or SpikeGadgetsRawIO
    Klass = neo.rawio.get_rawio_class(filename)
    if (Klass.rawmode == 'one-file' or Klass.rawmode == 'multi-file'):
      reader = Klass(filename=filename)
    elif (Klass.rawmode == 'one-dir'):
      reader = Klass(dirname=filename)
    return reader

  def channel_to_sample_rate(channel):
    if channel['_type'] == 'signal_channels':
      return channel['sampling_rate']
    elif channel['_type'] == 'spike_channels':
      return channel['wf_sampling_rate']
    elif channel['_type'] == 'event_channels':
      return None

def get_t0t1(filenames, segment_index, block_index=1):
  reader = neo.io.get_io(filenames[0])
  block = reader.read()[block_index - 1]
  segment = block.segments[segment_index - 1]

  def get_magnitude(q):
    return q.rescale('s').item()

  return [get_magnitude(segment.t_start), get_magnitude(segment.t_stop)]

# a = get_t0t1(["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"], 1, 1)
# print(a)

def channel_type_from_neo_to_ndr(_type):
  # From NDR comments:
  #   DATA is a two-column vector; the first column has the time of the event. The second
  #   column indicates the marker code. In the case of 'events', this is just 1.
  if _type == 'signal_channels':
    return 'analog_input'
  # TODO might be other types!
  elif _type == 'spike_channels':
    return 'event'
  elif _type == 'event_channels':
    return 'marker'

# daqchannels2internalchannels(channelprefix, channelnumber, epochstreams, epochselect)
def convert_channels_from_neo_to_ndi(channel_names, filenames, segment_index, block_index=1):
  # 1. Get all channels from the segment
  channels = Utils.get_channels_from_segment(filenames, segment_index, block_index)

  # 2. Filter for the channels we're interested in
  needed_channels = filter(lambda channel: channel['name'] in channel_names, channels)

  # 3. Format from neo to ndi format
  formatted_channels = list(map(lambda channel: {
    'internal_type':        channel['_type'],
    'internal_number':      channel['id'],
    'internal_channelname': channel['name'],
    'ndr_type':             channel_type_from_neo_to_ndr(channel['_type']),
    # TODO hieroglyph prints out if we don't convert to str
    'samplerate':           str(Utils.channel_to_sample_rate(channel)),
    # This is a nonstandard Neo-only field
    'stream_id':            channel['stream_id']
  }, needed_channels))

  return formatted_channels

# a = convert_channels_from_neo_to_ndi(['Ain'], ['1'], ["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"], 1, 1)
# print(a)

def get_sample_rates_for_channel_ids(filenames, channel_ids):
  header_channels = Utils.get_header_channels(filenames)
  our_channels = list(filter(lambda channel: channel['id'] in channel_ids, header_channels))
  sample_rates = list(map(Utils.channel_to_sample_rate, our_channels))
  return sample_rates

# a = get_sample_rates_for_channel_ids(["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"], ['Ain1', 'Aout1'])
# print(a)

def can_be_read_together(channelstruct):
  stream_ids = list(map(lambda channel: channel['stream_id'], channelstruct))
  unique_stream_ids = np.unique(stream_ids)

  if (len(unique_stream_ids) > 1):
    error_message = ''
    for channel in channelstruct:
      error_message += f"\nChannel_id: '{channel['id']}', stream_id: '{channel['stream_id']}'."

    return {
      'b': 0,
      'errormsg': f"All of your channels should belong to a single signal_stream in Neo.\n{error_message}\n"
    }
  else:
    return {
      'b': 1,
      'errormsg': ""
    }

# => [{ type: '', name, '' }, ~]
def get_channels(filenames, segment_index, block_index=1):
  # 1. If the user cares about all channels in this file, simply parse the header
  if segment_index == 'all':
    reader = Utils.get_reader(filenames)
    reader.parse_header()
    def format(channels):
      # We can find the Neo type in "mfdaq_prefix(channeltype)" if we like
      return list(map(lambda channel: { 'name': channel['name'], 'type': 'neo' }, channels))

    a = format(reader.header['signal_channels'])
    b = format(reader.header['spike_channels'])
    c = format(reader.header['event_channels'])

    return a + b + c
  # 2. If the user passed segment_index, gather the channel info from every signal!
  else:
    reader = neo.io.get_io(filenames[0])
    blocks = reader.read(lazy=True)
    block = blocks[int(block_index) - 1]
    segment = block.segments[int(segment_index) - 1]

    def format(signals):
      channels = []
      for signal in signals:
        channels += list(map(lambda name: { 'name': name, 'type': 'neo' }, signal.array_annotations['channel_names']))
      return channels

    a = format(segment.analogsignals)
    b = format(segment.spiketrains)
    c = format(segment.irregularlysampledsignals)

    return a + b + c

# channels = get_channels(["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rec"], 'all');
# print(channels)

# readchannels_epochsamples(channeltype, channel, epochfiles, epochselect, s0, s1)
# Additional arguments: block_index
def read_channel(channel_type, channel_ids, filenames, segment_index, start_sample, end_sample, block_index=1):
  if channel_type == 'time':
    sample_rate = get_sample_rates_for_channel_ids(filenames, channel_ids)[0]
    sample_interval = 1/sample_rate

    times = []
    for sample in range(int(start_sample) - 1, int(end_sample)):
      times.append([sample * sample_interval])
    return np.array(times, np.float32)
  else:
    reader = Utils.get_reader(filenames)

    stream_index = Utils.from_channel_ids_to_stream_index(reader, channel_ids)
    raw = reader.get_analogsignal_chunk(
      block_index=int(block_index), seg_index=int(segment_index),
      i_start=int(start_sample) - 1, i_stop=int(end_sample),
      channel_ids=channel_ids,
      stream_index=int(stream_index)
    )
    rescaled = reader.rescale_signal_raw_to_float(
      raw,
      channel_ids=channel_ids,
      stream_index=int(stream_index)
    )

    return rescaled

# data = read_channel("time", ['0', '1'], ["/Users/lakesare/Desktop/NDR-matlab/example_data/example.rhd"], segment_index=0, start_sample=1, end_sample=10)
# print(data)

# function [data] = readevents_epochsamples_native(self, channeltype, channel, epochstreams, epoch_select, t0, t1)
def read_channel_events(channel_type, channel_ids, filenames, segment_index, t0, t1):
  pass
