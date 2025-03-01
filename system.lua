import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("utils")

defaultListIcon = playdate.graphics.image.new("images/list_icon_default")
gameInfo, groups, sortedGameInfo = nil, nil, nil

season1 = {"com.a-m.beats-bleeps-boogie","com.crookedpark.demonquest85","com.dadako.questychess","com.davemakes.execgolf","com.gregorykogos.omaze","com.nelsanderson.forrest","com.NicMagnier.PickPackPup","com.panic.b360","com.panic.inventoryhero","com.panic.starsled", "com.radstronomical.CasualBirder","com.samanthazero.echoicmemory","com.serenityforge.elevator","com.shauninman.ratcheteer","com.spectrecollie.sasquatchers","com.sweetbabyinc.lostyourmarbles","com.teambottle.spellcorked","com.tpmcosoft.battleship","com.uvula.crankin","com.vertexpop.hypermeteor","com.vitei.whitewater","com.wildrose.saturday","net.foddy.zipper","net.stfj.snak",}

function setupGameInfo()
	sys.updateGameList()
	gameInfo = {}
	groups = sys.getInstalledGameList()
	for i,v in ipairs(groups) do
		for j,v2 in ipairs(v) do
			if gme.getPath(v2) then
				local gamePath = gme.getPath(v2)
				if gme.getBundleID(v2) then
					local props = playdate.system.getMetadata(gamePath .. "/pdxinfo")
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
					gameInfo[gme.getBundleID(v2)] = props
				end
			else
				return false
			end
		end
	end
	sortedGameInfo = {}
	for k,v in pairs(gameInfo) do
		if not sortedGameInfo[v["group"]] then sortedGameInfo[v["group"]] = {} end
		sortedGameInfo[v["group"]][k] = v
	end
	for k,v in pairs(sortedGameInfo) do
		for bundleID, objectData in pairs(sortedGameInfo[k]) do
			local found = false
			for label,data in pairs(labels) do
				for i,object in ipairs(labels[label].objects) do
					if object.bundleid == bundleID and bundleID ~= ".empty" then
						found = true	
					end
				end
			end
			if not found and bundleID ~= "com.panic.launcher" and bundleID ~= "com.shauninman.InputTest" and bundleID ~= "com.panic.setup" and bundleID ~= "com.panic.setupintro" then 
				local foundEmpty = false
				local index = nil				
				if not labels[k] then labels[k] = {["displayName"] = k, ["rows"] = 3, ["objects"] = {}, ["collapsed"] = false} end

				for i, data in ipairs(labels[k].objects) do
					if data.bundleid == ".empty" and not foundEmpty then
						index = i
					end	
				end
				if index then
					labels[k].objects[index] = objectData
				else
					table.insert(labels[k].objects,objectData) 
				end
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
			if gameInfo[data.bundleid] and not listHasValue(alreadyFoundObjects, data.bundleid)then
				table.insert(newObjects, data)
				table.insert(alreadyFoundObjects, data.bundleid)
			elseif data.bundleid == ".empty" then
				table.insert(newObjects, data)	
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
	return true
end

function alphabetSortLabels()
	table.sort(labelOrder)
end

function alphabetSortLabelContents()
	for k,v in pairs(labels) do
		local objectNames = {}
		for i,objectData in ipairs(v["objects"]) do
			table.insert(objectNames, objectData["name"])	
		end	
		
		table.sort(objectNames)
		
		local newObjects = {}
		for i,name in ipairs(objectNames) do
			for j, objectData in ipairs(v["objects"]) do
				if objectData["name"] == name then
					table.insert(newObjects, objectData)	
					break
				end	
			end
		end
		v["objects"] = newObjects
	end
end

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
	if not imageName then imageName = "icon" end
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

function loadIcon(bundleID, labelName,imageName)
	local rowsNumber = 6/labels[labelName].rows
	if bundleID == ".empty" then 
		if configVars["drawblanks"] then
			return emptySpaceImgs[rowsNumber] 
		else return gfx.image.new(1,1,gfx.kColorClear) end
	end
	
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	if not imageName then imageName = "icon" end
	local objectSize = objectSizes[labels[labelName].rows]
	local iconImg = gfx.image.new(objectSize,objectSize,gfx.kColorClear)
	gfx.lockFocus(iconImg)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(rowsNumber, rowsNumber, objectSize-3*rowsNumber, objectSize-3*rowsNumber)
	if not gameInfo[bundleID] then  
		return iconImg
	end
	local gameIcon = nil
	if gameInfo[bundleID].imagepath ~= nil then 
		gameIcon = gfx.image.new(gameInfo[bundleID].path .."/"..gameInfo[bundleID].imagepath.."/"..imageName) 
	end
	if listHasValue(season1, bundleID) and gameIcon == nil then
		gameIcon = gfx.image.new("s1_icons/"..bundleID)
	end
	if gameIcon == nil then 
		gameIcon = defaultListIcon 
	end
	gameIcon:drawScaled(rowsNumber,rowsNumber,rowsNumber)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2*rowsNumber)
	gfx.drawRoundRect(rowsNumber, rowsNumber, objectSize-2*rowsNumber, objectSize-2*rowsNumber, 4*rowsNumber)
	gfx.unlockFocus()
	if iconsCache[bundleID] == nil then iconsCache[bundleID] = {} end
	iconsCache[bundleID][imageName] = iconImg
	return iconImg
end