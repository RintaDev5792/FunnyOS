local ExampleWidget2 = {}
local widget = ExampleWidget2

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
local lastCircleCursorRadius = 4


-- Input handlers
function widget:AButtonDown()
    sys.switchToGame(launchers[launcherOrder[selectedLauncher]].path)
end

function widget:upButtonDown()
    selectedLauncher -= 1
    if selectedLauncher < 1 then selectedLauncher = 1 end
    widget:loadWidgetImage()
end

function widget:downButtonDown()
    selectedLauncher += 1
    if selectedLauncher > #launcherOrder then selectedLauncher = #launcherOrder end
    widget:loadWidgetImage()
end

function widget:leftButtonDown()
    
end

function widget:rightButtonDown()
    
end

local function getLauncherIcon(path)
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

local function loadLaunchers()
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

-- call this to get UPDATED widget image
function widget:loadWidgetImage()
    widget.image = gfx.image.new(200, 200)
    gfx.pushContext(widget.image)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)
    gfx.setColor(gfx.kColorWhite)
    gfx.setLineWidth(4)
    gfx.drawRoundRect(2, 2, 196, 196, configVars.cornerradius)
    
    local spacing = 34
    if selectedLauncher-scroll > 5 then
        scroll +=1
    end
    if selectedLauncher-scroll < 1 then
        scroll -=1
    end
    for i,v in pairs(launcherOrder) do
        local y = labelSpacing*3 + spacing*(i-scroll) - (spacing-2)
        if y < 200-labelSpacing and y > labelSpacing-1 then
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawTextInRect("*"..v.."*", labelSpacing*3+2, y-9, 200-labelSpacing*6-27, spacing, 0, "...")
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            if launchers[v].icon then
                launchers[v].icon:draw(200-16-labelSpacing*3-2, y-16)
            end
        end
    end
    drawCircleCursor(labelSpacing*3 - 12, labelSpacing*2-spacing+3, spacing, selectedLauncher, #launcherOrder, scroll)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)	
    gfx.popContext()
    return widget.image
end

-- call this to get RECENT widget image, DO NOT MODIFY
function widget:getWidgetImage()
    if widget.image and not forceReload and lastCircleCursorRadius == circleCursorRadius then
        return widget.image
    else
        lastCircleCursorRadius = circleCursorRadius
        return widget:loadWidgetImage()	
    end
end

function widget:update(isActive)
    if isActive then
        widget:getWidgetImage()
    end
end

function widget:init()
    loadLaunchers()
    selectedLauncher = 1
    scroll = 1
    widget:getWidgetImage()	
end

return widget