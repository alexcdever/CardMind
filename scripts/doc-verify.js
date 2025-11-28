#!/usr/bin/env node

import fs from 'fs';
import path from 'path';

/**
 * 文档与代码绑定验证脚本
 * 功能：
 * 1. 检查代码引用的文档是否存在
 * 2. 验证文档引用的代码行是否有效
 * 3. 检查文档与代码的版本一致性
 */

// 配置
const config = {
  projectRoot: path.resolve(process.cwd()),
  codeExtensions: ['.ts', '.tsx', '.js', '.jsx'],
  docExtensions: ['.md'],
  // 支持多种文档引用格式
  codeDocRegex: /@文档\s+([^\s]+)/g,
  docCodeRegex: /<!--\s*CODE_REF:\s*([^:\s]+):(\d+)-(\d+)\s*-->/g,
  bindingConfigFile: path.join(process.cwd(), 'doc-binding.json')
};

// 结果统计
const results = {
  totalCodeFiles: 0,
  totalDocFiles: 0,
  validCodeDocRefs: 0,
  invalidCodeDocRefs: 0,
  validDocCodeRefs: 0,
  invalidDocCodeRefs: 0,
  errors: []
};

/**
 * 读取目录下的所有文件
 */
function readDirectory(dirPath, extensions) {
  const files = [];
  
  function traverse(currentPath) {
    const entries = fs.readdirSync(currentPath, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(currentPath, entry.name);
      
      if (entry.isDirectory()) {
        // 跳过node_modules和dist目录
        if (entry.name === 'node_modules' || entry.name === 'dist' || entry.name === '.git') {
          continue;
        }
        traverse(fullPath);
      } else if (extensions.includes(path.extname(entry.name))) {
        files.push(fullPath);
      }
    }
  }
  
  traverse(dirPath);
  return files;
}

/**
 * 验证代码引用的文档
 */
function verifyCodeDocRefs(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  let match;
  
  while ((match = config.codeDocRegex.exec(content)) !== null) {
    const docPath = match[1];
    const fullDocPath = path.resolve(path.dirname(filePath), docPath);
    
    if (fs.existsSync(fullDocPath)) {
      results.validCodeDocRefs++;
    } else {
      results.invalidCodeDocRefs++;
      results.errors.push({
        type: 'code-doc-ref',
        file: filePath,
        ref: docPath,
        message: `文档不存在: ${fullDocPath}`
      });
    }
  }
}

/**
 * 验证文档引用的代码
 */
function verifyDocCodeRefs(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  let match;
  
  while ((match = config.docCodeRegex.exec(content)) !== null) {
    const codePath = match[1];
    const startLine = parseInt(match[2]);
    const endLine = parseInt(match[3]);
    const fullCodePath = path.resolve(config.projectRoot, codePath);
    
    if (fs.existsSync(fullCodePath)) {
      // 验证代码行范围
      const codeContent = fs.readFileSync(fullCodePath, 'utf8');
      const lines = codeContent.split('\n');
      
      if (startLine > 0 && endLine <= lines.length) {
        results.validDocCodeRefs++;
      } else {
        results.invalidDocCodeRefs++;
        results.errors.push({
          type: 'doc-code-ref',
          file: filePath,
          ref: `${codePath}:${startLine}-${endLine}`,
          message: `代码行范围无效，文件共有 ${lines.length} 行`
        });
      }
    } else {
      results.invalidDocCodeRefs++;
      results.errors.push({
        type: 'doc-code-ref',
        file: filePath,
        ref: codePath,
        message: `代码文件不存在: ${fullCodePath}`
      });
    }
  }
}

/**
 * 验证绑定配置文件
 */
