import("CoreLibs/graphics")
import("CoreLibs/keyboard")
import("CoreLibs/timer")
import("CoreLibs/frameTimer")
import("CoreLibs/object")
import("aesthetics")
import("system")
import("input")
import("utils")

savePath = "/Shared/FunnyOS2/"

firstUpdate = true

firstLaunch = false

currentLabel = "System"
currentObject = 1

heldObject = nil
heldObjectOriginIndex = 1
heldObjectOriginLabel = ""

tempVars = {}

iconsCache = {}

labels = {}
labelOrder = {}

objectSizes = {[3] = 68, [6] = 34}
objectSpacings = {[3] = 5, [6] = 2}
homeRows = 3

--0: select label, 1: select game, 2: game card, 
cursorStates = {["SELECT_LABEL"] = 1, ["SELECT_OBJECT"] = 2, ["GAME_CARD"] = 3, ["GAME_INFO"] = 4, ["MOVE_OBJECT"] = 5, ["ADD_LABEL"] = 6, ["RENAME_LABEL"] = 7, ["CONTROL_CENTER_MENU"] = 8, ["CONTROL_CENTER_CONTENT"] = 9, ["INFO_POPUP"] = 10}

installedLaunchers = {}
--launcher is {name, path}

funnyOSMetadata = playdate.system.getMetadata("pdxinfo")

controlCenterMenuSelection = 0
controlCenterInfoSelection = 0
controlCenterInfoMaxSelection = 0

cursorState = cursorStates.SELECT_LABEL
oldCursorState = cursorStates.SELECT_LABEL

emptyObject = {["bundleid"] = ".empty"}
emptySpaceImgs = {}

infoPopupTitle = ""
infoPopupBody = ""
infoPopupCallbackA = nil
infoPopupEnableB = true

configVarDefaults = {
    ["configversion"] = 2.0,
    
    --options
    ["musicon"] = true,
    ["skipcard"] = false,
    ["iconborders"] = true,
    ["invertborders"] = false,
    ["invertcursor"] = false,
    ["invertlabels"] = false,
    ["invertblanks"] = false,
    ["bgdither"] = 1,
    ["blankdither"] = 0.5,
    ["labeldither"] = 0.75,
    ["cornerradius"] = 20,
    ["drawblanks"] = false,
    ["autocollapselabels"] = false
}

configVarOptionsOrder = {
    "musicon",
    "skipcard",
    "iconborders",
    "invertborders",
    "invertcursor",
    "invertlabels",
    "invertblanks",
    "bgdither",
    "blankdither",
    "labeldither",
    "cornerradius",
    "drawblanks",
    "autocollapselabels"
}

