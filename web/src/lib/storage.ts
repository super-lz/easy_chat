import type { AppSettings, Message, PhoneEndpoint } from './types'

const STORED_ENDPOINT_KEY = 'easy-chat:last-endpoint'
const SETTINGS_KEY = 'easy-chat:settings'
const ENDPOINT_TTL_MS = 24 * 60 * 60 * 1000

type StoredEndpointRecord = {
  endpoint: PhoneEndpoint
  expiresAt: number
}

function logStorageDebug(action: string, detail?: unknown) {
  if (!import.meta.env.DEV) return
  console.info(`[easy-chat][storage] ${action}`, detail)
}

export const defaultSettings: AppSettings = {
  rememberConnection: true,
  autoReconnect: true,
  sendWithEnter: true,
  showSystemMessages: true,
}

export const initialMessages: Message[] = []

export function persistEndpoint(nextEndpoint: PhoneEndpoint) {
  const serialized = JSON.stringify({
    endpoint: nextEndpoint,
    expiresAt: Date.now() + ENDPOINT_TTL_MS,
  } satisfies StoredEndpointRecord)
  logStorageDebug('persist endpoint', nextEndpoint)

  try {
    window.localStorage.setItem(STORED_ENDPOINT_KEY, serialized)
  } catch {
    // Ignore storage write failures and keep the in-memory session usable.
  }

  try {
    window.sessionStorage.setItem(STORED_ENDPOINT_KEY, serialized)
  } catch {
    // Ignore storage write failures and keep the in-memory session usable.
  }
}

export function clearStoredEndpoint() {
  logStorageDebug('clear endpoint')
  try {
    window.localStorage.removeItem(STORED_ENDPOINT_KEY)
  } catch {
    // Ignore storage removal failures.
  }

  try {
    window.sessionStorage.removeItem(STORED_ENDPOINT_KEY)
  } catch {
    // Ignore storage removal failures.
  }
}

export function restoreStoredEndpoint() {
  const rawValues = [
    (() => {
      try {
        return window.localStorage.getItem(STORED_ENDPOINT_KEY)
      } catch {
        return null
      }
    })(),
    (() => {
      try {
        return window.sessionStorage.getItem(STORED_ENDPOINT_KEY)
      } catch {
        return null
      }
    })(),
  ]

  for (const raw of rawValues) {
    if (!raw) continue
    try {
      const parsed = JSON.parse(raw) as StoredEndpointRecord | PhoneEndpoint
      const endpoint = unwrapStoredEndpoint(parsed)
      if (!endpoint) {
        clearStoredEndpoint()
        return null
      }
      logStorageDebug('restore endpoint hit', endpoint)
      persistEndpoint(endpoint)
      return endpoint
    } catch {
      clearStoredEndpoint()
      return null
    }
  }

  logStorageDebug('restore endpoint miss')
  return null
}

export function persistSettings(nextSettings: AppSettings) {
  logStorageDebug('persist settings', nextSettings)
  window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(nextSettings))
}

export function restoreSettings() {
  const raw = window.localStorage.getItem(SETTINGS_KEY)
  if (!raw) {
    logStorageDebug('restore settings default', defaultSettings)
    return defaultSettings
  }
  try {
    const settings = {
      ...defaultSettings,
      ...(JSON.parse(raw) as Partial<AppSettings>),
      rememberConnection: true,
    }
    logStorageDebug('restore settings hit', settings)
    return settings
  } catch {
    logStorageDebug('restore settings parse failed')
    return defaultSettings
  }
}

function unwrapStoredEndpoint(value: StoredEndpointRecord | PhoneEndpoint) {
  if (isStoredEndpointRecord(value)) {
    if (value.expiresAt <= Date.now()) {
      logStorageDebug('restore endpoint expired', value.endpoint)
      return null
    }
    return value.endpoint
  }

  if (isPhoneEndpoint(value)) {
    logStorageDebug('restore endpoint legacy', value)
    return value
  }

  return null
}

function isStoredEndpointRecord(value: unknown): value is StoredEndpointRecord {
  return (
    typeof value === 'object' &&
    value !== null &&
    'endpoint' in value &&
    'expiresAt' in value &&
    typeof (value as { expiresAt?: unknown }).expiresAt === 'number' &&
    isPhoneEndpoint((value as { endpoint?: unknown }).endpoint)
  )
}

function isPhoneEndpoint(value: unknown): value is PhoneEndpoint {
  return (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { deviceName?: unknown }).deviceName === 'string' &&
    typeof (value as { phoneIp?: unknown }).phoneIp === 'string' &&
    typeof (value as { phonePort?: unknown }).phonePort === 'number' &&
    typeof (value as { token?: unknown }).token === 'string' &&
    typeof (value as { protocolVersion?: unknown }).protocolVersion === 'number'
  )
}
