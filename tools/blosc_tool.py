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

    encode_batch --cname NAME --clevel N --shuffle {0,1,2} --typesize N
                 [--blocksize N]
        Read a batched request from stdin and write a batched
        response to stdout. Wire format is a length-prefixed list of
        items: each item is a 64-bit little-endian unsigned length
        followed by that many bytes. The first 4 bytes of stdin are a
        32-bit little-endian item count; then each item is
        length-prefixed. Response format mirrors the input: 32-bit
        count then N length-prefixed encoded items.

    decode_batch
        Same wire format as encode_batch, but each input item is a
        Blosc container and each output item is the decoded raw
        bytes.

    server
        Persistent mode. One process handles many encode/decode
        requests. Protocol: a request is
            4 bytes  op  ("ENCB" / "DECB" / "QUIT")
            32 bytes options (raw ASCII, right-padded with NULs; ignored on
                              DECB / QUIT)
            8 bytes  payload length (little-endian uint64)
            <payload> N bytes, formatted as a batched request body
                     (item count + length-prefixed items, same as
                     encode_batch / decode_batch stdin).
        Response format is
            4 bytes  status  ("OK  " / "ERR ")
            8 bytes  payload length
            <payload>
        For ENCB / DECB the payload is a batched response body. For
        ERR the payload is a UTF-8 error message. QUIT returns OK
        with an empty payload and then exits.

    version
        Print JSON {numcodecs, blosc} on stdout. Used by
        ndr.util.blosc.version.
