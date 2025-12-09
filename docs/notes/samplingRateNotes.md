# Sampling Rate Manual Calculation Notes

The following locations in the code perform manual sample-to-time or time-to-sample conversions assuming a constant sampling rate and no gaps. These should eventually be migrated to use `ndr.time.fun.samples2times` or `ndr.reader.base.samples2times`.

| Class | Method | Line Number | Code Snippet |
|---|---|---|---|
| `ndr.reader.ced_smr` | `readchannels_epochsamples` | 91 | `t0 = (s0-1)/sr;` |
| `ndr.reader.intan_rhd` | `t0_t1` | 156 | `total_time = total_samples / header.frequency_parameters.amplifier_sample_rate;` |
| `ndr.reader.intan_rhd` | `readchannels_epochsamples` | 288 | `t0 = (s0-1)/sr;` |
| `ndr.reader.spikegadgets_rec` | `t0_t1` | 169 | `total_time = (total_samples - 1) / str2num(fileconfig.samplingRate);` |
