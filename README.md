# Easy Chat

手机 App 与电脑网页在同一局域网内直连聊天和传文件。

消息和文件内容不经过配对服务器，配对服务器只负责扫码后的会话引导。

## 项目结构

- `pairing_service`: 配对服务
- `web`: 电脑网页
- `mobile_app`: Flutter 手机 App

## 本地启动

```bash
cd /Users/leazer/Documents/leazer/easy_chat/pairing_service
node server.js
```

```bash
cd /Users/leazer/Documents/leazer/easy_chat/web
npm install
npm run dev -- --host 0.0.0.0
```

```bash
cd /Users/leazer/Documents/leazer/easy_chat/mobile_app
flutter run
```

## 使用流程

1. 电脑浏览器打开 Vite 输出里的局域网地址，例如 `http://192.168.29.50:5173`
2. 手机和电脑连接同一 Wi‑Fi
3. 手机打开 App，扫描网页二维码
4. 手机确认后启动本地服务
5. 网页直连手机，之后互发消息和文件

注意：

- 真机调试时不要用 `localhost` 打开网页
- 扫码确认页里的 `Server` 应该是电脑局域网 IP，不应该是 `localhost`

## 验证

```bash
cd /Users/leazer/Documents/leazer/easy_chat/web
npm run build
```

```bash
cd /Users/leazer/Documents/leazer/easy_chat/mobile_app
flutter analyze
```
