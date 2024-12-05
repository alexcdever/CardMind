// 生成柔和的彩虹色
export const getTagColor = (tagName: string): string => {
  // 使用标签名作为种子来生成一致的颜色
  const hash = tagName.split('').reduce((acc, char) => {
    return char.charCodeAt(0) + ((acc << 5) - acc);
  }, 0);
  
  // 生成柔和的HSL颜色
  const h = Math.abs(hash % 360);  // 色相 0-360
  const s = 70 + Math.abs(hash % 20);  // 饱和度 70-90%
  const l = 80 + Math.abs(hash % 10);  // 亮度 80-90%
  
  return `hsl(${h}, ${s}%, ${l}%)`;
};
