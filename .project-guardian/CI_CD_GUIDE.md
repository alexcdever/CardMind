# CI/CD 集成示例

本文档提供 Project Guardian 与各种 CI/CD 平台的集成示例。

---

## 📋 目录

1. [GitHub Actions](#github-actions)
2. [GitLab CI](#gitlab-ci)
3. [Jenkins](#jenkins)
4. [通用脚本](#通用脚本)

---

## GitHub Actions

### 基础配置

创建 `.github/workflows/project-guardian.yml`:

```yaml
name: Project Guardian

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

jobs:
  validate:
    name: Validate Constraints
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Run Project Guardian (Quick)
        run: dart tool/validate_constraints.dart
        continue-on-error: false

      - name: Run Project Guardian (Full)
        if: github.event_name == 'push'
        run: dart tool/validate_constraints.dart --full
        continue-on-error: false

      - name: Upload failure log
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: project-guardian-failures
          path: .project-guardian/failures.log
```

### 高级配置（带缓存）

```yaml
name: Project Guardian (Advanced)

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

jobs:
  validate:
    name: Validate Constraints
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Cache Dart dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.pub-cache
          key: ${{ runner.os }}-dart-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-dart-

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true
          components: rustfmt, clippy

      - name: Cache Rust dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.cargo/bin/
            ~/.cargo/registry/index/
            ~/.cargo/registry/cache/
            ~/.cargo/git/db/
            rust/target/
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
          restore-keys: |
            ${{ runner.os }}-cargo-

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          cache: true

      - name: Run Project Guardian (Quick Check)
        id: quick-check
        run: |
          echo "Running quick constraint check..."
          dart tool/validate_constraints.dart
        continue-on-error: false

      - name: Run Project Guardian (Full Validation)
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          echo "Running full validation with compilation..."
          dart tool/validate_constraints.dart --full
        continue-on-error: false

      - name: Generate constraint report
        if: always()
        run: |
          echo "## Project Guardian Report" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          if [ -f .project-guardian/failures.log ]; then
            echo "### Violations Found" >> $GITHUB_STEP_SUMMARY
            echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
            tail -20 .project-guardian/failures.log >> $GITHUB_STEP_SUMMARY
            echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          else
            echo "✅ No violations found!" >> $GITHUB_STEP_SUMMARY
          fi

      - name: Upload failure log
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: project-guardian-failures-${{ github.sha }}
          path: .project-guardian/failures.log
          retention-days: 30

      - name: Comment PR with results
        if: github.event_name == 'pull_request' && failure()
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const log = fs.readFileSync('.project-guardian/failures.log', 'utf8');
            const body = `## ❌ Project Guardian Validation Failed

            Please fix the following constraint violations:

            \`\`\`
            ${log.slice(-1000)}
            \`\`\`

            See [best practices](.project-guardian/best-practices.md) for guidance.
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

---

## GitLab CI

创建 `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - test

variables:
  DART_VERSION: "stable"
  FLUTTER_VERSION: "3.x"

# 缓存配置
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .pub-cache/
    - rust/target/
    - .cargo/

# 快速验证（所有分支）
validate:quick:
  stage: validate
  image: dart:stable
  before_script:
    - apt-get update && apt-get install -y curl git
    - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    - source $HOME/.cargo/env
  script:
    - echo "Running Project Guardian quick check..."
    - dart tool/validate_constraints.dart
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH'
  artifacts:
    when: on_failure
    paths:
      - .project-guardian/failures.log
    expire_in: 1 week

# 完整验证（仅主分支）
validate:full:
  stage: validate
  image: dart:stable
  before_script:
    - apt-get update && apt-get install -y curl git
    - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    - source $HOME/.cargo/env
    - rustup component add rustfmt clippy
  script:
    - echo "Running Project Guardian full validation..."
    - dart tool/validate_constraints.dart --full
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_BRANCH == "dev"'
  artifacts:
    when: on_failure
    paths:
      - .project-guardian/failures.log
    expire_in: 1 month

# 生成报告
report:
  stage: test
  image: dart:stable
  script:
    - |
      if [ -f .project-guardian/failures.log ]; then
        echo "Constraint violations found:"
        cat .project-guardian/failures.log
        exit 1
      else
        echo "✅ All constraints satisfied!"
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  allow_failure: false
```

---

## Jenkins

创建 `Jenkinsfile`:

```groovy
pipeline {
    agent any

    environment {
        DART_HOME = tool 'Dart'
        RUST_HOME = tool 'Rust'
        PATH = "${DART_HOME}/bin:${RUST_HOME}/bin:${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup') {
            steps {
                sh '''
                    dart --version
                    rustc --version
                    cargo --version
                '''
            }
        }

        stage('Quick Validation') {
            steps {
                script {
                    echo 'Running Project Guardian quick check...'
                    sh 'dart tool/validate_constraints.dart'
                }
            }
        }

        stage('Full Validation') {
            when {
                anyOf {
                    branch 'main'
                    branch 'dev'
                }
            }
            steps {
                script {
                    echo 'Running Project Guardian full validation...'
                    sh 'dart tool/validate_constraints.dart --full'
                }
            }
        }
    }

    post {
        failure {
            script {
                if (fileExists('.project-guardian/failures.log')) {
                    archiveArtifacts artifacts: '.project-guardian/failures.log',
                                   fingerprint: true

                    def log = readFile('.project-guardian/failures.log')
                    echo "Constraint violations:\n${log}"

                    // 发送通知
                    emailext(
                        subject: "Project Guardian Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                        body: """
                            Project Guardian validation failed.

                            Violations:
                            ${log}

                            See attached log for details.
                        """,
                        attachLog: true,
                        to: '${DEFAULT_RECIPIENTS}'
                    )
                }
            }
        }

        success {
            echo '✅ All Project Guardian checks passed!'
        }

        always {
            cleanWs()
        }
    }
}
```

---

## 通用脚本

### Bash 脚本（适用于任何 CI）

创建 `scripts/ci-validate.sh`:

```bash
#!/usr/bin/env bash
# CI 通用验证脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🛡️  Project Guardian - CI Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查环境
echo -e "${BLUE}检查环境...${NC}"

if ! command -v dart &> /dev/null; then
    echo -e "${RED}❌ Dart 未安装${NC}"
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${RED}❌ Rust 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 环境检查通过${NC}"
echo ""

# 检查配置文件
if [ ! -f "project-guardian.toml" ]; then
    echo -e "${YELLOW}⚠️  project-guardian.toml 不存在，跳过验证${NC}"
    exit 0
fi

# 运行验证
VALIDATION_MODE="${1:-quick}"

if [ "$VALIDATION_MODE" = "full" ]; then
    echo -e "${BLUE}运行完整验证（包括编译）...${NC}"
    dart tool/validate_constraints.dart --full
else
    echo -e "${BLUE}运行快速验证...${NC}"
    dart tool/validate_constraints.dart
fi

EXIT_CODE=$?

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ 所有约束检查通过${NC}"
    exit 0
else
    echo -e "${RED}❌ 约束检查失败${NC}"

    if [ -f ".project-guardian/failures.log" ]; then
        echo ""
        echo -e "${YELLOW}失败日志:${NC}"
        cat .project-guardian/failures.log
    fi

    exit 1
fi
```

使用方法:

```bash
# 快速验证
bash scripts/ci-validate.sh

# 完整验证
bash scripts/ci-validate.sh full
```

---

## 🎯 最佳实践

### 1. 分层验证策略

```yaml
# PR: 快速验证
- 代码模式检查
- 基本语法检查

# Push to dev: 中等验证
- 代码模式检查
- 编译检查
- 单元测试

# Push to main: 完整验证
- 代码模式检查
- 编译检查
- 所有测试
- 性能测试
```

### 2. 缓存优化

```yaml
# 缓存 Dart 依赖
- ~/.pub-cache

# 缓存 Rust 依赖
- ~/.cargo
- rust/target

# 缓存 Flutter
- ~/.flutter
```

### 3. 并行执行

```yaml
jobs:
  validate-rust:
    # Rust 验证

  validate-dart:
    # Dart 验证

  # 两个 job 并行运行
```

### 4. 失败通知

```yaml
# Slack 通知
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Project Guardian validation failed!'

# Email 通知
- name: Send email
  if: failure()
  uses: dawidd6/action-send-mail@v3
  with:
    subject: 'CI Failed: Project Guardian'
    body: file://.project-guardian/failures.log
```

---

## 📊 监控和报告

### 生成 HTML 报告

```bash
#!/usr/bin/env bash
# 生成 HTML 报告

cat > report.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Project Guardian Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        .warn { color: orange; }
    </style>
</head>
<body>
    <h1>Project Guardian Validation Report</h1>
    <p>Generated: $(date)</p>

    <h2>Results</h2>
    <pre>
$(cat .project-guardian/failures.log 2>/dev/null || echo "No violations found!")
    </pre>
</body>
</html>
EOF

echo "Report generated: report.html"
```

### 集成到 CI Dashboard

```yaml
- name: Publish report
  uses: actions/upload-artifact@v3
  with:
    name: project-guardian-report
    path: report.html
```

---

## 🔧 故障排查

### CI 中常见问题

1. **Dart 未找到**
   ```yaml
   - name: Setup Dart
     uses: dart-lang/setup-dart@v1
   ```

2. **Rust 未找到**
   ```yaml
   - name: Setup Rust
     uses: actions-rs/toolchain@v1
   ```

3. **权限问题**
   ```bash
   chmod +x tool/validate_constraints.dart
   ```

4. **缓存问题**
   ```yaml
   # 清除缓存
   - name: Clear cache
     run: rm -rf ~/.pub-cache ~/.cargo
   ```

---

## 📚 相关资源

- **验证脚本**: `tool/validate_constraints.dart`
- **配置文件**: `project-guardian.toml`
- **Hooks 指南**: `.project-guardian/HOOKS_GUIDE.md`
- **使用指南**: `.project-guardian/README.md`

---

*最后更新: 2026-01-16*
