import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("utils")
import("system")

-- pd symbols:
-- ⬆️➡️⬇️⬅️🟨 ⊙ 🔒 🎣 ✛ Ⓐ Ⓑ
-- fishing rod is crank
gfx = playdate.graphics

redrawFrame = true
defaultRedrawFrame = true
saveFrame = false

buttons = {
	["A"] = "Ⓐ",
	["B"] =  "Ⓑ",
	["DPAD"] = "✛",
	["MENU"] = "⊙",
	["LOCK"] = "🔒",
	["CRANK"] = "🎣",
	["PD"] = "🟨",
	["LEFT"] = "⬅️",
	["RIGHT"] = "➡️",
	["UP"] = "⬆️",
	["DOWN"] = "⬇️"
}

gameIconImgs = {}
badgeIconImgs = {}

iconsImg = nil
blankImg = nil
bgDitherImg = nil
bgImg = nil
loadingImg = nil
shuffleImgs = gfx.imagetable.new("images/shuffle")
batteryImg = gfx.image.new("images/battery")
funnyIconImg = gfx.image.new("icon")
wrappedImgs = gfx.imagetable.new("images/trans-wrapped")
newGame = gfx.image.new("images/newgame")
newGameMask = gfx.image.new("images/newgame_mask")
cursorImgs = {gfx.imagetable.new("images/cursor-1"),gfx.imagetable.new("images/cursor-2")}

labelSpacing, labelYMargin, labelTextSize = 10, 4, 15
widgetPadding, widgetSpacing = 8, 16
bottomBarHeight = 10 -- usually 22
snappiness, defaultSnappiness = 0.45,0.45

widgetsScreenWidth = 240
widgetWidth, widgetHeight = 200, 200

scrollX = 0
controlCenterProgress, maxControlCenterProgress, controlCenterState = 0, 224, 0 -- 0 close 1 closing 2 opening 3 open

cursorFrame = 1
lastObjectCursorDrawX = 0

invertedColors = {[true] = gfx.kColorWhite, [false] = gfx.kColorBlack}
invertedDrawModes = {[true] = gfx.kDrawModeInverted, [false] = gfx.kDrawModeCopy}
invertedFillDrawModes = {[true] = gfx.kDrawModeFillWhite, [false] = gfx.kDrawModeFillBlack}
-- Vertical space between widgets
widgetScroll = 0

function drawRoutine()
	gfx.clear(gfx.kColorWhite)
	gfx.clear(gfx.kColorWhite)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	snappiness = defaultSnappiness*(20/playdate.getFPS())
	if snappiness < 0.1 then snappiness = defaultSnappiness*(20/playdate.display.getRefreshRate()) end
	
	if redrawFrame then
		if saveFrame then
			iconsImg = gfx.image.new(400,240,gfx.kColorWhite)
			gfx.pushContext(iconsImg)
		end
		
		if bgDitherImg and configVars.bgdither ~= 1 then 
			bgDitherImg:draw(0 ,0) 
		end 
		if bgImg and configVars.bgon then 
			bgImg:draw(0,0) --bgImg:draw(0,0) 
		end 
		drawLabelBackgrounds()
		drawIcons()
		processAndDrawWidgets()
		
		if saveFrame then
			gfx.popContext()
			saveFrame = false
		end
	end
	redrawFrame = defaultRedrawFrame
	
	if iconsImg and ((not redrawFrame) or saveFrame) then iconsImg:draw(0,0) end
	saveFrame = false
	
	processDrawChanges()
	doScrolling()
	--always last
	local yOffset = 0
	if scrollX > 0 then
		yOffset = math.ceil(scrollX/(widgetsScreenWidth/bottomBarHeight))
	end
	drawBottomBar(yOffset)
	if cursorState == cursorStates.INFO_POPUP then
		drawInfoPopup()	
	elseif cursorState == cursorStates.RENAME_LABEL then
		drawLabelNameBox(currentLabel)	
	end
	playdate.drawFPS(383,0)
end

