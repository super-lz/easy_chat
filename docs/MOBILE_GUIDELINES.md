# EasyChat Mobile Guidelines

## 目的

这份文档记录当前 `mobile_app` 的开发规范。

目标：
- 保持目录结构稳定
- 避免页面、状态、服务混写
- 让后续新增页面和功能时有统一落点
- 降低重构和替换 UI 的成本

## 当前目录规范

`mobile_app/lib` 当前按下面的层级组织：

- `pages/`
- `components/`
- `models/`
- `provider/`
- `service/`
- `utils/`
- `route/`
- `theme/`
- `common/`

### pages

规则：
- 页面入口放在 `pages/` 下
- 不要直接平铺 `xxx_page.dart`
- 每个页面使用独立目录

示例：
- `pages/home/home_page.dart`
- `pages/scanner/scanner_page.dart`
- `pages/confirm/confirm_page.dart`
- `pages/chat/chat_page.dart`

页面目录下可以继续放：
- `components/`
- 当前页面私有的局部组件
- 当前页面强相关的小块 UI

如果某个组件只服务一个页面，优先放到该页面目录下，不要一开始就提升到全局 `components/`。

### components

这里放跨页面复用组件。

规则：
- 只放通用展示组件
- 不放页面专属业务逻辑
- 不直接处理路由跳转
- 不直接承担全局状态编排

### models

规则：
- 一个 model 一个文件
- 不保留聚合型 `chat_models.dart` 这类总出口文件
- model 需要支持值比较和后续不可变更新

当前要求：
- model 使用 `equatable`
- model 提供 `copyWith`

适用对象：
- `ChatMessage`
- `PairingPayload`
- `ConnectionCache`
- 后续新增的状态对象、协议对象、表单对象

### provider

规则：
- 全局状态统一放 `provider/`
- 一个业务模块对应一个 provider 文件
- provider 文件尽量以 `pprovider` 结尾

职责：
- 消费 `service`
- 组合业务状态
- 对接页面 UI
- 对外暴露页面可直接使用的状态和动作

不要把底层 API 调用细节直接放进页面里。

### service

规则：
- `service/` 只负责底层调用和外部交互
- 一个业务能力一个 service 文件

适合放在这里的内容：
- HTTP API 调用
- 本地 WebSocket 服务
- 本地持久化
- 文件系统存取

不适合放在这里的内容：
- 页面级状态
- UI 展示判断
- 路由跳转

### utils

规则：
- 工具文件尽量使用类的静态方法
- 不要在文件顶层暴露大量裸函数

推荐形式：
- `NetworkTools.detectBestLocalIp(...)`
- `FormatterTools.formatBytes(...)`

这样可以保持调用风格一致，也更便于后续扩展。

### route

规则：
- `route/` 只负责路由定义、observer、redirect、guard
- 不要在 router 文件里堆业务跳转方法
- 不要在 router 文件里做 provider 注入

当前拆分：
- `app_router.dart`：路由表
- `route_paths.dart`：路径常量

页面跳转应在页面内部完成，页面自己依赖 `go_router` 和 `route_paths.dart`。

### theme

规则：
- 全局主题统一放 `theme/`
- 页面里不要到处散落大段主题定义

### common

规则：
- 静态配置和公共常量统一放 `common/`
- 不要把应用名、默认端口、缓存 key 写死在多个文件里

适合放在这里的内容：
- app name
- 默认端口
- storage key
- 固定枚举文案

## 状态管理规范

### 全局状态

全局状态必须统一在应用根部注入。

当前要求：
- 使用 `provider`
- 在 `pages/app.dart` 中统一注入
- 使用 `MultiProvider`
- provider 列表做成数组，便于后续新增

不允许：
- 在各个页面里重复做全局 provider 注入
- 把全局 provider 放到 router 文件里

### 页面消费状态

规则：
- 页面内部使用 `context.watch<T>()` / `context.read<T>()`
- 不要为了全局状态在每个页面外再包一层 `Consumer`

可以接受的局部状态：
- 扫码页的 `_hasScanned`
- 临时折叠状态
- 局部选中状态
- 只影响单个组件的小交互状态

局部状态优先放在组件内部，不要无意义提升到全局。

## 路由规范

### 应用壳

当前应用壳文件：
- `pages/app.dart`

规则：
- 应用壳负责注入全局 provider
- 应用壳负责挂载 `MaterialApp.router`
- 应用壳可以做启动期的全局恢复逻辑

### 页面跳转

规则：
- 页面自己决定业务跳转
- 页面通过 `go_router` 执行跳转
- 统一使用 `RoutePaths`

避免在 router 层做：
- `openScanner`
- `showChat`
- `popOrHome`
- 其他业务语义方法

## 代码风格规范

### 页面文件

页面文件应该：
- 以页面结构为主
- 使用 provider 读取状态
- 把过重的展示块拆到页面私有组件

当页面文件明显变长时：
- 先考虑拆到 `pages/<page>/components/`
- 再考虑是否需要提升为全局 `components/`

### 模型更新

当状态或数据需要更新时：
- 优先使用 `copyWith`
- 避免随手拼临时 map 或散乱字段替换

### 常量

规则：
- 不要在 provider、page、service 里重复硬编码常量
- 统一提升到 `common/app_constants.dart`

## 后续开发默认执行

后续在 `mobile_app` 开发时，默认遵循以下原则：

- 新页面放到 `pages/<page>/`
- 新页面的私有组件优先放到对应页面目录
- 新 model 单独一个文件，并使用 `Equatable + copyWith`
- 新全局状态统一走 `provider/`
- 新底层调用统一走 `service/`
- 新工具优先使用静态工具类
- router 只做路由定义和拦截，不写业务跳转逻辑
- 全局 provider 只在应用壳统一注入

