import 'package:VanillaHeretic/authorization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'models.dart';
import 'vkApi.dart';

void main() {
    
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark 
  ));

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ванильный Еретик',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
  with SingleTickerProviderStateMixin {

  final minScale = 0.5;
  final maxScale = 1.5;
  final double avatarSize = 32;

  final _scroller = ScrollController();
  AnimationController _animationController;
  TextEditingController _replyController = TextEditingController();
  int _updateFactor = 0;

  String _vkToken;
  String _avatarUrl;

  Future<List<Post>> _texts;
  bool _loading = false;
  bool _commentsLoading = false;
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

  Future<String> getToken() async {
    final token = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Authoriztion())
    );
    return token;
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
      _vkToken = prefs.getString('vkToken');
    });

    loadProfile();

    final skipOnboarding = prefs.getBool('skipOnboarding') ?? false;  
    if (!skipOnboarding) {
      await _showOnboarding();
      await prefs.setBool('skipOnboarding', true);
    }
  }

  savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('scale', _scale);
    prefs.setString('vkToken', _vkToken);
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
      return VkApi.fetch(_totalIndex, (v) { _totalIndex += v; }).then((newTexts) {
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

  Future<void> loadMoreComments(Post post) async {
    setState(() {
      post.hasMoreComments = false;
      _commentsLoading = true;
    });

    final replies = await VkApi.loadComments(post);

    setState(() {
      post.replies = replies;
      _commentsLoading = false;
    }); 
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
    return Scaffold(
        body: SafeArea(
          child: Center(
            child: FutureBuilder<List<Post>>(
                future: _texts,
                builder: (context, snapshot) {
                  if ((!_loading || _viewIndex != 0) && snapshot.hasData) {
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
                          _replyController.clear();
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
                              if (_factor < -0.0001) Transform(
                                transform: Matrix4.identity()
                                  ..translate((_factor + 1) * MediaQuery.of(context).size.width)
                                  ..setEntry(3, 2, -0.001)
                                  ..rotateY(math.pi / 8 + math.pi / 2 * _factor / 4),
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  child: getContent(snapshot.data, _viewIndex + 1, screenSize)
                                  )
                              ),
                              if (_factor > 0.0001) Transform(
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
                      );
                  } else if (snapshot.hasError) {
                    return Text("${snapshot.error}");
                  }

                  // By default, show a loading spinner.
                  return CircularProgressIndicator();
                }),
          ),
        ),
        floatingActionButton: MediaQuery.of(context).viewInsets.bottom != 0 
          ? null 
          : FloatingActionButton(
              onPressed: refresh,
              tooltip: 'Refresh',
              child: Icon(Icons.refresh),
            )
      );
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
                    padding: const EdgeInsets.all(30),
                    child: Image.asset(
                      'images/suggestion_swipe.png',
                      height: 70,
                    )),
                Text("Текст можно растягивать",
                    style: TextStyle(fontSize: fontSize)),
                Padding(
                    padding: const EdgeInsets.all(30),
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
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 300),
        child: Column(
          children: <Widget>[
            Text('Опубликовано: ${post.date}\n', style: textStyle),
            Text(post.content
            
            .substring(0,100)
            , style: textStyle, textAlign: TextAlign.justify),
            if (post.id != null) Container(
              padding: const EdgeInsets.all(20),
              child: RaisedButton(
                child: Text('Открыть пост VK'), 
                color: Colors.lightBlue,
                textColor: Colors.white,
                onPressed: () => gotoPost(post)),
            ),
            if(post.replies.length > 0) 
              ...getWidgetReplies(post),
            if(_commentsLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              padding: const EdgeInsets.all(5.0),
              child: Row(
              children: <Widget>[
                if(_avatarUrl != null) 
                  getAvatarWidget(_avatarUrl),
                Flexible(
                  child: TextField(
                      controller: _replyController,
                      onSubmitted: (s) => replyTo(post, _replyController.text),
                      onTap: () => ensureUserLoggedIn(),
                      style: TextStyle(fontSize: 16 * _scale),
                      decoration: InputDecoration(
                        hintText: 'Комментировать...',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send, color: Colors.lightBlue),
                          onPressed: () => replyTo(post, _replyController.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if(post.hasMoreComments)
              FlatButton(
                onPressed: () {
                  loadMoreComments(post);
                },
                child: Text('Еще комментарии...', 
                  style: TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 16 * _scale)
                  )
              )
          ],
        ),
      );
    }
  
    Iterable<Widget> getWidgetReplies(Post post) 
    {
      return post.replies.map((reply) 
        => Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InkWell(
                onTap: () => gotoAuthor(reply),
                child: getAvatarWidget(reply.img),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InkWell(
                      onTap: () => gotoAuthor(reply),
                      child: Text(reply.name ?? '', 
                        style: TextStyle(color: Colors.blue, fontSize: 16 * _scale)
                      ),
                    ),
                    Text(reply.date ?? '',
                      style: TextStyle(color: Colors.grey, fontSize: 16 * _scale)
                    ),
                    Text(reply.content ?? '', 
                      style: TextStyle(fontSize: 16 * _scale)
                    ),
                  ],
                )
              ),
            ],
          )
          )
        );
    }

    Container getAvatarWidget(String url) {
      return Container(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize),
                  child: CachedNetworkImage(
                    width: avatarSize,
                    height: avatarSize,
                    placeholder: (context, url) => Container(
                      width: avatarSize,
                      height: avatarSize,
                      child: CircularProgressIndicator()),
                    imageUrl: url,
                  ),
                ),
              );
    }

    void gotoPost(Post post) async {
      var url = "https://vk.com/wall${VkApi.ownerId}_${post.id}";
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }

    void gotoAuthor(Reply reply) async {
      var url = "https://vk.com${reply.authorUrl}";
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }

    void ensureUserLoggedIn() async {
      if (_vkToken != null)
        return;
      
     final token = await showDialog<String>(
        context: context,
        builder: (c) =>  Authoriztion()
      );

      _vkToken = token;
      loadProfile();
      savePreferences();
    }

    void loadProfile() async {
      if(_vkToken == null)
        return;

      final avatarUrl = await VkApi.getUserAvatarUrl(_vkToken);
      if(avatarUrl != null)
      {
        setState(() {
          _avatarUrl = avatarUrl;
        });
      } else {
        setState(() { _vkToken = null; });
      }
    }

    void replyTo(Post post, String message) async {
      if(_vkToken == null)
        return;

      var success = await VkApi.replyTo(post, message, _vkToken);
      if(success) {
        _replyController.clear();
        loadMoreComments(post);
      } else {
        final snackBar = SnackBar(content: Text('Ошибка'));
        Scaffold.of(context).showSnackBar(snackBar);
      }
    }
}