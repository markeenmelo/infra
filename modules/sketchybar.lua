local sbar = require("sketchybar")

local function color(alpha, hex)
  return tonumber("0x" .. alpha .. hex)
end

local colors = {
  bar = color("@alpha@", "@base00@"),
  bg = color("ff", "@base00@"),
  surface = color("@alpha@", "@base01@"),
  selection = color("ff", "@base02@"),
  muted = color("ff", "@base03@"),
  fg = color("ff", "@base05@"),
  critical = color("ff", "@base08@"),
  warning = color("ff", "@base0A@"),
  accent = color("ff", "@base0D@"),
}
local font = "@font@"
local workspaces = { @workspaces@ }
local icalbuddy = "@icalbuddy@"
local grafana = "@grafana@"
local tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function popup_rows(parent)
  return { parent = parent }
end

local function fill_rows(rows, lines, empty)
  if #lines == 0 then
    lines = { empty }
  end
  for i = #rows + 1, #lines do
    rows[i] = sbar.add("item", rows.parent.name .. ".row." .. i, {
      position = "popup." .. rows.parent.name,
      icon = { drawing = "off" },
      label = { padding_left = 8, padding_right = 8 },
    })
  end
  for i, row in ipairs(rows) do
    local line = lines[i]
    if line then
      row:set({ drawing = "on", label = { string = line.text or line, color = line.color or colors.fg } })
      if line.click then
        row:set({ click_script = line.click })
      end
    else
      row:set({ drawing = "off" })
    end
  end
end

local function close_on_leave(item)
  item:subscribe("mouse.exited.global", function()
    item:set({ popup = { drawing = "off" } })
  end)
end

sbar.begin_config()

sbar.bar({
  height = 32,
  position = "top",
  sticky = "on",
  color = colors.bar,
  blur_radius = 20,
  padding_left = 8,
  padding_right = 8,
})

sbar.default({
  padding_left = 4,
  padding_right = 4,
  icon = { font = font .. ":Bold:15.0", color = colors.fg, padding_right = 4 },
  label = { font = font .. ":Bold:13.0", color = colors.fg },
  background = { color = colors.accent, corner_radius = 4, height = 22, drawing = "off" },
  popup = { background = { color = colors.surface, corner_radius = 4 }, blur_radius = 20 },
})

sbar.add("event", "aerospace_workspace_change")
local spaces = {}
local function focus(name)
  for n, space in pairs(spaces) do
    local on = n == name
    space:set({ label = { color = on and colors.bg or colors.fg }, background = { drawing = on and "on" or "off" } })
  end
end
for _, n in ipairs(workspaces) do
  spaces[n] = sbar.add("item", "space." .. n, {
    position = "left",
    icon = { drawing = "off" },
    label = { string = n, padding_left = 8, padding_right = 8 },
    click_script = "aerospace workspace " .. n,
  })
end
spaces[workspaces[1]]:subscribe("aerospace_workspace_change", function(env)
  focus(env.FOCUSED_WORKSPACE)
end)
sbar.exec("aerospace list-workspaces --focused", function(out)
  focus(trim(out))
end)

local front_app = sbar.add("item", "front_app", { position = "left", icon = { drawing = "off" } })
front_app:subscribe("front_app_switched", function(env)
  front_app:set({ label = { string = env.INFO } })
end)

sbar.add("event", "spotify_change", "com.spotify.client.PlaybackStateChanged")
local media = sbar.add("item", "media", {
  position = "left",
  drawing = "off",
  icon = { string = "󰎆" },
  label = { max_chars = 40 },
})
media:subscribe("spotify_change", function(env)
  local info = type(env.INFO) == "table" and env.INFO or {}
  local state = info["Player State"]
  if state == "Playing" or state == "Paused" then
    media:set({
      drawing = "on",
      icon = { string = state == "Playing" and "󰎆" or "󰏤", color = state == "Playing" and colors.fg or colors.muted },
      label = { string = (info.Artist or "") .. " - " .. (info.Name or ""), color = colors.muted },
    })
  else
    media:set({ drawing = "off" })
  end
end)
media:subscribe("mouse.clicked", function(env)
  local action = env.BUTTON == "right" and "next track" or "playpause"
  sbar.exec("osascript -e 'tell application \"Spotify\" to " .. action .. "'")
end)

