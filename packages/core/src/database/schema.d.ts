import { Sequelize, Model } from 'sequelize';
export interface CardAttributes {
    id: number;
    title: string;
    content: string;
    createdAt: Date;
    updatedAt: Date;
}
export interface TagAttributes {
    id: number;
    name: string;
    createdAt: Date;
    updatedAt: Date;
}
export declare class CardModel extends Model<CardAttributes> implements CardAttributes {
    id: number;
    title: string;
    content: string;
    createdAt: Date;
    updatedAt: Date;
    readonly tags?: TagModel[];
    getTags: () => Promise<TagModel[]>;
    setTags: (tags: TagModel[] | number[]) => Promise<void>;
    addTags: (tags: TagModel[] | number[]) => Promise<void>;
    removeTag: (tag: TagModel | number) => Promise<void>;
    hasTag: (tag: TagModel | number) => Promise<boolean>;
    toJSON(): CardAttributes & {
        tags?: string[];
    };
}
export declare class TagModel extends Model<TagAttributes> implements TagAttributes {
    id: number;
    name: string;
    createdAt: Date;
    updatedAt: Date;
    readonly cards?: CardModel[];
    getCards: () => Promise<CardModel[]>;
    setCards: (cards: CardModel[] | number[]) => Promise<void>;
    addCard: (card: CardModel | number) => Promise<void>;
    removeCard: (card: CardModel | number) => Promise<void>;
    hasCard: (card: CardModel | number) => Promise<boolean>;
    toJSON(): TagAttributes;
}
export default function defineModels(sequelize: Sequelize): {
    Card: typeof CardModel;
    Tag: typeof TagModel;
};
