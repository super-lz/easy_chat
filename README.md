# EasyChat

手机 App 与电脑网页在同一局域网内直连聊天和传文件。

消息和文件内容不经过配对服务，配对服务只负责扫码后的会话引导。

## 项目结构

- `pairing_service`: 配对服务
- `web`: 电脑网页
- `mobile_app`: Flutter 手机 App

## 本地开发

本地开发默认不需要额外配置。

直接启动：

根目录一键启动 `pairing_service + web`：

```bash
npm run dev
```

如果提示端口已被占用，说明你本地已经有旧的开发进程在运行。
这时直接复用已有服务，或者先结束旧进程后再重新执行。

分别启动：

```bash
npm run dev:pairing
```

```bash
npm run dev:web
```

启动手机端：

```bash
cd mobile_app
flutter run
```

如果你没有改过端口或域名，就不用创建 `.env.local`。

### 本地使用要求

- 电脑浏览器必须打开 Vite 输出的局域网地址，例如 `http://192.168.29.50:5173`
- 不要用 `localhost` 给手机扫码
- 手机和电脑必须在同一 Wi‑Fi
- iPhone 需要允许“本地网络”权限

## 线上部署

线上环境只需要关心这几个变量：

- Web：
  - `VITE_PAIRING_API_URL`
- 配对服务：
  - `PORT`
  - `ALLOW_ORIGIN`
  - `PUBLIC_SERVER_URL`

如果你只是本地开发，可以跳过下面这部分。

### 方案 A：Web 和 API 同域

例如：

- Web: `https://easychat.example.com`
- Pairing API: `https://easychat.example.com/api`

配置如下：

`web`

```env
VITE_PAIRING_API_URL=
```

`pairing_service`

```env
PORT=8787
ALLOW_ORIGIN=https://easychat.example.com
PUBLIC_SERVER_URL=https://easychat.example.com
```

说明：

- 这是最简单的方式
- Web 继续走同源 `/api`
- 线上反代把 `/api` 转发到配对服务即可

### 方案 B：Web 和 API 分域

例如：

- Web: `https://app.example.com`
- Pairing API: `https://pair.example.com`

配置：

`web`

```env
VITE_PAIRING_API_URL=https://pair.example.com
```

`pairing_service`

```env
PORT=8787
ALLOW_ORIGIN=https://app.example.com
PUBLIC_SERVER_URL=https://pair.example.com
```

## 常用命令

Web 构建：

```bash
cd web
npm run build
```

手机端检查：

```bash
cd mobile_app
flutter analyze
```

## 进阶配置

只有在你要改本地默认端口、改代理目标，或者做线上部署时，才需要看这里。

`pairing_service/.env.local`

```env
PORT=8787
ALLOW_ORIGIN=*
PUBLIC_SERVER_URL=
```

`web/.env.local`

```env
VITE_PAIRING_API_URL=
PAIRING_SERVICE_PROXY_TARGET=http://127.0.0.1:8787
```

简化理解：

- 本地开发：通常不用配，直接跑 `npm run dev`
- 同域部署：通常只需要配 `PUBLIC_SERVER_URL`
- 分域部署：`web` 配 `VITE_PAIRING_API_URL`，`pairing_service` 配 `ALLOW_ORIGIN` 和 `PUBLIC_SERVER_URL`
