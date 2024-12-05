import { Sequelize, QueryInterface, DataTypes } from 'sequelize';
import fs from 'fs';
import path from 'path';

interface MigrationRecord {
  id: number;
  name: string;
  batch: number;
  executed_at: Date;
}

export interface Migration {
  up: (queryInterface: QueryInterface, Sequelize: typeof DataTypes) => Promise<void>;
  down?: (queryInterface: QueryInterface, Sequelize: typeof DataTypes) => Promise<void>;
}

export class MigrationManager {
  private sequelize: Sequelize;
  private migrations: Map<string, Migration>;
  private migrationTableName = 'migrations';

  constructor(sequelize: Sequelize) {
    this.sequelize = sequelize;
    this.migrations = new Map();
  }

  // 初始化迁移表
  private async initMigrationTable() {
    await this.sequelize.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        batch INTEGER NOT NULL,
        executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
  }

  // 注册迁移
  public registerMigration(name: string, migration: Migration) {
    this.migrations.set(name, migration);
  }

  // 获取已执行的迁移
  private async getExecutedMigrations(): Promise<MigrationRecord[]> {
    const [records] = await this.sequelize.query(
      `SELECT * FROM ${this.migrationTableName} ORDER BY id ASC`
    );
    return records as MigrationRecord[];
  }

  // 记录迁移执行
  private async recordMigration(name: string, batch: number) {
    await this.sequelize.query(
      `INSERT INTO ${this.migrationTableName} (name, batch) VALUES (?, ?)`,
      {
        replacements: [name, batch],
        type: 'INSERT'
      }
    );
  }

  // 执行迁移
  public async migrate() {
    try {
      // 1. 初始化迁移表
      await this.initMigrationTable();

      // 2. 获取已执行的迁移
      const executedMigrations = await this.getExecutedMigrations();
      const executedNames = new Set(executedMigrations.map(m => m.name));

      // 3. 获取待执行的迁移
      const pendingMigrations = Array.from(this.migrations.entries())
        .filter(([name]) => !executedNames.has(name))
        .sort(([a], [b]) => a.localeCompare(b));

      if (pendingMigrations.length === 0) {
        console.log('No pending migrations.');
        return;
      }

      // 4. 获取当前批次号
      const currentBatch = executedMigrations.length > 0
        ? Math.max(...executedMigrations.map(m => m.batch)) + 1
        : 1;

      // 5. 执行待执行的迁移
      for (const [name, migration] of pendingMigrations) {
        console.log(`Running migration: ${name}`);
        await migration.up(this.sequelize.getQueryInterface(), DataTypes);
        await this.recordMigration(name, currentBatch);
        console.log(`Completed migration: ${name}`);
      }

      console.log('All migrations completed successfully.');
    } catch (error) {
      console.error('Migration failed:', error);
      throw error;
    }
  }

  // 回滚最后一个批次的迁移
  public async rollback() {
    const currentBatch = await this.getCurrentBatch();
    if (currentBatch === 0) {
      console.log('No migrations to rollback');
      return;
    }

    const toRollback = await this.sequelize.query(
      `SELECT name FROM ${this.migrationTableName} WHERE batch = ? ORDER BY id DESC`,
      {
        replacements: [currentBatch]
      }
    );

    for (const record of toRollback[0] as MigrationRecord[]) {
      const migration = this.migrations.get(record.name);
      if (migration?.down) {
        await migration.down(this.sequelize.getQueryInterface(), DataTypes);
        await this.sequelize.query(
          `DELETE FROM ${this.migrationTableName} WHERE name = ?`,
          {
            replacements: [record.name]
          }
        );
      }
    }
  }

  // 获取当前批次号
  private async getCurrentBatch(): Promise<number> {
    const result = await this.sequelize.query(
      `SELECT MAX(batch) as maxBatch FROM ${this.migrationTableName}`
    );
    return (result[0] as any)[0]?.maxBatch || 0;
  }
}
