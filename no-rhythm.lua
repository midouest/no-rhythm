-- 0-ctrl inspired sequencer

tab = require("tabutil")
s = require("sequins")

gui = include("lib/gridui/gridui")
modmatrix = include("lib/patcher/modmatrix")
g = grid.connect()

ppqn = 96
divisions = {1, 2, 4}

current_page = 1

clock_stopped = false
clock_running = false
clock_id = nil
seq_dir = 1

seqs = {
  s{72,71,69,67,66,64,62,60},
  s{127,63,63,63,127,63,63,63},
  s{127,0,127,0,127,0,127,0},
}

selected_chan = 1
selected_step = 1
active_step = 1

strength_mod = 127
strength_cv = 0
speed = 100
time_mod = 127
time_cv = 0

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

selected_source = nil
selected_sink = nil

grid_needs_redraw = true
needs_redraw = true

function init()
  params:add_separator("no-rhythm")
  params:add{
    id="nr_beat_div",
    name="beat div",
    type="option",
    options=divisions,
    default=2,
  }
  
  for i, channel in ipairs({"strength", "time"}) do
    params:add_group("nr_"..channel, channel, 8)
    for j=1,8 do
      params:add{
        id="nr_"..channel..j,
        name=channel.." "..j,
        type="number",
        default=seqs[i+1][j],
        min=0,
        max=127,
        action=function(v)
          seqs[i+1][j] = v
          channel_faders[i+1][j].value = v
          grid_needs_redraw = true
        end
      }
    end
  end
  
  matrix = modmatrix.new()
  
  matrix:add_source{
    id="clock",
    type="gate",
    action=function(s)
      clock_src_button.level = s
      grid_needs_redraw = true
      grid_redraw()
    end
  }
  matrix:add_source{
    id="pitch",
    type="cv",
    action=function(v)
      pitch_src_button.level = v//12
    end,
    transform=function(v)
      return (v/12)-5
    end
  }
  matrix:add_source{
    id="strength",
    type="cv",
    action=function(v)
      strength_src_button.level = v//12
    end,
    transform=function(v)
      return util.linlin(0, 127, 0, 5, v)
    end
  }
  matrix:add_source{
    id="time",
    type="cv",
    action=function(v)
      time_src_button.level = v//12
    end,
    transform=function(v)
      return util.linlin(0, 127, 0, 5, v)
    end
  }
  matrix:add_source{
    id="pressure",
    type="cv",
    transform=function(v)
      return 10*v/15
    end
  }
  matrix:add_source{
    id="touch_gate",
    type="gate",
  }
  matrix:add_source{
    id="dyn_gate",
    type="gate",
    action=function(s)
      dyn_gate_src_button.level = util.round(s)
      grid_needs_redraw = true
      grid_redraw()
    end
  }
  matrix:add_source{
    id="dyn_env",
    type="env",
  }
  for i = 1, 8 do
    matrix:add_source{
      id="gate"..i,
      type="gate",
      action=function(s)
        gate_src_buttons[i].level = util.round(s)
        grid_needs_redraw = true
        grid_redraw()
      end
    }
  end
  for i = 1, 2 do
    matrix:add_source{
      id="crow"..i,
      type={"gate", "cv"},
      init=function(mode)
        if mode == "gate" then
          crow.input[i].mode = "change"
          crow.input[i].change = function(s)
            local value = s and 8 or 0
            matrix:send("crow"..i, value)
            matrix:update()
          end
        elseif mode == "cv" then
          crow.input[i]{
            mode="stream",
            time=0.002,
          }
          crow.input[i].stream = function(v)
            matrix:send("crow"..i, util.linlin(0, 10, 0, 127, v))
            matrix:update()
          end
        end
      end
    }
  end

  matrix:add_sink{
    id="clock",
    gate=function(s)
      if s > 0 then
        step_hi()
      else
        step_lo()
      end
    end,
  }
  matrix:add_sink{
    id="dyn_reset",
    gate=function(s)
      if s > 0 then
        for _, seq in ipairs(seqs) do
          seq:select(last_touch)
        end
      end
    end,
  }
  matrix:add_sink{
    id="stop",
    gate=function(s)
      clock_stopped = s > 0
    end,
  }
  matrix:add_sink{
    id="direction",
    gate=function(s)
      if s > 0 then
        toggle_direction()
        direction_toggle.state = 1 - direction_toggle.state
      end
    end,
  }
  matrix:add_sink{
    id="strength",
    cv=function(v)
      strength_cv = v
    end,
  }
  matrix:add_sink{
    id="time",
    cv=function(v)
      time_cv = v
    end,
  }
  for i=1,4 do
    matrix:add_sink{
      id="crow"..i,
      external=true,
      init=function(mode)
        crow.output[i].volts = 0
        if mode == "env" then
          crow.output[i].action = "ar(0, dyn{decay=1}, dyn{level=8}, 'log')"
        end
      end,
      gate=function(v)
        crow.output[i].volts = v
      end,
      cv=function(v)
        crow.output[i].volts = v
      end,
      env=function(e)
        crow.output[i].dyn.level = e.level
        crow.output[i].dyn.decay = e.decay
        crow.output[i]()
      end,
    }
  end
  for i=1,6 do
    matrix:add_sink{
      id="jf.tr"..i,
      external=true,
      gate=function(v)
        crow.ii.jf.trigger(i, v)
      end
    }
  end
  
  matrix:normalize("time", "time")
  matrix:normalize("strength", "strength")
  matrix:normalize("clock", "clock")
  
  matrix:connect("pitch", "crow1")
  matrix:connect("time", "crow2")
  matrix:connect("dyn_env", "crow3")
  matrix:connect("touch_gate", "crow4")

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
  
  seq_group = gui.group.new()
  seq_group:add(channel_radio)
  seq_group:add(clock_toggle)
  seq_group:add(direction_toggle)
  seq_group:add(interrupt_toggle)
  seq_group:add(step_radio)
  seq_group:add(pitch_group)
  seq_group:add(strength_group)
  seq_group:add(time_group)
  seq_group:add(pressure_group)
  
  clock_src_button = gui.button.new{
    x=1,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "clock")
    end
  }
  pitch_src_button = gui.button.new{
    x=5,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "pitch")
    end
  }
  strength_src_button = gui.button.new{
    x=6,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "strength")
    end
  }
  time_src_button = gui.button.new{
    x=7,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "time")
    end
  }
  pressure_src_button = gui.button.new{
    x=8,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "pressure")
    end
  }
  touch_gate_src_button = gui.button.new{
    x=9,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "touch_gate")
    end
  }
  dyn_gate_src_button = gui.button.new{
    x=10,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "dyn_gate")
    end
  }
  dyn_env_src_button = gui.button.new{
    x=11,
    y=1,
    off=3,
    action=function(s)
      select_source(s, "dyn_env")
    end
  }
  crow_src_buttons = {}
  crow_src_group = gui.group.new()
  for i=1,2 do
    local button = gui.button.new{
      x=12+i,
      y=1,
      off=3,
      action=function(s)
        select_source(s, "crow"..i)
      end
    }    
    table.insert(crow_src_buttons, button)
    crow_src_group:add(button)
  end
  gate_src_buttons = {}
  gate_src_group = gui.group.new()
  for i=1,8 do
    local button = gui.button.new{
      x=4+i,
      y=3,
      off=3,
      action=function(s)
        select_source(s, "gate"..i)
      end
    }
    table.insert(gate_src_buttons, button)
    gate_src_group:add(button)
  end
  clock_sink_button = gui.button.new{
    x=1,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "clock")
    end
  }
  dyn_reset_sink_button = gui.button.new{
    x=2,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "dyn_reset")
    end
  }
  stop_sink_button = gui.button.new{
    x=3,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "stop")
    end
  }
  direction_sink_button = gui.button.new{
    x=4,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "direction")
    end
  }
  strength_sink_button = gui.button.new{
    x=6,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "strength")
    end
  }
  time_sink_button = gui.button.new{
    x=7,
    y=8,
    off=3,
    action=function(s)
      select_sink(s, "time")
    end
  }
  crow_sink_buttons = {}
  crow_sink_group = gui.group.new()
  for i=1,4 do
    local button = gui.button.new{
      x=12+i,
      y=8,
      off=3,
      action=function(s)
        select_sink(s, "crow"..i)
      end
    }
    table.insert(crow_sink_buttons, button)
    crow_sink_group:add(button)
  end
  
  jf_tr_sink_buttons = {}
  jf_tr_sink_group = gui.group.new()
  for i=1,6 do
    local button = gui.button.new{
      x=10+i,
      y=6,
      off=3,
      action=function(s)
        select_sink(s, "jf.tr"..i)
      end
    }
    table.insert(jf_tr_sink_buttons, button)
    jf_tr_sink_group:add(button)
  end
  
  patch_group = gui.group.new()
  patch_group:add(clock_src_button)
  patch_group:add(pitch_src_button)
  patch_group:add(strength_src_button)
  patch_group:add(time_src_button)
  patch_group:add(pressure_src_button)
  patch_group:add(touch_gate_src_button)
  patch_group:add(dyn_gate_src_button)
  patch_group:add(dyn_env_src_button)
  patch_group:add(crow_src_group)
  patch_group:add(gate_src_group)
  patch_group:add(clock_sink_button)
  patch_group:add(dyn_reset_sink_button)
  patch_group:add(stop_sink_button)
  patch_group:add(direction_sink_button)
  patch_group:add(strength_sink_button)
  patch_group:add(time_sink_button)
  patch_group:add(crow_sink_group)
  patch_group:add(jf_tr_sink_group)
  
  params:default()
  grid_redraw()
  
  clock.run(function()
    while true do
      clock.sleep(1/15)
      grid_redraw()
    end
  end)
