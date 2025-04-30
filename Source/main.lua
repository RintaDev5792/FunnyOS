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

targetFPS = 40

delta = 1/40

tempVars = {}

iconsCache = {}

recentlyPlayed = {}

labels = {}
labelOrder = {}

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
	["configversion"] = 2.0,
	
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
	["labeldither"] = 0.75,
	["cornerradius"] = 20,
	["linewidth"] = 3,
	["autocollapselabels"] = false,
	["transwrapped"] = true,
	["hidewrapped"] = true,
	["sysinfoonboot"] = false,
}

configVarOptions = {
	--options
	["musicon"] = {["name"] = "Enable Music", ["values"] = {true, false}, ["type"] = "BOOL"},
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
	["bgdither"] = {["name"] = "BG Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}, ["type"] = "DITHER"},
	["invertbgdither"] = {["name"] = "Invert BG Dither", ["values"] = {true, false}, ["type"] = "BOOL"},
	["ccdither"] = {["name"] = "CC Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}, ["type"] = "DITHER"},
	["invertcc"] = {["name"] = "Invert CC", ["values"] = {true, false}, ["type"] = "BOOL"},
	["labeldither"] = {["name"] = "Label Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}, ["type"] = "DITHER"},
	["cornerradius"] = {["name"] = "Corner Radius", ["values"] = {1, 5, 10, 15, 20, 25}, ["type"] = "PIXELS"},
	["linewidth"] = {["name"] = "Outline Width", ["values"] = {2, 3, 4, 5, 6}, ["type"] = "PIXELS"},
	["autocollapselabels"] =  {["name"] = "Auto-Close Labels", ["values"] = {true, false}, ["type"] = "BOOL"},
	["transwrapped"] =  {["name"] = "Clear Icon Wrap", ["values"] = {true, false}, ["type"] = "BOOL"},
	["hidewrapped"] =  {["name"] = "Hide New Names", ["values"] = {true, false}, ["type"] = "BOOL"},
	["sysinfoonboot"] =  {["name"] = "Get Sysinfo on Boot", ["values"] = {true, false}, ["type"] = "BOOL"},
}

configVarOptionsOrder = {
	"musicon",
	"bgon",
	"bgdither",
	"labeldither",
	"ccdither",
	"iconborders",
	"invertborders",
	"iconbgs",
	"inverticonbgs",
	"invertcursor",
	"invertlabels",
	"invertlabeltext",
	"labeltextbgs",
	"invertbgdither",
	"invertcc",
	"cornerradius",
	"linewidth",
	"autocollapselabels",
	"skipcard",
	"transwrapped",
	"hidewrapped",
	"sysinfoonboot",
}


controlCenterMenuItems = {
	"Controls Help",
	"Actions Menu",
	"Recently Played",
	"Badges Menu",
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
			
		else
			print(#s)	
		end
	end
	if save then das.write(s.."}", savePath.."Dump/globals_"..tostring(dumpCount)); dumpCount += 1 end
	return s.."}"
end

function saveConfig()
	das.write(configVars,savePath.."funnyConfig")
	das.write(labelOrder,savePath.."labelOrder")
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

function saveLabel(label)
	das.write(labels[label],savePath.."Labels/"..label)
end

function loadConfig()
	local datastore = das.read(savePath.."funnyConfig")
	if datastore then 
		for k, v in pairs(datastore) do
			if datastore["configversion"] ~= configVarDefaults["configversion"] then
				break
			end
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
			labels[labelFile:sub(1,-6)] = das.read(savePath .. "Labels/" .. labelFile:sub(1,-6))
			labels[labelFile:sub(1,-6)]["collapsed"] = configVars.autocollapselabels
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

function playdate.keyboard.keyboardDidHideCallback()
	if cursorState == cursorStates.RENAME_LABEL then
		changeCursorState(cursorStates.SELECT_LABEL)	
		redrawFrame = true
	end
end

function playdate.keyboard.keyboardWillHideCallback(pressedOK)
	if cursorState == cursorStates.RENAME_LABEL then
		if pressedOK then
			if labels[key.text] then
				stopAllSounds()
				sound04DenialTrimmed:play()
				createInfoPopup("Action Failed", "*A label cannot be created with the same name as an existing label.*", false)
				return
			end
			--set displayname, labels[key], labelOrder, filename (delete old)
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
	end
end

function playdate.keyboard.textChangedCallback()
	
end

function playdate.update()
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
	if loadingImg then
		loadingImg:draw(0,0)
	end
	playdate.display.setRefreshRate(targetFPS)
	playdate.display.flush()
	changeCursorState(cursorStates.SELECT_LABEL)
	loadWidgets()
	loadBadges()
	if configVars.musicon then
		loadMusic()
	end
	if configVars.bgon then
		loadBgImg()
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