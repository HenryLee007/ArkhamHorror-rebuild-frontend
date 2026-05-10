# Upstream 同步说明（面向 Agent）

本文档用于把源仓库的游戏规则、卡牌、剧本等更新合并到本仓库，同时尽量保留本仓库自己的界面重构、部署配置和 `arkham.build` 集成。

执行同步前，先阅读仓库根目录的 `AGENTS.md`，再阅读 `PROJECT_SUMMARY.md` 第 6 节「常见问题 → 代码位置映射」和第 8 节「风险区域 / 禁止随意修改」。

## 目标

- 接收源仓库中与游戏规则、卡牌、剧本、规则引擎相关的更新。
- 保留本仓库的主站 UI 重构、登录改造、组卡入口、`arkham.build` sidecar、本地图片导入和 Docker/Nginx 集成。
- 通过一条可审计的同步分支完成合并，不直接在长期分支上试错。

## 非目标

- 不在同步过程中重构目录、重命名文件或批量格式化。
- 不手工修改 `frontend/public/cards_*.json`。
- 不随意改动已有迁移、锁文件、规则引擎内部结构。
- 不只拷贝某几个游戏目录来“模拟同步”。应优先合并源仓库 commit，再按路径归属解决冲突。

## 开始前需要的信息

如果以下信息无法从本地仓库确认，Agent 必须先向用户提问：

- 源仓库 Git URL。
- 源仓库默认同步分支，例如 `main`、`master` 或其他长期分支。
- 本仓库目标合入分支，默认建议为 `dev`。
- 本轮是否允许接收源仓库的数据库迁移、Entity 或 API 契约变化。
- 是否需要同时同步 `arkham.build` 自身；默认只同步 ArkhamHorror 主站，不把 `arkham.build` 当作源仓库的一部分处理。

## 只读预检

先做只读检查，确认工作区和远端状态：

```bash
git status --short --branch
git remote -v
git branch --list --all
```

如果工作区已有未提交改动，不要覆盖或回退。先判断这些改动是否属于本次同步；不属于本次同步时，继续操作前向用户说明风险。

确认当前本地改动是否碰到游戏内容高风险路径：

```bash
git diff --name-only main..HEAD -- \
  backend/arkham-api/library/Arkham \
  backend/arkham-api/library/Entity/Arkham \
  migrations \
  frontend/public/cards_*.json \
  backend/cards-discover
```

该命令有输出时，不要直接开始同步。先确认这些改动是否是用户明确要保留的本地游戏逻辑改动。

## Remote 设置

如果还没有源仓库 remote，使用用户提供的 URL 添加 `upstream`：

```bash
git remote add upstream <source-repo-url>
git fetch upstream
```

如果已有 `upstream`，先抓取最新内容：

```bash
git fetch upstream --prune
```

不要猜测源仓库 URL。当前仓库的 `origin` 是用户自己的 fork，不等同于源仓库。

## 同步分支流程

默认从本仓库 `dev` 开同步分支：

```bash
git switch dev
git pull --ff-only origin dev
git switch -c sync/upstream-YYYYMMDD
git merge --no-commit upstream/main
```

如果用户指定了不同目标分支或源分支，替换上面的 `dev` 和 `upstream/main`。

使用 `--no-commit` 是为了在提交前检查路径归属、冲突和验证范围。

## 路径归属

### 本仓库优先

这些路径代表本仓库自己的 UI、部署和本地集成。冲突时通常保留 ours，但仍要确认源仓库是否有必要的接口契约变化：

- `frontend/src/views/`
- `frontend/src/components/`
- `frontend/src/arkham/components/`
- `frontend/src/arkham/views/`
- `frontend/src/stores/`
- `frontend/src/locales/`
- `frontend/src/components/NavBar.vue`
- `docker-compose.yml`
- `prod.nginxconf`
- `scripts/import-local-assets.sh`
- `scripts/export-arkham-build-assets.ps1`
- `arkham.build/`

### 源仓库优先

这些路径主要承载游戏规则、卡牌、剧本或生成数据。冲突时通常接收 theirs，但不能手工改出新的业务逻辑：

- `backend/arkham-api/library/Arkham/`
- `backend/cards-discover/`
- `frontend/public/cards_*.json`
- 新增剧本、战役、卡牌定义、规则 helper。

### 必须人工确认

这些路径是跨层契约或迁移边界。出现冲突、删除、结构变化时必须停下来分析，必要时向用户提问：

- `backend/arkham-api/library/Entity/Arkham/`
- `backend/arkham-api/library/Entity/`
- `migrations/`
- `backend/arkham-api/config/routes`
- `backend/arkham-api/library/Application.hs`
- `backend/arkham-api/library/Api/Handler/`
- `backend/arkham-api/library/Base/Api/Handler/`
- `frontend/src/arkham/api.ts`
- `frontend/src/api.ts`
- `frontend/src/arkham/types/`
- `frontend/src/stores/user.ts`
- `frontend/src/router/index.ts`
- `backend/arkham-api/library/Arkham/Message.hs`
- `backend/arkham-api/library/Arkham/Game.hs`

