import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("CoreLibs/frameTimer")
import("utils")

local keyTimer = nil
local keyTimerInitialDelay = 300
local keyTimerRepeatDelay = 40
local didShortcut = false

cursorStates = {
	SELECT_LABEL = 1, 
	SELECT_OBJECT = 2,
	GAME_CARD = 3, 
	GAME_INFO = 4, 
	MOVE_OBJECT = 5,
	ADD_LABEL = 6,
	RENAME_LABEL = 7, 
	CONTROL_CENTER_MENU = 8, 
	CONTROL_CENTER_CONTENT = 9, 
	INFO_POPUP = 10
}

blockInputHandler = {
	AButtonUp = function()
	end,
	BButtonUp = function()
	end,
	rightButtonDown = function()
	end,
	rightButtonUp = function()
	end,
	leftButtonDown = function()
	end,
	leftButtonUp = function()
	end,		
	upButtonDown = function()
	end,
	upButtonUp = function()
	end,		
	downButtonDown = function()
	end,
	downButtonUp = function() 
	end,
}

-- A - SELECT, A+U - MOVE OBJECT, A+L/R - SWITCH LABELS, A+D - ADD EMPTY SPACE
-- B - BACK, B+U - RENAME LABEL, B+L/R - MOVE LABEL， B+D - TOGGLE CC
-- A+B+L - REMOVE LABEL, A+B+R - ADD LABEL A+B+U - change scale, A+B+D - remove empty item
cursorStateInputHandlers = {
	[cursorStates.SELECT_LABEL] = {
		AButtonUp = function()
			if not didShortcut and #labels[currentLabel].objects > 0 then
				sound03ActionTrimmed:play()
				currentObject = 1
				changeCursorState(cursorStates.SELECT_OBJECT)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		BButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()

			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		rightButtonDown = function()
			
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					addLabel(currentLabel, "Label "..#labelOrder)
				else
				--select label
				end
			elseif playdate.buttonIsPressed("B") then
				moveLabelRight(currentLabel)
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveRight)
			end
		end,
		rightButtonUp = function()
			removeKeyTimer()
		end,
		leftButtonDown = function()
			
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					removeLabel(currentLabel)
				else
				--select label
				end
			elseif playdate.buttonIsPressed("B") then
				moveLabelLeft(currentLabel)
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveLeft)
			end
		end,
		leftButtonUp = function()
			removeKeyTimer()
		end,		
		upButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCursorState(cursorStates.RENAME_LABEL)
				else
					--move item
				end
			elseif playdate.buttonIsPressed("B") then
				--removeEmptyObject(currentObject, currentLabel)
				didShortcut = true
			else
				toggleControlCenter()
				didShortcut = false
			end
		end,
		upButtonUp = function()
			removeKeyTimer()
		end,		
		downButtonDown = function()
			
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCurrentLabelScale()
				else
					toggleControlCenter()
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
				--nope
			else
				toggleControlCenter()
				didShortcut = false
			end
		end,
		downButtonUp = function() removeKeyTimer() end,
	},
	[cursorStates.SELECT_OBJECT] = {
		BButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				changeCursorState(cursorStates.SELECT_LABEL)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		AButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				launchGame(labels[currentLabel].objects[currentObject].bundleid)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
				
		rightButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
				--create label
				else
					removeKeyTimer()
					keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveRight)
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--move label
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveRight)
			end
		end,
		rightButtonUp = function() removeKeyTimer() end,
				
		leftButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
				--delete label
				else
					removeKeyTimer()
					keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveLeft)
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--move label
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveLeft)
			end
		end,
		leftButtonUp = function() removeKeyTimer() end,
				
		upButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCursorState(cursorStates.RENAME_LABEL)
				else
					grabObject(currentLabel,currentObject)
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
				removeEmptyObject(currentObject, currentLabel)
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveUp)
			end
		end,
		upButtonUp = function() removeKeyTimer() end,
				
		downButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCurrentLabelScale()
				else
					toggleControlCenter()
				end
			elseif playdate.buttonIsPressed("B") then
				insertEmptyObject(currentObject+1, currentLabel)
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveDown)
			end
		end,
		downButtonUp = function() removeKeyTimer() end,
	},
	[cursorStates.MOVE_OBJECT] = {
		BButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				placeHeldObject(heldObjectOriginIndex, heldObjectOriginLabel, false)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		AButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				placeHeldObject(currentObject, currentLabel, true)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
				
		rightButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
				--create label
				else
					removeKeyTimer()
					keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveRight)
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--move label
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveRight)
			end
		end,
		rightButtonUp = function() removeKeyTimer() end,
				
		leftButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
				--delete label
				else
					removeKeyTimer()
					keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, labelSelectMoveLeft)
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--move label
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveLeft)
			end
		end,
		leftButtonUp = function() removeKeyTimer() end,
				
		upButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCursorState(cursorStates.RENAME_LABEL)
				else
					--move object, already moving object thought
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
				removeEmptyObject(currentObject, currentLabel)
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveUp)
			end
		end,
		upButtonUp = function() removeKeyTimer() end,
				
		downButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					changeCurrentLabelScale()
				else
					toggleControlCenter()
				end
			elseif playdate.buttonIsPressed("B") then
				insertEmptyObject(currentObject+1, currentLabel)
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, objectSelectMoveDown)
			end
		end,
		downButtonUp = function() removeKeyTimer() end,
		
	},
	[cursorStates.GAME_CARD] = {
	
	},	
	[cursorStates.GAME_INFO] = {
	
	},
	[cursorStates.ADD_LABEL] = {
	
	},
	[cursorStates.RENAME_LABEL] = {
	
	},
	[cursorStates.CONTROL_CENTER_MENU] = {
		BButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				toggleControlCenter()
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		AButtonUp = function()
			if not didShortcut then				
				sound03ActionTrimmed:play()
				local selected = controlCenterMenuItems[controlCenterMenuSelection]
				if selected == "FunnyOS Options" then
					changeCursorState(cursorStates.CONTROL_CENTER_CONTENT)
					controlCenterInfoScroll = 0
					controlCenterInfoSelection = 1
					controlCenterInfoMaxSelection = #configVarOptionsOrder
				elseif selected == "Launcher Select" then
					changeCursorState(cursorStates.CONTROL_CENTER_CONTENT)
					controlCenterInfoScroll = 0
					controlCenterInfoSelection = 1
					controlCenterInfoMaxSelection = #launcherOrder
				elseif selected == "Recently Played" then
					changeCursorState(cursorStates.CONTROL_CENTER_CONTENT)
					controlCenterInfoScroll = 0
					controlCenterInfoSelection = 1
					controlCenterInfoMaxSelection = #recentlyPlayed
				elseif selected == "Actions Menu" then
					changeCursorState(cursorStates.CONTROL_CENTER_CONTENT)
					controlCenterInfoScroll = 0
					controlCenterInfoSelection = 1
					controlCenterInfoMaxSelection = #actionsMenuItems
				end
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
				
		upButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					--changeCurrentLabelScale()
				else
					--move object, already moving object thought
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--rename label
			else
				didShortcut = false
				removeKeyTimer()
				controlCenterInfoSelection = 1
				controlCenterInfoScroll = 0
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, controlCenterMenuMoveUp)
			end
		end,
		upButtonUp = function() removeKeyTimer() end,
				
		downButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					--EMPTY SLOT
				else
					toggleControlCenter()
				end
			elseif playdate.buttonIsPressed("B") then
				
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				controlCenterInfoSelection = 1
				controlCenterInfoScroll = 0
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, controlCenterMenuMoveDown)
			end
		end,
		downButtonUp = function() removeKeyTimer() end,
		
	},
	[cursorStates.CONTROL_CENTER_CONTENT ] = {
		
		BButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				changeCursorState(cursorStates.CONTROL_CENTER_MENU)
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		AButtonUp = function()
			if not didShortcut then
				sound03ActionTrimmed:play()
				local selected = controlCenterMenuItems[controlCenterMenuSelection]
				if selected == "FunnyOS Options" then
					incrementOptionsValue(controlCenterInfoSelection)
				end
				if selected == "Launcher Select" then
					sys.switchToGame(launchers[launcherOrder[controlCenterInfoSelection]].path)
				end
				if selected == "Recently Played" then
					sys.switchToGame(gameInfo[recentlyPlayed[controlCenterInfoSelection]].path)
				end
				if selected == "Actions Menu" then
					doActionsMenuAction(actionsMenuItems[controlCenterInfoSelection])
				end
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		
		upButtonDown = function()
			sound02SelectionReverseTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					--changeCurrentLabelScale()
				else
					--move object, already moving object thought
				end
			elseif playdate.buttonIsPressed("B") then
				didShortcut = true
					--rename label
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, controlCenterContentMoveUp)
			end
		end,
		upButtonUp = function() removeKeyTimer() end,
				
		downButtonDown = function()
			sound01SelectionTrimmed:play()
			if playdate.buttonIsPressed("A") then
				didShortcut = true
				if playdate.buttonIsPressed("B") then
					--EMPTY SLOT
				else
					--nope
				end
			elseif playdate.buttonIsPressed("B") then
				
				didShortcut = true
			else
				didShortcut = false
				removeKeyTimer()
				keyTimer = playdate.timer.keyRepeatTimerWithDelay(keyTimerInitialDelay,keyTimerRepeatDelay, controlCenterContentMoveDown)
			end
		end,
		downButtonUp = function() removeKeyTimer() end,
	
	},
	[cursorStates.INFO_POPUP ] = {
		AButtonUp = function()
			sound03ActionTrimmed:play()
			if not didShortcut then
				changeCursorState(oldCursorState)
				if infoPopupCallbackA then infoPopupCallbackA() end
			end
			delaySetNoShortcut()
			removeKeyTimer()
		end,
		BButtonUp = function()
			sound03ActionTrimmed:play()
			if not didShortcut and infoPopupEnableB then
				changeCursorState(oldCursorState)
			end
			delaySetNoShortcut()	
			removeKeyTimer()
		end
	},
}

