#!/usr/bin/env python3
"""A self-contained fake of the ``sonpipe`` CLI for NDR-matlab unit tests.

It reproduces the sonpipe command-line *contract* (the ``header`` /
``sampleinterval`` / ``read`` sub-commands and their JSON / raw-binary output)
for a small synthetic file, using only the Python standard library -- no numpy,
no sonpy, no CED binaries. This lets NDR's ndr.format.ced 64-bit dispatch and
its +ced/+sonpipe adapter be exercised end-to-end wherever a Python 3
interpreter is available.

Synthetic layout (all times in seconds; timebase 1 us/tick):
  channel 1  Adc        10 kHz, 1000 samples; sample value == sample index
  channel 4  EventFall  events at k * 1e-4 s, k = 0..999
  channel 6  TextMark   text markers every 400 ticks
"""

import json
import struct
import sys

TIMEBASE = 1e-6
DIVIDE = 100
N = 1000
SR = 1.0 / (DIVIDE * TIMEBASE)   # 10000 Hz
SI = DIVIDE * TIMEBASE           # 1e-4 s
MAXT = N * DIVIDE                # 100000 ticks

CH = {
    1: dict(kind=1, kind_name="Adc", ndr_type="analog_in", title="Ramp", units="V"),
    4: dict(kind=2, kind_name="EventFall", ndr_type="event", title="Trig", units=""),
    6: dict(kind=8, kind_name="TextMark", ndr_type="text", title="Notes", units=""),
}


def chinfo(num):
    c = CH[num]
    wave = c["kind"] in (1, 9)
    return {
        "number": num, "index": num - 1, "kind": c["kind"],
        "kind_name": c["kind_name"], "ndr_type": c["ndr_type"],
        "title": c["title"], "units": c["units"], "comment": "",
        "max_time_ticks": MAXT, "max_time": MAXT * TIMEBASE,
        "sampleinterval": SI if wave else None,
        "samplerate": SR if wave else None,
        "divide": DIVIDE if wave else None,
        "ideal_rate": SR if wave else None,
        "scale": 1.0 if wave else None,
        "offset": 0.0 if wave else None,
        "num_samples": N if wave else None,
    }


def opt(args, name):
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return args[i + 1]
    return None


def main():
    argv = sys.argv[1:]
    if not argv or argv[0] == "--version":
        sys.stdout.write("sonpipe 0.1.0-fake\n")
        return 0

    cmd, rest = argv[0], argv[1:]

    if cmd == "header":
        out = {
            "fileinfo": {"path": rest[0], "timebase": TIMEBASE, "max_channels": 6,
                         "max_time_ticks": MAXT, "max_time": MAXT * TIMEBASE, "version": 9},
            "channelinfo": [chinfo(n) for n in sorted(CH)],
        }
        sys.stdout.write(json.dumps(out))
        return 0

    if cmd == "sampleinterval":
        c = int(opt(rest, "-c") or opt(rest, "--channel"))
        ci = chinfo(c)
        sys.stdout.write(json.dumps({
            "channel": c, "kind": ci["kind"], "kind_name": ci["kind_name"],
            "sampleinterval": ci["sampleinterval"], "samplerate": ci["samplerate"],
            "total_samples": ci["num_samples"], "total_time": ci["max_time"]}))
        return 0

    if cmd == "read":
        c = int(opt(rest, "-c") or opt(rest, "--channel"))
        kind = chinfo(c)["kind"]
        if kind in (1, 9):  # waveform -> raw little-endian doubles (== sample index)
            start = int(opt(rest, "--start") or 0)
            count = opt(rest, "--count")
            count = (N - start) if count is None else int(count)
            count = max(0, min(count, N - start))
            vals = [float(start + i) for i in range(count)]
            sys.stdout.buffer.write(struct.pack("<%dd" % len(vals), *vals))
            sys.stdout.buffer.flush()
            # Completion sentinel, matching the real CLI. The MATLAB layer relies
            # on this line to distinguish a finished read from a mid-stream crash.
            sys.stderr.write(
                "sonpipe: wrote %d samples (double) for channel %d\n" % (len(vals), c))
            return 0
        if kind in (2, 3, 4):  # event -> raw little-endian double times
            times = [k * SI for k in range(N)]
            t0, t1 = opt(rest, "--t0"), opt(rest, "--t1")
            if t0 is not None:
                times = [t for t in times if t >= float(t0)]
            if t1 is not None:
                times = [t for t in times if t <= float(t1)]
            sys.stdout.buffer.write(struct.pack("<%dd" % len(times), *times))
            sys.stdout.buffer.flush()
            sys.stderr.write(
                "sonpipe: wrote %d event times (double) for channel %d\n" % (len(times), c))
            return 0
        # marker / textmark -> JSON
        markers = [{"tick": t, "time": t * TIMEBASE, "code": [1, 0, 0, 0],
                    "text": "note%d" % t} for t in range(0, MAXT, 400)]
        sys.stdout.write(json.dumps({"channel": c, "kind": kind,
                                     "kind_name": chinfo(c)["kind_name"],
                                     "count": len(markers), "markers": markers}))
        return 0

    sys.stderr.write("fake_sonpipe: unknown command %s\n" % cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main())
