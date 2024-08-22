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

local bottomBar = true

local useCustomIconAnimation = false

selectedBadgeOriginX = 0
selectedBadgeOriginY = 0

labelImage = nil

movedLabels = false

paddingOffset = 0

editingLabel = 0
firstEdit = true

local showBatteryPercent = false

keyTimer = nil
local canLaunch = true
local initialDelay = 300
local repeatDelay = 40

local cardYpos = 218
local cardYposTarget = -10
local cardInfoShowing = false

blankImg = nil

first_load = true

local cardLaunchGame = nil
local cardImg = nil
cardShowing = false

contentWarningState = 0

local noCrankFrames = 5

local bgdither = 0
local bgditherimg = nil
local invertborders = false
local invertlabels = false
local invertcursor = false
local invertblanks = false

local emptydither = 0.75

local cardAnimationLoops = 0
local cardAnimationFrame = 0
local cardAnimationProps = {}
local cardAnimationState = "off" --off, highlighted, launch
local cardAnimationDoneIntro = false
local cardAnimationStayFrames = 0
local cardAnimationLaunch = true

local iconAnimationLoops = 0
local iconAnimationFrame = 0
local iconAnimationProps = {}
local iconAnimationState = "highlighted" --off, highlighted
local iconAnimationDoneIntro = false
local iconAnimationStayFrames = 0

local noToggleLabelFrames = 3
local unwrapAnimating = false

local music = nil
local musicOn = true

local movingFast = false

local bgImg = nil

local kPDGameStateFreshlyInstalled, kPDGameStateInstalled
if playdate.system ~= nil then
	kPDGameStateFreshlyInstalled = playdate.system.game.kPDGameStateFreshlyInstalled
	kPDGameStateInstalled = playdate.system.game.kPDGameStateInstalled
end

local invertedColors = {[true] = gfx.kColorWhite, [false] = gfx.kColorBlack}
local invertedDrawModes = {[true] = gfx.kDrawModeFillBlack, [false] = gfx.kDrawModeFillWhite}

local skipCard = false

local showBattery = false

