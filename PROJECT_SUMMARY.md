# PROJECT_SUMMARY — Arkham Horror LCG 在线版

> 面向：需要**快速上手并定位问题**的开发/调试人员。
> 所有路径均相对仓库根目录。不确定处标注「待确认」。

---

## 1. 项目定位

- 开源 Web 版《诡镇奇谈 卡牌版 (Arkham Horror LCG)》，非官方实现。
- 支持 1–4 人在线多人、单人多角色、重玩、剧本/战役、卡组导入 (ArkhamDB / arkham.build)。
- 作者：halogenandtoast，镜像：`halogenandtoast/arkham-horror:latest`。
- 默认对外端口：`3000`（Nginx），API 内部：`3002`。

---

## 2. 技术栈

| 层 | 技术 |
|---|---|
| 前端 | Vue 3.5 + TypeScript 5.9 + Vite 7 + Pinia 3 + Vue Router 4 + vue-i18n 11 + axios + GSAP + FontAwesome |
| 前端运行时 | 浏览器必须支持 AVIF（`App.vue` 启动即检测） |
| 后端 | Haskell（GHC 9.12.2，Stack nightly-2025-12-30）+ Yesod Web Framework |
| 后端关键库 | Persistent（PostgreSQL）、yesod-websockets、hedis（Redis）、jose（JWT）、fast-logger、Bugsnag、OpenTelemetry |
| 数据库 | PostgreSQL 14.6，JSONB 存储游戏状态 |
| arkham.build sidecar | 本地源码 `..\arkham.build-main\arkham.build-main`，Docker Compose 下提供 `/build` 前端与 `/build-api` API |
| 迁移工具 | Sqitch（`migrations/` 目录） |
| 消息/房间 | 本地 MVar + WebSocket；分布式用 Redis Pub/Sub（可选） |
| 部署 | Docker + docker-compose / Kamal / Kubernetes（DigitalOcean）+ Nginx |
| CDN 资源 | `https://assets.arkhamhorror.app`（图片 ~2.9GB，可本地替换） |
| arkham.build 卡图 | 默认从同域 `/build-assets` 读取，宿主机目录为仓库同级 `..\arkham-build-assets` |

---

## 3. 目录结构（简化版，只列核心）

