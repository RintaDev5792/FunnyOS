local FunnyExplorer = {}
local widget = FunnyExplorer
local folderImg = nil
local documentImg = nil
local pdxinfoImg = nil
--able to open PDX, PDA, PDI, PDZ
local extensionImgs = {
	["pdx"] = 0,
	["pdz"] = 0,
	["pda"] = 0,
	["pdi"] = 0,
	["pft"] = 0,
	["pdt"] = 0,
	["pds"] = 0,
	["fosl"] = 0,
	["json"] = 0,
}
local currentPath = "/Shared/FunnyOS2/"
local previousPaths = {}
local currentFiles = {"Test Folder"}
local currentSelection = 1
local scroll = 0
local itemHeight = 33
local loadedAssets = false
local contextMenu = false
local contextMenuSelection = 1
local contextMenuItemHeight = 20
local contextMenuScroll = 0
local copied = false
local copiedPath = ""
local copyProgress = 0
local copySize = 0
local contextMenuItems = {}
local fileAudio = nil
local fileText = nil
local fileImg = nil
local fileScript = nil
local inFileContent = false
local fileContentType = ""
local rename = false
local renameStartText = ""

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
	if contextMenu then 
		widget:closeContextMenu()
	else 
		widgetIsActive = false 
	end
	widget:loadWidgetImage()
end

function widget:AButtonUp()
	local selectedFile = currentFiles[currentSelection]
	if contextMenu then
		widget:performContextMenuAction()
	elseif selectedFile:sub(-1,-1) == "/" then
		widget:enterSelectedFolder()
	else
		widget:openFileContent(selectedFile)
		widget:closeContextMenu()
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
	local w,h = 400-labelSpacing*10+configVars.linewidth, 240-labelSpacing*14+configVars.linewidth
	local oldFont = gfx.getFont(gfx.font.kVariantNormal)
	gfx.setFont(gfx.getLargeUIFont())
	local textWidth, textHeight = gfx.getTextSize("HI")
	gfx.setFont(oldFont)
	local x,y = (200-w/2)//1, (120-h/2)//1
	gfx.fillRoundRect(x,y , w, h, configVars.cornerradius)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(configVars.linewidth)
	gfx.drawRoundRect(x,y+2, w, h-4, configVars.cornerradius)
	gfx.setPattern({170,170,170,170,170,170,170,170})
	local img = gfx.image.new(w-labelSpacing*2,32,gfx.kColorWhite)
	gfx.pushContext(img)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.fillRoundRect(0,0, (w-labelSpacing*2), 32, configVars.cornerradius*100)
	gfx.popContext()
	local mimg = gfx.image.new(w-labelSpacing*2,32,gfx.kColorBlack)
	gfx.pushContext(mimg)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setDitherPattern(0)
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, ((w-labelSpacing*2)*(value/outOfValue))//1, 32)
	gfx.popContext(mimg)
	img:setMaskImage(mimg)
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	img:draw(x+labelSpacing,y+h-labelSpacing-32 )
	gfx.setDitherPattern(0)
	gfx.drawRoundRect(x+labelSpacing,y+h-labelSpacing-32 , w-labelSpacing*2, 32, configVars.cornerradius*100)
	gfx.getLargeUIFont():drawTextAligned(text, 200, y+labelSpacing,kTextAlignment.center)
end

