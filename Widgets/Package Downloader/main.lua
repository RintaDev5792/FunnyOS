local VERSION = 1

local widget = {}

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

-- path is filled out when loaded by system
widget.metadata = {
	name = "Package Downloader",
	game = nil,
	path = nil,
}

widget.image = nil
widget.package_hierarchy = nil
widget.mode = MODE_PROMPT_REFRESH
widget.mode_previous = widget.mode
widget.t = 0
widget.scroll = 0
widget.httplink = {}

local itemHeight = 33
local top = 35
local bottom = top + itemHeight*4
local folderImg = nil
local pgkImg = nil
local loadImg = nil
local load2Img = nil
local errImg = nil
local scroll_items = 4
local scroll_offset = scroll_items/2
local savePath = "/Shared/FunnyOS2/Download/"

local maxLinkLoading = 3

function widget:getLinkLoadIndex()
	for i=1,maxLinkLoading do
		if not widget.httplink[i] then
			return i
		end
	end
	return nil
end

local function loadAssets()
	if not folderImg then
		folderImg = gfx.image.new(widget.metadata.path.."fol")
		pkgImg = gfx.image.new(widget.metadata.path.."pkg")
		errImg = gfx.image.new(widget.metadata.path.."err")
		loadImg = gfx.image.new(widget.metadata.path.."load")
		load2Img = gfx.image.new(widget.metadata.path.."load2")
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
	
	widget.mode = MODE_LOADING
	widget.http = playdate.network.http.new(host, 0, use_ssl, "to download a package")
	if not widget.http then
		widget.mode_previous = MODE_LISTING
		widget.mode = MODE_SHOW_MESSAGE
		widget.message = "Failed to open\n" .. scheme .. " connection"
		return
	end

	if not file then
		createInfoPopup(
			"Download Failed", "*Could not open file for writing:\n" .. tostring(file_error),
		nil)
		return
	end
	
	local http = widget.http
	http:setConnectTimeout(40)
	local function read_bytes()
		if not widget.http then return end
		while http:getBytesAvailable() > 0 do
			print("bytes available: ", http:getBytesAvailable())
			local s = http:read(1024)
			if #s == 0 then
				print("0 bytes read")
				widget.http = nil
				widget.mode_previous = MODE_LISTING
				widget.mode = MODE_SHOW_MESSAGE
				widget.message = "0 bytes read."
				file:close()
			elseif file:write(s) < 0 then
				print("Failed to write to file")
				widget.http = nil
				widget.mode_previous = MODE_LISTING
				widget.mode = MODE_SHOW_MESSAGE
				widget.message = "Failed to write\nto file."
				file:close()
			else
				file:flush()
			end
		end
	end
	http:setRequestCompleteCallback(
		function()
			if widget.http then
				read_bytes()
				widget.http = nil
				file:close()
				
				-- at this point, we are now on to installing/unzipping the file
				installPackage(fname, installpaths)
				playdate.file.delete(fname)
				widget.mode = MODE_LISTING
			else
				print("Err: ", http:getError())
			end
		end
	)
	http:setConnectionClosedCallback(
		function()
			if widget.http then
				widget.http = nil
				file:close()
				widget.mode = MODE_SHOW_MESSAGE
				widget.mode_previous = MODE_LISTING
				widget.message = "Download Failed."
			end
		end
	)
	http:setRequestCallback(read_bytes)
	http:setHeadersReadCallback(function()
		local status = http:getResponseStatus()
		print("status: ", status)
		if widget.http and status ~= 200 and status ~= 0 then
			widget.http = nil
			widget.mode = MODE_LISTING
			file:close()
			createInfoPopup("Connection Failed", "*HTTP Status: " .. tostring(status), nil)
		end
	end)
	print("GET " .. scheme .. "://" .. host .. path)
	http:get(path)
end

