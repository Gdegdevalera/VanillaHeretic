import 'package:flutter/widgets.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class Authoriztion extends StatefulWidget {
  _AuthoriztionState createState() => _AuthoriztionState();
}

class _AuthoriztionState extends State<Authoriztion> {

  var authUrl = "https://oauth.vk.com/authorize?client_id=7495305&display=page&" +
      "redirect_uri=https://oauth.vk.com/blank.html&scope=wall&response_type=token&v=5.92";

  final flutterWebviewPlugin = new FlutterWebviewPlugin();

  @override
  void initState() {  
    super.initState();

    flutterWebviewPlugin.onUrlChanged.listen((url) {
      var extractor = RegExp('#access_token=(.*?)&');
      if (extractor.hasMatch(url)) {
        final token = extractor.allMatches(url).single.group(1);
        Navigator.of(context).pop(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {    
    return WebviewScaffold(url: authUrl);
  }
}