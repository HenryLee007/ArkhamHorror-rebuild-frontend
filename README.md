# Arkham Horror LCG

![Screenshot](./docs/img/screenshot.png)

The goal of this project is to implement a web version of Arkham Horror with as
many of the rules implemented as possible.

## Warning

This is very much a work in progress. Things may break at any time, but if they do,
please file a bug.

## Features

* Multiplayer up to 4 players
* Multiplayer solitaire
* Tarot Readings
* Deck import from ArkhamDB and arkham.build

## Finished Content

### Player Cards

* All player cards before 2026

### Campaigns

* Night of the Zealot
  * Return to Night of the Zealot
* The Dunwich Legacy
  * Return to The Dunwich Legacy
* The Path To Carcosa
  * Return to The Path To Carcosa
* The Forgotten Age
  * Return to The Forgotten Age
* The Circle Undone
  * Return to The Circle Undone
* The Dream-Eaters
* The Innsmouth Conspiracy
* Edge of the Earth

### Side Stories

* The Curse of the Rougarou
* Carnevale of Horrors
* Murder at the Excelsior Hotel
* The Midwinter Gala
* Film Fatale

## I just want to try this out on my computer

### Linux Users

Install [Docker][docker], then run:

```
curl -fsSL https://raw.githubusercontent.com/halogenandtoast/ArkhamHorror/main/install.sh | bash
```

This creates an `arkham-horror/` directory, downloads the required files, generates
a database password, and starts the app. Open http://localhost:3000 when it's done.

The script will ask if you want to download game images (~2.9 GB). If you skip
this step, the app loads images from the CDN automatically — no extra setup needed.

### Windows Users

