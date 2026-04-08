export function getBrowserName(userAgent: string) {
  if (userAgent.includes('Edg/')) return 'Edge'
  if (userAgent.includes('OPR/') || userAgent.includes('Opera')) return 'Opera'
  if (userAgent.includes('Firefox/')) return 'Firefox'
  if (
    userAgent.includes('Chrome/') &&
    !userAgent.includes('Edg/') &&
    !userAgent.includes('OPR/')
  ) {
    return 'Chrome'
  }
  if (userAgent.includes('Safari/') && !userAgent.includes('Chrome/')) {
    return 'Safari'
  }
  return '当前浏览器'
}

export function getDeviceInfo(userAgent: string) {
  if (userAgent.includes('iPhone')) return 'iPhone'
  if (userAgent.includes('iPad')) return 'iPad'
  if (userAgent.includes('Android')) return 'Android 设备'
  if (userAgent.includes('Mac OS X')) return 'Mac 设备'
  if (userAgent.includes('Windows')) return 'Windows 电脑'
  if (userAgent.includes('Linux')) return 'Linux 设备'
  return '当前设备'
}
