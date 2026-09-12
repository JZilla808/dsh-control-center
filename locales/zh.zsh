# =============================================================================
#  中文目录（简体）。键集合必须与 en.zsh 完全一致 —— scripts/verify-i18n.py 会校验。
#
#  关于 card.*：这些标签预先补齐到 8 个显示列宽，这样状态卡在中英文下都能对齐
#  （CJK 字形占两列）。校验脚本会检查同一语言内所有 card.* 宽度一致。
# =============================================================================

_cc_locale_zh() {
  _CC_L=(
    # --- identity ------------------------------------------------------------
    [app.name]='DSH 控制中心'
    [app.tagline]='控制中心 · 深海作业控制台'

    # --- service state -------------------------------------------------------
    [state.running]='运行中'
    [state.stopped]='已停止'

    # --- banner --------------------------------------------------------------
    [banner.pid]='进程'
    [banner.addr]='地址'
    [banner.version]='版本'
    [banner.uptime]='在线'

    # --- status card labels (pre-padded to 8 display columns) ----------------
    [card.service]='服务    '
    [card.pid]='进程    '
    [card.addr]='地址    '
    [card.version]='版本    '
    [card.uptime]='在线    '

    # --- menu ----------------------------------------------------------------
    [menu.start]='启动 Web UI'
    [menu.stop]='停止 Web UI'
    [menu.restart]='重启 Web UI'
    [menu.open]='在浏览器打开界面'
    [menu.status]='查看状态'
    [menu.version]='版本与更新检查'
    [menu.update]='更新 dsh'
    [menu.logs]='查看运行日志'
    [menu.headless]='运行 headless 任务…'
    [menu.plugins]='插件管理…'
    [menu.config]='打开配置目录'
    [menu.workspace]='打开工作区目录'
    [menu.docs]='文档与命令速查'
    [menu.language]='Language / 语言'
    [menu.quit]='退出控制台'

    [footer.keys]='  ↑↓ 移动   ⏎ 执行   / 搜索   ctrl-/ 预览   esc 退出'

    # --- preview: titles, descriptions, equivalent commands -------------------
    [pv.start.title]='启动 Web UI'
    [pv.start.desc]='若服务未运行则启动 dsh web，并自动在浏览器打开带 token 的认证界面。'
    [pv.start.cmd]='dsh web'

    [pv.stop.title]='停止 Web UI'
    [pv.stop.desc]='结束正在监听 %s 端口的 dsh 服务进程。'
    [pv.stop.cmd]='lsof -ti tcp:%s -sTCP:LISTEN | xargs kill'

    [pv.restart.title]='重启 Web UI'
    [pv.restart.desc]='先停止再启动。改完配置或插件之后用它。'
    [pv.restart.cmd]='stop → start'

    [pv.open.title]='在浏览器打开界面'
    [pv.open.desc]='用已认证的地址打开 Web UI，不会重启服务。'
    [pv.open.cmd]='open "$(cat ~/.dsh/web.url)"'

    [pv.status.title]='查看状态'
    [pv.status.desc]='服务是否运行、进程号、运行时长、端口、日志与 profile。'
    [pv.status.cmd]='dsh-control-center status'

    [pv.version.title]='版本与更新检查'
    [pv.version.desc]='对比本地版本与 npm 的 latest / next / alpha 通道。'
    [pv.version.cmd]='npm view @deepseek-ai/dsh dist-tags'

    [pv.update.title]='更新 dsh'
    [pv.update.desc]='通过 npm 全局升级，并显式传入 allow-scripts，避免 node-pty 等原生模块损坏。'
    [pv.update.cmd]='npm install -g @deepseek-ai/dsh'

    [pv.logs.title]='查看运行日志'
    [pv.logs.desc]='显示 Web 服务日志的最近输出。'
    [pv.logs.cmd]='tail -n 80 ~/.dsh/web.log'

    [pv.headless.title]='运行 headless 任务'
    [pv.headless.desc]='执行一次性任务，打印结果后退出。'
    [pv.headless.cmd]='dsh --profile headless "<任务>"'

    [pv.plugins.title]='插件管理'
    [pv.plugins.desc]='在指定 profile 中列出 / 安装 / 移除 / 更新插件。'
    [pv.plugins.cmd]='dsh plugin --profile %s <参数>'

    [pv.config.title]='打开配置目录'
    [pv.config.desc]='在 Finder 中打开 dsh 主目录：profile、patch、日志。'
    [pv.config.cmd]='open ~/.dsh'

    [pv.workspace.title]='打开工作区'
    [pv.workspace.desc]='在 Finder 中打开默认工作区目录。'
    [pv.workspace.cmd]='open %s'

    [pv.docs.title]='文档与命令速查'
    [pv.docs.desc]='打开官方站点，并列出本控制台覆盖的原始命令。'
    [pv.docs.cmd]='open https://deepseek.com/harness/en/'

    [pv.language.title]='语言'
    [pv.language.desc]='在英文与简体中文之间切换控制台语言，选择会被记住。'
    [pv.language.cmd]='DSH_LANG=zh dsh-control-center'

    [pv.quit.title]='退出控制台'
    [pv.quit.desc]='关闭控制中心。不会停止 Web UI 服务。'
    [pv.quit.cmd]='—'

    # --- preview chrome ------------------------------------------------------
    [pv.equivalent]='等效命令'

    # --- splash --------------------------------------------------------------
    [splash.diving]='下潜中…'
    [splash.ready]='就绪'

    # --- messages ------------------------------------------------------------
    [msg.already_running]='Web UI 已在运行 (pid %s)'
    [msg.starting]='正在启动 dsh web …（首次启动可能需要几秒）'
    [msg.started]='已启动 (pid %s)'
    [msg.start_failed]='启动失败，请查看运行日志'
    [msg.not_running]='Web UI 当前未运行'
    [msg.stopping]='正在停止 pid %s …'
    [msg.stopped]='已停止'
    [msg.still_running]='仍在运行，强制结束…'
    [msg.stopped_forced]='已停止（强制）'
    [msg.stop_failed]='停止失败'
    [msg.start_first]='服务未运行，先启动…'
    [msg.opened]='已在浏览器打开：%s'
    [msg.no_browser]='DSH_NO_BROWSER=1，跳过打开浏览器'
    [msg.cancelled]='已取消'
    [msg.unknown_action]='未知操作：%s'
    [msg.unknown_command]='未知命令：%s'

    # --- screens -------------------------------------------------------------
    [screen.status]='运行状态'
    [screen.version]='版本与更新'
    [screen.update]='更新 dsh'
    [screen.logs]='运行日志'
    [screen.headless]='Headless 任务'
    [screen.plugins]='插件'
    [screen.docs]='文档与命令速查'
    [screen.language]='Language / 语言'

    # --- shared field labels (action screens) --------------------------------
    [lbl.service]='服务'
    [lbl.pid]='进程'
    [lbl.version]='版本'
    [lbl.node]='环境'
    [lbl.url]='地址'
    [lbl.health]='探活'
    [lbl.log]='日志'
    [lbl.config]='配置'
    [lbl.local]='本地'
    [lbl.channels]='npm 通道'
    [lbl.port_free]='端口 %s 空闲'

    # --- status screen -------------------------------------------------------
    [st.no_response]='无响应'
    [st.responding]='有响应'
    [st.http_note]='(HTTP %s · 裸地址返回 401 属正常)'
    [st.log_lines]='%s（%s 行）'
    [st.profile_suffix]='  ·  profile: %s'

    # --- version screen ------------------------------------------------------
    [ver.hint]='提示：npm 全局安装不会自动更新。'

    # --- update screen -------------------------------------------------------
    [upd.current]='当前版本：%s'
    [upd.running]='正在更新：npm install -g @deepseek-ai/dsh …（可能需要一会儿）'
    [upd.done]='更新完成：%s → %s'
    [upd.failed]='更新失败（exit %s）'

    # --- logs screen ---------------------------------------------------------
    [logs.empty]='日志为空或不存在：%s'
    [logs.recent]='最近 80 行'
    [logs.follow]='实时跟踪：在终端运行  tail -f "%s"'

    # --- headless screen -----------------------------------------------------
    [hl.prompt]='要执行的任务：'
    [hl.hint]='（首次使用会自动初始化 headless profile）'

    # --- plugins screen ------------------------------------------------------
    [pl.none]='（此 profile 未安装任何插件）'
    [pl.dir]='profile 目录：%s'
    [pl.which]='为 profile「%s」列出 / 安装 / 移除 / 更新插件'
    [pl.list]='列出已装插件'
    [pl.add]='安装插件…'
    [pl.remove]='移除插件…'
    [pl.update]='更新插件（全部）'
    [pl.back]='返回主菜单'
    [pl.pkg_prompt]='包名：'
    [pl.unsupported]='子菜单需要 fzf。直接用法：dsh-control-center plugins list|add|remove|update'

    # --- docs screen ---------------------------------------------------------
    [docs.site]='官网'
    [docs.repo]='仓库'
    [docs.docs]='文档'
    [docs.covered]='本控制台覆盖的原始命令'
    [docs.opened]='已打开官网'

    # --- language picker -----------------------------------------------------
    [lang.which]='Language / 语言'
    [lang.help]='选择控制台语言，之后可以在菜单里随时更改。'
    [lang.saved]='语言已设为简体中文。'
    [lang.current]='当前语言：简体中文'

    # --- misc ----------------------------------------------------------------
    [misc.press_enter]='按 Enter 返回控制台…'
    [misc.finder_opened]='已在 Finder 打开：%s'
    [misc.exit_thanks]='感谢使用 DSH 控制中心。'
    [misc.exit_note]='Web UI 服务不受影响；如需停止，重新打开控制台选择「停止 Web UI」。'
    [misc.script_missing]='找不到控制台脚本'
    [misc.script_missing_body]='缺少文件：%s'
    [misc.usage_title]='用法：dsh-control-center [action] [args]'
    [misc.usage_menu]='(无)                打开交互式控制台'
    [misc.usage_headless]='headless [任务]     运行一次性任务'
    [misc.usage_plugins]='plugins [list|add <pkg>|remove <pkg>|update]'
    [misc.usage_rest]='config|workspace|docs|language|help'
  )
}
