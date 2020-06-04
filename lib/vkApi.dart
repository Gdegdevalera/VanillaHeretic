import 'package:http/http.dart' as http;
import 'dart:convert' show json;
import 'models.dart';
import 'package:intl/intl.dart';

class VkApi {

  static const baseUrl = 'https://api.vk.com/method';
  static const v = 'v=5.92';
  static const serviceToken = 'access_token=f84f0ca0f84f0ca0f84f0ca0eff83d5229ff84ff84f0ca0a6994f097f9d0eaf132ebce1';
  static const ownerId = '-61574859'; // vk public id
  static const minTextLength = 1000;

  static final dateFormat = DateFormat.MMMd().add_Hm();

  static Future<List<Post>> fetch(int startFrom, void Function(int) setTotal) async {
    try {
      final response = await http.get('$baseUrl/wall.get?owner_id=$ownerId&offset=$startFrom&count=10&$serviceToken&$v');

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
          
        List<Post> allPosts = jsonResponse['response']['items']
          .where((x) => x['post_type'] == 'post')
          .map<Post>((x) => Post()
            ..id = x['id'].toString()
            ..date = dateFormat.format(DateTime.fromMillisecondsSinceEpoch(x['date'] * 1000))
            ..content = x['text']
            ..repliesCount = x['comments']['count']
          )
          .toList();

        setTotal(allPosts.length);
        var posts = allPosts
            .where((post) => (post.content?.length ?? 0) > minTextLength)
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

  static Future<List<Reply>> loadComments(Post post) async {
    try {
      final response = await http.get('$baseUrl/wall.getComments?'
        +'owner_id=$ownerId&post_id=${post.id}&sort=desc&$serviceToken&$v'
        +'&extended=1&lang=ru&thread_items_count=10');

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        Map<int, Profile> profiles = Map.fromIterable(
            jsonResponse['response']['profiles']
            .map<Profile>((x) => Profile()
              ..id = x['id']
              ..name = '${x["first_name"]} ${x["last_name"]}'
              ..img = x['photo_50']
              ..url = x['screen_name']
            ), 
            key: (x) => x.id, 
            value: (x) => x);

        List<Reply> replies = jsonResponse['response']['items']
          .where((x) => x['deleted'] == null)
          .map<Reply>((x) => Reply()
            ..id = x['id'].toString()
            ..date = dateFormat.format(DateTime.fromMillisecondsSinceEpoch(x['date'] * 1000))
            ..content = x['text']
            ..profile = profiles[x['from_id']]
            ..threadCount = x['thread']['count']
            ..thread = x['thread']['items']
              .where((y) => y['deleted'] == null)
              .map<Reply>((y) => Reply()
              ..id = y['id'].toString()
              ..date = dateFormat.format(DateTime.fromMillisecondsSinceEpoch(y['date'] * 1000))
              ..content = _clearMessage(y['text'])
              ..profile = profiles[y['from_id']]
              )
              .where((y) => !y.content.isEmpty)
              .toList()
          )
          .where((x) => !x.content.isEmpty)
          .toList();
        
        return replies;
      }
    } 
    catch(e) {
      print(e);
    }

    return null;
  }

  static Future<String> getUserAvatarUrl(String token) async {
    if (token == null)
      return null;

    try {
      final response = await http.get(baseUrl
        + '/users.get?fields=photo_50&access_token=$token&v=5.92');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final avatarUrl = jsonResponse['response'][0]['photo_50'].toString();

        return avatarUrl;
      } 
    }
    catch(e) {
      print(e);
    }
    
    return null;
  }

  static Future<bool> replyTo(Post post, String replyToComment, String message, String token) async {
    try {
      final response = await http.post('https://api.vk.com/method/'
        + 'wall.createComment?access_token=$token&v=5.92', body: {
          'post_id': post.id,
          'owner_id': ownerId,
          'message': message,
          if (replyToComment != null) 'reply_to_comment': replyToComment
        });

      if (response.statusCode == 200) {
        return true;
      }
    }
    catch(e) {
      print(e);
    }

    return false;
  }
  
  static String _clearMessage(String message) {
    if(message == null) return null;

    var targetPerson = RegExp(r'^\[.*\|(.*)\]');

    return message
      .replaceAllMapped(targetPerson, (match) => match.group(1));
  }
}