/**
 * 验证工具函数
 */

// UUID格式正则表达式
export const networkRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

/**
 * 验证字符串长度
 * @param value 要验证的值
 * @param min 最小长度
 * @param max 最大长度
 * @returns 验证结果
 */
export const validateLength = (value: string, min: number = 0, max: number = Infinity): boolean => {
  const length = value.length
  return length >= min && length <= max
}

/**
 * 验证卡片标题
 * @param title 标题
 * @returns 验证结果
 */
export const validateCardTitle = (title: string): boolean => {
  // 标题最多20个字符，允许为空
  return validateLength(title, 0, 20)
}

/**
 * 验证卡片内容
 * @param content 内容
 * @returns 验证结果
 */
export const validateCardContent = (content: string): boolean => {
  // 内容最多2000个字符，不能为空
  return validateLength(content, 1, 2000)
}

/**
 * 验证设备昵称
 * @param nickname 昵称
 * @returns 验证结果
 */
export const validateDeviceNickname = (nickname: string): boolean => {
  // 昵称1-50个字符
  return validateLength(nickname, 1, 50)
}

/**
 * 清理输入字符串
 * @param input 输入字符串
 * @returns 清理后的字符串
 */
export const sanitizeInput = (input: string): string => {
  // 去除前后空白字符
  return input.trim()
}

/**
 * 处理验证错误信息
 * @param field 字段名称
 * @param errorType 错误类型
 * @returns 错误消息
 */
export const handleValidationError = (
  field: string,
  errorType: 'required' | 'tooShort' | 'tooLong' | 'invalidFormat'
): string => {
  const messages: Record<string, Record<string, string>> = {
    title: {
      required: '标题不能为空',
      tooLong: '标题不能超过20个字符'
    },
    content: {
      required: '内容不能为空',
      tooLong: '内容不能超过2000个字符'
    },
    networkId: {
    required: '访问码不能为空',
    invalidFormat: '访问码格式不正确'
  },
    nickname: {
      required: '昵称不能为空',
      tooShort: '昵称长度不能少于1个字符',
      tooLong: '昵称不能超过50个字符'
    }
  }
  
  return messages[field]?.[errorType] || `${field}格式不正确`
}

/**
 * 验证访问码格式
 * 验证是否为有效的Base64编码字符串，并且解码后包含必要的网络连接信息
 */
export const validateAccessCode = (accessCode: string): boolean => {
  if (!accessCode || accessCode.length < 20 || accessCode.length > 200) {
    return false;
  }

  // 验证是否为有效的URL安全Base64格式
  const base64Regex = /^[A-Za-z0-9-_]+={0,2}$/;
  if (!base64Regex.test(accessCode)) {
    return false;
  }

  try {
    // 尝试解码并验证内容结构
    const padded = accessCode + '='.repeat((4 - accessCode.length % 4) % 4);
    const decoded = decodeURIComponent(atob(padded.replace(/-/g, '+').replace(/_/g, '/')));
    const data = JSON.parse(decoded);

    // 验证解码后的数据是否包含必要字段
    return data.address && typeof data.address === 'string' &&
           data.timestamp && typeof data.timestamp === 'number' &&
           data.randomCode && typeof data.randomCode === 'string';
  } catch (error) {
    // 解码失败或数据结构不正确
    return false;
  }
};