local agenda_command = icalbuddy
  .. [[ -n -nc -b "" -ps "| |" -iep datetime,title -po datetime,title -tf %H:%M -df "" eventsToday]]

local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 10,
  icon = { drawing = "off" },
  popup = { align = "right" },
})
clock:subscribe({ "routine", "forced", "system_woke" }, function()
  clock:set({ label = { string = os.date("%a %d %b %H:%M") } })
end)
local events = popup_rows(clock)
local function toggle_agenda()
  sbar.exec(agenda_command, function(out)
    local lines = {}
    for line in tostring(out):gmatch("[^\n]+") do
      table.insert(lines, trim(line))
    end
    fill_rows(events, lines, { text = "No more events today", color = colors.muted })
    clock:set({ popup = { drawing = "toggle" } })
  end)
end
clock:subscribe("mouse.clicked", toggle_agenda)
close_on_leave(clock)

local battery = sbar.add("item", "battery", { position = "right", update_freq = 120 })
battery:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, function()
  sbar.exec("pmset -g batt", function(out)
    out = tostring(out)
    local percent = out:match("(%d+)%%")
    if not percent then
      battery:set({ drawing = "off" })
      return
    end
    battery:set({
      drawing = "on",
      icon = { string = out:find("AC Power", 1, true) and "󰂄" or "󰁹" },
      label = { string = percent .. "%" },
    })
  end)
end)

local volume = sbar.add("item", "volume", { position = "right", popup = { align = "right" } })
local volume_slider = sbar.add("slider", "volume.slider", 120, {
  position = "popup.volume",
  slider = {
    highlight_color = colors.accent,
    background = { height = 4, corner_radius = 2, color = colors.selection },
    knob = { drawing = "off" },
  },
})
local function show_volume(level)
  level = math.floor(tonumber(level) or 0)
  volume:set({ icon = { string = level == 0 and "󰝟" or "󰕾" }, label = { string = level .. "%" } })
  volume_slider:set({ slider = { percentage = level } })
end
volume:subscribe("volume_change", function(env)
  show_volume(env.INFO)
end)
volume:subscribe("mouse.clicked", function()
  volume:set({ popup = { drawing = "toggle" } })
end)
volume:subscribe("mouse.scrolled", function(env)
  local delta = math.floor(tonumber(env.SCROLL_DELTA) or 0)
  sbar.exec("osascript -e 'set volume output volume ((output volume of (get volume settings)) + " .. delta .. ")'")
end)
volume_slider:subscribe("mouse.clicked", function(env)
  sbar.exec("osascript -e 'set volume output volume " .. math.floor(tonumber(env.PERCENTAGE) or 0) .. "'")
end)
close_on_leave(volume)
sbar.exec("osascript -e 'output volume of (get volume settings)'", show_volume)

local network = sbar.add("item", "network", { position = "right", update_freq = 60, label = { drawing = "off" } })
network:subscribe({ "routine", "forced", "wifi_change", "system_woke" }, function()
  sbar.exec(
    [[wifi=$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2 }')
    if [ -n "$wifi" ] && ipconfig getifaddr "$wifi" >/dev/null; then echo wifi
    elif route -n get default >/dev/null 2>&1; then echo wired
    else echo off; fi]],
    function(out)
      local icons = { wifi = "󰖩", wired = "󰈀", off = "󰖪" }
      network:set({ icon = { string = icons[trim(out)] or icons.off } })
    end
  )
end)

sbar.add("event", "tailnet_change")
local tailnet = sbar.add("item", "tailnet", {
  position = "right",
  update_freq = 30,
  icon = { string = "󰦝" },
  popup = { align = "right" },
})
local exit_nodes = popup_rows(tailnet)
local function short_name(peer)
  return (peer.DNSName or ""):match("^[^.]+")
end
local function current_exit(status)
  for _, peer in pairs(status.Peer or {}) do
    if peer.ExitNode then
      return short_name(peer)
    end
  end
  return "direct"