function removeEmptyObject(index,label)
	if labels[label].objects[index].bundleid == ".empty" then
		table.remove(labels[label].objects, index)	
	end
	fillLabelEndWithEmpty(label, true)
	saveLabel(label)
end

function insertEmptyObject(index, label)
	table.insert(labels[label].objects, index, emptyObject)	
	fillLabelEndWithEmpty(label, false)	
	saveLabel(label)
end

function toggleControlCenter()
	if controlCenterState == 0 or controlCenterState == 1 then
		controlCenterState = 2
		oldCursorState = cursorState
		controlCenterInfoSelection = 1
		controlCenterMenuSelection = 1
		controlCenterInfoScroll = 0
		redrawFrame = true
		defaultRedrawFrame = false
		saveFrame = true
		changeCursorState(cursorStates.CONTROL_CENTER_MENU)
	elseif controlCenterState == 3 or controlCenterState == 2 then
		redrawFrame = true
		defaultRedrawFrame = true
		controlCenterState = 1
	end	
end

function labelSelectMoveLeft()
	if indexOf(labelOrder, currentLabel) > 1 then
		currentObject = 1
		labels[currentLabel]["collapsed"] = configVars.autocollapselabels
		currentLabel = labelOrder[indexOf(labelOrder, currentLabel)-1]	
		labels[currentLabel]["collapsed"] = false
		cursorFrame = 1
	end
