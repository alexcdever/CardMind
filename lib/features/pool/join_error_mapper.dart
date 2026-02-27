String mapJoinError(String code) {
  switch (code) {
    case 'ADMIN_OFFLINE':
      return '管理员离线，请稍后重试';
    default:
      return '请求失败，请重试';
  }
}