```
ArkhamHorror-rebuild-frontend/
├── frontend/                    # Vue3 前端
│   ├── public/
│   │   ├── cards_*.json         # ⚠️ 13 种语言卡牌定义，由脚本生成，勿手改
│   │   └── img/                 # 图片资产（bind mount 到 web 容器 /opt/arkham/src/frontend/dist/img）
│   ├── vite.config.js        # ⚠️ build.copyPublicDir=false，避免与 fetch-images 并发冲突
│   └── src/
│       ├── main.ts              # Vue 启动入口
│       ├── App.vue              # 根组件 + AVIF 检测
│       ├── api.ts               # axios 实例，baseURL = /api/v1
│       ├── router/index.ts      # 路由 + 登录守卫
│       ├── routes/index.ts      # 基础页面路由（登录/注册/首页/Admin）
│       ├── stores/              # Pinia 全局状态
│       │   ├── user.ts          # ★ 登录/token/当前用户
│       │   ├── site_settings.ts # ★ ASSET_HOST 等站点配置
│       │   ├── dbCards.ts       # 卡牌数据库缓存
│       │   ├── cards.ts
│       │   └── settings.ts
│       ├── views/               # 顶层页面（Home/SignIn/SignUp/Admin/Rooms…）
│       ├── components/          # 通用组件 (NavBar/Menu/DropDown/...)
│       ├── arkham/              # ★ 游戏业务主目录
│       │   ├── api.ts           # 游戏相关所有 API 调用
│       │   ├── helpers.ts       # 游戏工具函数（含图片存在性检查）
│       │   ├── i18n.ts
│       │   ├── routes/          # 游戏页面路由
│       │   ├── components/      # 游戏 UI 组件（~93 个）
│       │   └── types/           # 51 个 ts.data.json 解码器/类型
│       └── locales/             # 多语言文案
├── backend/
│   ├── arkham-api/              # ★ 主后端
│   │   ├── app/main.hs          # 入口
│   │   ├── config/
│   │   │   ├── routes           # ★ Yesod 路由总表
│   │   │   └── settings.yml     # 端口/JWT/DB/Redis 配置
│   │   ├── library/
│   │   │   ├── Foundation.hs    # Yesod App、Room/Subscriber、WebSocket
│   │   │   ├── Application.hs   # 中间件、Handler 注册
│   │   │   ├── Config.hs
│   │   │   ├── Auth/JWT.hs      # JWT 签发/校验
│   │   │   ├── Base/Api/Handler # 登录/注册/whoami/账号
│   │   │   ├── Api/Handler/Arkham   # 游戏/卡组/卡牌 API Handler
│   │   │   ├── Entity/          # Persistent 实体定义
│   │   │   │   ├── User.hs
│   │   │   │   └── Arkham/      # Game/Deck/Player/Step/LogEntry
│   │   │   ├── Handler/Health.hs
│   │   │   └── Arkham/          # ⚠️ 游戏规则引擎（152+ 文件 / 42+ 子目录，高风险）
│   │   │       ├── Game.hs       # ~279KB 主状态机
│   │   │       ├── Message.hs    # ~70KB  游戏消息/动作
│   │   │       ├── Scenarios/    # 79 个剧本
│   │   │       ├── Campaigns/    # 战役
│   │   │       ├── Card/、Enemy/、Asset/、Event/、Treachery/、Skill/…
│   │   └── tests/Spec.hs        # Hspec 测试
│   ├── cards-discover/          # 构建时卡牌发现（build-tool）
│   └── validate/                # 卡组校验工具
├── migrations/                  # ⚠️ Sqitch，不可改历史
│   ├── deploy/  revert/  verify/
│   ├── sqitch.plan              # 已有 19 条迁移
│   └── sqitch.conf
├── scripts/                     # 运维 / 资产脚本
│   ├── fetch-assets.sh          # 从 S3/CDN 拉取图片（fetch-images 容器使用）
│   ├── deploy-frontend.ps1      # ★ Windows：本地 build 后热推到 web 容器（无需重建镜像）
│   ├── import-images.ps1        # ★ Windows：从 NAS/本地目录导入 img 包（跳过 CDN 下载）
│   ├── export-arkham-build-assets.ps1 # ★ Windows：导出 arkham.build 本地卡图到桌面 arkham-build-assets
│   └── ...
├── docker-compose.yml           # db:5433 + web:3000 + arkham.build sidecar + fetch-images profile
├── Dockerfile                   # 多阶段：Node 构建前端 → Ubuntu+GHC 构建后端
├── Makefile                     # 部署/镜像/同步常用命令
├── start.sh                     # 容器内：启动 arkham-api + Nginx
├── web-entrypoint.sh            # 自动拼 DATABASE_URL、探测 ASSET_HOST
├── prod.nginxconf / local.nginxconf
├── setup.sql                    # 初始化 DB 用户
├── install.sh                   # 给终端用户一键部署
└── terraform/ · infra/          # K8s + DigitalOcean 基础设施
```

---

## 4. 核心模块职责

### 前端
- [api.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/api.ts)：全局 axios 实例，`baseURL=/api/v1`。
- [stores/user.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/stores/user.ts)：登录、注册、token（localStorage key = `arkham-token`）、`whoami`、`isAdmin`。
- [router/index.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/router/index.ts)：`beforeEach` 守卫，区分 `requiresAuth` / `requiresAdmin` / `guest`。
- [arkham/api.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/arkham/api.ts)：游戏所有 REST 调用；响应用 `ts.data.json` 解码器强校验。
- [arkham/types/](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/arkham/types)：Game/Deck/Card/Message 等类型 + 解码器（51 个）。
- [arkham/components/](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/arkham/components)：游戏界面组件（~93 个）。

