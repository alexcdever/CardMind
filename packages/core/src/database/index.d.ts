import { TagModel } from './schema';
export declare function initializeDatabase(): Promise<{
    success: boolean;
    error?: undefined;
} | {
    success: boolean;
    error: string;
}>;
export declare function createTag(name: string): Promise<{
    success: boolean;
    data: TagModel;
    error?: undefined;
} | {
    success: boolean;
    error: string;
    data?: undefined;
}>;
export declare function getAllTags(): Promise<{
    success: boolean;
    data: TagModel[];
    error?: undefined;
} | {
    success: boolean;
    error: string;
    data?: undefined;
}>;
export declare function addCard({ title, content, tags }: {
    title: string;
    content: string;
    tags?: string[];
}): Promise<{
    success: boolean;
    data: {
        id: number;
        title: string;
        content: string;
        tags: {
            id: number;
            name: string;
        }[];
        createdAt: string;
        updatedAt: string;
    };
    error?: undefined;
} | {
    success: boolean;
    error: string;
    data?: undefined;
}>;
export declare function updateCard(id: number, { title, content, tags }: {
    title?: string;
    content?: string;
    tags?: string[];
}): Promise<{
    success: boolean;
    error: string;
    data?: undefined;
} | {
    success: boolean;
    data: {
        id: number;
        title: string;
        content: string;
        tags: {
            id: number;
            name: string;
        }[];
        createdAt: string;
        updatedAt: string;
    };
    error?: undefined;
}>;
export declare function deleteCard(id: number): Promise<{
    success: boolean;
    error: string;
} | {
    success: boolean;
    error?: undefined;
}>;
export declare function getAllCards(): Promise<{
    success: boolean;
    data: {
        id: number;
        title: string;
        content: string;
        tags: {
            id: number;
            name: string;
        }[];
        createdAt: string;
        updatedAt: string;
    }[];
    error?: undefined;
} | {
    success: boolean;
    error: string;
    data?: undefined;
}>;
export declare function searchCards(query: string): Promise<{
    success: boolean;
    data: {
        id: number;
        title: string;
        content: string;
        tags: {
            id: number;
            name: string;
        }[];
        createdAt: string;
        updatedAt: string;
    }[];
    error?: undefined;
} | {
    success: boolean;
    error: string;
    data?: undefined;
}>;
export declare function getCardById(id: number): Promise<{
    success: boolean;
    error: string;
    data?: undefined;
} | {
    success: boolean;
    data: {
        id: number;
        title: string;
        content: string;
        tags: {
            id: number;
            name: string;
        }[];
        createdAt: string;
        updatedAt: string;
    };
    error?: undefined;
}>;
export declare function resetDatabase(): Promise<{
    success: boolean;
    error?: undefined;
} | {
    success: boolean;
    error: string;
}>;
