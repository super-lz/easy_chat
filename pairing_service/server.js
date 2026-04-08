import { existsSync, readFileSync } from 'node:fs'
import { createServer } from 'node:http'
import { dirname, resolve } from 'node:path'
import { randomUUID } from 'node:crypto'
import { fileURLToPath } from 'node:url'

loadEnvFiles()

const PORT = Number(process.env.PORT || 8787)
const ORIGIN = process.env.ALLOW_ORIGIN || '*'
const PUBLIC_SERVER_URL = process.env.PUBLIC_SERVER_URL || ''
const SESSION_TTL_MS = 1000 * 60 * 3
const VERIFICATION_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

const sessions = new Map()

function loadEnvFiles() {
  const rootDir = dirname(fileURLToPath(import.meta.url))
  const envFiles = ['.env', '.env.local']

  for (const name of envFiles) {
    const fullPath = resolve(rootDir, name)
    if (!existsSync(fullPath)) continue

    const content = readFileSync(fullPath, 'utf8')
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue

      const separatorIndex = trimmed.indexOf('=')
      if (separatorIndex <= 0) continue

      const key = trimmed.slice(0, separatorIndex).trim()
      if (!key || process.env[key] !== undefined) continue

      let value = trimmed.slice(separatorIndex + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }

      process.env[key] = value
    }
  }
}

function createVerificationCode(length = 4) {
  let code = ''
  for (let index = 0; index < length; index += 1) {
    const randomIndex = Math.floor(Math.random() * VERIFICATION_CODE_ALPHABET.length)
    code += VERIFICATION_CODE_ALPHABET[randomIndex]
  }
  return code
}

function createSession(browserName = '当前浏览器', deviceInfo = '当前设备') {
  const sessionId = randomUUID()
  const challenge = randomUUID().replaceAll('-', '').slice(0, 24)
  const expiresAt = Date.now() + SESSION_TTL_MS
  const session = {
    sessionId,
    challenge,
    expiresAt,
    status: 'waiting',
    browserName,
    deviceInfo,
    verificationCode: createVerificationCode(),
    phoneEndpoint: null,
    subscribers: new Set(),
  }

  sessions.set(sessionId, session)
  return session
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': ORIGIN,
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Cache-Control': 'no-store',
  })
  response.end(JSON.stringify(payload))
}

function sendSseEvent(response, event, payload) {
  response.write(`event: ${event}\n`)
  response.write(`data: ${JSON.stringify(payload)}\n\n`)
}

function broadcast(session, event, payload) {
  for (const subscriber of session.subscribers) {
    sendSseEvent(subscriber, event, payload)
  }
}

function parseJsonBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = []

    request.on('data', (chunk) => chunks.push(chunk))
    request.on('end', () => {
      try {
        const text = Buffer.concat(chunks).toString('utf8')
        resolve(text ? JSON.parse(text) : {})
      } catch (error) {
        reject(error)
      }
    })
    request.on('error', reject)
  })
}

function getSession(sessionId) {
  const session = sessions.get(sessionId)

  if (!session) {
    return { error: 'Session not found', statusCode: 404 }
  }

  if (session.expiresAt <= Date.now()) {
    sessions.delete(sessionId)
    return { error: 'Session expired', statusCode: 410 }
  }

  return { session }
}

setInterval(() => {
  const now = Date.now()

  for (const [sessionId, session] of sessions.entries()) {
    if (session.expiresAt <= now) {
      broadcast(session, 'expired', { sessionId })
      for (const subscriber of session.subscribers) {
        subscriber.end()
      }
      sessions.delete(sessionId)
    }
  }
}, 1000 * 15)

