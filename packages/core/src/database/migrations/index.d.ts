import { Sequelize, QueryInterface, DataTypes } from 'sequelize';
export interface Migration {
    up: (queryInterface: QueryInterface, Sequelize: typeof DataTypes) => Promise<void>;
    down?: (queryInterface: QueryInterface, Sequelize: typeof DataTypes) => Promise<void>;
}
export declare class MigrationManager {
    private sequelize;
    private migrations;
    private migrationTableName;
    constructor(sequelize: Sequelize);
    private initMigrationTable;
    private getExecutedMigrations;
    private recordMigration;
    registerMigration(name: string, migration: Migration): void;
    migrate(): Promise<void>;
    private getCurrentBatch;
    rollback(): Promise<void>;
}
