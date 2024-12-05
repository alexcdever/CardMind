import { Sequelize, DataTypes, Model } from 'sequelize';

// 定义基础的卡片数据接口
export interface CardAttributes {
  id: number;
  title: string;
  content: string;
  createdAt: Date;
  updatedAt: Date;
}

// 定义标签数据接口
export interface TagAttributes {
  id: number;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

// 定义 Sequelize 模型类
export class CardModel extends Model<CardAttributes> implements CardAttributes {
  public id!: number;
  public title!: string;
  public content!: string;
  public createdAt!: Date;
  public updatedAt!: Date;

  // 声明关联
  public readonly tags?: TagModel[];
  public getTags!: () => Promise<TagModel[]>;
  public setTags!: (tags: TagModel[] | number[]) => Promise<void>;
  public addTags!: (tags: TagModel[] | number[]) => Promise<void>;
  public removeTag!: (tag: TagModel | number) => Promise<void>;
  public hasTag!: (tag: TagModel | number) => Promise<boolean>;

  public toJSON(): CardAttributes & { tags?: string[] } {
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

// 定义标签模型类
export class TagModel extends Model<TagAttributes> implements TagAttributes {
  public id!: number;
  public name!: string;
  public createdAt!: Date;
  public updatedAt!: Date;

  // 声明关联
  public readonly cards?: CardModel[];
  public getCards!: () => Promise<CardModel[]>;
  public setCards!: (cards: CardModel[] | number[]) => Promise<void>;
  public addCard!: (card: CardModel | number) => Promise<void>;
  public removeCard!: (card: CardModel | number) => Promise<void>;
  public hasCard!: (card: CardModel | number) => Promise<boolean>;

  public toJSON(): TagAttributes {
    return { ...super.toJSON() };
  }
}

export default function defineModels(sequelize: Sequelize) {
  // 初始化卡片模型
  CardModel.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false
    },
    title: {
      type: DataTypes.STRING,
      allowNull: false
    },
    content: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    createdAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'Cards',
    timestamps: true,
    sequelize
  });

  // 初始化标签模型
  TagModel.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true
    },
    createdAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW
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
