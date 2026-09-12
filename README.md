# dsh-control-center

English | [中文](README.zh.md)

A terminal control center for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`). It puts the commands you reach for most often — starting and stopping the Web UI, running one-shot tasks, managing plugins, reading logs, updating the CLI — behind one `fzf`-driven menu, so you do not have to memorise them.

## What it is, and what it is not

It is a **companion tool**. It runs outside `dsh` and drives the `dsh` command line.

It is **not** a Cordis plugin, and it cannot be one: a Cordis plugin only exists while `dsh` is running, and this tool's whole job is to start and stop `dsh` itself. A plugin that boots its own host is a circular dependency. Install it as a standalone CLI, or drop it into a profile's `plugins/` directory and reference it from `cordis.patch.yml` — both work.

## Requirements

- `zsh`
- `fzf` 0.48 or newer, for truecolor
- `dsh` on `PATH`
- `lsof` and `curl`
- macOS or Linux

## Install

```sh
npm install -g dsh-control-center
```

Or run it straight from a checkout:

```sh
git clone https://github.com/JZilla808/dsh-control-center.git
cd dsh-control-center
./bin/dsh-control-center
```

## Usage

### Interactive

```sh
dsh-control-center
```

### Direct commands

```sh
dsh-control-center start
dsh-control-center status
dsh-control-center headless "summarise the last commit"
dsh-control-center plugins list
```

## Language

The console ships English and Simplified Chinese, matching the two locales DeepSeek Harness itself maintains.

It resolves the language from `DSH_LANG`, then a stored preference, then your `LC_ALL` / `LC_MESSAGES` / `LANG`. When none of those decide, it asks once on first run and remembers the answer. Change it at any time from the **Language / 语言** row in the menu.

## Configuration

| Variable | Purpose |
|---|---|
| `DSH_LANG` | Force the console language: `en` or `zh`. |
| `DSH_PORT` | Port the Web UI listens on. Default `3080`. |
| `DSH_PROFILE` | Profile used by plugin commands. Default `web`. |
| `DSH_WORKSPACE` | Folder opened by the workspace action. Default `$HOME`. |
| `DSH_CC_HOME` | Where the console keeps its own preferences. |
| `DSH_NO_BROWSER` | Set to `1` to never open a browser. |
| `DSH_NO_SPLASH` | Set to `1` to skip the intro animation. |
| `DSH_NO_FZF` | Set to `1` for a plain numbered menu. |

## Keeping the service alive

`lib/launch-web.sh` starts `dsh web` in its **own session**. `nohup … &` on its own only ignores `SIGHUP`: the process stays in the terminal's foreground process group, so closing that window still takes the Web UI down with it. Detaching the session is what lets the service outlive the terminal that started it.

## Development

Verify the message catalogs before committing:

```sh
python3 scripts/verify-i18n.py
```

The gate fails on a missing or extra key, a mismatched `%s` placeholder, or `card.*` labels whose display widths disagree. CJK glyphs occupy two terminal columns, so a catalog that drifts breaks the layout at runtime rather than at review time.

## Trademarks

"DeepSeek" and "DeepSeek Harness" are trademarks of DeepSeek. This is an independent community project, not affiliated with, endorsed by, or sponsored by DeepSeek, and it redistributes no official brand assets. The project name uses the "DSH" abbreviation, as the brand guidelines recommend.

## License

[MIT](LICENSE)