function widget:copyFile(from,to,blockSize)
	if not blockSize then blockSize = 16384 end
	if to:sub(-1,-1) == "/" or from == to then 
		--print("COPYFILE EXIT FOLDER "..from)
		return false
	end	
	--open source file
	local sourceFile = fle.open(from,fle.kFileRead)
	if not sourceFile then 
		--print("SOURCE FILE AT "..from.." FAILED TO OPEN")
		return false
	end
	
	--create the file with no data, erase if data
	
	local destFile = fle.open(to,fle.kFileWrite)
	
	if not destFile then 
		
		--print("DESTINATION FILE AT "..to.." FAILED TO OPEN")
		return false
		
	end
	destFile:close()
	
	--open to append
	destFile = fle.open(to,fle.kFileAppend)
	if not destFile then 
		--print("2ND RUN DESTINATION FILE AT "..to.." FAILED TO OPEN")
		return false
	end
	
	local len = playdate.file.getSize(from)
	local numBlocks = (len/blockSize)//1 + 1
	--print("COPYING FROM "..from.." TO "..to)
	local fileSizeCopied = 0
	for i=1,numBlocks do
		local r, r2 = sourceFile:read(blockSize)
		if r and r2 then
			copyProgress += r2
			fileSizeCopied += r2
			destFile:write(r)
			widget:drawProgress(copyProgress, copySize, "Copying...")
			
			playdate.display.flush()
			coroutine.yield()
		else
			--print("CORRUPTED FILE :3\n\n\n")
			createInfoPopup("Action Failed", "*File "..from.." was unable to copy to "..to..".", function() return false end)
			--return false
		end
		coroutine.yield()
	end
	if destFile then destFile:close() end
	if sourceFile then sourceFile:close() end
	--print("FILE COPY SIZE / FILE SIZE      "..fileSizeCopied, len)
	return true
end

function widget:recreateFileStructure(originalPath, newPath,dontRename,forceOverWrite)
	copyProgress = 0
	copySize = 0
	if not fle.exists(newPath..originalPath:gsub(widget:removeLastFolder(originalPath), "")) then dontRename = true end
	local lastDir = "copy of "..originalPath:gsub(widget:removeLastFolder(originalPath),"")
	if dontRename then lastDir = originalPath:gsub(widget:removeLastFolder(originalPath),"") end
	if originalPath:sub(-1,-1) == "/" and lastDir:sub(-1,-1) ~= "/" then
		lastDir = lastDir.."/"
	end
	local isFolder = lastDir:sub(-1,-1) == "/"
	if not fle.exists(newPath) and isFolder then 
		fle.mkdir(newPath)
	end
	if indexOf(fle.listFiles(newPath, true), lastDir) and not forceOverWrite then 
		createInfoPopup("Action Failed", "*The specified file or folder already exists at the destination.", false)
		widget:closeContextMenu()
		return false
	end
	local fileStructure = {}
	local done = false
	local function returnFolderListAsDict(path)
		local dict = {}
		local listFiles = fle.listFiles(path, true)
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
				if not widget:copyFile(v,path..k) then
					--print("COPYFILE FAILED IN PASTEFS "..path..k.."  "..v)
					return false
				else
					--print("COPYFILE SUCCESS IN PASTEFS")
				end
			end
		end
		return true
	end
	if isFolder then
		if fle.exists(newPath..lastDir) then
			--print("EXISTS, ATTEMPTING DELETION")
			if fle.delete(newPath..lastDir,true) then
				--print("DELETE SUCCESS")
			else
				--print("DELETE FAILED")
			end
		else
			--print("DOES NOT EXIST")
		end
		if fle.exists(newPath..lastDir) then
			--print("DIRECTORY EXISTS")
			return false
		else
			--print("PASTING FS BEGIN")
			fle.mkdir(newPath..lastDir)
			if pasteFileStructure(fileStructure, newPath..lastDir) then
				--print("PASTEFS SUCCESS")
			else
				--print("PASTEFS FAILED")
				return false
			end
		end
	else
		copySize = fle.getSize(originalPath)
		if not widget:copyFile(originalPath, newPath..lastDir) then
			--print("COPY FILE FAILED")
			return false
		else
			--print("COPY FILE SUCCESS")
		end
	end
	if newPath == currentPath then
		table.insert(currentFiles, currentSelection+1, lastDir)
		widget:moveDown()
	end
	widget:loadWidgetImage()
	return true
end

