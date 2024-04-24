# Channels in TDT SEV files


## How are channels named natively in TDT SEV files?

Channels are named by numbers starting with 1

| Type | How specified | Example native channel name | Example meaning |
| -- | -- | -- | -- |
| Analog inputs | ChN | 'Ch1' | Analog input channel 1 |




## Questions for TDT on SEV

1. Can recordings begin at a local time other than t==0? Is there any concept of local time in SEV data?
2. Does SEV data only comprise of analog input data? Can one have digital inputs or events?
3. If there is a gap in a recording, is this a big problem? Can we still find out the time of each sample that was acquired?
4. Can different analog inputs be sampled at different rates or for different durations?
5. Can there be more than one "epoch" present in each directory? An epoch for us is a period of time when sampling is started and then turned off. For example, if there are two event-triggered recordings, can they be in the same directory?
6. Are TDT SEV files always little-endian?

