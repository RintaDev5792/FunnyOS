import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/frameTimer")
import("CoreLibs/object")
import("aesthetics")
import("system")
import("input")
import("utils")

savePath = "/Shared/FunnyOS2/"

firstLaunch = false

currentLabel = "System"
currentObject = 1

heldObject = nil
heldObjectOriginIndex = 1
heldObjectOriginLabel = ""

redrawFrame = true

iconsLoadedThisFrame = 0

targetFPS = 40

delta = 1/40

tempVars = {}

iconsCache = {}

recentlyPlayed = {}

labels = {}
labelOrder = {}
labelsCache = {}
iconGridCache = {}

widgetMaskImg = nil

badges = {}

widgets = {}
currentWidget = 1
widgetIsActive = false

objectSizes = {[3] = 68, [6] = 34}
objectSpacings = {[3] = 4, [6] = 2}
storage, freeStorage = nil, nil
local homeRows = 3

local firstUpdate = true

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
	INFO_POPUP = 10,
	SELECT_WIDGET = 11
}


crankSinceLastNotch = 0
crankNotchSizes = {180, 90,180,180,90,0,0,45,45,0,180}
currentCrankNotchSize = 1
crankCallbacks = {
	[cursorStates.SELECT_LABEL] = {
		[true] = labelSelectMoveRight,
		[false] = labelSelectMoveLeft
	},
	[cursorStates.SELECT_OBJECT] = {
		[true] = objectSelectMoveDown,
		[false] = objectSelectMoveUp
	},
	[cursorStates.MOVE_OBJECT] = {
		[true] = objectSelectMoveDown,
		[false] = objectSelectMoveUp
	},
	[cursorStates.CONTROL_CENTER_MENU] = {
		[true] = controlCenterMenuMoveDown,
		[false] = controlCenterMenuMoveUp
	},
	[cursorStates.CONTROL_CENTER_CONTENT] = {
		[true] = controlCenterContentMoveDown,
		[false] = controlCenterContentMoveUp
	},
	[cursorStates.SELECT_WIDGET] = {
		[true] = widgetSelectMoveDown,
		[false] = widgetSelectMoveUp
	},
}


music = nil
sound01SelectionTrimmed = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
sound02SelectionReverseTrimmed = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
sound03ActionTrimmed = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
sound04DenialTrimmed = playdate.sound.fileplayer.new("systemsfx/04-denial-trimmed")
soundUnwrap = playdate.sound.fileplayer.new("systemsfx/unwrap")

controlCenterMenuSelection = 0
controlCenterInfoSelection = 0
controlCenterInfoMaxSelection = 0
controlCenterInfoScroll = 0

drawingLaunchAnim = false
launchAnimProgress = 0
bundleIDToLaunch = nil

funnyOSMetadata = playdate.metadata

controlCenterMenuSelection = 2

cursorState = cursorStates.SELECT_LABEL
oldCursorState = cursorStates.SELECT_LABEL

emptyObject = {bundleid = ".empty"}
emptySpaceImgs = {}

infoPopupTitle = ""
infoPopupBody = ""
infoPopupCallbackA = nil
infoPopupEnableB = true

dumpFrame = false
dumpCount = 0

configVarDefaults = {
	["configversion"] = 2.1,
	
	--options
	["musicon"] = true,
	["bgon"] = true,
	["skipcard"] = false,
	["iconborders"] = true,
	["invertborders"] = false,
	["iconbgs"] = true,
	["inverticonbgs"] = false,
	["invertcursor"] = false,
	["invertlabels"] = false,
	["invertlabeltext"] = false,
	["labeltextbgs"] = true,
	["bgdither"] = 1,
	["invertbgdither"] = false,
	["ccdither"] = 0.25,
	["invertcc"] = false,
	["invertwidgets"] = false,
	["invertwidgetcursor"] = false,
	["labeldither"] = 0.75,
	["cornerradius"] = 20,
	["linewidth"] = 3,
	["autocollapselabels"] = false,
	["transwrapped"] = true,
	["hidewrapped"] = true,
	["sysinfoonboot"] = false,
	["showfps"] = false,
	["crankacceleration"] = false,
	["invertcrank"] = false,
	["lettericons"] = false,
}

