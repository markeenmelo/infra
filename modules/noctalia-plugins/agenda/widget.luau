--!nonstrict
local HORIZON_MS = 120 * 60000
local TITLE_CHARS = 16

noctalia.setUpdateInterval(60000)

local function shorten(title)
	title = title:gsub("%c", " ")
	local cut = utf8.offset(title, TITLE_CHARS + 1)
	return cut and title:sub(1, cut - 1) .. "…" or title
end

function update()
	local now = noctalia.nowMs()
	local next
	for _, event in ipairs(noctalia.calendarEvents() or {}) do
		if
			not event.allDay
			and event.endMs > now
			and event.startMs <= now + HORIZON_MS
			and (not next or event.startMs < next.startMs)
		then
			next = event
		end
	end
	barWidget.setVisible(next ~= nil)
	if not next then
		return
	end
	local minutes = math.ceil((next.startMs - now) / 60000)
	barWidget.setGlyph("calendar-event")
	barWidget.setColor("on_surface")
	barWidget.setText(shorten(next.title or "") .. " · " .. (minutes > 0 and minutes .. "m" or "now"))
end

function onClick()
	noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "calendar" })
end
