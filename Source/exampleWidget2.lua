local ExampleWidget2 = {}
local widget = ExampleWidget2

widget.metadata = {
    name = "Example Widget 2",
    game = "com.pencilpals.illuremination"
}

widget.style = {
    cornerRadius = 12,  -- 1-25
    inverted = false,   -- true for black bg, false for white
}

widget.image = playdate.graphics.image.new(200, 200)

-- Input handlers
function widget:AButtonDown()
    OpenApp(self.metadata.game)
end

function widget:upButtonDown()
    -- Handle up button
    self.style.inverted = not self.style.inverted
end

function widget:downButtonDown()
    -- Handle down button
    self.style.cornerRadius = (self.style.cornerRadius % 25) + 1
end

function widget:leftButtonDown()
    self.style.cornerRadius = math.max(1, self.style.cornerRadius - 1)
end

function widget:rightButtonDown()
    self.style.cornerRadius = math.min(25, self.style.cornerRadius + 1)
end

function widget:main(path)
    
    playdate.graphics.pushContext(widget.image)
        -- Clear the widget
        playdate.graphics.clear(playdate.graphics.kColorClear)
        
        -- Draw background with styling
        if self.style.inverted then
            playdate.graphics.setColor(playdate.graphics.kColorBlack)
        else
            playdate.graphics.setColor(playdate.graphics.kColorWhite)
        end
        
        playdate.graphics.fillRoundRect(0, 0, 200, 200, self.style.cornerRadius)
        
        -- Reset draw settings for content
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
        
        -- Draw content (now on top of background)
        playdate.graphics.drawText("Example Widget 2", 10, 90)

    playdate.graphics.popContext()
    
    -- Cache this image for when widget is inactive
    self.lastDrawnImage = widget.image
    
    return widget.image
end

return widget
