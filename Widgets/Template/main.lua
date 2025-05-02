local TemplateWidget = {}
local widget = TemplateWidget

local counter = 0

-- path is filled out when loaded by system
widget.metadata = {
	name = "Template Widget!",
	game = "com.panic.settings",
	path = nil
}

widget.image = nil

-- Fill these out with your inputs
function widget:AButtonUp()
	-- Open the bundle id listed in Metadata
	openApp(self.metadata.game)
end

-- If a B button function isn't provided, this is the default action for it.
function widget:BButtonUp()
	-- Removes focus from the widget so others can be selected
	-- Need this line somewhere if you use the B button.
	widgetIsActive = false
end

function widget:AButtonDown()
end

function widget:BButtonDown()
	
end

function widget:upButtonDown()
	
end

function widget:downButtonDown()
	
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

-- Refresh the widget image
function widget:loadWidgetImage()
	widget.image = playdate.graphics.image.new(200, 200)
	playdate.graphics.pushContext(widget.image)
		-- Draw widget content
		playdate.graphics.clear(playdate.graphics.kColorClear)

		playdate.graphics.setColor(playdate.graphics.kColorWhite)
		playdate.graphics.fillRoundRect(0, 0, 200, 200, configVars.cornerradius)

		playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
		playdate.graphics.drawTextAligned(tostring(counter), 100, 91, kTextAlignment.center)
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
		counter+=1
		-- Refresh graphic
		widget:loadWidgetImage()
	end
end

-- Called when FunnyOS boots up
function widget:init()
	widget:getWidgetImage()	
end

return widget