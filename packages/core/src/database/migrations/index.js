"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MigrationManager = void 0;
const sequelize_1 = require("sequelize");
class MigrationManager {
    constructor(sequelize) {
        this.migrationTableName = 'migrations';
        this.sequelize = sequelize;
        this.migrations = new Map();
    }
    // 初始化迁移表
    async initMigrationTable() {
        const queryInterface = this.sequelize.getQueryInterface();
        // 检查迁移表是否存在
        const tables = await queryInterface.showAllTables();
        if (!tables.includes(this.migrationTableName)) {
            await queryInterface.createTable(this.migrationTableName, {
                id: {
                    type: sequelize_1.DataTypes.INTEGER,
                    primaryKey: true,
                    autoIncrement: true
                },
                name: {
                    type: sequelize_1.DataTypes.STRING,
                    allowNull: false,
                    unique: true
                },
                batch: {
                    type: sequelize_1.DataTypes.INTEGER,
                    allowNull: false
                },
                executed_at: {
                    type: sequelize_1.DataTypes.DATE,
                    allowNull: false,
                    defaultValue: sequelize_1.Sequelize.fn('CURRENT_TIMESTAMP')
                }
            });
        }
    }
    // 获取已执行的迁移
    async getExecutedMigrations() {
        const records = await this.sequelize.query(`SELECT name FROM ${this.migrationTableName} ORDER BY id ASC`);
        return records[0].map(record => record.name);
    }
    // 记录已执行的迁移
    async recordMigration(name, batch) {
        await this.sequelize.query(`INSERT INTO ${this.migrationTableName} (name, batch) VALUES (?, ?)`, {
            replacements: [name, batch]
        });
    }
    // 注册迁移
    registerMigration(name, migration) {
        this.migrations.set(name, migration);
    }
    // 执行迁移
    async migrate() {
        await this.initMigrationTable();
        // 获取已执行的迁移
        const executedMigrations = await this.getExecutedMigrations();
        // 获取当前批次号
        const currentBatch = await this.getCurrentBatch();
        // 按名称排序迁移
        const pendingMigrations = Array.from(this.migrations.entries())
            .filter(([name]) => !executedMigrations.includes(name))
            .sort(([a], [b]) => a.localeCompare(b));
        // 执行待处理的迁移
        for (const [name, migration] of pendingMigrations) {
            try {
                console.log(`Executing migration: ${name}`);
                await migration.up(this.sequelize.getQueryInterface(), sequelize_1.DataTypes);
                await this.recordMigration(name, currentBatch + 1);
                console.log(`Migration completed: ${name}`);
            }
            catch (error) {
                console.error(`Migration failed: ${name}`, error);
                throw error;
            }
        }
    }
    // 获取当前批次号
    async getCurrentBatch() {
        const result = await this.sequelize.query(`SELECT MAX(batch) as maxBatch FROM ${this.migrationTableName}`);
        return result[0][0]?.maxBatch || 0;
    }
    // 回滚最后一个批次的迁移
    async rollback() {
        const currentBatch = await this.getCurrentBatch();
        if (currentBatch === 0) {
            console.log('No migrations to rollback');
            return;
        }
        const toRollback = await this.sequelize.query(`SELECT name FROM ${this.migrationTableName} WHERE batch = ? ORDER BY id DESC`, {
            replacements: [currentBatch]
        });
        for (const record of toRollback[0]) {
            const migration = this.migrations.get(record.name);
            if (migration?.down) {
                await migration.down(this.sequelize.getQueryInterface(), sequelize_1.DataTypes);
                await this.sequelize.query(`DELETE FROM ${this.migrationTableName} WHERE name = ?`, {
                    replacements: [record.name]
                });
            }
        }
    }
}
exports.MigrationManager = MigrationManager;
//# sourceMappingURL=index.js.map