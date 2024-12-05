import { Sequelize, Op } from 'sequelize';
import path from 'path';
import defineModels, { CardModel, TagModel, CardAttributes } from './schema';
import { MigrationManager } from './migrations';

// 数据库版本
const DB_VERSION = '1.0.0';

// 初始化数据库连接
let sequelize: Sequelize;
let models: { Card: typeof CardModel; Tag: typeof TagModel };

// 初始化迁移管理器
let migrationManager: MigrationManager;

export function initializeDatabaseConnection(userDataPath: string) {
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: path.join(userDataPath, 'database.sqlite'),
    logging: false
  });

  // 初始化迁移管理器
  migrationManager = new MigrationManager(sequelize);

  // 注册迁移
  // migrationManager.registerMigration('001_add_description_to_cards', addDescriptionMigration);
}

export async function initializeDatabase(userDataPath: string) {
  try {
    // 1. 初始化数据库连接
    initializeDatabaseConnection(userDataPath);

    // 2. 连接数据库
    await sequelize.authenticate();
    console.log('Database connection has been established successfully.');

    // 3. 定义模型
    models = defineModels(sequelize);

    // 4. 同步数据库结构
    await sequelize.sync({ force: true });
    console.log('Database synchronized successfully.');

    // 5. 运行迁移
    await migrationManager.migrate();

    return { success: true };
  } catch (error) {
    console.error('Unable to connect to the database:', error);
    return { success: false, error: 'Database initialization failed' };
  }
}

// 标签相关操作
export async function createTag(name: string) {
  try {
    const [tag] = await models.Tag.findOrCreate({
      where: { name }
    });
    return { success: true, data: tag };
  } catch (error) {
    console.error('Error creating tag:', error);
    return { success: false, error: 'Failed to create tag' };
  }
}

export async function getAllTags() {
  try {
    const tags = await models.Tag.findAll();
    return { success: true, data: tags };
  } catch (error) {
    console.error('Error getting tags:', error);
    return { success: false, error: 'Failed to get tags' };
  }
}

// 卡片相关操作
export async function addCard({ title, content, tags = [] }: { title: string; content: string; tags?: string[] }) {
  try {
    const card = await models.Card.create({
      title,
      content,
      createdAt: new Date(),
      updatedAt: new Date()
    } as CardAttributes);

    if (tags.length > 0) {
      const tagModels = await Promise.all(
        tags.map(name => models.Tag.findOrCreate({ where: { name } }).then(([tag]) => tag))
      );
      await card.setTags(tagModels);
    }

    const cardWithTags = await models.Card.findByPk(card.id, {
      include: [{
        model: models.Tag,
        as: 'tags'
      }]
    });

    if (!cardWithTags) {
      throw new Error('Failed to load created card');
    }

    // 转换为纯 JavaScript 对象
    const plainCard = {
      id: cardWithTags.id,
      title: cardWithTags.title,
      content: cardWithTags.content,
      tags: cardWithTags.tags?.map(tag => ({ 
        id: tag.id, 
        name: tag.name 
      })) || [],
      createdAt: cardWithTags.createdAt?.toISOString(),
      updatedAt: cardWithTags.updatedAt?.toISOString()
    };

    return { success: true, data: plainCard };
  } catch (error) {
    console.error('Error adding card:', error);
    return { success: false, error: 'Failed to add card' };
  }
}

