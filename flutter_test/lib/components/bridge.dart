import 'dart:ffi';
import 'package:ffi/ffi.dart';

// 显示悬浮歌词
// [lyric] 歌词
// [opacity] 透明度(double 0~100)
// [int] 字体大小
typedef ShowFloatLyricDart = void Function(Pointer<Utf8> lyric, double opacity, int fontsize);
typedef ShowFloatLyric = Void Function(Pointer<Utf8> lyric, Double opacity, Int fontsize);

// 隐藏悬浮歌词
typedef HideFloatLyricDart = void Function();
typedef HideFloatLyric = Void Function();

// 更新歌词
typedef UpdateLyricDart = void Function(Pointer<Utf8> lyric);
typedef UpdateLyric = Void Function(Pointer<Utf8> lyric);

// 更新透明度
typedef UpdateOpacityDart = void Function(double opacity);
typedef UpdateOpacity = Void Function(Double opacity);

// 更新字体大小
typedef UpdateFontSizeDart = void Function(int fontsize);
typedef UpdateFontSize = Void Function(Int fontsize);

class FFIBridge{
  
}