## 冲突处理原则

- 先用 `git status --short` 和 `git diff --name-only --diff-filter=U` 看冲突列表。
- 对本仓库优先路径，不要让源仓库覆盖本地 UI 和部署集成。
- 对源仓库优先路径，可以按路径接收源仓库版本，但不能跨目录批量格式化。
- 对 `frontend/public/cards_*.json`，只能接收源仓库生成结果，不手工编辑内容。
- 对 `migrations/`，已有迁移不要改写。源仓库新增迁移可以接收；已有迁移发生冲突时必须停下确认。
- 对 `Entity/Arkham/`、routes、Handler、前端解码器或 store 契约，必须确认后端返回结构和前端读取结构一致。
- 对 `Arkham/Message.hs`、`Arkham/Game.hs`，即使倾向接收源仓库，也要确认没有本地未提交游戏逻辑改动。

## 提交前检查

检查合并结果：

```bash
git status --short
git diff --name-only --cached
git diff --stat
```

确认没有意外改动这些文件：

- `stack.yaml.lock`
- `flake.lock`
- `package-lock.json`
- `cabal.project.local`

确认没有手工编辑生成文件：

- `frontend/public/cards_*.json`

## 验证命令

后端至少运行：

```bash
cd backend/arkham-api
stack build --flag arkham-api:library-only --flag arkham-api:dev
```

如果同步包含规则、剧本、Entity、迁移或 Handler 变化，继续运行：

```bash
stack test --flag arkham-api:library-only --flag arkham-api:dev
```

前端至少运行构建：

```bash
cd frontend
npm run build
```

### TypeScript 基线策略

当前源仓库 `upstream/main` 和本仓同步前 `dev` 都存在既有 `npm run tc` 错误，因此上游同步时不能把 `tc` 全绿作为硬门禁。正确做法是比对三份基线：

- 本仓目标分支，例如 `dev`。
- 源仓库分支，例如 `upstream/main`。
- 当前同步分支，例如 `HEAD`。

优先使用项目内 skill 附带脚本：

```bash
.agents/skills/sync-arkham-upstream/scripts/compare-tc-baselines.sh dev upstream/main
```

脚本默认把当前工作区作为同步分支检查对象，因此能覆盖 `git merge --no-commit` 后尚未提交的解冲突结果。

判定规则：

- `dev` 或 `upstream/main` 已存在的 `tc` 错误，不阻塞本轮同步，但需要在汇报中说明。
- 同步分支新增、且属于本仓 UI/中文化/部署集成改动的 `tc` 错误，必须修复。
- 同步分支新增、但来自源仓库规则/API/类型演进的错误，先确认 `npm run build`、Docker 后端编译和基本流程是否通过；若运行时正常，可作为源仓库类型债记录，不强行在同步任务里修完整套类型系统。

Docker 冒烟验证：

```bash
docker compose config --quiet
docker compose up -d
curl -f http://localhost:3000/health
```

涉及游戏流程时，还要在浏览器里完成：

- 登录。
- 进入首页。
- 新建或进入一局游戏。
- 执行一次操作。
- 刷新页面后确认游戏可恢复。

涉及 `arkham.build` 或图片时，还要确认：

- `http://localhost:3000/build/browse` 可访问。
- 简体中文默认生效。
- 卡图和缩略图返回 200。
- `arkham.build` 左上角 logo 可返回 ArkhamHorror 主站。

## 提交

硬门禁通过后再提交：

```bash
git add <resolved-files>
git commit -m "sync upstream game updates YYYY-MM-DD"
```

如果后端编译、`npm run build`、Docker 冒烟或基本游戏流程失败，不要提交。`npm run tc` 失败时按基线策略判断；不要要求本轮同步修复上游和历史分支已有的全部类型债。

## 必须停下提问的情况

遇到以下情况，Agent 不得继续猜测：

- 源仓库 URL 或默认分支未知。
- 工作区已有用户未提交改动，且这些改动会被合并影响。
- `migrations/` 中已有迁移出现冲突。
- `Entity/Arkham/` 的 JSONB 字段形状发生变化。
- Yesod routes、Handler、前端 API 解码器出现契约不一致。
- `Arkham/Message.hs` 或 `Arkham/Game.hs` 既有本地改动又有源仓库改动。
- 后端 build/test 因规则、Entity 或迁移错误失败。
- 源仓库删除或重命名了本仓库正在使用的主站入口、登录、组卡或图片路径。

## 汇报格式

同步完成后，汇报只包含高信号信息：

- 使用的源仓库和分支。
- 本仓库目标分支和同步分支。
- 接收了哪些游戏内容范围。
- 解决了哪些冲突。
- 跑了哪些验证命令，以及结果。
- 是否触碰 `PROJECT_SUMMARY.md` 第 8 节风险区域。
