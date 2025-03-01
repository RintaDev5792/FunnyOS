import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
gfx = playdate.graphics
fle = playdate.file
gme = playdate.system.game
sys = playdate.system
das = playdate.datastore
key = playdate.keyboard

kPDGameStateFreshlyInstalled, kPDGameStateInstalled = nil, nil
if sys ~= nil then
	kPDGameStateFreshlyInstalled =gme.kPDGameStateFreshlyInstalled
	kPDGameStateInstalled = gme.kPDGameStateInstalled end

function generateDrawTextScaledImage(text, x, y, scale, font)
	local padding = string.upper(text) == text and 6 or 0 -- Weird padding hack?
	local w <const> = font:getTextWidth(text)
	local h <const> = font:getHeight() - padding
	local img <const> = gfx.image.new(w, h, gfx.kColorClear)
	local img2 <const> = gfx.image.new(w*scale*2, h*scale*2, gfx.kColorClear)
	gfx.lockFocus(img)
	gfx.setFont(font)
	gfx.drawTextAligned(text, w / 2, 0, kTextAlignment.center)
	gfx.unlockFocus()
	gfx.lockFocus(img2)
	img:drawScaled((scale * w) / 2, (scale * h) / 2, scale)
	gfx.unlockFocus()
	return img2
end

function indexOf(array, value)
	for i, v in ipairs(array) do
		if v == value then
			return i
		end
	end
	return nil
end

function indexFromPos(x,y,rows)
	local i = (x*rows) - (rows - y)
	return i
end

function posFromIndex(i, rows)
	local gridy = (i-1)%rows + 1
	local gridx = math.ceil(i/rows)
	return gridx,gridy
end

function listCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function listHasValue (tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

function listHasKey (tab, val)
	for index, value in pairs(tab) do
		if index == val then
			return true
		end
	end

	return false
end

--THIS FUNCTION IS SCRATCH'S
function parseAnimFile(animFile)
	if nil == animFile then
		return {loop = 0}
	end
	local info = {}
	local line = animFile:readline()
	local frames = {}
	local introFrames
	local addFramesToTable = function(frameTable, frameValues)
		for word in string.gmatch(frameValues, "%s*([^,]+)") do
			local r = 1
			local frame = tonumber(word)
			if nil == frame then
				frame, r = string.match(word, "(%d+) -x -(%d+)")
				if nil ~= frame then
					frame = tonumber(frame)
				end
				if nil ~= r then
					r = tonumber(r)
				end
			end
			if nil ~= frame and frame > 0 and nil ~= r and r > 0 then
				for i = 1, r do
					table.insert(frameTable, frame)
				end
			end
		end
	end
	while nil ~= line do
		local key, value = string.match(line, "%s*(.-)%s*=%s*(.+)")
		if nil ~= key and nil ~= value then
			key = key:lower()
			if "frames" == key then
				addFramesToTable(frames, value)
			elseif "introframes" == key then
				introFrames = {}
				addFramesToTable(introFrames, value)
			elseif "loopcount" == key then
				local count = tonumber(value)
				if nil ~= count and count > 0 then
					info.loop = count
				end
			end
			line = animFile:readline()
		end
	end
	if #frames > 0 then
		info.frames = frames
		info.introFrames = introFrames
	end
	info.loop = info.loop or 0
	return info
end

function readableBytes(bytes, maxDecimalPlaces)
	local si = {
		"B",
		"KB",
		"MB",
		"GB",
		"TB",
		"PB",
		"EB",
		"ZB",
		"YB"
	}
	local decimalPlaces = maxDecimalPlaces or 1
	local roundNumber = function(num, digits)
		local fmt = "%." .. digits .. "f"
		return tonumber(fmt:format(num))
	end
	local negative = bytes < 0
	if negative then
		bytes = -bytes
	end
	local kbit = 1000.0
	local i = 1
	while i <= #si and bytes >= kbit do
		bytes = bytes / kbit
		i = i + 1
	end
	if negative then
		bytes = -bytes
	end
	bytes = roundNumber(bytes, decimalPlaces)
	local value = tostring(bytes)
	value = value:gsub("%.0$", "")
	local suffix = si[i]
	return value .. " " .. suffix
end

function easeInOutSine(t, b, c, d)
	return -c/2 * (math.cos(math.pi*t/d) - 1) + b
end

function lerp(a,b,t) 
	return a * (1-t) + b * t 
end
function lerpFloored(a,b,t) 
	return math.floor(a * (1-t) + b * t) 
end
function getListSize(list)
	local l = 0
	for i,v in pairs(list) do
		l=l+1
	end
	return l
end