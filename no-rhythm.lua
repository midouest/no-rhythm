-- 0-ctrl inspired sequencer

s = require("sequins")

gui = include("lib/gridui")

g = grid.connect()

clock_running = false
clock_id = nil
seq_dir = 1

seqs = {
  s{0,0,0,0,0,0,0,0},
  s{0,0,0,0,0,0,0,0},
  s{0,0,0,0,0,0,0,0},
}

selected_chan = 1
selected_step = 1

strength_mod = 0
speed = 0
time_mod = 0

grid_needs_redraw = true
needs_redraw = true

function init()
  crow.output[2].action = "pulse(dyn{time=1},dyn{level=8})"
  crow.output[3].action = "ar(0,dyn{time=1},dyn{level=8},'exp')"
  
  channel_radio = gui.radio.new{
    x=1,
    y=1,
    size=3,
    action=function(option)
      pitch_keyboard.hidden = option ~= 1
      strength_fader.hidden = option ~= 2
      speed_fader.hidden = option ~= 3
      time_fader.hidden = option ~= 3
      for i=1,3 do
        for j=1,8 do
          channel_faders[i][j].hidden = i~=option
        end
      end
      selected_chan = option
    end,
  }
  
  clock_toggle = gui.toggle.new{
    x=1,
    y=8,
    action=function(s)
      toggle_clock(s)
    end,
  }
  
  direction_toggle = gui.toggle.new{
    x=1,
    y=7,
    action=function(s)
      toggle_direction(s)
    end,
  }
  
  interrupt_toggle = gui.toggle.new{
    x=1,
    y=6,
    action=function(s)
    end,
  }
  
  step_radio = gui.radio.new{
    x=4,
    y=1,
    size=8,
    action=function(value)
      selected_step = value
      if selected_chan == 1 then
        pitch_keyboard.value = seqs[1][value]
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
          seqs[i][j] = value
          if i == 1 and selected_chan == 1 and j == selected_step then
            pitch_keyboard.value = value
          end
        end,
      })
    end
    table.insert(channel_faders, step_faders)
  end
  
  pitch_keyboard = gui.keyboard.new{
    x=2,
    action=function(note)
      seqs[1][selected_step] = note
      channel_faders[1][selected_step].value = note
    end,
  }
  
  strength_fader = gui.vfader.new{
    x=3,
    hidden=true,
    action=function(value)
      strength_mod = value
    end,
  }
  
  speed_fader = gui.vfader.new{
    x=2,
    hidden=true,
    action=function(value)
      speed = value
    end,
  }
  
  time_fader = gui.vfader.new{
    x=3,
    hidden=true,
    action=function(value)
      time_mod = value
    end,
  }
  
  widgets = {
    channel_radio,
    clock_toggle,
    direction_toggle,
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

function toggle_clock()
  if not clock_running then
    clock_running = true
    clock_id = clock.run(function()
      while clock_running do
        local p = seqs[1]()
        local s = seqs[2]()
        local s_volts = util.linlin(0, 127, 0, 8, s)
        local t = seqs[3]()
        local time_scale = util.linlin(0, 127, 0, 1.0, time_mod)
        local bpm = util.linlin(0, 127, 1, 300, speed - time_scale * t)
        local delay = 60/bpm/4
        crow.output[1].volts = (p/12) - 5
        crow.output[2].dyn.time=delay/2
        crow.output[2].dyn.level=s_volts
        crow.output[2]()
        crow.output[3].dyn.time=delay/2
        crow.output[3].dyn.level=s_volts
        crow.output[3]()
        clock.sleep(delay)
      end
    end)
  else
    clock_running = false
    clock.cancel(clock_id)
  end
end

function toggle_direction()
  seq_dir = -seq_dir
  for _, seq in ipairs(seqs) do
    seq:step(seq_dir)
  end
end
