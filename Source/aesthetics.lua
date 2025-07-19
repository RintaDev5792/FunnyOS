import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("utils")
import("system")

-- pd symbols:
-- ⬆️➡️⬇️⬅️🟨 ⊙ 🔒 🎣 ✛ 🅐 🅑
-- fishing rod is crank
gfx = playdate.graphics

local incFrame = 0
redrawIcons = true
redrawLabels = true
defaultRedrawFrame = false
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

widgetsBackground = nil
cachedScreenImg = nil
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
behindCursorImg = nil

local cursorFrameDelay = 600
labelSpacing, labelYMargin, labelTextSize = 10, 4, 15
widgetPadding, widgetSpacing = 8, 16
bottomBarHeight = 10 -- usually 22
snappiness, defaultSnappiness = 0.175,0.17
circleCursorRadius = 4

widgetsScreenWidth = 230
widgetWidth, widgetHeight = 200, 200

local lastScrollX = 0
scrollX = 0
controlCenterProgress, maxControlCenterProgress, controlCenterState = 0, 222, 0 -- 0 close 1 closing 2 opening 3 open

cursorFrame = 1
lastObjectCursorDrawX = 0

invertedColors = {[true] = playdate.graphics.kColorWhite, [false] = playdate.graphics.kColorBlack}
invertedDrawModes = {[true] = playdate.graphics.kDrawModeInverted, [false] = playdate.graphics.kDrawModeCopy}
invertedFillDrawModes = {[true] = playdate.graphics.kDrawModeFillWhite, [false] = playdate.graphics.kDrawModeFillBlack}
-- Vertical space between widgets
widgetScroll = 0

function drawRoutine()
	
	if drawingLaunchAnim then
		drawIconLaunchAnim()
		return
	end
	iconsLoadedThisFrame = 0
	local redraw = redrawFrame
	redrawFrame = defaultRedrawFrame
	snappiness=defaultSnappiness*targetFPS*delta
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	if not saveFrame then cachedScreenImg = nil end
	if redraw then
		incFrame+=1
		gfx.clear(gfx.kColorWhite)
		
		if bgDitherImg and configVars.bgdither ~= 1 then 
			bgDitherImg:draw(0 ,0) 
		end 
		if bgImg and configVars.bgon then 
			bgImg:draw(0,0) --bgImg:draw(0,0) 
		end 
		drawLabelBackgrounds()
		--drawIcons()
		
	end
	
	if cachedScreenImg and ((not redraw) or saveFrame) then
		--cachedScreenImg:draw(0,0) 
	end
	
	saveFrame = false
	processAndDrawWidgets()
	
	lastScrollX = scrollX
	processDrawChanges()
	doScrolling()
	--always last
	local yOffset = 0
	if scrollX > 0 then
		yOffset = (scrollX/(widgetsScreenWidth/bottomBarHeight)+1)//1
	end
	
	if scrollX//1 ~= lastScrollX//1 then
		redrawFrame = true	
	end
	
	if cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT then
		drawObjectCursor()	
	else
		lastObjectCursorDrawX = labels[currentLabel].drawX+labelTextSize*2
	end
	
	drawBottomBar(yOffset)
	if cursorState == cursorStates.INFO_POPUP then
		drawInfoPopup()	
	elseif cursorState == cursorStates.RENAME_LABEL then
		drawLabelNameBox(currentLabel)	
	end
	
	--playdate.drawFPS(383,0)
end

function drawIconLaunchAnim()
	if not configVars.skipcard then
		launchAnimProgress = 100
	end
	local x,y = calcIconPositionCentered(currentObject, currentLabel)
	local size = objectSizes[labels[currentLabel].rows]
	launchAnimProgress=launchAnimProgress+5
	gfx.setColor(gfx.kColorBlack)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	w = (820)*launchAnimProgress/100
	h = (500)*launchAnimProgress/100
	local rx,ry = x-w/2,y-h/2
	gfx.fillRoundRect(rx, ry, w, h,5)
	
	local icon, status = getIcon(bundleIDToLaunch, currentLabel)
	if icon then icon:drawCentered(x,y) end
	if launchAnimProgress >= 100 then
		playdate.system.switchToGame(gameInfo[bundleIDToLaunch].path)
		return
	end
