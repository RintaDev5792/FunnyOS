local VERSION = 1

packageInstaller = {}

local MODE_PROMPT_REFRESH = 0
local MODE_LOADING = 1
local MODE_SHOW_MESSAGE = 2
local MODE_LISTING = 3

local PACKAGE_ROOT = "/RintaDev5792/FunnyOS/refs/heads/main/Assets/Packages"
if fos and fos.getenv then
	PACKAGE_ROOT = fos.getenv("FOS_PACKAGE_ROOT") or PACKAGE_ROOT
end
print("Using package root: ", PACKAGE_ROOT)
local PACKAGE_FILE = joinPaths(PACKAGE_ROOT, "packages.json")
local PACKAGE_HOST = "raw.githubusercontent.com"

packageInstaller = {}
packageInstaller.image = nil
packageInstaller.package_hierarchy = nil
packageInstaller.mode = MODE_PROMPT_REFRESH
packageInstaller.mode_previous = packageInstaller.mode
packageInstaller.t = 0
packageInstaller.scroll = 0
packageInstaller.httplink = {}
packageInstaller.metadata = {
    name="Package Installer",
    path="images/package-installer/",
}

local itemHeight = 33
local top = 35
local folderImg = nil
local pgkImg = nil
local loadImg = nil
local load2Img = nil
local errImg = nil
local scroll_items = 5
local bottom = top + itemHeight*scroll_items
local scroll_offset = scroll_items/2
local savePath = "/Shared/FunnyOS2/Download/"

local maxLinkLoading = 3

function packageInstaller:isActive()
    return cursorState == cursorStates.CONTROL_CENTER_PACKAGE_INSTALLER
end

function packageInstaller:getLinkLoadIndex()
	for i=1,maxLinkLoading do
		if not packageInstaller.httplink[i] then
			return i
		end
	end
	return nil
end

local function loadAssets()
	if not folderImg then
		folderImg = gfx.image.new(packageInstaller.metadata.path.."fol")
		pkgImg = gfx.image.new(packageInstaller.metadata.path.."pkg")
		errImg = gfx.image.new(packageInstaller.metadata.path.."err")
		loadImg = gfx.image.new(packageInstaller.metadata.path.."load")
		load2Img = gfx.image.new(packageInstaller.metadata.path.."load2")
	end
end

local function splitURLMaybeRelative(url, rel_scheme, rel_host, rel_root)
	local scheme, host, path
	if url:sub(1, 1) == '.' then
		scheme = rel_scheme or "https"
		host = rel_host or PACKAGE_HOST
		path = getCanonicalPath((rel_root or PACKAGE_ROOT) .. "/" .. url)
	else
		scheme, host, path = splitUrl(url)
	end
	return scheme, host, path
end

