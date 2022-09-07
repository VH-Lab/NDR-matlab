import neo
from neo.rawio.cedrawio import CedRawIO
import quantities as pq
import numpy as np
import Utils

def getchannelsepoch(filenames, segment_index, block_index=1):
  def format(channels):
    return list(map(lambda channel: {
      'name': channel['name'],
      'type': Utils.channel_type_from_neo_to_ndr(channel['_type'])
    }, channels))

  # 1. If the user cares about all channels in this file, simply parse the header
  if segment_index == 'all':
    all_channels = Utils.get_header_channels(filenames)
    return format(all_channels)
  # 2. If the user passed segment_index, gather the channel info from every signal!
  else:
    segment_channels = Utils.get_channels_from_segment(filenames, segment_index, block_index)
    return format(segment_channels)

def readchannels_epochsamples(channel_type, channel_names, filenames, segment_index, start_sample, end_sample, block_index=1):
  if channel_type == 'time':
    sample_rate = samplerate(filenames, channel_names)[0]
    sample_interval = 1/sample_rate

    times = []
    for sample in range(int(start_sample) - 1, int(end_sample)):
      times.append([sample * sample_interval])
    return np.array(times, np.float32)
  else:
    reader = Utils.get_reader(filenames)
    # THIS IS needed for the get_analogsignal_chunk() call!
    reader.parse_header()

    stream_index = Utils.from_channel_names_to_stream_index(filenames, channel_names)

    raw = reader.get_analogsignal_chunk(
      block_index=int(block_index) - 1, seg_index=int(segment_index) - 1,
      i_start=int(start_sample) - 1, i_stop=int(end_sample),
      channel_names=channel_names,
      stream_index=int(stream_index)
    )
    rescaled = reader.rescale_signal_raw_to_float(
      raw,
      channel_names=channel_names,
      stream_index=int(stream_index)
    )

    return rescaled

def daqchannels2internalchannels(channel_names, filenames, segment_index, block_index=1):
  # 1. Get all channels from the segment
  channels = Utils.get_channels_from_segment(filenames, segment_index, block_index)

  # 2. Filter for the channels we're interested in
  needed_channels = filter(lambda channel: channel['name'] in channel_names, channels)

  # 3. Format from neo to ndi format
  formatted_channels = list(map(lambda channel: {
    'internal_type':        channel['_type'],
    'internal_number':      channel['id'],
    'internal_channelname': channel['name'],
    'ndr_type':             Utils.channel_type_from_neo_to_ndr(channel['_type']),
    # TODO hieroglyph prints out if we don't convert to str
    'samplerate':           str(Utils.channel_to_sample_rate(channel)),
    # This is a nonstandard Neo-only field
    'stream_id':            channel['stream_id']
  }, needed_channels))

  return formatted_channels

def canbereadtogether(channelstruct):
  '''
  => { 'b': 1, 'errormsg': '' } when all channels belong to the same stream.
  => { 'b': 0, 'errormsg': 'explanation...' when some channels belong to different streams.

  Neo helps us by grouping all analogsignals into a single signal_stream when these analogsignals have the same: "sampling_rate, start_time, length, sample dtype".
  That is, it only makes sense to retrieve channels from a single stream!
  
  Neo docs: "A stream thus has multiple channels which all have the same sampling rate and are on the same clock, have the same sections with t_starts and lengths, and the same data type for their samples. The samples in a stream can thus be retrieved as an Numpy array, a chunk of samples."
  '''
  stream_ids = list(map(lambda channel: channel['stream_id'], channelstruct))
  unique_stream_ids = np.unique(stream_ids)

  if (len(unique_stream_ids) > 1):
    error_message = ''
    for channel in channelstruct:
      error_message += f"\nChannel_name: '{channel['name']}', stream_id: '{channel['stream_id']}'."

    return {
      'b': 0,
      'errormsg': f"All of your channels should belong to a single signal_stream in Neo.\n{error_message}\n"
    }
  else:
    return {
      'b': 1,
      'errormsg': ""
    }

def samplerate(filenames, channel_names):
  header_channels = Utils.get_header_channels(filenames)
  our_channels = list(filter(lambda channel: channel['name'] in channel_names, header_channels))
  sample_rates = list(map(Utils.channel_to_sample_rate, our_channels))
  return sample_rates

def t0_t1(filenames, segment_index, block_index=1):
  reader = neo.io.get_io(filenames[0])
  block = reader.read()[block_index - 1]
  segment = block.segments[segment_index - 1]

  def get_magnitude(q):
    return q.rescale('s').item()

  return [get_magnitude(segment.t_start), get_magnitude(segment.t_stop)]

def read_channel_events(channel_type, channel_names, filenames, segment_index, t0, t1):
  pass