end

function enc(n, d)
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, 2)
    needs_redraw = true
    grid_needs_redraw = true
    grid_redraw()
  end
end

function norns.crow.add(id, name, dev)
  matrix:init()
end

function refresh()
  if not needs_redraw then
    return
  end
  needs_redraw = false
  
  screen.clear()
  
  if current_page == 1 then
    screen.move(64, 36)
    screen.text_center("sequencer")
  elseif current_page == 2 then
    if selected_source then
      screen.move(64, 8)
      screen.text_center(selected_source)
    end
    screen.move(64, 36)
    screen.text_center("patcher")
    if selected_sink then
      screen.move(64, 62)
      screen.text_center(selected_sink)
    end
  end
  
  screen.update()
end

function grid_redraw()
  if not grid_needs_redraw then
    return
  end
  grid_needs_redraw = false
  
  g:all(0)
  local group
  if current_page == 1 then
    group = seq_group
  elseif current_page == 2 then
    group = patch_group
  end
  group:redraw(g)
  g:refresh()
end

function g.key(x, y, s)
  local group
  if current_page == 1 then
    group = seq_group
  elseif current_page == 2 then
    group = patch_group
  end
  
  if group:key(x, y, s) then
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

function select_strength_mod(value)
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
    matrix:send("clock", 0)
    matrix:update()
  end
  clock_running = true
  clock_id = clock.run(run_clock)
