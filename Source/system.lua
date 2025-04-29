import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("utils")
import("unzip")
import("reap")

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

local reaping = false
local reaper = nil

local kPDGameStateFreshlyInstalled, kPDGameStateInstalled
if playdate.system ~= nil then
	kPDGameStateFreshlyInstalled = playdate.system.game.kPDGameStateFreshlyInstalled
	kPDGameStateInstalled = playdate.system.game.kPDGameStateInstalled
end

function reapPackage(zipPath,destinationPath)
	playdate.inputHandlers.push(blockInputHandler)
	if destinationPath then fle.mkdir(destinationPath) end
	if not fle.exists(zipPath) then createInfoPopup("Action Failed", "*Invalid file path, please try again.", false); return end
	reaper = Reap(zipPath,destinationPath)
	reaping = true
end

local function drawReapProgress()
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
	local img = gfx.image.new(w-labelSpacing*2,32,gfx.kColorWhite)
	gfx.pushContext(img)
	gfx.fillRoundRect(0,0, (w-labelSpacing*2), 32, configVars.cornerradius*100)
	gfx.popContext()
	local mimg = gfx.image.new(w-labelSpacing*2,32,gfx.kColorBlack)
	gfx.pushContext(mimg)
	gfx.setDitherPattern(0)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, ((w-labelSpacing*2)*reaper:getPercentComplete()/100)//1, 32)
	gfx.popContext(mimg)
	img:setMaskImage(mimg)
	img:draw(x+labelSpacing,y+h-labelSpacing-32 )
	gfx.setDitherPattern(0)
	gfx.drawRoundRect(x+labelSpacing,y+h-labelSpacing-32 , w-labelSpacing*2, 32, configVars.cornerradius*100)
	gfx.getLargeUIFont():drawTextAligned("Installing...", 200, y+labelSpacing,kTextAlignment.center)
end

function updateReap()
	if reaping and reaper then
		local done, err = reaper:update()
		drawReapProgress()
		print(err)
		if err then 
			reaper = nil
			reaping = false
			createInfoPopup("Action Failed", "*An error was encountered while unzipping. Please verify the integrity of your files.\n\nError: "..tostring(err), false)
			playdate.inputHandlers.pop()
			return
		end
		if done then
			reaper = nil
			reaping = false
			playdate.inputHandlers.pop()
		createInfoPopup("Action Succeeded", "*The package has been successfully installed and the system will now restart the launcher.", false, function()
				sys.switchToLauncher()
			end
			)
		end
	end	
end

function installPackage(zipPath,destinationPath)
	if unzip(zipPath,destinationPath) then
		createInfoPopup("Action Succeeded", "*The package has been successfully installed and the system will now restart the launcher.", false, function()
			sys.switchToLauncher()
		end
		)
	else
		createInfoPopup("Action Failed", "*An error was encountered while unzipping. Please verify the integrity of your files.", false)
		printTable(sys)
		
	end
end

function openApp(bundleId)
	if bundleId and gameInfo[bundleId] then
		if gameInfo[bundleId].path then
			playdate.system.switchToGame(gameInfo[bundleId].path)
			return
		end
	end
	sound04DenialTrimmed:play()
	createInfoPopup("Action Failed", "*The game or app could not be launched. It may have been moved or deleted.*", false)
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
				
				if success and widget and widget.metadata and widget.update and widget.getWidgetImage and widget.loadWidgetImage then
					widget.metadata.path = folderPath
					table.insert(widgets, widget)
				end
			end
		end
	end

	if #widgets > 0 then
		selectedWidget = 1
		-- Generate initial cached images for all widgets
		for _, widget in ipairs(widgets) do
			widget:init()
		end
	end
	alphabetSortWidgets()
end

