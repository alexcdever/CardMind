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
      required: '网络ID不能为空',
      invalidFormat: '网络ID格式不正确'
    },
    nickname: {
      required: '昵称不能为空',
      tooShort: '昵称长度不能少于1个字符',
      tooLong: '昵称不能超过50个字符'
    }
  }
  
  return messages[field]?.[errorType] || `${field}格式不正确`
}