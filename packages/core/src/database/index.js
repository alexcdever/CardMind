"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeDatabase = initializeDatabase;
exports.createTag = createTag;
exports.getAllTags = getAllTags;
exports.addCard = addCard;
exports.updateCard = updateCard;
exports.deleteCard = deleteCard;
exports.getAllCards = getAllCards;
exports.searchCards = searchCards;
exports.getCardById = getCardById;
exports.resetDatabase = resetDatabase;
const electron_1 = require("electron");
const sequelize_1 = require("sequelize");
const path_1 = __importDefault(require("path"));
const schema_1 = __importDefault(require("./schema"));
const migrations_1 = require("./migrations");
const _001_add_description_to_cards_1 = __importDefault(require("./migrations/001_add_description_to_cards"));
// 数据库版本
const DB_VERSION = '1.0.0';
// 初始化数据库连接
const sequelize = new sequelize_1.Sequelize({
    dialect: 'sqlite',
    storage: path_1.default.join(electron_1.app.getPath('userData'), 'database.sqlite'),
    logging: false
});
let models;
// 初始化迁移管理器
const migrationManager = new migrations_1.MigrationManager(sequelize);
// 注册迁移
migrationManager.registerMigration('001_add_description_to_cards', _001_add_description_to_cards_1.default);
async function initializeDatabase() {
    try {
        // 1. 连接数据库
        await sequelize.authenticate();
        console.log('Database connection has been established successfully.');
        // 2. 定义模型
        models = (0, schema_1.default)(sequelize);
        // 3. 同步数据库结构
        await sequelize.sync({ force: true });
        console.log('Database synchronized successfully.');
        // 4. 运行迁移
        await migrationManager.migrate();
        return { success: true };
    }
    catch (error) {
        console.error('Unable to connect to the database:', error);
        return { success: false, error: 'Database initialization failed' };
    }
}
// 标签相关操作
async function createTag(name) {
    try {
        const [tag] = await models.Tag.findOrCreate({
            where: { name }
        });
        return { success: true, data: tag };
    }
    catch (error) {
        console.error('Error creating tag:', error);
        return { success: false, error: 'Failed to create tag' };
    }
}
async function getAllTags() {
    try {
        const tags = await models.Tag.findAll();
        return { success: true, data: tags };
    }
    catch (error) {
        console.error('Error getting tags:', error);
        return { success: false, error: 'Failed to get tags' };
    }
}
// 卡片相关操作
async function addCard({ title, content, tags = [] }) {
    try {
        const card = await models.Card.create({
            title,
            content,
            createdAt: new Date(),
            updatedAt: new Date()
        });
        if (tags.length > 0) {
            const tagModels = await Promise.all(tags.map(name => models.Tag.findOrCreate({ where: { name } }).then(([tag]) => tag)));
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
    }
    catch (error) {
        console.error('Error adding card:', error);
        return { success: false, error: 'Failed to add card' };
    }
}
async function updateCard(id, { title, content, tags = [] }) {
    try {
        // 查找卡片
        const card = await models.Card.findByPk(id);
        if (!card) {
            return { success: false, error: 'Card not found' };
        }
        // 更新卡片字段
        const updateData = {};
        if (title !== undefined)
            updateData.title = title;
        if (content !== undefined)
            updateData.content = content;
        // 保存卡片更改
        await card.update(updateData);
        // 更新标签
        if (Array.isArray(tags)) {
            // 先清除现有的标签关联
            await card.setTags([]);
            // 找到或创建所有标签
            const tagModels = await Promise.all(tags.map(async (name) => {
                const [tag] = await models.Tag.findOrCreate({ where: { name } });
                return tag;
            }));
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
    }
    catch (error) {
        console.error('Error updating card:', error);
        return { success: false, error: 'Failed to update card' };
    }
}
async function deleteCard(id) {
    try {
        const card = await models.Card.findByPk(id);
        if (!card) {
            return { success: false, error: 'Card not found' };
        }
        await card.destroy();
        return { success: true };
    }
    catch (error) {
        console.error('Error deleting card:', error);
        return { success: false, error: 'Failed to delete card' };
    }
}
async function getAllCards() {
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
    }
    catch (error) {
        console.error('Error getting all cards:', error);
        return { success: false, error: 'Failed to get cards' };
    }
}
async function searchCards(query) {
    try {
        const cards = await models.Card.findAll({
            include: [{
                    model: models.Tag,
                    as: 'tags'
                }],
            where: {
                [sequelize_1.Op.or]: [
                    { title: { [sequelize_1.Op.like]: `%${query}%` } },
                    { content: { [sequelize_1.Op.like]: `%${query}%` } }
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
        return { success: true, data: plainCards };
    }
    catch (error) {
        console.error('Error searching cards:', error);
        return { success: false, error: 'Failed to search cards' };
    }
}
async function getCardById(id) {
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
    }
    catch (error) {
        console.error('Error getting card:', error);
        return { success: false, error: 'Failed to get card' };
    }
}
async function resetDatabase() {
    try {
        await sequelize.sync({ force: true });
        console.log('Database reset successfully.');
        return { success: true };
    }
    catch (error) {
        console.error('Error resetting database:', error);
        return { success: false, error: 'Failed to reset database' };
    }
}
//# sourceMappingURL=index.js.map