end

function labelSelectMoveRight()
	if indexOf(labelOrder, currentLabel) < #labelOrder then
		currentObject = 1
		labels[currentLabel]["collapsed"] = configVars.autocollapselabels
		currentLabel = labelOrder[indexOf(labelOrder, currentLabel)+1]	
		labels[currentLabel]["collapsed"] = false
		cursorFrame = 1
	end
end


function objectSelectMoveLeft()
	if currentObject-labels[currentLabel].rows >= 1 then
		currentObject-=labels[currentLabel].rows
	elseif labelOrder[indexOf(labelOrder, currentLabel)-1] ~= nil then
		labels[currentLabel]["collapsed"] = configVars.autocollapselabels
		local oldRows = labels[currentLabel].rows
		currentLabel = labelOrder[indexOf(labelOrder, currentLabel)-1]
		labels[currentLabel]["collapsed"] = false
		local rows = labels[currentLabel].rows
		local newCurrentObject = #labels[currentLabel].objects - rows + math.ceil((rows/oldRows)*currentObject)
		if newCurrentObject < 1 then newCurrentObject = 1 end
		currentObject = newCurrentObject
		cursorFrame = 1	
	end
end

function objectSelectMoveRight()
	if currentObject+labels[currentLabel].rows <= #labels[currentLabel].objects then
		currentObject+=labels[currentLabel].rows
	elseif labelOrder[indexOf(labelOrder, currentLabel)+1] ~= nil then
		labels[currentLabel]["collapsed"] = configVars.autocollapselabels
		local oldRows = labels[currentLabel].rows
		local oldSize = #labels[currentLabel].objects
		currentLabel = labelOrder[indexOf(labelOrder, currentLabel)+1]
		labels[currentLabel]["collapsed"] = false
		local rows = labels[currentLabel].rows
		local newCurrentObject = math.ceil((((currentObject-1)%oldRows)+1)*(rows/oldRows))
		if newCurrentObject > #labels[currentLabel].objects then newCurrentObject = #labels[currentLabel].objects end
		currentObject = newCurrentObject
		cursorFrame = 1	
	end
