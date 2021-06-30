# Channel names in Intan RHD files:

## How channels are named natively according to the Intan system:

| CED Type | How specified | Example native channel name | Example meaning |
| -- | -- | -- | --- | 
|Waveforms| Specified according to type and number | ai21 | Reads waveform data on channel 21 |
| Event- | NDR events can go up or down, so it is specified as an event and channel number only | e24 | All events on channel 24, either positive going or negative going|
| Event+ | NDR events can go up or down, so it is specified as an event and channel number only | e24 | All events on channel 24, either positive going or negative going|
| Level  | To be filled in | To be filled in | To be filled in |
| Marker | Specify a numeric marker with the channel number | mk20 | numeric marker on channel 20 |
| TextMark | Specify a text marker with the channel number | text30  | Text marker on channel 30|

 (change the below for ced_smr)

| Example input to `ndr.read` | Meaning |
| --- | --- | 
| 'ai1-3' | Waveforms on channels 1 through 3 (total of 3 channels) |
| 'e10' | Digital events on channel 10 |
| 'text30' | Text marker events on channel 30|






