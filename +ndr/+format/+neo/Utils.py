import neo
from neo.rawio.cedrawio import CedRawIO

def get_header_channels(raw_reader):
  raw_reader.parse_header()
  header = raw_reader.header
  all_channels = []
  for _type in ['signal_channels', 'spike_channels', 'event_channels']:
    numpy_channels = header[_type]
    python_channels = [dict(zip(numpy_channels.dtype.names,x)) for x in numpy_channels]
    for python_channel in python_channels:
      python_channel['_type'] = _type
      all_channels.append(python_channel)
  return all_channels

def get_channels_from_segment(reader, raw_reader, segment_index, block_index):
  blocks = reader.read(lazy=True)
  block = blocks[block_index]
  segment = block.segments[segment_index]

  signals = segment.analogsignals + segment.spiketrains + segment.irregularlysampledsignals
  channel_names = []
  for signal in signals:
    channel_names += signal.array_annotations['channel_names'].tolist()

  header_channels = get_header_channels(raw_reader)
  our_channels = list(filter(lambda channel: channel['name'] in channel_names, header_channels))
  return our_channels

def from_channel_names_to_stream_index(raw_reader, channel_names):
  '''
  => a single stream_index that the first passed channel belongs to
  '''
  all_channels = get_header_channels(raw_reader)
  channel = list(filter(lambda channel: channel['name'] == channel_names[0], all_channels))[0]
  stream_id = channel['stream_id']

  all_streams = raw_reader.header['signal_streams']
  for index, stream in enumerate(all_streams):
    if stream_id == stream['id']: return index

def from_channel_name_to_event_channel_index(raw_reader, channel_name):
  raw_reader.parse_header()
  event_channels = raw_reader.header['event_channels']
  n = raw_reader.event_channels_count()
  for event_channel_index in range(n):
    if (event_channels[event_channel_index]['name'] == channel_name):
      return event_channel_index

def from_channel_name_to_marker_channel_index(raw_reader, channel_name):
  raw_reader.parse_header()
  spike_channels = raw_reader.header['spike_channels']
  n = raw_reader.spike_channels_count()
  for spike_channel_index in range(n):
    if (spike_channels[spike_channel_index]['name'] == channel_name):
      return spike_channel_index

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
  elif _type == 'spike_channels':
    return 'event'
  # From Neo: ev_timestamps, _, ev_labels = reader.event_timestamps(event_channel_index=0)
  # So, events have labels => they are markers in Neo
  elif _type == 'event_channels':
    return 'marker'

def get_sample_rates(raw_reader, channel_names):
  header_channels = get_header_channels(raw_reader)
  our_channels = list(filter(lambda channel: channel['name'] in channel_names, header_channels))
  sample_rates = list(map(channel_to_sample_rate, our_channels))
  return sample_rates

def get_reader(filenames):
  # => e.g. CedIO or SpikeGadgetsIO
  reader = neo.io.get_io(filenames[0])
  return reader

def get_raw_reader(filenames):
  # NDI passes an array of strings, however Neo always expects a single string, even for multi-file readers.
  filename = filenames[0]

  # Ced can't find the CedRawIO class via get_rawio_class() for some reason
  if filename.endswith('.smr'):
    return CedRawIO(filename=filename)

  # => e.g. CedRawIO or SpikeGadgetsRawIO
  Klass = neo.rawio.get_rawio_class(filename)
  if (Klass.rawmode == 'one-file' or Klass.rawmode == 'multi-file'):
    raw_reader = Klass(filename=filename)
  elif (Klass.rawmode == 'one-dir'):
    raw_reader = Klass(dirname=filename)

  return raw_reader
