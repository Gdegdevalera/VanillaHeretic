import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show json;
import 'decoder.dart' show decodeCp1251;
import 'models.dart';

class VkApi {

  static const ownerId = '-61574859'; // vk public id
  static const minTextLength = 1000;

  static Future<List<Post>> fetch(int startFrom, void Function(int) setTotal) async {
    try {
      final response = await http.post('https://vk.com/al_wall.php', body: {
        'act': 'get_wall',
        'owner_id': ownerId,
        'wall_start_from': startFrom.toString(),
        'al': '1'
      });
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body.substring(4));
        var payload = jsonResponse['payload'][1][0].toString();
        var document = parse(decodeCp1251(payload));

        var allPosts = document.querySelectorAll('._post_content');
        setTotal(allPosts.length);
        var posts = allPosts
            .map((post) => Post()
                ..id = post.querySelector('.post_img')
                  .map((x) => x.attributes['data-post-id'].substring(ownerId.length + 1))
                ..date = post.querySelector('.rel_date')?.innerHtml
                ..likesCount = post.querySelector('.like_button_count')?.innerHtml
                ..html = post.querySelector('.wall_post_text')
                ..repliesHtml = post.querySelectorAll('.reply')
                ..hasMoreComments = post.querySelector('.replies_next') != null
            )
            .where((post) => (post.html?.innerHtml?.length ?? 0) > minTextLength)
            .map((post) {
              post.html.querySelectorAll('a').forEach((element) {
                element.remove();
              });
              post.content =
                  _removeAllHtmlTags(post.html.innerHtml);
              post.replies = _getReplies(post.repliesHtml);
                
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

  static Future<List<Reply>> loadComments(Post post) async {
    try {
      final response = await http.post('https://vk.com/al_wall.php', body: {
        'act': 'get_post_replies',
        'owner_id': ownerId,
        'item_id': post.id,
        'order': 'desc',
        'al': '1'
      });

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body.substring(4));
        var payload = jsonResponse['payload'][1][0].toString();
        var document = parse(decodeCp1251(payload));
        
        return _getReplies(document.querySelectorAll('.reply'));
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
      final response = await http.get('https://api.vk.com/method/'
        + 'users.get?fields=photo_50&access_token=$token&v=5.92');
      
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

  static Future<bool> replyTo(Post post, String message, String token) async {
    try {
      final response = await http.post('https://api.vk.com/method/'
        + 'wall.createComment?access_token=$token&v=5.92', body: {
          'post_id': post.id,
          'owner_id': ownerId,
          'message': message
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

  static List<Reply> _getReplies(List<Element> payload) 
      => payload.map((reply) => Reply()
            ..img = reply.querySelector('.reply_img')?.attributes['src']
            ..authorUrl = reply.querySelector('.reply_image')?.attributes['href']
            ..name = reply.querySelector('.author')?.innerHtml
            ..content = 
              _removeAllHtmlTags(reply.querySelector('.wall_reply_text')?.innerHtml)
            ..date = 
              _removeAllHtmlTags(reply.querySelector('.reply_date')?.innerHtml)
              .trim()
          )
          .where((reply) => reply.content != null && reply.content.length > 0)
          .toList();

  static String _removeAllHtmlTags(String htmlText) {
    if(htmlText == null) return null;

    var exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    var emoji = RegExp(r'<img .*emoji.* alt="(.*)">');

    return htmlText
      .replaceAll('<br>', '\n')
      .replaceAllMapped(emoji, (match) => match.group(1))
      .replaceAll(exp, '');
  }
}

extension Func on Object {
  K map<T, K>(K Function(T) mapper) {
    return this == null ? null : mapper(this);
  }
}