function getGameObject(bundleID) 
	if not gameInfo[bundleID] then return nil end
	for i,v in ipairs(groups) do
		if v.name == gameInfo[bundleID].group then
			for j, w in ipairs(v) do
				if betterGetBundleID(w) == bundleID then return w end	
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
	if not gameInfo[bundleID] then return end
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
					openApp(labels[currentLabel].objects[currentObject].bundleid)
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
				local cwpassed = w:getSuppressContentWarning()
				if not gameInfo[betterGetBundleID(w)].contentwarning then cwpassed = true end
				if w:getInstalledState() == kPDGameStateInstalled and cwpassed then
					table.insert(possibleGames, w)
				end
			end	
		end	
	end
	local game = possibleGames[math.random(1, #possibleGames)]
	openApp(betterGetBundleID(game))
end

function loadBadges()
	badges = {}
	if fle.isdir(savePath.."Badges") then
		local files = fle.listFiles(savePath.."Badges")
		for i,v in ipairs(files) do
			if v:sub(#v-3,#v) == ".pdi" then
				table.insert(badges, ".badge:"..v:sub(1,#v-4))
			end
		end
	end
	table.sort(badges)
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

function betterGetBundleID(game)
	if not game then return nil end
	if game:getBundleID() then return game:getBundleID() end
	local path
	if not game:getPath() then return nil else path = game:getPath().."/pdxinfo" end
	local file = fle.open(path)
	if not file then return nil end
	local line = file:readline()
	while line ~= nil and line:sub(1,8) ~= "bundleID" do 
		line = file:readline()
	end
	if not line then return nil end
	local index = nil
	for i=1,#line do
		local char = line:sub(i,i)
		if i > 8 and char ~= " " and char ~= "=" then
			index=i; break
		end
	end
	if not index then return nil end
	return line:sub(index,#line)
end

function setupGameInfo()
	sys.updateGameList()
	gameInfo = {}
	groups = sys.getInstalledGameList()
	for i,v in ipairs(groups) do
		for j,v2 in ipairs(v) do
			if gme.getPath(v2) then
				local gamePath = gme.getPath(v2)
				local props = playdate.system.getMetadata(gamePath .. "/pdxinfo")
				local bid = betterGetBundleID(v2)
				if bid then
					
					local newprops = {}
					for k,v in pairs(props) do
						newprops[string.lower(k)] = v
					end
					props = newprops
					props["path"] = gme.getPath(v2)
					if props["imagepath"] and props["path"] then
						if props["imagepath"]:sub(#props["imagepath"]-3,#props["imagepath"]) == ".png" or fle.exists(props["path"] .."/"..props["imagepath"]..".pdi") then
							local imgp = ""
							local str = props["imagepath"]
							for i = 1, #str do
								local c = str:sub(i,i)
								if c ~= "/" then
									imgp = imgp..c
								else
									break
								end
							end
							if imgp == props["imagepath"] then
								imgp = ""
							end
							props["imagepath"] = imgp
						end
					end

					props["group"] = v.name
					props["suppresscontentwarning"] = v2:getSuppressContentWarning()
					props["bundleid"] = bid
					gameInfo[bid] = props
				end
			else
				return false
			end
		end
	end
	
	
	-- add badges here
	for i,bundleID in ipairs(badges) do
		-- found is "if an object has been found in label"
		local found = false
		-- if an object is in a label, it is "found"
		for label,data in pairs(labels) do
			for i,object in ipairs(labels[label].objects) do
				if object.bundleid == bundleID and bundleID ~= ".empty" then
					found = true	
					break
				end
			end
		end
		-- if the game isn't in your launcher and isnt a system app
		if not found and bundleID ~= "com.panic.launcher" and bundleID ~= "com.shauninman.InputTest" and bundleID ~= "com.panic.setup" and bundleID ~= "com.panic.setupintro" then 
			-- look for an empty space to place it
			local badgeObject = listCopy(emptyObject)
			badgeObject.bundleid = bundleID
			placeObjectAtEmpty(badgeObject, "Badges")
		end
	end
	
	
	sortedGameInfo = {}
	-- if a group doesn't exist in sortedgameinfo, create it with gameinfo
	for k,v in pairs(gameInfo) do
		if not sortedGameInfo[v["group"]] then sortedGameInfo[v["group"]] = {} end
		sortedGameInfo[v["group"]][k] = v
	end
	for k,v in pairs(sortedGameInfo) do
		-- for each game
		for bundleID, objectData in pairs(sortedGameInfo[k]) do
			-- found is "if an object has been found"
			local found = false
			-- if an object is in a label, it is "found"
			for label,data in pairs(labels) do
				for i,object in ipairs(labels[label].objects) do
					if object.bundleid == bundleID and bundleID ~= ".empty" then
						found = true	
					end
				end
			end
			-- if the game isn't in your launcher and isnt a system app
			if not found and bundleID ~= "com.panic.launcher" and bundleID ~= "com.shauninman.InputTest" and bundleID ~= "com.panic.setup" and bundleID ~= "com.panic.setupintro" then 
				-- look for an empty space to place it
				placeObjectAtEmpty(objectData, k)
			end
		end
	end
	
	for k,v in pairs(labels) do
		if v.objects == {} then
			labels[k] = nil	
		end	
	end
	local newLabelOrder = {}
	for i,v in ipairs(labelOrder) do
		if labels[v] then
			table.insert(newLabelOrder, v)	
		end	
	end
	labelOrder = newLabelOrder
	local alreadyFoundObjects = {}
	for k,v in pairs(labels) do
		local newObjects = {}
		for i,data in ipairs(v.objects) do
			if (gameInfo[data.bundleid] or bundleIDIsBadge(data.bundleid)) and not listHasValue(alreadyFoundObjects, data.bundleid)then
				table.insert(newObjects, data)
				table.insert(alreadyFoundObjects, data.bundleid)
			else
				table.insert(newObjects, emptyObject)
			end
		end	
		labels[k].objects = newObjects
	end
	for k,v in pairs(labels) do
		if not listHasValue(labelOrder, k) then
			table.insert(labelOrder, k)
		end
	end
	
	if firstLaunch then
		alphabetSortLabels()
		alphabetSortLabelContents()
	end
	currentLabel = labelOrder[1]
	labels[currentLabel]["collapsed"] = false
	for k,v in pairs(labels) do
		fillLabelEndWithEmpty(k, false)	
	end
	saveConfig()
end

function placeObjectAtEmpty(objectData, label)
	local index = nil				
	if labels[label] == nil then labels[label] = {["displayName"] = label, ["rows"] = 3, ["objects"] = {}, ["collapsed"] = false} end

	for i, data in ipairs(labels[label].objects) do
		if data.bundleid == ".empty" then
			index = i
			break
		end
	end
-- if there's an empty space, put it there, otherwise put it at the end.
	if index then
		labels[label].objects[index] = objectData
	else
		table.insert(labels[label].objects,objectData) 
	end	
end

function getBadgeName(bundleID)
	return bundleID:sub(8,#bundleID)	
end

function bundleIDIsBadge(bundleID)
	return bundleID:sub(1,7) == ".badge:"
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
				if betterGetBundleID(v2) == bundleID then
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
	if iconsCache[bundleID] == nil then
		iconsCache[bundleID] = {}
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
	local objectSpacing = objectSpacings[(1/rowsNumber)*6]
	local iconImg = gfx.image.new(objectSize, objectSize, gfx.kColorClear)
	
	if not gameInfo[bundleID] then
		if bundleIDIsBadge(bundleID) then
			local badgeIcon = gfx.image.new(savePath.."Badges/"..getBadgeName(bundleID))
			if badgeIcon then
				local w,h = badgeIcon:getSize()
				badgeIcon = badgeIcon:scaledImage((objectSize+objectSpacing)/w)
				iconsCache[bundleID][imageName] = badgeIcon
				return badgeIcon
			else
				iconsCache[bundleID][imageName] = iconImg
				return iconImg	
			end
		else
			iconsCache[bundleID][imageName] = iconImg
			return iconImg
		end
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
	if labelName ~= "recentlyPlayed" then
		iconsCache[bundleID][imageName] = iconImg
	else
		iconsCache[bundleID]["recentlyPlayed"] = iconImg
	end
	
	return iconImg
end