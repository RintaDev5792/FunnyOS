import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/object")
import("CoreLibs/sprites")
import("options")
gameInfo, groups = nil, nil
gameIcons = {}
gameGrid = {}
gfx = playdate.graphics
fle = playdate.file
gme = playdate.system.game
cursorx,cursory = 1,1
cursordrawx,cursordrawy = 1,1
columns,rows = 1,3
iconsImage = nil
iconOffsetX = 0
iconOffsetY = 12
season_1 = {
"com.a-m.beats-bleeps-boogie",
"com.crookedpark.demonquest85",
"com.dadako.questychess",
"com.davemakes.execgolf",
"com.gregorykogos.omaze",
"com.nelsanderson.forrest",
"com.NicMagnier.PickPackPup",
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
"net.stfj.snak",
}
recentCursorDown = 0
recentCursorRight = 0
inputDelay = 0
badgeIcons = {}

labels = {}
currentLabel = ""
labelMaxSize = 8

organizeMode = false
selectedBadge = nil
selectedBadgeImage = nil

reloadIconsNextFrame = false
iconPlacements = nil

drawIconBorders = true

selectedBadgeOriginX = 0
selectedBadgeOriginY = 0

labelImage = nil

paddingOffset = 0

editingLabel = 0
firstEdit = true

keyTimer = nil
local initialDelay = 300
local repeatDelay = 40

blankImg = nil

first_load = true

local cardLaunchGame = nil
local cardImg = nil
cardShowing = false

contentWarningState = 0

local bgdither = 0
local bgditherimg = nil
local invertborders = false
local invertlabels = false
local invertcursor = false
local invertblanks = false

local emptydither = 0.75

local invertedColors = {[true] = gfx.kColorWhite, [false] = gfx.kColorBlack}
local invertedDrawModes = {[true] = gfx.kDrawModeFillBlack, [false] = gfx.kDrawModeFillWhite}
Opts = Options(
    {
        { 
            header="Customization", options = {
                {
                    name = "Icon Borders",
                    key = "iconborders",
                    default = true
                },
                {
                    name = "Invert Borders",
                    key = "invertborders",
                    default = false
                },
                {
                    name = "Invert Cursor",
                    key = "invertcursor",
                    default = false
                },
                {
                    name = "Invert Labels",
                    key = "invertlabels",
                    default = false
                },
                {
                    name = "Invert Blanks",
                    key = "invertblanks",
                    default = false
                },
                {
                    name = "Background Dither",
                    key = "bgdither",
                    style = Options.SLIDER,
                    min = 0,
                    max = 4,
                    default = 0
                },
                {
                    name = "Blank Space Dither",
                    key = "emptydither",
                    style = Options.SLIDER,
                    min = 0,
                    max = 4,
                    default = 1
                }
            }
        }
    },
    true,
    "Funny OS/pdoptions",
    function() 
        loadOptions()
    end
)

function loadOptions(initial)
    if drawIconBorders == nil then drawIconBorders = true Opts:write("iconborders", 2) end

    local i = Opts:read("bgdither", true, true)
    i = 1- 0.25*i
    if i ~= bgdither or initial == true then
        changeBgDither(i)
    end
    i = Opts:read("emptydither", true, true)
    i = 1- 0.25*i
    if i ~= emptydither or initial == true then
        setEmptyIcon(i)
    end
    if Opts:read("iconborders", true, true) ~= drawIconBorders or Opts:read("invertlabels", true, true) ~= invertlabels 
    or Opts:read("invertborders", true, true) ~= invertborders or Opts:read("invertcursor", true, true) ~= invertcursor 
    or Opts:read("invertblanks", true, true) ~= invertblanks then
        invertborders = Opts:read("invertborders", true, true) 
        invertlabels = Opts:read("invertlabels", true, true) 
        invertcursor = Opts:read("invertcursor", true, true) 
        invertblanks = Opts:read("invertblanks", true, true) 
        drawIconBorders = Opts:read("iconborders", true, true) 
        i = Opts:read("emptydither", true, true)
        i = 1- 0.25*i
        setEmptyIcon(i)
        for k,v in pairs(gameInfo) do
            if not (v["group"] == "System") then
                loadIcon(k)
            end
        end
        reloadIconsNextFrame = true
    end
end

function setEmptyIcon(n)
    emptydither = n
    
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(invertedColors[invertblanks])
    blankImg = gfx.image.new(66,66)
    gfx.lockFocus(blankImg)
    gfx.setDitherPattern(n,gfx.image.kDitherTypeScreen)
    gfx.fillRoundRect(0,0,66,66,8)
    gfx.unlockFocus()
    loadOptions()
    drawIcons()
end

