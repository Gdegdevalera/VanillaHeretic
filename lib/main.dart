import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as DOM;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert' show json;
import 'decoder.dart' show decodeCp1251;
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class Reply {
  String img;
  String name;
  String content;
}

class Post {
  String id;
  String date;
  String content;
  String likesCount;
  List<Reply> replies;
  
  DOM.Element html;
  List<DOM.Element> repliesHtml;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ванильный еретик',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Ванильный еретик'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
  with SingleTickerProviderStateMixin {

  final minTextLength = 1000;
  final minScale = 0.5;
  final maxScale = 1.5;
  final _scroller = ScrollController();
  AnimationController _animationController;
  int _updateFactor = 0;

  Future<List<Post>> _texts;
  bool _loading = false;
  int _viewIndex = 0;
  int _totalIndex = 0;
  double _scale = 1.0;
  double _previousScale;
  double _factor = 0.0;
  Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _texts = fetchTexts();

    _animationController = AnimationController(vsync: this);
    _animationController.addListener(() {
      setState(() {
        _factor = _animation.value;
      });
    });

    loadPreferences();
  }

  @override
  void dispose() {
    savePreferences();
    super.dispose();
  }

  loadPreferences() async {
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

  savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('scale', _scale);
  }

  runAnimation() {
    _animation = _animationController.drive(
      Tween(
        begin: _factor,
        end: 0.0
      )
    );
    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1
    );
    
    var simulation = SpringSimulation(spring, 0, 1, 0.001);

