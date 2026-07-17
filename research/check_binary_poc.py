"""Binary inspector: extract __const from static_auth.cpp.o in the arm64 AR slice
and compare against PoC constants."""
import struct, hashlib, sys

LIB = r"D:\Copy\ocr studio\OCRStudioSDK-1.3.1-iOS-Trial\OCRStudioSDKCore\lib\ocrstudiosdk.xcframework\ios-arm64_armv7_armv7s\libocrstudiosdk-ios.a"

POC_N_HEX = (
    "aa81d3f7eb1996c8ffd6d119451d60554d1d2924d2a6fd8e035dff9fcf29b3d5"
    "9046835374fab7dfa823c02c4f553ebe21e34277aa12c1cbf1df3e18d6e1eea6"
    "76f1628520b80db807e8b1a911c19797b7cd4c3c66eab2dab0daaafbe765c372"
    "b62d0825b8e2023a1fd2e88a22df338fa2e267a67bbf89613ac1d836cea1bf39"
)
POC_E_HEX = "00000003"
POC_CLIENT = b"ocrstudio_arafatgroup_trial"
POC_HASH_HEX = "25159e611dfa6f5f077a732a01d17ead8cc9770b"

with open(LIB, "rb") as fp:
    magic = fp.read(8)
    if magic != b"!<arch>\n":
        print("not an ar archive"); sys.exit(2)
    found = None
    pos = 8
    fp.seek(0, 2)
    sz = fp.tell()
    fp.seek(8)
    while pos < sz:
        fp.seek(pos)
        hdr = fp.read(60)
        if len(hdr) < 60:
            break
        name_field = hdr[0:16]
        try:
            size_field = int(hdr[48:58].rstrip(b" ") or b"0")
        except ValueError:
            break
        if name_field.startswith(b"#1/"):
            name_len = int(name_field[3:].rstrip(b" "))
            name_bytes = fp.read(name_len)
            name = name_bytes.split(b"\x00", 1)[0].decode("latin-1", "replace")
        else:
            name_len = 0
            name = name_field.split(b"/", 1)[0].rstrip(b" ").decode("latin-1", "replace")
        data_off = fp.tell()
        if "static_auth.cpp.o" in name and 0 < size_field < 200_000:
            fp.seek(data_off)
            peek = fp.read(4)
            if peek == b"\xcf\xfa\xed\xfe":
                fp.seek(data_off)
                full = fp.read(size_field - name_len)
                found = full
                print(f"FOUND {name!r} size={len(full)} arm64-MachO")
                break
        pos = data_off + size_field - name_len
        if pos & 1:
            pos += 1

if not found:
    print("static_auth.cpp.o arm64 slice not found"); sys.exit(3)

blob = found
mhash, mhcpu, mhsub, ftype, ncmds, szcmds, flags = struct.unpack_from("<IIIIIII", blob, 0)
print(f"Mach-O: magic=0x{mhash:08X} ncmds={ncmds}")
off = 32
text_sec_data = const_sec_data = None
for i in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", blob, off)
    if cmd == 0x19:  # LC_SEGMENT_64
        nsects = struct.unpack_from("<I", blob, off + 64)[0]
        sec_off = off + 72
        for s in range(nsects):
            secname = blob[sec_off:sec_off + 16].split(b"\x00", 1)[0].decode("latin-1", "replace")
            sect_segn = blob[sec_off + 16:sec_off + 32].split(b"\x00", 1)[0].decode("latin-1", "replace")
            addr, size_b, fileoff, align, reloff, nreloc = struct.unpack_from("<QQIIII", blob, sec_off + 32)
            print(f"  {sect_segn},{secname}: vma=0x{addr:x} size={size_b} fileoff={fileoff}")
            data = blob[fileoff:fileoff + size_b]
            if sect_segn == "__TEXT" and secname == "__text":
                text_sec_data = data
            if sect_segn == "__TEXT" and secname == "__const":
                const_sec_data = data
            sec_off += 80
    off += cmdsize

if not const_sec_data:
    print("__const not found"); sys.exit(4)

print(f"\n__const blob ({len(const_sec_data)} bytes)")
n_bin = const_sec_data[0:128]
e_bin = const_sec_data[128:132]
hash_bin = const_sec_data[-20:]
marker_idx = const_sec_data.find(POC_CLIENT)

n_hex = n_bin.hex()
e_hex = e_bin.hex()
hash_hex = hash_bin.hex()
client_sha1 = hashlib.sha1(POC_CLIENT).hexdigest()

print(f"  RSA n      : {n_hex}")
print(f"  RSA e      : {e_hex}")
print(f"  EXPECTED_H : {hash_hex}")
print(f"  marker idx : {'offset ' + str(marker_idx) if marker_idx >= 0 else 'NOT FOUND'}")
print(f"  SHA1(client): {client_sha1}")

print(f"\n=== binary vs PoC cross-check ===")
n_ok  = n_hex == POC_N_HEX
e_ok  = e_hex == POC_E_HEX
h_ok  = hash_hex == POC_HASH_HEX
c_ok  = marker_idx >= 0
s_ok  = client_sha1 == hash_hex
print(f"  n  match : {n_ok}")
print(f"  e  match : {e_ok}")
print(f"  hash match: {h_ok}")
print(f"  client_in : {c_ok}")
print(f"  hash == SHA1(client) : {s_ok}")
if all([n_ok, e_ok, h_ok, c_ok, s_ok]):
    print("\n*** BINARY CROSS-CHECK: ALL MATCH — PoC constants faithfully reflect the shipped library blob ***")
else:
    print("\n*** MISMATCH DETECTED ***")
