"""blosc_tool.py - encode/decode Blosc v1 containers via numcodecs.

This file is the Python worker that ndr.format.blosc.encode/decode
invoke as a subprocess. It is deliberately tiny: one command-line
verb, raw bytes over stdin/stdout, all knobs on argv. No import of
anything MATLAB. Runs under the private venv at
<NDR-matlab>/private_env/blosc/ that ndr.util.blosc.setup creates.

Why a subprocess and not MATLAB's `py.` bridge:
    MATLAB's `pyenv` is process-global. Setting it steals whatever
    Python configuration the customer's session already has. This
    tool is invoked as `<venv>/bin/python blosc_tool.py ...`; the
    customer's Python stays where it is.

Verbs:
    encode --cname NAME --clevel N --shuffle {0,1,2} --typesize N
           [--blocksize N]
        Read raw bytes from stdin, write a Blosc container to stdout.

    decode
        Read a Blosc container from stdin, write raw bytes to stdout.
        typesize is read from the container header; the caller does
        not have to supply it.

    version
        Print JSON {numcodecs, blosc} on stdout. Used by
        ndr.util.blosc.version.
"""

from __future__ import annotations

import argparse
import json
import sys


def _read_stdin_bytes() -> bytes:
    return sys.stdin.buffer.read()


def _write_stdout_bytes(b: bytes) -> None:
    sys.stdout.buffer.write(b)


def _dtype_for(typesize: int):
    import numpy as np

    if typesize in (1, 2, 4, 8):
        return np.dtype(f"u{typesize}")
    if typesize <= 0:
        raise ValueError(f"typesize must be positive, got {typesize}")
    return np.dtype(f"V{typesize}")


def cmd_encode(args) -> None:
    import numpy as np
    from numcodecs import Blosc

    raw = _read_stdin_bytes()
    dt = _dtype_for(args.typesize)
    if len(raw) % dt.itemsize != 0:
        raise ValueError(
            f"input length {len(raw)} is not a multiple of typesize {dt.itemsize}"
        )
    buf = np.frombuffer(raw, dtype=dt)
    codec = Blosc(
        cname=args.cname,
        clevel=args.clevel,
        shuffle=args.shuffle,
        blocksize=args.blocksize,
    )
    _write_stdout_bytes(bytes(codec.encode(buf)))


def cmd_decode(args) -> None:
    from numcodecs import Blosc

    _ = args
    container = _read_stdin_bytes()
    codec = Blosc()
    out = codec.decode(container)
    _write_stdout_bytes(bytes(out))


def cmd_version(args) -> None:
    import numcodecs

    _ = args
    payload = {
        "numcodecs": getattr(numcodecs, "__version__", ""),
        "blosc": None,
    }
    try:
        from numcodecs import blosc as _blosc

        payload["blosc"] = getattr(_blosc, "__version__", None) or getattr(
            _blosc, "blosc_version", lambda: None
        )()
    except Exception:
        pass
    sys.stdout.write(json.dumps(payload))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="blosc_tool")
    sub = parser.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("encode")
    e.add_argument("--cname", default="zstd")
    e.add_argument("--clevel", type=int, default=5)
    e.add_argument("--shuffle", type=int, choices=(0, 1, 2), default=1)
    e.add_argument("--typesize", type=int, required=True)
    e.add_argument("--blocksize", type=int, default=0)
    e.set_defaults(func=cmd_encode)

    d = sub.add_parser("decode")
    d.set_defaults(func=cmd_decode)

    v = sub.add_parser("version")
    v.set_defaults(func=cmd_version)

    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
