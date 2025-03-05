local ExampleWidget = {}
local widget = ExampleWidget

widget.metadata = {
    name = "Example Widget",
    game = "com.pencilpals.illuremination"
}

widget.style = {
    cornerRadius = 12,
    inverted = false,
}

widget.image = playdate.graphics.image.new(200, 200)

-- Input handlers
function widget:AButtonDown()
    OpenApp(self.metadata.game)
    print("hi :D")
end

function widget:upButtonDown()
    self.style.inverted = not self.style.inverted
end

function widget:downButtonDown()
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
        -- Draw widget content
        playdate.graphics.clear(playdate.graphics.kColorClear)
        
        if self.style.inverted then
            playdate.graphics.setColor(playdate.graphics.kColorBlack)
        else
            playdate.graphics.setColor(playdate.graphics.kColorWhite)
        end
        
        playdate.graphics.fillRoundRect(0, 0, 200, 200, self.style.cornerRadius)
        
        playdate.graphics.setColor(playdate.graphics.kColorBlack)
        playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeCopy)
        
        playdate.graphics.drawText("Example Widget", 10, 90)
    playdate.graphics.popContext()
    
    self.lastDrawnImage = widget.image:copy()
    return widget.image
end

return widget
