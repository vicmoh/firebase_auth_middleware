import 'package:http/http.dart' as _http;
import './firebase/firebase_server.dart';
import './server_database.dart';
import 'package:dart_util/dart_util.dart';
import 'package:ethos/core/server/firebase/server_response.dart';

class SimpleHttp {
  /// Function for getting access token
  /// for bearer request.
  /// [return] string of the access token.
  static String Function() accessToken;

  /// The main domain URL for requesting data
  static String apiUrl; 

  /// Http post.
  Future<Map<String, dynamic>> httpPost(
    String url, {
    Map<String, dynamic> body,
  }) async {
    const func = 'httpPost';
    const debug = true;
    if (debug) Log(func, 'Fetching httpPost: $url');

    /// Set up headers
    var apiUrl = '${apiUrl}/$url';
    Map<String, String> headers = {
      'Authorization': "Bearer ${accessToken()}"
    };

    /// Try without refreshing token.
    ServerResponse res;
    try {
      if (body == null)
        res = ServerResponse(await _http.post(apiUrl, headers: headers));
      else
        res = ServerResponse(
            await _http.post(apiUrl, headers: headers, body: body));
    } catch (_) {
      /// Session is probably expired.
      try {
        final token = await accessToken();
        headers = {'Authorization': "Bearer ${token}"};
      } catch (err) {
        throw Exception('Could not get new token session.');
      }

      /// Try again with new token.
      if (body == null)
        res = ServerResponse(await _http.post(apiUrl, headers: headers));
      else
        res = ServerResponse(
            await _http.post(apiUrl, headers: headers, body: body));
    }

    if (debug && res.isError) Log(func, 'Server request error -> $res.message');
    if (res.isError) throw Exception(res.message);
    try {
      if (debug) Log(func, 'res.data: ${res.data}');
      return Map<String, dynamic>.from(res.data);
    } catch (err) {
      if (debug) Log(func, 'Could not cast to map: $err');
      return null;
    }
  }
}

