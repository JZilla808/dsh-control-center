# dsh-control-center

[English](README.md) | 中文

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）的终端控制中心。它把最常用的那些命令 —— 启停 Web UI、运行一次性任务、管理插件、查看日志、升级 CLI —— 收进一个由 `fzf` 驱动的菜单里，你不必再记命令。

## 它是什么，以及它不是什么

它是一个**伴随工具**，运行在 `dsh` 之外，驱动 `dsh` 命令行。

它**不是** Cordis 插件，而且不可能是：Cordis 插件只在 `dsh` 运行期间存在，而这个工具的全部职责就是启停 `dsh` 本身。一个要启动自己宿主的插件是循环依赖。你可以把它当作独立 CLI 安装，也可以放进某个 profile 的 `plugins/` 目录并在 `cordis.patch.yml` 里引用 —— 两种方式都可以。

## 依赖

- `zsh`
- `fzf` 0.48 或更新版本（需要真彩色支持）
- `dsh` 在 `PATH` 中
- `lsof` 与 `curl`
- macOS 或 Linux

## 安装

```sh
npm install -g dsh-control-center
```

或者直接从源码仓库运行：

```sh
git clone https://github.com/jbeazy/dsh-control-center.git
cd dsh-control-center
./bin/dsh-control-center
```

## 使用

### 交互式

```sh
dsh-control-center
```

### 直接命令

```sh
dsh-control-center start
dsh-control-center status
dsh-control-center headless "summarise the last commit"
dsh-control-center plugins list
```

## 语言

控制台内置英文与简体中文，与 DeepSeek Harness 自身维护的两个 locale 保持一致。

语言解析顺序为 `DSH_LANG`、已保存的偏好、你的 `LC_ALL` / `LC_MESSAGES` / `LANG`。当这些都决定不了时，它会在首次运行时询问一次并记住答案。之后随时可以在菜单的 **Language / 语言** 一行更改。

## 配置

| 变量 | 用途 |
|---|---|
| `DSH_LANG` | 强制控制台语言：`en` 或 `zh`。 |
| `DSH_PORT` | Web UI 监听的端口。默认 `3080`。 |
| `DSH_PROFILE` | 插件命令使用的 profile。默认 `web`。 |
| `DSH_WORKSPACE` | 「工作区」操作打开的目录。默认 `$HOME`。 |
| `DSH_CC_HOME` | 控制台保存自身偏好的位置。 |
| `DSH_NO_BROWSER` | 设为 `1` 则永不打开浏览器。 |
| `DSH_NO_SPLASH` | 设为 `1` 则跳过开场动画。 |
| `DSH_NO_FZF` | 设为 `1` 则使用纯数字菜单。 |

## 让服务活下来

`lib/launch-web.sh` 会**在独立会话中**启动 `dsh web`。单靠 `nohup … &` 只是忽略 `SIGHUP`：进程仍留在终端的前台进程组里，所以关掉那个窗口依然会把 Web UI 一起带走。真正让服务活过启动它的那个终端的，是脱离会话。

## 开发

提交前校验消息目录：

```sh
python3 scripts/verify-i18n.py
```

以下情况会让校验失败：缺失或多余的键、`%s` 占位符不匹配、`card.*` 标签的显示宽度不一致。CJK 字形占两个终端列宽，所以目录一旦漂移，布局会在运行时而不是评审时崩掉。

## 商标

"DeepSeek" 与 "DeepSeek Harness" 是 DeepSeek 的商标。本项目是独立的社区项目，与 DeepSeek 无隶属关系，未获其背书或赞助，也不再分发任何官方品牌素材。项目名称使用品牌指南推荐的 "DSH" 缩写。

## 许可证

[MIT](LICENSE)
