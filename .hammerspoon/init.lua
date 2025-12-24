-- /Users/mekann/.hammerspoon/init.lua
-- Hammerspoon のホットキーと AeroSpace 連携を管理する設定
-- AeroSpace 側のホットキーと競合しないように制御するため
-- 関連ファイル: ~/.config/aerospace/aerospace.toml, ~/.hammerspoon/Spoons, /Users/mekann/.hammerspoon/init.lua
-- ==============================================================================
-- ┌────────────────────────────────────────────────────────────────────────────┐
-- │                                                                            │
-- │  ██╗  ██╗ █████╗ ███╗   ███╗███╗   ███╗███████╗██████╗     S P O O N       │
-- │  ██║  ██║██╔══██╗████╗ ████║████╗ ████║██╔════╝██╔══██╗    C O N F I G     │
-- │  ███████║███████║██╔████╔██║██╔████╔██║█████╗  ██████╔╝    ────────────────│
-- │  ██╔══██║██╔══██║██║╚██╔╝██║██║╚██╔╝██║██╔══╝  ██╔══██╗    macOS Automation│
-- │  ██║  ██║██║  ██║██║ ╚═╝ ██║██║ ╚═╝ ██║███████╗██║  ██║    By Mekann       │
-- │  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝                    │
-- │                                                                            │
-- └────────────────────────────────────────────────────────────────────────────┘
-- ==============================================================================

-- /Users/mekann/.hammerspoon/init.lua
-- Alt+Wheel(T/通常/D) / Alt+Shift+Wheel / Alt+N,B / Alt+Shift+N,B によるワークスペース制御
-- AeroSpace CLI を通じて、切替と「ウィンドウを連れて移動」を安定提供
-- 関連: ~/.config/aerospace/aerospace.toml, ~/.hammerspoon/Spoons

local AEROSPACE = "/opt/homebrew/bin/aerospace"
-- local AEROSPACE = "/usr/local/bin/aerospace"
local KITTY_CANDIDATES = {
  "/opt/homebrew/bin/kitty",
  "/usr/local/bin/kitty",
  "/Applications/kitty.app/Contents/MacOS/kitty",
}

local IDLE_GAP        = 0.10
local STEP_THRESHOLD  = 1
local DIR_UP             = "prev"
local DIR_DOWN           = "next"
local WORKSPACE_T        = "T"
local WORKSPACE_D        = "D"
local NORMAL_WS_PATTERN  = "^[1-7]$"
local TASK_TIMEOUT    = 1.5
local DOUBLE_ALT_GAP  = 0.35

-- AeroSpace に Alt+N/B を渡す場合は false にする
local ENABLE_HAMMERSPOON_ALT_NB = false

-- スクロール操作を AeroSpace のホットキーに変換する場合は true
local USE_AEROSPACE_HOTKEYS = true

-- Alt+クリックでワークスペース切替を行う場合は true
local ENABLE_ALT_CLICK = true

-- Alt+クリックは通常ワークスペース(1-7)のみ移動
-- Alt+右クリック/Alt+ひらりクリックの割り当て
local ALT_CLICK_MAP = {
  right = DIR_DOWN,
  left = DIR_UP,
}

-- Alt 押下中のスクロール抑止
local ALT_BLOCK_SCROLL   = true
local ALT_RELEASE_GRACE  = 0.12

-- ========= ユーティリティ =========
local function fileExists(p) return hs.fs.attributes(p) ~= nil end
local function findKitty()
  for _, p in ipairs(KITTY_CANDIDATES) do
    if fileExists(p) then return p end
  end
  return nil
end

-- ========= 実行中ガード =========
local busy, currentTask, watchdogTimer = false, nil, nil
local function resetTaskState()
  busy = false
  currentTask = nil
  if watchdogTimer then
    watchdogTimer:stop()
    watchdogTimer = nil
  end
end

-- ========= 操作種別 =========
local OP_WORKSPACE        = "workspace"        -- ワークスペース切替
local OP_WORKSPACE_ID     = "workspace-id"     -- 指定ワークスペースへ移動
local OP_WORKSPACE_NORMAL = "workspace-normal" -- 通常WS(1-7)のみで移動
local OP_MOVE_NODE        = "move-node"        -- ウィンドウを前後WSへ移動

