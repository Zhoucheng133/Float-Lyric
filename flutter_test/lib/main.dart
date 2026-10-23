import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {

  final TextEditingController lyric = TextEditingController(text: "歌词内容");
  final TextEditingController fontsize = TextEditingController(text: "12");
  double opacity=1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: .min,
            spacing: 10,
            children: [
              Row(
                mainAxisSize: .min,
                spacing: 10,
                children: [
                  FilledButton(
                    onPressed: (){}, 
                    child: Text("显示歌词")
                  ),
                  FilledButton(
                    onPressed: (){}, 
                    child: Text("隐藏歌词")
                  )
                ],
              ),
              Padding(
                padding: .only(left: 20, right: 20),
                child: TextField(
                  controller: lyric,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                onPressed: (){}, 
                child: Text("更新歌词")
              ),
              Padding(
                padding: .only(left: 20, right: 20),
                child: Slider(
                  value: opacity, 
                  onChanged: (val){
                    setState(() {
                      opacity=val;
                    });
                  }
                ),
              ),
              TextButton(
                onPressed: (){}, 
                child: Text("更新透明度")
              ),
              Padding(
                padding: .only(left: 20, right: 20),
                child: TextField(
                  controller: fontsize,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                onPressed: (){}, 
                child: Text("更新字体")
              ),
            ],
          )
        ),
      ),
    );
  }
}