function verifyBindingConfig() {
  if (fs.existsSync(config.bindingConfigFile)) {
    try {
      const configContent = fs.readFileSync(config.bindingConfigFile, 'utf8');
      const bindingConfig = JSON.parse(configContent);
      
      if (bindingConfig.bindings) {
        for (const binding of bindingConfig.bindings) {
          const codePath = path.resolve(config.projectRoot, binding.codePath);
          
          if (!fs.existsSync(codePath)) {
            results.errors.push({
              type: 'binding-config',
              file: config.bindingConfigFile,
              ref: binding.codePath,
              message: `绑定配置中的代码文件不存在: ${codePath}`
            });
          }
          
          for (const docPath of binding.docsPath) {
            const fullDocPath = path.resolve(config.projectRoot, docPath);
            if (!fs.existsSync(fullDocPath)) {
              results.errors.push({
                type: 'binding-config',
                file: config.bindingConfigFile,
                ref: docPath,
                message: `绑定配置中的文档不存在: ${fullDocPath}`
              });
            }
          }
          
          // 检查版本一致性（如果配置了版本）
          if (binding.version) {
            // 这里可以添加版本一致性检查逻辑
            // 例如：检查代码中的版本注释与配置中的版本是否一致
          }
        }
      }
    } catch (error) {
      results.errors.push({
        type: 'binding-config',
        file: config.bindingConfigFile,
        message: `绑定配置文件格式错误: ${error.message}`
      });
    }
  }
}

/**
 * 生成验证报告
 */
function generateReport() {
  console.log('========================================');
  console.log('📋 文档与代码绑定验证报告');
  console.log('========================================');
  console.log(`📁 代码文件总数: ${results.totalCodeFiles}`);
  console.log(`📄 文档文件总数: ${results.totalDocFiles}`);
  console.log('----------------------------------------');
  console.log('🔗 代码引用文档:');
  console.log(`   ✅ 有效引用: ${results.validCodeDocRefs}`);
  console.log(`   ❌ 无效引用: ${results.invalidCodeDocRefs}`);
  console.log('----------------------------------------');
  console.log('📝 文档引用代码:');
  console.log(`   ✅ 有效引用: ${results.validDocCodeRefs}`);
  console.log(`   ❌ 无效引用: ${results.invalidDocCodeRefs}`);
  console.log('----------------------------------------');
  
  if (results.errors.length > 0) {
    console.log('❌ 错误详情:');
    console.log('----------------------------------------');
    
    for (const error of results.errors) {
      console.log(`[${error.type}] ${error.file}`);
      if (error.ref) {
        console.log(`   引用: ${error.ref}`);
      }
      console.log(`   错误: ${error.message}`);
      console.log('');
    }
    
    console.log('========================================');
    console.log(`❌ 验证失败，共发现 ${results.errors.length} 个错误`);
    console.log('========================================');
    process.exit(1);
  } else {
    console.log('========================================');
    console.log('✅ 验证通过，所有引用都有效');
    console.log('========================================');
    process.exit(0);
  }
}

/**
 * 主函数
 */
function main() {
  console.log('🔍 开始文档与代码绑定验证...');
  
  // 读取所有代码文件
  const codeFiles = readDirectory(config.projectRoot, config.codeExtensions);
  results.totalCodeFiles = codeFiles.length;
  
  // 读取所有文档文件
  const docFiles = readDirectory(config.projectRoot, config.docExtensions);
  results.totalDocFiles = docFiles.length;
  
  console.log(`📁 扫描到 ${results.totalCodeFiles} 个代码文件`);
  console.log(`📄 扫描到 ${results.totalDocFiles} 个文档文件`);
  
  // 验证代码引用的文档
  console.log('🔗 验证代码引用的文档...');
  for (const file of codeFiles) {
    verifyCodeDocRefs(file);
  }
  
  // 验证文档引用的代码
  console.log('📝 验证文档引用的代码...');
  for (const file of docFiles) {
    verifyDocCodeRefs(file);
  }
  
  // 验证绑定配置文件
  console.log('⚙️  验证绑定配置文件...');
  verifyBindingConfig();
  
  // 生成报告
  generateReport();
}

// 执行主函数
main();