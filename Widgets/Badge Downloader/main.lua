local FunnyExplorer = {}
local widget = FunnyExplorer
local folderImg = nil
local documentImg = nil
local currentPath = "/Shared/FunnyOS2/"
local previousPaths = {}
local currentFiles = {"Test Folder"}
local currentSelection = 1
local scroll = 0
local itemHeight = 33
local loadedAssets = false
local copied = false
local copiedPath = ""
local copyProgress = 0
local copySize = 0
local fileImg = nil
local inFileContent = false
local fileContentType = ""
local server = nil

local timerInitialDelay,timerRepeatDelay = 300,40
local scrollRepeatTimer = nil

-- path is filled out when loaded by system
widget.metadata = {
	name = "FunnyBadgeExplorer",
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
	local selectedFile = currentFiles[currentSelection]
	if selectedFile:sub(-1,-1) == "/" then
		widget:enterSelectedFolder()
	else
		widget:openFileContent(selectedFile)
	end
end

function widget:keyboardWillHideCallback(pressedOK)
	if rename then
		rename = false
		local text = playdate.keyboard.text:gsub("/","")
		if text == "" then return end 
		if pressedOK then 
			local newPath = currentPath..text
			currentFiles[currentSelection] = text
			if renameStartText:sub(-1,-1) == "/" then			
				playdate.file.rename(currentPath..renameStartText:sub(1,#renameStartText-1),newPath)
				currentFiles[currentSelection] = text.."/"
			else
				playdate.file.rename(currentPath..renameStartText,newPath)				
			end
		else
			currentFiles[currentSelection] = renameStartText
		end
		widget:loadWidgetImage()	
	end
end

function widget:textChangedCallback()
	local text = playdate.keyboard.text:gsub("/","")
	currentFiles[currentSelection] = text
	if renameStartText:sub(-1,-1) == "/" then
		currentFiles[currentSelection] = text.."/"
	end
	widget:loadWidgetImage()
end

function widget:renameItem()
	widget:removeScrollTimer()
	if currentSelection > 1 then
		local ktext = currentFiles[currentSelection]
		renameStartText = ktext
		if ktext:sub(#ktext,#ktext) == "/" then
			ktext = ktext:sub(1,#ktext-1)
		end
		playdate.keyboard.show(ktext)	
		rename = true
		widget:loadWidgetImage()	
	end
end

function widget:drawProgress(value,outOfValue, text)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setColor(gfx.kColorWhite)	
	local w,h = 400-labelSpacing*10, 240-labelSpacing*14
	local oldFont = gfx.getFont(gfx.font.kVariantNormal)
	gfx.setFont(gfx.getLargeUIFont())
	local textWidth, textHeight = gfx.getTextSize("HI")
	gfx.setFont(oldFont)
	local x,y = (200-w/2)//1, (120-h/2)//1
	gfx.fillRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.setPattern({170,170,170,170,170,170,170,170})
	local img = gfx.image.new(w-labelSpacing*2,34,gfx.kColorWhite)
	gfx.pushContext(img)
	gfx.fillRoundRect(0,0, (w-labelSpacing*2), 34, configVars.cornerradius*100)
	gfx.popContext()
	local mimg = gfx.image.new(w-labelSpacing*2,34,gfx.kColorBlack)
	gfx.pushContext(mimg)
	gfx.setDitherPattern(0)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, ((w-labelSpacing*2)*(value/outOfValue))//1, 34)
	gfx.popContext(mimg)
	img:setMaskImage(mimg)
	img:draw(x+labelSpacing,y+h-labelSpacing-32 )
	gfx.setDitherPattern(0)
	gfx.drawRoundRect(x+labelSpacing,y+h-labelSpacing-32 , w-labelSpacing*2, 32, configVars.cornerradius*100)
	gfx.getLargeUIFont():drawTextAligned(text, 200, y+labelSpacing,kTextAlignment.center)
end

function widget:copyFile(from,to,blockSize)
	if not blockSize then blockSize = 98304 end
	if to:sub(-1,-1) == "/" or from == to then return end	
	--open source file
	local sourceFile = fle.open(from,fle.kFileRead)
	if not sourceFile then return end
	
	--create the file with no data, erase if data
	local destFile = fle.open(to,fle.kFileWrite)
	if not destFile then return end
	destFile:close()
	
	--open to append
	destFile = fle.open(to,fle.kFileAppend)
	if not destFile then return end
	
	local len = playdate.file.getSize(from)
	local numBlocks = (len/blockSize)//1 + 1
	for i=1,numBlocks do
		local r, r2 = sourceFile:read(blockSize)
		if r then
			copyProgress += r2
			destFile:write(r)
			
			widget:drawProgress(copyProgress, copySize, "Copying...")
			
			playdate.display.flush()
			coroutine.yield()
		else
			createInfoPopup("Action Failed", "*File "..from.." was unable to copy to "..to..".", function() return false end)
			return false
		end
		coroutine.yield()
	end
	return true
end

function widget:recreateFileStructure(originalPath, newPath)
	copyProgress = 0
	copySize = 0
	local lastDir = "copy of "..originalPath:gsub(widget:removeLastFolder(originalPath),"")
	local isFolder = lastDir:sub(-1,-1) == "/"
	if indexOf(currentFiles, lastDir) then 
		createInfoPopup("Action Failed", "*The specified file or folder already exists at the destination.", false)
		return false
	end
	local fileStructure = {}
	local done = false
	local function returnFolderListAsDict(path)
		local dict = {}
		local listFiles = fle.listFiles(path)
		for i=1,#listFiles do
			if listFiles[i]:sub(-1,-1) == "/" then
				dict[listFiles[i]] = returnFolderListAsDict(path..listFiles[i])
			else
				copySize += fle.getSize(path..listFiles[i])
				dict[listFiles[i]] = path..listFiles[i]
			end
		end
		return dict
	end
	if isFolder then
		fileStructure = returnFolderListAsDict(originalPath)
		coroutine.yield()
	end
	fle.mkdir(newPath)
	local function pasteFileStructure(fs, path)
		if path:sub(-1,-1) ~= "/" then path = path.."/" end
		for k,v in pairs(fs) do
			if k:sub(-1,-1) == "/" then
				fle.mkdir(path..k)
				pasteFileStructure(v, path..k)
			else
				widget:copyFile(v,path..k)
			end
		end
	end
	if isFolder then
		fle.mkdir(newPath..lastDir)
		pasteFileStructure(fileStructure, newPath..lastDir)
	else
		print(originalPath, newPath..lastDir)
		if not widget:copyFile(originalPath, newPath..lastDir) then
			return false
		end
		
	end
	table.insert(currentFiles, currentSelection+1, lastDir)
	widget:moveDown()
	widget:loadWidgetImage()
	return fileStructure
end

function widget:copy(ogPath,newPath)
	local fs = widget:recreateFileStructure(copiedPath, currentPath)
	copied = false
	redrawFrame = true
	copyProgress = 0
end

function widget:rightButtonUp()
	if rename then
		widget:removeScrollTimer()
		return	
	end
end

function widget:removeLastFolder(path)
	lastSlash = 1
	for i=1,#path-1 do
		local c = path:sub(i,i)
		if c == "/" then
			lastSlash = i
		end
	end
	return path:sub(1,lastSlash)
end

function widget:getFilesFromServer(path)
	--https://sv.ocean.lol/funnybadges/
	server = playdate.network.http.new("https://sv.ocean.lol/")
	server:get("/funnybadges/")
	return {"Loading..."}
end

function widget:goToFolder(path)
	if not path then return end
	if path:sub(#path-2,#path) == "../" then
		path = path:sub(1,#path-3)
		currentPath = widget:removeLastFolder(currentPath)
		widget:goToFolder(currentPath)
	else
		table.insert(previousPaths, currentPath)
		if #previousPaths > 64 then
			table.remove(previousPaths, 1)
		end
		currentPath = path
		currentFiles = widget:getFilesFromServer(currentPath)
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

function widget:closeFileContent()
	inFileContent = false
	fileContentType = ""
	if fileAudio then fileAudio:stop(); fileAudio = nil end
	if fileImg then fileImg = nil end
	if fileScript then fileScript = nil end
	widget:loadWidgetImage()
end

function widget:openFileContent(selectedFile)
	
	inFileContent = true
	
	local suffix = selectedFile:sub(#selectedFile-4,#selectedFile)
	if suffix:sub(1,1) ~= "." then
		suffix = suffix:sub(2,#suffix)
	end
	fileContentType = suffix
	
	if suffix == ".pdx/" then
		sys.switchToGame(currentPath..selectedFile)
	elseif suffix == ".pdi" then
		if fileImg then fileImg = nil end
		fileImg = gfx.image.new(currentPath..selectedFile)
		if fileImg then
			
		else
			createInfoPopup("Action Failed", "*The Playdate Image File "..selectedFile.." was unable to be displayed.", false)
		end
	elseif selectedFile:sub(-1,-1) == "/" then
		widget:enterSelectedFolder()
	end
	widget:loadWidgetImage()
end

function widget:leftButtonUp()
	if inFileContent then
		widget:closeFileContent()
		return
	end
	if rename then
		widget:removeScrollTimer()
		return	
	end
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
	if rename then
		widget:removeScrollTimer()
		return	
	end
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
	if rename then
		widget:removeScrollTimer()
		return	
	end
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

function widget:drawFileIconAt(v,x,y)
	if v:sub(#v,#v) == "/" then
		folderImg:draw(x,y)
	else
		documentImg:draw(x,y+1)
	end
end

function widget:drawBottomBar()
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
		if inFileContent then
			gfx.drawTextAligned(buttons.LEFT.."    "..buttons.RIGHT,100, 200-21,kTextAlignment.center)
			
		else
			gfx.drawTextAligned(buttons.A.."    " ..buttons.LEFT.."    "..buttons.RIGHT,100, 200-21,kTextAlignment.center)
		end
		
	end	
end

-- Refresh the widget image
function widget:loadWidgetImage()
	widget.image = playdate.graphics.image.new(200, 200,gfx.kColorWhite)
	if not loadedAssets then return widget.image end
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorWhite)
		playdate.graphics.setColor(playdate.graphics.kColorWhite)

		if inFileContent then
			
			if fileContentType == ".pdi" then
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.setColor(gfx.kColorBlack)
				gfx.setDitherPattern(0.5)
				gfx.fillRect(0, 0, 200, 200)
				local w,h = fileImg:getSize()
				local wRatio,hRatio = w/200, h/175
				local ratio = math.max(wRatio,hRatio)
				local scaleFactor = (1/ratio)
				fileImg:drawScaled(100 - w*scaleFactor/2,100 - h*scaleFactor/2 - 11,scaleFactor)
			end
			
			widget:drawBottomBar()
			gfx.popContext()
			return
		end

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
				
				if v:sub(#v,#v) == "/" then drawText = drawText:sub(1,#drawText-1) end
				gfx.drawText("*"..drawText,40,y+9)
				gfx.setImageDrawMode(gfx.kDrawModeNXOR)
				widget:drawFileIconAt(v,4,y)
			end
			gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		end
		if copied then 
			gfx.drawTextAligned("*Copy", 100, 7, kTextAlignment.center)
		else
			gfx.drawTextAligned("*Badge Explorer*",100, 7,kTextAlignment.center)
		end
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		
		widget:drawBottomBar()
		
		
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
		documentImg = gfx.image.new(widget.metadata.path.."pdi")	
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