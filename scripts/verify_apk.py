import sys
from pathlib import Path


def is_signed(data: bytes) -> bool:
    if b"APK Sig Block 42" in data:
        return True
    has_manifest = b"MANIFEST.MF" in data
    has_v1 = b".RSA" in data or b".DSA" in data or b".EC" in data
    return has_manifest and has_v1


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify_apk.py <apk>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    data = path.read_bytes()
    if data[:2] != b"PK":
        print(f"{path}: not an APK", file=sys.stderr)
        return 1
    if not is_signed(data):
        print(f"{path}: unsigned APK", file=sys.stderr)
        return 1
    print(f"{path}: signed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
