import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'components/bridge.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {

  final TextEditingController lyric = TextEditingController(text: "正在播放歌词...");
  final TextEditingController fontsize = TextEditingController(text: "16");
  double opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  FilledButton(
                    onPressed: () {
                      final ptr = lyric.text.toNativeUtf8();
                      final size = int.tryParse(fontsize.text) ?? 16;
                      FFIBridge.showFloatLyric(ptr, opacity * 100, size);
                      calloc.free(ptr);
                    }, 
                    child: const Text("显示歌词")
                  ),
                  FilledButton(
                    onPressed: () {
                      FFIBridge.hideFloatLyric();
                    }, 
                    child: const Text("隐藏歌词")
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: TextField(
                  controller: lyric,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final ptr = lyric.text.toNativeUtf8();
                  FFIBridge.updateLyric(ptr);
                  calloc.free(ptr);
                }, 
                child: const Text("更新歌词")
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Slider(
                  value: opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      opacity = val;
                    });
                    FFIBridge.updateOpacity(opacity * 100);
                  }
                ),
              ),
              const Text("更新透明度"),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: TextField(
                  controller: fontsize,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final size = int.tryParse(fontsize.text) ?? 16;
                  FFIBridge.updateFontSize(size);
                }, 
                child: const Text("更新字体")
              ),
            ],
          )
        ),
      ),
    );
  }
}