function widget:copy(ogPath,newPath,dontRename,forceOverWrite,finishCallback)
	if widget:recreateFileStructure(ogPath, newPath,dontRename,forceOverWrite) then
		if finishCallback then
			finishCallback()
		end
	else
		createInfoPopup("Action Failed", "*The copy operation returned an error. Please try again. The system will automatically delete the failed copy.",false,function()
			local fname = newPath..ogPath:gsub(widget:removeLastFolder(ogPath), "")
			if fle.exists(fname) then
				--print("FOUND, DELETING")
				if fle.delete(fname,true) then
					--print("DELETE SUCCESS!")
				else
					--print("DELETE RETURNED FAIL")
				end
			else
				
			end
			if fle.exists(fname) then
				--print("DELETE FAIL AFTER COPY FAIL")
				createInfoPopup("Action Failed", "*The system was unable to remove failed copy. Please remove it manually.",false)
			else
				--print("DELETE SUCCESS AFTER COPY FAIL")
			end
		end
		)
	end
	copied = false
	redrawFrame = true
	copyProgress = 0
end

function widget:performContextMenuAction()
	local selected = contextMenuItems[contextMenuSelection]
	if selected == "Delete" then
		createInfoPopup("Confirm Action", "*Please confirm that you would like to delete the item \""..currentFiles[currentSelection].."\".", true, function()
			if fle.delete(currentPath..currentFiles[currentSelection],true) then
				table.remove(currentFiles,currentSelection)
				currentSelection -= 1
				if scroll > 0 then scroll -= 1 end
				widget:closeContextMenu()
			end
		end)
	elseif selected == "Rename" then
		widget:renameItem()
		widget:closeContextMenu()
	elseif selected == "Copy" then
		copiedPath = currentPath..currentFiles[currentSelection]
		copied = true
		widget:closeContextMenu()
	elseif selected == "Install as Launcher" then
		copiedPath = currentPath..currentFiles[currentSelection]
		copied = true
		
		local installToPath = "/System/Launchers/"
		local foslpathpath = copiedPath:gsub(".fosl/",".foslpath"):sub(1,-1)
		if not fle.exists(foslpathpath) then
			foslpathpath = copiedPath:gsub(".fosl/",".foslpath.txt"):sub(1,-1)
		end
		if not fle.exists(foslpathpath) then
			foslpathpath = copiedPath:gsub(".fosl/",".txt.foslpath"):sub(1,-1)
		end
		if not fle.exists(foslpathpath) then
			foslpathpath = copiedPath .. ".foslpath"
		end
		if not fle.exists(foslpathpath) then
			local basename = copiedPath:match("([^/]+)/$")
			foslpathpath = copiedPath .. basename:gsub(".fosl$",".foslpath")
		end
		print("foslpath:", foslpathpath)
		if fle.exists(foslpathpath) then
			print("FOUND")
			local foslpathfile = fle.open(foslpathpath)
			if foslpathfile then
				print("FILE GOT")
				local path = foslpathfile:readline()
				if path then
					print("PATH GOT")
					installToPath = path
				end
			end
		else
			print("NOPE") 
		end
		if not installToPath then
			installToPath = "/System/Launchers/"
		end
		
		-- append "/" if missing
		if installToPath:sub(-1) ~= "/" then
			installToPath = installToPath .. "/"
		end
		
		print(installToPath)
		print(copiedPath)
		
		widget:closeContextMenu()
		playdate.frameTimer.performAfterDelay(1, function() widget:copy(copiedPath,installToPath,true,true,function()
			
				--Update
				if fle.exists(installToPath..currentFiles[currentSelection]) then
					--print("FOUND COPY")
					if fle.exists(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx")) then
						--print("FOUND PRE-EXISTING")
						fle.delete(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx"), true)
						if fle.exists(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx")) then
							--print("PRE EXIST REMAINS")
							fle.delete(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx"),true)
							if fle.exists(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx")) then
								--print("PRE EXIST STILL REMAINS")
								createInfoPopup("Action Failed", "*The old launcher file at that location was unable to be deleted. The installation will not halt, but this file will remain as a hidden file.")
								
								local count = 0
								local fname = "."..tostring(count)..currentFiles[currentSelection]:gsub(".fosl",".pdx")
								local success = true
								while fle.exists(installToPath..fname) do
									count+=1
									fname = "."..tostring(count)..currentFiles[currentSelection]:gsub(".fosl",".pdx")
									if count > 99 then
										success = false
										break
									end
								end
								--print("CREATED FNAME "..fname)
								if not success then
									--print("HELLLLL NO")
									createInfoPopup("Action Failed", "*There are already 99 hidden files with this name. It is recommended to do a fresh system install from a .pdos file after backing up. I am sorry for your wasted hours.",false,function()
									return
									end)
								else
									if fle.rename(installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx"), installToPath..fname) then
										--print("HIDDEN RENAME SUCCESS")
										createInfoPopup("Action Success", "*The file was successfully renamed to a hidden file.")
									else
										--print("HIDDEN RENAME FAILED")
										createInfoPopup("Action Failed", "*There was an error encountered while renaming to a hidden file.",false,function() 
											return
										end)
									end
								end
								
							else
								--print("DELETED PRE-EXISTING")
							end
						else
							--print("DELETED PRE-EXISTING")
						end
					end
					
					--rename fosl to pdx
					--print("/System/Launchers/"..currentFiles[currentSelection])
					--print("/System/Launchers/"..currentFiles[currentSelection]:gsub(".fosl",".pdx"))
					if playdate.file.rename(installToPath..currentFiles[currentSelection],installToPath..currentFiles[currentSelection]:gsub(".fosl",".pdx")) then
						createInfoPopup("Action Success", "*The .fosl installation has finished. The system will now restart in order to properly load the new software.", false, function()
							sys.switchToLauncher()
						end
						)
					else
						createInfoPopup("Action Failed", "*Renaming the .fosl file in /System/Launchers has failed. It is recommended to manually rename it or future updates may fail.")
					end
				else
					createInfoPopup("Action Failed", "*The file "..currentFiles[currentSelection].." was not copied to /System/Launchers/ properly",false)
					return
				end
			end)
		end)	
	elseif selected == "Paste" then
		widget:closeContextMenu()
		playdate.frameTimer.performAfterDelay(1, function() widget:copy(copiedPath,currentPath) end)	
	elseif selected == "New Folder" then
		if fle.mkdir(currentPath.."New Folder") then
			table.insert(currentFiles, currentSelection, "New Folder/")
			widget:renameItem()
			widget:closeContextMenu()
		end
	elseif selected == "Open" then
		local selectedFile = currentFiles[currentSelection]
		widget:openFileContent(selectedFile)
		widget:closeContextMenu()
	end
end

function widget:openContextMenu()
	contextMenuSelection = 1
	contextMenuScroll = 0
	local selectedFile = currentFiles[currentSelection]
	if selectedFile ~= "../" then
		local suffix = selectedFile:sub(#selectedFile-5,#selectedFile)
		while suffix:sub(1,1) ~= "." and #suffix > 1 do
			suffix = suffix:sub(2,#suffix)
			if #suffix < 2 then break end
		end
		if suffix == ".pda" or suffix == ".pdi" or suffix == ".pdx/" or suffix == ".pdz" or selectedFile == "pdxinfo" or suffix:sub(1,1) == "/" then
			contextMenuItems = {
			"Open",
			"Copy",
			"Paste",
			"Rename",
			"New Folder",
			"Delete",
			}
			
		elseif suffix == ".fosl/" then
			contextMenuItems = {
			"Install as Launcher",
			"Copy",
			"Paste",
			"Rename",
			"New Folder",
			"Delete",
			}
		else
			contextMenuItems = {
			"Copy",
			"Paste",
			"Rename",
			"New Folder",
			"Delete",
			}
		end
	else
		contextMenuItems = {
			"Paste",
			"New Folder"
		}
	end
	contextMenu = true
	widget:loadWidgetImage()
end

function widget:closeContextMenu()
	contextMenuSelection = 1
	contextMenuScroll = 0
	contextMenu = false
	widget:loadWidgetImage()
end

function widget:rightButtonUp()
	if rename then
		widget:removeScrollTimer()
		return	
	end
	
	if contextMenu then	
		widget:performContextMenuAction()
	else		
		widget:openContextMenu()
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
		currentFiles = fle.listFiles(currentPath, true)
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
	if fileText then fileText = nil end
	widget:loadWidgetImage()
end

function widget:openFileContent(selectedFile)
	
	inFileContent = true
	
	local suffix = selectedFile:sub(#selectedFile-4,#selectedFile)
	if suffix:sub(1,1) ~= "." then
		suffix = suffix:sub(2,#suffix)
	end
	fileContentType = suffix
	if selectedFile == "pdxinfo" then fileContentType = "pdxinfo" end
	
	if suffix == ".pdx/" then
		sys.switchToGame(currentPath..selectedFile)
	elseif suffix == ".pdi" then
		if fileImg then fileImg = nil end
		fileImg = gfx.image.new(currentPath..selectedFile)
		if fileImg then
			
		else
			createInfoPopup("Action Failed", "*The Playdate Image File "..selectedFile.." was unable to be displayed.", false)
		end
	elseif selectedFile == "pdxinfo" then
		if fileText then fileText = nil end
		file = fle.open(currentPath..selectedFile)
		fileText = file:read(65536)
		file:close()
		if fileText then
			
		else
			createInfoPopup("Action Failed", "*The Playdate Package Info File "..selectedFile.." was unable to be displayed.", false)
		end
	elseif suffix == ".pdz" then
		if fileScript then fileScript = nil end
		local success, fileScript = pcall(function()
			return playdate.file.run(currentPath..selectedFile)
		end)
		if fileScript then
			if fileScript.init then
				fileScript:init()
			else
				fileScript = nil
				createInfoPopup("Action Failed", "*The Playdate Compiled Script File "..selectedFile.." was unable to be run.", false)
			end
		else
			createInfoPopup("Action Failed", "*The Playdate Compiled Script File "..selectedFile.." was unable to be run.", false)
		end
	elseif suffix == ".pda" then
		if fileAudio then fileAudio:stop(); fileAudio = nil end
		fileAudio = playdate.sound.fileplayer.new(currentPath..selectedFile)
		if fileAudio then
			if music then
				music:pause()
			end
			fileAudio:setFinishCallback(function()
				if music then
					music:play()
				end
				widget:closeFileContent()
			end
			)
			fileAudio:play()
		else
			createInfoPopup("Action Failed", "*The Playdate Audio File "..selectedFile.." was unable to be played.", false)
		end
	elseif selectedFile:sub(-1,-1) == "/" then
		widget:enterSelectedFolder()
		inFileContent = false
	else
		inFileContent = false
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
	if contextMenu then
		widget:closeContextMenu()
	else
		widget:returnToPreviousFolder()
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
	if inFileContent then return end
	if rename then
		widget:removeScrollTimer()
		return	
	end
	if contextMenu then
		contextMenuSelection=math.max(contextMenuSelection-1,1)
		if contextMenuSelection < contextMenuScroll+1 then
			contextMenuScroll=contextMenuScroll-1
		end	
	else
		currentSelection=math.max(currentSelection-1,1)
		if currentSelection < scroll+1 then
			scroll=scroll-1
		end	
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
	if inFileContent then return end
	if rename then
		widget:removeScrollTimer()
		return	
	end
	if contextMenu then
		contextMenuSelection=math.min(contextMenuSelection+1,#contextMenuItems)
		if contextMenuSelection > (200/contextMenuItemHeight)+contextMenuScroll-2 then
			contextMenuScroll=contextMenuScroll+1
		end
	
	else
		currentSelection=math.min(currentSelection+1,#currentFiles)
		if currentSelection > (200/itemHeight)+scroll-2 then
			scroll=scroll+1
		end
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
		if v:sub(#v-4,#v) == ".pdx/" then
			extensionImgs["pdx"]:draw(x,y)
		elseif v:sub(#v-5,#v) == ".fosl/" then
			extensionImgs["fosl"]:draw(x,y)
		else
			folderImg:draw(x,y)
		end
	else
		if v == "pdxinfo" then
			pdxinfoImg:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pda" then
			extensionImgs["pda"]:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pdi" then
			extensionImgs["pdi"]:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pds" then
			extensionImgs["pds"]:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pdz" then
			extensionImgs["pdz"]:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pdt" then
			extensionImgs["pdt"]:draw(x,y+1)
		elseif v:sub(#v-3,#v) == ".pft" then
			extensionImgs["pft"]:draw(x,y+1)
		elseif v:sub(#v-4,#v) == ".json" then
			extensionImgs["json"]:draw(x,y+1)
		else
			documentImg:draw(x,y+1)
		end
	end
end

function widget:drawBottomBar()
	if widgetIsActive then
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(0, 200-24, 200, 24)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
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
			
			if fileContentType == ".pda" then
				extensionImgs["pda"]:drawScaled(53, 26, 3)
				gfx.drawTextInRect("*"..currentFiles[currentSelection], 10, 134, 180,20,nil,"...",kTextAlignment.center)
			elseif fileContentType == ".pdi" then
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.setColor(gfx.kColorBlack)
				gfx.setDitherPattern(0.5)
				gfx.fillRect(0, 0, 200, 200)
				local w,h = fileImg:getSize()
				local wRatio,hRatio = w/200, h/175
				local ratio = math.max(wRatio,hRatio)
				local scaleFactor = (1/ratio)
				fileImg:drawScaled(100 - w*scaleFactor/2,100 - h*scaleFactor/2 - 11,scaleFactor)
			elseif fileContentType == "pdxinfo" then
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.drawTextInRect("*"..fileText, 10, 10,180,165)
				
			elseif fileContentType == ".pdz" then
				extensionImgs["pdz"]:drawScaled(53, 26, 3)
				gfx.drawTextInRect("*"..currentFiles[currentSelection], 10, 134, 180,20,nil,"...",kTextAlignment.center)
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
			gfx.drawTextAligned("*File Explorer*",100, 7,kTextAlignment.center)
		end
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		
		widget:drawBottomBar()
		
		if contextMenu then
			local addSpacing = ((configVars.linewidth/2)//1)
			local w = 200-labelSpacing*2
			local h = 200-24-7-14-labelSpacing*2 + 1
			local contextMenuImg = gfx.image.new(w+addSpacing*2,h+addSpacing*2,gfx.kColorClear)
			local contextMenuMaskImg = gfx.image.new(w+addSpacing*2,h+addSpacing*2,gfx.kColorBlack)
			
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.setLineWidth(configVars.linewidth)
			
			gfx.pushContext(contextMenuMaskImg)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.setColor(gfx.kColorWhite)
				gfx.fillRoundRect(0, 0, w+addSpacing*2, h+addSpacing*2, configVars.cornerradius)
			gfx.popContext()
			
			gfx.pushContext(contextMenuImg)
				gfx.setLineWidth(configVars.linewidth)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.setColor(gfx.kColorWhite)
				gfx.fillRoundRect(addSpacing, addSpacing, w, h, configVars.cornerradius)
				gfx.setColor(gfx.kColorBlack)
				gfx.drawRoundRect(addSpacing, addSpacing, w, h, configVars.cornerradius)
				for i,v in ipairs(contextMenuItems) do
					gfx.setImageDrawMode(gfx.kDrawModeCopy)
					local y = (i-1)*contextMenuItemHeight - contextMenuScroll*contextMenuItemHeight + addSpacing + 8
					if i == contextMenuSelection and widgetIsActive then
						gfx.fillRect(addSpacing, y, w, contextMenuItemHeight)
						gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
					end
					if y > 0 and y < 200 then
						local drawText = v
						drawText = drawText:gsub("_","__")
						drawText = drawText:gsub("*","**")
						gfx.drawText("*"..drawText,addSpacing+labelSpacing,y+2)
					end
					gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
				end
			gfx.popContext()
			contextMenuImg:setMaskImage(contextMenuMaskImg)
			contextMenuImg:draw(labelSpacing - addSpacing,labelSpacing+22 - addSpacing - 1)
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
		pdxinfoImg = gfx.image.new(widget.metadata.path.."pdxinfo")	
		for k,v in pairs(extensionImgs) do
			extensionImgs[k] = gfx.image.new(widget.metadata.path..k)
		end
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
	widget:goToFolder("/Shared/FunnyOS2/")
	widget:getWidgetImage()
	loadedAssets = false
end

return widget