end
tailnet:subscribe({ "routine", "forced", "system_woke", "tailnet_change" }, function()
  sbar.exec(tailscale .. " status --json", function(status)
    if type(status) ~= "table" or status.BackendState ~= "Running" then
      tailnet:set({ icon = { color = colors.muted }, label = { string = "off" } })
    else
      tailnet:set({ icon = { color = colors.fg }, label = { string = current_exit(status) } })
    end
  end)
end)
tailnet:subscribe("mouse.clicked", function()
  sbar.exec(tailscale .. " status --json", function(status)
    if type(status) ~= "table" then
      return
    end
    local current = current_exit(status)
    local names = {}
    for _, peer in pairs(status.Peer or {}) do
      local name = short_name(peer)
      if peer.ExitNodeOption and peer.Online and name and name:match("^[%w-]+$") then
        table.insert(names, name)
      end
    end
    table.sort(names)
    table.insert(names, 1, "direct")
    local lines = {}
    for _, name in ipairs(names) do
      local flags = name == "direct" and "--exit-node=" or ("--exit-node=" .. name .. " --exit-node-allow-lan-access")
      table.insert(lines, {
        text = name,
        color = name == current and colors.accent or colors.fg,
        click = tailscale
          .. " set "
          .. flags
          .. "; sketchybar --set tailnet popup.drawing=off --trigger tailnet_change",
      })
    end
    fill_rows(exit_nodes, lines)
    tailnet:set({ popup = { drawing = "toggle" } })
  end)
end)
close_on_leave(tailnet)

local memory = sbar.add("item", "memory", { position = "right", icon = { string = "󰍛" } })
local cpu = sbar.add("item", "cpu", { position = "right", update_freq = 10, icon = { string = "󰻠" } })
cpu:subscribe({ "routine", "forced" }, function()
  sbar.exec(
    [[cpu=$(ps -A -o %cpu | awk -v n="$(getconf _NPROCESSORS_ONLN)" '{ s += $1 } END { printf "%.0f", s / n }')
    mem=$(memory_pressure | awk '/free percentage/ { gsub("%", "", $5); print 100 - $5 }')
    echo "$cpu $mem"]],
    function(out)
      local c, m = tostring(out):match("(%d+)%s+(%d+)")
      cpu:set({ label = { string = (c or "?") .. "%" } })
      memory:set({ label = { string = (m or "?") .. "%" } })
    end
  )
end)

local alerts = sbar.add("item", "alerts", {
  position = "right",
  drawing = "off",
  update_freq = 60,
  icon = { string = "󰂚" },
  click_script = "open '" .. grafana .. "/alerting/list'",
})
alerts:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec(
    [[printf 'Authorization: Bearer %s\n' "$(cat @grafanaToken@)" | curl -fsS --max-time 10 -H @- "]]
      .. grafana
      .. [[/api/alertmanager/grafana/api/v2/alerts?active=true&silenced=false&inhibited=false"]],
    function(result, exit_code)
      if exit_code ~= 0 or type(result) ~= "table" then
        alerts:set({ drawing = "on", icon = { color = colors.muted }, label = { string = "?" } })
        return
      end
      local critical, warning = 0, 0
      for _, alert in ipairs(result) do
        local severity = alert.labels and alert.labels.severity
        if severity == "critical" then
          critical = critical + 1
        elseif severity == "warning" then
          warning = warning + 1
        end
      end
      if critical > 0 then
        alerts:set({ drawing = "on", icon = { color = colors.critical }, label = { string = tostring(critical + warning) } })
      elseif warning > 0 then
        alerts:set({ drawing = "on", icon = { color = colors.warning }, label = { string = tostring(warning) } })
      else
        alerts:set({ drawing = "off" })
      end
    end
  )
end)

local agenda = sbar.add("item", "agenda", { position = "right", update_freq = 300, icon = { drawing = "off" } })
agenda:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec(agenda_command .. " | head -1", function(out)
    agenda:set({ label = { string = trim(out) } })
  end)
end)
agenda:subscribe("mouse.clicked", toggle_agenda)

sbar.end_config()
sbar.exec("sketchybar --update")
sbar.event_loop()