export async function updateCard(id: number, { title, content, tags = [] }: { title?: string; content?: string; tags?: string[] }) {
  try {
    // 查找卡片
    const card = await models.Card.findByPk(id);
    if (!card) {
      return { success: false, error: 'Card not found' };
    }

    // 更新卡片字段
    const updateData: Partial<CardAttributes> = {};
    if (title !== undefined) updateData.title = title;
    if (content !== undefined) updateData.content = content;

    // 保存卡片更改
    await card.update(updateData);

    // 更新标签
    if (Array.isArray(tags)) {
      // 先清除现有的标签关联
      await card.setTags([]);

      // 找到或创建所有标签
      const tagModels = await Promise.all(
        tags.map(async name => {
          const [tag] = await models.Tag.findOrCreate({ where: { name } });
          return tag;
        })
      );

      // 设置卡片的新标签
      await card.setTags(tagModels);
    }

    // 重新加载卡片以获取最新数据（包括标签）
    const updatedCard = await models.Card.findByPk(id, {
      include: [{
        model: models.Tag,
        as: 'tags'
      }]
    });

    if (!updatedCard) {
      return { success: false, error: 'Failed to reload updated card' };
    }

    // 转换为纯 JavaScript 对象
    const plainCard = {
      id: updatedCard.id,
      title: updatedCard.title,
      content: updatedCard.content,
      tags: updatedCard.tags?.map(tag => ({ 
        id: tag.id, 
        name: tag.name 
      })) || [],
      createdAt: updatedCard.createdAt?.toISOString(),
      updatedAt: updatedCard.updatedAt?.toISOString()
    };

    return { success: true, data: plainCard };
  } catch (error) {
    console.error('Error updating card:', error);
    return { success: false, error: 'Failed to update card' };
  }
}

export async function deleteCard(id: number) {
  try {
    const card = await models.Card.findByPk(id);
    if (!card) {
      return { success: false, error: 'Card not found' };
    }

    await card.destroy();
    return { success: true };
  } catch (error) {
    console.error('Error deleting card:', error);
    return { success: false, error: 'Failed to delete card' };
  }
}

export async function getAllCards() {
  try {
    const cards = await models.Card.findAll({
      include: [{
        model: models.Tag,
        as: 'tags'
      }],
      order: [['updatedAt', 'DESC']]
    });

    // 转换为纯 JavaScript 对象
    const plainCards = cards.map(card => ({
      id: card.id,
      title: card.title,
      content: card.content,
      tags: card.tags?.map(tag => ({ 
        id: tag.id, 
        name: tag.name 
      })) || [],
      createdAt: card.createdAt?.toISOString(),
      updatedAt: card.updatedAt?.toISOString()
    }));

    return { success: true, data: plainCards };
  } catch (error) {
    console.error('Error getting all cards:', error);
    return { success: false, error: 'Failed to get cards' };
  }
}

export async function searchCards(query: string) {
  try {
    if (!models?.Card) {
      console.error('Error: Card model is not initialized');
      return { success: false, error: 'Database not initialized', data: [] };
    }

    const cards = await models.Card.findAll({
      include: [{
        model: models.Tag,
        as: 'tags'
      }],
      where: {
        [Op.or]: [
          { title: { [Op.like]: `%${query}%` } },
          { content: { [Op.like]: `%${query}%` } }
        ]
      },
      order: [['updatedAt', 'DESC']]
    });

    // 转换为纯 JavaScript 对象
    const plainCards = cards.map(card => ({
      id: card.id,
      title: card.title,
      content: card.content,
      tags: card.tags?.map(tag => ({ 
        id: tag.id, 
        name: tag.name 
      })) || [],
      createdAt: card.createdAt?.toISOString(),
      updatedAt: card.updatedAt?.toISOString()
    }));

    return { success: true, data: plainCards || [] };
  } catch (error) {
    console.error('Error searching cards:', error);
    return { success: false, error: 'Failed to search cards', data: [] };
  }
}

export async function getCardById(id: number) {
  try {
    const card = await models.Card.findByPk(id, {
      include: [{
        model: models.Tag,
        as: 'tags'
      }]
    });

    if (!card) {
      return { success: false, error: 'Card not found' };
    }

    // 转换为纯 JavaScript 对象
    const plainCard = {
      id: card.id,
      title: card.title,
      content: card.content,
      tags: card.tags?.map(tag => ({ 
        id: tag.id, 
        name: tag.name 
      })) || [],
      createdAt: card.createdAt?.toISOString(),
      updatedAt: card.updatedAt?.toISOString()
    };

    return { success: true, data: plainCard };
  } catch (error) {
    console.error('Error getting card:', error);
    return { success: false, error: 'Failed to get card' };
  }
}

export async function resetDatabase() {
  try {
    await sequelize.sync({ force: true });
    console.log('Database reset successfully.');
    return { success: true };
  } catch (error) {
    console.error('Error resetting database:', error);
    return { success: false, error: 'Failed to reset database' };
  }
}