function widget:upOneLevel()
	widget.selected = widget.path[#widget.path]
	widget.path[#widget.path] = nil
	widget.scroll = widget.selected - scroll_offset
end

-- If a B button function isn't provided, this is the default action for it.
function widget:BButtonUp()
	if widget.mode == MODE_LISTING and #widget.path > 0 then
		widget:upOneLevel()
		return
	end
	-- Removes focus from the widget so others can be selected
	-- Need this line somewhere if you use the B button.
	widgetIsActive = false
	widget:loadWidgetImage()
end

local function get_package_list()
	local http = widget.http
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
			if data and widget.http then
				widget.http = nil
				widget.db = json.decode(data)
				if widget.db then
					if widget.db.version == VERSION then
						widget.path = {}
						widget.http = nil
						widget.mode = MODE_LISTING
						widget.scroll = 0
						widget.selected = 1
					else
						widget.mode = MODE_SHOW_MESSAGE
						widget.message = "Package database\nversion mismatch.\nPlease update manually."
						widget.t = 0
					end
				else
					widget.t = 0
					widget.mode = MODE_SHOW_MESSAGE
					widget.message = "Invalid package\ndatabase received"
				end
			else
				print("Err: ", http:getError())
			end
		end
	)
	http:setConnectionClosedCallback(
		function()
			print("B")
			if widget.http then
				widget.http = nil
				widget.mode = MODE_PROMPT_REFRESH
			end
		end
	)
	http:setRequestCallback(function()
		print("C")
	end)
	http:setHeadersReadCallback(function()
		print("D")
		local status = http:getResponseStatus()
		if widget.http and status ~= 200 and status ~= 0 then
			widget.http = nil
			widget.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Connection Failed", "*HTTP Status: " .. tostring(status), nil)
		end
	end)
	
	local pf = PACKAGE_FILE .. "?nocache=" .. tostring(math.floor(math.random(0, 10000)))
	print("GET", pf)
	http:get(pf)
end

function get_package_list_prepare()
	playdate.network.setEnabled(true, function(err)
		if err then 
			widget.mode = MODE_PROMPT_REFRESH
			createInfoPopup("Failed to Enable Networking", "*" .. err, nil)
		else
			--[[
			local status = playdate.network.getStatus()
			if status == playdate.network.kStatusNotConnected then
				widget.message = "Network Not Connected"
				widget.mode = MODE_SHOW_MESSAGE
				widget.t = 0
				return
			elseif playdate.network.kStatusNotAvailable then
				widget.message = "Network Not Available"
				widget.mode = MODE_SHOW_MESSAGE
				widget.t = 0
				return
			end
			]]
			
			if not widget.http then
				widget.http = playdate.network.http.new(PACKAGE_HOST, 0, true, "to list downloadable packages")
				if not widget.http then
					widget.mode = MODE_PROMPT_REFRESH
				else
					get_package_list()
				end
			end
		end
	end)
end

function widget:AButtonUp()
	if widget.mode == MODE_SHOW_MESSAGE and widget.t > 15 then
		widget.mode = widget.mode_previous
	elseif widget.mode == MODE_PROMPT_REFRESH then
		widget.t = 0
		widget.mode = MODE_LOADING
		widget.pending = get_package_list_prepare
	elseif widget.mode == MODE_LISTING then
		local list = widget:get_current_list()
		if not list then return end
		if widget.selected == 0 then
			widget:upOneLevel()
		else
			local entry = list[widget.selected]
			if entry.error then
				createInfoPopup("Error", "*" .. tostring(widget.error), true)
			elseif entry.link then
				-- do nothing
			elseif entry.directory then
				widget.path[#widget.path + 1] = widget.selected
				widget.t = 0
				widget.selected = 1
				widget.scroll = 0
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

function widget:BButtonDown()
	
end

function widget:upButtonDown()
	if widget.mode == MODE_LISTING then
		if widget.selected > widget:get_listing_start_idx() then
			widget.selected -= 1
		end
	end
end

function widget:downButtonDown()
	if widget.mode == MODE_LISTING then
		local list = widget:get_current_list()
		if not list then return end
		if widget.selected < #list then
			widget.selected += 1
		end
	end
end

function widget:leftButtonDown()
	
end

function widget:rightButtonDown()
	
end

function widget:upButtonUp()
	
end

function widget:downButtonUp()
	
end

function widget:leftButtonUp()
	
end

function widget:rightButtonUp()
	
end

function widget:get_current_list()
	local list = widget.db.listing
	for i, key in ipairs(widget.path) do
		list = list[key].contents
	end
	return list
end

function widget:get_listing_start_idx()
	if #widget.path == 0 then
		return 1
	end
	return 0
end

function widget:draw_listing()
	local list = widget:get_current_list()
	
	if not list then
		widget.t = 0
		widget.mode = MODE_SHOW_MESSAGE
		widget.mode_previous = MODE_PROMPT_REFRESH
		widget.message = "Unable to\nlist packages"
		return
	end
	
	-- if start_idx is 0, '..'
	local start_idx = widget:get_listing_start_idx()
	
	-- update scroll
	widget.scroll = toward(
		widget.scroll,
		math.max(
			math.min(widget.selected - scroll_offset, #list - scroll_items + 1),
			start_idx
		),
		1/10.0 + math.max(0, (math.abs(widget.selected - widget.scroll + scroll_offset) - 2)/8.0)
	)
	
	-- hard clamp
	widget.scroll = math.max(
		math.min(widget.scroll, #list - scroll_items + 1),
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
				icon = (widget.t % 24 < 12) and loadImg or load2Img
			elseif entry.directory then
				text = entry.directory .. "/"
			else
				icon = pkgImg
				text = entry.name
			end
		end
		
		text = text:gsub("_","__")
		text = text:gsub("*","**")
		
		local y = (i - widget.scroll)*itemHeight
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		if i == widget.selected and widgetIsActive then
			gfx.fillRect(0, y, 200, itemHeight)
			gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		end
		gfx.drawText("*"..text,40,y+9)
		if i == widget.selected and widgetIsActive then
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
		end
		icon:draw(4, y)
		gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function widget:getTitle()
	if widgetIsActive and widget.mode == MODE_LISTING and #widget.path > 0 then
		local list = widget.db.listing
		local name = nil
		for i = 1,#widget.path do
			list = list[widget.path[#widget.path]]
			name = list.directory
			list = list.contents
		end
		if name then return name end
	end
	return widget.metadata.name
end

-- Refresh the widget image
function widget:loadWidgetImage()
	if not widget.image then
		widget.image = playdate.graphics.image.new(200, 200)
	end
	if not widget.scrollArea then
		widget.scrollArea = playdate.graphics.image.new(200, bottom - top)
	end
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		gfx.drawTextAligned("*" .. widget:getTitle() .. "*",100, 7,kTextAlignment.center)
		
		if widget.mode == MODE_PROMPT_REFRESH and widgetIsActive then
			gfx.drawTextAligned("*Press (A) To Refresh*",100, 100,kTextAlignment.center)
		elseif widget.mode == MODE_SHOW_MESSAGE then
			gfx.drawTextAligned(widget.message,100, 100,kTextAlignment.center)
		elseif widget.mode == MODE_LOADING then
			local s = "."
			if widget.t % 32 > 8 then
				s = ".."
			end
			if widget.t % 32 > 16 then
				s = "..."
			end
			gfx.drawTextAligned("*" .. s .. "*",100, 100, kTextAlignment.center)
		elseif widget.mode == MODE_LISTING then
			playdate.graphics.pushContext(widget.scrollArea)
				playdate.graphics.clear(playdate.graphics.kColorClear)
				widget:draw_listing()
			playdate.graphics.popContext()
			widget.scrollArea:draw(0, top)
		end
		
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
			gfx.drawTextAligned(buttons.B.."    " ..buttons.A,100, 200-21,kTextAlignment.center)
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

function widget:updateLoadLink()
	local list = widget:get_current_list()
	local linkLoadIndex = widget:getLinkLoadIndex()
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
				widget.httplink[linkLoadIndex] = entry.http
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
							widget.httplink[linkLoadIndex] = nil
						else
							entry.error = http:getError()
							entry.http = nil
							widget.httplink[linkLoadIndex] = nil
						end
					end
				)
				http:setConnectionClosedCallback(
					function()
						print("B")
						if entry.http then
							entry.error = scheme .. " server closed connection unexpectedly."
							entry.http = nil
							widget.httplink[linkLoadIndex] = nil
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
						widget.httplink[linkLoadIndex] = nil
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
function widget:update(isActive)
	loadAssets()
	
	if widget.pending then
		local pending = widget.pending
		widget.pending = nil
		pending()
	end
	
	if widget.mode == MODE_LISTING then
		widget:updateLoadLink()
	end
	
	if isActive then
		widget.t += 1
		-- Refresh graphic
		widget:loadWidgetImage()
	end
end

-- Called when FunnyOS boots up
function widget:init()
	widget:getWidgetImage()	
end

return widget