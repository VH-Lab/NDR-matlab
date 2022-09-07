import neo
from neo.rawio.cedrawio import CedRawIO
import quantities as pq
import numpy as np

def get_header_channels(filenames):
  raw_reader = get_reader(filenames)
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

def get_channels_from_segment(filenames, segment_index, block_index=1):
  io_reader = neo.io.get_io(filenames[0])
  blocks = io_reader.read(lazy=True)
  block = blocks[int(block_index) - 1]
  segment = block.segments[int(segment_index) - 1]

  signals = segment.analogsignals + segment.spiketrains + segment.irregularlysampledsignals
  channel_names = []
  for signal in signals:
    channel_names += signal.array_annotations['channel_names'].tolist()

  header_channels = get_header_channels(filenames)
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
    return 0

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