### 后端
- [config/routes](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/backend/arkham-api/config/routes)：Yesod 路由声明，所有 API 都从这里开始。
- [Foundation.hs](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/backend/arkham-api/library/Foundation.hs)：`App`（连接池、Room/Subscriber、Bugsnag、Tracer）、`mkYesodData`。
- [Application.hs](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/backend/arkham-api/library/Application.hs)：中间件、日志、`appMain`。
- `Base/Api/Handler/`：认证（`Authentication.hs`、`CurrentUser.hs`、`PasswordReset.hs`、`Account.hs`、`Notifications.hs`）。
- `Api/Handler/Arkham/`：游戏核心 API（`Games.hs`、`Decks.hs`、`Cards.hs`、`Investigators.hs`、`PendingGames.hs`、`Replay.hs`、`Undo.hs`、`Shared.hs`、`Admin/…`、`Game/Bug.hs`、`Game/Debug.hs`）。
- `Entity/`：Persistent schema。`Entity/Arkham/Game.hs` 是 `arkham_games` 表映射（JSONB）。
- `Arkham/`：**游戏规则引擎**（高风险，见第 8 节）。

---

## 5. 启动 / 测试 / 构建

### 一键本地启动（推荐）
```bash
# 根目录
docker compose up -d               # 启 db(5433) + web(3000)
# 访问 http://localhost:3000
```

### 前端开发（热更新）
```bash
cd frontend
npm ci                             # 国内卡可换：npm install --registry=https://registry.npmmirror.com
npm run dev                        # vite 8080，代理 /api /health → 127.0.0.1:3002
```
Vite 脚本（`frontend/package.json`）：`dev`、`serve`、`build`、`tc`（vue-tsc 类型检查）、`digest`。

### 后端开发
```bash
cd backend/arkham-api
# 前提：Stack + GHC 9.12.2 + PostgreSQL
stack exec -- yesod devel          # 3002 端口，自动重编
```

### 后端测试
```bash
cd backend/arkham-api
stack test --flag arkham-horror-backend:library-only --flag arkham-horror-backend:dev
# 测试目录：backend/arkham-api/tests/
```

### 构建镜像 / 部署
- `make v2-deploy` → DigitalOcean K8s（通过 `terraform/kubeconfig`）。
- `make deploy` → Kamal 部署。
- `make sync-images` / `fetch-images` / `generate-manifest`：管理图片资产。
- 完整构建参见 [Dockerfile](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/Dockerfile)（多阶段）。

### 其它实用命令（来自根 Makefile）
- `make db-unstick` / `make db-unstick-kill`：处理 Postgres idle-in-transaction。
- `make count`：统计代码行数。

### 本地 Docker 场景常用脚本（Windows PowerShell，★ 重点）
- **前端热更新**（改完源码秒级上线，无需重建镜像）：
  ```powershell
  pwsh .\scripts\deploy-frontend.ps1
  pwsh .\scripts\deploy-frontend.ps1 -Install   # 首次或 package.json 变动时加
  ```
  内部流程：`npm install` → `npm run build` → 清理容器旧 `dist/assets`+`index.html` → `docker cp` 新产物。
- **离线导入图片包**（跳过 2.9G CDN 下载）：
  ```powershell
  pwsh .\scripts\import-images.ps1 -SourcePath D:\backup\arkham-horror-images
  pwsh .\scripts\import-images.ps1 -SourcePath '\\NAS\share\arkham\img'
  ```
  内部流程：robocopy `/MT:16 /XF *.tmp` 同步到 `frontend/public/img` → `docker compose restart web` → `/health` 自检。
