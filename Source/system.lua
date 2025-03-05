import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("utils")

defaultListIcon = playdate.graphics.image.new("images/list_icon_default")
gameInfo, groups, sortedGameInfo = nil, nil, nil

season1 = {
	"com.a-m.beats-bleeps-boogie",
	"com.crookedpark.demonquest85",
	"com.dadako.questychess",
	"com.davemakes.execgolf",
	"com.gregorykogos.omaze",
	"com.nelsanderson.forrest",
	"com.nicmagnier.pickpackpup",
	"com.panic.b360",
	"com.panic.inventoryhero",
	"com.panic.starsled",
	"com.radstronomical.CasualBirder",
	"com.samanthazero.echoicmemory",
	"com.serenityforge.elevator",
	"com.shauninman.ratcheteer",
	"com.spectrecollie.sasquatchers",
	"com.sweetbabyinc.lostyourmarbles",
	"com.teambottle.spellcorked",
	"com.tpmcosoft.battleship",
	"com.uvula.crankin",
	"com.vertexpop.hypermeteor",
	"com.vitei.whitewater",
	"com.wildrose.saturday",
	"net.foddy.zipper",
	"net.stfj.snak"
}

local kPDGameStateFreshlyInstalled, kPDGameStateInstalled
if playdate.system ~= nil then
	kPDGameStateFreshlyInstalled = playdate.system.game.kPDGameStateFreshlyInstalled
	kPDGameStateInstalled = playdate.system.game.kPDGameStateInstalled
end


function openApp(bundleId)
	if bundleId and gameInfo[bundleId] then
		local success = playdate.system.switchToGame(gameInfo[bundleId].path)
		if not success then
			print("Failed to launch app: " .. bundleId)
			sound04DenialTrimmed:play()
			createInfoPopup("Launch Failed", "*The game or app could not be launched. It may have been moved or deleted.*", false)
		end
	end
end

function loadWidgets()
	local widgetsPath = savePath.."Widgets/"

	widgets = {}

	local folders = playdate.file.listFiles(widgetsPath)
	for _, folder in ipairs(folders) do
		local folderPath = widgetsPath .. folder .. "/"
		if playdate.file.isdir(folderPath) then
			if playdate.file.exists(folderPath .. "main.pdz") then
				local success, widget = pcall(function()
					return playdate.file.run(folderPath .. "main.pdz")
				end)

				if success and widget and widget.metadata and widget.main then
					widget.path = folderPath
					table.insert(widgets, widget)
				else
					print("Failed to load widget: " .. (success and "invalid widget" or widget))
				end
			end
		end
	end

	if #widgets > 0 then
		selectedWidget = 1
		-- Generate initial cached images for all widgets
		for _, widget in ipairs(widgets) do
			widget.lastDrawnImage = widget:main(widget.path)
		end
	end
	alphabetSortWidgets()
	printTable(widgets)
	
end

function getGameObject(bundleID) 
	if not gameInfo[bundleID] then return nil end
	for i,v in ipairs(groups) do
		if v.name == gameInfo[bundleID].group then
			for j, w in ipairs(v) do
				if w:getBundleID() == bundleID then return w end	
			end
		end
	end	
	return nil
end

