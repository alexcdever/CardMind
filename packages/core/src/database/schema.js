"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TagModel = exports.CardModel = void 0;
exports.default = defineModels;
const sequelize_1 = require("sequelize");
// 定义 Sequelize 模型类
class CardModel extends sequelize_1.Model {
    toJSON() {
        const values = { ...super.toJSON() };
        if (this.tags) {
            return {
                ...values,
                tags: this.tags.map(tag => tag.name)
            };
        }
        return values;
    }
}
exports.CardModel = CardModel;
// 定义标签模型类
class TagModel extends sequelize_1.Model {
    toJSON() {
        return { ...super.toJSON() };
    }
}
exports.TagModel = TagModel;
function defineModels(sequelize) {
    // 初始化卡片模型
    CardModel.init({
        id: {
            type: sequelize_1.DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
            allowNull: false
        },
        title: {
            type: sequelize_1.DataTypes.STRING,
            allowNull: false
        },
        content: {
            type: sequelize_1.DataTypes.TEXT,
            allowNull: false
        },
        createdAt: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: false,
            defaultValue: sequelize_1.DataTypes.NOW
        },
        updatedAt: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: false,
            defaultValue: sequelize_1.DataTypes.NOW
        }
    }, {
        tableName: 'Cards',
        timestamps: true,
        sequelize
    });
    // 初始化标签模型
    TagModel.init({
        id: {
            type: sequelize_1.DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true,
            allowNull: false
        },
        name: {
            type: sequelize_1.DataTypes.STRING,
            allowNull: false,
            unique: true
        },
        createdAt: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: false,
            defaultValue: sequelize_1.DataTypes.NOW
        },
        updatedAt: {
            type: sequelize_1.DataTypes.DATE,
            allowNull: false,
            defaultValue: sequelize_1.DataTypes.NOW
        }
    }, {
        tableName: 'Tags',
        timestamps: true,
        sequelize
    });
    // 设置多对多关联
    CardModel.belongsToMany(TagModel, {
        through: 'CardTags',
        as: 'tags',
        foreignKey: {
            name: 'CardModelId',
            allowNull: false
        },
        otherKey: {
            name: 'TagModelId',
            allowNull: false
        },
        uniqueKey: 'CardTags_unique'
    });
    TagModel.belongsToMany(CardModel, {
        through: 'CardTags',
        as: 'cards',
        foreignKey: {
            name: 'TagModelId',
            allowNull: false
        },
        otherKey: {
            name: 'CardModelId',
            allowNull: false
        },
        uniqueKey: 'CardTags_unique'
    });
    return { Card: CardModel, Tag: TagModel };
}
//# sourceMappingURL=schema.js.map