function processAndDrawWidgets()
	if scrollX > 0 then
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		gfx.setColor(gfx.kColorBlack)
		gfx.setPattern({0, 255,0,255,0,255,0,255})
		local x = -widgetsScreenWidth+scrollX
		local baseY = math.floor(((240-widgetHeight)/2))
		gfx.fillRect(x, 0, widgetsScreenWidth, 240)
	
		-- Update widget scroll position with lerp
		widgetScroll = lerpFloored(widgetScroll, -(currentWidget-1)*(widgetHeight + widgetSpacing), snappiness)
	
		-- Draw all widgets in a vertical list
		for i, widget in ipairs(widgets) do
			if i == currentWidget then
				widget:update(widgetIsActive)
			end
			local widgetY = baseY + (i-1) * (widgetHeight + widgetSpacing) + widgetScroll
			local widgetX = x + math.floor((widgetsScreenWidth - widgetWidth)/2)
	
			-- Only draw if widget would be visible
			if widgetY + widgetHeight > 0 and widgetY < 240 then
				-- Draw widget content first
				local widgetImage = widget:getWidgetImage()  -- Always run main()
				if widgetImage then
					widgetImage:draw(widgetX, widgetY)
				end
	
				-- Draw widget cursor
				if i == currentWidget then
					gfx.setLineWidth(configVars.linewidth)
					gfx.setColor(invertedColors[configVars.invertcursor])
	
					-- If widget is active, border fits exactly
					-- If inactive, border has padding
					local padding = (widgetIsActive) and 0 or widgetPadding
					gfx.drawRoundRect(
						widgetX - padding, 
						widgetY - padding, 
						widgetWidth + padding*2, 
						widgetHeight + padding*2, 
						configVars.cornerradius
					)
				end
			end
		end
	end
end