- Install Docker, specifically the version of Docker known as [Docker Desktop](https://docs.docker.com/desktop/).
- Install a "terminal only" version of Ubuntu that can be run inside of Windows, for which the easiest available method is to [install from the Microsoft Store](https://documentation.ubuntu.com/wsl/latest/howto/install-ubuntu-wsl2/#method-3-install-from-the-microsoft-store). You may choose any Linux distro other than Ubuntu if you know what you are doing.
- In Docker Desktop, go to `Settings > Resources > WSL Integration` and enable integration with Ubuntu Linux distro that you installed in the previous step. This allows us to access Docker from inside Ubuntu.
- Start the Ubuntu terminal and run:
  ```
  curl -fsSL https://raw.githubusercontent.com/halogenandtoast/ArkhamHorror/main/install.sh | bash
  ```
- The app should start being served at http://localhost:3000, if nothing went wrong.
- Every time you want to start the app, you can use `docker compose up`
- If you get around to figuring out how to use Docker Desktop, you could also press buttons to start and stop the app instead of typing commands to run it.

#### Things that can go wrong

If the app doesnt start at all, or it starts but you cannot create a user account, or any other issue due to Murphy's Law, you have to check the logs of the Docker container to find the error messages. In Docker Desktop, you can access this by clicking on the `arkham-horror` "compose stack" found in the `Containers` list.

Possible problems:

| Problem | Solution |
| ------------- | ------------- |
| Error involving `docker-credential-desktop.exe` | Try restarting your computer |
| When clicking on the "REGISTER" button, the error `password authentication failed` is logged| Stop the app using `docker compose down` and then refetch the app using `docker compose pull`

### Manual setup (alternative)

If you prefer not to use the install script, you'll need four files:

```
mkdir -p arkham-horror/config arkham-horror/scripts arkham-horror/frontend/public/img
cd arkham-horror
curl -fsSL https://raw.githubusercontent.com/halogenandtoast/ArkhamHorror/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/halogenandtoast/ArkhamHorror/main/setup.sql -o setup.sql
curl -fsSL https://raw.githubusercontent.com/halogenandtoast/ArkhamHorror/main/scripts/fetch-assets.sh -o scripts/fetch-assets.sh
# Generate a strong password
openssl rand -base64 32 > config/postgres_password.txt
docker compose up -d
```

The app automatically detects whether local images are present:
- **No local images** (default after install) → images load from the CDN automatically
- **Local images present** (after running the fetch service) → images served locally

To fetch images locally, use the `fetch-images` Docker service.
Once fetched, restart with `docker compose restart web` and the app will switch to local images.

```
# English only (~1.3 GB) — portraits, tokens, icons, card images
docker compose --profile fetch-images run --rm fetch-images en

# English + a specific language (recommended for non-English play)
docker compose --profile fetch-images run --rm fetch-images en+fr   # French
docker compose --profile fetch-images run --rm fetch-images en+es   # Spanish
docker compose --profile fetch-images run --rm fetch-images en+ita  # Italian
docker compose --profile fetch-images run --rm fetch-images en+ko   # Korean
docker compose --profile fetch-images run --rm fetch-images en+zh   # Chinese

# A single language's card translations only (English assets still load from CDN)
docker compose --profile fetch-images run --rm fetch-images fr

# Everything (~2.9 GB)
docker compose --profile fetch-images run --rm fetch-images all
```

Images are stored in `frontend/public/img/` and mounted into the container.
After fetching, run `docker compose restart web` to pick them up.

To switch back to CDN at any time, add this to the `web` service environment in `docker-compose.yml`:

```yaml
    environment:
      - ASSET_HOST=https://assets.arkhamhorror.app
```

### Updating

```
docker compose pull
docker compose up -d
```

### 前端热更新（改完源码快速上线）

本仓库包含一个 PowerShell 脚本，用于本地构建前端并把产物热推到运行中的 `web` 容器，**无需重启容器、无需重建镜像**。适合改了 `frontend/src` 下的 Vue/i18n/TS 源码后立刻在 http://localhost:3000 看到效果。

前置条件：
- 已通过 `docker compose up -d` 启动容器（默认容器名 `arkhamhorror-rebuild-frontend-web-1`）
- 本机已安装 Node.js 20+ 与 npm
- [vite.config.js](frontend/vite.config.js) 已设置 `build.copyPublicDir: false`（仓库默认即是），避免构建时拷贝 `public/img` 遇到 fetch-images 并发写入的 `.tmp` 临时文件

常规用法（改完代码后每次跑一次即可）：

```powershell
pwsh .\scripts\deploy-frontend.ps1
# 或 Windows PowerShell 5.x：
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-frontend.ps1
```

首次运行或 `package.json` 变动后（会先跑 `npm install`，使用淘宝镜像加速）：

```powershell
pwsh .\scripts\deploy-frontend.ps1 -Install
```

自定义容器名 / 容器内路径 / registry：

```powershell
pwsh .\scripts\deploy-frontend.ps1 `
    -ContainerName arkhamhorror-rebuild-frontend-web-1 `
    -DistRoot /opt/arkham/src/frontend/dist `
    -Registry https://registry.npmjs.org
```

脚本动作：
1. 检查 Docker 与目标容器在运行
2. `npm install`（仅 `-Install` 或未检测到 `node_modules` 时）
3. `npm run build` 产出 `frontend/dist/{index.html, assets/}`
4. 清理容器内 `dist/index.html` 与 `dist/assets`（文件 hash 会变，必须先删）
5. `docker cp` 新产物覆盖进容器

完成后浏览器 **Ctrl+F5 强刷** 即可看到新版本；容器内 `img/` `fonts/` `cards*.json` 等静态资源保持不动。

## Local dev

### Dependencies

* Stack for GHC
* Node
* Postgresql
* Sqitch (optional: for migrations)

### Local Setup

#### Running via Docker

The image is setup to use an external database passed via the `DATABASE_URL` environment variable. Follow the steps below to setup the database and then run the following commands

```
docker build -t arkham .
docker run -t -i -e PORT=3000 -e DATABASE_URL="postgres://docker:docker@host.docker.internal:5432/arkham-horror-backend" -p 3000:3000 arkham
```

#### Backend

Run `stack setup` in the `backend` directory, then run `stack build --fast` (note: this will still take a long time)

#### Frontend

Run `npm install` in the `frontend` directory

#### Images

Image assets (~2.9 GB) are **not stored in the git repository**. They are hosted
on CloudFront and the app loads them from the CDN by default in both development
and production — no extra setup needed.

If you need local copies (e.g. for offline development), use the fetch script
(requires `aws` CLI and `curl`):

```
make fetch-images     # Everything (~2.9 GB)
make fetch-cards      # English card images only (~755 MB)

# Or use the script directly:
./scripts/fetch-assets.sh en        # All English/static images (~1.3 GB)
./scripts/fetch-assets.sh en+fr     # English + French (recommended for French play)
./scripts/fetch-assets.sh en+es     # English + Spanish
./scripts/fetch-assets.sh en+ita    # English + Italian
./scripts/fetch-assets.sh en+ko     # English + Korean
./scripts/fetch-assets.sh en+zh     # English + Chinese
./scripts/fetch-assets.sh fr        # French card translations only
```

If you only have Docker (no local AWS CLI), use the Docker-based targets instead:

```
make fetch-images-docker    # Everything via Docker (~2.9 GB)
make fetch-cards-docker     # English card images only via Docker

# Or run directly with the same targets as above:
docker compose --profile fetch-images run --rm fetch-images en
docker compose --profile fetch-images run --rm fetch-images en+fr
docker compose --profile fetch-images run --rm fetch-images fr
```

To use local images instead of CDN in local dev, create `frontend/.env.development.local`:
```
VITE_ASSET_HOST=
```

To revert to CDN, remove the file or set `VITE_ASSET_HOST=https://assets.arkhamhorror.app`.

If you add new images, sync them to S3 and regenerate the manifest:
```
make sync-and-manifest
```

To install a git hook that warns if you forget to update the manifest:
```
make install-hooks
```

#### Database
Create the local database:

```
createdb arkham-horror-backend
cd migrations
sqitch deploy db:pg:arkham-horror-backend
```

If you do not have sqitch you can `cat migrations/deploy/*` to see the create
table statements and run them manually, you will want to specifically run the
`users` and `arkham_games` create table statements first.

### Running the server

* start the backend with `cd backend && make api.watch`
* start the frontend with `cd frontend && npm run serve`

## Copyright Disclaimer

The information presented in this app about [Arkham Horror: The Card Game™][arkham], both textual and graphical, is © Fantasy Flight Games 2024. This app is a fan project and is not produced, endorsed, or supported by, or affiliated with Fantasy Flight Games.

All artwork and illustrations are the intellectual property of their respective creators. All Arkham Horror: The Card Game™ images and graphics are copyrighted by Fantasy Flight Games.

[arkham]: https://www.fantasyflightgames.com/en/products/arkham-horror-the-card-game/
[docker]: https://www.docker.com/
[wsl2]: https://learn.microsoft.com/en-us/windows/wsl/install