    _animationController.animateWith(simulation);
  }

  Future<List<Post>> fetchTexts({Future<List<Post>> prevFuture}) async {
    _loading = true;
    if (prevFuture == null) prevFuture = Future.value([]);

    return prevFuture.then((oldTexts) {
      return fetch(_totalIndex).then((newTexts) {
        _loading = false;
        return oldTexts +
          newTexts
              .where((y) => oldTexts.every((x) =>
                  x.content.substring(0, 10) != y.content.substring(0, 10)))
              .toList();
      }, onError: (error) {
        _loading = false;
        if(oldTexts.length > 0) return oldTexts;
        throw error;
      });
    });
  }

  Future<List<Post>> fetch(int startFrom) async {
    try {
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
            .map((post) => Post()
                ..id = post.querySelector('.post_img').map((x) => x.attributes['data-post-id'])
                ..date = post.querySelector('.rel_date')?.innerHtml
                ..likesCount = post.querySelector('.like_button_count')?.innerHtml
                ..html = post.querySelector('.wall_post_text')
                ..repliesHtml = post.querySelectorAll('.replies')
            )
            .where((post) => (post.html?.innerHtml?.length ?? 0) > minTextLength)
            .map((post) {
              post.html.querySelectorAll('a').forEach((element) {
                element.remove();
              });
              post.content =
                  removeAllHtmlTags(post.html.innerHtml.replaceAll('<br>', '\n'));
                  //.substring(0, 100);
              post.replies = post.repliesHtml
                .where((reply) => reply.querySelector('img') != null)
                .map((reply) => Reply()
                  ..img = reply.querySelector('.reply_img')?.attributes['src']
                  ..name = reply.querySelector('.author')?.innerHtml
                  ..content = reply.querySelector('.wall_reply_text')?.innerHtml
                )
                .toList();
              return post;
            })
            .toList();
        return posts;
      } else {
        return new List<Post>();
      }
    }
    catch(e) {
      throw Exception("Ошибка. Проверьте соединение с Интернет");
    }
  }

  String removeAllHtmlTags(String htmlText) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);

    return htmlText.replaceAll(exp, '');
  }

  void refresh() {
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
        //appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: Center(
            child: FutureBuilder<List<Post>>(
                future: _texts,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    var screenSize = MediaQuery.of(context).size;
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
                          savePreferences();
                        },
                        onHorizontalDragUpdate: (details) {
                          _animationController.stop();
                          _updateFactor++;
                          var screenWidth = screenSize.width;
                          _factor += details.delta.dx / screenWidth;

                          if(_updateFactor == 1)
                          {
                            setState(() { });
                          }

                          if(_updateFactor >= 5)
                            _updateFactor = 0;
                        },
                        onHorizontalDragEnd: (details) {
                          setState(() {
                            if (_factor.abs() > 0.1) {
                              if (_factor > 0 
                                && _viewIndex > 0) {
                                  _factor -= 1;
                                  _viewIndex--;
                              } 
                              else if (_factor < 0 
                                && _viewIndex < snapshot.data.length - 1) {
                                  _factor += 1;
                                  _viewIndex++;
                              }
                              _scroller.jumpTo(0);
                            }
                          });
                          runAnimation();

                          if (!_loading && _viewIndex > snapshot.data.length - 3) {
                            _texts = fetchTexts(prevFuture: _texts);
                          }
                        },
                        child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform(
                                transform: Matrix4.identity()
                                  ..translate(_factor * screenSize.width)
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(0 - math.pi / 2 * _factor / 4)
                                  ,
                                alignment: _factor >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                                child: SingleChildScrollView(
                                    controller: _scroller,
                                    child: getContent(snapshot.data, _viewIndex, screenSize)),
                              ),
                              Transform(
                                transform: Matrix4.identity()
                                  ..translate((_factor + 1) * MediaQuery.of(context).size.width)
                                  ..setEntry(3, 2, -0.001)
                                  ..rotateY(math.pi / 8 + math.pi / 2 * _factor / 4),
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  child: getContent(snapshot.data, _viewIndex + 1, screenSize)
                                  )
                              ),
                              Transform(
                                transform: Matrix4.identity()
                                  ..translate((_factor - 1)* MediaQuery.of(context).size.width)
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(math.pi / 8 - math.pi / 2 * _factor / 4),
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  child: getContent(snapshot.data, _viewIndex - 1, screenSize)
                                  )
                              ),
                            ]
                        )
                        // child: Stack(children: [
                        //   Transform.translate(
                        //     offset: Offset(_factor, 0),
                        //     child: SingleChildScrollView(
                        //         controller: _scroller,
                        //         child: getContent(snapshot.data, _viewIndex)),
                        //   ),
                        //   Transform.translate(
                        //       offset: Offset(
                        //           _factor + MediaQuery.of(context).size.width,
                        //           0),
                        //       child: getContent(snapshot.data, _viewIndex + 1)),
                        //   Transform.translate(
                        //       offset: Offset(
                        //           _factor - MediaQuery.of(context).size.width,
                        //           0),
                        //       child: getContent(snapshot.data, _viewIndex - 1)),
                        //   //createSuggestionWidget()
                        // ])
                        );
                  } else if (snapshot.hasError) {
                    return Text("${snapshot.error}");
                  }

                  // By default, show a loading spinner.
                  return CircularProgressIndicator();
                }),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: refresh,
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

  Widget getContent(List<Post> data, int index, Size screenSize) {
    if (index < 0 || index >= data.length) return null;

    var textStyle = GoogleFonts.openSans(fontSize: 16 * _scale);
    var post = data[index];
    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 20),
        child: Column(
          children: <Widget>[
            Text('Опубликовано: ${post.date}\n', style: textStyle),
            Text(post.content, style: textStyle, textAlign: TextAlign.justify,),
            if (post.id != null) RaisedButton(
              child: Text('Открыть пост VK'), 
              color: Colors.lightBlue,
              textColor: Colors.white,
              onPressed: () async {
                var url = "https://vk.com/wall${post.id}";
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              },)
            // Row(children: <Widget>[
            //   Icon(Icons.thumb_up),
            //   Text(post.likesCount)
            // ]),
            // ListView(children:
            //   post.replies.map((reply) =>
            //     ListTile(
            //      // leading: Image.network(reply.img),
            //       leading: Icon(Icons.reorder),
            //       title: Text(reply.name)
            //     )
            //   ).toList()
            // )
          ],
        ),
      );
  }
}

extension Func on Object {
  K map<T, K>(K Function(T) mapper) {
    return this == null ? null : mapper(this);
  }
}