Opts = Options(
    {
        { 
            header="Customization", options = {
                {
                    name = "Reduce stuttering",
                    key = "reducestuttering",
                    default = false,
                    tooltip = "If enabled, icons are processed when the launcher starts instead of as you scroll. Longer load times, less stuttering. Open and close a game for this to take effect."
                },
                {
                    name = "Music",
                    key = "musicon",
                    default = true,
                    tooltip = "Whether your music placed in /Shared/FunnyOS will play."
                },
                {
                    name = "Skip Card",
                    key = "skipcard",
                    default = false,
                    tooltip = "When you click on an icon, launch the game without going to the card menu."
                },
                {
                    name = "Show Battery",
                    key = "showbattery",
                    default = false,
                    tooltip = "Switch out the bottom bar for battery and time instead of controls."
                },
                {
                    name = "Battery Percent",
                    key = "batterypercent",
                    default = false,
                    tooltip = "If show battery is selected, this changes the battery icon to show exact percents."
                },
                {
                    name = "Icon Borders",
                    key = "iconborders",
                    default = true,
                    tooltip = "Show borders around list view icons."
                },
                {
                    name = "Invert Borders",
                    key = "invertborders",
                    default = false,
                    tooltip = "Make list view icons borders white."
                },
                {
                    name = "Invert Cursor",
                    key = "invertcursor",
                    default = false,
                    tooltip = "Make the cursor white."
                },
                {
                    name = "Invert Labels",
                    key = "invertlabels",
                    default = false,
                    tooltip = "Make labels white."
                },
                {
                    name = "Invert Blanks",
                    key = "invertblanks",
                    default = false,
                    tooltip = "Make blanks dither white instead of black (good for dark backgrounds)."
                },
                {
                    name = "Background Dither",
                    key = "bgdither",
                    tooltip = "Controls dithering strength applied to background.",
                    style = Options.SLIDER,
                    min = 0,
                    max = 4,
                    default = 0
                },
                {
                    name = "Blank Space Dither",
                    key = "emptydither",
                    tooltip = "Controls dithering strength on spaces without an icon.",
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
        noToggleLabelFrames = 3
    end
)
local unwrapx = 0
local unwrapy = 0
local unwrapxvel = 0
local unwrapyvel = 0
local unwrapmaxvel = 25

local stockLauncherImg = gfx.image.new("images/stocklauncher")
local loadingImg = gfx.image.new("images/loading")
local batteryImg = gfx.image.new("images/battery")
local batteryImgs = gfx.imagetable.new("images/battery-bars")
local wrappedImg = gfx.image.new("images/wrapped")
local newGame = gfx.image.new("images/newgame")
local newGameMask = gfx.image.new("images/newgame_mask")

local crankChange = 0
local crankIncrement = 45

local reduceStuttering = false

function loadOptions(initial)
    gfx.sprite.update()
    reloadIconsNextFrame = true
    if drawIconBorders == nil then drawIconBorders = true Opts:write("iconborders", 2) end
    if showBattery == nil then showBattery = false Opts:write("showbattery", 1) end
    if reduceStuttering == nil then reduceStuttering = false Opts:write("reducestuttering", 1) end
    if showBatteryPercent == nil then showBatteryPercent = false Opts:write("batterypercent", 1) end
    if skipCard == nil then skipCard = false Opts:write("skipcard", 1) end
    if musicOn == nil then drawIconBorders = true Opts:write("musicon", 2) loadMusic() end
    skipCard = Opts:read("skipcard", true, true)
    showBattery = Opts:read("showbattery", true, true)
    reduceStuttering = Opts:read("reducestuttering", true, true)
    showBatteryPercent = Opts:read("batterypercent", true, true)
    if (musicOn ~= Opts:read("musicon", true, true) or initial) and Opts:read("musicon", true, true) == true then
        loadMusic()
    end
    if Opts:read("musicon", true, true) == false then
        if music~= nil then music:stop() end
    end
    musicOn =  Opts:read("musicon", true, true)
    if not musicOn then
        if music then music:stop() end
    end
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
                loadIcon(k,nil,true)
            end
        end
    end
    reloadIconsNextFrame = true
end

function collapseEmptyExpansions()
    for i,v in ipairs(labels) do
        local collapse = false
        local currentx = v["x"]
        if gameGrid[indexFromPos(currentx-1,1)] == ".empty" and gameGrid[indexFromPos(currentx-1,2)] == ".empty" and gameGrid[indexFromPos(currentx-1,3)] == ".empty" then
            collapse = true
        end
        if collapse then
            table.remove(gameGrid,indexFromPos(currentx-1,1))
            table.remove(gameGrid,indexFromPos(currentx-1,1))
            table.remove(gameGrid,indexFromPos(currentx-1,1))
            local newLabels = {}
            for j,v2 in ipairs(labels) do
                if v2["x"] < currentx then
                    table.insert(newLabels,v2)
                else
                    local newLabel = {["name"] = v2["name"], ["x"] = v2["x"]-1}
                    table.insert(newLabels,newLabel)
                end
            end
            labels = newLabels
        end
    end
    reloadIconsNextFrame = true
    iconSaveNuclearOption()
end

function setEmptyIcon(n)
    emptydither = n
    
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(invertedColors[invertblanks])
    blankImg = gfx.image.new(66,66)
    gfx.lockFocus(blankImg)
    gfx.setDitherPattern(n,gfx.image.kDitherTypeBayer4x4)
    gfx.fillRoundRect(0,0,66,66,8)
    gfx.unlockFocus()
    reloadIconsNextFrame = true
    loadOptions()
end

function changeBgDither(n)
    bgdither = n
    
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    local img = gfx.image.new(402,240)
    gfx.lockFocus(img)
    gfx.setDitherPattern(n)
    gfx.fillRect(0,0,402,240)
    gfx.unlockFocus()
    bgditherimg = img
    reloadIconsNextFrame = true
    loadOptions()
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
    movingFast = false
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
    datastore["cursorx"] = cursorx
    datastore["cursory"] = cursory
    playdate.datastore.write(datastore,"/Shared/FunnyOS/funnyConfig")
end

targetcx = 1
targetcy = 1

function loadConfig()
    local datastore = playdate.datastore.read("/Shared/FunnyOS/funnyConfig")
    if datastore == nil then
        datastore = playdate.datastore.read("Funny OS/funnyConfig")
        playdate.datastore.write(datastore,"/Shared/FunnyOS/funnyConfig")
        fle.delete("/System/Data/Funny OS/funnyConfig.json")
        saveConfig()
    end
    if datastore then
        iconPlacements = datastore["iconPlacements"]
        labels = datastore["labels"]
        targetcx = datastore["cursorx"]
        targetcy = datastore["cursory"]

    else
        first_load = true
    end
    if not iconPlacements then iconPlacements = {} end
    if not targetcx then targetcx = 1 end
    if not targetcy then targetcy = 1 end
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
            if not found and (v["x"] ~= nil and v["y"] ~= nil) then
                while indexFromPos(v["x"],v["y"]) > #gameGrid-1 do
                    table.insert(gameGrid,#gameGrid-1,".empty")
                end
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
local actualIconOffsetX = 0
function drawIcons()
    local paddingAmount = 30
    gfx.clear()
    if bgImg then
        bgImg:drawCentered(200,120)
    end
    if bgditherimg then
        bgditherimg:draw(0,0)
    end

    for i,v in ipairs(gameGrid) do
        if not (cardShowing and contentWarningState > 0) then
            local found = false
            gridx,gridy = posFromIndex(i)
            local drawx = ((gridx*72)-52)-actualIconOffsetX*72  + 2 - getOffset(cursorx)*paddingAmount
            local drawy = ((gridy*72)-56)-iconOffsetY
            drawx,drawy = math.floor(drawx),math.floor(drawy)
            drawx+=getOffset(gridx)*paddingAmount
            if (drawx < 400 and drawx > -100) then
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
                    local xoff = 0
                    if drawx%2 == 0 then
                        xoff =  1
                    end
                    blankImg:draw(drawx-xoff,drawy)
                elseif v == ".stockLauncher" then
                    stockLauncherImg:draw(drawx,drawy)
                elseif gameInfo[v] then
                    if not gameInfo[v]["icon"] then
                        loadIcon(v)
                    end
                    gameInfo[v]["icon"]:draw(drawx,drawy)
                end
            end
        end
    end
    local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
    local t = ""
    if game then
        t = game.name
    elseif gameGrid[indexFromPos(cursorx,cursory)] == ".stockLauncher" then
        t = "Boot to Stock Launcher"
    end
    if not (cardShowing and contentWarningState > 0) and t ~= "" then
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

    iconsImage = gfx.getWorkingImage()
end

function reloadBadges()
    local files = fle.listFiles("/Shared/FunnyOS/Badges")
    local added = 0
    local badgeCountInit = 0
    for i,v in ipairs(iconPlacements) do
        if v["name"] then
            if v["name"]:sub(1,7) == ".badge:" then
                badgeCountInit += 1
            end
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
        if v["name"] then
            if v["name"]:sub(1,7) == ".badge:" then
                local img = gfx.image.new("/Shared/FunnyOS/Badges/"..v["name"]:sub(8,#v["name"])..".pdi")
                if img then
                    local w,h = img:getSize()
                    if w <= 68 then size = 64 else size = 72 end
                    img = img:scaledImage(1/(w/size))
                    badgeIcons[v["name"]] = img    
                    table.insert(newIconPlacements, v)
                end
            else
                table.insert(newIconPlacements, v)
            end
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
            if v.x ~= nil and v.y ~= nil then
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
    end
    iconPlacements = newIconPlacements
    newIconPlacements = {}

    for i,v in ipairs(iconPlacements) do
        if gameInfo[v["name"]] or v["name"] == ".empty" or v["name"]:sub(1,7) == ".badge:" or v["name"] == ".stockLauncher" then 
            table.insert(newIconPlacements,v) 
        else 
            table.insert(newIconPlacements,{["name"] = ".empty", ["x"] = v["x"], ["y"] = v["y"]}) 
        end
    end
    iconPlacements = newIconPlacements
    if iconPlacements == {} then
        iconPlacements={{["name"]=".empty",["x"]=1,["y"]=1}}
    end
end

function badgeSetup()
    if not fle.isdir("/Shared/FunnyOS/Badges") then
        fle.mkdir("/Shared/FunnyOS/Badges")
    end
    --playdate.datastore.write(badges, "/Shared/FunnyOSBadges/badges")
    reloadBadges()
end

function dirSetup()
    if fle.isdir("/Shared/FunnyOSBadges") then
        local data = playdate.datastore.read("/Shared/FunnyOSBadges/funnyConfigBackup")
        if data then playdate.datastore.write(data,"/Shared/FunnyOS/funnyConfig") end
        local files = fle.listFiles("/Shared/FunnyOSBadges")
        for i,v in ipairs(files) do
            if v:sub(#v-3,#v) == ".pdi" then
                local i = playdate.datastore.readImage("/Shared/FunnyOSBadges/"..v)
                playdate.datastore.writeImage(i, "/Shared/FunnyOS/Badges/"..v)
            end
        end
        playdate.file.delete("/Shared/FunnyOSBadges", true)
    end
    local img = gfx.image.new("/Shared/FunnyOS/bg.pdi")
    fle.mkdir("/Shared/FunnyOS/Icons")
    if img then
        local w,h = img:getSize()
        img = img:scaledImage(1/(w/400))
        bgImg = img
    end
end

function loadMusic()
    music = playdate.sound.fileplayer.new("/Shared/FunnyOS/bgm")
    if music ~= nil then
        music:play()
        music:setFinishCallback(function() playdate.timer.performAfterDelay(10000, function() if musicOn then loadMusic() end end ) end)
    end
end

function moveUp(fast) 
    loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
    if gameGrid[indexFromPos(cursorx,cursory-1)] and cursory > 1 then
        cursory -= 1
        cursordrawy -= 1
        if cursory < 1 then
            cursory = 1
            cursordrawy = 1
        end
        if cursordrawy > 1 then recentCursorDown = 1 else recentCursorDown = 0 end
        
    end
    iconAnimationState = "highlighted"
    if not fast then
        startIconAnimation()
        doLabelExpansionStuff()
    end
    reloadIconsNextFrame = true
end

function moveDown(fast)
    loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
    if gameGrid[indexFromPos(cursorx,cursory+1)] and cursory < rows then
        cursory += 1
        cursordrawy += 1
        
        if cursory > rows then
            cursory = rows
            cursordrawy = rows
        end
        if cursordrawy > 1 then recentCursorDown = 1 else recentCursorDown = 0 end
        
    end
    iconAnimationState = "highlighted"
    if not fast then
        startIconAnimation()
        doLabelExpansionStuff()
    end
    reloadIconsNextFrame = true
end

function moveRight(fast)
    loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
    if gameGrid[indexFromPos(cursorx+1,cursory)] then
        cursorx += 1
        if cursordrawx < 5 then
            cursordrawx += 1
        else
            iconOffsetX += 1
        end
        if cursordrawx > 3 then recentCursorRight = 1 end
        
    end
    iconAnimationState = "highlighted"
    if not fast then
        startIconAnimation()
        doLabelExpansionStuff()
    end
    reloadIconsNextFrame = true
end

function moveLeft(fast)
    loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
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
    iconAnimationState = "highlighted"
    if not fast then
        startIconAnimation()
        doLabelExpansionStuff()
    end
    reloadIconsNextFrame = true
end

function wrapPatternForGame(game)
	local pattern
	if nil ~= game then
		local info = gameInfo[game:getBundleID()]
		if nil ~= info["imagepath"] then
			local imagepath = info.imagepath .. "/wrapping-pattern.pdi"
            if info.imagepath:sub(#info.imagepath,#info.imagepath) == "/" then
			imagepath = info.imagepath .. "wrapping-pattern.pdi"
            end
			pattern = gfx.image.new(info["path"].."/"..imagepath)
		end
	end
	if nil == pattern then
		pattern = gfx.image.new("images/default_pattern")
	end
	return pattern
end

function loadCard(bundleid , i)
    local imageName = i
    if imageName == nil then imageName = "card" end
    local icon = gfx.image.new(358, 163,gfx.kColorClear)
    gfx.lockFocus(icon)
    for i,v in ipairs(groups) do
        if v.name == gameInfo[bundleid]["group"] then
            for j,v2 in ipairs(v) do
                if v2:getBundleID() == bundleid then
                    game = v2
                end
            end
            break
        end
    end
    if game and gameInfo[bundleid] then
        if game:getInstalledState() == kPDGameStateFreshlyInstalled then
            local pattern = wrapPatternForGame(game)
            local wrappingPattern = gfx.image.new(400, 240, gfx.kColorClear)
            gfx.lockFocus(wrappingPattern)
            newGame:draw(0, 0)
            gfx.setStencilImage(newGameMask)
            pattern:draw(0, 0)
            gfx.lockFocus(icon)
            gameInfo[bundleid]["wrap"] = wrappingPattern
        else
            gameInfo[bundleid]["wrap"] = nil
        end
    end
    local drawletter = false
    local look_for_icon = true
    if gameInfo[bundleid]["imagepath"] and look_for_icon then
        local gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/"..imageName)
        if gameicon then
            gameicon:draw(4,4)
        else
            gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/card")
            if gameicon then
                gameicon:draw(4,4)
            else
                drawletter = true
            end
        end
    elseif not look_for_icon then
        
        drawletter = true
    end
    if drawletter and look_for_icon then
        local f = gfx.getLargeUIFont()
        local t = gameInfo[bundleid]["name"]
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(0,0,358,163,8)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextInRect(t, 20,66,317, 50, 0, "\226\128\166", kTextAlignment.center, f)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    gfx.unlockFocus()
    gameInfo[bundleid]["card"] = icon
end

function loadIcon(bundleid , i,force_load)
    if force_load == nil then force_load = false end
    if gameInfo[bundleid] then
        local game
        for i,v in ipairs(groups) do
            if v.name == gameInfo[bundleid]["group"] then
                for j,v2 in ipairs(v) do
                    if v2:getBundleID() == bundleid then
                        game = v2
                    end
                end
                break
            end
        end
        if game then
            if game:getInstalledState() == kPDGameStateFreshlyInstalled then
                gameInfo[bundleid]["icon"] = wrappedImg 
                return
            end
        end
        local imageName = i
        local getDefaultIcon = false
        if imageName == nil then imageName = "icon" getDefaultIcon = true end
        if getDefaultIcon and  gameInfo[bundleid]["defaultIcon"] and not force_load and not fle.isdir("/Shared/FunnyOS/Icons/"..bundleid) then
            gameInfo[bundleid]["icon"] = gameInfo[bundleid]["defaultIcon"]      
            return 
        end
        local icon = gfx.image.new(66, 66, gfx.kColorClear)
        gfx.lockFocus(icon)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(2,2,62,62,8)
        local drawletter = false
        local look_for_icon = true
        if fle.isdir("/Shared/FunnyOS/Icons/"..bundleid) then
            if fle.exists("/Shared/FunnyOS/Icons/"..bundleid.."/"..imageName..".pdi") then
                look_for_icon = false
                local gameicon = gfx.image.new("/Shared/FunnyOS/Icons/"..bundleid.."/"..imageName)
                if gameicon then
                    local w,h = gameicon:getSize()
                    gameicon:drawScaled(1,1,1/(w/64))
                    look_for_icon = false
                end
            end
        end
        for i,v2 in ipairs(season_1) do
            if string.lower(v2) == string.lower(bundleid) and look_for_icon then
                local gameicon = gfx.image.new("s1_icons/"..v2..".pdi")
                if gameicon then
                    gameicon:drawScaled(1,1,2)
                    look_for_icon = false
                break
                end
            end 
        end
        if gameInfo[bundleid]["imagepath"] and look_for_icon then
            local gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/"..imageName)
            if gameicon then
                gameicon:drawScaled(1,1,2)
            else
                gameicon = gfx.image.new(gameInfo[bundleid]["path"] .."/"..gameInfo[bundleid]["imagepath"].."/icon")
                if gameicon then
                    gameicon:drawScaled(1,1,2)
                else
                    drawletter = true
                end
            end
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
        if getDefaultIcon then
            gameInfo[bundleid]["defaultIcon"] = icon
        end
        gameInfo[bundleid]["icon"] = icon
    end
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
    local i = -1
    gameGrid = {}
    for k,v in pairs(gameInfo) do
        if  (v["group"] ~= "System") or (v["bundleid"] == "com.panic.catalog" or v["bundleid"] == "com.panic.settings") then
            i += 1
            if  i < 16 then
                loadIcon(k)
            end
            table.insert(gameGrid,k)
        end
    end
    sortGameGrid()
    table.insert(gameGrid,".stockLauncher")
    if first_load then
        table.insert(gameGrid,".empty")
        table.insert(gameGrid,".empty")
        table.insert(gameGrid,".empty")
        for i,v in ipairs(labels) do
            table.insert(gameGrid,".empty")
            table.insert(gameGrid,".empty")
        end
    end
    saveConfig()
    return true 
end

--THIS FUNCTION IS SCRATCH'S
function parseAnimFile(animFile)
	if nil == animFile then
		return {loop = 0}
	end
	local info = {}
	local line = animFile:readline()
	local frames = {}
	local introFrames
	local addFramesToTable = function(frameTable, frameValues)
		for word in string.gmatch(frameValues, "%s*([^,]+)") do
			local r = 1
			local frame = tonumber(word)
			if nil == frame then
				frame, r = string.match(word, "(%d+) -x -(%d+)")
				if nil ~= frame then
					frame = tonumber(frame)
				end
				if nil ~= r then
					r = tonumber(r)
				end
			end
			if nil ~= frame and frame > 0 and nil ~= r and r > 0 then
				for i = 1, r do
					table.insert(frameTable, frame)
				end
			end
		end
	end
	while nil ~= line do
		local key, value = string.match(line, "%s*(.-)%s*=%s*(.+)")
		if nil ~= key and nil ~= value then
			key = key:lower()
			if "frames" == key then
				addFramesToTable(frames, value)
			elseif "introframes" == key then
				introFrames = {}
				addFramesToTable(introFrames, value)
			elseif "loopcount" == key then
				local count = tonumber(value)
				if nil ~= count and count > 0 then
					info.loop = count
				end
			end
			line = animFile:readline()
		end
	end
	if #frames > 0 then
		info.frames = frames
		info.introFrames = introFrames
	end
	info.loop = info.loop or 0
	return info
end

function startCardAnimation()
    playdate.display.setRefreshRate(20)
    cardAnimationState = "highlighted"
    cardAnimationFrame = 0
    cardAnimationLoops = 0
    cardAnimationStayFrames = 2
    cardAnimationDoneIntro = false
    if gameInfo[cardLaunchGame]["imagepath"] then
        c = fle.open(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/card-highlighted/animation.txt")
        if c then
        cardAnimationProps = parseAnimFile(c)
        c:close()
        else
            local files = fle.listFiles(gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["path"] .. "/"..gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"].."/card-highlighted/")
            if files and #files > 0 then
                cardAnimationProps = {}
                cardAnimationProps["loop"] = 1
                local frames = {}
                for i,v in ipairs(files) do
                    if v:sub(#v-3,#v) == ".pdi" then
                        local t = tonumber(v:sub(1,#v-4))
                        if #frames == 0 then
                            table.insert(frames,t)
                        else
                            local found = falee
                            for i,v in ipairs(frames) do
                                if v < t then
                                    found = true
                                    table.insert(frames,i,t)
                                    break
                                end
                            end
                            if not found then
                                table.insert(frames,t)
                            end
                        end
                    end
                end
                cardAnimationProps["frames"] = frames
            else
                iconAnimationProps = nil
            end
        end
    else
        cardAnimationState = "off"
    end
end

function startIconAnimation()
    if gameGrid[indexFromPos(cursorx,cursory)] ~= ".empty" and gameGrid[indexFromPos(cursorx,cursory)]:sub(1,7) ~= ".badge:" and gameGrid[indexFromPos(cursorx,cursory)] ~= ".stocklauncher" then
        
    else
        iconAnimationState = "off"
        return
    end
    playdate.display.setRefreshRate(20)
    iconAnimationState = "highlighted"
    iconAnimationFrame = 0
    iconAnimationLoops = 0
    iconAnimationStayFrames = 2
    iconAnimationDoneIntro = false
    local findIcon = true
    local c
    useCustomIconAnimation = false
    if fle.exists("/Shared/FunnyOS/Icons/"..gameGrid[indexFromPos(cursorx,cursory)].."/".."icon"..".pdi") then
        c = fle.open("/Shared/FunnyOS/Icons/"..gameGrid[indexFromPos(cursorx,cursory)].."/icon-highlighted/".."animation"..".txt")
        useCustomIconAnimation = true
    elseif gameInfo[gameGrid[indexFromPos(cursorx,cursory)]] and gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"] then
        c = fle.open(gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["path"] .. "/"..gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"].."/icon-highlighted/animation.txt")
    else
        iconAnimationState = "off"
    end
    if c then
        iconAnimationProps = parseAnimFile(c)
        c:close()
    elseif useCustomIconAnimation then
        local files = fle.listFiles("/Shared/FunnyOS/Icons/"..gameGrid[indexFromPos(cursorx,cursory)].."/icon-highlighted/".."animation"..".txt")
        if files and #files > 0 then
            iconAnimationProps = {}
            iconAnimationProps["loop"] = 1
            local frames = {}
            for i,v in ipairs(files) do
                if v:sub(#v-3,#v) == ".pdi" then
                    local t = tonumber(v:sub(1,#v-4))
                    if #frames == 0 then
                        table.insert(frames,t)
                    else
                        local found = falee
                        for i,v in ipairs(frames) do
                            if v < t then
                                found = true
                                table.insert(frames,i,t)
                                break
                            end
                        end
                        if not found then
                            table.insert(frames,t)
                        end
                    end
                end
            end
            iconAnimationProps["frames"] = frames
        else
            iconAnimationProps = nil
        end
    elseif gameInfo[gameGrid[indexFromPos(cursorx,cursory)]] then
        if gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"] then
            local files = fle.listFiles(gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["path"] .. "/"..gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"].."/icon-highlighted/")
            if files and #files > 0 then
                iconAnimationProps = {}
                iconAnimationProps["loop"] = 1
                local frames = {}
                for i,v in ipairs(files) do
                    if v:sub(#v-3,#v) == ".pdi" then
                        local t = tonumber(v:sub(1,#v-4))
                        if #frames == 0 then
                            table.insert(frames,t)
                        else
                            local found = falee
                            for i,v in ipairs(frames) do
                                if v < t then
                                    found = true
                                    table.insert(frames,i,t)
                                    break
                                end
                            end
                            if not found then
                                table.insert(frames,t)
                            end
                        end
                    end
                end
                iconAnimationProps["frames"] = frames
            else
                iconAnimationProps = nil
            end
        end
    end
end

function startCardLaunchAnimation()
    cardAnimationState = "launch"
    cardAnimationFrame = 0
    playdate.display.setRefreshRate(20)
    if gameInfo[cardLaunchGame]["launchsoundpath"] then
        if music then music:stop() end
        local launchSound = playdate.sound.fileplayer.new(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["launchsoundpath"]..".pda")
        if launchSound then
            launchSound:play()
        else
            appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
            appearSound:play()
        end
    else
        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
        appearSound:play()
    end
    if gameInfo[cardLaunchGame]["imagepath"] then
        cardAnimationLaunch = fle.isdir(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/launchImages")
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0,0,400,240)
        
        playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
    end
end
function lerp(a,b,t) return a * (1-t) + b * t end
function lerpFloored(a,b,t) return math.floor(a * (1-t) + b * t) end

function playdate.deviceWillLock()
    if selectedBadge == nil then
        iconsImage = nil
        cardImg = nil
        cardCursorImg = nil
        music = nil
        reloadIconsNextFrame = true
        collectgarbage("collect")
        saveConfig()
    end
end

function playdate.deviceWillUnlock()
    if selectedBadge == nil then
        reloadIconsNextFrame = true
        main()
    end
end

function updateCardCursor()
    if cardYpos ~= cardYposTarget then
        cardYpos=lerpFloored(cardYpos,cardYposTarget,0.2*(40/playdate.display.getRefreshRate()))
        reloadIconsNextFrame = true
    end
    if math.abs(math.abs(cardYpos)-math.abs(cardYposTarget)) < 2 then cardYpos = cardYposTarget end
    cardCursorImg = gfx.image.new(400,470,gfx.kColorClear)
    gfx.lockFocus(cardCursorImg)
    if contentWarningState == 0 or cardAnimating then
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setColor(gfx.kColorBlack)
        gfx.setPattern({255,0,255,0,255,0,255,0})
        if cardYpos > -10 then
            gfx.fillRoundRect(0,0,400,240 ,10)
        else
            gfx.fillRoundRect(0,-cardYpos-240,400,480 ,10)
        end
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(25,270,350,240 ,10)
        local f = gfx.getLargeUIFont()
        local t = gameInfo[cardLaunchGame]["name"]
        gfx.drawTextInRect(t, 35,280,330, 50, 0, "\226\128\166", kTextAlignment.center, f)
        local f = gfx.getUIFont()
        local t = gameInfo[cardLaunchGame]["description"]
        if t then
            gfx.setColor(gfx.kColorBlack)
            gfx.drawTextInRect(t, 30,320,340, 100, 0, "\226\128\166", kTextAlignment.center, f)
        end
        local t = gameInfo[cardLaunchGame]["version"]
        if t then
            f:drawText(t, 30,445)
        end
        local t = gameInfo[cardLaunchGame]["author"]
        if t then
            f:drawTextAligned(t, 370,445,kTextAlignment.right)
        end
        cardImg:drawCentered(200,120)
        if  gameInfo[cardLaunchGame]["wrap"] then
            if unwrapAnimating then
                unwrapx+=unwrapxvel
                unwrapy+=unwrapyvel
                unwrapxvel = lerp(unwrapxvel,0,0.1)
                unwrapyvel = lerp(unwrapyvel,unwrapmaxvel,0.2)
            end
            gameInfo[cardLaunchGame]["wrap"]:draw(unwrapx,unwrapy)
        end

        
    elseif contentWarningState == 1 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0,0,400,218)
        gfx.drawTextInRect("*"..gameInfo[cardLaunchGame]["contentwarning"].."*", 20, 50, 360, 75, 2, "\226\128\166", kTextAlignment.center)
    elseif contentWarningState == 2 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0,0,400,218)
        gfx.drawTextInRect("*"..gameInfo[cardLaunchGame]["contentwarning2"].."*", 20, 50, 360, 75, 2, "\226\128\166", kTextAlignment.center)
    end
    if playdate.buttonJustPressed("down") and not cardInfoShowing then
        cardYposTarget = -250
        cardInfoShowing = true
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
    end
    if playdate.buttonJustPressed("up") and cardInfoShowing then
        cardYposTarget = -10
        cardInfoShowing = false
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
    end
    if cardAnimationState ~= "launch" then
        if playdate.buttonJustPressed("b") and canLaunch then
            cardShowing = false
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
            reloadIconsNextFrame = true
            cardYposTarget = -10
            cardInfoShowing = false
        end
        if playdate.buttonJustPressed("a") and canLaunch and not cardInfoShowing then
            loadCard(cardLaunchGame,"card-pressed")
            cardImg = gameInfo[cardLaunchGame]["card"]
            local unwrapped = false
            local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
            for i,v in ipairs(groups) do
                if v.name == game["group"] then
                    for j,v2 in ipairs(v) do
                        if v2:getBundleID() == game["bundleid"] then
                            if v2:getInstalledState() == kPDGameStateFreshlyInstalled then
                                canLaunch = false
                                local unwrapSound = playdate.sound.fileplayer.new("systemsfx/unwrap")
                                unwrapSound:setOffset(2)
                                --appearSound:setOffset(2)
                                playdate.timer.performAfterDelay(1000, function()                                 
                                    v2:setInstalledState(kPDGameStateInstalled)
                                    loadIcon(game["bundleid"])
                                    loadCard(game["bundleid"]) 
                                    reloadIconsNextFrame = true
                                    end) 
                                unwrapAnimating = true
                                --appearSound:setFinishCallback(
                                playdate.timer.performAfterDelay(3500,function()                                 
                                    playdate.system.updateGameList()
                                    canLaunch = true
                                    reloadIconsNextFrame = true
                                    unwrapAnimating = false
                                    unwrapx = 0
                                    unwrapy = 0
                                    end) 
                                unwrapSound:play()
                                unwrapx = 0
                                unwrapy = 0
                                unwrapxvel = -10
                                unwrapyvel = -25
                                reloadIconsNextFrame = true
                                unwrapped = true
                                break
                            end
                            
                        end
                    end
                end
            end
            if not unwrapped then
                if contentWarningState == 0 then
                    saveConfig()
                end
                local cw = gameInfo[cardLaunchGame]["contentwarning"]
                local cw2 = gameInfo[cardLaunchGame]["contentwarning2"]
                local game = nil
                if cw or cw2 then
                    for i,v in ipairs(groups) do
                        if v.name == gameInfo[cardLaunchGame]["group"] then
                            for j,v2 in ipairs(v) do
                                if v2:getBundleID() == gameInfo[cardLaunchGame]["bundleid"] then
                                    game = v2
                                end
                            end
                            break
                        end
                    end
                end
                local launchImmediately =false
                if game then 
                    if game:getSuppressContentWarning() == true then 
                        launchImmediately = true
                    end
                end
                if not cw or launchImmediately then
                    startCardLaunchAnimation()
                elseif not cw2 then
                    if contentWarningState == 0 then
                        contentWarningState = 1
                    else
                        game:setSuppressContentWarning(true)
                        startCardLaunchAnimation()
                    end
                else
                    if contentWarningState == 0 then
                        contentWarningState = 1
                    elseif contentWarningState == 1 then
                        contentWarningState = 2
                    else
                        game:setSuppressContentWarning(true)
                        startCardLaunchAnimation()
                    end
                end
            end
        end
    end
    if cardAnimationState == "highlighted" then
        if cardAnimationProps then
            if (not cardAnimationDoneIntro and cardAnimationProps["introFrames"]) then
                
                cardAnimationFrame+=1
                if cardAnimationFrame <= #cardAnimationProps["introFrames"] then
                    loadCard(cardLaunchGame,"card-highlighted/"..cardAnimationProps["introFrames"][cardAnimationFrame])
                    cardImg = gameInfo[cardLaunchGame]["card"]
                else
                    cardAnimationFrame = 0
                    cardAnimationDoneIntro = true
                end
            elseif cardAnimationProps["frames"] then
                local loops = cardAnimationProps["loop"]
                if loops == nil then loops = -1 end
                
                cardAnimationFrame+=1
                if cardAnimationFrame <= #cardAnimationProps["frames"] and cardAnimationProps["frames"][cardAnimationFrame] ~= nil then
                    loadCard(cardLaunchGame,"card-highlighted/"..cardAnimationProps["frames"][cardAnimationFrame])
                    cardImg = gameInfo[cardLaunchGame]["card"]
                else
                    if (cardAnimationLoops >= loops -1) and not (loops < 1) then
                        cardAnimationState = "off"
                    else
                        cardAnimationFrame = 0
                        cardAnimationLoops += 1
                        cardAnimationStayFrames = 2
                    end
                end
            end
        end
    elseif cardAnimationState == "launch" then
        bottomBar = false
        cardYpos = 0
        if cardAnimationLaunch then
            cardAnimationFrame+=1
            if gameInfo[cardLaunchGame]["imagepath"] then
                local img = gfx.image.new(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/launchImages/"..tostring(cardAnimationFrame)..".pdi")
                if img then
                    img:draw(0,0)
                else
                    gfx.unlockFocus()
                    local img = gfx.image.new(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/launchImage.pdi")
                    if img then img:draw(0,0) else
                    img = gfx.image.new(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/launchImages/"..tostring(cardAnimationFrame-1)..".pdi")
                    if img then img:draw(0,0) else
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillRect(0,0,400,240)
                    end
                    end
                    cardCursorImg = nil
                    playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
                end
            else
                gfx.unlockFocus()
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(0,0,400,240)
                cardCursorImg = nil
                playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
            end
        else
            gfx.unlockFocus()
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(0,0,400,240)
            cardCursorImg = nil
            playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
        end
    end

    gfx.unlockFocus()
    --testImg:draw(0,0)
end

function drawBottomBar()

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0,218,400,30)
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    if not showBattery then
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
        gfx.drawTextAligned("*"..t.."*", 395, 220, kTextAlignment.right)
    else
        if showBatteryPercent then
            batteryImg:draw(5,220)
            --print("drawin bp")
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            gfx.drawTextAligned("*"..tostring(math.floor(playdate.getBatteryPercentage())).."*",22,221, kTextAlignment.center)
        else
            batteryImgs:getImage(math.ceil(playdate.getBatteryPercentage()/25)+1):draw(5,220)
        end

        --print(showBatteryPercent)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        local t = playdate.getTime()
        local min = tostring(t["minute"])
        if #min < 2 then
            min = "0"..min
        end
        local hour = tostring(t["hour"])
        if not playdate.shouldDisplay24HourTime() then
            if t["hour"] > 12 then
                hour = tostring(t["hour"]-12)
                min = min .. " PM"
            else
                hour = tostring(t["hour"])
                min = min ..  " AM"
            end
        end
        local text = "*"..hour..":"..min.."*"
        gfx.drawText(text, 50, 221)
        local t = currentLabel
        gfx.drawTextAligned("*"..t.."*", 395, 220, kTextAlignment.right)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end


function playdate.update()
    if noToggleLabelFrames > 0 then noToggleLabelFrames -= 1 end
    --gfx.clear()
    if not Opts:isVisible() then
        --gfx.sprite.update()
    end
    playdate.timer.updateTimers()
    if actualIconOffsetX < iconOffsetX then
        actualIconOffsetX+=(iconOffsetX-actualIconOffsetX)*0.2*(40/playdate.display.getRefreshRate())
        reloadIconsNextFrame = true
    elseif actualIconOffsetX > iconOffsetX then
        actualIconOffsetX-=(actualIconOffsetX-iconOffsetX)*0.2*(40/playdate.display.getRefreshRate())
        reloadIconsNextFrame = true
    end
    if math.abs(actualIconOffsetX-iconOffsetX) < 0.02 then
        actualIconOffsetX = iconOffsetX
    end
    if reloadIconsNextFrame then
        drawIcons()
        reloadIconsNextFrame = false
    else
        --iconsImage:draw(0,0)
    end
    if inputDelay > 0 then inputDelay -= 1 end
    if not Opts:isVisible() then
        if not playdate.keyboard.isVisible() and not cardShowing then
            updateCursor()
        elseif cardShowing then
            updateCardCursor()
        end
    end
    if cardCursorImg then
        cardCursorImg:drawAnchored(200,cardYpos,0.5,0)
        if cardYpos < 230 and not cardShowing then
            cardYpos+=(230-cardYpos)*0.2*(40/playdate.display.getRefreshRate())
            reloadIconsNextFrame = true
            if cardYpos > 218 then
                cardCursorImg = nil
            end

        end
    end
    if bottomBar then
        drawBottomBar()
    end
    if Opts:isVisible() then
        local img = iconsImage
        gfx.lockFocus(img)
        if cardCursorImg then cardCursorImg:drawAnchored(200,cardYpos,0.5,0) end
        drawBottomBar()
        gfx.unlockFocus()
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

function playdate.keyboard.keyboardAnimatingCallback()
    reloadIconsNextFrame = true
end

function playdate.keyboard.keyboardDidHideCallback()
    reloadIconsNextFrame = true
end

function playdate.keyboard.keyboardWillHideCallback(pressedOK)
    if not pressedOK and editingLabel ~= 0 then
        table.remove(labels,editingLabel)
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
    elseif pressedOK and editingLabel ~= 0 then
        sortLabels()
        saveConfig()
        appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
        appearSound:play()
    end
    reloadIconsNextFrame = true
end

function playdate.keyboard.textChangedCallback()
    if playdate.keyboard.text == "New Labe" then
        playdate.keyboard.text = ""
    end
    if editingLabel ~= 0 then
        labels[editingLabel]["name"] = playdate.keyboard.text

    end
    reloadIconsNextFrame = true
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
            t = "" 
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
    labels = newLabels
    while cursorx > math.ceil(#gameGrid/rows) do
        moveLeft()
    end
    while indexFromPos(cursorx,cursory) > #gameGrid do
        moveUp()
    end
    saveConfig()
    reloadIconsNextFrame = true
end

function updateCursor()
    gfx.setLineWidth(6)
    gfx.setColor(invertedColors[invertcursor])
    gfx.drawRoundRect(cursordrawx*72-49, cursordrawy*72-55 - iconOffsetY,64,64,8)
    if iconsImage then
        if iconsImage:sample(cursordrawx*72-45, cursordrawy*72-51 - iconOffsetY) == gfx.kColorBlack and iconsImage:sample(cursordrawx*72-45, cursordrawy*72-50 - iconOffsetY) == gfx.kColorBlack and iconsImage:sample(cursordrawx*72-44, cursordrawy*72-51 - iconOffsetY+1) == gfx.kColorBlack then
            gfx.setColor(invertedColors[ not invertcursor])
            gfx.setLineWidth(1)
            gfx.drawRoundRect(cursordrawx*72-48, cursordrawy*72-54 - iconOffsetY,62,62,6)
        end
    end
    if iconAnimationState == "highlighted" then
        reloadIconsNextFrame = true
        if iconAnimationProps then
            if (not iconAnimationDoneIntro and iconAnimationProps["introFrames"]) then
                iconAnimationFrame+=1
                if iconAnimationFrame <= #iconAnimationProps["introFrames"] then
                    loadIcon(gameGrid[indexFromPos(cursorx,cursory)],"icon-highlighted/"..iconAnimationProps["introFrames"][iconAnimationFrame])
                else
                    iconAnimationFrame = 0
                    iconAnimationDoneIntro = true
                    iconAnimationStayFrames = 2
                end
            elseif iconAnimationProps["frames"] then
                local loops = iconAnimationProps["loop"]
                if loops == nil then loops = -1 end
                
                iconAnimationFrame+=1
                if iconAnimationFrame <= #iconAnimationProps["frames"] then
                    loadIcon(gameGrid[indexFromPos(cursorx,cursory)],"icon-highlighted/"..iconAnimationProps["frames"][iconAnimationFrame])
                    reloadIconsNextFrame = true
                else
                    if (iconAnimationLoops >= loops -1) and not (loops < 1) then
                        
                        --loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
                        iconAnimationState = "off"
                    else
                        iconAnimationFrame = 0
                        iconAnimationLoops += 1
                        iconAnimationStayFrames = 2
                    end
                end
            elseif gameGrid[indexFromPos(cursorx,cursory)] then
                if gameInfo[gameGrid[indexFromPos(cursorx,cursory)]] then
                    local loops = iconAnimationProps["loop"]
                    if loops == nil then loops = -1 end
                    if iconAnimationStayFrames >= 1 then
                        iconAnimationFrame+=1
                        iconAnimationStayFrames = 0
                    else
                        iconAnimationStayFrames += 1
                    end
                    local img = nil
                    if gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"] then
                        img = gfx.image.new(gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["path"] .. "/"..gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]["imagepath"].."/icon-highlighted/"..tostring(iconAnimationFrame)..".pdi")
                    else
                        img = nil
                    end
                    if img then
                        loadIcon(gameGrid[indexFromPos(cursorx,cursory)],"icon-highlighted/"..tostring(iconAnimationFrame))
                        reloadIconsNextFrame = true
                    else
                        if (iconAnimationLoops >= loops -1) and not (loops < 1) then
                            
                            --loadIcon(gameGrid[indexFromPos(cursorx,cursory)])
                            iconAnimationState = "off"
                        else
                            iconAnimationFrame = 0
                            iconAnimationLoops += 1
                            iconAnimationStayFrames = 2
                        end
                    end
                else
                    iconAnimationState = "off"
                end
            else
                iconAnimationState = "off"
            end
        else
            iconAnimationState = "off"
        end
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
            moveLeft(movingFast)
            movingFast = true
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("left") then
        removeKeyTimer()
        startIconAnimation()
    end
    if  playdate.buttonJustPressed("right") and not playdate.buttonIsPressed("b") then 

        removeKeyTimer()
        local timerCallback = function()
            moveRight(movingFast)
            movingFast = true
            appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
            appearSound:play()
    
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("right") then
        removeKeyTimer()
        startIconAnimation()
    end
    if playdate.buttonJustPressed("down") and not playdate.buttonIsPressed("b") then 
        removeKeyTimer()
        local timerCallback = function()
            moveDown(movingFast)
            movingFast = true
            appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("down") then
        removeKeyTimer()
        startIconAnimation()
    end
    if playdate.buttonJustPressed("up") and not playdate.buttonIsPressed("b") then 
        removeKeyTimer()
        local timerCallback = function()
            moveUp(movingFast)
            movingFast = true
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
        end
        keyTimer = playdate.timer.keyRepeatTimerWithDelay(initialDelay, repeatDelay, timerCallback)
    end
    if playdate.buttonJustReleased("up") then
        removeKeyTimer()
        startIconAnimation()
    end
    if playdate.buttonJustPressed("a") then
        cardYpos = 218
        if not organizeMode then
            local game = gameInfo[gameGrid[indexFromPos(cursorx,cursory)]]
            if game then
                local unwrapped = false
                if not unwrapped then
                    cardYPos = 218
                    cardLaunchGame = gameGrid[indexFromPos(cursorx,cursory)]
                    loadCard(cardLaunchGame,"card-pressed")
                    cardImg = game["card"]
                    appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                    appearSound:play()
                    if not skipCard then
                        reloadIconsNextFrame = true
                        cardShowing = true
                        contentWarningState = 0
                        startCardAnimation()
                        removeKeyTimer()
                    else
                        local img = gfx.image.new(gameInfo[cardLaunchGame]["path"] .. "/"..gameInfo[cardLaunchGame]["imagepath"].."/launchImage.pdi")
                        if img then img:draw(0,0) else
                        gfx.setColor(gfx.kColorBlack)
                        gfx.fillRect(0,0,400,240)
                        end
                        playdate.system.switchToGame(gameInfo[cardLaunchGame]["path"])
                    end
                end
            elseif gameGrid[indexFromPos(cursorx,cursory)] == ".stockLauncher" then
                appearSound = playdate.sound.fileplayer.new("systemsfx/03-action-trimmed")
                appearSound:play()
                playdate.system.switchToGame("/System/StockLauncher.pdx")
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
                    elseif gameGrid[indexFromPos(cursorx,cursory)] == ".stockLauncher" then
                        local badge = table.remove(gameGrid,indexFromPos(cursorx,cursory))
                        table.insert(gameGrid,indexFromPos(cursorx,cursory),".tempblank")
                        selectedBadge = badge
                        selectedBadgeImage = stockLauncherImg
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
                while gameGrid[#gameGrid] == ".empty" do
                    table.remove(gameGrid,#gameGrid)
                end
            end
        end
    end
    if playdate.buttonJustPressed("b") then
        movedLabels = false
    end
    if playdate.buttonIsPressed("b") then
        if playdate.buttonJustPressed("left") then
            moveLabels(-1)
            appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
            appearSound:play()
            movedLabels = true
        end
        if playdate.buttonJustPressed("right") then
            moveLabels(1)
            appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
            appearSound:play()
            movedLabels = true
        end
    end
    if playdate.buttonJustReleased("b") then
        if organizeMode and selectedBadge ~= nil and not movedLabels then
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
        elseif organizeMode and not movedLabels then
            if noToggleLabelFrames < 1 then
                toggleLabel(cursorx)
            end
        end
    end
    crankChange+=playdate.getCrankChange()
    local fast = false
    while crankChange < -crankIncrement do
        if noCrankFrames < 1 then
            moveLeft(fast)
        end
        fast = true
        crankChange+=crankIncrement
    end
    if fast then
        
        appearSound = playdate.sound.fileplayer.new("systemsfx/01-selection-trimmed")
        appearSound:play()
    end
    fast = false
    while crankChange > crankIncrement do
        if noCrankFrames < 1 then
            moveRight(fast)
        end
        fast = true
        crankChange-=crankIncrement
    end
    if fast then 
        appearSound = playdate.sound.fileplayer.new("systemsfx/02-selection-reverse-trimmed")
        appearSound:play()
    end
    if not (noCrankFrames < 1) then
        noCrankFrames -= 1
        crankChange = 0
    end
    setCurrentLabel()
end

function setCurrentLabel()
    local currentcurrentLabel = currentLabel
    currentLabel = nil
    if #labels > 0 then
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
    else
        currentLabel= ""
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
                if v["x"] <= cursorx then
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

function  main()
    loadingImg:draw(0,0)
    playdate.display.setRefreshRate(20)
    playdate.display.flush()
    gfx.clear()
    dirSetup()
    loadConfig()
    setupGameInfo()
    loadOptions(true)
    badgeSetup()
    placeIcons()
    noCrankFrames = 5
    if indexFromPos(cursorx,cursory) > #gameGrid then
        cursorx,cursory = 1,1
        iconOffsetX = 0
        cursordrawx,cursordrawy = 1,1
    end
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
    menu:addCheckmarkMenuItem("organize", organizeMode, function(bool) 
        organizeMode = bool 
        reloadIconsNextFrame = true 
        drawerOpen = false 
        collapseEmptyExpansions()
    end)
    local x,y = targetcx,targetcy
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

    if reduceStuttering then
        for i,v in ipairs(gameGrid) do
            loadIcon(v)
        end
    end
end


main()