- **反向备份图片包给其它机器**：
  ```powershell
  robocopy .\frontend\public\img C:\Users\$env:USERNAME\Desktop\arkham-horror-images\img /E /MT:16 /XF *.tmp /NFL /NDL
  ```
- **导出 arkham.build 本地卡图**（供 `/build-assets` 离线使用）：
  ```powershell
  pwsh .\scripts\export-arkham-build-assets.ps1
  ```
  内部流程：读取 `frontend/public/img/arkham/cards/*.avif` → 复制到桌面 `arkham-build-assets/optimized` → 复制 arkham.build 需要的卡背图。`docker-compose.yml` 默认将仓库同级 `..\arkham-build-assets` 挂载到 web 容器 `/opt/arkham/build-assets`。

---

## 6. 常见问题 → 代码位置映射（★核心）

| 症状 / 需求 | 先看这里 | 再看这里 |
|---|---|---|
| **登录/注册失败、token 失效** | [stores/user.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/stores/user.ts)、[views/SignIn.vue](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/views/SignIn.vue)、[views/SignUp.vue](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/views/SignUp.vue) | 后端 `library/Base/Api/Handler/Authentication.hs`、`library/Auth/JWT.hs`、`Entity/User.hs` |
| **未登录跳错路由、admin 越权** | [router/index.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/router/index.ts)（`beforeEach`） | [routes/index.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/routes/index.ts) 的 `meta.requiresAuth/requiresAdmin` |
| **忘记密码 / 重置密码** | `views/PasswordReset.vue`、`views/UpdatePassword.vue` | `Base/Api/Handler/PasswordReset.hs`、`Entity/PasswordReset.hs`、迁移 `create_password_resets.sql` |
| **游戏列表、进入游戏、加入房间** | [arkham/api.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/arkham/api.ts) (`fetchGames`/`fetchGame`/`fetchJoinGame`) | `Api/Handler/Arkham/Games.hs`、`PendingGames.hs` |
| **卡牌展示、卡牌定义** | `frontend/public/cards_*.json`（静态）、[stores/dbCards.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/stores/dbCards.ts)、`arkham/components/*Card*` | 后端 `Api/Handler/Arkham/Cards.hs`、`library/Arkham/Card/`、`backend/cards-discover/` |
| **arkham.build 卡牌浏览 / 组卡 sidecar** | `docker-compose.yml` 中 `arkham-build-*` 服务、`prod.nginxconf` 的 `/build` `/build-api` `/build-assets`、`frontend/src/components/NavBar.vue` 卡牌导航 | 本地外部源码 `..\arkham.build-main\arkham.build-main`；默认语言/图片源在其 `frontend/src/utils/i18n.ts`、`constants.ts`、`card-utils.ts`、`.env.example` |
| **卡组导入/校验** | `arkham/api.ts` (`newDeck`/`fetchDecks`/`fetchDeck`)、相关 Vue 组件 | `Api/Handler/Arkham/Decks.hs`、`backend/validate/`、`Entity/Arkham/ArkhamDBDecklist.hs` |
| **arkham.build 组完后导入当前项目** | `frontend/src/arkham/views/ArkhamBuildImport.vue`、`frontend/src/arkham/routes/index.ts` 的 `/decks/import/arkham-build` | arkham.build 本地桥接写入同源 `localStorage` key `arkham-build-import-payload`；导入后复用 `validateDeck` / `newDeck` |
| **游戏状态不同步 / 回放 / 撤销** | `arkham/api.ts` (`fetchGameReplay`/`undo*`)、游戏视图组件 | `Api/Handler/Arkham/Replay.hs`、`Undo.hs`、`Shared.hs`、`Foundation.hs` (Room/Subscriber)、`Entity/Arkham/Step.hs` |
| **WebSocket 断连 / 广播丢失** | 浏览器 DevTools Network WS | `Foundation.hs` 中 `Room`、`Subscriber`、`appGameRooms`、`roomQueueBound`、`gameStream`；Redis `REDIS_CONN` 环境变量 |
| **接口 4xx/5xx 报错** | axios 调用点（`arkham/api.ts`、`stores/user.ts`） | 后端对应 `Api/Handler/...`；全局异常 → Bugsnag 中间件 `Application.hs`；查容器日志 |
| **数据库写入失败 / 约束冲突** | 对应 Handler 的 `runDB`/`insert`/`update` 调用 | `Entity/` 实体定义、`migrations/deploy/*.sql`；Postgres 日志；`make db-unstick` |
| **图片加载失败 / 404** | [App.vue](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/App.vue)（AVIF 检查）、[arkham/helpers.ts](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/src/arkham/helpers.ts) (`checkImageExists`)、`stores/site_settings.ts`（ASSET_HOST） | 当前项目图片：`web-entrypoint.sh` 的 ASSET_HOST 自动探测、`image-manifest.json`、`scripts/fetch-assets.sh`、`scripts/import-images.ps1`；arkham.build 图片：`/build-assets/optimized/*.avif`，宿主机 `..\arkham-build-assets`，导出脚本 `scripts/export-arkham-build-assets.ps1` |
| **本地改完前端想立刻生效**（Windows Docker） | `scripts/deploy-frontend.ps1` | [vite.config.js](file:///c:/Users/29298/Desktop/ArkhamHorror-rebuild-frontend/frontend/vite.config.js) 的 `build.copyPublicDir: false`；容器名 `arkhamhorror-rebuild-frontend-web-1` |
| **管理后台 / 房间监控** | `views/Admin.vue`、`views/Rooms.vue`、`components/admin/` | `Api/Handler/Arkham/Admin/Metrics.hs`、路由中的 `/api/v1/admin/*` |
| **多语言文案缺失** | `frontend/src/locales/messages.ts` 及各语言目录；`arkham/i18n.ts` | 卡牌翻译在 `cards_<lang>.json` |
| **规则/战役相关 bug** | `Arkham/Scenarios/<剧本名>.hs`、`Arkham/Campaigns/<战役>.hs` | `Arkham/Game.hs`、`Arkham/Message.hs`（⚠️ 高风险） |
| **卡牌机制（敌人/资产/事件/诡计）行为异常** | `Arkham/Enemy/Cards/*.hs` 等按卡类分类目录 | `Arkham/Matcher.hs`、`Arkham/Helpers/` |

---

## 7. 主要调用链

### 7.1 登录
```
SignIn.vue
  → stores/user.ts · authenticate()
  → POST /api/v1/authenticate      (axios, baseURL=/api/v1)
  → Yesod route ApiV1AuthenticationR (backend/arkham-api/config/routes)
  → Base/Api/Handler/Authentication.hs
  → 校验密码 (Entity/User.hs, bcrypt) → JWT 签发 (Auth/JWT.hs)
  ← { token }
  → localStorage 'arkham-token' + axios Authorization header
  → GET /api/v1/whoami → Base/Api/Handler/CurrentUser.hs
```

### 7.2 新建 / 推进游戏
```
Home / NewGame 组件
  → arkham/api.ts · newGame(params)
  → POST /api/v1/arkham/games → Api/Handler/Arkham/Games.hs
  → runDB: insert arkham_games (current_data/choices/log 均 JSONB)
  → 在 Foundation.hs 的 appGameRooms 创建 Room（MVar/TBQueue/Redis channel）
  ← Game
推进一步：
  Game 组件选项
  → arkham/api.ts · updateGame(gameId, choice)
  → PUT /api/v1/arkham/games/{id}
  → Handler 读 JSONB → 调 Arkham.Game/Message 规则引擎 → 写回 JSONB
  → 追加 arkham_log_entries；广播到 Room 订阅者（WS/Redis）
  ← Game
```

### 7.3 整体调用链
```
浏览器 (Vue + axios + WS)
  ↓ /api/* · /health · /build/* · /build-api/* · /build-assets/*
Nginx (prod.nginxconf) -- 同容器
  ├─ /api, /health → 3002
  ├─ /build → arkham-build-web:3000
  ├─ /build-api → arkham-build-api:8686
  ├─ /build-assets → /opt/arkham/build-assets
  ↓
arkham-api (Yesod Warp)
  ├─ routes → Handler
  ├─ Persistent (SqlBackend) → PostgreSQL (JSONB)
  ├─ yesod-websockets / hedis → Redis Pub/Sub（可选）
  ├─ Bugsnag 中间件
  └─ OpenTelemetry Tracer
```

---

## 8. 风险区域 / 禁止随意修改

### 严格禁改（或必须充分评估）
1. **`backend/arkham-api/library/Arkham/`** — 152+ 文件、42+ 子目录的游戏规则引擎。
   - `Game.hs`（~279KB）、`Message.hs`（~70KB）、`Scenarios/`（79 个）、`Campaigns/`：改动极易引发跨剧本回归。
   - 目录内部高度模式化，**不要跨目录大规模重构 / 格式化**。
2. **`migrations/`**（Sqitch）— 历史迁移不可删改、不可重排；新增必须成对写 `deploy/revert/verify`。
3. **`backend/arkham-api/library/Entity/`** 特别是 `Entity/Arkham/Game.hs`：JSONB 列 `current_data`/`choices`/`log` 结构变化需同时改规则引擎 + 迁移。
4. **`backend/arkham-api/config/routes`** — 增删路由必须同步 Handler 与 `Application.hs` 分发（Yesod TH 生成）。
5. **`frontend/public/cards_*.json`** — 由卡牌抓取脚本生成（待确认脚本位置，可能在 `backend/cards-discover/` 或外部），13 种语言，不得手改。
6. **锁文件**：`backend/stack.yaml.lock`、`backend/cabal.project.local`、`flake.lock`、`frontend/package-lock.json`。
7. **Dockerfile、`docker-compose.yml`、`prod.nginxconf`、`web-entrypoint.sh`、`start.sh`** — 生产/本地部署链路，改动需同步验证 Docker Compose、Kamal、K8s。`prod.nginxconf` 还承载 arkham.build 的 `/build`、`/build-api`、`/build-assets` 路由。
8. **`terraform/` · `config/deploy.yml` · `infra/`** — 基础设施代码，改动有费用/可用性风险。
9. **`frontend/vite.config.js` 中 `build.copyPublicDir: false`** — 2.6G 图片由 bind mount 接管，开启 copy 会在 `vite build` 期间试图拷贝 `public/img`，与 fetch-images 并发下载的 `.tmp` 冲突，导致 build 崩溃或产物爆胀到 2G+。
10. **仓库同级 `..\arkham.build-main\arkham.build-main` 与 `..\arkham-build-assets`** — arkham.build sidecar 与本地卡图目录，不属于当前仓库 git 管理；迁移机器时需要一起带走，并保持 docker-compose 中的相对路径可用。

### 安全可改（普通开发对象）
- `frontend/src/views/` · `frontend/src/components/` · `frontend/src/arkham/components/`（UI）
- `frontend/src/stores/`（状态，注意 API 契约）
- `frontend/src/locales/`（文案）
- `backend/arkham-api/library/Api/Handler/…` · `Base/Api/Handler/…` 的业务逻辑（保留路由/DB 契约）
- 配置文件的非关键字段（`settings.yml` 中 log 开关等）

### 待确认
- `frontend/public/cards_*.json` 的生成脚本入口（README/Makefile 未直接给出命令）。
- `backend/cards-discover/` 与 `backend/validate/` 的运行方式（`cabal run` or build-tool）。
- 开发环境是否必须 Stack，能否纯 `cabal build`（`cabal.project` 存在）。

---
