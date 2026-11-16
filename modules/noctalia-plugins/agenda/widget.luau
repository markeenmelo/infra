--!nonstrict
local HORIZON_MS = 120 * 60000
local TITLE_CHARS = 16

noctalia.setUpdateInterval(60000)

local function shorten(title)
	title = title:gsub("%c", " ")
	local cut = utf8.offset(title, TITLE_CHARS + 1)
	return cut and cut <= #title and title:sub(1, cut - 1) .. "…" or title
end

function update()
	local now = noctalia.nowMs()
	local upcoming, current
	for _, event in ipairs(noctalia.calendarEvents() or {}) do
		if not event.allDay and event.endMs > now and event.startMs <= now + HORIZON_MS then
			if event.startMs > now then
				if not upcoming or event.startMs < upcoming.startMs then
					upcoming = event
				end
			elseif not current or event.startMs > current.startMs then
				current = event
			end
		end
	end
	local shown = upcoming or current
	barWidget.setVisible(shown ~= nil)
	if not shown then
		return
	end
	local minutes = math.ceil((shown.startMs - now) / 60000)
	barWidget.setGlyph("calendar-event")
	barWidget.setColor("on_surface")
	barWidget.setText(shorten(shown.title or "") .. " · " .. (minutes > 0 and minutes .. "m" or "now"))
end

function onClick()
	noctalia.runAsync({ "noctalia", "msg", "panel-open", "control-center", "calendar" })
end