end

function generateWidgetMask()
	widgetMaskImg = gfx.image.new(200,200,gfx.kColorBlack)	
	gfx.pushContext(widgetMaskImg)
	gfx.setColor(gfx.kColorWhite)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)
	gfx.popContext()
end

function processAndDrawWidgets()
	if scrollX > 1 then
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if not widgetsBackground then
			widgetsBackground = gfx.image.new(widgetsScreenWidth,240,gfx.kColorWhite)
			gfx.pushContext(widgetsBackground)
			gfx.setColor(gfx.kColorBlack)
			gfx.setPattern({0, 255,0,255,0,255,0,255})
			gfx.fillRect(0, 0, widgetsScreenWidth, 240)
			gfx.popContext()
		end
		local x = -widgetsScreenWidth+scrollX
		local baseY = (((240-widgetHeight)/2))//1
		
		widgetsBackground:draw(x,0)
	
		-- Update widget scroll position with lerp
		widgetScroll = lerpMaxed(widgetScroll, -(currentWidget-1)*(widgetHeight + widgetSpacing), snappiness)
	
		-- Draw all widgets in a vertical list
		for i, widget in ipairs(widgets) do
			if i == currentWidget then
				widget:update(widgetIsActive)
			end
			local widgetY = baseY + (i-1) * (widgetHeight + widgetSpacing) + widgetScroll
			local widgetX = x + ((widgetsScreenWidth - widgetWidth)/2)//1
			-- Only draw if widget would be visible
			if widgetY + widgetHeight > 0 and widgetY < 240 then
				-- Draw widget content first
				local widgetImage = widget:getWidgetImage()  -- Always run main()
				if widgetImage then
					if not widgetMaskImg then generateWidgetMask() end
					widgetImage:setMaskImage(widgetMaskImg)
					if configVars.invertwidgets then
						gfx.setImageDrawMode(gfx.kDrawModeInverted)
					else
						gfx.setImageDrawMode(gfx.kDrawModeCopy)
					end
					widgetImage:draw(widgetX, widgetY)
				end
	
				-- Draw widget cursor
				if i == currentWidget and cursorState == cursorStates.SELECT_WIDGET then
					gfx.setLineWidth(configVars.linewidth)
					gfx.setColor(invertedColors[configVars.invertwidgetcursor])
	
					-- If widget is active, border fits exactly
					-- If inactive, border has padding
					widgetPadding = labelSpacing - (configVars.linewidth/2)//1
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
	gfx.fillRoundRect(labelSpacing/2, (120-h/2)//1, w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(labelSpacing/2, (120-h/2)//1, w, h, configVars.cornerradius)
	gfx.drawTextAligned("*"..key.text.."*", (w/2+labelSpacing/2)//1, (120-h/2+labelSpacing/2)//1+2, kTextAlignment.center)
end

function updateCursorFrame()
	if cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT then
		redrawFrame = true
		local rowsNumber = 6/labels[currentLabel].rows
		cursorFrame+=1
		if cursorFrame > #cursorImgs[rowsNumber] then
			cursorFrame = 1	
		end
	end
	playdate.timer.performAfterDelay(cursorFrameDelay, updateCursorFrame)
end

function drawIconsDeprecated()
	
	-- DO NOT USE, NOT OPTIMIZED
	
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	for i,v in ipairs(labelOrder) do
		drawIconsForLabel(v)
	end
end

function drawIconsForLabel(v,xoffset,yoffset)
	local cap = false
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	if not labels[v].collapsed and #labels[v].objects > 0 then
		for j, objectData in ipairs(labels[v].objects) do
			local x, y = calcIconPositionCentered(j, v)
			x += xoffset
			y+= yoffset
			if objectData then--and x > -objectSizes[labels[v].rows] and x < 450 then
				local icon, status = getIcon(objectData.bundleid, v)
				if icon then 
					icon:drawCentered(x,y) 
				else
					cap = true
				end
				if status == "CAP" then
					cap = true
				end
			end
		end
	end	
	return cap
end

function doScrolling()
	
	local objectTotalSize = objectSizes[labels[currentLabel].rows]+objectSpacings[labels[currentLabel].rows]
	
	if labels[currentLabel]["drawX"] ~= labelSpacing and cursorState == cursorStates.SELECT_LABEL then
		scrollX = lerpMaxed(scrollX,scrollX-labels[currentLabel]["drawX"]+labelSpacing,snappiness)
	end
	
	if cursorState == cursorStates.SELECT_WIDGET and scrollX < widgetsScreenWidth then
		scrollX = lerpMaxed(scrollX, widgetsScreenWidth, snappiness)	
	end
		
	if (lastObjectCursorDrawX > 400-objectTotalSize-labelSpacing-configVars.cornerradius) and (currentObject > #labels[currentLabel].objects-labels[currentLabel].rows) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		
		scrollX = lerpFloored(scrollX,scrollX-(lastObjectCursorDrawX-400)-objectTotalSize-labelSpacing-configVars.cornerradius,snappiness)
		
	elseif (lastObjectCursorDrawX > 400-objectTotalSize-labelSpacing) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		
		scrollX = lerpFloored(scrollX,scrollX-(lastObjectCursorDrawX-400)-objectTotalSize-labelSpacing,snappiness)
		
	elseif (lastObjectCursorDrawX < labelSpacing+labelTextSize*2 and currentObject <= labels[currentLabel].rows) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		
		scrollX = lerpFloored(scrollX,scrollX-lastObjectCursorDrawX+labelSpacing+labelTextSize*2,snappiness)
		
	elseif (lastObjectCursorDrawX < labelSpacing) and (cursorState == cursorStates.SELECT_OBJECT or cursorState == cursorStates.MOVE_OBJECT) then
		
		scrollX = lerpFloored(scrollX,scrollX-lastObjectCursorDrawX+labelSpacing,snappiness)
		
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
		heldObjectImage:drawCentered(x + (w/2)//1,y + (w/2)//1)
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
			t = t:gsub("'","*'*")
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
			if currentObject % labels[currentLabel].rows < (labels[currentLabel].rows/2)//1+1 and currentObject % labels[currentLabel].rows > 0 then
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
	x = (x+0.5)*(objectSize+objectSpacing)
	y = (y+0.5)*(objectSize+objectSpacing)
	x+=labels[label].drawX+labelTextSize*2
	y+=labelYMargin+3
	
	return x // 1, y // 1	
end

function processDrawChanges()
	if controlCenterState == 1 then
		controlCenterProgress = lerpMaxed(controlCenterProgress,  0, snappiness)//1
		redrawFrame = true
		if controlCenterProgress < 2 then 
			controlCenterProgress = 0
			controlCenterState = 0
		end
		if controlCenterProgress < 20 then
			changeCursorState(oldCursorState)	
		end
	end
	if controlCenterState == 2 then
		controlCenterProgress = lerpMaxed(controlCenterProgress,  maxControlCenterProgress, snappiness)
		redrawFrame = true
		if controlCenterProgress > maxControlCenterProgress-3 then 
			controlCenterProgress = maxControlCenterProgress
			controlCenterState = 3  
		end
	end
end

function drawLabelBackgrounds()
	local currentLabelOffset = labelSpacing
	for i,v in ipairs(labelOrder) do
		local label = labels[v]
		labels[v]["drawX"] = scrollX + currentLabelOffset
		
		w = labelTextSize*3 + ((#label["objects"]/label["rows"])//1)*(objectSizes[label["rows"]] + objectSpacings[label["rows"]]) - objectSpacings[label["rows"]] -6 + (configVars.cornerradius/2)//1
		h = 240-bottomBarHeight-(labelYMargin*2)
		if labels[v]["collapsed"] then
			w = labelTextSize*2	
		end
		
		x = scrollX + currentLabelOffset
		local ditherMod = (x//1)%2
		found = labelsCache[v] ~= nil
		if found then found = found and labelsCache[v][ditherMod] end
		if found then
			if x < 403 and x > -3-w then
				labelsCache[v][ditherMod]:draw(x-ditherMod,labelYMargin)
			end
		else
			local limg = gfx.image.new(w,h,gfx.kColorClear)
			gfx.pushContext(limg)
			gfx.setColor(invertedColors[configVars["invertlabels"]])
			gfx.setDitherPattern(configVars.labeldither, gfx.image.kDitherTypeBayer8x8)
			gfx.fillRoundRect(ditherMod, 0, w, h, configVars["cornerradius"])
			local t = "*"..labels[v]["displayName"].."*"
			local tw,th = gfx.getTextSize(t)
			tw += 20
			th = (th*1.2)//1
			local dw = 240-bottomBarHeight
			local img = gfx.image.new(dw,th)
			gfx.pushContext(img)
			
			gfx.setColor(invertedColors[not configVars.invertlabeltext])
			gfx.setImageDrawMode(invertedDrawModes[configVars.invertlabeltext])
			if configVars.labeltextbgs then
				gfx.fillRoundRect(dw/2 - tw/2, 1, tw, th-2, 10)
			end
			gfx.drawTextAligned(t, (h/2)//1+3, 3,kTextAlignment.center)
			gfx.popContext()
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			img = img:rotatedImage(90)
			img = img:rotatedImage(180)
			img:draw(4 + ditherMod,0)
			
			
			local cap = drawIconsForLabel(v,0-x+ditherMod,-labelYMargin)
			gfx.popContext()
			if (not labelsCache[v]) or cap then labelsCache[v] = {} end
			if not cap then
				labelsCache[v][ditherMod] = limg
			else
				redrawFrame = true
			end
			
			limg:draw(scrollX+currentLabelOffset - ditherMod,labelYMargin)
		end
		
		if v == currentLabel and cursorState ~= cursorStates.SELECT_WIDGET then
			gfx.setDitherPattern(0)
			gfx.setLineWidth(configVars.linewidth)
			gfx.setColor(invertedColors[configVars.invertcursor])
			gfx.drawRoundRect(scrollX + currentLabelOffset, labelYMargin, w, h, configVars["cornerradius"])
		end
		
		
		currentLabelOffset += w + labelSpacing
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
	gfx.setDitherPattern(configVars.bgdither, gfx.image.kDitherTypeBayer8x8)
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
	gfx.setDitherPattern(configVars.ccdither, gfx.image.kDitherTypeBayer8x8)
	local x = -1
	gfx.fillRoundRect(x,240-bottomBarHeight-controlCenterProgress+yOffset,402,bottomBarHeight*3+controlCenterProgress,configVars["cornerradius"])
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
		arrowProgress = 3 - ((maxControlCenterProgress-controlCenterProgress)/arrowFactor)//1
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
	local batteryWidth = (27*(playdate.getBatteryPercentage()/100)+1)//1
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
	elseif controlCenterMenuItem == "Package Installer" then
		drawPackageInstallerMenu()
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
	local x,y = (200-w/2)//1, (120-h/2)//1
	gfx.fillRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.getLargeUIFont():drawTextAligned(infoPopupTitle, 200, y+labelSpacing,kTextAlignment.center)
	
	if infoPopupEnableB then
		gfx.drawText(buttons.B.." *Back* ",((200-w/2)//1) +labelSpacing, y+h-18-labelSpacing)
		gfx.drawTextAligned("* Accept *"..buttons.A, w+((200-w/2)//1)-labelSpacing, y+h-18-labelSpacing,kTextAlignment.right)
	else
		gfx.drawTextAligned("* Accept *"..buttons.A, 200, y+h-18-labelSpacing,kTextAlignment.center)
	end
	
	gfx.drawTextInRect(infoPopupBody, x+labelSpacing, y+labelSpacing+textHeight+2, w-labelSpacing*2, h-labelSpacing*8, 0, "...", kTextAlignment.center)
end

function drawSystemInfo()
	gfx.setImageDrawMode(invertedDrawModes[configVars.invertcc])
	
	funnyIconImg:drawScaled(180, 256-controlCenterProgress, 4)
	if not freeStorage or not totalStorage then
		freeStorage = playdate.system.getFreeDiskSpace()
		totalStorage = playdate.system.getTotalDiskSpace()	
	end
	local storagePercent = (totalStorage-freeStorage)/totalStorage
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	gfx.setPattern({ 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa })
	gfx.fillRoundRect(180, 420-controlCenterProgress, 226-24, 20, configVars.cornerradius)
	gfx.setDitherPattern(0)
	gfx.setColor(gfx.kColorWhite)
	if storagePercent == 1/0 then storagePercent = 0.1 end
	gfx.fillRoundRect(180, 420-controlCenterProgress, ((226-24)*storagePercent)//1, 20, configVars.cornerradius)
	
	local filledGB = readableBytes(totalStorage-freeStorage, 2)
	local totalGB = readableBytes(totalStorage, 2)
	
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
			local invertedFillDrawModes = invertedFillDrawModes
			if not invertedFillDrawModes then 
				invertedFillDrawModes = {[true] = playdate.graphics.kDrawModeFillWhite, [false] = playdate.graphics.kDrawModeFillBlack}
			end
			if gameInfo[v] then
				gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
				gfx.drawTextInRect("*"..gameInfo[v].name.."*", 190, y-8,155,30,nil,"...")
				gfx.setImageDrawMode(invertedDrawModes[configVars.invertcc])
				local icon = getIcon(v, "recentlyPlayed", "recentlyPlayed")
				if icon then
					icon:draw(400-32-labelSpacing*2, y-16)
				end
			else
				table.remove(recentlyPlayed, i)
				saveRecentlyPlayed()
				--recentlyPlayed[i] = nil
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

function drawPackageInstallerMenu()
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	local ccOptionsSpacing = 20
	if controlCenterInfoSelection-controlCenterInfoScroll > 9 then
		controlCenterInfoScroll +=1
	end
	if controlCenterInfoSelection-controlCenterInfoScroll < 1 then
		controlCenterInfoScroll -=1
	end
	for i,v in ipairs(packageInstallerMenuItems) do
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

function updateCircleCursorRadius()
	if circleCursorRadius == 4 then circleCursorRadius = 5 else circleCursorRadius = 4 end
	playdate.timer.performAfterDelay(cursorFrameDelay, updateCircleCursorRadius)
end

function drawCircleCursor(baseX, baseY, spacing, index, maxIndex, scroll)
	gfx.setImageDrawMode(invertedFillDrawModes[not configVars.invertcc])
	gfx.fillCircleAtPoint(baseX, baseY-controlCenterProgress+8+spacing*(index-scroll), circleCursorRadius)
	if index ~= 1 then
		gfx.fillTriangle(baseX,  baseY-controlCenterProgress+spacing*(index-scroll)-circleCursorRadius, baseX+circleCursorRadius,  baseY-controlCenterProgress+8+spacing*(index-scroll)-1 , baseX - circleCursorRadius,  baseY-controlCenterProgress+8+spacing*(index-scroll)-1)	
	end
	if index ~= maxIndex then
		gfx.fillTriangle(baseX,  baseY-controlCenterProgress+16+spacing*(index-scroll)+circleCursorRadius, baseX+circleCursorRadius,  baseY-controlCenterProgress+8+spacing*(index-scroll)+1 , baseX - circleCursorRadius,  baseY-controlCenterProgress+8+spacing*(index-scroll)+1)	
	end
end
