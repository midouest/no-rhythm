-- 0-ctrl inspired sequencer

s = require("sequins")

gui = include("lib/gridui/gridui")

g = grid.connect()

clock_running = false
clock_id = nil
seq_dir = 1

seqs = {
  s{60,60,60,60,60,60,60,60},
  s{127,0,0,0,0,0,0,0},
  s{0,0,0,0,0,0,0,0},
}

selected_chan = 1
selected_step = 1

strength_mod = 127
speed = 63
time_mod = 63

interrupt = false
last_touch = 1
pressure = {
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
  {0, 0, 0, 0},
}

grid_needs_redraw = true
needs_redraw = true

function init()
  crow.output[2].action = "pulse(dyn{time=1},dyn{level=8})"
  crow.output[3].action = "ar(0,dyn{time=1},dyn{level=8},'exp')"
  crow.output[4].slew = 0.1
  
  pitch_group = gui.group.new()
  strength_group = gui.group.new{hidden=true}
  time_group = gui.group.new{hidden=true}
  
  channel_radio = gui.radio.new{
    x=1,
    y=1,
    size=3,
    action=function(option)
      select_channel(option)
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
      toggle_interrupt()
    end,
  }
  
  step_radio = gui.radio.new{
    x=4,
    y=1,
    size=8,
    action=function(value)
      select_step(value)
    end,
  }
  
  channel_faders = {}
  for i, group in ipairs({pitch_group, strength_group, time_group}) do
    step_faders = {}
    for j = 1, 8 do
      local fader = gui.hfader.new{
        x=5,
        y=j,
        initial=seqs[i][j],
        action=function(value)
          select_step_fader(i, j, value)
        end,
      }
      table.insert(step_faders, fader)
      group:add(fader)
    end
    table.insert(channel_faders, step_faders)
  end
  
  pitch_keyboard = gui.keyboard.new{
    x=2,
    initial=seqs[1][1],
    action=function(note)
      select_pitch(note)
    end,
  }
  pitch_group:add(pitch_keyboard)
  
  strength_fader = gui.vfader.new{
    x=3,
    initial=strength_mod,
    action=function(value)
      select_strength_mod(value)
    end,
  }
  strength_group:add(strength_fader)
  
  speed_fader = gui.vfader.new{
    x=2,
    initial=speed,
    action=function(value)
      select_speed(value)
    end,
  }
  time_group:add(speed_fader)
  
  time_fader = gui.vfader.new{
    x=3,
    initial=time_mod,
    action=function(value)
      select_time_mod(value)
    end,
  }
  time_group:add(time_fader)
  
  pressure_group = gui.group.new()
  pressure_buttons = {}
  for y=1,8 do
    local row = {}
    for x=1,4 do
      local button = gui.button.new{
        x=12+x,
        y=y,
        on=7,
        action=function(s)
          set_pressure_plate(y, x, s)
        end
      }
      table.insert(row, button)
      pressure_group:add(button)
    end
    table.insert(pressure_buttons, row)
  end
  
  root_group = gui.group.new()
  root_group:add(channel_radio)
  root_group:add(clock_toggle)
  root_group:add(direction_toggle)
  root_group:add(interrupt_toggle)
  root_group:add(step_radio)
  root_group:add(pitch_group)
  root_group:add(strength_group)
  root_group:add(time_group)
  root_group:add(pressure_group)
  
  grid_redraw()
end

function refresh()
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
  root_group:redraw(g)
  g:refresh()
end

function g.key(x, y, s)
  if root_group:key(x, y, s) then
    grid_needs_redraw = true
    grid_redraw()
  end
end

function select_channel(index)
  pitch_group.hidden = index ~= 1
  strength_group.hidden = index ~= 2
  time_group.hidden = index ~= 3
  selected_chan = index
end

function select_step(index)
  selected_step = index
  if selected_chan == 1 then
    pitch_keyboard.value = seqs[1][index]
  end
end

function select_step_fader(channel, step, value)
  seqs[channel][step] = value
  if channel == 1 and selected_chan == channel and step == selected_step then
    pitch_keyboard.value = value
  end
end

function select_pitch(note)
  seqs[1][selected_step] = note
  channel_faders[1][selected_step].value = note
end

function select_strength(value)
  strength_mod = value
end

function select_speed(value)
  speed = value
end

function select_time_mod(value)
  time_mod = value
end

function toggle_clock()
  if not clock_running then
    start_clock()
  else
    stop_clock()
  end
end

function start_clock()
  if clock_running and clock_id ~= nil then
    clock.cancel(clock_id)
  end
  clock_running = true
  clock_id = clock.run(run_sequencer)
end

function stop_clock()
  clock_running = false
  clock.cancel(clock_id)
  clock_id = nil
end

function run_sequencer()
  while clock_running do
    if interrupt then
      for _, p in ipairs(pressure[last_touch]) do
        if p > 0 then
          for _, seq in ipairs(seqs) do
            seq:select(last_touch)
          end
          break
        end
      end
    end
    
    local p = seqs[1]()
    local s = seqs[2]()
    local s_volts = (strength_mod/127) * util.linlin(0, 127, 0, 8, s)
    local t = seqs[3]()
    local bpm = util.linlin(0, 127, 15, 300, speed - (time_mod/127) * t)
    local delay = 60/bpm/4
    crow.output[1].volts = (p/12) - 5
    crow.output[2].dyn.time=delay/2
    crow.output[2].dyn.level=s_volts
    crow.output[2]()
    crow.output[3].dyn.time=delay/2
    crow.output[3].dyn.level=s_volts
    crow.output[3]()
    
    local ix = seqs[1].ix
    for y=1,8 do
      for x=1,4 do
        pressure_buttons[y][x].level = ix==y and 15 or 0
      end
    end
    grid_needs_redraw = true
    grid_redraw()

    clock.sleep(delay)
  end
end

function set_pressure_plate(step, index, value)
  pressure[step][index] = value
  
  if value == 1 then
    select_step(step)
    step_radio.state = step
    last_touch = step

    if interrupt then
      for _, seq in ipairs(seqs) do
        seq:select(last_touch)
      end
      if clock_running then
        start_clock()
      else
        local p = seqs[1]()
        seq[1]:select(last_touch)
        crow.output[1].volts = (p/12) - 5
      end
    end
  end
  
  local expr = 0
  for i, p in ipairs(pressure[last_touch]) do
    expr = expr | (p<<(4-i))
  end
  crow.output[4].volts = 10 * expr / 15
end

function toggle_direction()
  seq_dir = -seq_dir
  for _, seq in ipairs(seqs) do
    seq:step(seq_dir)
  end
end

function toggle_interrupt()
  interrupt = not interrupt
end