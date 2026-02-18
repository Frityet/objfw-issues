#!/usr/bin/env python3
import socket
import sys

ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
ls.bind(("127.0.0.1", 0))
ls.listen(1)
print(ls.getsockname()[1], flush=True)

conn, _ = ls.accept()
conn.settimeout(5)

hdr = conn.recv(2)
if len(hdr) != 2:
    print("ERR greeting header", file=sys.stderr)
    sys.exit(2)
ver, nmethods = hdr
methods = conn.recv(nmethods)
conn.sendall(b"\x05\x00")

req = conn.recv(4)
if len(req) != 4:
    print("ERR request header", file=sys.stderr)
    sys.exit(3)
ver2, cmd, _, atyp = req
host_len = None
host = b""

if atyp == 0x03:
    b = conn.recv(1)
    if len(b) != 1:
        print("ERR domain len", file=sys.stderr)
        sys.exit(4)
    host_len = b[0]
    host = conn.recv(host_len)
    _ = conn.recv(2)
else:
    print(f"ERR atyp={atyp}", file=sys.stderr)
    sys.exit(5)

conn.sendall(b"\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00")
print(f"GREETING ver={ver} nmethods={nmethods} methods={methods.hex()}")
print(
    f"REQUEST ver={ver2} cmd={cmd} atyp={atyp} "
    f"host_len={host_len} host_recv_bytes={len(host)}"
)

conn.close()
ls.close()
