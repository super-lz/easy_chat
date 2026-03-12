import type { AppSettings, Message, PhoneEndpoint } from './types'

const STORED_ENDPOINT_KEY = 'easy-chat:last-endpoint'
const SETTINGS_KEY = 'easy-chat:settings'

export const defaultSettings: AppSettings = {
  rememberConnection: true,
  autoReconnect: true,
  sendWithEnter: true,
  showSystemMessages: true,
}

export const initialMessages: Message[] = [
  {
    id: 'm1',
    sender: 'system',
    type: 'text',
    content: '打开手机 App 扫描二维码，连接成功后就可以像聊天一样互发消息和文件',
  },
]

export function persistEndpoint(nextEndpoint: PhoneEndpoint) {
  window.localStorage.setItem(STORED_ENDPOINT_KEY, JSON.stringify(nextEndpoint))
}

export function clearStoredEndpoint() {
  window.localStorage.removeItem(STORED_ENDPOINT_KEY)
}

export function restoreStoredEndpoint() {
  const raw = window.localStorage.getItem(STORED_ENDPOINT_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as PhoneEndpoint
  } catch {
    clearStoredEndpoint()
    return null
  }
}

export function persistSettings(nextSettings: AppSettings) {
  window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(nextSettings))
}

export function restoreSettings() {
  const raw = window.localStorage.getItem(SETTINGS_KEY)
  if (!raw) return defaultSettings
  try {
    return { ...defaultSettings, ...(JSON.parse(raw) as Partial<AppSettings>) }
  } catch {
    return defaultSettings
  }
}
