# =============================================================================
#  English catalog (base locale).
#
#  Every key here MUST also exist in every other locale file: `scripts/verify-i18n.py`
#  fails the build otherwise. Keys are stable ids, never the English text itself.
#
#  Note on `card.*`: those labels are pre-padded to 8 display columns so the
#  status card columns line up in both locales (CJK glyphs are two columns
#  wide). The verifier checks that all `card.*` values in a locale share one
#  display width.
# =============================================================================

_cc_locale_en() {
  _CC_L=(
    # --- identity ------------------------------------------------------------
    [app.name]='DSH Control Center'
    [app.tagline]='control center · deep sea ops console'

    # --- service state -------------------------------------------------------
    [state.running]='Running'
    [state.stopped]='Stopped'

    # --- banner --------------------------------------------------------------
    [banner.pid]='pid'
    [banner.addr]='at'
    [banner.version]='ver'
    [banner.uptime]='up'

    # --- status card labels (pre-padded to 8 display columns) ----------------
    [card.service]='Service '
    [card.pid]='PID     '
    [card.addr]='Address '
    [card.version]='Version '
    [card.uptime]='Uptime  '

    # --- menu ----------------------------------------------------------------
    [menu.start]='Start Web UI'
    [menu.stop]='Stop Web UI'
    [menu.restart]='Restart Web UI'
    [menu.open]='Open in browser'
    [menu.status]='Show status'
    [menu.version]='Version & update check'
    [menu.update]='Update dsh'
    [menu.logs]='View runtime log'
    [menu.headless]='Run a headless task…'
    [menu.plugins]='Manage plugins…'
    [menu.config]='Open config folder'
    [menu.workspace]='Open workspace folder'
    [menu.docs]='Docs & command cheatsheet'
    [menu.language]='Language / 语言'
    [menu.quit]='Quit'

    [footer.keys]='  ↑↓ move   ⏎ run   / search   esc quit'

    # --- preview: titles, descriptions, equivalent commands -------------------
    [pv.start.title]='Start Web UI'
    [pv.start.desc]='Start dsh web if it is not already running, then open the authenticated UI.'
    [pv.start.cmd]='dsh web'

    [pv.stop.title]='Stop Web UI'
    [pv.stop.desc]='Ends the dsh process listening on port %s.'
    [pv.stop.cmd]='lsof -ti tcp:%s -sTCP:LISTEN | xargs kill'

    [pv.restart.title]='Restart Web UI'
    [pv.restart.desc]='Stop, then start again. Use after changing config or plugins.'
    [pv.restart.cmd]='stop → start'

    [pv.open.title]='Open in browser'
    [pv.open.desc]='Open the authenticated Web UI address without restarting.'
    [pv.open.cmd]='open "$(cat ~/.dsh/web.url)"'

    [pv.status.title]='Show status'
    [pv.status.desc]='Service state, pid, uptime, port, log and profile.'
    [pv.status.cmd]='dsh-control-center status'

    [pv.version.title]='Version & update check'
    [pv.version.desc]='Compare the local version with the npm release channels.'
    [pv.version.cmd]='npm view @deepseek-ai/dsh dist-tags'

    [pv.update.title]='Update dsh'
    [pv.update.desc]='Global npm upgrade, passing allow-scripts so node-pty stays intact.'
    [pv.update.cmd]='npm install -g @deepseek-ai/dsh'

    [pv.logs.title]='View runtime log'
    [pv.logs.desc]='Recent output from the web service log.'
    [pv.logs.cmd]='tail -n 80 ~/.dsh/web.log'

    [pv.headless.title]='Run a headless task'
    [pv.headless.desc]='Run a one-shot task, print the result, and exit.'
    [pv.headless.cmd]='dsh --profile headless "<task>"'

    [pv.plugins.title]='Manage plugins'
    [pv.plugins.desc]='List, install, remove or update plugins in the profile.'
    [pv.plugins.cmd]='dsh plugin --profile %s <args>'

    [pv.config.title]='Open config folder'
    [pv.config.desc]='Reveal the dsh home directory: profiles, patches, logs.'
    [pv.config.cmd]='open ~/.dsh'

    [pv.workspace.title]='Open workspace folder'
    [pv.workspace.desc]='Reveal the default workspace directory.'
    [pv.workspace.cmd]='open %s'

    [pv.docs.title]='Docs & command cheatsheet'
    [pv.docs.desc]='Open the official site and list the raw commands covered here.'
    [pv.docs.cmd]='open https://deepseek.com/harness/en/'

    [pv.language.title]='Language'
    [pv.language.desc]='Switch between English and Simplified Chinese. Remembered.'
    [pv.language.cmd]='DSH_LANG=en dsh-control-center'

    [pv.quit.title]='Quit'
    [pv.quit.desc]='Close the console. The Web UI service keeps running.'
    [pv.quit.cmd]='—'

    # --- preview chrome ------------------------------------------------------
    [pv.equivalent]='Equivalent command'

    # --- splash --------------------------------------------------------------
    [splash.diving]='diving…'
    [splash.ready]='ready'

    # --- messages ------------------------------------------------------------
    [msg.already_running]='Web UI is already running (pid %s)'
    [msg.starting]='Starting dsh web… (the first launch can take a few seconds)'
    [msg.started]='Started (pid %s)'
    [msg.start_failed]='Start failed. Check the runtime log.'
    [msg.not_running]='Web UI is not running'
    [msg.stopping]='Stopping pid %s…'
    [msg.stopped]='Stopped'
    [msg.still_running]='Still alive, forcing…'
    [msg.stopped_forced]='Stopped (forced)'
    [msg.stop_failed]='Stop failed'
    [msg.start_first]='Service is not running, starting it first…'
    [msg.opened]='Opened in your browser: %s'
    [msg.no_browser]='DSH_NO_BROWSER=1, skipping the browser'
    [msg.cancelled]='Cancelled'
    [msg.unknown_action]='Unknown action: %s'
    [msg.unknown_command]='Unknown command: %s'

    # --- screens -------------------------------------------------------------
    [screen.status]='Status'
    [screen.version]='Version & update'
    [screen.update]='Update dsh'
    [screen.logs]='Runtime log'
    [screen.headless]='Headless task'
    [screen.plugins]='Plugins'
    [screen.docs]='Docs & command cheatsheet'
    [screen.language]='Language / 语言'

    # --- shared field labels (action screens) --------------------------------
    [lbl.service]='Service'
    [lbl.pid]='PID'
    [lbl.version]='Version'
    [lbl.node]='Runtime'
    [lbl.url]='Address'
    [lbl.health]='Health'
    [lbl.log]='Log'
    [lbl.config]='Config'
    [lbl.local]='Local'
    [lbl.channels]='npm channels'
    [lbl.port_free]='port %s is free'

    # --- status screen -------------------------------------------------------
    [st.no_response]='no response'
    [st.responding]='responding'
    [st.http_note]='(HTTP %s · a 401 on the bare address is normal)'
    [st.log_lines]='%s (%s lines)'
    [st.profile_suffix]='  ·  profile: %s'

    # --- version screen ------------------------------------------------------
    [ver.hint]='Note: a global npm install does not self-update.'

    # --- update screen -------------------------------------------------------
    [upd.current]='Current version: %s'
    [upd.running]='Updating: npm install -g @deepseek-ai/dsh … (this can take a while)'
    [upd.done]='Updated: %s → %s'
    [upd.failed]='Update failed (exit %s)'

    # --- logs screen ---------------------------------------------------------
    [logs.empty]='The log is empty or missing: %s'
    [logs.recent]='Last 80 lines'
    [logs.follow]='Follow it live with:  tail -f "%s"'

    # --- headless screen -----------------------------------------------------
    [hl.prompt]='Task to run: '
    [hl.hint]='(the headless profile initialises itself on first use)'

    # --- plugins screen ------------------------------------------------------
    [pl.none]='(no plugins installed in this profile)'
    [pl.dir]='profile directory: %s'
    [pl.which]='List, install, remove or update plugins in profile "%s"'
    [pl.list]='List installed plugins'
    [pl.add]='Install a plugin…'
    [pl.remove]='Remove a plugin…'
    [pl.update]='Update all plugins'
    [pl.back]='Back to the main menu'
    [pl.pkg_prompt]='Package name: '
    [pl.unsupported]='fzf is required for the submenu. Use: dsh-control-center plugins list|add|remove|update'

    # --- docs screen ---------------------------------------------------------
    [docs.site]='Website'
    [docs.repo]='Repository'
    [docs.docs]='Documentation'
    [docs.covered]='Raw commands this console covers'
    [docs.opened]='Opened the official site'

    # --- language picker -----------------------------------------------------
    [lang.which]='Language / 语言'
    [lang.help]='Choose the console language. You can change it later from the menu.'
    [lang.saved]='Language set to English.'
    [lang.current]='Current language: English'

    # --- misc ----------------------------------------------------------------
    [misc.press_enter]='Press Enter to return to the console…'
    [misc.finder_opened]='Opened in Finder: %s'
    [misc.exit_thanks]='Thanks for using DSH Control Center.'
    [misc.exit_note]='The Web UI service is unaffected; to stop it, reopen the console and pick "Stop Web UI".'
    [misc.script_missing]='Control center script not found'
    [misc.script_missing_body]='Missing file: %s'
    [misc.usage_title]='Usage: dsh-control-center [action] [args]'
    [misc.usage_menu]='(none)              open the interactive console'
    [misc.usage_headless]='headless [task]     run a one-shot task'
    [misc.usage_plugins]='plugins [list|add <pkg>|remove <pkg>|update]'
    [misc.usage_rest]='config|workspace|docs|language|help'
  )
}
