# Float Lyric

This is the Desktop Lyric Kit submodule for [netPlayer Next](https://github.com/Zhoucheng133/netPlayer-Next)

## Build

### macOS

```bash
# [For Test] Move to: flutter_test/macos/libFloatLyric.dylib
cd macos &&
xcrun swiftc \
  -target arm64-apple-macosx12.0 \
  -emit-library \
  -o libFloatLyric.dylib \
  main.swift
```

### Windows

```bash
# [For Test] Move to: flutter_test/windows/libFloatLyric.dll
go build -buildmode=c-shared -ldflags="-s -w" -o build/libFloatLyric.dll
```