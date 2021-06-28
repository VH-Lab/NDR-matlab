# Channel names in Intan RHD files:

## How channels are named natively according to the Intan system:

| CED Type | How specified | Example native channel name | Example meaning |
| -- | -- | -- | --- | 
|Waveforms| Specified according to type and number | ai21 | Analog input channel 21 |
| Event- | Fill in |Fill in | Fill in|
| Event+ | Fill in |Fill in | Fill in|
| Level  | FIll in | Fill in | fill in |
| Marker | mk30 | 30 | marker on channel 30 |
| TextMark | Fill in |Fill in | Fill in|
| | Fill in |Fill in | Fill in|

 (change the below for ced_smr)

| Example input to `ndr.read` | Meaning |
| --- | --- | 
| 'A000-015' | Traditional analog input channels A-001 through A-021 (total of 20 channels) |
| 'A000-010;B023-035' | Traditional analog input channels A-001 through A-010 and channels B-023 through 035 (total of 23 channels) |
| 'DIN00-15' | Digital input channels 00 - 15 |
| 'AAUX1-3' | Auxillary inputs 1-3 from bank A |





