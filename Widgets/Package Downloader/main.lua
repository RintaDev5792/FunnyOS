local VERSION = 1

local widget = {}

local MODE_PROMPT_REFRESH = 0
local MODE_LOADING = 1
local MODE_SHOW_MESSAGE = 2
local MODE_LISTING = 3

local PACKAGE_ROOT = "/RintaDev5792/FunnyOS/refs/heads/main/Assets/Packages"
if fos and fos.getenv then
	PACKAGE_ROOT = fos.getenv("FOS_PACKAGE_ROOT") or PACKAGE_ROOT
end
print("Using package root: ", PACKAGE_ROOT)
local PACKAGE_FILE = joinPaths(PACKAGE_ROOT, "packages.json")

-- path is filled out when loaded by system
widget.metadata = {
	name = "Package Downloader",
	game = nil,
	path = nil,
}

widget.image = nil
widget.package_hierarchy = nil
widget.mode = MODE_PROMPT_REFRESH
widget.t = 0

-- Fill these out with your inputs
function widget:AButtonUp()
	-- TODO
end

-- If a B button function isn't provided, this is the default action for it.
function widget:BButtonUp()
	-- Removes focus from the widget so others can be selected
	-- Need this line somewhere if you use the B button.
	widgetIsActive = false
	widget:loadWidgetImage()
end

local function get_package_list()
	local http = widget.http
	http:setConnectTimeout(30)
	http:setRequestCompleteCallback(
		function()
			print("A")
			local data = ""
			while true do
				local d = http:read()
				if not d or #d == 0 then
					break
				end
				data = data .. d
			end
			if data and widget.http then
				widget.http = nil
				widget.db = json.decode(data)
				if widget.db then
					if widget.db.version == VERSION then
						widget.dir = {}
						widget.http = nil
						widget.mode = MODE_LISTING
					else
						widget.mode = MODE_SHOW_MESSAGE
						widget.message = "Package database\nversion mismatch.\nPlease update manually."
						widget.t = 0
					end
				else
					widget.t = 0
					widget.mode = MODE_SHOW_MESSAGE
					widget.message = "Invalid package\ndatabase received"
				end
			else
				print("Err: ", http:getError())
			end
		end
	)
	http:setConnectionClosedCallback(
		function()
			print("B")
			if widget.http then
				widget.http = nil
				widget.mode = MODE_PROMPT_REFRESH
			end
		end
	)
	http:setRequestCallback(function()
		print("C")
	end)
	http:setHeadersReadCallback(function()
		print("D")
		local status = http:getResponseStatus()
		if widget.http and status ~= 200 and status ~= 0 then
			widget.http = nil
			widget.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Connection Failed", "*HTTP Status: " .. tostring(status), nil)
		end
	end)
	print("GET", PACKAGE_FILE)
	http:get(PACKAGE_FILE)
end

function get_package_list_prepare()
	playdate.network.setEnabled(true, function(err)
		if err then 
			widget.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Failed to Enable Networking", "*" .. err, nil)
		else
			--[[
			local status = playdate.network.getStatus()
			if status == playdate.network.kStatusNotConnected then
				widget.message = "Network Not Connected"
				widget.mode = MODE_SHOW_MESSAGE
				widget.t = 0
				return
			elseif playdate.network.kStatusNotAvailable then
				widget.message = "Network Not Available"
				widget.mode = MODE_SHOW_MESSAGE
				widget.t = 0
				return
			end
			]]
			
			if not widget.http then
				widget.http = playdate.network.http.new("raw.githubusercontent.com", 0, true, "to list downloadable packages")
				if not widget.http then
					widget.mode = MODE_PROMPT_REFRESH
				else
					get_package_list()
				end
			end
		end
	end)
end

function widget:AButtonDown()
	if widget.mode == MODE_SHOW_MESSAGE and widget.t > 15 then
		widget.mode = MODE_PROMPT_REFRESH
	elseif widget.mode == MODE_PROMPT_REFRESH then
		widget.t = 0
		widget.mode = MODE_LOADING
		widget.pending = get_package_list_prepare
	end
end

function widget:BButtonDown()
	
end

function widget:upButtonDown()
	
end

function widget:downButtonDown()
	
end

function widget:leftButtonDown()
	
end

function widget:rightButtonDown()
	
end

function widget:upButtonUp()
	
end

function widget:downButtonUp()
	
end

function widget:leftButtonUp()
	
end

function widget:rightButtonUp()
	
end

-- Refresh the widget image
function widget:loadWidgetImage()
	if not widget.image then
		widget.image = playdate.graphics.image.new(200, 200)
	end
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		gfx.drawTextAligned("*" .. widget.metadata.name .. "*",100, 7,kTextAlignment.center)
		
		if widget.mode == MODE_PROMPT_REFRESH and widgetIsActive then
			gfx.drawTextAligned("*Press (A) To Refresh*",100, 100,kTextAlignment.center)
		elseif widget.mode == MODE_SHOW_MESSAGE then
			gfx.drawTextAligned(widget.message,100, 100,kTextAlignment.center)
		elseif widget.mode == MODE_LOADING then
			local s = "."
			if widget.t % 32 > 8 then
				s = ".."
			end
			if widget.t % 32 > 16 then
				s = "..."
			end
			gfx.drawTextAligned("*" .. s .. "*",100, 100, kTextAlignment.center)
		end
		
		if widgetIsActive then
			gfx.setColor(gfx.kColorBlack)
			gfx.fillRect(0, 200-24, 200, 24)
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			local curveImg = gfx.image.new(200,configVars.cornerradius,gfx.kColorBlack)
			local maskImg = gfx.image.new(200,configVars.cornerradius,gfx.kColorWhite)
			gfx.pushContext(maskImg)
				gfx.setColor(gfx.kColorBlack)
				gfx.fillRoundRect(0, -configVars.cornerradius*2, 200, configVars.cornerradius*3, configVars.cornerradius)
			gfx.popContext()
			curveImg:setMaskImage(maskImg)
			curveImg:draw(0,200-24-configVars.cornerradius)
			
			gfx.setImageDrawMode(gfx.kDrawModeNXOR)
			gfx.drawTextAligned(buttons.B.."    " ..buttons.A,100, 200-21,kTextAlignment.center)
			
		end
	playdate.graphics.popContext()

	return widget.image
end

-- Get the widget image most recently drawn with loadWidgetImage(); called every frame.
function widget:getWidgetImage()
	if widget.image then
		return widget.image
	else
		return widget:loadWidgetImage()	
	end
end

-- Called every frame, put main loop here
function widget:update(isActive)
	if widget.pending then
		local pending = widget.pending
		widget.pending = nil
		pending()
	end
	
	if isActive then
		widget.t += 1
		-- Refresh graphic
		widget:loadWidgetImage()
	end
end

-- Called when FunnyOS boots up
function widget:init()
	widget:getWidgetImage()	
end

return widget