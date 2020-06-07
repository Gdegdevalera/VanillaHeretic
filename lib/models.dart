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
  bool adv = false;

  String id;
  String date;
  String content;
  int repliesCount;
  List<Reply> replies = List<Reply>();
}