"""

from __future__ import annotations

import argparse
import json
import struct
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


def _read_batch(buf: bytes) -> list[bytes]:
    """Parse the length-prefixed batch wire format into a list of items."""
    if len(buf) < 4:
        raise ValueError(f"batch header too short: {len(buf)} bytes")
    (count,) = struct.unpack("<I", buf[:4])
    items: list[bytes] = []
    off = 4
    for _ in range(count):
        if off + 8 > len(buf):
            raise ValueError("batch item length header runs past end of buffer")
        (n,) = struct.unpack("<Q", buf[off : off + 8])
        off += 8
        if off + n > len(buf):
            raise ValueError("batch item body runs past end of buffer")
        items.append(buf[off : off + n])
        off += n
    return items


def _write_batch(items: list[bytes]) -> bytes:
    """Serialize a list of byte strings into the batch wire format."""
    parts = [struct.pack("<I", len(items))]
    for item in items:
        parts.append(struct.pack("<Q", len(item)))
        parts.append(bytes(item))
    return b"".join(parts)


def _encode_batch(items: list[bytes], args) -> list[bytes]:
    import numpy as np
    from numcodecs import Blosc

    dt = _dtype_for(args.typesize)
    codec = Blosc(
        cname=args.cname,
        clevel=args.clevel,
        shuffle=args.shuffle,
        blocksize=args.blocksize,
    )
    out = []
    for raw in items:
        if len(raw) % dt.itemsize != 0:
            raise ValueError(
                f"input length {len(raw)} is not a multiple of typesize {dt.itemsize}"
            )
        buf = np.frombuffer(raw, dtype=dt)
        out.append(bytes(codec.encode(buf)))
    return out


def _decode_batch(items: list[bytes]) -> list[bytes]:
    from numcodecs import Blosc

    codec = Blosc()
    return [bytes(codec.decode(item)) for item in items]


def cmd_encode(args) -> None:
    raw = _read_stdin_bytes()
    out = _encode_batch([raw], args)
    _write_stdout_bytes(out[0])


def cmd_decode(args) -> None:
    _ = args
    container = _read_stdin_bytes()
    out = _decode_batch([container])
    _write_stdout_bytes(out[0])


def cmd_encode_batch(args) -> None:
    body = _read_stdin_bytes()
    items = _read_batch(body)
    out_items = _encode_batch(items, args)
    _write_stdout_bytes(_write_batch(out_items))


def cmd_decode_batch(args) -> None:
    _ = args
    body = _read_stdin_bytes()
    items = _read_batch(body)
    out_items = _decode_batch(items)
    _write_stdout_bytes(_write_batch(out_items))


class _EncodeArgs:
    """Shim so _encode_batch can reuse cmd_encode's arg names when
    called from the persistent server, whose per-request options
    arrive in a fixed-format header rather than argparse."""

    def __init__(self, cname: str, clevel: int, shuffle: int, typesize: int, blocksize: int) -> None:
        self.cname = cname
        self.clevel = clevel
        self.shuffle = shuffle
        self.typesize = typesize
        self.blocksize = blocksize


def _parse_server_options(hdr: bytes) -> _EncodeArgs:
    """Server request options come in a 32-byte ASCII slug:
        "cname=NAME,clevel=N,shuffle=S,typesize=T,blocksize=B"
    right-padded with NULs. Kept short and human-readable so a
    hex dump of the request stream stays legible."""
    text = hdr.rstrip(b"\x00").decode("ascii")
    kw = {}
    for part in text.split(","):
        if not part:
            continue
        k, _, v = part.partition("=")
        kw[k] = v
    return _EncodeArgs(
        cname=kw.get("cname", "zstd"),
        clevel=int(kw.get("clevel", "5")),
        shuffle=int(kw.get("shuffle", "1")),
        typesize=int(kw.get("typesize", "1")),
        blocksize=int(kw.get("blocksize", "0")),
    )


def cmd_server(args) -> None:
    """Persistent request loop.

    Kept simple: single-threaded, one request at a time, hard-fail
    on protocol error (the caller respawns). Every read from stdin
    is a fixed number of bytes so a truncation is detected as EOF
    rather than misparsed as data.
    """
    _ = args
    inp = sys.stdin.buffer
    out = sys.stdout.buffer

    def _read_exact(n: int) -> bytes:
        buf = bytearray()
        while len(buf) < n:
            chunk = inp.read(n - len(buf))
            if not chunk:
                return bytes(buf)
            buf.extend(chunk)
        return bytes(buf)

    def _respond(ok: bool, payload: bytes) -> None:
        out.write(b"OK  " if ok else b"ERR ")
        out.write(struct.pack("<Q", len(payload)))
        out.write(payload)
        out.flush()

    while True:
        header = _read_exact(4 + 32 + 8)
        if len(header) < 4 + 32 + 8:
            return
        op = header[:4]
        opt_hdr = header[4:36]
        (n,) = struct.unpack("<Q", header[36:44])
        payload = _read_exact(n) if n else b""
        if len(payload) < n:
            return

        try:
            if op == b"ENCB":
                enc_args = _parse_server_options(opt_hdr)
                items = _read_batch(payload)
                out_items = _encode_batch(items, enc_args)
                _respond(True, _write_batch(out_items))
            elif op == b"DECB":
                items = _read_batch(payload)
                out_items = _decode_batch(items)
                _respond(True, _write_batch(out_items))
            elif op == b"QUIT":
                _respond(True, b"")
                return
            else:
                _respond(False, f"unknown op: {op!r}".encode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - report and continue
            _respond(False, f"{type(exc).__name__}: {exc}".encode("utf-8"))


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


def _add_encode_options(p: argparse.ArgumentParser) -> None:
    p.add_argument("--cname", default="zstd")
    p.add_argument("--clevel", type=int, default=5)
    p.add_argument("--shuffle", type=int, choices=(0, 1, 2), default=1)
    p.add_argument("--typesize", type=int, required=True)
    p.add_argument("--blocksize", type=int, default=0)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="blosc_tool")
    sub = parser.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("encode")
    _add_encode_options(e)
    e.set_defaults(func=cmd_encode)

    d = sub.add_parser("decode")
    d.set_defaults(func=cmd_decode)

    eb = sub.add_parser("encode_batch")
    _add_encode_options(eb)
    eb.set_defaults(func=cmd_encode_batch)

    db = sub.add_parser("decode_batch")
    db.set_defaults(func=cmd_decode_batch)

    srv = sub.add_parser("server")
    srv.set_defaults(func=cmd_server)

    v = sub.add_parser("version")
    v.set_defaults(func=cmd_version)

    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
