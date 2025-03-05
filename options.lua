--
--  pd-options - Robust and portable options manager class for the Playdate Lua SDK
--
import 'CoreLibs/ui'
import 'CoreLibs/object'
import 'CoreLibs/graphics'
import 'CoreLibs/sprites'
import 'CoreLibs/crank'

local pd <const> = playdate
local gfx <const> = pd.graphics

class('Options').extends(gfx.sprite)


-- Probably no need to change this stuff unless you want more custom drawing styles
local timer <const> = pd.timer
local w <const> = 200	--198
local h <const> = 240
local DIVIDER_WIDTH <const> = 1
local ITEM_HEIGHT <const> = 24
Options.TOGGLE, Options.SLIDER, Options.RESET = 1, 2, 'RESET'
TOGGLE, SLIDER, RESET = Options.TOGGLE, Options.SLIDER, Options.RESET
local TOGGLE_VALS = {false, true}
-- Option selection key repeat values
local UP_DOWN_KEY_REPEAT = 50 -- time between key repeats when scrolling
local UP_DOWN_KEY_REPEAT_INITIAL = 250 -- initial delay before key repeating starts
-- Value selection key repeat values (these are slower by default because some value changing operations can be expensive)
local LEFT_RIGHT_KEY_REPEAT = 150
local LEFT_RIGHT_KEY_REPEAT_INITIAL = 250

local lockRelations = {} -- store for options that lock other options
local lockedOptions = {} -- hash set of option keys that are currently locked from being altered
local optionDefsByKey = {} -- transformation of the optionDefinitions object to be indexed by key. values point back to the option definition