end

function stop_clock()
  clock_running = false
  if clock_id ~= nil then
    clock.cancel(clock_id)
  end
  clock_id = nil
  
  matrix:send("dyn_gate", 0)
  matrix:update()
end

function run_clock()
  while clock_running do
    for i=1,ppqn do
      local div = divisions[params:get("nr_beat_div")]
      local cycle = ppqn//div
      local half_cycle = cycle//2
      
      if (i-1)%cycle==0 then
        matrix:send("clock", 8)
        matrix:update()
      elseif (i+half_cycle-1)%cycle==0 then
        matrix:send("clock", 0)
        matrix:update()
      end
      clock.sync(1/ppqn)
    end
  end
end

function step_hi()
  if clock_stopped then
    for _, seq in ipairs(seqs) do
      seq:select(active_step)
    end
  end
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
  
  local div = divisions[params:get("nr_beat_div")]
  local cycle = ppqn//div
  local half_cycle = cycle//2

  local pitch_internal = seqs[1]()
  local strength_internal = seqs[2]()
  local time_internal = seqs[3]()
  local ix = seqs[1].ix
  
  matrix:send("gate"..active_step, 0)
  matrix:update()
  matrix:send("pitch", pitch_internal)
  matrix:send("strength", strength_internal)
  matrix:send("time", time_internal)
  matrix:update()
  matrix:send("gate"..ix, 8)
  active_step = ix
  matrix:update()

  local strength = (strength_mod/127) * strength_cv
  local time = (time_mod/127) * time_cv

  local base_bpm = util.linlin(0, 127, 60, 300, speed)
  local bpm_mod = util.linlin(0, 127, 0, base_bpm/2, time)
  local bpm = base_bpm - bpm_mod
  if params:string("clock_source") == "internal" then
    params:set("clock_tempo", bpm)
  end

  local beat_sec = 60/bpm
  local delay = beat_sec/div
  
  if strength > 0 then
    local dyn_gate = util.linlin(0, 127, 0, 8, strength)
    matrix:send("dyn_gate", dyn_gate)
    matrix:send("dyn_env", {level=dyn_gate, decay=delay})
    matrix:update()
  end
  for y=1,8 do
    for x=1,4 do
      pressure_buttons[y][x].level = ix==y and 15 or 0
    end
  end
  grid_needs_redraw = true
  grid_redraw()
