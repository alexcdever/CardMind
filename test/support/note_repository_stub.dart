import 'package:cardmind/bridge/note_repository.dart';
import 'package:cardmind/src/rust/discovery.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';

/// 测试用的 `NoteRepository` 桩基类：为全部成员提供抛 [UnimplementedError]
/// 的默认实现，让测试 fake 只需 override 它关心的成员。
///
/// 与 `MemoryNoteRepository` 的区别：本类不带任何真实内存行为——任何成员被
/// 调用都会立刻失败，迫使测试只依赖显式覆写的那部分。`NoteRepository` 每加
/// 一个成员，编译器会强制这里补一个默认实现，各测试 fake 不再跟着改。
abstract class NoteRepositoryStub implements NoteRepository {
  static Never _unimplemented(String member) =>
      throw UnimplementedError('NoteRepositoryStub.$member 未被覆写');

  @override
  Future<List<NoteRow>> listNotes() => _unimplemented('listNotes');

  @override
  Future<List<NoteRow>> search(String query) => _unimplemented('search');

  @override
  Future<String?> getNote(String id) => _unimplemented('getNote');

  @override
  Future<void> createNote(String id, String content) =>
      _unimplemented('createNote');

  @override
  Future<String> generateNoteId() => _unimplemented('generateNoteId');

  @override
  Future<void> updateMetadata(String id, List<String> tags) =>
      _unimplemented('updateMetadata');

  @override
  Future<List<LinkRow>> getOutgoingLinks(String id) =>
      _unimplemented('getOutgoingLinks');

  @override
  Future<List<LinkRow>> getBacklinks(String id) =>
      _unimplemented('getBacklinks');

  @override
  Future<List<NoteRow>> searchNotes(String query) =>
      _unimplemented('searchNotes');

  @override
  Future<List<NoteRow>> autoCompleteLinks(String prefix) =>
      _unimplemented('autoCompleteLinks');

  @override
  Future<List<String>> getAllTags() => _unimplemented('getAllTags');

  @override
  Future<List<NoteRow>> searchByTag(String tag) =>
      _unimplemented('searchByTag');

  @override
  Future<void> softDelete(String id) => _unimplemented('softDelete');

  @override
  Future<void> restore(String id) => _unimplemented('restore');

  @override
  Future<void> purge(String id) => _unimplemented('purge');

  @override
  Future<int> purgeExpired(DateTime cutoff) => _unimplemented('purgeExpired');

  @override
  Future<List<NoteRow>> trashList() => _unimplemented('trashList');

  @override
  Future<String> deviceId() => _unimplemented('deviceId');

  @override
  Future<String> deviceName() => _unimplemented('deviceName');

  @override
  Future<void> setDeviceName(String name) => _unimplemented('setDeviceName');

  @override
  Future<List<String>> localAddrs() => _unimplemented('localAddrs');

  @override
  Future<String> beginPairingAccept() => _unimplemented('beginPairingAccept');

  @override
  Future<String> beginPairingAcceptAndAdvertise() =>
      _unimplemented('beginPairingAcceptAndAdvertise');

  @override
  Future<void> stopPairingAdvertising() =>
      _unimplemented('stopPairingAdvertising');

  @override
  Future<List<PeerInfo>> discoverPeers() => _unimplemented('discoverPeers');

  @override
  Future<PairingRequest> acceptPairingRequest() =>
      _unimplemented('acceptPairingRequest');

  @override
  Future<PairingRequest?> acceptPairingRequestWithTimeout(Duration timeout) =>
      _unimplemented('acceptPairingRequestWithTimeout');

  @override
  Future<PairingResult> confirmPairing(String code, PairingRequest requester) =>
      _unimplemented('confirmPairing');

  @override
  Future<PairingResult> beginPairingConnect(
    String code,
    PairingTarget target,
  ) => _unimplemented('beginPairingConnect');

  @override
  Future<PairingCredentialDisplay> beginPairingCredential() =>
      _unimplemented('beginPairingCredential');

  @override
  Future<ParsedPairingCredential> parsePairingCredential(String credential) =>
      _unimplemented('parsePairingCredential');

  @override
  Future<PairingResult> beginPairingConnectWithCredential(String credential) =>
      _unimplemented('beginPairingConnectWithCredential');

  @override
  Future<void> acceptAndImportPush() => _unimplemented('acceptAndImportPush');

  @override
  Future<List<PairedDeviceRow>> listPairedDevices() =>
      _unimplemented('listPairedDevices');

  @override
  Future<void> removePairedDevice(String peerId) =>
      _unimplemented('removePairedDevice');
}
