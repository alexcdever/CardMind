import 'package:cardmind/shared/util/logger.dart';
import '../data/dao/card_dao.dart';
import '../data/database/database_manager.dart';
import '../data/model/card.dart';

/// 卡片服务类
/// 处理卡片的业务逻辑，包括数据库操作和同步
class CardService {
  final _logger = AppLogger.getLogger('CardService');
  late final CardDao _cardDao;
  
  /// 私有构造函数
  CardService._();
  
  /// 单例实例
  static CardService? _instance;
  
  /// 获取卡片服务实例（同步方式，仅在确定实例已初始化后使用）
  static CardService get instance {
    if (_instance == null) {
      throw StateError('CardService 尚未初始化，请先调用 getInstance()');
    }
    return _instance!;
  }
  
  /// 获取卡片服务实例
  static Future<CardService> getInstance() async {
    if (_instance == null) {
      _instance = CardService._();
      await _instance!._init();
    }
    return _instance!;
  }
  
  /// 初始化
  Future<void> _init() async {
    try {
      final db = await DatabaseManager.getInstance();
      _cardDao = CardDao(db.database);
      _logger.info('卡片服务初始化成功');
    } catch (e, stack) {
      _logger.severe('卡片服务初始化失败', e, stack);
      rethrow;
    }
  }

  /// 获取所有卡片
  /// 从数据库中获取所有卡片，并返回卡片列表
  Future<List<Card>> getAllCards() async {
    try {
      // 从 CRDT 数据库获取卡片
      final cards = await _cardDao.getAllCards();
      return cards;
    } catch (e, stack) {
      // 记录错误日志
      _logger.severe('获取卡片列表失败', e, stack);
      return [];
    }
  }


  /// 根据 ID 获取卡片
  /// 从数据库中获取指定 ID 的卡片，并返回卡片对象
  Future<Card?> getCardById(int id) async {
    try {
      // 从 CRDT 数据库获取卡片
      final card = await _cardDao.getCardById(id);
      return card;
    } catch (e, stack) {
      // 记录错误日志
      _logger.severe('获取卡片失败：id=$id', e, stack);
      return null;
    }
  }

  /// 创建新的卡片
  /// 将卡片信息插入到数据库中，并返回创建后的卡片对象
  Future<Card?> createCard(String title, String content) async {
    try {
      // 将卡片信息插入到 CRDT 数据库中
      final card = await _cardDao.createCard(title, content);
      if (card == null) {
        throw StateError('创建卡片失败');
      }
      
      _logger.info('创建卡片成功：id=${card.id}, 标题=$title');
      return card;
    } catch (e, stack) {
      // 记录错误日志
      _logger.severe('创建卡片失败', e, stack);
      return null;
    }
  }

  /// 更新卡片
  /// 更新数据库中的卡片信息，并返回更新后的卡片对象
  Future<Card?> updateCard(int id, String title, String content) async {
    try {
      _logger.info('开始更新卡片: id=$id, title=$title');
      
      // 检查卡片是否存在
      final existingCard = await _cardDao.getCardById(id);
      if (existingCard == null) {
        _logger.severe('更新卡片失败: 卡片不存在, id=$id');
        throw StateError('更新卡片失败: 卡片不存在');
      }
      
      // 更新 CRDT 数据库中的卡片
      final success = await _cardDao.updateCard(id, title, content);
      _logger.info('卡片更新操作结果: id=$id, success=$success');
      
      if (!success) {
        throw StateError('更新卡片失败：数据库操作未成功');
      }

      // 获取更新后的卡片
      final updatedCard = await _cardDao.getCardById(id);
      if (updatedCard == null) {
        _logger.severe('更新卡片后无法获取卡片: id=$id');
        throw StateError('更新卡片失败：无法获取更新后的卡片');
      }
      
      _logger.info('卡片更新成功: id=${updatedCard.id}, title=${updatedCard.title}');
      return updatedCard;
    } catch (e, stack) {
      // 记录错误日志
      _logger.severe('更新卡片失败：id=$id, 错误=$e', e, stack);
      rethrow;
    }
  }

  /// 删除卡片
  /// 从数据库中删除指定 ID 的卡片
  Future<bool> deleteCard(int id) async {
    try {
      // 从 CRDT 数据库中删除卡片
      final success = await _cardDao.deleteCard(id);
      if (!success) {
        throw StateError('删除卡片失败：找不到指定的卡片');
      }
      _logger.info('删除卡片成功：id=$id');
      return true;
    } catch (e, stack) {
      // 记录错误日志
      _logger.severe('删除卡片失败：id=$id', e, stack);
      return false;
    }
  }

  /// 搜索卡片
  /// 根据关键词搜索卡片
  Future<List<Card>> searchCards(String query) async {
    try {
      final cards = await _cardDao.searchCards(query);
      _logger.info('搜索卡片：关键词=$query, 结果=${cards.length}条');
      return cards;
    } catch (e, stack) {
      _logger.severe('搜索卡片失败：关键词=$query', e, stack);
      return [];
    }
  }
}
