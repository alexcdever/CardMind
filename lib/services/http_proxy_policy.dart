import 'dart:io';

/// Selects the proxy used by application HTTP requests at request time.
class HttpProxyPolicy {
  HttpProxyPolicy({this.useSystemProxy = true, this.environment});

  bool useSystemProxy;
  final Map<String, String>? environment;

  String findProxy(Uri uri) {
    if (_isLoopback(uri.host)) return 'DIRECT';
    if (!useSystemProxy) return 'DIRECT';
    return HttpClient.findProxyFromEnvironment(uri, environment: environment);
  }

  static bool _isLoopback(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '0:0:0:0:0:0:0:1';
  }
}
