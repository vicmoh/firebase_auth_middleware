//This package parses a standard response from the express server
import 'dart:convert';
import 'package:http/http.dart';

/// Server response.
class ServerResponse {
  /// Determine if response is an error.
  bool isError = true;

  /// The response data.
  var data;

  /// Response message.
  String message;

  /// Create server response.
  ServerResponse(Response res) {
    try {
      if (!_isValidResponse(res)) throw Exception("Invalid server response!");
      var errMess = 'The URL api request is probably wrong.';
      assert(res.body != "", errMess);
      assert(res.body != null, errMess);
      var jsonObject = json.decode(res.body);
      //Check for success object
      if (jsonObject["success"] != null) {
        this.isError = false;
        this.data = jsonObject["success"]["data"];
        this.message = jsonObject["success"]["message"];
      } else if (jsonObject["error"] != null) {
        this.isError = true;
        this.data = jsonObject["error"]["data"];
        this.message = jsonObject["error"]["message"];
        throw Exception(jsonObject['error']['message']);
      } else {
        throw Exception("Invalid server response!");
      }
    } catch (e) {
      rethrow;
    }
  }

  //-------------------------------------------------------
  // Validator functions
  //-------------------------------------------------------

  /// Check if the response is valid and ok.
  static bool _isValidResponse(Response res) {
    if (!_isValidStatusCode(res?.statusCode) || res?.body == null) return false;
    return true;
  }

  /// Check if status code is valid
  static bool _isValidStatusCode(int code) {
    if (code < 200 || code > 404 || code == null) return false;
    return true;
  }
}
