export function getBrowserName(userAgent: string) {
  if (userAgent.includes('Mac OS X')) return 'Mac 浏览器'
  if (userAgent.includes('Windows')) return 'Windows 浏览器'
  return '当前浏览器'
}