-- ========= AeroSpace ホットキー変換 =========
local AEROSPACE_HOTKEYS = {
  switch = {
    prev = {mods = {"alt"},          key = "b"},
    next = {mods = {"alt"},          key = "n"},
  },
  move = {
    prev = {mods = {"alt", "shift"}, key = "b"},
    next = {mods = {"alt", "shift"}, key = "n"},
  },
}

local function sendAerospaceHotkey(dir, op)
  local map = (op == OP_MOVE_NODE) and AEROSPACE_HOTKEYS.move or AEROSPACE_HOTKEYS.switch
  local def = (dir == DIR_UP) and map.prev or map.next
  if not def then return end

  -- 明示的に keyDown/keyUp を発火して確実に送る
  hs.eventtap.event.newKeyEvent(def.mods, def.key, true):post()
  hs.eventtap.event.newKeyEvent(def.mods, def.key, false):post()
end

local function triggerAerospace(dir, op)
  if USE_AEROSPACE_HOTKEYS then
    sendAerospaceHotkey(dir, op)
  else
    runAerospace(dir, op)
  end
end

-- ========= AeroSpace 実行ヘルパー =========
local function runAerospace(dir, op)
  if not fileExists(AEROSPACE) then
    hs.alert.show("aerospace が見つからない: "..AEROSPACE)
    return
  end
  if busy then return end
  busy = true

  local execPath, execArgs, label
  if op == OP_MOVE_NODE then
    -- フォーカス維持でウィンドウを移動
    execPath = AEROSPACE
    execArgs = {"move-node-to-workspace", "--wrap-around", "--focus-follows-window", dir}
    label = "move-node"
  elseif op == OP_WORKSPACE_ID then
    -- ワークスペースを直接指定して移動
    execPath = AEROSPACE
    execArgs = {"workspace", dir}
    label = "workspace-id"
  elseif op == OP_WORKSPACE_NORMAL then
    -- 通常ワークスペース(1-7)のみ巡回
    local cmd = string.format(
      "%q list-workspaces --monitor focused --format '%%{workspace}' | grep -E '%s' | %q workspace --stdin --wrap-around %s",
      AEROSPACE,
      NORMAL_WS_PATTERN,
      AEROSPACE,
      dir
    )
    execPath = "/bin/bash"
    execArgs = {"-lc", cmd}
    label = "workspace-normal"
  else
    -- モニター内の妥当なワークスペースに絞ってから wrap-around で移動
    local cmd = string.format("%q list-workspaces --monitor focused | %q workspace --wrap-around %s", AEROSPACE, AEROSPACE, dir)
    execPath = "/bin/bash"
    execArgs = {"-lc", cmd}
    label = "workspace"
    op = OP_WORKSPACE
  end

  currentTask = hs.task.new(execPath, function() resetTaskState() end, execArgs)
  if not currentTask or not currentTask:start() then
    resetTaskState()
    hs.alert.show("aerospace 実行に失敗: "..label.." "..dir)
    return
  end

  if watchdogTimer then watchdogTimer:stop() end
  watchdogTimer = hs.timer.doAfter(TASK_TIMEOUT, function()
    if not busy then return end
    if currentTask then currentTask:terminate() end
    resetTaskState()
    hs.alert.show("aerospace 応答なしでタイムアウト: "..label.." "..dir)
  end)
end

-- ========= ワークスペース取得 =========
local lastNormalWorkspace = nil

local function trim(s)
  return (s:gsub("%s+$", ""))
end

local function getFocusedWorkspace()
  if not fileExists(AEROSPACE) then return nil end
  local cmd = string.format("%q list-workspaces --focused --format '%%{workspace}'", AEROSPACE)
  local out = hs.execute(cmd)
  if not out then return nil end
  out = trim(out)
  if out == "" then return nil end
  return out
end

local function isNormalWorkspace(ws)
  return ws and ws:match(NORMAL_WS_PATTERN) ~= nil
end

local function getNormalWorkspaceFallback()
  if not fileExists(AEROSPACE) then return nil end
  local cmd = string.format("%q list-workspaces --monitor focused --format '%%{workspace}'", AEROSPACE)
  local out = hs.execute(cmd) or ""
  for ws in out:gmatch("[^\r\n]+") do
    if ws:match(NORMAL_WS_PATTERN) then
      return ws
    end
  end
  return nil
end