function drawLabelNameBox(label)
	local w, h = gfx.getTextSize("HI")
	w = 400-labelSpacing-key.width()
	h+=labelSpacing
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(labelSpacing/2, math.floor(240/2-h/2), w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(labelSpacing/2, math.floor(240/2-h/2), w, h, configVars.cornerradius)
	gfx.drawTextAligned("*"..key.text.."*", math.floor(w/2+labelSpacing/2), math.floor(240/2-h/2+labelSpacing/2)+2, kTextAlignment.center)
end

function updateCursorFrame()
	local rowsNumber = 6/labels[currentLabel].rows
	cursorFrame+=1
	if cursorFrame > #cursorImgs[rowsNumber] then
		cursorFrame = 1	
	end
	playdate.timer.performAfterDelay(500, updateCursorFrame)
end

function drawIcons()
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	for i,v in ipairs(labelOrder) do
		if not labels[v].collapsed and #labels[v].objects > 0 then
			for j, objectData in ipairs(labels[v].objects) do
				local x, y = calcIconPositionCentered(j, v)
				if objectData and x > -objectSizes[labels[v].rows] and x < 450 then
					local icon = getIcon(objectData.bundleid, v)
					if icon then icon:drawCentered(x,y) end
				end
			end
		end
	end
	if cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT then
		drawObjectCursor()	
	end
end

function doScrolling()
	if labels[currentLabel]["drawX"] ~= labelSpacing and cursorState == cursorStates.SELECT_LABEL then
		scrollX = lerpFloored(scrollX,scrollX-labels[currentLabel]["drawX"]+labelSpacing,snappiness)
	end
	if cursorState == cursorStates.SELECT_WIDGET then
		scrollX = lerpFloored(scrollX, widgetsScreenWidth, snappiness)	
	end
	local objectTotalSize = objectSizes[labels[currentLabel].rows]+objectSpacings[labels[currentLabel].rows]
	if (lastObjectCursorDrawX > 400-objectTotalSize-labelSpacing) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		scrollX = lerpFloored(scrollX,scrollX-(lastObjectCursorDrawX-400)-objectTotalSize-labelSpacing,snappiness)
	elseif ((lastObjectCursorDrawX < labelSpacing)or (lastObjectCursorDrawX < labelSpacing+labelTextSize*2 and currentObject <= labels[currentLabel].rows)) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		scrollX = lerpFloored(scrollX,scrollX-lastObjectCursorDrawX+labelSpacing+labelTextSize*2,snappiness)
	end
end

function drawObjectCursor()
	local x, y = calcIconPosition(currentObject, currentLabel)
	local rowsNumber = 6/labels[currentLabel].rows
	x-=2*rowsNumber;y-=2*rowsNumber
	lastObjectCursorDrawX = x
	if heldObject then
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		gfx.setColor(gfx.kColorBlack)
		gfx.setDitherPattern(0.5)
		local heldObjectImage = getIcon(heldObject.bundleid, currentLabel)
		local w,h = heldObjectImage:getSize()
		gfx.fillRoundRect(x+2*rowsNumber, y+2*rowsNumber, w, h, 4*rowsNumber)
		heldObjectImage:drawCentered(x + math.floor(w/2),y + math.floor(w/2))
		gfx.setImageDrawMode(invertedDrawModes[configVars.invertcursor])
		
		cursorImgs[rowsNumber][cursorFrame]:draw(x-2*rowsNumber,y-2*rowsNumber)
	else	
		gfx.setImageDrawMode(invertedDrawModes[configVars.invertcursor])
		if cursorFrame > #cursorImgs[rowsNumber] then cursorFrame = 1 end
		cursorImgs[rowsNumber][cursorFrame]:draw(x+rowsNumber,y+rowsNumber-1)
		local t = labels[currentLabel].objects[currentObject].name
		if labels[currentLabel].objects ~= nil and labels[currentLabel].objects[currentObject] ~= nil and  gameInfo[labels[currentLabel].objects[currentObject].bundleid] ~= nil then
			if configVars.hidewrapped and gameInfo[labels[currentLabel].objects[currentObject].bundleid].wrapped then
				t = "?????"	
			end
		end
		if t then
			t = "*"..t.."*"
			local tw,th = gfx.getTextSize(t)
			local textMargins = 5
			local textImg = gfx.image.new(tw+textMargins*2+configVars.linewidth*2,th+textMargins*2+configVars.linewidth*2,gfx.kColorClear)
			gfx.lockFocus(textImg)
			gfx.setColor(gfx.kColorWhite)
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.fillRoundRect(configVars.linewidth, configVars.linewidth, tw-2+textMargins*2, th-2+textMargins*2, 4)
			gfx.setColor(gfx.kColorBlack)
			gfx.setLineWidth(configVars.linewidth)
			gfx.drawRoundRect(configVars.linewidth, configVars.linewidth, tw-2+textMargins*2, th-2+textMargins*2, 4)
			gfx.drawText(t, textMargins+configVars.linewidth-1, textMargins+configVars.linewidth)
			gfx.unlockFocus()
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			local lx, ly = x,y
			lx+=2
			if currentObject % labels[currentLabel].rows < math.floor(labels[currentLabel].rows/2)+1 and currentObject % labels[currentLabel].rows > 0 then
				ly += ((objectSizes[3]+4)*(6/labels[currentLabel].rows))/2 + 4
			else
				ly -= (th-2+textMargins*2) + 4
			end
			if lx+(tw-2+textMargins*2) > 390 then
				lx -= (tw-2+textMargins*2)
				lx += objectSizes[labels[currentLabel].rows] + 7
			end
			
			textImg:draw(lx,ly)
		end
	end

end

function calcIconPosition(index, label)
	local objectSize = objectSizes[labels[label].rows]
	local objectSpacing = objectSpacings[labels[label].rows]
	local x, y = posFromIndex(index, labels[label].rows)
	x-=1;y-=1
	x*=(objectSize+objectSpacing)
	y*=(objectSize+objectSpacing)
	x+=labels[label].drawX+labelTextSize*2
	y+=labelYMargin+4
	return x, y	
end

function calcIconPositionCentered(index, label)
	local objectSize = objectSizes[labels[label].rows]
	local objectSpacing = objectSpacings[labels[label].rows]
	local x, y = posFromIndex(index, labels[label].rows)
	x-=1;y-=1
	--y+=(6/labels[label].rows)-1
	x*=(objectSize+objectSpacing)
	x+=(objectSize+objectSpacing)/2
	y*=(objectSize+objectSpacing)
	y+=(objectSize+objectSpacing)/2
	x+=labels[label].drawX+labelTextSize*2
	y+=labelYMargin+3
	
	return math.floor(x), math.floor(y)	
end

function processDrawChanges()
	if controlCenterState == 1 then
		controlCenterProgress = math.floor(lerp(controlCenterProgress,  0, snappiness))	
		if controlCenterProgress < 2 then 
			controlCenterProgress = 0
			controlCenterState = 0
		end
		if controlCenterProgress < 20 then
			changeCursorState(oldCursorState)	
		end
	end
	if controlCenterState == 2 then
		controlCenterProgress = math.floor(lerp(controlCenterProgress,  maxControlCenterProgress, snappiness))
		if controlCenterProgress > maxControlCenterProgress-2 then 
			controlCenterProgress = maxControlCenterProgress
			controlCenterState = 3  
		end
	end
end

function drawLabelBackgrounds()
	local currentLabelOffset = labelSpacing
	for i,v in ipairs(labelOrder) do
		
		gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		gfx.setColor(invertedColors[configVars["invertlabels"]])
		gfx.setDitherPattern(configVars.labeldither)
		local label = labels[v]
		w = labelTextSize*3 + math.ceil(#label["objects"]/label["rows"])*(objectSizes[label["rows"]] + objectSpacings[label["rows"]]) - objectSpacings[label["rows"]] -6 + math.floor(configVars.cornerradius/2)
		if labels[v]["collapsed"] then
			w = labelTextSize*2	
		end
		x = scrollX + currentLabelOffset
		currentLabelOffset += w + labelSpacing
		labels[v]["drawX"] = x
		gfx.fillRoundRect(x, labelYMargin, w, 240-bottomBarHeight-(labelYMargin*2), configVars["cornerradius"])
		local t = "*"..labels[v]["displayName"].."*"
		local tw,th = gfx.getTextSize(t)
		tw += 20
		th = math.floor(th*1.2)
		local dw = 240-bottomBarHeight
		local img = gfx.image.new(dw,th)
		gfx.pushContext(img)
		
		gfx.setColor(invertedColors[not configVars.invertlabeltext])
		gfx.setImageDrawMode(invertedDrawModes[configVars.invertlabeltext])
		if configVars.labeltextbgs then
			gfx.fillRoundRect(dw/2 - tw/2, 1, tw, th-2, 10)
		end
		gfx.drawTextAligned(t, (240-bottomBarHeight)/2, 3,kTextAlignment.center)
		gfx.popContext()
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		img = img:rotatedImage(90)
		img = img:rotatedImage(180)
		img:draw(x+labelTextSize/2-3,0)
		
		if v == currentLabel then
			gfx.setDitherPattern(0)
			gfx.setLineWidth(configVars.linewidth)
			gfx.setColor(invertedColors[configVars.invertcursor])
			gfx.drawRoundRect(x, labelYMargin, w, 240-bottomBarHeight-(labelYMargin*2), configVars["cornerradius"])
		end
	end
end

function loadImgs()
	if fle.exists(savePath.."load.pdi") then
		loadingImg = gfx.image.new(savePath.."load.pdi")
	else
		loadingImg = gfx.image.new("images/load")	
	end
	
	makeBgDitherImg()
	makeWrappedImgs()
end

function makeWrappedImgs()
	if configVars.transwrapped then
		wrappedImgs = gfx.imagetable.new("images/trans-wrapped")
	else
		wrappedImgs = gfx.imagetable.new("images/wrapped")
	end
end

function makeBgDitherImg()
	gfx.setImageDrawMode(invertedFillDrawModes[configVars.invertbgdither])
	gfx.setColor(invertedColors[configVars.invertbgdither])
	local img = gfx.image.new(402,240,gfx.kColorClear)
	gfx.lockFocus(img)
	gfx.setDitherPattern(configVars.bgdither)
	gfx.fillRect(0,0,402,240)
	gfx.unlockFocus()
	bgDitherImg = img
end

function loadMusic()
	if configVars["musicon"] then
		music = playdate.sound.fileplayer.new(savePath.."bgm")
		if music ~= nil then
			music:play()
			music:setFinishCallback(function() if configVars["musicon"] then loadMusic() end end)
		end
	else
		music = nil    
	end
end

function wrapPatternForGame(game)
	local pattern
	if nil ~= game then
		local info = gameInfo[game:getBundleID()]
		if nil ~= info["imagepath"] then
			local imagepath = info.imagepath .. "/wrapping-pattern.pdi"
			if info.imagepath:sub(#info.imagepath,#info.imagepath) == "/" then
			imagepath = info.imagepath .. "wrapping-pattern.pdi"
			end
			pattern = gfx.image.new(info["path"].."/"..imagepath)
		end
	end
	if nil == pattern then
		pattern = gfx.image.new("images/default_pattern")
	end
	return pattern
end

function drawBottomBar(yOffset)
	local color = invertedColors[configVars.invertcc]
	gfx.setColor(color)
	gfx.setDitherPattern(configVars.ccdither)
	gfx.fillRoundRect(-1,240-bottomBarHeight-controlCenterProgress+yOffset,402,bottomBarHeight*3+controlCenterProgress,configVars["cornerradius"])
	if controlCenterState ~= 0 then
		--backgrounds
		--right text
		gfx.setColor(color)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		gfx.fillRoundRect(180-12, 244-controlCenterProgress, 226, 209, configVars["cornerradius"]/2)
		--left text
		gfx.fillRoundRect(6, 244-controlCenterProgress, 155, 215-38, configVars["cornerradius"]/2)
		--left bottom bar
		gfx.fillRoundRect(6, 237+170+20-controlCenterProgress, 155, 26, configVars["cornerradius"]/2)
		
		drawControlCenterStatusBar()
		
		drawControlCenterMenu()
	end
	
	gfx.setColor(invertedColors[not configVars.invertcc])
	gfx.setDitherPattern(0.25)
	gfx.setLineWidth(4)
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	local arrowFactor = 50
	local arrowProgress = 0
	if controlCenterProgress > maxControlCenterProgress-(6*arrowFactor) then
		arrowProgress = 3 - math.floor((maxControlCenterProgress-controlCenterProgress)/arrowFactor)
	end
	--arrow
	gfx.drawLine(180, 245-bottomBarHeight-controlCenterProgress+yOffset, 199, 236 + arrowProgress-controlCenterProgress+yOffset)
	gfx.drawLine(219, 245-bottomBarHeight-controlCenterProgress+yOffset, 200, 236 + arrowProgress-controlCenterProgress+yOffset)
end

function drawHelp()
	gfx.setImageDrawMode(invertedDrawModes[not configVars.invertcc])
	local t =  buttons.A.."*+*"..buttons.DOWN.."* - Toggle Menu*\n"
	t = t..buttons.A.."*+*"..buttons.LEFT.."*/*"..buttons.RIGHT.."* - Select Label*\n"
	t = t..buttons.A.."*+*"..buttons.UP.."* - Move Item*\n"
	t = t..buttons.B.."*+*"..buttons.DOWN.."* - Add Blank*\n"
	t = t..buttons.B.."*+*"..buttons.UP.."* - Remove Blank*\n"
	t = t..buttons.B.."*+*"..buttons.LEFT.."*/*"..buttons.RIGHT.."* - Move Label*\n"
	t = t..buttons.A.."*+*"..buttons.B.."*+*"..buttons.LEFT.."* - Delete Label*\n"
	t = t..buttons.A.."*+*"..buttons.B.."*+*"..buttons.RIGHT.."* - Create Label*\n"
	t = t..buttons.A.."*+*"..buttons.B.."*+*"..buttons.DOWN.."* - Change Scale*\n"
	t = t..buttons.A.."*+*"..buttons.B.."*+*"..buttons.UP.."* - Rename Label*\n"
	gfx.drawText(t, 170+labelSpacing/2, 249-controlCenterProgress)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)	
end

function drawComingSoon()
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	gfx.getLargeUIFont():drawTextAligned("COMING", 275, 320-controlCenterProgress, kTextAlignment.center)
	gfx.getLargeUIFont():drawTextAligned("SOON", 275, 345-controlCenterProgress, kTextAlignment.center)	gfx.setImageDrawMode(gfx.kDrawModeCopy)	
end

function drawControlCenterStatusBar()
	--battery
	gfx.setColor(invertedColors[not configVars.invertcc])
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	batteryImg:draw(12,432-controlCenterProgress)
	local batteryWidth = math.ceil(27*(playdate.getBatteryPercentage()/100))
	gfx.fillRect(14, 432-controlCenterProgress, batteryWidth, 15)
	
	local t = playdate.getTime()
	local min = tostring(t["minute"])
	if #min < 2 then
		min = "0"..min
	end
	local hour = tostring(t["hour"])
	if not playdate.shouldDisplay24HourTime() then
		if t["hour"] >= 12 then
			local h = t["hour"]-12
			if h == 0 then h = 12 end
			hour = tostring(h)
			min = min .. " PM"
		else
			local h = t["hour"]
			if h == 0 then h = 12 end
			hour = tostring(h)
			min = min .. " AM"
		end
	end
	local text = "*"..hour..":"..min.."*"
	gfx.drawText(text, 170 - 18 - gfx.getTextSize(text), 432-controlCenterProgress)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function drawControlCenterMenu()
	gfx.setImageDrawMode(invertedDrawModes[not configVars.invertcc])
	local ccMenuSpacing = 18
	for i,v in ipairs(controlCenterMenuItems) do
		gfx.drawText("*"..v.."*", 28, 260-controlCenterProgress + ccMenuSpacing*(i-1))
	end
	if cursorState == cursorStates.CONTROL_CENTER_MENU then
		drawCircleCursor(17, 260-17, ccMenuSpacing, controlCenterMenuSelection, #controlCenterMenuItems, 0)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	local controlCenterMenuItem = controlCenterMenuItems[controlCenterMenuSelection]
	if controlCenterMenuItem == "Controls Help" then
		drawHelp()
	elseif controlCenterMenuItem == "System Info" then
		drawSystemInfo()	
	elseif controlCenterMenuItem == "FunnyOS Options" then
		drawOptions()
	elseif controlCenterMenuItem == "Recently Played" then
		drawRecentlyPlayed()
	elseif controlCenterMenuItem == "Actions Menu" then
		drawActions()
	else
		drawComingSoon()	
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function drawInfoPopup()
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setColor(gfx.kColorWhite)	
	local w,h = 400-labelSpacing*10, 240-labelSpacing*6
	local oldFont = gfx.getFont(gfx.font.kVariantNormal)
	gfx.setFont(gfx.getLargeUIFont())
	local textWidth, textHeight = gfx.getTextSize("HI")
	gfx.setFont(oldFont)
	local x,y = (400-w) - math.floor((400-w)/2), (240-h) - math.floor((240-h)/2)
	gfx.fillRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.getLargeUIFont():drawTextAligned(infoPopupTitle, 200, y+labelSpacing,kTextAlignment.center)
	
	if infoPopupEnableB then
		gfx.drawText(buttons.B.." *Back* ",math.floor((400-w)/2)+labelSpacing, y+h-18-labelSpacing)
		gfx.drawTextAligned("* Accept *"..buttons.A, math.floor(w+(400-w)/2)-labelSpacing, y+h-18-labelSpacing,kTextAlignment.right)
	else
		gfx.drawTextAligned("* Accept *"..buttons.A, 200, y+h-18-labelSpacing,kTextAlignment.center)
	end
	
	gfx.drawTextInRect(infoPopupBody, x+labelSpacing, y+labelSpacing+textHeight+2, w-labelSpacing*2, h-labelSpacing*8, 0, "...", kTextAlignment.center)
end

function drawSystemInfo()
	gfx.setImageDrawMode(invertedDrawModes[configVars.invertcc])
	
	funnyIconImg:drawScaled(180, 256-controlCenterProgress, 4)
	local freeSpace = playdate.system.getFreeDiskSpace()
	local totalSpace = playdate.system.getTotalDiskSpace()
	local storagePercent = (totalSpace-freeSpace)/totalSpace
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	gfx.setPattern({ 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa })
	gfx.fillRoundRect(180, 420-controlCenterProgress, 226-24, 20, configVars.cornerradius)
	gfx.setDitherPattern(0)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(180, 420-controlCenterProgress, math.floor((226-24)*storagePercent), 20, configVars.cornerradius)
	
	local filledGB = readableBytes(totalSpace-freeSpace, 2)
	local totalGB = readableBytes(totalSpace, 2)
	
	gfx.drawText("*" ..filledGB.. " of " .. totalGB.. " full*", 180, 400-controlCenterProgress)
	
	gfx.drawText("*FunnyOS: *\n*v".. funnyOSMetadata.version .. "*", 320, 330-controlCenterProgress)
	gfx.drawText("*PDOS: *\n*v".. playdate.systemInfo.sdk .. "*", 320, 280-controlCenterProgress)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function drawRecentlyPlayed()
	local ccOptionsSpacing = 34
	if controlCenterInfoSelection-controlCenterInfoScroll > 5 then
		controlCenterInfoScroll +=1
	end
	if controlCenterInfoSelection-controlCenterInfoScroll < 1 then
		controlCenterInfoScroll -=1
	end
	for i,v in pairs(recentlyPlayed) do
		local y = 245-controlCenterProgress + ccOptionsSpacing*(i-controlCenterInfoScroll)
		if y < 440-controlCenterProgress and y > 245-controlCenterProgress then
			gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
			gfx.drawText("*"..gameInfo[v].name.."*", 190, y-8)
			gfx.setImageDrawMode(invertedDrawModes[configVars.invertcc])
			local icon = getIcon(v, "recentlyPlayed", "recentlyPlayed")
			if icon then
				icon:draw(400-32-labelSpacing*2, y-16)
			end
		end
	end
	if cursorState == cursorStates.CONTROL_CENTER_CONTENT then
		drawCircleCursor(179, 237, ccOptionsSpacing, controlCenterInfoSelection, controlCenterInfoMaxSelection, controlCenterInfoScroll)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)	
end

function drawOptions()
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	local ccOptionsSpacing = 20
	if controlCenterInfoSelection-controlCenterInfoScroll > 9 then
		controlCenterInfoScroll +=1
	end
	if controlCenterInfoSelection-controlCenterInfoScroll < 1 then
		controlCenterInfoScroll -=1
	end
	for i,v in ipairs(configVarOptionsOrder) do
		if configVarOptions[v] then
			local y = 240-controlCenterProgress + ccOptionsSpacing*(i-controlCenterInfoScroll)
			if y < 440-controlCenterProgress and y > 240-controlCenterProgress then
				gfx.drawText("*"..configVarOptions[v].name..":*", 190, y)
				gfx.drawTextAligned("*"..makeOptionsValueReadable(configVars[v], configVarOptions[v].type).."*", 400-12-6, y, kTextAlignment.right)
			end
		end
	end
	if cursorState == cursorStates.CONTROL_CENTER_CONTENT then
		drawCircleCursor(179, 240, ccOptionsSpacing, controlCenterInfoSelection, controlCenterInfoMaxSelection, controlCenterInfoScroll)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function drawActions()
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	local ccOptionsSpacing = 20
	if controlCenterInfoSelection-controlCenterInfoScroll > 9 then
		controlCenterInfoScroll +=1
	end
	if controlCenterInfoSelection-controlCenterInfoScroll < 1 then
		controlCenterInfoScroll -=1
	end
	for i,v in ipairs(actionsMenuItems) do
		if v then
			local y = 240-controlCenterProgress + ccOptionsSpacing*(i-controlCenterInfoScroll)
			if y < 440-controlCenterProgress and y > 240-controlCenterProgress then
				gfx.drawText("*"..v.."*", 190, y)
			end
		end
	end
	if cursorState == cursorStates.CONTROL_CENTER_CONTENT then
		drawCircleCursor(179, 240, ccOptionsSpacing, controlCenterInfoSelection, controlCenterInfoMaxSelection, controlCenterInfoScroll)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function drawCircleCursor(baseX, baseY, spacing, index, maxIndex, scroll)
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	gfx.fillCircleAtPoint(baseX, baseY-controlCenterProgress+8+spacing*(index-scroll), 4)
	if index ~= 1 then
		gfx.fillTriangle(baseX,  baseY-controlCenterProgress+spacing*(index-scroll)-4, baseX+4,  baseY-controlCenterProgress+8+spacing*(index-scroll)-1 , baseX - 4,  baseY-controlCenterProgress+8+spacing*(index-scroll)-1)	
	end
	if index ~= maxIndex then
		gfx.fillTriangle(baseX,  baseY-controlCenterProgress+16+spacing*(index-scroll)+4, baseX+4,  baseY-controlCenterProgress+8+spacing*(index-scroll)+1 , baseX - 4,  baseY-controlCenterProgress+8+spacing*(index-scroll)+1)	
	end
end
