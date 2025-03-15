-- 8 step sequencer
--
-- pitch, strength and time

s = require("sequins")
music = require("musicutil")
tab = require("tabutil")

g = grid.connect()

pitch_chan = 1
strength_chan = 2
time_chan = 3

num_chan = 3
num_step = 8

selected_chan = pitch_chan
selected_step = 1

seq_running = false
seq_clock = nil

seq = {
  s{0,0,0,0,0,0,0,0},
  s{0,0,0,0,0,0,0,0},
  s{0,0,0,0,0,0,0,0},
}

locked = {false,false,false,false,false,false,false,false}

needs_redraw = true

pulse_dir = 1
pulse = 0

function init()
  params:add_separator("8step")
  for i=1,8 do
    params:add{
      id="8step_chan_step"..i,
      name="Active Step "..i,
      type="number",
      min=0,
      max=127,
      default=0,
      action=function(v)
        if locked[i] then
          local prev = seq[selected_chan][i]
          if v < prev-1 or v > prev+1 then
            return
          else
            locked[i] = false
          end
        end
        seq[selected_chan][i] = v
      end
    }
  end
  
  clock.run(function()
    while true do
      clock.sleep(1/15)
      update()
      redraw()
      grid_redraw()
    end
  end)
  
  grid_redraw()
end

function enc(n, d)
  if n == 3 then
    local v = seq[selected_chan][selected_step]
    seq[selected_chan][selected_step] = math.min(math.max(v + d, 0), 127)
    locked[selected_step] = true
  end
end

function key(n, s)
end

function g.key(x, y, s)
  if x == 1 then
    if s==1 then
      if y==8 then
        toggle_clock()
      end
    end
  elseif x >= 2 and x <= 4 then
    if s==1 then
      local new_selected_chan = x - 1
      if new_selected_chan ~= selected_chan then
        locked = {true,true,true,true,true,true,true,true}
      end
      selected_chan = new_selected_chan
      selected_step = y
    end
  elseif x >= 5 and x <= 13 then
    selected_step = y
    if s==1 then
      local i = x-5
      local value = i*16
      seq[selected_chan][selected_step] = value
      locked[selected_step]=true
    end
  end
end

function toggle_clock()
  if not seq_running then
    seq_running = true
    clock_id = clock.run(function()
      while seq_running do
        clock.sleep(1/8)
        local pitch = seq[pitch_chan]()
        local strength = seq[strength_chan]()
        local t = seq[time_chan]()
        crow.output[1].volts = (pitch / 12) - 5
        crow.output[2].volts = 10 * strength / 127
        crow.output[3].volts = 10 * t / 127
      end
    end)
  else
    seq_running = false
    clock.cancel(clock_id)
    clock_id = nil
  end
end

function update()
  if pulse == 15 and pulse_dir == 1 then
    pulse_dir = -1
  elseif pulse == 0 and pulse_dir == -1 then
    pulse_dir = 1
  end
  pulse = pulse + pulse_dir
end

function grid_redraw()
  g:all(0)
  
  if seq_running then
    g:led(1, 8, 15)
  end
  
  for x=1,num_chan do
    local ix = seq[x].ix
    for y=1,num_step do
      local v = seq[x][y]
      local level=math.floor(v/16+0.5)
      if y == ix then
        level = level + 2
      end
      if x==selected_chan then
        if y==selected_step then
          level=pulse
        else
          level=level+3
        end
      end
      g:led(x+1, y, level)
    end
  end
  
  for y=1,num_step do
    local v = seq[selected_chan][y]
    if v == 0 then
      g:led(5, y, 15)
    else
      local fil = v//16
      local rem = v%16
      for x=6,5+fil do
        g:led(x, y, 15)
      end
      g:led(6+fil, y, rem)
    end
  end
  
  g:refresh()
end

function redraw()
  if not needs_redraw then
    return
  end
  needs_redraw = false
  
  screen.clear()
  screen.update()
end