-- grid widget test

local gui = include("lib/gridui")

g = grid.connect()

grid_needs_redraw = true
needs_redraw = true

function init()
  channel_radio = gui.radio.new{
    x=1,
    y=1,
    size=3,
    action=function(option)
      print("channel: "..option)
      pitch_keyboard.hidden = option ~= 1
      strength_fader.hidden = option ~= 2
      speed_fader.hidden = option ~= 3
      time_fader.hidden = option ~= 3
      for i=1,3 do
        for j=1,8 do
          channel_faders[i][j].hidden = i~=option
        end
      end
    end,
  }
  
  clock_toggle = gui.toggle.new{
    x=1,
    y=8,
    action=function(s)
      print("clock: "..s)
    end,
  }
  
  direction_button = gui.button.new{
    x=1,
    y=7,
    action=function(s)
      print("direction: "..s)
    end,
  }
  
  interrupt_toggle = gui.toggle.new{
    x=1,
    y=6,
    action=function(s)
      print("interrupt: "..s)
    end,
  }
  
  step_radio = gui.radio.new{
    x=4,
    y=1,
    size=8,
    action=function(value)
      print("step: "..value)
      if channel_radio.state == 1 then
        pitch_keyboard.value = channel_faders[1][value].value
      end
    end,
  }
  
  channel_faders = {}
  for i = 1, 3 do
    step_faders = {}
    for j = 1, 8 do
      table.insert(step_faders, gui.hfader.new{
        x=5,
        y=j,
        hidden=i~=1,
        action=function(value)
          print("channel step: "..i.." "..j.." "..value)
        end,
      })
    end
    table.insert(channel_faders, step_faders)
  end
  
  pitch_keyboard = gui.keyboard.new{
    x=2,
    action=function(note)
      print("pitch: "..note)
      local step = step_radio.state
      channel_faders[1][step].value = note
    end,
  }
  
  strength_fader = gui.vfader.new{
    x=3,
    hidden=true,
    action=function(value)
      print("strength mod: "..value)
    end,
  }
  
  speed_fader = gui.vfader.new{
    x=2,
    hidden=true,
    action=function(value)
      print("speed: "..value)
    end,
  }
  
  time_fader = gui.vfader.new{
    x=3,
    hidden=true,
    action=function(value)
      print("time mod: "..value)
    end,
  }
  
  widgets = {
    channel_radio,
    clock_toggle,
    direction_button,
    interrupt_toggle,
    step_radio,
    pitch_keyboard,
    strength_fader,
    speed_fader,
    time_fader,
  }
  for i=1,3 do
    for j=1,8 do
      table.insert(widgets, channel_faders[i][j])
    end
  end
  for y=1,8 do
    for x=1,4 do
      table.insert(widgets, gui.button.new{
        x=12+x,
        y=y,
        action=function(s)
          print("pressure: "..y.." "..x.." "..s)
        end
      })
    end
  end
  
  clock.run(function()
    while true do
      clock.sleep(1/15)
      grid_redraw()
      redraw()
    end
  end)
end

function redraw()
  if not needs_redraw then
    return
  end
  needs_redraw = false
  
  screen.clear()
  screen.update()
end

function grid_redraw()
  if not grid_needs_redraw then
    return
  end
  grid_needs_redraw = false
  
  g:all(0)
  
  for _, widget in ipairs(widgets) do
    widget:redraw(g)
  end

  g:refresh()
end

function g.key(x, y, s)
  for _, widget in ipairs(widgets) do
    if widget:key(x, y, s) then
      grid_needs_redraw = true
      return
    end
  end
end