-- Initialize the Options class with three parameters:
-- definitions: Define the list of options declaratively. Each option must fall within a section header. See readme for details
-- displayOnRight: set to true to show the options on the right side of the screen instead of left
-- saveDataPath:  File path of the output user settings in game data folder (don't include .json)
-- onHide: Function called when the Options menu hides
function Options:init(definitions, displayOnRight, saveDataPath, onHide)
    Options.super.init(self)
    assert(definitions, "Must supply an options definition object")
    self.displayOnRight = displayOnRight
    self.saveDataPath = saveDataPath or 'settings'
    self.xOffset = self.displayOnRight and 200 or 0

    self.frame = 1
    self.menu = pd.ui.gridview.new(0, ITEM_HEIGHT)

    -- list of available options based on option screen (indexed by section/row for easy selection)
    self.currentOptions = definitions
    -- current values for each option. (indexed by key for easy reads)
    self.userOptions = {}
    self.dirty = false
    self.previewMode = false
    self.onHide = onHide

    -- sprite init
    self:setZIndex(9999)
    self:setIgnoresDrawOffset(true)
    self:setCenter(0,0)
    self:moveTo(0,0)
    self:setVisible(false)
    local img = gfx.image.new(400,240)
    self:setImage(img)
    self.menuImg = gfx.image.new(w, h)

    self:add()

    self:menuInit()
    self:userOptionsInit()

    function self.menu.drawCell(menuSelf, section, row, column, selected, x, y, width, height)
        local textPadding = 5
        local val, isFavorited = self:getValue(section, row)
        local label, style, numValues, minVal, showValue = self:getOptionDefInfo(section, row)
        if self.previewMode and not selected then return end
        gfx.pushContext()
        if selected then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(x, y, width, height+2, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end

        -- draw option label
        local labelWidth, _ = gfx.getTextSize(label)
        labelWidth = math.min(width, labelWidth)
        gfx.drawTextInRect(label, x+textPadding, y+textPadding, labelWidth, height, nil, '...', kTextAlignment.left)

        -- draw option value
        if val ~= 'n/a' and val ~= nil then
            if style == TOGGLE then
                Options.drawSwitch(y+textPadding-2, val, selected)
            elseif style == SLIDER then
                Options.drawSlider(y+textPadding-2, val, selected, numValues, minVal, showValue)
            elseif style ~= RESET then
                -- draw value as text
                local optionWidth = 192 - (labelWidth+textPadding)
                if isFavorited then val = '❤️*' .. val else val = '*' .. val end
                gfx.drawTextInRect(val, labelWidth+textPadding, y+textPadding, optionWidth, height, nil, '...', kTextAlignment.right)
            end
        end

        gfx.popContext()
    end

    function self.menu.drawSectionHeader(menuSelf, section, x, y, width, height)
        if self.previewMode then return end

        local textPadding = 4
        local text = '*'..self.currentOptions[section].header:upper()..'*'
        gfx.pushContext()
            -- gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.drawText(text, x+4, y+textPadding)
            gfx.setColor(gfx.kColorBlack)
            gfx.setLineWidth(2)
            gfx.drawLine(x, y+height, x+width, y+height)

        gfx.popContext()
    end

    self.keyTimer = {}
    self.controls = {
        -- move
        leftButtonDown = function()
            self.keyTimer.L = timer.keyRepeatTimerWithDelay(LEFT_RIGHT_KEY_REPEAT_INITIAL, LEFT_RIGHT_KEY_REPEAT, function() self:toggleCurrentOption(-1) end)
        end,
        leftButtonUp = function() if self.keyTimer.L then self.keyTimer.L:remove() end end,
        rightButtonDown = function()
            self.keyTimer.R = timer.keyRepeatTimerWithDelay(LEFT_RIGHT_KEY_REPEAT_INITIAL, LEFT_RIGHT_KEY_REPEAT, function() self:toggleCurrentOption(1) end)
        end,
        rightButtonUp = function() if self.keyTimer.R then self.keyTimer.R:remove() end end,
        upButtonDown = function()
            self.keyTimer.U = timer.keyRepeatTimerWithDelay(UP_DOWN_KEY_REPEAT_INITIAL, UP_DOWN_KEY_REPEAT, function() self:selectPreviousRow() end)
        end,
        upButtonUp = function() if self.keyTimer.U then self.keyTimer.U:remove() end end,
        downButtonDown = function()
            self.keyTimer.D = timer.keyRepeatTimerWithDelay(UP_DOWN_KEY_REPEAT_INITIAL, UP_DOWN_KEY_REPEAT, function() self:selectNextRow() end)
        end,
        downButtonUp = function() if self.keyTimer.D then self.keyTimer.D:remove() end end,

        -- action
        AButtonDown = function()
            self:handleAPress()
        end,
        BButtonDown = function()
            if self.previewMode then
                self.previewMode = false
                self:updateImage()
            elseif not self.slideAnim then
                self:hide()
            end
        end,
        BButtonUp = function () end,
        -- turn with crank
        cranked = function(change, acceleratedChange)
            if pd.getCrankTicks(8) ~= 0 then
                if change < 0 then
                    self:selectPreviousRow()
                else
                    self:selectNextRow()
                end
            end
        end,
    }
end

function Options:menuInit()
    local sectionRows = {}
    local startRow = 0
    for i, section in ipairs(self.currentOptions) do
        if section.header then
            table.insert(sectionRows, #section.options)
        end
    end

    self.menu:setCellPadding(0,0,2,2)
    self.menu:setContentInset(4, 4, 0, 0)
    self.menu:setSectionHeaderHeight(ITEM_HEIGHT)
    self.menu:setSectionHeaderPadding(0, 0, 2, 0)

    self.menu:setNumberOfRows(table.unpack(sectionRows))
    self.menu:setSelectedRow(1)
end

function Options:userOptionsInit(ignoreUserOptions)
    local existingOptions = nil
    if not ignoreUserOptions then
        existingOptions = self:loadUserOptions()
    end
    self.userOptions = {}

    -- Go through each defined option and see if an existing value was loaded
    for j, section in ipairs(self.currentOptions) do
        for i, option in ipairs(section.options) do
            local key = option.key or option.name:lower()
            optionDefsByKey[key] = option
            if not option.style and not option.values then
                option.style = TOGGLE
            end
            if option.style == TOGGLE then
                option.values = TOGGLE_VALS
            end
            if option.key == RESET then
                option.values = {1}
                option.style = RESET
            end
            if option.style == SLIDER then
                option.values = {}
                for i=option.min, option.max, 1 do
                    table.insert(option.values, i)
                end

                if option.default == nil then option.default = 1 end
                -- when first loading this option, adjust the default to be an index rather than actual value
                if not option.defaultAdjusted then
                    option.default = table.indexOfElement(option.values, option.default)
                    option.defaultAdjusted = true
                end
            end
            if option.locks then
                lockRelations[key] = option.locks
            end
            local default = option.default or 1

            -- this option exists in the loaded json and needs to be imported
            if existingOptions and existingOptions[key] ~= nil and not option.ignoreOnLoad then
                local val = existingOptions[key]

                -- if the existing option is a dirtyRead option, mark it as dirty
                if #val == 2 then val[2] = true end

                -- if the value index exceeds the number of values available, reset to default
                if type(val[1]) == 'number' and val[1] > #option.values then
                    val[1] = default
                end

                -- set the loaded option
                self.userOptions[key] = val
                if val[1] == true then
                    option.current = 2
                elseif val[1] == false then
                    option.current = 1
                else
                    option.current = val[1]
                end

            -- this option does not exist and should be set to the default value
            else
                local val = {default}
                if option.style == TOGGLE then
                    val = {option.values[default]}
                end
                if option.dirtyRead then
                    val[2] = true
                end

                self.userOptions[key] = val
                option.current = default
            end

            -- if this option has favorites, load them
            local favKey = key .. 'Favorites'
            if option.canFavorite then
                option.favKey = favKey
                if existingOptions and existingOptions[favKey] then
                    local filteredFavs = {}
                    -- filter out favorites that are beyond the available number of assets
                    for i, idx in ipairs(existingOptions[favKey]) do
                        if idx <= #option.values then
                            table.insert(filteredFavs, idx)
                        end
                    end
                    self.userOptions[favKey] = filteredFavs
                else
                    self.userOptions[favKey] = {}
                end
            end

            option.key = key
        end
    end

    -- Iterate once more through all userOptions (now that they were imported or set to default)
    -- and set relevant options based on the 'locks' setting
    for key, val in pairs(self.userOptions) do
        self:handleOptionLocks(key, val[1])

    end
end

function Options:saveUserOptions()
    self.userOptions._build = pd.metadata.buildNumber
    pd.datastore.write(self.userOptions, self.saveDataPath, false)
end

function Options:loadUserOptions()
    return pd.datastore.read(self.saveDataPath)
end

function Options:resetKeyTimers(upDownOnly)
    for k, v in pairs(self.keyTimer) do
        if not upDownOnly or k == 'U' or k == 'D' then
            v:remove()
        end
    end
end
function Options:show()
    if self:isVisible() then return end

    self:playOpenSFX()
    self:setVisible(true)
    self.previewMode = false
    self:updateMenuImage()
    pd.inputHandlers.push(self.controls, true)

    self:updateImage()
end

function Options:hide()
    self:playCloseSFX()
    self:saveUserOptions()
    self:resetKeyTimers()
    pd.inputHandlers.pop()
    self:setVisible(false)
    local callback = self.onHide
    if callback then
      	assert(
          type(callback) == "function",
          "Tried to call onHide callback but it's not a function"
        )
        callback(self)
    end
end

-- given an option key and a value, check if that setting should lock any other options from changing
function Options:handleOptionLocks(key, val)
    -- if this option locks something else
    if lockRelations[key] then
        -- get the other option
        local otherKey, otherVal = lockRelations[key].lockedOption, lockRelations[key].lockedValue

        -- value matches so lock this other option
        if lockRelations[key].lockedWhen == val then
            -- set the user option add to the locked options set to prevent it from being changed later
            self:setOptionIdx(otherKey, otherVal, optionDefsByKey[otherKey])
            lockedOptions[otherKey] = true
        -- unlock the option instead
        else
            lockedOptions[otherKey] = nil
        end

        -- mark other option as dirty if necessary
        if #self.userOptions[otherKey] == 2 then
            self.userOptions[otherKey][2] = true
        end
    end
end

-- Returns the option at the given section and row, or the currently selected option if no args
function Options:getSelectedOption(section, row)
    local selectedSection, selectedRow, selectedCol = self.menu:getSelection()
    section = section or selectedSection
    row = row or selectedRow
    return self.currentOptions[section].options[row]
end

function Options:getOptionDefInfo(section, row)
    local active <const> = self:getValue(section, row) == nil
    local bold <const> = active and '' or ''
    gfx.setFontTracking(0)
    local optDef = self:getSelectedOption(section, row)
    return bold..optDef.name, optDef.style, #optDef.values, optDef.min, optDef.showValue
end

function Options:getValue(section, row)
    local option = self:getSelectedOption(section, row)
    local isFavorited = false
    if option.favKey and table.indexOfElement(self.userOptions[option.favKey], option.current) ~= nil then
        isFavorited = true
    end
    return option.values[option.current], isFavorited
end

-- Returns the index of the option's value if it is marked as dirty, otherwise return nil
-- Pass ignoreDirty=true to always read the value of the option
-- Pass returnValue=true to return the actual value instead of the index
function Options:read(key, ignoreDirty, returnValue)
    local opt = self.userOptions[key]
    if opt == nil then return opt end

    local values = nil
    if returnValue then
        values = optionDefsByKey[key].values
    end

    -- opt[1] is the value, opt[2] is a boolean indicating if the option is dirty.
    -- not all options are defined with dirty reads, and in that case they are only length 1
    if #opt == 2 and not ignoreDirty then
        if opt[2] then
            opt[2] = false
            return returnValue and values[opt[1]] or opt[1]
        end
    else
        if opt[2] then
            opt[2] = false
        end
        return returnValue and values[opt[1]] or opt[1]
    end
end

-- Write a new index to a given option key. Pass keepClean=true if you want to not mark this change as dirty.
function Options:write(key, newIdx, keepClean)
    self:setOptionIdx(key, newIdx, optionDefsByKey[key], keepClean)
    self:updateImage()
end

-- Sets the given option to the new index, handling the boolean and dirty read case
function Options:setOptionIdx(key, newIdx, optionDef, keepClean)
    -- non-boolean options are stored as indices into values rather than values to make backwards-compatibility easier
    self.userOptions[key] = { newIdx }
    if optionDef.style == TOGGLE then
        self.userOptions[key] = { optionDef.values[newIdx] }
    end

    -- add dirty flag for this option
    if optionDef.dirtyRead then
        if not keepClean then
            self.userOptions[key][2] = newIdx ~= currentIdx
        else
            self.userOptions[key][2] = false
        end
    end

    -- keep track of the current index in the option definition as well
    optionDef.current = newIdx
end

function Options:isOptsDirty()
    return self.dirty
end

function Options:markOptsDirty()
    self.dirty = true
end

function Options:markClean()
    self.dirty = false
end

-- Given a table of option keys, randomize the value of those options and write the result.
-- If favorite values are set, randomizer only pulls from favorites.
function Options:randomize(keyList)
    local randomizableOpts = {}
    for i, key in ipairs(keyList) do
        if optionDefsByKey[key] ~= nil then
            table.insert(randomizableOpts, optionDefsByKey[key])
        end
    end
    if #randomizableOpts == 0 then return end

    for i, opt in ipairs(randomizableOpts) do
        local vals = opt.values
        local currentIdx = opt.current or opt.default
        local newIdx = 1

        if opt.favKey and #self.userOptions[opt.favKey] > 0 then
            local favList = self.userOptions[opt.favKey]
            newIdx = favList[math.random(1, #favList)]
        else
            newIdx = math.random(1, #vals)
        end

        self.userOptions[opt.key] = {newIdx}
        if opt.dirtyRead then
            self.userOptions[opt.key][2] = (newIdx ~= currentIdx)
        end

        opt.current = newIdx
    end
    self:markOptsDirty()
    self:updateImage()
end

function Options:getFavorites(key)
    local opt = optionDefsByKey[key]
    if opt.favKey then
        local favs = self.userOptions[opt.favKey]
        return favs
    end
    return {}
end

function Options:handleAPress()
    local option = self:getSelectedOption()
    -- toggle the option if can't be favorited
    if option.key == RESET then
        return self:resetToDefaults()
    end
    if not option.favKey then
        return self:toggleCurrentOption(1, true)
    end

    local favList = self.userOptions[option.favKey]
    local loc = table.indexOfElement(favList, option.current)
    if loc ~= nil then -- remove favorite by recreating the list without
        local newFavs = {}
        for i, fav in ipairs(favList) do
            if fav ~= option.current then table.insert(newFavs, fav) end
        end
        self.userOptions[option.favKey] = newFavs
    else -- add favorite
        table.insert(favList, option.current)
    end
    self:updateImage()
end

function Options:resetToDefaults()
    self:playResetSFX()
    self:userOptionsInit(true)
    self:updateImage()
end

function Options:toggleCurrentOption(incr, forceWrap)
    incr = incr or 1
    self:resetKeyTimers(true)
    self:playSelectionSFX(incr == 1)

    local option = self:getSelectedOption()
    local key =  option.key
    local values = option.values
    local currentIdx = option.current  or option.default

    if lockedOptions[key] then
        print('option is locked')
        return
    end

    local newIdx = currentIdx+incr
    if option.style == SLIDER then -- sliders dont wrap
        local minVal = 1
        local maxVal = #values
        newIdx = newIdx < minVal and minVal or newIdx > maxVal and maxVal or newIdx
    else -- pick new index by wrapping around all the values
        newIdx = 1 + (newIdx-1) % #values
    end
    -- boolean toggles should not wrap unless the A button is being used to toggle
    if option.style == TOGGLE and not forceWrap then
        newIdx = incr == -1 and 1 or 2
    end

    self:setOptionIdx(key, newIdx, option)

    -- mark entire object dirty
    if newIdx ~= currentIdx then
        self:markOptsDirty()
        if option.preview then
            self.previewMode = true
        end
    end

    self:handleOptionLocks(key, self.userOptions[key][1])
    self:updateImage()
end

function Options:onCurrentOption()
    local row <const> = self:getCurrentRow()

    if self:getValue(row) == false then
        self:toggleCurrentOption()
    end
end

function Options:offCurrentOption()
    local row <const> = self:getCurrentRow()

    if self:getValue(row) == true then
        self:toggleCurrentOption()
    end
end

function Options:update()
    if self.slideAnim then
        self:updateImage()
    end
end

function Options:updateImage()

    local img = self:getImage()
    img:clear(gfx.kColorClear)
    gfx.pushContext(img)

    if not self.previewMode then

        self:updateMenuImage()
        self:drawSideBar()

        -- xoffset is a parameter for this methods in case you want to animate the drawing left or right
        self:drawMenu(0)

        local tooltip = self:getSelectedOption().tooltip
        if tooltip then
            self:drawTooltipBox(tooltip)
        end
    else
        self:updateMenuImage()
        self:drawMenu(0)
    end

    gfx.popContext()
    self:markDirty()
end

function Options:updateMenuImage()
    self.menuImg:clear(gfx.kColorClear)
    gfx.pushContext(self.menuImg)
        self.menu:drawInRect(0, 0, w, h)
    gfx.popContext()
end

function Options:drawSideBar()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(self.xOffset, 0, w, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(w,0,w,240)
end

function Options:drawMenu(xoffset)
    local menuXOffset = xoffset + self.xOffset
    self.menuImg:draw(menuXOffset, 0)
end

function Options:drawTooltipBox(tooltip)
    local textPadding = 10
    local distanceFromDivider = 18
    local x, y = w + DIVIDER_WIDTH + distanceFromDivider, 20
    if self.displayOnRight then
        x = distanceFromDivider
    end
    local maxWidth = 160
    local maxHeight = 180

    local tw, th = gfx.getTextSizeForMaxWidth(tooltip, maxWidth - 2*textPadding)
    local textRect = pd.geometry.rect.new(textPadding, textPadding, maxWidth - 2*textPadding, th)

    self.tooltipImg = gfx.image.new(200, th+40)
    gfx.pushContext(self.tooltipImg)

        Options.drawBox(1, 1, textRect.width + 2*textPadding, textRect.height + 2*textPadding, false)
        gfx.drawTextInRect(tooltip, textRect, nil, '...', kTextAlignment.left)

    gfx.popContext()

    self.tooltipImg:draw(x, y + (maxHeight-th)/2)
end

function Options:selectPreviousRow()
    self.previewMode = false
    self.menu:selectPreviousRow(true, false, false)
    local sect, row, col = self.menu:getSelection()
    self.menu:scrollCellToCenter(sect, row, col, false)
    self:playSelectionSFX(false)
    self:updateImage()
end

function Options:selectNextRow()
    self.previewMode = false
    self.menu:selectNextRow(true, false, false)
    local sect, row, col = self.menu:getSelection()
    self.menu:scrollCellToCenter(sect, row, col, false)
    self:playSelectionSFX(true)
    self:updateImage()
end

------------------------------------------
--------- STATIC DRAWING METHODS ---------
------------------------------------------

function Options.drawSwitch(y, val, selected)
    local x = 158

    local y <const> = y+8

    local r <const> = 6
    local rx <const> = x+9
    local ry <const> = y-5
    local rw <const> = 24
    local rh <const> = r*2+2

    local cxoff <const> = x+16
    local cxon <const> = x+rw+2
    local cy <const> = y+2

    gfx.pushContext()
    gfx.setLineWidth(2)

    gfx.setColor(selected and gfx.kColorWhite or gfx.kColorBlack)

    if val then
        gfx.setDitherPattern(0.5)
        gfx.fillRoundRect(rx,ry,rw,rh, r)

        gfx.setColor(selected and gfx.kColorWhite or gfx.kColorBlack)
        gfx.drawRoundRect(rx,ry,rw,rh, r)
        gfx.fillCircleAtPoint(cxon,cy,r+2)
        -- gfx.drawRect(cxon,cy-3,1,6)
    else
        gfx.drawRoundRect(rx,ry,rw,rh, r)
        gfx.drawCircleAtPoint(cxoff,cy,r+1)
        gfx.setColor(selected and gfx.kColorBlack or gfx.kColorWhite)
        gfx.fillCircleAtPoint(cxoff,cy,r)
    end

    gfx.popContext()
end

function Options.drawSlider(y, rawVal, selected, numValues, minVal, showValue)
    -- rawVal: integer between min and max in the definition (inclusive)
    -- numValues: how many possible values (max - min + 1)
    -- minVal: minimum end of the range

    local rightEdge = 190

    local y <const> = y+8

    local r <const> = 6
    local rw <const> = numValues * 5 + 12
    local rx <const> = rightEdge - rw
    local ry <const> = y-5
    local rh <const> = r*2+2

    -- adjust val to be between 1 and numValues
    val = rawVal + (1 - minVal)
    if showValue then
        gfx.drawTextAligned(rawVal, rx - 5, ry-1, kTextAlignment.right)
    end
    local cx <const> = rx
    local cxv <const> = cx+(val*5)-1
    local cy <const> = y-6

    gfx.pushContext()
    gfx.setLineWidth(2)

    gfx.setColor(selected and gfx.kColorWhite or gfx.kColorBlack)

    if val then
        gfx.setColor(selected and gfx.kColorWhite or gfx.kColorBlack)

        -- body
        gfx.drawRoundRect(rx,ry,rw,rh, r)

        -- notches
        for dot=1,numValues do
            gfx.fillRect(cx+3+(dot*5),cy+7,2,2)
        end

        -- handle
        gfx.drawRoundRect(cxv+2,cy,6,rh+2,r)

        -- handle pattern
        gfx.setDitherPattern(0.5)
        gfx.fillRoundRect(cxv+2,cy,6,rh+2,r+2)
    end

    gfx.popContext()
end

function Options.drawBox(x, y, width, height, drawShadow)

    local rect = pd.geometry.rect.new(x, y, width, height)
    local shadow = pd.geometry.rect.new(rect.x, rect.y, rect.width+ 5, rect.height + 5)

    if drawShadow then
        -- shadow
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer2x2)
        gfx.fillRect(shadow)
    end

     -- background
     gfx.setColor(gfx.kColorWhite)
     gfx.fillRoundRect(rect, 4)

     -- border
     gfx.setColor(gfx.kColorBlack)
     gfx.setLineWidth(2)
     gfx.drawRoundRect(rect, 4)

    return drawShadow and shadow or rect
end

------------------------------------------
-------- SOUND EFFECT PLACEHOLDERS -------
------------------------------------------

-- open the menu
function Options:playOpenSFX() end

-- close the menu
function Options:playCloseSFX() end

-- reset to defaults
function Options:playResetSFX() end

-- select item
-- pass boolean true for forward selection, boolean false for reverse selection
function Options:playSelectionSFX(isForward) end