function changeBgDither(n)
    bgdither = n
    
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    print(n)
    local img = gfx.image.new(400,240)
    gfx.lockFocus(img)
    gfx.setDitherPattern(n)
    gfx.fillRect(0,0,400,240)
    gfx.unlockFocus()
    bgditherimg = img
    reloadIconsNextFrame = true
    loadOptions()
    drawIcons()
end

function cleanUpIconPlacements()
    local newIconPlacements = {}
    for i,v in ipairs(iconPlacements) do
        if v  ~= ".tempblank" then
            table.insert(newIconPlacements,v)
        end
    end
    iconPlacements = newIconPlacements
end

function removeKeyTimer()
    if keyTimer ~= nil then
        keyTimer:pause()
        keyTimer:remove()
        keyTimer = nil
    end
end

function sortLabels()
    local newLabels = {}
    for i,v in ipairs(labels) do
        if i == 1 then
            table.insert(newLabels,v)
        else
            local found = false
            for j,v2 in ipairs(newLabels) do
                if (indexFromPos(v.x,1) < indexFromPos(v2.x,1)) and not found then
                    table.insert(newLabels,j,v)
                    found = true
                end
            end
            if not found then
                table.insert(newLabels,#newLabels+1,v)
                found = true
            end
        end
    end
    labels = newLabels
end

function saveConfig()
    local datastore = {}
    datastore["iconPlacements"] = iconPlacements
    datastore["labels"] = labels
    playdate.datastore.write(datastore,"Funny OS/funnyConfig")
end

function loadConfig()
    local datastore = playdate.datastore.read("Funny OS/funnyConfig")
    if datastore then
        iconPlacements = datastore["iconPlacements"]
        labels = datastore["labels"]

    else
        print("no data")
        first_load = true
    end
    if not iconPlacements then iconPlacements = {} end
    if not labels or labels == {} then labels = {{["name"] = "Home", ["x"] = 1}} end
    if #labels < 1 then
        table.insert(labels, {["name"] = "Home", ["x"] = 1})
    end
    currentLabel = labels[1]["name"]
    sortLabels()
end

function indexFromPos(x,y)
    local i = (x*rows) - (rows - y)
    return i
end

function posFromIndex(i)
    local gridy = (i-1)%rows + 1
    local gridx = math.ceil(i/rows)
    return gridx,gridy
end

function generateDrawTextScaledImage(text, x, y, scale, font)
    local padding = string.upper(text) == text and 6 or 0 -- Weird padding hack?
    local w <const> = font:getTextWidth(text)
    local h <const> = font:getHeight() - padding
    local img <const> = gfx.image.new(w, h, gfx.kColorClear)
    local img2 <const> = gfx.image.new(w*scale*2, h*scale*2, gfx.kColorClear)
    gfx.lockFocus(img)
    gfx.setFont(font)
    gfx.drawTextAligned(text, w / 2, 0, kTextAlignment.center)
    gfx.unlockFocus()
    gfx.lockFocus(img2)
    img:drawScaled((scale * w) / 2, (scale * h) / 2, scale)
    gfx.unlockFocus()
    return img2
end

function listCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function processPdxinfoLines(lines)
    local pdxInfoProperties = {}
    for i,v in ipairs(lines) do
        local propertyName = ""
        local propertyValue = ""
        local hasFoundEqual = false
        for i = 1, #v do
            local c = v:sub(i,i)
            if hasFoundEqual then
                propertyValue = propertyValue..c
            else
                if c == "=" then
                    hasFoundEqual = true
                else
                    propertyName = propertyName..c
                end
            end
        end
        pdxInfoProperties[string.lower(propertyName)] = propertyValue
    end
    return pdxInfoProperties
end

function sortGameGrid()
    local newGameGrid = {}
    for i,v in ipairs(gameGrid) do
        if i == 1 then
            table.insert(newGameGrid,v)
        else
            local found = false
            for j,v2 in ipairs(newGameGrid) do
                if not (string.lower(gameInfo[v]["name"]) > string.lower(gameInfo[v2]["name"])) and not found then
                    table.insert(newGameGrid,j,v)
                    found = true
                end
            end
            if not found then
                table.insert(newGameGrid,#newGameGrid+1,v)
                found = true
            end
        end
    end
    gameGrid = newGameGrid
end

function placeIcons()
    sortIconPlacements()
    for i,v in ipairs(iconPlacements) do
        if v["name"] == ".empty" then
            while indexFromPos(v["x"],v["y"]) > #gameGrid-1 do
                table.insert(gameGrid,#gameGrid-1,".empty")
            end
            table.insert(gameGrid,indexFromPos(v["x"],v["y"]),".empty")
        else
            local found = false
            for j,v2 in ipairs(gameGrid) do
                if v2 == v["name"] and not found then
                    while indexFromPos(v["x"],v["y"]) > #gameGrid-1 do
                        table.insert(gameGrid,#gameGrid-1,".empty")
                    end
                    gameGrid[j] = gameGrid[indexFromPos(v["x"],v["y"])]
                    table.insert(gameGrid,indexFromPos(v["x"],v["y"]),v["name"])
                    table.remove(gameGrid,indexFromPos(v["x"],v["y"])+1)
                    found = true
                end
            end
            if not found then
                table.insert(gameGrid,indexFromPos(v["x"],v["y"]),v["name"])
            end
        end

    end
end

function getOffset(x)
    local displayOffsetX = 0
    for j,v2 in ipairs(labels) do
        if v2["x"] == x then
            displayOffsetX += 1   
            
        end
        
        if v2["x"] >= x then
            displayOffsetX += 1
            break
        elseif v2["x"] < x then
            displayOffsetX += 1
            if j == #labels then
                
                displayOffsetX += 1
            end
        end
    end
    return displayOffsetX
end

function drawIcons()
    local paddingAmount = 30
    gfx.clear()
    if bgditherimg then
        bgditherimg:draw(0,0)
    else
        print("NO")
    end
    for i,v in ipairs(gameGrid) do
        if not (cardShowing and contentWarningState > 0) then
            local found = false
            gridx,gridy = posFromIndex(i)
            local drawx = ((gridx*72)-52)-iconOffsetX*72  + 2 - getOffset(cursorx)*paddingAmount
            local drawy = ((gridy*72)-56)-iconOffsetY
            drawx,drawy = math.floor(drawx),math.floor(drawy)
            if (drawx < 400 and drawx > -160) then
    
                drawx+=getOffset(gridx)*paddingAmount
                for j,v2 in ipairs(labels) do
                    if indexFromPos(v2["x"],1) == i and not found then
                        found = true
                        currentLabelIndex = j   
                        gfx.setColor(invertedColors[invertlabels])
                        gfx.fillRect(drawx-3 - paddingAmount + 9,0,paddingAmount-10,240)
                        local t = "*"..labels[j]["name"].."*"
                        local w,h = gfx.getTextSize(t)
                        local img = gfx.image.new(w,h)
                        gfx.lockFocus(img)
                        gfx.setImageDrawMode(invertedDrawModes[invertlabels])
                        gfx.drawText(t, 0, 0)
                        gfx.setImageDrawMode(gfx.kDrawModeCopy)
                        gfx.lockFocus(drawIconsImg)
                        w,h = img:getSize()
                        img = img:rotatedImage(270)
                        img:drawAnchored(drawx-3 - paddingAmount/2 - 3, 210, 0,1)
                    end
                end
                if v:sub(1,7) == ".badge:" then
                    local img = badgeIcons[v]
                    local w,h = img:getSize()
                    local back = 0
                    if w == 72 then
                        back = 3
                    end
                    img:drawCentered(drawx + w/2 -back,drawy + h/2 -back)
                elseif v == ".empty" or v == ".tempblank" then
                    
                    blankImg:draw(drawx-1,drawy)
                else
                    if not gameInfo[v]["icon"]then
                        loadIcon(v)
                    end
                    gameInfo[v]["icon"]:draw(drawx,drawy)
                end
            end
        end
    end
    local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
    local t = ""
    if game and not (cardShowing and contentWarningState > 0) then
        t = t..game.name
        local img = generateDrawTextScaledImage("*"..t.."*",0,0,1,gfx.getFont())
        w,h = img:getSize()
        
        
        if recentCursorDown == 0 then
            basey = cursordrawy*72+21
        else
            basey = cursordrawy*72 - 55 - h
        end
        if recentCursorRight == 0 then
            basex = cursordrawx*72-55
        else
            basex = cursordrawx*72 + 6 - w/2
        end
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(basex,basey-iconOffsetY,w/2+10,h/2+8,6)
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(4)
        gfx.drawRoundRect(basex,basey-iconOffsetY,w/2+10,h/2+8,6)
        gfx.setColor(gfx.kColorWhite)
        img:draw(basex+5 - w/4,basey+5 - h/4 - iconOffsetY)
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0,218,400,30)
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    if organizeMode and selectedBadge == nil then
        gfx.drawText("Ⓐ* Move Object*   Ⓑ* Toggle Label",5,220)
    elseif organizeMode then
        gfx.drawText("Ⓐ* Place Object*   Ⓑ* Cancel",5,220)
    elseif cardShowing then
        gfx.drawText("Ⓐ* Launch Game*   Ⓑ* Back",5,220)
    else
        gfx.drawText("Ⓐ* View Game*   Ⓑ✛* Go to Label",5,220)
    end
    local t = currentLabel
    local w,h = gfx.getTextSize(t)
    gfx.drawTextAligned("*"..t.."*", 395, 220, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    iconsImage = gfx.getWorkingImage()
end

function reloadBadges()
    local files = fle.listFiles("/Shared/FunnyOSBadges")
    local added = 0
    local badgeCountInit = 0
    for i,v in ipairs(iconPlacements) do
        if v["name"]:sub(1,7) == ".badge:" then
            badgeCountInit += 1
        end
    end
    for i,v in ipairs(files) do
        if v:sub(#v-3,#v) == ".pdi" then
            local found = false
            for j,v2 in ipairs(iconPlacements) do
                if v2["name"] == ".badge:"..v:sub(1,#v-4) and v2["name"]:sub(1,7) == ".badge:" then
                    found = true
                    added+=1
                end
            end
            if not found then
                local x,y = posFromIndex(#gameGrid+1+added+badgeCountInit)
                table.insert(iconPlacements, {["name"] = ".badge:"..v:sub(1,#v-4), ["x"] = x,["y"] = y})
                added+=1
            end
        end
    end
    local newIconPlacements = {}
    for i,v in ipairs(iconPlacements) do
        if v["name"]:sub(1,7) == ".badge:" then
            local img = gfx.image.new("/Shared/FunnyOSBadges/"..v["name"]:sub(8,#v["name"])..".pdi")
            if img then
                local w,h = img:getSize()
                if w <= 68 then size = 64 else size = 72 end
                print(v["name"])
                print(size)
                img = img:scaledImage(1/(w/size))
                badgeIcons[v["name"]] = img    
                table.insert(newIconPlacements, v)
            end
        else
            table.insert(newIconPlacements, v)
        end
    end
    iconPlacements = newIconPlacements
end

function sortIconPlacements()
    newIconPlacements = {}
    for i,v in ipairs(iconPlacements) do
        if i == 1 then
            table.insert(newIconPlacements,v)
        else
            local found = false
            for j,v2 in ipairs(newIconPlacements) do
                if (indexFromPos(v.x,v.y) < indexFromPos(v2.x,v2.y)) and not found then
                    table.insert(newIconPlacements,j,v)
                    found = true
                end
            end
            if not found then
                table.insert(newIconPlacements,#newIconPlacements+1,v)
                found = true
            end
        end
    end
    iconPlacements = newIconPlacements
end

function badgeSetup()
    if not fle.isdir("/Shared/FunnyOSBadges") then
        fle.mkdir("/Shared/FunnyOSBadges")
    end
    --playdate.datastore.write(badges, "/Shared/FunnyOSBadges/badges")
    reloadBadges()
end

function main()
    playdate.display.setRefreshRate(50)
    gfx.clear()
    loadConfig()
    setupGameInfo()
    badgeSetup()
    placeIcons()
    loadOptions(true)
    drawIcons()
    while gameGrid[#gameGrid] == ".empty" do
        table.remove(gameGrid,#gameGrid)
    end
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addMenuItem('options', function(value)
        -- Check current state of options sprite to determine whether to open or close the menu.
        if Opts:isVisible(true) then
            Opts:hide()
        else
            Opts:show()
        end
    end)    
    menu:addCheckmarkMenuItem("organize", organizeMode, function(bool) organizeMode = bool reloadIconsNextFrame = true drawerOpen = false end)
   
end

function loadCard(bundleid)
    local icon = gfx.image.new(352, 157,gfx.kColorClear)
    gfx.lockFocus(icon)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(2,2,348,153,8)
    local drawletter = false
    local look_for_icon = true
    --for i,v2 in ipairs(season_1) do
    --    if string.lower(v2) == string.lower(bundleid) then
    --        local gameicon = gfx.image.new("s1_icons/"..v2..".pdi")
    --        if gameicon then
    --            gameicon:drawScaled(1,1,2)
    --            look_for_icon = false
    --        break
    --        end
    --    end 
    --end
    if gameInfo[bundleid]["imagepath"] and look_for_icon then
        local gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/card")
        if gameicon then
            gameicon:draw(1,1)
        else drawletter = true end
    elseif not look_for_icon then
        
        drawletter = true
    end
    if drawletter and look_for_icon then
        local f = gfx.getLargeUIFont()
        local t = gameInfo[bundleid]["name"]
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextInRect(t, 20,66,317, 50, 0, "\226\128\166", kTextAlignment.center, f)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    gfx.setLineWidth(4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(2,2,348,153)
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(0,0,352,157)

    gfx.unlockFocus()
    gameInfo[bundleid]["card"] = icon
end


function loadIcon(bundleid)
    local icon = gfx.image.new(66, 66, gfx.kColorClear)
    gfx.lockFocus(icon)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(2,2,62,62,8)
    local drawletter = false
    local look_for_icon = true
    for i,v2 in ipairs(season_1) do
        if string.lower(v2) == string.lower(bundleid) then
            local gameicon = gfx.image.new("s1_icons/"..v2..".pdi")
            if gameicon then
                gameicon:drawScaled(1,1,2)
                look_for_icon = false
            break
            end
        end 
    end
    if gameInfo[bundleid]["imagepath"] and look_for_icon then
        local gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/icon")
        if gameicon then
            gameicon:drawScaled(1,1,2)
        else drawletter = true end
    else
        
        drawletter = true
    end
    if drawletter and look_for_icon then
        local drawstring = gameInfo[bundleid]["name"]
        while #drawstring < 21 do
            drawstring = drawstring.." "
        end
        local letter = gfx.image.new(16, 16, gfx.kColorClear)
        gfx.lockFocus(letter)
        gfx.drawTextAligned("*"..string.upper(gameInfo[bundleid]["name"]:sub(1,1)).."*",8,0,kTextAlignment.center)
        gfx.unlockFocus()
        gfx.lockFocus(icon)
        letter:drawScaled(0,1,4)
    end
    if drawIconBorders then
        gfx.setLineWidth(4)
        gfx.setColor(invertedColors[invertborders])
        gfx.drawRoundRect(1,1,64,64,8)
    end
    gfx.unlockFocus()
    gameInfo[bundleid]["icon"] = icon
end

function setupGameInfo()
    playdate.system.updateGameList()
    gameInfo = {}
    columns = 2
    loopy = -1
    local i = Opts:read("emptydither", true, true)
    i = 1- 0.25*i
    setEmptyIcon(i)
    groups = playdate.system.getInstalledGameList()
    for i,v in ipairs(groups) do
        for j,v2 in ipairs(v) do
            loopy+=1
            if loopy > rows then
                loopy = 0
                columns += 1
            end
            if gme.getPath(v2) then

                local gamePath = gme.getPath(v2)
                if gme.getBundleID(v2) then
                    local props = playdate.system.getMetadata(gamePath .. "/pdxinfo")
                    props["path"] = gme.getPath(v2)
                    props["group"] = v.name
                    local newprops = {}
                    for k,v in pairs(props) do
                        newprops[string.lower(k)] = v
                    end
                    gameInfo[gme.getBundleID(v2)] = newprops
                end
            else
                print("INVALID GAME")
                return false
            end
        end
    end
    print("finished 1")
    local i = -1
    gameGrid = {}
    for k,v in pairs(gameInfo) do
        if not (v["group"] == "System") then
            i += 1
            if  i < 16 then
                loadIcon(k)
            end
            table.insert(gameGrid,k)
        end
    end
    print("finished 2")
    sortGameGrid()
    if first_load then
        table.insert(gameGrid,".empty")
        table.insert(gameGrid,".empty")
        table.insert(gameGrid,".empty")
        for i,v in ipairs(labels) do
            table.insert(gameGrid,".empty")
            table.insert(gameGrid,".empty")
        end
    end
    print("finished 3")
    return true
end

main()

function updateCardCursor()
    if contentWarningState == 0 then
        cardImg:drawCentered(200,110)
        
    elseif contentWarningState == 1 then
        
        gfx.drawTextInRect("*"..gameInfo[cardLaunchGame]["contentwarning"].."*", 20, 50, 360, 75, 2, "\226\128\166", kTextAlignment.center)
    elseif contentWarningState == 2 then
        
        gfx.drawTextInRect("*"..gameInfo[cardLaunchGame]["contentwarning2"].."*", 20, 50, 360, 75, 2, "\226\128\166", kTextAlignment.center)
    end
    if playdate.buttonJustPressed("b") then
        cardShowing = false
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
        reloadIconsNextFrame = true
    end
    if playdate.buttonJustPressed("a") then
        reloadIconsNextFrame = true
        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
        appearSound:play()
        if contentWarningState == 0 then
            saveConfig()
        end
        local cw = gameInfo[cardLaunchGame]["contentwarning"]
        local cw2 = gameInfo[cardLaunchGame]["contentwarning2"]
        if not cw then
            playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
        elseif not cw2 then
            if contentWarningState == 0 then
                contentWarningState = 1
            else
                playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
            end
        else
            if contentWarningState == 0 then
                contentWarningState = 1
            elseif contentWarningState == 1 then
                contentWarningState = 2
            else
                playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
            end
        end
    end
end

function playdate.update()
    
    gfx.clear()
    if not Opts:isVisible() then
        gfx.sprite.update()
    end
    playdate.timer.updateTimers()
    if reloadIconsNextFrame then
        drawIcons()
        reloadIconsNextFrame = false
    else
        iconsImage:draw(0,0)
    end
    if inputDelay > 0 then inputDelay -= 1 end
    if not Opts:isVisible() then
        if not playdate.keyboard.isVisible() and not cardShowing then
            updateCursor()
        elseif cardShowing then
            updateCardCursor()
        end
    end

    if Opts:isVisible() then
        local img = gfx.getWorkingImage()
        local spr = gfx.sprite.new()
        spr:add()
        spr:moveTo(200,120)
        spr:setImage(img)
        gfx.sprite.update()
        spr:remove()
    end
    --img:draw(0,0)
    --playdate.drawFPS(0,0)
end



function playdate.keyboard.keyboardWillHideCallback(pressedOK)
    if not pressedOK and editingLabel ~= 0 then
        table.remove(labels,editingLabel)
        drawIcons()
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
    elseif pressedOK and editingLabel ~= 0 then
        sortLabels()
        drawIcons()
        saveConfig()
        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
        appearSound:play()
    end
end

function playdate.keyboard.textChangedCallback()
    if editingLabel ~= 0 then
        labels[editingLabel]["name"] = playdate.keyboard.text
        drawIcons()
    end
end

function toggleLabel(x)
    local newLabels = {}
    local foundLabel = false
    for i,v in ipairs(labels) do
        if v["x"] ~= x or v["name"] == "Home" then
            table.insert(newLabels,v)
        end
        if v["x"] == x then
            foundLabel = true
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
        end
    end
    labels = newLabels
    if not foundLabel then
        table.insert(gameGrid,".empty")
        table.insert(gameGrid,".empty")
        editingLabel = 0
        for i,v in ipairs(labels) do
            if v["x"] < x then
                editingLabel = i+1
            end
        end
        if firstEdit then 
            t = "." 
            firstEdit = false 
        else 
            t = "" 
        end
        playdate.keyboard.show("New Label"..t)
        table.insert(labels, editingLabel, {["name"] = playdate.keyboard.text, ["x"] = x})
        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
        appearSound:play()
        sortLabels()
    end
    local newLabels = {}
    for i,v in ipairs(labels) do
        if v["x"] <= math.ceil(#gameGrid/rows) then
            table.insert(newLabels,v)
        end
    end
    if #newLabels < #labels then
        local deleted = 0
        for i=1,#gameGrid,1 do
            if gameGrid[i] == ".empty" and deleted < (#labels-#newLabels)*2 then
                deleted+=1
                table.remove(gameGrid,i)
                print("BAMM")
                i-=1
            end
        end
    end
    labels = newLabels
    while cursorx > math.ceil(#gameGrid/rows) do
        moveLeft()
    end
    while indexFromPos(cursorx,cursory) > #gameGrid do
        moveUp()
    end
    saveConfig()
    drawIcons()
end

function updateCursor()
    gfx.setLineWidth(6)
    gfx.setColor(invertedColors[invertcursor])
    gfx.drawRoundRect(cursordrawx*72-49, cursordrawy*72-55 - iconOffsetY,64,64,8)
    if iconsImage:sample(cursordrawx*72-45, cursordrawy*72-51 - iconOffsetY) == gfx.kColorBlack then
        gfx.setColor(invertedColors[ not invertcursor])
        gfx.setLineWidth(1)
        gfx.drawRoundRect(cursordrawx*72-48, cursordrawy*72-54 - iconOffsetY,62,62,6)
    end
    if organizeMode and selectedBadge ~= nil then
        if selectedBadgeImage then
            local drawx = ((cursordrawx*72)-57)
            local drawy = ((cursordrawy*72)-63) - iconOffsetY
            local w,h = selectedBadgeImage:getSize()
            local img = gfx.image.new(w,h,gfx.kColorClear)
            gfx.lockFocus(img)
            gfx.setLineWidth(2)
            gfx.setPattern({0,255,0,255,0,255,0,255,255,0,255,0,255,0,255,0})
            gfx.fillRoundRect(0,0,w,h,8)
            gfx.unlockFocus(img)
            img:drawCentered(drawx + 4+ w/2,drawy+4 + h/2)
            
            selectedBadgeImage:drawCentered(drawx + w/2,drawy + h/2)
        end
    end
    if playdate.buttonJustPressed("left") and not playdate.buttonIsPressed("b") then 
        removeKeyTimer()
        local timerCallback = function()
            moveLeft()
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
        drawIcons()
    end
    if playdate.buttonJustReleased("left") then
        removeKeyTimer()
    end
    if  playdate.buttonJustPressed("right") and not playdate.buttonIsPressed("b") then 

        removeKeyTimer()
        local timerCallback = function()
            moveRight()
            appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
            appearSound:play()
    
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("right") then
        removeKeyTimer()
    end
    if playdate.buttonJustPressed("down") and not playdate.buttonIsPressed("b") then 
        removeKeyTimer()
        local timerCallback = function()
            moveDown()
            appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("down") then
        removeKeyTimer()
    end
    if playdate.buttonJustPressed("up") and not playdate.buttonIsPressed("b") then 
        removeKeyTimer()
        local timerCallback = function()
            moveUp()
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("up") then
        removeKeyTimer()
    end
    if playdate.buttonJustPressed("a") then
        if not organizeMode then
            local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
            if game then
                cardLaunchGame = gameGrid[indexFromPos(cursorx,cursory)]
                loadCard(cardLaunchGame)
                cardImg = game["card"]
                appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                appearSound:play()
                reloadIconsNextFrame = true
                cardShowing = true
                contentWarningState = 0
            else

                appearSound = playdate.sound.fileplayer.new("systemsfx/04-denial-trimmed")
                appearSound:play()
            end
        else
            if selectedBadge == nil then
                selectedBadgeOriginX = cursorx
                selectedBadgeOriginY = cursory
                if gameGrid[indexFromPos(cursorx,cursory)]:sub(1,7) == ".badge:" then
                    local badge = table.remove(gameGrid,indexFromPos(cursorx,cursory))
                    table.insert(gameGrid,indexFromPos(cursorx,cursory),".tempblank")
                    selectedBadge = badge
                    selectedBadgeImage = badgeIcons[badge]
                    reloadIconsNextFrame = true
                    appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                    appearSound:play()
                elseif gameGrid[indexFromPos(cursorx,cursory)] ~= ".tempblank" then
                    local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
                    if game then
                        local badge = table.remove(gameGrid,indexFromPos(cursorx,cursory))
                        table.insert(gameGrid,indexFromPos(cursorx,cursory),".tempblank")
                        selectedBadge = badge
                        selectedBadgeImage = gameInfo[badge]["icon"]
                        reloadIconsNextFrame = true
                        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                        appearSound:play()
                    else
        
                        appearSound = playdate.sound.fileplayer.new("systemsfx/04-denial-trimmed")
                        appearSound:play()
                    end
                end
            else --if have badge 
                local swapObject = table.remove(gameGrid,(indexFromPos(cursorx,cursory)))
                if swapObject ~= ".tempblank" then
                    local found = false
                    local index = 0
                    for i,v in ipairs(iconPlacements) do
                        if v["name"] == swapObject and v["x"] == cursorx and v["y"] == cursory and not found then
                            found = true
                            index = i
                        end
                    end
                    local x,y = posFromIndex(indexFromPos(selectedBadgeOriginX,selectedBadgeOriginY))
                    if found then
                        iconPlacements[index] = {["name"] = swapObject, ["x"] = x, ["y"] = y}
                    else
                        table.insert(iconPlacements, {["name"] = swapObject, ["x"] = x, ["y"] = y})
                    end
                end
                table.insert(gameGrid,(indexFromPos(cursorx,cursory)),selectedBadge)
                
                local found = false
                local index = 0
                for i,v in ipairs(iconPlacements) do
                    if v["name"] == selectedBadge and not found then
                        found = true
                        index = i
                    end
                end
                if found then
                    iconPlacements[index] = {["name"] = selectedBadge, ["x"] = cursorx, ["y"] = cursory}
                else
                    table.insert(iconPlacements, {["name"] = selectedBadge, ["x"] = cursorx, ["y"] = cursory})
                end

                selectedBadgeImage = nil
                selectedBadge = nil
                reloadIconsNextFrame = true
                local newGameGrid = {}
                for i,v in ipairs(gameGrid) do
                    if v ~= ".tempblank" then
                        table.insert(newGameGrid,v)
                    else
                        table.insert(newGameGrid,swapObject)
                    end
                end
                gameGrid = newGameGrid   
                appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                appearSound:play()
                
                doLabelExpansionStuff()
                iconSaveNuclearOption()
            end
        end
    end
    if playdate.buttonIsPressed("b") and not organizeMode then
        if playdate.buttonJustPressed("left") then
            moveLabels(-1)
        end
        if playdate.buttonJustPressed("right") then
            moveLabels(1)
        end
    end
    if playdate.buttonJustPressed("b") then
       if organizeMode and selectedBadge ~= nil then
            for i,v in ipairs(gameGrid) do
                if v == ".tempblank" then
                    table.remove(gameGrid,i)
                    table.insert(gameGrid ,i, selectedBadge)
                    selectedBadge = nil
                    reloadIconsNextFrame = true
                    appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                    appearSound:play()
                    break
                end
            end 
        elseif organizeMode then
            toggleLabel(cursorx)
        end
    end
    setCurrentLabel()
end

function setCurrentLabel()
    local currentcurrentLabel = currentLabel
    currentLabel = nil
    for i,v in ipairs(labels) do
        if indexFromPos(v["x"],1) <= indexFromPos(cursorx,cursory) then
            currentLabel = v["name"]
        end
    end
    if not currentLabel then
        currentLabel = labels[#labels]["name"]
    end
    if currentcurrentLabel ~= currentLabel then
        reloadIconsNextFrame = true
    end
end

function moveLabels(dirint)
    local index = 0
    for i,v in ipairs(labels) do
        if v["name"] == currentLabel then
            index = i
            break
        end
    end
    index+= dirint
    local x,y = 0,0
    while index > #labels do
        index = #labels
    end
    while index < 1 do
        index = 1
    end
    x = labels[index]["x"]
    y = 1
    while cursorx < x do
        moveRight(true)
    end
    while cursorx > x do
        moveLeft(true)
    end
    while cursory > y do
        moveUp(true)
    end
    while cursory < y do
        moveDown(true)
    end
    reloadIconsNextFrame = true
end

function iconSaveNuclearOption()
    iconPlacements = {}
    for i,v in ipairs(gameGrid) do
        if v ~= ".tempblank" then
            local found = false
            local index = 0
            for i,v in ipairs(iconPlacements) do
                if v["name"] == v and not found then
                    found = true
                    index = i
                end
            end
            local x,y = posFromIndex(i)
            if found and v ~= ".empty" then
                iconPlacements[index] = {["name"] = v, ["x"] = x, ["y"] = y}
            else
                table.insert(iconPlacements, {["name"] = v, ["x"] = x, ["y"] = y})
            end
        end
    end
    saveConfig()
end

function doLabelExpansionStuff()
    if organizeMode then
        local expand = false
        for i,v in ipairs(labels) do
            if v["x"] == cursorx+1 then
                if gameGrid[indexFromPos(cursorx,1)]  ~= ".empty" and gameGrid[indexFromPos(cursorx,2)]  ~= ".empty" and gameGrid[indexFromPos(cursorx,3)]  ~= ".empty" and selectedBadge ~= nil then
                    expand = true
                end
            end
        end
        if expand then
            table.insert(gameGrid,indexFromPos(cursorx+1,1),".empty")
            table.insert(gameGrid,indexFromPos(cursorx+1,1),".empty")
            table.insert(gameGrid,indexFromPos(cursorx+1,1),".empty")
            local newLabels = {}
            for i,v in ipairs(labels) do
                if v["x"] < cursorx then
                    table.insert(newLabels,v)
                else
                    local newLabel = {["name"] = v["name"], ["x"] = v["x"]+1}
                    table.insert(newLabels,newLabel)
                end
            end
            for i=2,2,1 do
                for y=1,3,1 do
                table.insert(iconPlacements, {["name"] = gameGrid[indexFromPos(cursorx+i,y)], ["x"] = cursorx+i, ["y"] = y})
                end
            end
            labels = newLabels
            sortLabels()
            iconSaveNuclearOption()
            reloadIconsNextFrame = true
        end
    end
end

function moveUp(fast) 
    if gameGrid[indexFromPos(cursorx,cursory-1)] and cursory > 1 then
        cursory -= 1
        cursordrawy -= 1
        if cursory < 1 then
            cursory = 1
            cursordrawy = 1
        end
        if cursordrawy > 1 then recentCursorDown = 1 else recentCursorDown = 0 end
        
    end
    if not fast then
        drawIcons()
        doLabelExpansionStuff()
    end
end

function moveDown(fast)
    if gameGrid[indexFromPos(cursorx,cursory+1)] and cursory < rows then
        cursory += 1
        cursordrawy += 1
        
        if cursory > rows then
            cursory = rows
            cursordrawy = rows
        end
        if cursordrawy > 1 then recentCursorDown = 1 else recentCursorDown = 0 end
        
    end
    if not fast then
        drawIcons()
        doLabelExpansionStuff()
    end
end

function moveRight(fast)
    if gameGrid[indexFromPos(cursorx+1,cursory)] then
        cursorx += 1
        if cursordrawx < 5 then
            cursordrawx += 1
        else
            iconOffsetX += 1
        end
        if cursordrawx > 3 then recentCursorRight = 1 end
        
    end
    if not fast then
        drawIcons()
        doLabelExpansionStuff()
    end
end

function moveLeft(fast)

    cursorx -= 1    
    if cursordrawx > 1 then
        
        cursordrawx -= 1
    elseif cursorx >= 1 then
        iconOffsetX -= 1
    end
    if cursorx < 1 then
        cursorx = 1
    else 
        if cursordrawx < 3 then recentCursorRight = 0 end
        
    end
    if not fast then
        drawIcons()
        doLabelExpansionStuff()
    end
end