# AGENTS.md — 协作与修改约束

> 面向：在本仓库中进行任何代码修改的 Agent / 开发者。
> 本文件是**行为规范**，不是教程。执行前必读。

---

## 1. 工作方式（先分析、再修改）

1. **先定位，后动手。**
   - 接到任务先在 [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) 第 6 节「常见问题 → 代码位置映射」查起点。
   - 读完起点文件再决定是否继续外扩，不先读就改。
   - 做源仓库规则引擎同步时，优先使用项目内 skill：[.agents/skills/sync-arkham-upstream/SKILL.md](./.agents/skills/sync-arkham-upstream/SKILL.md)。
2. **一次任务、一次最小改动。**
   - 不要为「顺手优化」修改无关文件。
   - 不要重构目录、重命名、大规模格式化。
3. **先假设、后求证。**
   - 对规则引擎 (`library/Arkham/`)、JSONB Schema、Yesod 路由的任何假设，必须用代码证据确认。
4. **不确定就标注「待确认」并停下提问。** 禁止凭直觉改 `Arkham/` / `migrations/` / `routes` / `Entity/Arkham/`。

---

## 2. 修改边界

### 禁止
- ❌ 全仓大范围扫描（如递归遍历 `backend/arkham-api/library/Arkham/`、`frontend/public/cards_*.json`）。
  - 这些目录体量巨大（Arkham/ 有 150+ 文件，cards.json 每份 MB 级）。
- ❌ 改 `migrations/` 中已存在的迁移（只能新增成对的 deploy/revert/verify）。
- ❌ 改 `backend/arkham-api/config/routes` 但不同步 Handler / `Application.hs`。
- ❌ 改 `Entity/Arkham/*.hs` 的 JSONB 字段形状但不同步游戏引擎与迁移。
- ❌ 改 `frontend/public/cards_*.json`（由脚本生成）。
- ❌ 改锁文件：`stack.yaml.lock` / `flake.lock` / `package-lock.json` / `cabal.project.local`。
- ❌ 改 `Dockerfile` / `prod.nginxconf` / `start.sh` / `web-entrypoint.sh` / `terraform/` 未经确认。
- ❌ 批量 lint/格式化已有文件（会产生无意义 diff）。

### 可以
- ✅ 编辑 `frontend/src/views/`、`frontend/src/components/`、`frontend/src/arkham/components/`（UI）。
- ✅ 编辑 `frontend/src/stores/`（注意与后端 API 契约一致）。
- ✅ 编辑 `frontend/src/locales/`（多语言文案）。
- ✅ 编辑 `backend/arkham-api/library/Api/Handler/`、`Base/Api/Handler/` 的业务逻辑（保留路由签名 & DB 契约）。
- ✅ 新增测试文件（`backend/arkham-api/tests/` 下）。
- ✅ 非关键配置（日志级别等）。

### 改动前必须确认的事
| 改动类型 | 必须检查 |
|---|---|
| 新增后端路由 | `config/routes` + 新 Handler + `Application.hs` 导入 |
| 修改 Entity | 同步迁移 + 规则引擎序列化 + 前端解码器 |
| 修改前端 API 返回结构 | 同步 `arkham/types/*.ts` 解码器，否则运行时炸 |
| 修改登录/JWT | 同步 `stores/user.ts` 与 `router/index.ts` 守卫 |
| 修改游戏消息 (`Arkham/Message.hs`) | 同步所有使用该消息的 `Scenarios/` `Campaigns/` |

---

## 3. 输出规范

1. **不要把代码贴在对话里回显。** 用 `search_replace`/`create_file` 直接落地，回复只概括改动。
2. **改动按文件分组**，同一文件的连续修改在一次工具调用中完成。
3. **不写解释性注释堆叠**：一行说明「为什么」足矣，不写多行 docstring。
4. **不生成文档**（`*.md`、README）除非用户明确要求。
5. **不输出 TODO/留坑**。完成就是完成，做不完就停下问。
6. **引用代码用 Markdown 链接**，不要粘贴完整文件。
7. **日志/总结只说做了什么、下一步是什么**，不复述需求。

---

## 4. 验证要求

改动完成后，按相关栈最少跑下列验证：

