import 'dart:io';

/// Selects the proxy used by application HTTP requests at request time.
class HttpProxyPolicy {
  HttpProxyPolicy({this.useSystemProxy = true, this.environment});

  bool useSystemProxy;
  final Map<String, String>? environment;

  String findProxy(Uri uri) => useSystemProxy
      ? HttpClient.findProxyFromEnvironment(uri, environment: environment)
      : 'DIRECT';
}
