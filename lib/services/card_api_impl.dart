import '../bridge/models/card.dart';
import '../bridge/third_party/cardmind_rust/api/card.dart' as card_api;
import 'card_api_interface.dart';

/// Real Card API Implementation
///
/// 真实的 Card API 实现，调用 Rust bridge
class CardApiImpl implements CardApiInterface {
  @override
  Future<Card> createCard({
    required String title,
    required String content,
  }) async {
    return card_api.createCard(title: title, content: content);
  }

  @override
  Future<void> updateCard({
    required String id,
    String? title,
    String? content,
  }) async {
    await card_api.updateCard(id: id, title: title, content: content);
  }

  @override
  Future<void> deleteCard({required String id}) async {
    await card_api.deleteCard(id: id);
  }

  @override
  Future<Card> getCardById({required String id}) async {
    return card_api.getCardById(id: id);
  }

  @override
  Future<List<Card>> getActiveCards() async {
    return card_api.getActiveCards();
  }

  @override
  Future<List<Card>> getAllCards() async {
    return card_api.getAllCards();
  }
}