end

function objectSelectMoveDown()
	if currentObject < #labels[currentLabel].objects then
		currentObject+=1
	end
end

function objectSelectMoveUp()
	if currentObject > 1 then
		currentObject-=1
	end
end

function moveLabelLeft(label)
	if indexOf(labelOrder, label) > 1 then
		local oldIndex = indexOf(labelOrder, label)
		table.remove(labelOrder, oldIndex)
		table.insert(labelOrder, oldIndex - 1, label)
	end	
	saveLabelOrder()
end

function moveLabelRight(label)
	if indexOf(labelOrder, label) < #labelOrder then
		local oldIndex = indexOf(labelOrder, label)
		table.remove(labelOrder, oldIndex)
		table.insert(labelOrder, oldIndex + 1, label)
	end	
	saveLabelOrder()
end

function changeCurrentLabelScale()
	if labels[currentLabel].rows == 3 then
		labels[currentLabel].rows = 6
	else
		labels[currentLabel].rows = 3	
	end
	for i, objectData in ipairs(labels[currentLabel].objects) do
		iconsCache[objectData.bundleid] = nil
	end
	saveLabel(currentLabel)
end

function delaySetNoShortcut()
	--you do this so A+B+DIR combos dont register wrong
	playdate.frameTimer.performAfterDelay(1, function() didShortcut = false end)	
end

function removeLabel(label)
	local continue = true	
	local oldLabelIndex = indexOf(labelOrder, currentLabel)
	if continue then
		for i,v in ipairs(labels[label].objects) do
			if v.bundleid ~= ".empty" then
				continue = false	
			end
		end
	end
	if not continue then
		stopAllSounds()
		sound04DenialTrimmed:play()
		createInfoPopup("Action Failed", "*A label with items in it cannot be removed without first removing those items.*", false)
		return	
	end
	labels[label] = nil
	fle.delete(savePath.."Labels/"..label..".json")
	local oldIndex = indexOf(labelOrder, label)
	table.remove(labelOrder,oldIndex)
	currentLabel = labelOrder[oldLabelIndex]
	local sub = 1
	while not currentLabel do
		currentLabel = labelOrder[oldIndex-sub]
		sub+=1
		if oldIndex - sub < 1 then
			currentLabel = labelOrder[1]	
		end
	end
	saveLabelOrder()
end

function addLabel(afterLabel, name)
	local newLabel = {["displayName"] = name, ["rows"] = 3, ["objects"] = {emptyObject}, ["collapsed"] = false}
	
	table.insert(labelOrder,  indexOf(labelOrder, currentLabel)+1, name)
	currentLabel = name
	labels[name] = newLabel
	currentObject = 1
	fillLabelEndWithEmpty(name, false)
	saveLabel(name)
	saveLabelOrder()
	changeCursorState(cursorStates.RENAME_LABEL)
end


