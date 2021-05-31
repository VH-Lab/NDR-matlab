# Channel names in Intan RHD files:

## How channels are named natively according to the Intan system:

| Type | How specified | Example native channel name | Example meaning |
| -- | -- | -- | --- | 
|Traditional analog inputs | Specified according to the input bank ('A', 'B', 'C', D', etc) and a number. | A-000 | Analog input bank A, channel 000 |
| Auxillary analog inputs | Specified according to input bank ('A', 'B', 'C', 'D', etc) followed by '-AUX' and a number. | A-AUX2 | Auxillary input bank A channel 2 |
| Traditional digital inputs | Specified with 'DIN-' followed by the channel number | DIN-00 | Digital input channel 00 |
| Traditional digital outputs log | Specified with 'DOUT-' followed by the channel number | DOUT-00 | Digital output channel 00 |
| Supply voltage channels | Specified with bank followed by '-VDD1' | A-VDD1 | Supply voltage on port A |

NDR doesn't allow dashes in read strings so one specfies channels from different banks according to the following examples:

| Example input to `ndr.read` | Meaning |
| --- | --- | 
| 'A000-015' | Traditional analog input channels A-000 through A-015 (total of 16 channels) |
| 'A000-010;B023-035' | Traditional analog input channels A-000 through A-010 and channels B-023 through 035 (total of 24 channels) |
| 'DIN00-15' | Digital input channels 00 - 15 |
| 'AAUX1-3' | Auxillary inputs 1-3 from bank A |

## Relative channel specification for Intan:

NDR also allows one to specify Intan channels in a relative fashion. The mapping between relative channels and the native channel names
varies depending upon which channels were turned on during a particular recording.

| Type | How specified | Example channel name | Example meaning |
| --- | --- | --- | --- |
| Traditional analog inputs | 'ai' followed by channel number | 'ai1' | The first analog input channel that was turned on in the acquisition; for example, if A-023 was the lowest channel that was turned on during the recording, then 'ai1' would correspond to channel A-023. If A-030 was the lowest channel turned on during the recording, then 'ai1' would correspond to A-030. |
| Traditional digital inputs | 'di' followed by channel number | 'di1' | The first digital input channel. If DIN-000 was active, then 'di1' would correspond to DIN-000. |

Examples:

| Example input to `ndr.read` | Meaning |
| --- | --- |
| 'ai1-5' | The first (lowest name/numbered) 5 channels that were turned on during the recording. |
| 'ai5-7' | The fifth through 7th channels (starting from the lowest name/number) that were turned on during the recording. |
| 'di1-16' | The first through 16th digital channels that were turned on during the recording. |




