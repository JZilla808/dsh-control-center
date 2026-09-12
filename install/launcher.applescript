-- =============================================================================
--  DSH Control Center — desktop launcher (macOS).
--
--  Opens exactly ONE Terminal window running the console.
--
--  WHY THIS IS WRITTEN THIS WAY — the "two Terminal windows" bug
--  ------------------------------------------------------------
--  The obvious version is:
--
--      tell application "Terminal"
--          activate                              -- the bug
--          do script "/bin/zsh .../console"
--      end tell
--
--  `activate` does not merely raise Terminal. When Terminal has to come up it
--  opens its own startup window ("Startup Window Settings"), and `do script`
--  then opens a SECOND window for the console. Closing the console window
--  leaves Terminal alive with zero windows, so the next launch lands in exactly
--  the same state — which is why it happens every time, never "sometimes".
--
--  Measured on macOS 26: a cold launch of Terminal ALWAYS produces its startup
--  window first, whichever way it is started — `activate`, `do script`, and
--  `open -a Terminal file.command` all end up with the startup window plus a
--  second window for the command. So the fix is not to create a second window
--  at all:
--
--    warm start (Terminal already up) -> `do script` makes exactly one window
--    cold start (Terminal not running) -> wait for the startup window, then run
--                                         the console INSIDE that very window
--
--  An earlier revision instead closed the leftover startup window afterwards.
--  That only works once the window has settled: closing it while its shell is
--  still starting leaves a permanently blank "ghost" window whose tab reports
--  `missing value`, which is worse than the problem it solved. Reusing the
--  window avoids the situation entirely — nothing is ever closed.
--
--  __CC_BIN__ is substituted with the absolute path to the console at build
--  time; AppleScript's `do shell script` does not inherit a login PATH.
-- =============================================================================

property ccBin : "__CC_BIN__"
property profileName : "Deep Sea"
property windowCols : 110
property windowRows : 32

-- Deliberately NOT `exec`. With exec the console REPLACES the login shell, so
-- when it exits the tab dies and Terminal is left holding a window whose tab is
-- `missing value` -- a state AppleScript cannot close at all. Run as a child
-- instead: the shell survives, the tab stays valid and idle, and the detached
-- close-window helper has something it can actually close. Worst case the user
-- lands on a usable shell prompt rather than a dead "[Process completed]" tab.
set launchCmd to "/bin/zsh " & quoted form of ccBin

if (do shell script "/bin/test -x " & quoted form of ccBin & " && echo yes || echo no") is not "yes" then
	display alert "DSH Control Center not found" message "Missing executable:" & return & return & ccBin & return & return & "Reinstall it with: npm install -g dsh-control-center" as critical
	return
end if

if application "Terminal" is running then
	-- Warm start: `do script` makes exactly one new window on its own. Calling
	-- `activate` first is what used to add the stray empty one.
	tell application "Terminal"
		set newTab to do script launchCmd
		delay 0.8
		set targetID to my windowOfTty(tty of newTab)
	end tell

else
	-- Cold start: bring Terminal up, wait for the startup window to exist, and
	-- run the console inside it. One window, nothing closed.
	tell application "Terminal" to activate
	repeat 150 times
		delay 0.1
		if (count of windows of application "Terminal") > 0 then exit repeat
	end repeat
	-- Let the fresh shell settle before typing into it.
	delay 1.2

	tell application "Terminal"
		if (count of windows) > 0 then
			set newTab to do script launchCmd in (selected tab of front window)
		else
			set newTab to do script launchCmd
		end if
		delay 0.8
		set targetID to my windowOfTty(tty of newTab)
	end tell
end if

my dress(targetID)


-- Locate the window owning a given tty. Window ids are stable; "front window"
-- is not, and restyling somebody else's terminal would be rude.
on windowOfTty(theTty)
	tell application "Terminal"
		repeat with w in windows
			try
				repeat with t in tabs of w
					if (tty of t) is theTty then return (id of w)
				end repeat
			end try
		end repeat
	end tell
	return -1
end windowOfTty


-- Apply the console's terminal profile and size, when the profile exists.
on dress(winID)
	if winID is -1 then return
	tell application "Terminal"
		try
			set theWin to (first window whose id is winID)
		on error
			return
		end try
		try
			set current settings of selected tab of theWin to settings set profileName
		end try
		try
			set custom title of selected tab of theWin to "DSH Control Center"
		end try
		try
			set number of columns of theWin to windowCols
			set number of rows of theWin to windowRows
		end try
		activate
	end tell
end dress
