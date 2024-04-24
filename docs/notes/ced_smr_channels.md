# Channel names in CED Spike2 files:

## How channels are named natively according to the CED Spike2 systems:

| CED Type | What it is | How specified | Example native channel name | Example meaning |
| -- | -- | -- | -- | --- | 
|Waveforms| Analog waveforms that are regularly sampled | Specified according to type and number | ai21 | Reads waveform data on channel 21 |
| Event- | Digital events that are defined by a negative-going signal | 'e' and channel number  | e24 | All events on channel 24 (no check is made to ensure they are negative going, any event on channel 24 is returned)|
| Event+ | Digital events that are defined by a negative-going signal | 'e' and channel number  | e25 | All events on channel 25 (no check is made to ensure they are positive going, any event on channel 25 is returned) |
| Level  | Digital events that are defined by a positive or negative-going signal | 'e' and channel number | e26 | All events on channel 26 (no check is made to see how the event is defined) 
| Marker | Specify a numeric marker with the channel number | mk20 | numeric marker on channel 20 |
| TextMark | Specify a text marker with the channel number | text30  | Text marker on channel 30|



| Example input to `ndr.read` | Meaning |
| --- | --- | 
| 'ai1-3' | Waveforms on channels 1 through 3 (total of 3 channels) |
| 'e10' | Digital events on channel 10 |
| 'text30' | Text marker events on channel 30|






