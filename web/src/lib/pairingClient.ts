import type { PairingSession, PhoneEndpoint } from './types'

export type PairingStatusPayload = {
  status: PairingSession['status']
  phoneEndpoint?: PhoneEndpoint
}

type PairingSubscriptionHandlers = {
  onStatus: (payload: PairingStatusPayload) => void
  onExpired: () => void
  onError: () => void
}

export async function createPairingSession(
  baseUrl: string,
  browserName: string,
  deviceInfo: string,
) {
  const response = await fetch(`${baseUrl}/api/pairings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ browserName, deviceInfo }),
  })

  if (!response.ok) {
    throw new Error('创建配对会话失败')
  }

  return (await response.json()) as PairingSession
}

export function subscribeToPairingSession(baseUrl: string, sessionId: string, handlers: PairingSubscriptionHandlers) {
  const source = new EventSource(`${baseUrl}/api/pairings/${sessionId}/events`)
  let isExpectedClose = false

  source.addEventListener('status', (event) => {
    handlers.onStatus(JSON.parse((event as MessageEvent).data) as PairingStatusPayload)
  })

  source.addEventListener('expired', () => {
    isExpectedClose = true
    source.close()
    handlers.onExpired()
  })

  source.onerror = () => {
    if (isExpectedClose) return
    source.close()
    handlers.onError()
  }

  return () => {
    isExpectedClose = true
    source.close()
  }
}
