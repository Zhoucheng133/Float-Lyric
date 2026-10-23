# Float Lyric

## Build

### macOS

```bash
cd macos &&
xcrun swiftc \
  -target arm64-apple-macosx13.0 \
  -emit-library \
  -o libFloatLyric.dylib \
  main.swift
```