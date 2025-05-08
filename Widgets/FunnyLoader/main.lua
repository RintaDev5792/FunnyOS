local FunnyLoaderWidget = {}
local widget = FunnyLoaderWidget

local counter = 0

-- path is filled out when loaded by system
widget.metadata = {
    name = "FunnyLoader Widget",
    game = nil,
    path = nil
}

widget.image = nil

local launchers = {}
local launcherOrder = {}
local selectedLauncher = 1
local scroll = 1
local itemHeight = 34
local listIconImg = nil
local loadedAssets = false

local timerInitialDelay,timerRepeatDelay = 300,40
local scrollRepeatTimer = nil

-- Input handlers
function widget:AButtonDown()
    sys.switchToGame(launchers[launcherOrder[selectedLauncher]].path)
end

-- If a B button function widget:isn't provided, this is the default action for it.
function widget:BButtonUp()
    -- Removes focus from the widget so others can be selected
    -- Need this line somewhere if you use the B button.
    widgetIsActive = false
    widget:loadWidgetImage()
end


function widget:upButtonDown()
    widget:removeScrollTimer()
    scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, widget.moveUp)
end

function widget:moveUp()
    selectedLauncher=math.max(selectedLauncher-1,1)
    if selectedLauncher < scroll then
        scroll=scroll-1
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
    selectedLauncher=math.min(selectedLauncher+1,#launcherOrder)
    if selectedLauncher > (200/itemHeight)+scroll-2 then
        scroll=scroll+1
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

local function getLauncherIcon(path)
    if fle.exists(path.."/icon.pdi") then
        return gfx.image.new(path.."/icon.pdi")
    elseif fle.exists(path.."/images/list_icon_default.pdi") then
        return gfx.image.new(path.."/images/list_icon_default.pdi")
    elseif sys.getMetadata(path .. "/pdxinfo") then
        local f = fle.open(path.."/pdxinfo") 
        if sys.getMetadata(path .. "/pdxinfo").name=="Index OS" then
            local img = gfx.image.new(32,32,gfx.kColorClear)
            gfx.lockFocus(img)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(0, 0, 32, 32, 3)
            gfx.image.new("images/indexOS"):draw(0,0)
            gfx.unlockFocus()
            return img
        elseif sys.getMetadata(path .. "/pdxinfo").imagePath then
            return gfx.image.new(path.."/"..sys.getMetadata(path .. "/pdxinfo").imagePath.."/icon")
        end
    elseif listIconImg ~= nil then
        return listIconImg
    end
    return nil
end

local function loadLaunchers()
    launchers = {}
    local launcherName = sys.getMetadata("/System/Launcher.pdx/pdxinfo").name
    if launchers[launcherName] then 
        launcherName = "/System/Launcher.pdx".." ["..launcherName.."]"
    end
    launchers[launcherName] = {["icon"] = getLauncherIcon("/System/Launcher.pdx"), ["path"] = "/System/Launcher.pdx"}
    if fle.isdir("/System/Launchers") then
        local files = fle.listFiles("/System/Launchers")
        for i,v in ipairs(files) do
            v = v:sub(1,#v-1) --remove slash
            files[i] = v
            if string.lower(v:sub(#v-3,#v)) == ".pdx" then
                local data = sys.getMetadata("/System/Launchers/".. v .. "/pdxinfo")
                local launcherName = v:sub(1,#v-4)
                if data then
                    launcherName = data.name
                end
                if launchers[launcherName] then 
                    launcherName = "/System/Launchers/"..v.." ["..launcherName.."]"
                end
                launchers[launcherName] = {["icon"] = getLauncherIcon("/System/Launchers/"..v), ["path"] = "/System/Launchers/"..v}
            end
        end	
    end
    launcherOrder = {}
    for k,v in pairs(launchers) do
        table.insert(launcherOrder, k)	
    end
    table.sort(launcherOrder)
end

-- Refresh the widget image
function widget:loadWidgetImage()
    widget.image = playdate.graphics.image.new(200, 200,gfx.kColorWhite)
    playdate.graphics.pushContext(widget.image)
        -- Draw widget content
        playdate.graphics.clear(playdate.graphics.kColorClear)

        playdate.graphics.setColor(playdate.graphics.kColorWhite)
        playdate.graphics.fillRect(0, 0, 200, 200)

        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
        
        gfx.setColor(gfx.kColorBlack)
        
        for i,v in ipairs(launcherOrder) do
            
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            local y = i*itemHeight - scroll*itemHeight - 5+ itemHeight
            if i == selectedLauncher and widgetIsActive then
                gfx.fillRect(0, y, 200, itemHeight)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            end
            if y > 15 and y < 200 then
                local drawText = v
                drawText = drawText:gsub("_","__")
                drawText = drawText:gsub("*","**")
                gfx.drawText("*"..drawText,40,y+9)
                gfx.setImageDrawMode(gfx.kDrawModeNXOR)
                if launchers[v].icon then
                    launchers[v].icon:draw(4,y+1)
                elseif listIconImg then
                    listIconImg:draw(4,y+1)
                end
            end
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        end
        gfx.drawTextAligned("*System Loader*",100, 7,kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        
        if widgetIsActive then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(0, 200-24, 200, 24)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            --curveLeftImg:draw(0,200-36)
            --curveRightImg:draw(200-13,200-36)
            local curveImg = gfx.image.new(200,configVars.cornerradius,gfx.kColorBlack)
            local maskImg = gfx.image.new(200,configVars.cornerradius,gfx.kColorWhite)
            gfx.pushContext(maskImg)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(0, -configVars.cornerradius*2, 200, configVars.cornerradius*3, configVars.cornerradius)
            gfx.popContext()
            curveImg:setMaskImage(maskImg)
            curveImg:draw(0,200-24-configVars.cornerradius)
            
            gfx.setImageDrawMode(gfx.kDrawModeNXOR)
            gfx.drawTextAligned(buttons.A,100, 200-21,kTextAlignment.center)
            
        end
        
    playdate.graphics.popContext()

    return widget.image
end

-- call this to get RECENT widget image, DO NOT MODIFY
function widget:getWidgetImage()
    if widget.image then
        return widget.image
    else
        return widget:loadWidgetImage()	
    end
end

function widget:update(isActive)
    if not loadedAssets and widget.metadata.path ~= nil then
        listIconImg = gfx.image.new(widget.metadata.path.."list_icon_default")
        loadedAssets = listIconImg ~= nil
        widget:loadWidgetImage()
    end
end

function widget:init()
    loadLaunchers()
    selectedLauncher = 1
    scroll = 1
    widget:getWidgetImage()	
end

return widget