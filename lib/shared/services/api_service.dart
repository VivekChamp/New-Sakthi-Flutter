import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// A centralized service for handling all API communications.
class ApiService {
  final String serverUrl;
  final String sid;

  ApiService({required this.serverUrl, required this.sid});

  /// Constructs the standard headers required for API calls.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Cookie': 'sid=$sid',
  };

  /// Performs a GET request to the specified endpoint.
  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$serverUrl$endpoint');
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Performs a POST request to the specified endpoint with a given body.
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$serverUrl$endpoint');
    try {
      final response = await http
          .post(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Performs a PUT request to the specified endpoint with a given body.
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$serverUrl$endpoint');
    try {
      final response = await http
          .put(url, headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Uploads a file to the server.
  Future<dynamic> uploadFile({
    required String doctype,
    required String docname,
    required String fieldname,
    required File file,
  }) async {
    final url = Uri.parse('$serverUrl/api/method/upload_file');
    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Cookie'] = 'sid=$sid'
        ..fields['doctype'] = doctype
        ..fields['docname'] = docname
        ..fields['fieldname'] = fieldname
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Processes the HTTP response, decoding JSON and handling non-200 status codes.
  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      // Throws an exception with the full response body for detailed error handling
      throw response.body;
    }
  }
}
