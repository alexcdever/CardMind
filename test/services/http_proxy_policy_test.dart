import 'package:cardmind/services/http_proxy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const proxy = 'http://proxy.example:8080';
  final environment = <String, String>{
    'http_proxy': proxy,
    'https_proxy': proxy,
  };

  test('uses the configured environment proxy when enabled', () {
    final policy = HttpProxyPolicy(environment: environment);

    expect(
      policy.findProxy(Uri.parse('https://example.com')),
      'PROXY proxy.example:8080',
    );
  });

  test('uses DIRECT and does not consult the environment when disabled', () {
    final policy = HttpProxyPolicy(
      useSystemProxy: false,
      environment: <String, String>{'https_proxy': 'not a valid proxy'},
    );

    expect(policy.findProxy(Uri.parse('https://example.com')), 'DIRECT');
  });

  test('honors no_proxy for configured environment requests', () {
    final policy = HttpProxyPolicy(
      environment: <String, String>{...environment, 'no_proxy': 'example.com'},
    );

    expect(policy.findProxy(Uri.parse('https://example.com/path')), 'DIRECT');
  });

  test('always connects to localhost and loopback addresses directly', () {
    final policy = HttpProxyPolicy(environment: environment);

    for (final host in <String>['localhost', '127.0.0.1', '::1']) {
      expect(
        policy.findProxy(Uri(scheme: 'https', host: host, path: '/')),
        'DIRECT',
        reason: host,
      );
    }
  });
}
