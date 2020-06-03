import 'package:html/dom.dart';

class Reply {
  String img;
  String name;
  String content;
  String date;
  String authorUrl;
}

class Post {
  String id;
  String date;
  String content;
  String likesCount;
  List<Reply> replies;
  bool hasMoreComments;
  
  Element html;
  List<Element> repliesHtml;
}