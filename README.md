# Float Lyric

## Build

### macOS

```bash
cd macos &&
xcrun swiftc \
  -target arm64-apple-macosx12.0 \
  -emit-library \
  -o libFloatLyric.dylib \
  main.swift
```

### Windows

```bash
go build -buildmode=c-shared -ldflags="-s -w" -o build/libFloatLyric.dll
```