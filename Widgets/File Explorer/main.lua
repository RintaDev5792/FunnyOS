local FunnyExplorer = {}
local widget = FunnyExplorer
local folderImg = nil--fol")
local documentImg = nil--doc")
local upImg = nil--aup")
local backImg = nil--bac")
local forwardsImg = nil--for")
local deleteImg = nil--del")
local curveLeftImg = nil--del")
local curveRightImg = nil--del")
local currentPath = "/"
local previousPaths = {}
local currentFiles = {"Test Folder"}
local currentSelection = 1
local scroll = 0
local itemHeight = 33
local loadedAssets = false

local timerInitialDelay,timerRepeatDelay = 300,40
local scrollRepeatTimer = nil

-- path is filled out when loaded by system
widget.metadata = {
	name = "FunnyExplorer",
	game = nil,
	path = nil
}

widget.image = nil

-- If a B button function widget:isn't provided, this is the default action for it.
function widget:BButtonUp()
	-- Removes focus from the widget so others can be selected
	-- Need this line somewhere if you use the B button.
	widgetIsActive = false
	widget:loadWidgetImage()
end

function widget:AButtonUp()
	widget:openContextMenu()
end

function widget:openContextMenu()
		
end

function widget:rightButtonUp()
	widget:enterSelectedFolder()
end

function widget:goToFolder(path)
	if path then
		table.insert(previousPaths, currentPath)
		if #previousPaths > 64 then
			table.remove(previousPaths, 1)
		end
		currentPath = path
		currentFiles = fle.listFiles(currentPath)
		if not currentFiles then
			widget:goToFolder("/")
			return
		end
		table.sort(currentFiles)
		table.insert(currentFiles,1,"../")
		currentSelection = 1
		scroll = 0
		widget:loadWidgetImage()
	end
end

function widget:enterSelectedFolder()
	if currentFiles[currentSelection]:sub(#currentFiles[currentSelection],#currentFiles[currentSelection]) == "/" then
		widget:goToFolder(currentPath .. currentFiles[currentSelection])
	end	
end

function widget:leftButtonUp()
	widget:returnToPreviousFolder()
end

function widget:returnToPreviousFolder()
	if #previousPaths > 0 then
		local folder = widget:getLastFolderInPath(currentPath)
		local previousPath = table.remove(previousPaths, #previousPaths)
		widget:goToFolder(previousPath)
		for i,v in ipairs(currentFiles) do
			if folder == v then
				currentSelection = i
				break
			end
		end
		while currentSelection > (200/itemHeight)+scroll-2 do
			scroll+=1
		end
		while currentSelection < scroll+1 do
			scroll-=1
		end
		table.remove(previousPaths, #previousPaths)
		widget:loadWidgetImage()
	end
end


function widget:upButtonDown()
	widget:removeScrollTimer()
	scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, widget.moveUp)
end

function widget:moveUp()
	currentSelection=math.max(currentSelection-1,1)
	if currentSelection < scroll+1 then
		scroll=scroll-1
	end	
	widget:loadWidgetImage()
end

function widget:upButtonUp()
	widget:removeScrollTimer()
end

function widget:downButtonDown()
	widget:removeScrollTimer()
	scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, widget.moveDown)
end

function widget:moveDown()
	currentSelection=math.min(currentSelection+1,#currentFiles)
	if currentSelection > (200/itemHeight)+scroll-2 then
		scroll=scroll+1
	end
	widget:loadWidgetImage()
end


function widget:downButtonUp()
	widget:removeScrollTimer()
end

function widget:removeScrollTimer()
	if scrollRepeatTimer ~= nil then
		scrollRepeatTimer:pause()
		scrollRepeatTimer:remove()
		scrollRepeatTimer = nil
	end	
end

-- Refresh the widget image
function widget:loadWidgetImage()
	widget.image = playdate.graphics.image.new(200, 200,gfx.kColorWhite)
	if not loadedAssets then return widget.image end
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRect(0, 0, 200, 200)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		
		gfx.setColor(gfx.kColorBlack)
		
		if not currentFiles then 
			widget:goToFolder("/")
		end
		
		for i,v in ipairs(currentFiles) do
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			local y = i*itemHeight - scroll*itemHeight - 5
			if i == currentSelection and widgetIsActive then
				gfx.fillRect(0, y, 200, itemHeight)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
			end
			if y > 15 and y < 200 then
				local drawText = v
				drawText = drawText:gsub("_","__")
				drawText = drawText:gsub("*","**")
				gfx.drawText("*"..drawText,40,y+9)
				gfx.setImageDrawMode(gfx.kDrawModeNXOR)
				if v:sub(#v,#v) == "/" then
					folderImg:draw(4,y)
				else
					documentImg:draw(4,y+1)
				end
			end
			gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		end
		gfx.drawTextAligned("*File Explorer*",100, 7,kTextAlignment.center)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		
		if widgetIsActive then
			gfx.setColor(gfx.kColorBlack)
			gfx.fillRect(0, 200-24, 200, 24)
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			--curveLeftImg:draw(0,200-36)
			--curveRightImg:draw(200-13,200-36)
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
	if not loadedAssets and widget.metadata.path ~= nil then
		folderImg = gfx.image.new(widget.metadata.path.."fol")
		documentImg = gfx.image.new(widget.metadata.path.."doc")
		upImg = gfx.image.new(widget.metadata.path.."aup")
		backImg = gfx.image.new(widget.metadata.path.."bac")
		forwardsImg = gfx.image.new(widget.metadata.path.."for")
		deleteImg = gfx.image.new(widget.metadata.path.."del")
		curveLeftImg = gfx.image.new(widget.metadata.path.."curve_left")
		curveRightImg = gfx.image.new(widget.metadata.path.."curve_right")
		loadedAssets = folderImg ~= nil
		widget:loadWidgetImage()
	end
end

function widget:getLastFolderInPath(path)
	lastSlash = 1
	for i=1,#path-1 do
		local c = path:sub(i,i)
		if c == "/" then
			lastSlash = i
		end
	end
	return path:sub(lastSlash+1,#path)
end

-- Called when FunnyOS boots up
function widget:init()
	widget:goToFolder("/")
	widget:getWidgetImage()
	loadedAssets = false
end

return widget