function placeHeldObject(index, label, swap)
	if not swap then
		labels[label].objects[index] = heldObject
		heldObject = nil
	else
		local tempHeldObject = labels[label].objects[index]
		if tempHeldObject.bundleid == ".empty" then
			placeHeldObject(index, label, false)
			return	
		end
		labels[label].objects[index] = heldObject
		labels[heldObjectOriginLabel].objects[heldObjectOriginIndex] = tempHeldObject
		heldObject = nil
	end	
	changeCursorState(cursorStates.SELECT_OBJECT)	
	
	saveLabel(label)
	if label ~= heldObjectOriginLabel then
		saveLabel(heldObjectOriginLabel)
	end
end

function grabObject(label, index) 
	if labels[label].objects[index].bundleid ~= ".empty" then 
		heldObject = labels[label].objects[index]
		heldObjectOriginIndex = index
		heldObjectOriginLabel = label
		labels[label].objects[index] = emptyObject
		changeCursorState(cursorStates.MOVE_OBJECT)
	end
end

function removeKeyTimer()
	if keyTimer ~= nil then
		keyTimer:pause()
		keyTimer:remove()
		keyTimer = nil
	end
end

function controlCenterMenuMoveDown()
	controlCenterMenuSelection = controlCenterMenuSelection + 1
	if controlCenterMenuSelection > #controlCenterMenuItems then
		controlCenterMenuSelection = #controlCenterMenuItems
	end
end

function controlCenterMenuMoveUp()
	controlCenterMenuSelection = controlCenterMenuSelection - 1
	if controlCenterMenuSelection < 1 then
		controlCenterMenuSelection = 1
	end
end

function controlCenterContentMoveDown()
	controlCenterInfoSelection = controlCenterInfoSelection + 1
	if controlCenterInfoSelection and controlCenterInfoMaxSelection then
		if controlCenterInfoSelection > controlCenterInfoMaxSelection then
			controlCenterInfoSelection = controlCenterInfoMaxSelection
		end
	end
end

function controlCenterContentMoveUp()
	controlCenterInfoSelection = controlCenterInfoSelection - 1
	if controlCenterInfoSelection < 1 then
		controlCenterInfoSelection = 1
	end
end

function incrementOptionsValue(selection)
	local selected = configVarOptionsOrder[selection]
	
	
	local currentValueIndex = indexOf(configVarOptions[selected].values, configVars[selected])
	if currentValueIndex == nil then currentValueIndex = 0 end
	currentValueIndex += 1
	if currentValueIndex > # configVarOptions[selected].values then currentValueIndex = 1 end
	configVars[selected] = configVarOptions[selected].values[currentValueIndex]
	
	if selected == "autocollapselabels" then
		if configVars.autocollapselabels then
			for k,v in pairs(labels) do
				if k == currentLabel then
					labels[k].collapsed = false	
				else
					labels[k].collapsed = true	
				end
			end
		else
			for k,v in pairs(labels) do
				labels[k].collapsed = false	
			end	
		end
	elseif selected == "bgdither" or selected == "invertbgdither" then
		makeBgDitherImg()
	elseif selected == "transwrapped" then
		makeWrappedImgs()
		iconsCache = {}
	elseif selected == "musicon" then
		if configVars.musicon then 
			loadMusic() 
		elseif music then
			music:stop()
		end
	elseif selected == "bgon" then
		if configVars.bgon then loadBgImg() else bgImg = nil end	
	elseif selected == "iconborders" or selected == "invertborders" then
		iconsCache = {}	
	end
	redrawFrame = true
	saveConfig()
end

function doActionsMenuAction(name) 
	if name == "Play Random Game" then
		launchRandomGame()
	elseif name == "Alphabet Sort Objects" then
		alphabetSortLabelContents()
		saveConfig()
	elseif name == "Alphabet Sort Labels" then
		alphabetSortLabels()
		saveLabelOrder()
	elseif name == "Reset FunnyOS 2" then
		createInfoPopup("Warning", "*This cannot be reversed. Pressing *"..buttons.A.."* on this prompt will erase your customizaion settings and label setups. Your custom assets in the shared folder will not be deleted.", true, function()
			fle.delete(savePath.."funnyConfig.json")
			fle.delete(savePath.."labelOrder.json")
			if fle.isdir(savePath.."Labels") then
				fle.delete(savePath.."Labels", true)
			end
			local path = launchers[funnyOSMetadata.name].path
			sys.switchToGame(path)
		end
		)
	end	
end