configVarOptions = {
    --options
    ["musicon"] = {["name"] = "Enable Music", ["values"] = {true, false}},
    ["iconborders"] =  {["name"] = "Enable Borders", ["values"] = {true, false}},
    ["skipcard"] =  {["name"] = "Skip Card View", ["values"] = {true, false}},
    ["invertborders"] =  {["name"] = "Invert Borders", ["values"] = {true, false}},
    ["invertcursor"] =  {["name"] = "Invert Cursor", ["values"] = {true, false}},
    ["invertlabels"] =  {["name"] = "Invert Labels", ["values"] = {true, false}},
    ["invertblanks"] =  {["name"] = "Invert Blanks", ["values"] = {true, false}},
    ["bgdither"] = {["name"] = "BG Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}},
    ["blankdither"] = {["name"] = "Blank Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}},
    ["labeldither"] = {["name"] = "Label Dither", ["values"] = {1, 0.75, 0.5, 0.25, 0}},
    ["cornerradius"] = {["name"] = "Corner Radius", ["values"] = {0, 5, 10, 15, 20}},
    ["drawblanks"] =  {["name"] = "Draw Blank Spaces", ["values"] = {true, false}},
    ["autocollapselabels"] =  {["name"] = "Auto-Collapse Labels", ["values"] = {true, false}}
}

controlCenterMenuItems = {
    "Controls Help",
    "Badges Menu",
    "Screenshots",
    "Launcher Select",
    "FunnyOS Options",
    "System Info"
}

controlCenterInfoMaxSelections = {
    ["FunnyOS Options"] = #configVarOptionsOrder
}

configVars = configVarDefaults

function createInfoPopup(title, text, enableB, callbackA)
    if cursorState ~= cursorStates.INFO_POPUP then  
        oldCursorState = cursorState
    end
    changeCursorState(cursorStates.INFO_POPUP)
    infoPopupTitle = title
    infoPopupBody = text
    infoPopupCallbackA = callbackA
    infoPopupEnableB = enableB
    if enableB == nil then
        infoPopupEnableB = true    
    end
end

function changeCursorState(state)
    cursorState = state
    while #playdate.inputHandlers > 1 do
        playdate.inputHandlers.pop()
    end
    playdate.inputHandlers.push(cursorStateInputHandlers[state])    
    if state == cursorStates.RENAME_LABEL then
        playdate.frameTimer.performAfterDelay(10, function() key.show(currentLabel) end)	
    end
end

function saveConfig()
    das.write(configVars,savePath.."funnyConfig")
    das.write(labelOrder,savePath.."labelOrder")
    for k,v in pairs(labels) do
        das.write(v,savePath.."Labels/"..k)
    end
end

function saveLabelOrder()
    das.write(labelOrder,savePath.."labelOrder")    
end

function saveLabel(label)
    das.write(labels[label],savePath.."Labels/"..label)
end

function loadConfig()
    local datastore = das.read(savePath.."funnyConfig")
    if datastore then 
        for k,v in pairs(datastore) do
            if datastore["configversion"] ~= configVarDefaults["configversion"] then break end
            configVars[k] = v    
        end
    end
    for k,v in pairs(configVars) do
        if v==nil then configVars[k] = configVarDefaults[k] end    
    end
    local datastore = das.read(savePath.."labelOrder")
    if datastore then labelOrder = datastore end
    if fle.isdir(savePath.."Labels/") then
        local labelFiles = fle.listFiles(savePath.."Labels/")
        labels = {}

        for i,v in ipairs(labelFiles) do
            labels[v:sub(1,#v-5)]=das.read(savePath.."Labels/"..v:sub(1,#v-5))
            labels[v:sub(1,#v-5)]["collapsed"] = configVars.autocollapselabels
        end
    end
end

function dirSetup()
    firstLaunch = not fle.exists(savePath.."funnyConfig.json")
    fle.mkdir(savePath)
	fle.mkdir(savePath.."Icons")
    fle.mkdir(savePath.."Badges")
    fle.mkdir(savePath.."Labels")
    loadImgs()
end

function playdate.deviceWillLock()
    collectgarbage("collect")
end

function playdate.deviceWillUnlock()
    --i just have this here in case
end

function playdate.keyboard.keyboardAnimatingCallback()
    
end

function playdate.keyboard.keyboardDidHideCallback()
    if cursorState == cursorStates.RENAME_LABEL then
        changeCursorState(cursorStates.SELECT_LABEL)    
    end
end

function playdate.keyboard.keyboardWillHideCallback(pressedOK)
    if cursorState == cursorStates.RENAME_LABEL then
        if pressedOK then
            if labels[key.text] then
                createInfoPopup("Action Failed", "*A label cannot be created with the same name as an existing label.*", false)
                return
            end
            --set displayname, labels[key], labelOrder, filename (delete old)
            local oldLabelName = currentLabel
            local newLabelName = key.text
            fle.delete(savePath.."Labels/"..oldLabelName..".json")
            labels[oldLabelName].displayName = newLabelName
            local labelData = labels[oldLabelName]
            labels[newLabelName] = {}
            for k,v in pairs(labelData) do
                labels[newLabelName][k] = v    
            end
            labels[newLabelName].objects = listCopy(labelData.objects)
            labels[oldLabelName] = nil
            labelOrder[indexOf(labelOrder, oldLabelName)] = newLabelName
            currentLabel = newLabelName
            currentObject = 1
            saveLabel(newLabelName)
            saveLabelOrder()
        end
    end
end

function playdate.keyboard.textChangedCallback()
    
end

function playdate.update()
    playdate.resetElapsedTime()
    if firstUpdate then
        firstUpdate=false
        main()
        return
    end
    drawRoutine()
    playdate.timer.updateTimers()
    playdate.frameTimer.updateTimers()
    playdate.drawFPS(383,0)
    if #playdate.inputHandlers < 2 then
        playdate.inputHandlers.push(cursorStateInputHandlers[cursorState])      
    end
end

function  main()
    loadConfig()
    setupEmptySpaceImages()
    dirSetup()
    loadingImg:draw(0,0)
    playdate.display.setRefreshRate(50)
    playdate.display.flush()
    gfx.clear()
    setupGameInfo()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    changeCursorState(cursorStates.SELECT_LABEL)
    playdate.timer.performAfterDelay(500, updateCursorFrame)
    sys.pushNotification(100)
    --firstLaunch=true
    if firstLaunch then
        createInfoPopup("Welcome!", "*Hello, and thank you for using FunnyOS 2! FunnyOS 2 uses button combos, so you must know those to do most tasks. These combos can be found in the control center.*", false, function() createInfoPopup("Welcome!", "*In order to open the control center, press *"..buttons.A.."*+*"..buttons.DOWN.."*. The control center also houses other useful features, so be sure to look through it to get the most out of FunnyOS 2. Have fun!*", false, function()  end) end)
    end
end