end

function step_lo()
  matrix:send("dyn_gate", 0)
  matrix:update()
end

function set_pressure_plate(step, index, value)
  -- TODO: param to allow retrig on each pressure button?
  
  local prev_pressure = false
  for _, p in ipairs(pressure[step]) do
    if p > 0 then
      prev_pressure = true
      break
    end
  end
  
  pressure[step][index] = value
  
  if value == 1 and (step ~= last_touch or not prev_pressure) then
    select_step(step)
    step_radio.state = step
  
    if interrupt then
      last_touch = step
      for _, seq in ipairs(seqs) do
        seq:select(last_touch)
      end
      if clock_running then
        start_clock()
      else
        local pitch = seqs[1]()
        local strength = seqs[2]()
        local time = seqs[3]()
        local ix = seqs[1].ix
        for i=1,3 do
          seqs[i]:select(last_touch)
        end
        matrix:send("gate"..active_step, 0)
        matrix:update()
        matrix:send("pitch", pitch)
        matrix:send("strength", strength)
        matrix:send("time", time)
        matrix:send("gate"..ix, 8)
        active_step = ix
      end
    end
    matrix:send("touch_gate", 8)
  else
    local release = true
    for _, p in ipairs(pressure[last_touch]) do
      if p > 0 then
        release = false
        break
      end
    end
    if release then
      matrix:send("touch_gate", 0)
    end
  end
  
  local expr = get_pressure()
  matrix:send("pressure", expr)
  matrix:update()
end

function get_pressure()
  local expr = 0
  for i, p in ipairs(pressure[last_touch]) do
    expr = expr | (p<<(4-i))
  end
  return expr
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

function select_source(s, source_id)
  if s > 0 then
    selected_source = source_id
    toggle_connection()
  elseif source_id == selected_source then
    selected_source = nil
  end
  needs_redraw = true
end

function select_sink(s, sink_id)
  if s > 0 then
    selected_sink = sink_id
    toggle_connection()
  elseif sink_id == selected_sink then
    selected_sink = nil
  end
  needs_redraw = true
end

function toggle_connection()
  if not selected_source or not selected_sink then
    return
  end
  matrix:toggle(selected_source, selected_sink)
end