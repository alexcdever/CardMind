#!/usr/bin/env node

/**
 * 生成移动端图标脚本
 * 该脚本将assets/icon.svg转换为不同尺寸的PNG图标，适配移动端不同分辨率
 */

import { createCanvas, loadImage } from 'canvas';
import { writeFile, mkdir } from 'fs/promises';
import { join } from 'path';

// 定义不同分辨率的尺寸
const sizes = [
  { name: 'mipmap-mdpi', size: 48 },
  { name: 'mipmap-hdpi', size: 72 },
  { name: 'mipmap-xhdpi', size: 96 },
  { name: 'mipmap-xxhdpi', size: 144 },
  { name: 'mipmap-xxxhdpi', size: 192 }
];

/**
 * 转换SVG到PNG的函数
 * @param {string} inputPath - 输入SVG文件路径
 * @param {string} outputPath - 输出PNG文件路径
 * @param {number} size - 图标尺寸
 */
async function convertSvgToPng(inputPath, outputPath, size) {
  try {
    const image = await loadImage(inputPath);
    const canvas = createCanvas(size, size);
    const ctx = canvas.getContext('2d');
    
    // 绘制图像
    ctx.drawImage(image, 0, 0, size, size);
    
    // 保存为PNG
    const buffer = canvas.toBuffer('image/png');
    await writeFile(outputPath, buffer);
    console.log(`✅ 已生成 ${outputPath}`);
  } catch (error) {
    console.error(`❌ 生成 ${outputPath} 时出错:`, error);
    throw error;
  }
}

/**
 * 确保目录存在
 * @param {string} dirPath - 目录路径
 */
async function ensureDir(dirPath) {
  try {
    await mkdir(dirPath, { recursive: true });
  } catch (error) {
    // 如果目录已存在则忽略错误
    if (error.code !== 'EEXIST') {
      throw error;
    }
  }
}

/**
 * 主函数
 */
async function main() {
  console.log('📱 开始生成移动端图标...');
  
  const inputSvg = join(process.cwd(), 'assets', 'icon.svg');
  
  // 为每种分辨率生成图标
  for (const { name, size } of sizes) {
    const outputDir = join(process.cwd(), 'CardMindAndroid', 'android', 'app', 'src', 'main', 'res', name);
    const outputPath = join(outputDir, 'ic_launcher.png');
    const outputRoundPath = join(outputDir, 'ic_launcher_round.png');
    
    // 确保输出目录存在
    await ensureDir(outputDir);
    
    // 生成标准图标和圆形图标
    await convertSvgToPng(inputSvg, outputPath, size);
    await convertSvgToPng(inputSvg, outputRoundPath, size);
  }
  
  console.log('✅ 所有移动端图标已生成完成');
}

// 执行主函数
main().catch(error => {
  console.error('❌ 生成图标过程中发生错误:', error);
  process.exit(1);
});