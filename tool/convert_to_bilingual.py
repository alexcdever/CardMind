#!/usr/bin/env python3
"""
批量转换规格文件为双语格式
Convert specification files to bilingual format
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# 术语翻译表
TERM_TRANSLATIONS = {
    'Requirement': '需求',
    'Scenario': '场景',
    'Overview': '概述',
    'Test Coverage': '测试覆盖',
    'Related Documents': '相关文档',
    'Version': '版本',
    'Status': '状态',
    'Dependencies': '依赖',
    'Related Tests': '相关测试',
    'Unit Tests': '单元测试',
    'Integration Tests': '集成测试',
    'Acceptance Criteria': '验收标准',
    'Test File': '测试文件',
    'Last Updated': '最后更新',
    'Authors': '作者',
    'ADRs': '架构决策记录',
    'Related Specs': '相关规格',

    # 关键字
    'GIVEN': '前置条件',
    'WHEN': '操作',
    'THEN': '预期结果',
    'AND': '并且',
    'OR': '或者',

    # 状态
    'Draft': '草稿',
    'Active': '已启用',
    'Deprecated': '已弃用',
    'Completed': '已完成',
}

def extract_metadata(content: str) -> Dict[str, str]:
    """提取元数据"""
    metadata = {}

    # 提取版本
    version_match = re.search(r'\*\*(?:Version|版本)\*\*\s*\|\s*\*\*(?:Version|版本)\*\*:\s*([^\n]+)', content)
    if not version_match:
        version_match = re.search(r'\*\*(?:Version|版本)\*\*:\s*([^\n]+)', content)
    if version_match:
        metadata['version'] = version_match.group(1).strip()
    else:
        metadata['version'] = '1.0.0'

    # 提取状态
    status_match = re.search(r'\*\*(?:Status|状态)\*\*\s*\|\s*\*\*(?:Status|状态)\*\*:\s*([^\n]+)', content)
    if not status_match:
        status_match = re.search(r'\*\*(?:Status|状态)\*\*:\s*([^\n]+)', content)
    if status_match:
        metadata['status'] = status_match.group(1).strip()
    else:
        metadata['status'] = 'Active'

    # 提取依赖
    deps_match = re.search(r'\*\*(?:Dependencies|依赖)\*\*\s*\|\s*\*\*(?:Dependencies|依赖)\*\*:\s*([^\n]+)', content)
    if not deps_match:
        deps_match = re.search(r'\*\*(?:Dependencies|依赖)\*\*:\s*([^\n]+)', content)
    if deps_match:
        metadata['dependencies'] = deps_match.group(1).strip()

    # 提取相关测试
    tests_match = re.search(r'\*\*(?:Related Tests|相关测试)\*\*\s*\|\s*\*\*(?:Related Tests|相关测试)\*\*:\s*([^\n]+)', content)
    if not tests_match:
        tests_match = re.search(r'\*\*(?:Related Tests|相关测试)\*\*:\s*`([^`]+)`', content)
    if tests_match:
        metadata['tests'] = tests_match.group(1).strip()

    return metadata

def extract_title(content: str) -> str:
    """提取标题"""
    title_match = re.search(r'^#\s+(.+?)(?:\n|$)', content, re.MULTILINE)
    if title_match:
        title = title_match.group(1).strip()
        # 移除可能的规格编号
        title = re.sub(r'Specification$', '规格', title)
        return title
    return "Untitled Specification"

def convert_to_bilingual_header(filepath: Path, content: str) -> str:
    """转换为双语头部"""
    title = extract_title(content)
    metadata = extract_metadata(content)

    # 如果标题已经是双语格式，不重复添加
    if '\n#' in title or '规格' not in title:
        # 添加中文标题
        if 'Specification' in title:
            chinese_title = title.replace('Specification', '规格')
        else:
            chinese_title = title + ' 规格'
        bilingual_title = f"# {title}\n# {chinese_title}"
    else:
        bilingual_title = f"# {title}"

    # 构建元数据
    header_parts = [bilingual_title, ""]

    # 版本
    version = metadata.get('version', '1.0.0')
    header_parts.append(f"**Version** | **版本**: {version}")

    # 状态
    status = metadata.get('status', 'Active')
    status_cn = TERM_TRANSLATIONS.get(status, status)
    header_parts.append(f"**Status** | **状态**: {status_cn}")

    # 依赖
    if 'dependencies' in metadata:
        header_parts.append(f"**Dependencies** | **依赖**: {metadata['dependencies']}")

    # 相关测试
    if 'tests' in metadata:
        header_parts.append(f"**Related Tests** | **相关测试**: `{metadata['tests']}`")

    header_parts.append("")
    header_parts.append("---")
    header_parts.append("")

    return '\n'.join(header_parts)

def convert_requirement_section(match: re.Match) -> str:
    """转换需求部分"""
    req_title = match.group(1).strip()
    req_content = match.group(2).strip() if match.lastindex >= 2 else ""

    # 构建双语需求标题
    result = f"## Requirement: {req_title}\n"
    result += f"## 需求：{req_title} [待翻译]\n\n"

    # 需求陈述
    if req_content:
        # 提取第一行作为需求陈述
        lines = req_content.split('\n')
        if lines:
            first_line = lines[0].strip()
            result += f"{first_line}\n"
            result += f"[待翻译：{first_line}]\n\n"

    return result

def convert_scenario(match: re.Match) -> str:
    """转换场景"""
    scenario_title = match.group(1).strip()
    scenario_content = match.group(2).strip() if match.lastindex >= 2 else ""

    result = f"### Scenario: {scenario_title}\n"
    result += f"### 场景：{scenario_title} [待翻译]\n\n"

    # 解析场景步骤
    lines = scenario_content.split('\n')
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # 识别 GIVEN/WHEN/THEN/AND
        for keyword in ['GIVEN', 'WHEN', 'THEN', 'AND']:
            if line.startswith(f'- **{keyword}**') or line.startswith(f'- {keyword}'):
                cn_keyword = TERM_TRANSLATIONS.get(keyword, keyword)
                # 提取内容
                content_match = re.search(rf'-\s*\*\*{keyword}\*\*\s*(.+)', line)
                if not content_match:
                    content_match = re.search(rf'-\s*{keyword}\s+(.+)', line)

                if content_match:
                    content = content_match.group(1).strip()
                    result += f"- **{keyword}** {content}\n"
                    result += f"- **{cn_keyword}**：{content} [待翻译]\n"
                break
        else:
            # 普通行
            if line.startswith('-'):
                result += f"{line}\n"

    result += "\n"
    return result

def needs_conversion(content: str) -> bool:
    """检查是否需要转换"""
    # 如果已经是双语格式，跳过
    if '**Version** | **版本**:' in content:
        return False
    if '## 需求：' in content and '## Requirement:' in content:
        return False
    return True

def convert_spec_file(filepath: Path, dry_run: bool = False) -> bool:
    """转换单个规格文件"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        if not needs_conversion(content):
            print(f"  ⏭️  跳过 {filepath.name} (已是双语格式)")
            return False

        # 转换头部
        new_content = convert_to_bilingual_header(filepath, content)

        # 查找并保留 Overview 部分
        overview_match = re.search(r'##\s+Overview.*?\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
        if overview_match:
            overview_content = overview_match.group(1).strip()
            new_content += f"## Overview | 概述\n\n"
            new_content += f"{overview_content}\n\n"
            new_content += f"[待翻译概述]\n\n"
            new_content += "---\n\n"

        # 保留原有内容（从第一个 ## Requirement 或 ## ADDED Requirements 开始）
        req_start = re.search(r'##\s+(?:Requirement|ADDED Requirements|需求)', content)
        if req_start:
            remaining_content = content[req_start.start():]
            new_content += remaining_content
        else:
            # 如果没有找到需求部分，保留所有内容
            new_content += "\n" + content

        if dry_run:
            print(f"  🔍 预览 {filepath.name}")
            print(new_content[:500])
            print("...")
            return True

        # 写回文件
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)

        print(f"  ✅ 转换 {filepath.name}")
        return True

    except Exception as e:
        print(f"  ❌ 错误 {filepath.name}: {e}")
        return False