### 前端
- 类型检查：`cd frontend; npm run tc`
  - 源仓库同步任务例外：`upstream/main` 与本仓 `dev` 当前均存在既有 `tc` 错误。同步时按 `.agents/skills/sync-arkham-upstream/scripts/compare-tc-baselines.sh` 做基线对比，只把同步分支新增且属于本仓改动的错误作为阻塞项。
- 构建：`cd frontend; npm run build`
- Dev 服务器自测：`npm run dev`（vite 8080，代理 → 3002）
- **热更新到运行中的容器**（Windows Docker 开发场景首选）：
  - `pwsh .\scripts\deploy-frontend.ps1`（改完源码快速上线，无需重启容器）
  - 首次或依赖变动加 `-Install`
  - 脚本内部已处理：检查容器、`npm install`（淘宝源）、`npm run build`、清旧产物、`docker cp` 覆盖
- **从外部图片包导入（跳过 CDN 下载）**：用户提供了 NAS / 移动硬盘 / 本地路径的 `img/` 目录时：
  - `pwsh .\scripts\import-images.ps1 -SourcePath <路径>`
  - 支持 UNC 路径（`\\NAS\share\...`）、`-DryRun`、`-SkipRestart`
  - 脚本内部已处理：路径校验、`robocopy` 同步（排除 `*.tmp`）、自动重启 web、`/health` 自检
  - 请不要用 `Copy-Item` 或手写 `docker cp` 替代（两万小文件会极慢）

### 后端
- 编译：`cd backend/arkham-api; stack build --flag arkham-api:library-only --flag arkham-api:dev`
- 测试：`stack test --flag arkham-api:library-only --flag arkham-api:dev`
- 开发态启动：`stack exec -- yesod devel`

### 数据库迁移
- 新迁移必须成对新增 `migrations/deploy/xxx.sql` + `revert/xxx.sql` + `verify/xxx.sql` 并在 `sqitch.plan` 登记。
- 本地执行：`sqitch deploy` / `sqitch verify` / `sqitch revert`（待确认用户本地是否装 sqitch）。

### 端到端
- `docker compose up -d` 后访问 `http://localhost:3000`：能注册、能登录、能进首页。
- 涉及游戏流程的改动需走「新建 → 进入 → 一次操作 → 刷新仍能恢复」。

---

## 5. 完成标准（Definition of Done）

一个改动可以声明完成，当且仅当：

1. **功能点满足**原始需求，且只改了必要文件。
2. **类型/编译通过**：普通改动要求前端 `npm run tc && npm run build` 无错、后端 `stack build` 无错；源仓库同步任务按项目内 skill 做 `tc` 基线对比，`npm run build`、后端编译和 Docker 冒烟仍是硬门禁。
3. **相关测试通过**：受影响模块至少跑一次 `stack test` 或相关 spec。
4. **跨层契约一致**：路由 / Entity / 解码器 / Store / 组件 四处没有断点。
5. **无意外 diff**：`git status` 只包含与任务相关的文件；锁文件未改；生成文件未手改。
6. **风险披露**：若触碰了 `PROJECT_SUMMARY.md` 第 8 节「风险区域」，在结束时显式说明。
7. **验证证据**：汇报中给出「跑了哪条命令、输出是什么」，不能只说「应该没问题」。

---

## 6. 常用只读工具箱（推荐先查再动）

- 路由总表：`backend/arkham-api/config/routes`
- Yesod App 与房间：`backend/arkham-api/library/Foundation.hs`
- 前端 API 调用：`frontend/src/arkham/api.ts`、`frontend/src/api.ts`
- 登录：`frontend/src/stores/user.ts`、`library/Base/Api/Handler/Authentication.hs`、`library/Auth/JWT.hs`
- 迁移计划：`migrations/sqitch.plan`
- 运行配置：`backend/arkham-api/config/settings.yml`
- 容器入口：`web-entrypoint.sh`、`start.sh`

---

## 7. 不确定清单（Agent 处理时遇到需主动询问）

- [ ] `frontend/public/cards_*.json` 的生成命令（目前 README/Makefile 未显式给出）。
- [ ] Sqitch 在本地是否已配置（Windows 用户可能没有）。
- [ ] Stack vs Cabal：项目同时存在 `stack.yaml` 与 `cabal.project`，默认使用 Stack（与 README 一致）。
- [ ] Redis 是否默认启用：`docker-compose.yml` 中已注释，本地默认使用内存 broker（待确认）。

遇到不确定项 → **先问再改**。
