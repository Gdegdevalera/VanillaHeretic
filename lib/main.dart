import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'dart:convert' show json;
import 'decoder.dart' show decodeCp1251;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Ванильный еретик'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<List<String>> _texts;
  int _viewIndex = 0;
  int _totalIndex = 0;
  double _scale = 1.0;
  double _previousScale;
  Offset _offset = Offset.zero;
  ScrollController _scroller = new ScrollController();

  @override
  void initState() {
    super.initState();
    _texts = fetchTexts();
  }

  Future<List<String>> fetchTexts({Future<List<String>> prevFuture}) async {
    if(prevFuture == null)
      prevFuture = Future.value([]);

    return prevFuture.then((oldTexts) {
      return fetch(_totalIndex)
        .then((newTexts) => oldTexts + 
          newTexts
            .where((y) => oldTexts.every((x) => x.substring(0,10) != y.substring(0, 10)))
            .toList());
    });
  }

  Future<List<String>> fetch(int startFrom) async {
    final response = await http.post(
      'https://vk.com/al_wall.php',
      body: {
        'act': 'get_wall',
        'owner_id': '-61574859',
        'wall_start_from': startFrom.toString(),
        'al': '1'
      });
    if(response.statusCode == 200) {
      var jsonResponse = json.decode(response.body.substring(4));
      var payload = jsonResponse['payload'][1][0].toString();
      var document = parse(decodeCp1251(payload));

      var allPosts = document.querySelectorAll('.wall_post_text');
      _totalIndex += allPosts.length;
      var posts = allPosts
        .where((element) => element.innerHtml.length > 300)
        .map((post) {
          post.querySelectorAll('a').forEach((element) { element.remove(); });
          return removeAllHtmlTags(post.innerHtml.replaceAll('<br>', '\n'));
        })
        .toList();
      return posts;
    } else {
      return [ '[Error!]' ];
    }
  }

  String removeAllHtmlTags(String htmlText) {
    RegExp exp = RegExp(
      r"<[^>]*>",
      multiLine: true,
      caseSensitive: true
    );

    return htmlText.replaceAll(exp, '');
  }

  void _refresh() {
    setState(() {
      _viewIndex = 0;
      _totalIndex = 0;
      _texts = fetchTexts();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title)
      ),
      body: Center(
        child: FutureBuilder<List<String>>(
            future: _texts,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return GestureDetector(
                  onScaleStart: (ScaleStartDetails details) {
                    _previousScale = _scale;
                  },
                  onScaleUpdate: (ScaleUpdateDetails details) {
                    setState(() {
                      var newScale = _previousScale * details.scale;
                      if(newScale >= 0.5 && newScale <= 2.5) { 
                        _scale = newScale;
                      }
                    });
                  },
                  onScaleEnd: (ScaleEndDetails details) {
                    _previousScale = null;
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _offset += details.delta;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      var screenWidth = MediaQuery.of(context).size.width;
                      if(_offset.dx.abs() > screenWidth / 3) {
                        if(_offset.dx > 0 && _viewIndex > 0) {
                          _viewIndex--;
                        }
                        if(_offset.dx < 0 && _viewIndex < snapshot.data.length - 1) {
                          _viewIndex++;
                        }
                        _scroller.jumpTo(0);

                        if(_viewIndex > snapshot.data.length - 3) {
                          _texts = fetchTexts(prevFuture: _texts);
                        }
                      }
                      _offset = Offset.zero;
                    });
                  },
                  child: Stack(
                    children: [ 
                      Transform.translate(
                        offset: _offset,
                        child: SingleChildScrollView(
                          controller: _scroller,
                          child: getContent(snapshot.data, _viewIndex)
                        ),
                      ),
                      Transform.translate(offset: 
                        Offset(_offset.dx + MediaQuery.of(context).size.width, 0),
                        child: getContent(snapshot.data, _viewIndex + 1)
                      ),
                      Transform.translate(offset: 
                        Offset(_offset.dx - MediaQuery.of(context).size.width, 0),
                        child: getContent(snapshot.data, _viewIndex - 1)
                      )
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }

              // By default, show a loading spinner.
              return CircularProgressIndicator();
            }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Increment',
        child: Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget getContent(List<String> data, int index) {
    if(index < 0 || index >= data.length)
      return null;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 20),
          child: Text(data[index], 
            style: GoogleFonts.openSans(fontSize: 16 * _scale)
          ),
        )
      ),
    );
  }
}