def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description='批量转换规格文件为双语格式')
    parser.add_argument('--dry-run', action='store_true', help='预览模式，不实际修改文件')
    parser.add_argument('--path', default='openspec/specs', help='规格目录路径')
    args = parser.parse_args()

    specs_dir = Path(args.path)

    # 查找所有需要转换的文件
    patterns = [
        'domain/*.md',
        'api/*.md',
        'features/*/*.md',
        'ui_system/*.md',
    ]

    files_to_convert = []
    for pattern in patterns:
        files = list(specs_dir.glob(pattern))
        for filepath in files:
            # 跳过特殊文件
            if filepath.name in ['README.md', 'DEPRECATED.md'] or filepath.name.startswith('SPEC_') or filepath.name.startswith('BILINGUAL_'):
                continue
            files_to_convert.append(filepath)

    print(f"找到 {len(files_to_convert)} 个文件需要转换")
    print()

    if args.dry_run:
        print("🔍 预览模式（不会修改文件）")
        print()

    converted_count = 0
    for filepath in sorted(files_to_convert):
        if convert_spec_file(filepath, dry_run=args.dry_run):
            converted_count += 1

    print()
    if args.dry_run:
        print(f"预览完成：{converted_count} 个文件可以转换")
        print("运行 `python3 tool/convert_to_bilingual.py` 执行实际转换")
    else:
        print(f"✅ 转换完成：{converted_count} 个文件已更新")
        print()
        print("⚠️  注意：所有 [待翻译] 标记需要手动填写中文翻译")

if __name__ == '__main__':
    main()
