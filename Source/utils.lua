import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/math")
import("CoreLibs/object")
import("CoreLibs/timer")

das = playdate.datastore
fle = playdate.file
gfx = playdate.graphics
key = playdate.keyboard
sys = playdate.system

lerp = playdate.math.lerp

invertedColors = {[true] = playdate.graphics.kColorWhite, [false] = playdate.graphics.kColorBlack}
invertedDrawModes = {[true] = playdate.graphics.kDrawModeInverted, [false] = playdate.graphics.kDrawModeCopy}
invertedFillDrawModes = {[true] = playdate.graphics.kDrawModeFillWhite, [false] = playdate.graphics.kDrawModeFillBlack}

if sys ~= nil then
	gme = playdate.system.game
end

--SCRATCH KEEP THIS FUNCTION, BUILT-IN DOESNT HANDLE BOOLS
function indexOf(table, value) 
	if not table then return nil end
	for i,v in ipairs(table) do
		if v == value then return i end
	end
	return nil
end

function dictLength(table)
	local n = 0
	for k,v in pairs(table) do
		if k ~= nil then
			n+=1	
		end
	end
	return n
end

function generateDrawTextScaledImage(text, x, y, scale, font)
	local padding = text:upper() == text and 6 or 0 -- Weird padding hack?
	local w <const> = font:getTextWidth(text)
	local h <const> = font:getHeight() - padding
	local img <const> = gfx.image.new(w, h, gfx.kColorClear)
	local img2 <const> = gfx.image.new(w*scale*2, h*scale*2, gfx.kColorClear)
	
	gfx.pushContext(img)
	gfx.setFont(font)
	gfx.drawTextAligned(text, w / 2, 0, kTextAlignment.center)
	gfx.popContext()
	
	gfx.pushContext(img2)
	img:drawScaled((scale * w) / 2, (scale * h) / 2, scale)
	gfx.popContext()
	
	return img2
end

function indexFromPos(x,y,rows)
	local i = (x * rows) - (rows - y)
	return i
end

function posFromIndex(i, rows)
	local gridy = (i - 1) % rows + 1
	local gridx = math.ceil(i / rows)
	return gridx, gridy
end

function listCopy(orig)
	local copy
	
	if type(orig) == "table" then
		copy = {}
		for k, v in pairs(orig) do
			copy[k] = v
		end
	else
		-- number, string, boolean, etc.
		copy = orig
	end
	
	return copy
end

function listHasValue(tab, val)
	for index, value in pairs(tab) do
		if value == val then
			return true
		end
	end
	
	return false
end

function listHasKey(tab, val)
	for index, value in pairs(tab) do
		if index == val then
			return true
		end
	end
	
	return false
end

-- THIS FUNCTION IS SCRATCH'S
function parseAnimFile(animFile)
	if animFile == nil then
		return {loop = 0}
	end
	
	local info = {}
	local line = animFile:readline()
	local frames = {}
	local introFrames
	
	local addFramesToTable = function(frameTable, frameValues)
		for word in frameValues:gmatch("%s*([^,]+)") do
			local r = 1
			local frame = tonumber(word)
			if frame == nil then
				frame, r = word:match("(%d+) -x -(%d+)")
				if frame ~= nil then
					frame = tonumber(frame)
				end
				if r ~= nil then
					r = tonumber(r)
				end
			end
			if frame ~= nil and frame > 0 and r ~= nil and r > 0 then
				for i = 1, r do
					table.insert(frameTable, frame)
				end
			end
		end
	end
	while line ~= nil do
		local key, value = line:match("%s*(.-)%s*=%s*(.+)")
		if key ~= nil and value ~= nil then
			key = key:lower()
			if key == "frames" then
				addFramesToTable(frames, value)
			elseif key == "introframes" then
				introFrames = {}
				addFramesToTable(introFrames, value)
			elseif key == "loopcount" then
				local count = tonumber(value)
				if count ~= nil and count > 0 then
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

roundNumber = function(num, digits)
	local fmt = "%." .. digits .. "f"
	return tonumber(fmt:format(num))
end


-- THIS FUNCTION COMES FROM THE SETTINGS APP
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
	
	-- take off the decimal point
	local value = tostring(bytes)
	value = value:gsub("%.0$", "")
	
	local suffix = si[i]
	return value .. " " .. suffix
end

function easeInOutSine(t, b, c, d)
	return -c / 2 * (math.cos(math.pi * t / d) - 1) + b
end

function lerpFloored(a, b, t) 
	local v =  (a * (1 - t) + b * t) // 1
	if v ~= v then return 0 else return v end 
end

function lerpCeiled(a, b, t) 
	local v =  (a * (1 - t) + b * t) 
	v = -(-v//1)
	if v ~= v then return 0 else return v end 
end

function lerpMaxed(a, b, t) 
	local v =  (a * (1 - t) + b * t) 
	if a < b then
		v = -(-v//1)
	else
		v = v//1
	end
	if v ~= v then return 0 else return v end 
end

function lerpMinned(a, b, t) 
	local v =  (a * (1 - t) + b * t) 
	if a > b then
		v = -(-v//1)
	else
		v = v//1
	end
	if v ~= v then return 0 else return v end 
end

function getListSize(list)
	local l = 0
	for i,v in pairs(list) do
		l = l+1
	end
	
	return l
end

function makeOptionsValueReadable(value,type)
	if type == "BOOL" then
		if value then return "ON" else return "OFF" end	
	elseif type == "DITHER" then
		local s = roundNumber((1-value)*100, 0)
		s = tostring(s).."%"
		return s
	elseif type == "PIXELS" then
		return tostring(value).."px"	
	end
end