local function downloadAndInstall(url, installpaths, rel_scheme, rel_host, rel_root)
	local scheme, host, path = splitURLMaybeRelative(url, rel_scheme, rel_host, rel_root)
	if not scheme or not host or not path then
		createInfoPopup("Download Failed", "*Failed to parse URL:\n" .. url, nil)
		return
	end
	
	local fname = getBasename(path)
	print(scheme, host, path, fname)
	playdate.file.mkdir(savePath)
	
	fname = savePath .. fname
	local file, file_error = fos.file_open_write(fname)
	
	local use_ssl = true
	if scheme == "http" then
		use_ssl = false
	elseif scheme == "https" then
		use_ssl = true
	else
		createInfoPopup("Download Failed", "*Unrecognized URL scheme \"" .. scheme .. "\"", nil)
		return
	end
	
	packageInstaller.mode = MODE_LOADING
	packageInstaller.http = playdate.network.http.new(host, 0, use_ssl, "to download a package")
	if not packageInstaller.http then
		packageInstaller.mode_previous = MODE_LISTING
		packageInstaller.mode = MODE_SHOW_MESSAGE
		packageInstaller.message = "Failed to open\n" .. scheme .. " connection"
		return
	end

	if not file then
		createInfoPopup(
			"Download Failed", "*Could not open file for writing:\n" .. tostring(file_error),
		nil)
		return
	end
	
	local http = packageInstaller.http
	http:setConnectTimeout(40)
	local function read_bytes()
		if not packageInstaller.http then return end
		while http:getBytesAvailable() > 0 do
			print("bytes available: ", http:getBytesAvailable())
			local s = http:read(1024)
			if #s == 0 then
				print("0 bytes read")
				packageInstaller.http = nil
				packageInstaller.mode_previous = MODE_LISTING
				packageInstaller.mode = MODE_SHOW_MESSAGE
				packageInstaller.message = "0 bytes read."
				file:close()
			elseif file:write(s) < 0 then
				print("Failed to write to file")
				packageInstaller.http = nil
				packageInstaller.mode_previous = MODE_LISTING
				packageInstaller.mode = MODE_SHOW_MESSAGE
				packageInstaller.message = "Failed to write\nto file."
				file:close()
			else
				file:flush()
			end
		end
	end
	http:setRequestCompleteCallback(
		function()
			if packageInstaller.http then
				read_bytes()
				packageInstaller.http = nil
				file:close()
				
				-- at this point, we are now on to installing/unzipping the file
				installPackage(fname, installpaths)
				playdate.file.delete(fname)
				packageInstaller.mode = MODE_LISTING
			else
				print("Err: ", http:getError())
			end
		end
	)
	http:setConnectionClosedCallback(
		function()
			if packageInstaller.http then
				packageInstaller.http = nil
				file:close()
				packageInstaller.mode = MODE_SHOW_MESSAGE
				packageInstaller.mode_previous = MODE_LISTING
				packageInstaller.message = "Download Failed."
			end
		end
	)
	http:setRequestCallback(read_bytes)
	http:setHeadersReadCallback(function()
		local status = http:getResponseStatus()
		print("status: ", status)
		if packageInstaller.http and status ~= 200 and status ~= 0 then
			packageInstaller.http = nil
			packageInstaller.mode = MODE_LISTING
			file:close()
			createInfoPopup("Connection Failed", "*HTTP Status: " .. tostring(status), nil)
		end
	end)
	print("GET " .. scheme .. "://" .. host .. path)
	http:get(path)
end

