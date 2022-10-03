import neo
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
    raw_reader = Utils.get_raw_reader(filenames)
    all_channels = Utils.get_header_channels(raw_reader)
    return format(all_channels)
  # 2. If the user passed segment_index, gather the channel info from every signal!
  else:
    reader = Utils.get_reader(filenames)
    raw_reader = Utils.get_raw_reader(filenames)
    segment_channels = Utils.get_channels_from_segment(reader, raw_reader, int(segment_index) - 1, int(block_index) - 1)
    return format(segment_channels)

def readchannels_epochsamples(channel_type, channel_names, filenames, segment_index, start_sample, end_sample, block_index=1):
  if channel_type == 'time':
    raw_reader = Utils.get_raw_reader(filenames)
    sample_rate = Utils.get_sample_rates(raw_reader, channel_names)[0]
    sample_interval = 1/sample_rate

    times = []
    for sample in range(int(start_sample) - 1, int(end_sample)):
      times.append([sample * sample_interval])
    return np.array(times, np.float32)
  else:
    raw_reader = Utils.get_raw_reader(filenames)

    stream_index = Utils.from_channel_names_to_stream_index(raw_reader, channel_names)

    raw = raw_reader.get_analogsignal_chunk(
      block_index=int(block_index) - 1, seg_index=int(segment_index) - 1,
      i_start=int(start_sample) - 1, i_stop=int(end_sample),
      channel_names=channel_names,
      stream_index=int(stream_index)
    )
    rescaled = raw_reader.rescale_signal_raw_to_float(
      raw,
      channel_names=channel_names,
      stream_index=int(stream_index)
    )

    return rescaled

def daqchannels2internalchannels(channel_names, filenames, segment_index, block_index=1):
  reader = Utils.get_reader(filenames)
  raw_reader = Utils.get_raw_reader(filenames)

  # 1. Get all channels from the segment
  channels = Utils.get_channels_from_segment(reader, raw_reader, int(segment_index) - 1, int(block_index) - 1)

  # 2. Filter for the channels we're interested in
  needed_channels = filter(lambda channel: channel['name'] in channel_names, channels)

  # 3. Format from neo to ndi format
  formatted_channels = list(map(lambda channel: {
    'internal_type':        channel['_type'],
    'internal_number':      channel['id'],
    'internal_channelname': channel['name'],
    'ndr_type':             Utils.channel_type_from_neo_to_ndr(channel['_type']),
    # At some point the hieroglyph was printing out if we did't convert the sample rate to str.
    # I can't replicate this issue now, might have been a problem with a particular Python version.
    # Still leaving this wrapped in str() for safety.
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
  raw_reader = Utils.get_raw_reader(filenames)
  return Utils.get_sample_rates(raw_reader, channel_names)

def t0_t1(filenames, segment_index, block_index=1):
  reader = Utils.get_reader(filenames)
  block = reader.read()[block_index - 1]
  segment = block.segments[segment_index - 1]

  def get_magnitude(q):
    return q.rescale('s').item()

  return [get_magnitude(segment.t_start), get_magnitude(segment.t_stop)]

def readevents_epochsamples_native(channel_type, channel_names, filenames, segment_index, start_time, end_time, block_index=1):
  raw_reader = Utils.get_raw_reader(filenames)

  if channel_type == 'marker':
    list_of_timestamps = []
    list_of_marker_codes = []

    for channel_name in channel_names:
      event_channel_index = Utils.from_channel_name_to_event_channel_index(raw_reader, channel_name)
      timestamps, _durations, marker_codes = raw_reader.get_event_timestamps(
        event_channel_index=event_channel_index,
        block_index=int(block_index) - 1,
        seg_index=int(segment_index) - 1,
        t_start=start_time,
        t_stop=end_time
      )
      timestamps = raw_reader.rescale_event_timestamp(timestamps, event_channel_index=event_channel_index)
      list_of_timestamps.append(timestamps.tolist())
      list_of_marker_codes.append(marker_codes.tolist())

    return [list_of_timestamps, list_of_marker_codes]
  elif channel_type == 'event':
    list_of_timestamps = []
    list_of_events = []

    for channel_name in channel_names:
      timestamps = raw_reader.get_spike_timestamps(
        spike_channel_index=Utils.from_channel_name_to_marker_channel_index(raw_reader, channel_name),
        block_index=int(block_index) - 1,
        seg_index=int(segment_index) - 1,
        t_start=start_time,
        t_stop=end_time
      )
      timestamps = raw_reader.rescale_spike_timestamp(timestamps)
      events = [1] * len(timestamps)
      list_of_timestamps.append(timestamps.tolist())
      list_of_events.append(events)

    return [list_of_timestamps, list_of_events]
  else:
    raise Exception(f"channel_type in readevents_epochsamples_native(channel_type, ...) should be either 'marker' or 'event', not {str(channel_type)}")
