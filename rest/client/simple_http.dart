import 'package:http/http.dart' as _http;
import 'package:dart_util/dart_util.dart';
import './server_response.dart';
import 'dart:convert';

extension GetResponseObject on Map {
  /// Get the HTTP Response object map data
  /// from the rest. This getter parse
  /// the response into a map object.
  Map<String, dynamic> get responseData =>
      Map<String, dynamic>.from(jsonDecode(this['response'] ?? '{}'));
}

/// Function for parsing try catch error.
/// If the error type is not known.
/// This function will make sure that
/// it returns the correct message.
String? _parseError(err, {String? message}) {
  try {
    if (err?.message is String) return err.message;
    if (err is String) return err;
  } catch (err) {
    return message ?? err.toString();
  }
  return message ?? err.toString();
}

enum _HttpType { post, get }

/// A custom HTTP exception.
class HttpException implements Exception {
  /// The exception string.
  final String? message;

  /// A custom HTTP exception.
  HttpException(this.message);

  @override
  String toString() => message!;
}

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
  static Future<String?> Function(TokenStatus)? get accessToken => _accessToken;
  static Future<String?> Function(TokenStatus)? _accessToken;

  /// Determine if the http request is production
  /// or local environment.
  static bool _isProd = false;
  static String? _apiUrlEnv() => _isProd ? _defaultApiUrl : _defaultLocalApiUrl;

  /// The default api url that is initialize.
  /// on [init] initialization.
  static String? get defaultApiUrl => _defaultApiUrl;
  static String? _defaultApiUrl;

  /// The default api url that is initialize.
  static String? get defaultLocalApiUrl => _defaultLocalApiUrl;
  static String? _defaultLocalApiUrl;

  /// The accepted language code header.
  static String? _acceptLanguage;
  static String? get acceptLanguage => _acceptLanguage;

  static void setDefaultAcceptLanguageHeader(String? lang) {
    _acceptLanguage = lang;
  }

  /// The main domain URL for requesting data
  String? get apiUrl => _apiUrl;
  late String? _apiUrl;

  /// Determine it is using
  /// [init] function.
  static bool isInit = false;

  /// Determine whether to show debug prints.
  bool get debug => _debug;
  final bool _debug;

  /// Create a simple http call.
  /// Used with Firebase authenticate middleware.
  SimpleHttp({
    String? apiUrl,
    Future<void> Function(TokenStatus)? accessToken,
    bool showDebug = false,
  }) : _debug = showDebug {
    if (!isInit) {
      assert(accessToken != null,
          'accessToken must be passed if SimpleHttp.init() is never called.');
      SimpleHttp._accessToken =
          accessToken as Future<String?> Function(TokenStatus)?;
    }

    this._apiUrl = apiUrl ?? _apiUrlEnv();
    assert(this._apiUrl != null,
        'SimpleHttp() must be initialized with an api url. You can call SimpleHttp.init() to initialize the api url.');
  }

  /// Initialize default setup for
  /// the http post and get request.
  /// Call this function at the start of the program.
  /// This initialization is optional.
  /// If this is initialize. Get's and post's
  /// [accessToken] and [apiUrl] can be passed as null,
  /// else they must be passed upon calling post or get request.
  static void init({
    required Future<String?> Function(TokenStatus) accessToken,
    required String defaultApiUrl,
    String? defaultLocalApiUrl,
    bool isProd = false,
  }) {
    SimpleHttp._isProd = isProd;
    SimpleHttp.isInit = true;
    SimpleHttp._accessToken = accessToken;
    SimpleHttp._defaultApiUrl = defaultApiUrl;
    SimpleHttp._defaultLocalApiUrl = defaultLocalApiUrl;
  }

  /// HTTP get. [url] example: 'www.myUrl.com'.
  /// Where [apiPath] might be '/api/v1/test'.
  Future<dynamic> _get(
    String url,
    String apiPath, {
    required Map<String, String> body,
    required Map<String, String> headers,
  }) async {
    final stripUrl = url.replaceAll(RegExp(r'http[s]?://'), '');
    final uri = Uri.https(stripUrl, apiPath, body);
    final res = await _http.get(uri, headers: headers);
    return res;
  }

  Future<Map<String, dynamic>?> _request(
    String urlPath, {
    required Map<String, dynamic> body,
    required _HttpType httpType,
    bool noCache = false,
  }) async {
    const func = 'httpPost';
    if (debug) Log(func, 'Fetching httpPost: $urlPath');

    /// Set up headers
    var firstToken =
        await SimpleHttp.accessToken!(TokenStatus(isTokenExpired: false));
    if (debug && firstToken == null)
      Log(this, '[WARNING]: First token is null.');
    var headers = <String, String>{'Authorization': 'Bearer $firstToken'};

    /// No cache if it's is set for get API only.
    if (httpType == _HttpType.get && noCache) {
      headers['Cache-Control'] =
          'no-cache, no-store, must-revalidate, max-age=0';
      headers['Pragma'] = 'no-cache';
      headers['Expires'] = '0';
    }

    if (_acceptLanguage != null) {
      headers['Accept-Language'] = _acceptLanguage!;
    }

    /// Try without refreshing token.
    Log(this, 'Http request: $_apiUrl$urlPath');
    ServerResponse res;
    try {
      /// First try if the token is not expired.
      if (_HttpType.get == httpType)
        res = ServerResponse(await (_get(_apiUrl!, urlPath,
            body: Map<String, String>.from(body), headers: headers)));
      else
        res = ServerResponse(await _http.post(Uri.parse(_apiUrl! + urlPath),
            headers: headers, body: body));
    } catch (err) {
      /// Session is probably expired.
      if (debug) Log(this, 'Token may have expired.');
      if (debug) Log(this, 'Session probably expired: Catch -> $err');
      try {
        final token =
            await SimpleHttp.accessToken!(TokenStatus(isTokenExpired: true));
        if (debug && token == null)
          Log(this, 'Token has expired. Token must not be null.');
        headers = {'Authorization': 'Bearer $token'};
      } catch (err) {
        throw HttpException('Could not get new token session.');
      }

      /// Second try with another new token.
      try {
        if (httpType == _HttpType.get)
          res = ServerResponse(await (_get(_apiUrl!, urlPath,
              body: Map<String, String>.from(body), headers: headers)));
        else
          res = ServerResponse(await _http.post(Uri.parse(_apiUrl! + urlPath),
              headers: headers, body: Map<String, String>.from(body)));
      } catch (err) {
        throw HttpException(_parseError(err));
      }
    }

    /// Return the response.
    if (debug && res.isError)
      Log(func, 'Server request error -> ${res.message}');
    if (res.isError) throw HttpException(_parseError(res.message));

    try {
      if (debug) Log(func, 'res.data: ${res.data}');
      return Map<String, dynamic>.from(res.data);
    } catch (err) {
      if (debug) Log(func, 'Could not cast to map: $err');
      return null;
    }
  }

  /// GET http request. Please note that this
  /// is dependent on server side using this package.
  /// This functions parses the request
  /// data and return a JSON object requested
  /// from the back end instead if string.
  Future<Map<String, dynamic>> getRequest(
    String urlPath,
    Map body, {
    bool noCache = false,
  }) async =>
      // ignore: deprecated_member_use_from_same_package
      (await this.get(
        urlPath,
        {'request': jsonEncode(body)},
        noCache: noCache,
      ))!
          .responseData;

  /// POST http request. Please note that this
  /// is dependent on server side using this package.
  /// This functions parses the request data that is received
  /// from the backend and return the JSON object instead
  /// of string.
  Future<Map<String, dynamic>> postRequest(String urlPath, Map body) async =>
      // ignore: deprecated_member_use_from_same_package
      (await this.post(urlPath, {
        'request': jsonEncode(body),
      }))!
          .responseData;

  /// GET request. This does note parse the JSON string.
  /// Data sent with JSON string must be parsed. Checkout
  /// getRequest() function instead.
  @Deprecated('Use getRequest() instead.')
  Future<Map<String, dynamic>?> get(String urlPath, Map<String, String?> body,
          {bool noCache = false}) async =>
      _request(urlPath, body: body, httpType: _HttpType.get, noCache: noCache);

  /// POST request. This does note parse the JSON string.
  /// Data sent with JSON string must be parsed. Checkout
  /// getRequest() function instead.
  @Deprecated('Use postRequest() instead.')
  Future<Map<String, dynamic>?> post(
          String urlPath, Map<String, dynamic> body) async =>
      _request(urlPath, body: body, httpType: _HttpType.post);
}
