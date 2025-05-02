local TemplateWidget = {}
local widget = TemplateWidget

local list = {}
local listPath = savePath.."Widgets/Save/ToDoList/"
local listFilename = "list"
local selected = 1
local scroll = 0
local itemHeight = 20
local didAction = true
local scrollRepeatTimer = nil
local rename = false 
local timerInitialDelay,timerRepeatDelay = 300,40
-- path is filled out when loaded by system
widget.metadata = {
	name = "To-do List",
	game = "com.hydrasoftworks.pocketplanner",
	path = nil
}

widget.image = nil

-- Fill these out with your inputs
function widget:AButtonDown()
	didAction = false
	if selected > #list then
		didAction = true
		addItem()
	end
end

function addItem()
	table.insert(list,"")
	selected = #list
	renameSelectedItem()
end

function playdate.keyboard.keyboardWillHideCallback(pressedOK)
	if rename then
		rename = false
		--if playdate.keyboard.text == "" then return end 
		if pressedOK then list[selected] = playdate.keyboard.text end
		widget:loadWidgetImage()
		saveList()
	end
end

function playdate.keyboard.textChangedCallback()
	if rename then
		if gfx.getTextSize(playdate.keyboard.text) > 190 then
			playdate.keyboard.text = string.sub(playdate.keyboard.text,1,#playdate.keyboard.text - 1)
		end
		list[selected] = playdate.keyboard.text
		widget:loadWidgetImage()
	end
end

function widget:AButtonUp()
	-- Open the bundle id listed in Metadata
	if not didAction then
		--openApp(self.metadata.game)
	end
end

-- If a B button function isn't provided, this is the default action for it.
function widget:BButtonUp()
	-- Removes focus from the widget so others can be selected
	-- Need this line somewhere if you use the B button.
	widgetIsActive = false
	selected = 1
	scroll = 0
	widget:loadWidgetImage()
end

function widget:upButtonDown()
	if playdate.buttonIsPressed("A") then
		didAction = true
		removeScrollTimer()
		scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, moveSelectedItemUp)
	else
		scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, moveUp)
	end
end

function moveSelectedItemUp()
	if selected == 1 then return end
	local item = table.remove(list,selected)
	table.insert(list,selected-1,item)
	moveUp()
	saveList()
end

function moveUp()
	selected=math.max(selected-1,1)
	if selected < scroll+1 then
		scroll=scroll-1
	end	
	widget:loadWidgetImage()
end

function widget:upButtonUp()
	removeScrollTimer()
end

function widget:downButtonDown()
	if playdate.buttonIsPressed("A") then
		didAction = true
		removeScrollTimer()
		scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, moveSelectedItemDown)
	else
		scrollRepeatTimer = playdate.timer.keyRepeatTimerWithDelay(timerInitialDelay,timerRepeatDelay, moveDown)
	end
end

function moveSelectedItemDown()
	if selected >= #list  then return end
	local item = table.remove(list,selected)
	table.insert(list,selected+1,item)
	moveDown()
	saveList()
end

function moveDown()
	selected=math.min(selected+1,#list+1)
	if selected > (200/itemHeight)-2+scroll then
		scroll=scroll+1
	end
	widget:loadWidgetImage()
end


function widget:downButtonUp()
	removeScrollTimer()
end

function removeScrollTimer()
	if scrollRepeatTimer ~= nil then
		scrollRepeatTimer:pause()
		scrollRepeatTimer:remove()
		scrollRepeatTimer = nil
	end	
end

function widget:leftButtonDown()

	if playdate.buttonIsPressed("A") then
		didAction = true	
		removeSelectedItem()
	end
end

function widget:rightButtonDown()

	if playdate.buttonIsPressed("A") then
		didAction = true	
		renameSelectedItem()
	end
end

function renameSelectedItem()
	if selected <= #list then
		playdate.keyboard.show()	
		playdate.keyboard.text = list[selected]
		rename = true
		widget:loadWidgetImage()	
	end
end

function removeSelectedItem()
	if selected <= #list then
		table.remove(list,selected)
		widget:loadWidgetImage()
		saveList()
	end	
end

-- Refresh the widget image
function widget:loadWidgetImage()
	widget.image = playdate.graphics.image.new(200, 200)
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRect(0, 0, 200, 200)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		
		gfx.setColor(gfx.kColorBlack)
		for i,v in ipairs(list) do
			
			gfx.setImageDrawMode(gfx.kDrawModeCopy)
			local y = i*itemHeight - scroll*itemHeight + 5
			if i == selected and widgetIsActive then
				gfx.fillRect(0, y, 200, itemHeight)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
			end
			if y > 15 and y < 200 then
				gfx.drawText(v,5,y+3)
			end
			gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
		end
		gfx.drawTextAligned("To-Do List",100, 7,kTextAlignment.center)
		local y = (#list+1)*itemHeight - scroll*itemHeight + 5
		if #list+1 == selected and widgetIsActive then
			gfx.fillRect(0, y, 200, itemHeight)
			gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		end
		gfx.drawText("+ Add Item",5, y+3)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		
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
	if isActive then
		
	end
end

function saveList()
	playdate.file.mkdir(listPath)
	playdate.datastore.write(list,listPath..listFilename)	
end

-- Called when FunnyOS boots up
function widget:init()
	list = playdate.datastore.read(listPath..listFilename)
	if not list then 
		list = {}
		saveList()
	end
	widget:getWidgetImage()	
end

return widget