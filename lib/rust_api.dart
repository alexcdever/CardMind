// input: 
// output: 
// pos: 
import 'bridge_generated/frb_generated.dart';

class RustApi {
  RustApi._();

  static Future<RustApi> init() async {
    await RustLib.init();
    return RustApi._();
  }

  RustLibApi get api => RustLib.instance.api;
}
