import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as DOM;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert' show json;
import 'decoder.dart' show decodeCp1251;

void main() {
  runApp(MyApp());
}

class Post {
  String date;
  String content;
  DOM.Element html;
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ванильный еретик',
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

class _MyHomePageState extends State<MyHomePage>
  with SingleTickerProviderStateMixin {

  final minScale = 0.5;
  final maxScale = 1.5;
  final _scroller = ScrollController();
  AnimationController _animationController;

  Future<List<Post>> _texts;
  int _viewIndex = 0;
  int _totalIndex = 0;
  double _scale = 1.0;
  double _previousScale;
  Offset _offset = Offset.zero;
  Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _texts = fetchTexts();

    _animationController = AnimationController(vsync: this);
    _animationController.addListener(() {
      setState(() {
        _offset = _animation.value;
      });
    });

    _loadPreferences();
  }

  @override
  void dispose() {
    _savePreferences();
    super.dispose();
  }

  _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scale = prefs.getDouble('scale') ?? 1.0;
    });

    final skipOnboarding = prefs.getBool('skipOnboarding') ?? false;  
    if (!skipOnboarding) {
      await _showOnboarding();
      await prefs.setBool('skipOnboarding', true);
    }
  }

  _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('scale', _scale);
  }

  _runAnimation() {
    _animation = _animationController.drive(
      Tween(
        begin: _offset,
        end: Offset.zero
      )
    );
    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1
    );
    
    var simulation = SpringSimulation(spring, 0, 1, 0.1);
    _animationController.animateWith(simulation);
  }

  Future<List<Post>> fetchTexts({Future<List<Post>> prevFuture}) async {
    if (prevFuture == null) prevFuture = Future.value([]);

    return prevFuture.then((oldTexts) {
      return fetch(_totalIndex).then((newTexts) =>
          oldTexts +
          newTexts
              .where((y) => oldTexts.every((x) =>
                  x.content.substring(0, 10) != y.content.substring(0, 10)))
              .toList());
    });
  }

  Future<List<Post>> fetch(int startFrom) async {
    final response = await http.post('https://vk.com/al_wall.php', body: {
      'act': 'get_wall',
      'owner_id': '-61574859',
      'wall_start_from': startFrom.toString(),
      'al': '1'
    });
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body.substring(4));
      var payload = jsonResponse['payload'][1][0].toString();
      var document = parse(decodeCp1251(payload));

      var allPosts = document.querySelectorAll('._post_content');
      _totalIndex += allPosts.length;
      var posts = allPosts
          .map((post) {
            return Post()
              ..date = post.querySelector('.rel_date')?.innerHtml
              ..html = post.querySelector('.wall_post_text');
          })
          .where((post) => (post.html?.innerHtml?.length ?? 0) > 300)
          .map((post) {
            post.html.querySelectorAll('a').forEach((element) {
              element.remove();
            });
            post.content =
                removeAllHtmlTags(post.html.innerHtml.replaceAll('<br>', '\n'));
            return post;
          })
          .toList();
      return posts;
    } else {
      return null;
    }
  }

  String removeAllHtmlTags(String htmlText) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);

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
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: FutureBuilder<List<Post>>(
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
                          if (newScale >= minScale && newScale <= maxScale) {
                            _scale = newScale;
                          }
                          if (newScale < minScale) _scale = minScale;
                          if (newScale > maxScale) _scale = maxScale;
                        });
                      },
                      onScaleEnd: (ScaleEndDetails details) {
                        _previousScale = null;
                        _savePreferences();
                      },
                      onHorizontalDragUpdate: (details) {
                        _animationController.stop();
                        setState(() {
                          _offset += details.delta;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() {
                          var screenWidth = MediaQuery.of(context).size.width;
                          if (_offset.dx.abs() > screenWidth / 3) {
                            if (_offset.dx > 0 
                              && _viewIndex > 0) {
                                _offset = _offset.translate(-screenWidth, 0);
                                _viewIndex--;
                            } 
                            else if (_offset.dx < 0 
                              && _viewIndex < snapshot.data.length - 1) {
                                _offset = _offset.translate(screenWidth, 0);
                                _viewIndex++;
                            }
                            _scroller.jumpTo(0);
                          }
                        });
                        _runAnimation();

                        if (_viewIndex > snapshot.data.length - 3) {
                          _texts = fetchTexts(prevFuture: _texts);
                        }
                      },
                      child: Stack(children: [
                        Transform.translate(
                          offset: _offset,
                          child: SingleChildScrollView(
                              controller: _scroller,
                              child: getContent(snapshot.data, _viewIndex)),
                        ),
                        Transform.translate(
                            offset: Offset(
                                _offset.dx + MediaQuery.of(context).size.width,
                                0),
                            child: getContent(snapshot.data, _viewIndex + 1)),
                        Transform.translate(
                            offset: Offset(
                                _offset.dx - MediaQuery.of(context).size.width,
                                0),
                            child: getContent(snapshot.data, _viewIndex - 1)),
                        //createSuggestionWidget()
                      ]));
                } else if (snapshot.hasError) {
                  return Text("${snapshot.error}");
                }

                // By default, show a loading spinner.
                return CircularProgressIndicator();
              }),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _refresh,
          tooltip: 'Refresh',
          child: Icon(Icons.refresh),
        ));
  }

  Future<void> _showOnboarding() async {
    final double fontSize = 15;
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text("Свайпай чтобы листать", style: TextStyle(fontSize: fontSize)),
                Padding(
                    padding: EdgeInsets.all(30),
                    child: Image.asset(
                      'images/suggestion_swipe.png',
                      height: 70,
                    )),
                Text("Текст можно растягивать",
                    style: TextStyle(fontSize: fontSize)),
                Padding(
                    padding: EdgeInsets.all(30),
                    child: Image.asset(
                      'images/suggestion_pinch.png',
                      height: 70,
                    )),
                RaisedButton(
                    color: Colors.lightBlue,
                    textColor: Colors.white,
                    child: Text('Понятно', style: TextStyle(fontSize: fontSize)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              ),
            )
          );
        },
    );
  }

  Widget getContent(List<Post> data, int index) {
    if (index < 0 || index >= data.length) return null;

    return ConstrainedBox(
      constraints:
          BoxConstraints(minHeight: MediaQuery.of(context).size.height),
      child: Container(
          //color: Colors.white,
          child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 20),
        child: Text(
            'Опубликовано: ' + data[index].date + '\n\n' + data[index].content,
            style: GoogleFonts.openSans(fontSize: 16 * _scale)),
      )),
    );
  }
}
