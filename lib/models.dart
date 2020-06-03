import 'package:html/dom.dart';

class Reply {
  String id;
  Profile profile;
  String content;
  String date;
  int threadCount;
  List<Reply> thread;
}

class Profile {
  int id;
  String name;
  String img;
  String url;
}

class Post {
  String id;
  String date;
  String content;
  int repliesCount;
  List<Reply> replies = List<Reply>();
  
  Element html;
  List<Element> repliesHtml;

  // static Post fromJson(json) 
  //   => Post()
  //     ..id = json['id']
  //     ..date = json['date']
  //     ..content = json['text'];

}