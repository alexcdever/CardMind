#!/usr/bin/env python3
"""验证 OpenSpec 规格文档的脚本 v2 - 支持新的编号格式"""

import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Set

class SpecValidator:
    def __init__(self, specs_dir: str):
        self.specs_dir = Path(specs_dir)
        self.issues = []
        self.specs = {}
        
    def validate_all(self):
        """验证所有规格文档"""
        print("🔍 开始验证规格文档...\n")
        
        # 1. 查找所有规格文档
        spec_files = self.find_spec_files()
        print(f"📁 找到 {len(spec_files)} 个规格文档\n")
        
        # 2. 验证每个文档
        for spec_file in spec_files:
            self.validate_spec_file(spec_file)
        
        # 3. 验证依赖关系
        self.validate_dependencies()
        
        # 4. 输出结果
        return self.print_results()
        
    def find_spec_files(self) -> List[Path]:
        """查找所有包含规格编号的 Markdown 文件"""
        spec_files = []
        for md_file in self.specs_dir.rglob("*.md"):
            if md_file.name == "README.md":
                continue
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()
                if "## 📋 规格编号:" in content:
                    spec_files.append(md_file)
        return sorted(spec_files)
    
    def validate_spec_file(self, spec_file: Path):
        """验证单个规格文档"""
        with open(spec_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        rel_path = spec_file.relative_to(self.specs_dir)
        
        # 提取规格编号
        spec_id_match = re.search(r'## 📋 规格编号:\s*(\S+)', content)
        if not spec_id_match:
            self.issues.append(f"❌ {rel_path}: 缺少规格编号")
            return
        
        spec_id = spec_id_match.group(1)
        
        # 检查规格编号格式 - 支持新格式
        # 允许的格式:
        # - SP-XXX-NNN (旧格式，如 SP-SPM-001)
        # - SP-XXX-XXX-NNN (新格式，如 SP-FLT-MOB-001)
        # - ADR-NNNN (ADR 格式)
        # - SPCS-NNN (特殊格式)
        valid_formats = [
            r'^SP-[A-Z]+-\d+$',           # SP-SPM-001
            r'^SP-[A-Z]+-[A-Z]+-\d+$',    # SP-FLT-MOB-001
            r'^ADR-\d+$',                  # ADR-0001
            r'^SPCS-\d+$',                 # SPCS-000
            r'^SP-[A-Z]+-\d+-[A-Z]+$',    # SP-API-005-IMPL
        ]
        
        is_valid_format = any(re.match(pattern, spec_id) for pattern in valid_formats)
        
        if not is_valid_format:
            self.issues.append(f"⚠️  {rel_path}: 规格编号格式不规范: {spec_id}")
        
        # 提取版本
        version_match = re.search(r'\*\*版本\*\*:\s*(\S+)', content)
        if not version_match:
            self.issues.append(f"⚠️  {rel_path}: 缺少版本信息")
        
        # 提取状态
        status_match = re.search(r'\*\*状态\*\*:\s*(.+)', content)
        if not status_match:
            self.issues.append(f"⚠️  {rel_path}: 缺少状态信息")
        
        # 提取依赖
        deps = []
        deps_match = re.search(r'\*\*依赖\*\*:\s*(.+)', content)
        if deps_match:
            deps_text = deps_match.group(1)
            # 提取所有规格编号格式的依赖
            deps = re.findall(r'(SP-[A-Z]+-\d+|SP-[A-Z]+-[A-Z]+-\d+|ADR-\d+)', deps_text)
        
        # 存储规格信息
        self.specs[spec_id] = {
            'file': rel_path,
            'deps': deps,
            'version': version_match.group(1) if version_match else None,
            'status': status_match.group(1) if status_match else None,
        }
    
    def validate_dependencies(self):
        """验证依赖关系"""
        print("🔗 验证依赖关系...\n")
        
        all_spec_ids = set(self.specs.keys())
        
        for spec_id, info in self.specs.items():
            for dep in info['deps']:
                if dep not in all_spec_ids:
                    self.issues.append(f"⚠️  {spec_id}: 依赖的规格不存在: {dep}")
    
    def print_results(self):
        """输出验证结果"""
        print("\n" + "="*60)
        print("📊 验证结果")
        print("="*60 + "\n")
        
        print(f"✅ 验证的规格数量: {len(self.specs)}")
        print(f"❌ 发现的问题数量: {len(self.issues)}\n")
        
        if self.issues:
            print("🔍 问题详情:\n")
            for issue in self.issues:
                print(f"  {issue}")
            print()
        else:
            print("🎉 所有规格文档验证通过！\n")
        
        # 按类型统计
        print("📋 规格统计:\n")
        by_type = {}
        for spec_id in self.specs.keys():
            if spec_id.startswith("SP-FLT-SHR"):
                type_name = "Flutter Shared"
            elif spec_id.startswith("SP-FLT-MOB"):
                type_name = "Flutter Mobile"
            elif spec_id.startswith("SP-FLT-DSK"):
                type_name = "Flutter Desktop"
            elif spec_id.startswith("SP-"):
                parts = spec_id.split("-")
                if len(parts) >= 2:
                    prefix = parts[1]
                    type_name = f"Rust {prefix}"
                else:
                    type_name = "Other"
            elif spec_id.startswith("ADR"):
                type_name = "ADR"
            else:
                type_name = "Other"
            
            by_type[type_name] = by_type.get(type_name, 0) + 1
        
        for type_name, count in sorted(by_type.items()):
            print(f"  - {type_name}: {count} 个")
        
        print()
        
        # 返回状态码
        return 0 if not self.issues else 1

if __name__ == "__main__":
    specs_dir = sys.argv[1] if len(sys.argv) > 1 else "openspec/specs"
    validator = SpecValidator(specs_dir)
    exit_code = validator.validate_all()
    sys.exit(exit_code)