function addToRecentlyPlayed(bundleid)
	if not listHasValue(recentlyPlayed, bundleid) then
		table.insert(recentlyPlayed, 1, bundleid)
	else
		table.remove(recentlyPlayed,indexOf(recentlyPlayed, bundleid))
		table.insert(recentlyPlayed, 1, bundleid)
	end
	while #recentlyPlayed > 6 do
		table.remove(recentlyPlayed, #recentlyPlayed)
	end
	saveRecentlyPlayed()
end

function launchGame(bundleID)
	if gameInfo[bundleID].path then
		if fle.isdir(gameInfo[bundleID].path) or fle.exists(gameInfo[bundleID].path) then
			if gameIsFreshlyInstalled(bundleID, true) then
				soundUnwrap:setOffset(2)
				soundUnwrap:play()
				playdate.inputHandlers.push(blockInputHandler)
				playdate.timer.performAfterDelay(1000, function()
					iconsCache[labels[currentLabel].objects[currentObject].bundleid] = nil
				end)
				playdate.timer.performAfterDelay(3000,function()
					sys.updateGameList()
					playdate.inputHandlers.pop()
				end)
			else
				if gameInfo[bundleID].suppresscontentwarning or not gameInfo[bundleID].contentwarning then
					addToRecentlyPlayed(bundleID)
					sys.switchToGame(labels[currentLabel].objects[currentObject].path)
				elseif gameInfo[bundleID].contentwarning then
					createInfoPopup("Content Warning", "*"..gameInfo[bundleID].contentwarning.."*", true, function()
						if gameInfo[bundleID].contentwarning2 then
							createInfoPopup("Content Warning", "*"..gameInfo[bundleID].contentwarning2.."*", true, function()
								local game = getGameObject(bundleID)
								if game then
									game:setSuppressContentWarning(true)
								end
								sys.updateGameList()
								addToRecentlyPlayed(bundleID)
								sys.switchToGame(labels[currentLabel].objects[currentObject].path)
							end)
						else
							local game = getGameObject(bundleID)
							if game then
								game:setSuppressContentWarning(true)
								print("SUPRESSED")
							else
								print("THEREISNOGAME")	
							end
							sys.updateGameList()
							addToRecentlyPlayed(bundleID)
							sys.switchToGame(labels[currentLabel].objects[currentObject].path)
						end
						
					end)	
				end
			end
		end
	end
end

function launchRandomGame()
	local possibleGames = {}
	for i,v in ipairs(groups) do
		if v.name ~= "System" then
			for j,w in ipairs(v) do
				table.insert(possibleGames, w)
			end	
		end	
	end
	local game = possibleGames[math.random(1, #possibleGames)]
	launchGame(game:getBundleID())
end

function getLauncherIcon(path)
	if fle.exists(path.."/icon.pdi") then
		return gfx.image.new(path.."/icon.pdi")
	elseif fle.exists(path.."/images/list_icon_default.pdi") then
		return gfx.image.new(path.."/images/list_icon_default.pdi")
	else
		local f = fle.open(path.."/pdxinfo") 
		if sys.getMetadata(path .. "/pdxinfo").name=="Index OS" then
			local img = gfx.image.new(32,32,gfx.kColorClear)
			gfx.lockFocus(img)
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRoundRect(0, 0, 32, 32, 3)
			gfx.image.new("images/indexOS"):draw(0,0)
			gfx.unlockFocus()
			return img
		end
	end	
end

function loadLaunchers()
	launchers = {}
	if fle.isdir("/System/Launchers") then
		local files = fle.listFiles("/System/Launchers")
		for i,v in ipairs(files) do
			v = v:sub(1,#v-1) --remove slash
			files[i] = v
			if string.lower(v:sub(#v-3,#v)) == ".pdx" then
				local launcherName = sys.getMetadata("/System/Launchers/".. v .. "/pdxinfo").name
				launchers[launcherName] = {["icon"] = getLauncherIcon("/System/Launchers/"..v), ["path"] = "/System/Launchers/"..v}
			end
		end	
	end
	local launcherName = sys.getMetadata("/System/Launcher.pdx/pdxinfo").name
	launchers[launcherName] = {["icon"] = getLauncherIcon("/System/Launcher.pdx"), ["path"] = "/System/Launcher.pdx"}
	launcherOrder = {}
	for k,v in pairs(launchers) do
		if k ~= "FunnyOS 2" then
			table.insert(launcherOrder, k)	
		end
	end
	table.sort(launcherOrder)
	launchers["FunnyOS 2"] = nil
end

function alphabetSortLabels()
	table.sort(labelOrder)
end

function alphabetSortLabelContents()
	for _, label in pairs(labels) do
		table.sort(label.objects, function(o1, o2)
			if o1.name and o2.name then
				return o1.name < o2.name
			else
				return o1.name	
			end
		end)
	end
end

function alphabetSortWidgets()
	for _, label in pairs(widgets) do
		table.sort(widgets, function(o1, o2)
			if o1.metadata.name and o2.metadata.name then
				return o1.metadata.name < o2.metadata.name
			else
				return o1.metadata.name	
			end
		end)
	end
end

function setupGameInfo()
	sys.updateGameList()
	
	gameInfo = {}
	groups = sys.getInstalledGameList()
	
	-- fill out the gameInfo table
	for i, group in ipairs(groups) do
		for j, game in ipairs(group) do
			local gamePath = game:getPath()
			if gamePath ~= nil then
				if game:getBundleID() then
					local props = sys.getMetadata(gamePath .. "/pdxinfo")
					local newprops = {}
					
					for k, v in pairs(props) do
						newprops[k:lower()] = v
					end
					
					props = newprops
					props["path"] = gamePath
					
					local imagePath = props["imagepath"]
					if imagePath then
						if imagePath:sub(-4) == ".png" or fle.exists(gamePath .. "/" .. imagePath .. ".pdi") then
							local found, _, imgp = imagePath:find("^([^/]-)/")
							if found == nil or imgp == imagePath then
								imgp = ""
							end
							
							props["imagepath"] = imgp
						end
					end

					props["group"] = group.name
					props["suppresscontentwarning"] = game:getSuppressContentWarning()
					props["wrapped"] = game:getInstalledState() == kPDGameStateFreshlyInstalled
					gameInfo[game:getBundleID()] = props
				end
			else
				return false
			end
		end
	end
	
	-- copy all the game metadata to sortedGameInfo
	sortedGameInfo = {}
	for bundleID, props in pairs(gameInfo) do
		if sortedGameInfo[props["group"]] == nil then
			sortedGameInfo[props["group"]] = {}
		end
		sortedGameInfo[props["group"]][bundleID] = props
	end
	
	for groupName, group in pairs(sortedGameInfo) do
		for bundleID, objectData in pairs(group) do
			local found = false
			
			-- make sure the game actually exists and is not an empty slot
			if bundleID ~= ".empty" then
				for name, label in pairs(labels) do
					for _, object in ipairs(label.objects) do
						if object.bundleid == bundleID then
							found = true
							break
						end
					end
					
					if found then
						break
					end
				end
			end
			
			-- games which should not be displayed in the launcher
			local systemGameBlacklist = {
				"com.panic.launcher",
				"com.shauninman.InputTest",
				"com.panic.setup",
				"com.panic.setupintro"
			}
			
			-- remove the games which weren't found or are on the blacklist
			if not found and not listHasValue(systemGameBlacklist, bundleID) then 
				if labels[groupName] == nil then
					labels[groupName] = {
						displayName = groupName,
						rows = 3,
						objects = {},
						collapsed = false
					}
				end
				
				local foundEmpty = false
				local index = nil
				
				for i, data in ipairs(labels[groupName].objects) do
					if data.bundleid == ".empty" then
						index = i
						foundEmpty = true
						break
					end
				end
				
				if foundEmpty then
					labels[groupName].objects[index] = objectData
				else
					table.insert(labels[groupName].objects, objectData) 
				end
			end
		end
	end
	
	-- don't display empty labels
	for name, label in pairs(labels) do
		if label.objects == {} then
			labels[name] = nil	
			fle.delete(savePath.."Labels/"..name..".json")
		end
	end
	
	-- delete empty label names from labelOrder
	local newLabelOrder = {}
	for _, name in ipairs(labelOrder) do
		if labels[name] ~= nil then
			table.insert(newLabelOrder, name)	
		end
	end
	labelOrder = newLabelOrder
	
	-- deduplicate games and delete nonexistent ones
	local alreadyFoundObjects = {}
	for name, label in pairs(labels) do
		local newObjects = {}
		for _, data in ipairs(label.objects) do
			if gameInfo[data.bundleid] and not listHasValue(alreadyFoundObjects, data.bundleid)then
				table.insert(newObjects, data)
				table.insert(alreadyFoundObjects, data.bundleid)
			elseif data.bundleid == ".empty" then
				table.insert(newObjects, data)	
			else
				table.insert(newObjects, emptyObject)	
			end
		end	
		labels[name].objects = newObjects
	end
	
	-- make sure every label at this point is visible
	for name, label in pairs(labels) do
		if not listHasValue(labelOrder, name) then
			table.insert(labelOrder, name)
		end
	end
	
	-- sort the labels if this is the first launch
	if firstLaunch then
		alphabetSortLabels()
		alphabetSortLabelContents()
	end
	
	-- uncollapse the current label
	currentLabel = labelOrder[1]
	labels[currentLabel]["collapsed"] = false
	
	for name, label in pairs(labels) do
		fillLabelEndWithEmpty(name, false)
	end
	
	saveConfig()
end


--scratch whatever refactoring you did here broke it so i returned it to previous
function fillLabelEndWithEmpty(label, removeEmptyColumns)
	if #labels[label].objects == 0 then return end
	while #labels[label].objects % labels[label].rows ~= 0 do
		table.insert(labels[label].objects, #labels[label].objects+1, emptyObject)	
	end	
	if removeEmptyColumns then
		local done = false
		while not done do
			done = false
			for i=0, labels[label].rows-1 do
				if i <= #labels[label].objects and #labels[label].objects - i > 0 then
					if labels[label].objects[#labels[label].objects - i].bundleid ~= ".empty" then
						done = true
					end
				end
			end	
			if not done then 
				for i=1, labels[label].rows do
					table.remove(labels[label].objects,#labels[label].objects)	
				end	
			end
		end
	end
	while currentObject > #labels[currentLabel].objects do
		currentObject -= labels[currentLabel].rows
	end
end

function getIcon(bundleID, labelName, imageName)
	if not imageName then
		imageName = "icon"
	end
	
	if iconsCache[bundleID] then
		if iconsCache[bundleID][imageName] then
			return iconsCache[bundleID][imageName]
		else 
			return loadIcon(bundleID, labelName, imageName)
		end
	else
		return loadIcon(bundleID, labelName, imageName)
	end
end

function gameIsFreshlyInstalled(bundleID, set) 
	if set == nil then set = false end
	local gameGroup = nil
	local gameIndex = nil
	for i,v in ipairs(groups) do
		if v.name == gameInfo[bundleID]["group"] then
			gameGroup = i
			for j,v2 in ipairs(v) do
				if v2:getBundleID() == bundleID then
					gameIndex = j
					break
				end
			end
			break
		end
	end	
	if gameGroup and gameIndex and groups[gameGroup][gameIndex] then
		local fresh =  groups[gameGroup][gameIndex]:getInstalledState() == kPDGameStateFreshlyInstalled
		if set == true then groups[gameGroup][gameIndex]:setInstalledState(kPDGameStateInstalled) end
		gameInfo[bundleID].wrapped = groups[gameGroup][gameIndex]:getInstalledState() == kPDGameStateFreshlyInstalled
		return fresh
	end
end

function loadIcon(bundleID, labelName, imageName)
	local rowsNumber = 1
	if labels[labelName] then
		rowsNumber = 6 / labels[labelName].rows
	elseif labelName == "recentlyPlayed" then
		rowsNumber = 1	
	else
		return nil	
	end
	if bundleID == ".empty" then 
		if configVars["drawblanks"] then
			return emptySpaceImgs[rowsNumber] 
		else
			return gfx.image.new(1, 1, gfx.kColorClear)
		end
	end
	
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	
	if not imageName or imageName == "recentlyPlayed" then
		imageName = "icon"
	end
	
	local objectSize = objectSizes[(1/rowsNumber)*6]
	local iconImg = gfx.image.new(objectSize, objectSize, gfx.kColorClear)
	
	if not gameInfo[bundleID] then
		return iconImg
	end
	
	local gameIcon
	local fresh = gameIsFreshlyInstalled(bundleID,false)
	if gameInfo[bundleID].imagepath ~= nil then 
		gameIcon = gfx.image.new(gameInfo[bundleID].path .. "/" .. gameInfo[bundleID].imagepath .. "/" .. imageName) 
	end
	
	if listHasValue(season1, bundleID) and gameIcon == nil then
		gameIcon = gfx.image.new("s1_icons/"..bundleID)
	end
	
	if gameIcon == nil then 
		
		gameIcon = defaultListIcon 
	end
	
	gfx.pushContext(iconImg)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRoundRect(rowsNumber, rowsNumber, objectSize-2*rowsNumber, objectSize-2*rowsNumber, 7*rowsNumber)
	gameIcon:drawScaled(rowsNumber, rowsNumber, rowsNumber)
	if fresh then
		wrappedImgs[(6/labels[labelName].rows)]:draw(rowsNumber,rowsNumber, 1)
	end
	if configVars.iconborders then
		gfx.setColor(invertedColors[configVars.invertborders])
		gfx.setLineWidth(3 * rowsNumber)
		if rowsNumber == 2 then
			gfx.drawRoundRect(3, 3, objectSize - 6, objectSize - 6, 8)
		else
			gfx.drawRoundRect(1, 1, objectSize - 2, objectSize - 2, 4)
		end
	end
	gfx.popContext()
	
	if iconsCache[bundleID] == nil then
		iconsCache[bundleID] = {}
	end
	if labelName ~= "recentlyPlayed" then
		iconsCache[bundleID][imageName] = iconImg
	else
		iconsCache[bundleID]["recentlyPlayed"] = iconImg
	end
	
	return iconImg
end