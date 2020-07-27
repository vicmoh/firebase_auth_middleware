import 'package:http/http.dart' as _http;
import 'package:dart_util/dart_util.dart';
import './server_response.dart';

enum _HttpType { post, get }

/// Token status.
class TokenStatus {
  /// Determine if asking for new token.
  final bool isTokenExpired;

  /// Token status.
  TokenStatus({this.isTokenExpired = false});
}

/// Object that handles simple https.
class SimpleHttp {
  /// Function for getting access token
  /// for bearer request.
  /// [return] string of the access token.
  static Future<String> Function(TokenStatus) get accessToken => _accessToken;
  static Future<String> Function(TokenStatus) _accessToken;

  /// The default api url that is initialize.
  /// on [init] initialization.
  static String get defaultApiUrl => _defaultApiUrl;
  static String _defaultApiUrl;

  /// The main domain URL for requesting data
  String apiUrl;

  /// Determine it is using
  /// [init] function.
  static bool isInit = false;

  /// Determine whether to show debug prints.
  bool get debug => _debug;
  bool _debug = false;

  /// Create a simple http call.
  /// Used with Firebase authenticate middleware.
  SimpleHttp({
    String apiUrl,
    Future<void> Function(TokenStatus) accessToken,
    bool showDebug = false,
  }) : _debug = showDebug ?? false {
    if (!isInit) {
      assert(defaultApiUrl != null,
          "apiUrl must be passed if SimpleHttp.init() is never called.");
      assert(accessToken != null,
          "accessToken must be passed if SimpleHttp.init() is never called.");
      SimpleHttp._accessToken = accessToken;
    }
    this.apiUrl = apiUrl ?? _defaultApiUrl;
  }

  /// Initialize default setup for
  /// the http post and get request.
  /// Call this function at the start of the program.
  /// This initialization is optional.
  /// If this is initialize. Get's and post's
  /// [accessToken] and [apiUrl] can be passed as null,
  /// else they must be passed upon calling post or get request.
  static void init({
    Future<String> Function(TokenStatus) accessToken,
    String defaultApiUrl,
  }) {
    assert(!isInit, 'You should only only call SimpleHttp.init() once.');
    assert(accessToken != null,
        "On SimpleHttp.init(), accessToken must not be null.");
    assert(defaultApiUrl != null,
        "on SimpleHttp.init(), defaultApiUrl must not be null.");
    SimpleHttp.isInit = true;
    SimpleHttp._accessToken = accessToken;
    SimpleHttp._defaultApiUrl = defaultApiUrl;
  }

  /// HTTP get. [url] example: 'www.myurl.com'.
  /// Where [apiPath] might be '/api/v1/test'.
  Future<dynamic> _get(
    String url,
    String apiPath, {
    Map<String, String> body,
    Map<String, String> headers,
  }) async {
    assert(body != null, 'body parameter must not be null.');
    assert(headers != null, 'headers parameter must not be null.');
    final stripUrl = url.replaceAll(RegExp(r"http[s]?://"), "");
    final uri = Uri.https(stripUrl, apiPath, body);
    final res = await _http.get(uri, headers: headers);
    return res;
  }

  Future<Map<String, dynamic>> _request(
    String urlPath, {
    Map<String, dynamic> body,
    _HttpType httpType,
  }) async {
    const func = 'httpPost';
    assert(httpType != null);
    assert(body != null);
    if (debug) Log(func, 'Fetching httpPost: $urlPath');

    /// Set up headers
    var firstToken =
        await SimpleHttp.accessToken(TokenStatus(isTokenExpired: false));
    assert(firstToken != null, 'Session token must not be null.');
    Map<String, String> headers = {'Authorization': "Bearer $firstToken"};

    /// Try without refreshing token.
    Log(this, 'Http request: ${this.apiUrl}$urlPath');
    ServerResponse res;
    try {
      /// First try if the token is not expired.
      if (_HttpType.get == httpType)
        res = ServerResponse(await _get(this.apiUrl, urlPath,
            body: Map<String, String>.from(body), headers: headers));
      else
        res = ServerResponse(await _http.post(this.apiUrl + urlPath,
            headers: headers, body: body));
    } catch (err) {
      /// Session is probably expired.
      if (debug) Log(this, 'Token may have expired.');
      if (debug) Log(this, 'Session probably expired: Catch -> $err');
      try {
        final token =
            await SimpleHttp.accessToken(TokenStatus(isTokenExpired: true));
        assert(token != null, 'Token has expired. Token must not be null.');
        headers = {'Authorization': "Bearer ${token}"};
      } catch (err) {
        throw Exception('Could not get new token session.');
      }

      /// Second try with another new token.
      if (httpType == _HttpType.get)
        res = ServerResponse(await _get(this.apiUrl, urlPath,
            body: Map<String, String>.from(body), headers: headers));
      else
        res = ServerResponse(await _http.post(this.apiUrl + urlPath,
            headers: headers, body: Map<String, String>.from(body)));
    }

    /// Return the response.
    if (debug && res.isError)
      Log(func, 'Server request error -> ${res.message}');
    if (res.isError) throw Exception(res.message);
    try {
      if (debug) Log(func, 'res.data: ${res.data}');
      return Map<String, dynamic>.from(res.data);
    } catch (err) {
      if (debug) Log(func, 'Could not cast to map: $err');
      return null;
    }
  }

  /// Get request.
  Future<Map<String, dynamic>> get(
          String urlPath, Map<String, String> body) async =>
      _request(urlPath, body: body, httpType: _HttpType.get);

  /// Post request.
  Future<Map<String, dynamic>> post(
          String urlPath, Map<String, dynamic> body) async =>
      _request(urlPath, body: body, httpType: _HttpType.post);
}