local function getNormalWorkspaceForReturn()
  if isNormalWorkspace(lastNormalWorkspace) then
    return lastNormalWorkspace
  end
  return getNormalWorkspaceFallback()
end

local function moveAltScroll(dir)
  local focused = getFocusedWorkspace()
  if not focused then return end

  if isNormalWorkspace(focused) then
    lastNormalWorkspace = focused
  end

  if dir == DIR_UP then
    if focused == WORKSPACE_T then
      return
    end
    if focused == WORKSPACE_D then
      local target = getNormalWorkspaceForReturn()
      if target then runAerospace(target, OP_WORKSPACE_ID) end
      return
    end
    runAerospace(WORKSPACE_T, OP_WORKSPACE_ID)
    return
  end

  -- DIR_DOWN
  if focused == WORKSPACE_D then
    return
  end
  if focused == WORKSPACE_T then
    local target = getNormalWorkspaceForReturn()
    if target then runAerospace(target, OP_WORKSPACE_ID) end
    return
  end
  runAerospace(WORKSPACE_D, OP_WORKSPACE_ID)
end

-- ========= Alt/Shift 抑止ロジック =========
local guardUntil = 0
local function nowSec() return hs.timer.absoluteTime() / 1e9 end

-- ========= Option 二連打で kitty =========
-- Alt(Option) 連打カウンタ
local lastAltTap, altTapCount, altTapTimer = 0, 0, nil

local function launchKitty()
  local kitty = findKitty()
  if not kitty then
    hs.alert.show("kitty が見つからない")
    return
  end

  -- 【修正箇所】
  -- hs.task.new は Hammerspoon リロード時に子プロセスを道連れ終了させるため廃止。
  -- 代わりに hs.execute を使い、末尾に " &" をつけてプロセスを切り離して実行します。
  -- string.format("%q") でパスのスペースなどをエスケープ処理しています。
  hs.execute(string.format("%q --single-instance > /dev/null 2>&1 &", kitty))
end

-- Vivaldi Snapshot で chatgpt.com を新しい OS ウィンドウで開く
local function openChatGPTInVivaldi()
  local appPath = "/Applications/Vivaldi Snapshot.app"

  -- openコマンドは実行後すぐに終了するため、hs.task でも道連れ終了の影響を受けません
  local task = hs.task.new("/usr/bin/open", function() end, {
    "-n",
    "-a", appPath,
    "--args",
    "--new-window",
    "https://chatgpt.com",
  })
  if not task or not task:start() then
    hs.alert.show("Vivaldi Snapshot で chatgpt.com を開けなかった")
  end
end

if optionDoubleTap then optionDoubleTap:stop() end
optionDoubleTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
  local code = e:getKeyCode()
  if code ~= 58 and code ~= 61 then return false end  -- 58: left option, 61: right option

  local flags = e:getFlags()
  if not flags.alt then return false end

  local t = nowSec()
  if (t - lastAltTap) <= DOUBLE_ALT_GAP then
    altTapCount = altTapCount + 1
  else
    altTapCount = 1
  end
  lastAltTap = t

  -- 以前のタイマーがあればキャンセル
  if altTapTimer then
    altTapTimer:stop()
    altTapTimer = nil
  end

  -- 「最後のタップから DOUBLE_ALT_GAP 経過した時点」で回数を確定させる
  altTapTimer = hs.timer.doAfter(DOUBLE_ALT_GAP, function()
    if altTapCount == 2 then
      -- ダブルタップ: kitty
      launchKitty()
    elseif altTapCount >= 3 then
      -- トリプルタップ以上: Vivaldi Snapshot の新しい OS ウィンドウで chatgpt.com
      openChatGPTInVivaldi()
    end
    altTapCount = 0
    altTapTimer = nil
  end)

  return false
end)
optionDoubleTap:start()

-- 戻り値: shouldBlock, altActive, shiftActive
local function altBlockState()
  if not ALT_BLOCK_SCROLL then return false, false, false end
  local m = hs.eventtap.checkKeyboardModifiers()
  local t = nowSec()
  if m.alt then
    guardUntil = t + ALT_RELEASE_GRACE
    return true, true, m.shift or false
  end
  return t < guardUntil, false, false
end

-- ========= スクロール集約（切替/移動を分離） =========
local sumSwitch, sumMove = 0, 0
local debounceSwitch, debounceMove = nil, nil

