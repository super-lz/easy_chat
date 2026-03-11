# 网页端

EasyChat 的电脑网页端，基于 React + Vite。

## 启动

```bash
npm run dev -- --host 0.0.0.0
```

本地默认不需要额外配置。

## 构建

```bash
npm run build
```

## 进阶配置

只有在你要改本地代理目标或做线上部署时，才需要 `web/.env.local`：

```env
VITE_PAIRING_API_URL=
PAIRING_SERVICE_PROXY_TARGET=http://127.0.0.1:8787
```

说明：

- 本地开发时通常不用改这里
- 本地默认会把 `/api` 转发到 `http://127.0.0.1:8787`
- 只有前后端分域部署时，才需要配置 `VITE_PAIRING_API_URL`
