local widget = {}

local MODE_PROMPT_REFRESH = 0
local MODE_LOADING = 1
local MODE_LISTING = 2

local PACKAGE_ROOT = "RintaDev5792/FunnyOS/tree/main/Assets/Packages"
if fos and fos.get_launch_args then
	local launchArgs = fos.get_launch_args()
	local args = {}
	for arg in launchArgs:gmatch("%S+") do
		table.insert(args, arg)
	end
	for _, arg in ipairs(args) do
		if arg:sub(1, #"package_root=") == "package_root=" then
			PACKAGE_ROOT = arg:sub(#"package_root="+1)
			print("using package root " .. PACKAGE_ROOT)
			break
		end
	end
end
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
	widget:get("/")
end

function widget:AButtonDown()
	if widget.mode == MODE_PROMPT_REFRESH then
		widget.t = 0
		widget.mode = MODE_LOADING
		
		playdate.network.setEnabled(true, function(err)
			if err then 
				widget.mode = MODE_PROMPT_REFRESH
				createInfoPopup("Failed to Enable Networking", "*" .. err, nil)
			else
				if not widget.http then
					widget.http = playdate.network.http.new("github.com", nil, true, "to list downloadable packages")
					if not widget.http then
						widget.mode = MODE_PROMPT_REFRESH
					else
						get_package_list()
					end
				end
			end
		end)
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
			gfx.drawTextAligned(buttons.A.."    " ..buttons.LEFT.."    "..buttons.RIGHT,100, 200-21,kTextAlignment.center)
			
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