local function flushSwitch()
  debounceSwitch = nil
  local s = sumSwitch; sumSwitch = 0
  if s == 0 or math.abs(s) < STEP_THRESHOLD then return end
  -- Alt+Wheel は T / 通常 / D の三点移動
  local dir = (s > 0) and DIR_UP or DIR_DOWN
  moveAltScroll(dir)
end

local function flushMove()
  debounceMove = nil
  local s = sumMove; sumMove = 0
  if s == 0 or math.abs(s) < STEP_THRESHOLD then return end
  triggerAerospace((s > 0) and DIR_UP or DIR_DOWN, OP_MOVE_NODE)
end

-- ========= Alt+Wheel / Alt+Shift+Wheel =========
if workspaceAltWheelTap then workspaceAltWheelTap:stop() end
workspaceAltWheelTap = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(e)
  local shouldBlock, altActive, shiftActive = altBlockState()

  if not shouldBlock then
    return false  -- 通常スクロール
  end

  if altActive then
    local dy
    if shiftActive then
      -- macOS は Shift+スクロールで横スクロール（Axis2）に値が入る
      dy = e:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis2) or 0
      if dy == 0 then
        -- 一部デバイスは Axis1 を使うのでフォールバック
        dy = e:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
      end
    else
      dy = e:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
    end
    if shiftActive then
      -- Alt+Shift+Wheel → ウィンドウを移動
      sumMove = sumMove + dy
      if debounceMove then debounceMove:stop() end
      debounceMove = hs.timer.doAfter(IDLE_GAP, flushMove)
    else
      -- Alt+Wheel → T / 通常 / D の切替
      sumSwitch = sumSwitch + dy
      if debounceSwitch then debounceSwitch:stop() end
      debounceSwitch = hs.timer.doAfter(IDLE_GAP, flushSwitch)
    end
  end

  return true  -- Alt中はスクロール抑止
end)
workspaceAltWheelTap:start()

-- ========= Alt+Right / Alt+Other Click =========
if altClickTap then altClickTap:stop() end
altClickTap = hs.eventtap.new({
  hs.eventtap.event.types.rightMouseDown,
  hs.eventtap.event.types.leftMouseDown,
}, function(e)
  if not ENABLE_ALT_CLICK then
    return false
  end

  local flags = e:getFlags()
  if not flags.alt then
    return false
  end

  local t = e:getType()
  if t == hs.eventtap.event.types.rightMouseDown then
    runAerospace(ALT_CLICK_MAP.right, OP_WORKSPACE_NORMAL)
    return true
  end

  if t == hs.eventtap.event.types.leftMouseDown then
    runAerospace(ALT_CLICK_MAP.left, OP_WORKSPACE_NORMAL)
    return true
  end

  return false
end)
altClickTap:start()

-- ========= Alt+N/B / Alt+Shift+N/B =========
local function bindWorkspaceHotkeys()
  if not ENABLE_HAMMERSPOON_ALT_NB then
    return
  end

  -- Alt 系は切替、Alt+Shift 系はノード移動
  local bindings = {
    {mods = {"alt"},            key = "n", dir = DIR_DOWN, op = OP_WORKSPACE},
    {mods = {"alt"},            key = "b", dir = DIR_UP,   op = OP_WORKSPACE},
    {mods = {"alt", "shift"},   key = "n", dir = DIR_DOWN, op = OP_MOVE_NODE},
    {mods = {"alt", "shift"},   key = "b", dir = DIR_UP,   op = OP_MOVE_NODE},
  }

  for _, def in ipairs(bindings) do
    hs.hotkey.bind(def.mods, def.key, function()
      runAerospace(def.dir, def.op)
    end)
  end
end
bindWorkspaceHotkeys()

-- ========= ユーティリティ =========
hs.hotkey.bind({"cmd","alt","ctrl"}, "R", function() hs.reload() end)
local alertParts = {
  "Alt+Wheel: T / normal / D",
  "Alt+Shift+Wheel: move window",
}
if ENABLE_ALT_CLICK then
  table.insert(alertParts, "Alt+Right: next normal / Alt+Left: prev normal")
end
if ENABLE_HAMMERSPOON_ALT_NB then
  table.insert(alertParts, "Alt+N,B: switch / Alt+Shift+N,B: move window")
end
hs.alert.show(table.concat(alertParts, " / "))