configVarOptions = {
	--options
	["musicon"] = {["name"] = "Enable Music", ["values"] = {true, false}, ["type"] = "BOOL"},
	["lettericons"] = {["name"] = "Letter Icons", ["values"] = {true, false}, ["type"] = "BOOL"},
	["bgon"] = {["name"] = "Enable BG Image", ["values"] = {true, false}, ["type"] = "BOOL"},
	["crankacceleration"] = {["name"] = "Crank Acceleration", ["values"] = {true, false}, ["type"] = "BOOL"},
	["bgon"] = {["name"] = "Enable BG Image", ["values"] = {true, false}, ["type"] = "BOOL"},
	["iconborders"] =  {["name"] = "Enable Icon Borders", ["values"] = {true, false}, ["type"] = "BOOL"},
	["iconbgs"] =  {["name"] = "Enable Icon BGs", ["values"] = {true, false}, ["type"] = "BOOL"},
	["skipcard"] =  {["name"] = "Skip Card View", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertborders"] =  {["name"] = "Invert Icon Borders", ["values"] = {true, false}, ["type"] = "BOOL"},
	["inverticonbgs"] =  {["name"] = "Invert Icon BGs", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertcursor"] =  {["name"] = "Invert Cursor", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertlabels"] =  {["name"] = "Invert Labels", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertlabeltext"] =  {["name"] = "Invert Label Text", ["values"] = {true, false}, ["type"] = "BOOL"},
	["labeltextbgs"] =  {["name"] = "Label Text BGs", ["values"] = {true, false}, ["type"] = "BOOL"},
	["bgdither"] = {["name"] = "BG Dither", ["values"] = {1, 0.9, 0.75, 0.6, 0.5,0.35,0.25,0.10,0}, ["type"] = "DITHER"},
	["invertbgdither"] = {["name"] = "Invert BG Dither", ["values"] = {true, false}, ["type"] = "BOOL"},
	["ccdither"] = {["name"] = "CC Dither", ["values"] = {1, 0.9, 0.75, 0.6, 0.5,0.35,0.25,0.10,0}, ["type"] = "DITHER"},
	["invertcc"] = {["name"] = "Invert CC", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertwidgets"] = {["name"] = "Invert Widgets", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertwidgetcursor"] = {["name"] = "Invert Widget Cursor", ["values"] = {true, false}, ["type"] = "BOOL"},
	["labeldither"] = {["name"] = "Label Dither", ["values"] = {1, 0.9, 0.75, 0.6, 0.5,0.35,0.25,0.10,0}, ["type"] = "DITHER"},
	["cornerradius"] = {["name"] = "Corner Radius", ["values"] = {1, 5, 10, 15, 20, 25, 30}, ["type"] = "PIXELS"},
	["linewidth"] = {["name"] = "Outline Width", ["values"] = {1, 2, 3, 4, 5, 6}, ["type"] = "PIXELS"},
	["autocollapselabels"] =  {["name"] = "Auto-Close Labels", ["values"] = {true, false}, ["type"] = "BOOL"},
	["transwrapped"] =  {["name"] = "Clear Icon Wrap", ["values"] = {true, false}, ["type"] = "BOOL"},
	["hidewrapped"] =  {["name"] = "Hide New Names", ["values"] = {true, false}, ["type"] = "BOOL"},
	["sysinfoonboot"] =  {["name"] = "Get Sysinfo on Boot", ["values"] = {true, false}, ["type"] = "BOOL"},
	["showfps"] =  {["name"] = "Show FPS", ["values"] = {true, false}, ["type"] = "BOOL"},
	["invertcrank"] =  {["name"] = "Reverse Crank", ["values"] = {true, false}, ["type"] = "BOOL"},
}

configVarOptionsOrder = {
	"musicon",
	"bgon",
	"bgdither",
	"labeldither",
	"ccdither",
	"lettericons",
	"iconborders",
	"invertborders",
	"iconbgs",
	"labeltextbgs",
	"inverticonbgs",
	"invertcursor",
	"invertlabels",
	"invertlabeltext",
	"invertbgdither",
	"invertcc",
	"invertwidgets",
	"invertwidgetcursor",
	"cornerradius",
	"linewidth",
	"autocollapselabels",
	"crankacceleration",
	"invertcrank",
	"skipcard",
	"transwrapped",
	"hidewrapped",
	"showfps",
	"sysinfoonboot",
}


controlCenterMenuItems = {
	"Controls Help",
	"Actions Menu",
	"Recently Played",
	"FunnyOS Options",
	"Screenshots",
	"Package Installer",
	"System Info"
}

actionsMenuItems = {
	"Play Random Game",
	"Alphabet Sort Objects",
	"Alphabet Sort Labels",
	"Reset FunnyOS 2",
}

packageInstallerMenuItems = {
	"Check for Updates",
	"Install Package",
}

configVars = configVarDefaults


function playdate.cranked(c,ac)
	local change = c
	if configVars.crankacceleration then
		change = ac
	end
	crankSinceLastNotch+=change
	local crankNotchSize = crankNotchSizes[cursorState]
	local times = 0
	while math.abs(crankSinceLastNotch) >= crankNotchSize and crankNotchSize ~= 0 do
		times += 1
		if crankSinceLastNotch < 0 then
			crankSinceLastNotch += crankNotchSize
			
		else
			crankSinceLastNotch -= crankNotchSize
			
		end
		if crankCallbacks[cursorState] then
			local bool = crankSinceLastNotch > 0
			if configVars.invertcrank then bool = not bool end
			if crankCallbacks[cursorState][bool] then
				crankCallbacks[cursorState][bool](times > 1)
			end
		end
	end
end

function stopAllSounds()
	sound01SelectionTrimmed:stop()
	sound02SelectionReverseTrimmed:stop()
	sound03ActionTrimmed:stop()	
	sound04DenialTrimmed:stop()
end

function createInfoPopup(title, text, enableB, callbackA)
	if cursorState ~= cursorStates.INFO_POPUP then  
		oldCursorState = cursorState
	end
	changeCursorState(cursorStates.INFO_POPUP)
	infoPopupTitle = title
	infoPopupBody = text
	infoPopupCallbackA = callbackA
	infoPopupEnableB = enableB
	if enableB == nil then
		infoPopupEnableB = true	
	end
end

function changeCursorState(state)
	cursorState = state
	redrawFrame = true
	while #playdate.inputHandlers > 1 do
		playdate.inputHandlers.pop()
	end
	playdate.inputHandlers.push(cursorStateInputHandlers[state])	
	if state == cursorStates.RENAME_LABEL then
		playdate.frameTimer.performAfterDelay(10, function() key.show(currentLabel) end)	
	end
end

function dumpGlobals()
	dumpCount = 0
	if fle.isdir(savePath.."Dump") then
		fle.delete(savePath.."Dump", true)
	end
	fle.mkdir(savePath.."Dump")
	playdate.resetElapsedTime()
	deepStringCopy(_G, 0, true)
	print("DONE")
end

function deepStringCopy(table, depth, save)
	local s = "{"
	for k,v in pairs(table) do
		local valString = tostring(k).." = "
		if k == "_G" then
			valString = valString.."RECURSION PREVENTION SQUAD :sunglasses:"
		elseif type(v) == "nil" or v == nil then
			valString = valString.."nil"
		elseif type(v) == "boolean" then
			if v==true then
				valString = valString.."true"
			else
				valString = valString.."false"
			end
		elseif type(v) == "table" then
			if depth < 4 then
				valString = valString..deepStringCopy(v, depth+1, false)
			else
				valString = valString.."miscellaneous "..type(v)	
			end	
		elseif type(v) == "number" or type(v) == "string" then
			valString = valString..tostring(v)
			
		else
			valString = valString.."miscellaneous "..type(v)	
		end
		s = s..valString..", "
		if playdate.getElapsedTime() > 8.5 or #s > 1048576 then
			if save then 
				das.write(s.."}", savePath.."Dump/globals_"..tostring(dumpCount))
				dumpCount += 1
				s = "{" 
			end
			playdate.resetElapsedTime()
			coroutine.yield()
		end
	end
	if save then das.write(s.."}", savePath.."Dump/globals_"..tostring(dumpCount)); dumpCount += 1 end
	return s.."}"
end

function saveConfig()
	das.write(configVars,savePath.."funnyConfig")
	saveLabelOrder()
	saveWidgetOrder()
	for k,v in pairs(labels) do
		das.write(v,savePath.."Labels/"..k)
	end
end

function saveRecentlyPlayed()
	das.write(recentlyPlayed,savePath.."recentlyPlayed")	
end

function saveLabelOrder()
	das.write(labelOrder,savePath.."labelOrder")	
end

function saveWidgetOrder()
	local widgetOrder = {}
	for i,widget in ipairs(widgets) do
		widgetOrder[i] = widget.metadata.name
	end
	das.write(widgetOrder,savePath.."widgetOrder")	
end

function saveLabel(label,skipReload)
	if not skipReload then
		labelsCache[label] = nil
	end
	das.write(labels[label],savePath.."Labels/"..label)
end

function loadConfig()
	local datastore = das.read(savePath.."funnyConfig")
	if datastore then 
		for k, v in pairs(datastore) do
			--if datastore["configversion"] ~= configVarDefaults["configversion"] then
			--	break
			--end
			configVars[k] = v	
		end
	end
	
	for k, v in pairs(configVars) do
		if v == nil then configVars[k] = configVarDefaults[k] end	
	end
	
	local datastore = das.read(savePath .. "labelOrder")
	if datastore then
		labelOrder = datastore
	end
	
	if fle.isdir(savePath .. "Labels/") then
		local labelFiles = fle.listFiles(savePath .. "Labels/")
		labels = {}
	
		for _, labelFile in ipairs(labelFiles) do
			if labelFile:sub(1,-6) then
				labels[labelFile:sub(1,-6)] = das.read(savePath .. "Labels/" .. labelFile:sub(1,-6))
				if labels[labelFile:sub(1,-6)] then
					labels[labelFile:sub(1,-6)]["collapsed"] = configVars.autocollapselabels
				end
			end
		end
	end
	
	local datastore = das.read(savePath .. "recentlyPlayed")
	if not datastore then recentlyPlayed = {} else recentlyPlayed = datastore end
	while #recentlyPlayed > 6 do
		table.remove(recentlyPlayed,#recentlyPlayed)	
	end
end

function dirSetup()
	firstLaunch = not fle.exists(savePath .. "funnyConfig.json")
	fle.mkdir(savePath)
	fle.mkdir(savePath .. "Badges")
	fle.mkdir(savePath .. "Widgets")
	fle.mkdir(savePath .. "Labels")
	fle.mkdir(savePath .. "Package")
	loadImgs()
end

function playdate.deviceWillLock()
	--collectgarbage("collect")
end

function playdate.deviceWillUnlock()
	-- i just have this here in case
end

function playdate.keyboard.keyboardAnimatingCallback()
	redrawFrame = true
end

function playdate.keyboard.keyboardAnimatingCallback()
	redrawFrame = true
end

function playdate.keyboard.textChangedCallback()
	key.text = key.text:gsub("/", "&")
	key.text = key.text:gsub("\\", "&")
	if cursorState == cursorStates.SELECT_WIDGET then
		if widgetIsActive and widgets[currentWidget].textChangedCallback then
			widgets[currentWidget]:textChangedCallback()	
		end
	end
end

function playdate.keyboard.keyboardDidHideCallback()
	if cursorState == cursorStates.RENAME_LABEL then
		changeCursorState(cursorStates.SELECT_LABEL)	
		redrawFrame = true
	end
end

function playdate.keyboard.keyboardWillHideCallback(pressedOK)
	if cursorState == cursorStates.RENAME_LABEL then
		if pressedOK then
			key.text = key.text:gsub("/", "&")
			if key.text == currentLabel then return end
			if labels[key.text] then
				stopAllSounds()
				sound04DenialTrimmed:play()
				createInfoPopup("Action Failed", "*A label cannot be created with the same name as an existing label.*", false)
				return
			end			--set displayname, labels[key], labelOrder, filename (delete old)
			local oldLabelName = currentLabel
			local newLabelName = key.text
			fle.delete(savePath.."Labels/"..oldLabelName..".json")
			labels[oldLabelName].displayName = newLabelName
			local labelData = labels[oldLabelName]
			labels[newLabelName] = {}
			for k,v in pairs(labelData) do
				labels[newLabelName][k] = v	
			end
			labels[newLabelName].objects = listCopy(labelData.objects)
			labels[oldLabelName] = nil
			labelOrder[indexOf(labelOrder, oldLabelName)] = newLabelName
			currentLabel = newLabelName
			currentObject = 1
			saveLabel(newLabelName)
			saveLabelOrder()
		end
	elseif cursorState == cursorStates.SELECT_WIDGET then
		if widgetIsActive and widgets[currentWidget].keyboardWillHideCallback then
			widgets[currentWidget]:keyboardWillHideCallback(pressedOK)	
		end
	end
end

function playdate.update()
	iconsLoadedThisFrame = 0
	if firstUpdate then
		firstUpdate = false
		main()
		return
	end
	
	
	playdate.timer.updateTimers()
	playdate.frameTimer.updateTimers()
	
	if #playdate.inputHandlers < 2 then
		playdate.inputHandlers.push(cursorStateInputHandlers[cursorState])	  
	end
	drawRoutine()
	if dumpFrame then
		dumpGlobals()
		dumpFrame = false
	end
	delta = 1/playdate.display.getRefreshRate()--playdate.getFPS()
	updateReap()
	if configVars.showfps then
		playdate.drawFPS(0,0)
	end
end

function loadMusic()
	music = playdate.sound.fileplayer.new("/Shared/FunnyOS2/bgm")
	if music ~= nil then
		music:play()
		music:setFinishCallback(function()  if configVars.musicon then loadMusic() end end)
	else
		stopAllSounds()
		sound04DenialTrimmed:play()
		createInfoPopup("Action Failed", "*FunnyOS does not come with music pre-installed. To have music, please place a .pda of the music you want at /Shared/FunnyOS2/bgm.pda. ", false, function() configVars.musicon = false; saveConfig() end)	
	end
end

function loadBgImg()
	bgImg = gfx.image.new("/Shared/FunnyOS2/bg")
	if bgImg == nil then
		stopAllSounds()
		sound04DenialTrimmed:play()
		createInfoPopup("Action Failed", "*FunnyOS does not come with a background pre-installed. To have one, please place a .pdi of the background you want at /Shared/FunnyOS2/bg.pdi. ", false, function() configVars.bgon = false; saveConfig() end)	
	end
end

function main()
	loadConfig()
	dirSetup()
	playdate.setAutoLockDisabled(false)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	if configVars.bgon then
		loadBgImg()
	end
	if loadingImg then
		if configVars.bgon and bgImg ~= nil then
			bgImg:draw(0,0)	
		end
		loadingImg:drawCentered(200,120)
	end
	playdate.display.setRefreshRate(targetFPS)
	playdate.display.flush()
	coroutine.yield()
	changeCursorState(cursorStates.SELECT_LABEL)
	loadWidgets()
	loadBadges()
	if configVars.musicon then
		loadMusic()
	end
	
	math.randomseed(playdate.getSecondsSinceEpoch())
	
	
	-- give it a tad
	coroutine.yield()
	
	setupGameInfo()
	if configVars.sysinfoonboot then
		freeStorage = playdate.system.getFreeDiskSpace()
		totalStorage = playdate.system.getTotalDiskSpace()		
	end
	
	local menu = playdate.getSystemMenu()
	menu:removeAllMenuItems()
	menu:addMenuItem("DUMP", function() dumpFrame = true end) 
	
	playdate.timer.performAfterDelay(500, updateCursorFrame)
	playdate.timer.performAfterDelay(500, updateCircleCursorRadius)
	if firstLaunch then
		createInfoPopup("Welcome!", "*Hello, and thank you for using FunnyOS 2! FunnyOS 2 uses button combos, so you must know those to do most tasks. These combos can be found in the control center.*", false, function() createInfoPopup("Welcome!", "*In order to open the control center, press *"..buttons.A.."*+*"..buttons.DOWN.."*. The control center also houses other useful features, so be sure to look through it to get the most out of FunnyOS 2. Have fun!*", false, function()  end) end)
	end
end