const server = createServer(async (request, response) => {
  const url = new URL(request.url || '/', `http://${request.headers.host}`)

  if (request.method === 'OPTIONS') {
    response.writeHead(204, {
      'Access-Control-Allow-Origin': ORIGIN,
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    })
    response.end()
    return
  }

  if (request.method === 'GET' && url.pathname === '/health') {
    sendJson(response, 200, { ok: true })
    return
  }

  if (request.method === 'POST' && url.pathname === '/api/pairings') {
    const body = await parseJsonBody(request).catch(() => ({}))
    const browserName =
      typeof body.browserName === 'string' && body.browserName.trim().length > 0
        ? body.browserName.trim().slice(0, 48)
        : '当前浏览器'
    const deviceInfo =
      typeof body.deviceInfo === 'string' && body.deviceInfo.trim().length > 0
        ? body.deviceInfo.trim().slice(0, 48)
        : '当前设备'
    const session = createSession(browserName, deviceInfo)
    const publicServerUrl = PUBLIC_SERVER_URL || `http://${request.headers.host}`
    const pairingUrl = `easychat://pair?sessionId=${session.sessionId}&challenge=${session.challenge}&serverUrl=${encodeURIComponent(
      publicServerUrl,
    )}&browserName=${encodeURIComponent(session.browserName)}&deviceInfo=${encodeURIComponent(
      session.deviceInfo,
    )}&verificationCode=${encodeURIComponent(session.verificationCode)}`

    sendJson(response, 201, {
      sessionId: session.sessionId,
      challenge: session.challenge,
      expiresAt: session.expiresAt,
      status: session.status,
      deviceInfo: session.deviceInfo,
      browserName: session.browserName,
      verificationCode: session.verificationCode,
      pairingUrl,
    })
    return
  }

  if (request.method === 'GET' && url.pathname.startsWith('/api/pairings/')) {
    const [, , , sessionId, action] = url.pathname.split('/')
    const { session, error, statusCode } = getSession(sessionId)

    if (!session) {
      sendJson(response, statusCode, { error })
      return
    }

    if (action === 'events') {
      response.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'Access-Control-Allow-Origin': ORIGIN,
      })
      response.write('\n')
      session.subscribers.add(response)
      sendSseEvent(response, 'status', {
        sessionId: session.sessionId,
        status: session.status,
        deviceInfo: session.deviceInfo,
        browserName: session.browserName,
        verificationCode: session.verificationCode,
        phoneEndpoint: session.phoneEndpoint,
      })

      request.on('close', () => {
        session.subscribers.delete(response)
      })
      return
    }

    sendJson(response, 200, {
      sessionId: session.sessionId,
      challenge: session.challenge,
      expiresAt: session.expiresAt,
      status: session.status,
      deviceInfo: session.deviceInfo,
      browserName: session.browserName,
      verificationCode: session.verificationCode,
      phoneEndpoint: session.phoneEndpoint,
    })
    return
  }

  if (request.method === 'POST' && url.pathname.match(/^\/api\/pairings\/[^/]+\/register$/)) {
    const sessionId = url.pathname.split('/')[3]
    const { session, error, statusCode } = getSession(sessionId)

    if (!session) {
      sendJson(response, statusCode, { error })
      return
    }

    try {
      const body = await parseJsonBody(request)

      if (body.challenge !== session.challenge) {
        sendJson(response, 401, { error: 'Invalid challenge' })
        return
      }

      session.status = 'phone_registered'
      session.phoneEndpoint = {
        deviceName: body.deviceName || 'Phone',
        phoneIp: body.phoneIp,
        phonePort: body.phonePort,
        token: body.token,
        protocolVersion: body.protocolVersion || 1,
      }

      broadcast(session, 'status', {
        sessionId: session.sessionId,
        status: session.status,
        phoneEndpoint: session.phoneEndpoint,
      })

      sendJson(response, 200, {
        ok: true,
        status: session.status,
        phoneEndpoint: session.phoneEndpoint,
      })
    } catch {
      sendJson(response, 400, { error: 'Invalid JSON payload' })
    }
    return
  }

  sendJson(response, 404, { error: 'Not found' })
})

server.listen(PORT, () => {
  console.log(`pairing_service listening on http://localhost:${PORT}`)
})
