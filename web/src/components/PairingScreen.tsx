import { QRCodeSVG } from 'qrcode.react'
import type { PairingSession } from '../lib/types'

type PairingScreenProps = {
  browserName: string
  countdown: number
  isLoading: boolean
  session: PairingSession | null
}

export function PairingScreen({
  browserName,
  countdown,
  isLoading,
  session,
}: PairingScreenProps) {
  const isLocalOnlyHost =
    window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'

  return (
    <section className="pairing-shell">
      <div className="pairing-card">
        <div className="pairing-copy-block">
          <h1 className="pairing-title">EasyChat</h1>
        </div>

        <div className="qr-stage pairing-qr-stage">
          {isLoading ? (
            <p className="placeholder-copy">正在生成二维码…</p>
          ) : session ? (
            <div className="pairing-qr-frame">
              <QRCodeSVG value={session.pairingUrl} size={292} bgColor="#ffffff" fgColor="#283042" />
            </div>
          ) : (
            <p className="placeholder-copy">二维码生成失败，请重试。</p>
          )}
        </div>

        <div className="pairing-copy-bottom">
          <p className="pairing-note">请使用手机 App 扫描二维码</p>
          <p className="pairing-subnote">同一 Wi‑Fi 下可直接建立连接</p>
          {isLocalOnlyHost ? (
            <p className="error-copy">当前页面是通过 localhost 打开的，手机无法访问。请改用电脑的局域网地址打开此页面后再扫码。</p>
          ) : null}
        </div>

        <div className="pairing-meta-inline">
          <span>有效期 {countdown}s</span>
          <span>{browserName}</span>
        </div>
      </div>
    </section>
  )
}