function packageInstaller:upOneLevel()
	packageInstaller.selected = packageInstaller.path[#packageInstaller.path]
	packageInstaller.path[#packageInstaller.path] = nil
	packageInstaller.scroll = packageInstaller.selected - scroll_offset
end

-- If a B button function isn't provided, this is the default action for it.
function packageInstaller:BButtonUp()
	if packageInstaller.mode == MODE_LISTING and #packageInstaller.path > 0 then
		packageInstaller:upOneLevel()
		return
	end
	-- Removes focus from the packageInstaller so others can be selected
	-- Need this line somewhere if you use the B button.
	packageInstaller:loadImage()
    changeCursorState(cursorStates.CONTROL_CENTER_MENU)
end

local function get_package_list()
	local http = packageInstaller.http
    print("getting package list...")
	http:setConnectTimeout(30)
	http:setRequestCompleteCallback(
        function()
            print("A-", http, packageInstaller.http)
			local data = ""
			while true do
				local d = http:read()
				if not d or #d == 0 then
					break
				end
				data = data .. d
			end
			if data and packageInstaller.http then
                print("DATA RECEIVED: ", data)
				packageInstaller.http = nil
				packageInstaller.db = json.decode(data)
				if packageInstaller.db then
					if packageInstaller.db.version == VERSION then
						packageInstaller.path = {}
						packageInstaller.http = nil
						packageInstaller.mode = MODE_LISTING
						packageInstaller.scroll = 0
						packageInstaller.selected = 1
					else
						packageInstaller.mode = MODE_SHOW_MESSAGE
						packageInstaller.message = "Package database\nversion mismatch.\nPlease update manually."
						packageInstaller.t = 0
					end
				else
					packageInstaller.t = 0
					packageInstaller.mode = MODE_SHOW_MESSAGE
					packageInstaller.message = "Invalid package\ndatabase received"
				end
			else
				print("Err: ", http:getError())
			end
		end
	)
	http:setConnectionClosedCallback(
		function()
			print("B")
			if packageInstaller.http then
				packageInstaller.http = nil
				packageInstaller.mode = MODE_PROMPT_REFRESH
			end
		end
	)
	http:setRequestCallback(function()
		print("C")
	end)
	http:setHeadersReadCallback(function()
		print("D")
		local status = http:getResponseStatus()
		if packageInstaller.http and status ~= 200 and status ~= 0 then
			packageInstaller.http = nil
			packageInstaller.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Connection Failed", "*HTTP Status: " .. tostring(status), nil)
		end
	end)
	
	local pf = PACKAGE_FILE .. "?nocache=" .. tostring(math.floor(math.random(0, 10000)))
	print("GET", pf)
	http:get(pf)
end

local function get_package_list_prepare()
	playdate.network.setEnabled(true, function(err)
		if err then 
			packageInstaller.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Failed to Enable Networking", "*" .. err, nil)
		else
			--[[
			local status = playdate.network.getStatus()
			if status == playdate.network.kStatusNotConnected then
				packageInstaller.message = "Network Not Connected"
				packageInstaller.mode = MODE_SHOW_MESSAGE
				packageInstaller.t = 0
				return
			elseif playdate.network.kStatusNotAvailable then
				packageInstaller.message = "Network Not Available"
				packageInstaller.mode = MODE_SHOW_MESSAGE
				packageInstaller.t = 0
				return
			end
			]]
			
			if not packageInstaller.http then
				packageInstaller.http = playdate.network.http.new(PACKAGE_HOST, 0, true, "to list downloadable packages")
				if not packageInstaller.http then
					packageInstaller.mode = MODE_PROMPT_REFRESH
				else
					get_package_list()
				end
			end
		end
	end)
end

function packageInstaller:AButtonUp()
	if packageInstaller.mode == MODE_SHOW_MESSAGE and packageInstaller.t > 15 then
		packageInstaller.mode = packageInstaller.mode_previous
	elseif packageInstaller.mode == MODE_PROMPT_REFRESH then
		packageInstaller.t = 0
		packageInstaller.mode = MODE_LOADING
		packageInstaller.pending = get_package_list_prepare
	elseif packageInstaller.mode == MODE_LISTING then
		local list = packageInstaller:get_current_list()
		if not list then return end
		if packageInstaller.selected == 0 then
			packageInstaller:upOneLevel()
		else
			local entry = list[packageInstaller.selected]
			if entry.error then
				createInfoPopup("Error", "*" .. tostring(packageInstaller.error), true)
			elseif entry.link then
				-- do nothing
			elseif entry.directory then
				packageInstaller.path[#packageInstaller.path + 1] = packageInstaller.selected
				packageInstaller.t = 0
				packageInstaller.selected = 1
				packageInstaller.scroll = 0
			else
				if not fos or not fos.zip_open then
					createInfoPopup("Unable to Install", "*This version of FunnyOS was not built with zip file support.", true)
				elseif entry.path then
					createInfoPopup("Really Install?", "*The latest version of package \"" .. entry.name .. "\" will be downloaded and installed.", true, function()
						downloadAndInstall(entry.path, entry.installpath, entry.source_scheme, entry.source_host, entry.source_path)
					end)
				else
					createInfoPopup("Unable to Install", "*No 'path' field specifying url exists.")
				end
			end
		end
	end
end

function packageInstaller:BButtonDown()
	
end

function packageInstaller:upButtonDown()
	if packageInstaller.mode == MODE_LISTING then
		if packageInstaller.selected > packageInstaller:get_listing_start_idx() then
			packageInstaller.selected -= 1
		end
	end
end

function packageInstaller:downButtonDown()
	if packageInstaller.mode == MODE_LISTING then
		local list = packageInstaller:get_current_list()
		if not list then return end
		if packageInstaller.selected < #list then
			packageInstaller.selected += 1
		end
	end
end

function packageInstaller:leftButtonDown()
	
end

function packageInstaller:rightButtonDown()
	
end

function packageInstaller:upButtonUp()
	
end

function packageInstaller:downButtonUp()
	
end

function packageInstaller:leftButtonUp()
	
end

function packageInstaller:rightButtonUp()
	
end

function packageInstaller:get_current_list()
	local list = packageInstaller.db.listing
	for i, key in ipairs(packageInstaller.path) do
		list = list[key].contents
	end
	return list
end

function packageInstaller:get_listing_start_idx()
	if #packageInstaller.path == 0 then
		return 1
	end
	return 0
end

function packageInstaller:draw_listing()
	local list = packageInstaller:get_current_list()
	
	if not list then
		packageInstaller.t = 0
		packageInstaller.mode = MODE_SHOW_MESSAGE
		packageInstaller.mode_previous = MODE_PROMPT_REFRESH
		packageInstaller.message = "Unable to\nlist packages"
		return
	end
	
	-- if start_idx is 0, '..'
	local start_idx = packageInstaller:get_listing_start_idx()
	
	-- update scroll
	packageInstaller.scroll = toward(
		packageInstaller.scroll,
		math.max(
			math.min(packageInstaller.selected - scroll_offset, #list - scroll_items + 1),
			start_idx
		),
		1/10.0 + math.max(0, (math.abs(packageInstaller.selected - packageInstaller.scroll + scroll_offset) - 2)/8.0)
	)
	
	-- hard clamp
	packageInstaller.scroll = math.max(
		math.min(packageInstaller.scroll, #list - scroll_items + 1),
		start_idx
	)
	
	gfx.setColor(gfx.kColorBlack)
	for i=start_idx,#list do
		local icon = folderImg
		local text = ".."
		
		if i > 0 then
			local entry = list[i]
			if entry.error then
				text = entry.name or entry.directory
				icon = errImg
			elseif entry.link then
				text = entry.name or entry.directory
				icon = (packageInstaller.t % 24 < 12) and loadImg or load2Img
			elseif entry.directory then
				text = entry.directory .. "/"
			else
				icon = pkgImg
				text = entry.name
			end
		end
		
		text = text:gsub("_","__")
		text = text:gsub("*","**")
		
		local y = (i - packageInstaller.scroll)*itemHeight
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if i == packageInstaller.selected and packageInstaller:isActive() then
			gfx.fillRect(0, y, 200, itemHeight)
			gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		end
		gfx.drawText("*"..text,40,y+9)
		if i == packageInstaller.selected and packageInstaller:isActive() then
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
		end
		icon:draw(4, y)
		gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function packageInstaller:getTitle()
	if packageInstaller:isActive() and packageInstaller.mode == MODE_LISTING and #packageInstaller.path > 0 then
		local list = packageInstaller.db.listing
		local name = nil
		for i = 1,#packageInstaller.path do
			list = list[packageInstaller.path[#packageInstaller.path]]
			name = list.directory
			list = list.contents
		end
		if name then return name end
	end
	return packageInstaller.metadata.name
end

-- Refresh the packageInstaller image
function packageInstaller:loadImage()
	if not packageInstaller.image then
		packageInstaller.image = playdate.graphics.image.new(200, 200)
	end
	if not packageInstaller.scrollArea then
		packageInstaller.scrollArea = playdate.graphics.image.new(200, bottom - top)
	end
	playdate.graphics.pushContext(packageInstaller.image)
		-- Draw packageInstaller content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		gfx.drawTextAligned("*" .. packageInstaller:getTitle() .. "*",100, 7,kTextAlignment.center)
		
		if packageInstaller.mode == MODE_PROMPT_REFRESH and packageInstaller:isActive() then
			gfx.drawTextAligned("*Press (A) To Refresh*",100, 100,kTextAlignment.center)
		elseif packageInstaller.mode == MODE_SHOW_MESSAGE then
			gfx.drawTextAligned(packageInstaller.message,100, 100,kTextAlignment.center)
		elseif packageInstaller.mode == MODE_LOADING then
			local s = "."
			if packageInstaller.t % 32 > 8 then
				s = ".."
			end
			if packageInstaller.t % 32 > 16 then
				s = "..."
			end
			gfx.drawTextAligned("*" .. s .. "*",100, 100, kTextAlignment.center)
		elseif packageInstaller.mode == MODE_LISTING then
			playdate.graphics.pushContext(packageInstaller.scrollArea)
				playdate.graphics.clear(playdate.graphics.kColorClear)
				packageInstaller:draw_listing()
			playdate.graphics.popContext()
			packageInstaller.scrollArea:draw(0, top)
		end
	playdate.graphics.popContext()

	return packageInstaller.image
end

-- Get the packageInstaller image most recently drawn with loadImage(); called every frame.
function packageInstaller:getpackageInstallerImage()
	if packageInstaller.image then
		return packageInstaller.image
	else
		return packageInstaller:loadImage()	
	end
end

function packageInstaller:updateLoadLink()
	local list = packageInstaller:get_current_list()
	local linkLoadIndex = packageInstaller:getLinkLoadIndex()
	if not linkLoadIndex then
		return
	end
	for i, entry in ipairs(list) do
		if not entry.http then
			if entry.link and not entry.error then
				local prevName = entry.name
				local scheme, host, path = splitURLMaybeRelative(
					entry.path,
					
					-- source_* indicate where we got this entry from. if nil, from base package.json
					entry.source_scheme, entry.source_host, entry.source_path
				)
				entry.http = playdate.network.http.new(host, 0, scheme == "https", "to download package info")
				if not entry.http then
					entry.error = scheme .. " failure"
					return
				end
				packageInstaller.httplink[linkLoadIndex] = entry.http
				local http = entry.http
				http:setConnectTimeout(30)
				http:setRequestCompleteCallback(
					function()
						print("A")
						local data = ""
						while true do
							local d = http:read()
							if not d or #d == 0 then
								break
							end
							data = data .. d
						end
						if data and entry.http then
							local j = json.decode(data)
							if not j then
								entry.error = "error decoding json"
							else
								entry.link = nil
								entry.path = nil
								
								-- integrate new source
								for key, value in pairs(j) do
									entry[key] = value
									print("replace: ", key, value)
								end
								
								-- mark down where we got it from
								local function recursivelySetSource(entry, scheme, host, path)
									entry.source_scheme = scheme
									entry.source_host = host
									entry.source_path = path
									
									if entry.contents then
										for j, e in ipairs(entry.contents) do
											recursivelySetSource(e, scheme, host, path)
										end
									end
								end
								
								recursivelySetSource(entry, scheme, host, getParentDirectory(path))
							end
							entry.http = nil
							packageInstaller.httplink[linkLoadIndex] = nil
						else
							entry.error = http:getError()
							entry.http = nil
							packageInstaller.httplink[linkLoadIndex] = nil
						end
					end
				)
				http:setConnectionClosedCallback(
					function()
						print("B")
						if entry.http then
							entry.error = scheme .. " server closed connection unexpectedly."
							entry.http = nil
							packageInstaller.httplink[linkLoadIndex] = nil
						end
					end
				)
				http:setRequestCallback(function()
					print("C")
				end)
				http:setHeadersReadCallback(function()
					print("D")
					local status = http:getResponseStatus()
					if entry.http and status ~= 200 and status ~= 0 then
						entry.error = scheme .. " status " .. tostring(status)
						entry.http = nil
						packageInstaller.httplink[linkLoadIndex] = nil
					end
				end)
				local pf = path
				if not pf:find("?") then
					pf = pf .. "?nocache=" .. tostring(math.floor(math.random(0, 10000)))
				end
				
				print("GET", pf)
				http:get(pf)
				break
			end
		end
	end
end

-- Called every frame, put main loop here
function packageInstaller:update()
	loadAssets()
	
	if packageInstaller.pending then
		local pending = packageInstaller.pending
		packageInstaller.pending = nil
		pending()
	end
	
	if packageInstaller.mode == MODE_LISTING then
		packageInstaller:updateLoadLink()
	end
	
	if true then
		packageInstaller.t += 1
		-- Refresh graphic
		packageInstaller:loadImage()
	end
    
    if packageInstaller.image then
        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeInverted)
        packageInstaller.image:draw(180, 246-controlCenterProgress)
        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
    end
end

-- Called when FunnyOS boots up
function packageInstaller:init()
	packageInstaller:getpackageInstallerImage()	
end

return packageInstaller