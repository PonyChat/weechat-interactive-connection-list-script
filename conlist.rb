# 
# Copyright (C) 2012 Kyle Johnson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.)
#
# Controls:
#
#   Up/Down Arrows      Navigate list by single lines.
#   Page Up/Down        Navigate list by whole pages.
#   Home/End            Navigate to the first or last item.
#   r                   Refresh list.
#   c                   Clear list.
#   k                   Flag selected item for KILL.
#   a                   Flag selected item for AKILL.
#   u                   Unflag selected item.
#   Enter               Apply pending KILLs and AKILLs.
#


ICL_Client = Struct.new(:time, :nick, :ip, :status, :current)

def weechat_init
  Weechat.register("conlist", "Kabaka", "1.0", "MIT", "Interactive Connection List", "", "")

  @buffer = Weechat.buffer_new("Connections", "buf_in_cb", "", "", "")
  @recent, @selected = [], 0


  # Change me!
  server_name = "server.ponychat"


  Weechat.buffer_set(@buffer, "title", "Interactive Connection List")

  Weechat.hook_command("icl", "Connection List Control", "", "", "", "cmd", "")
  Weechat.hook_modifier("input_text_content", "input_cb", "")

  Weechat.buffer_set(@buffer, "key_bind_meta2-A",  "/icl up")
  Weechat.buffer_set(@buffer, "key_bind_meta2-B",  "/icl down")
  Weechat.buffer_set(@buffer, "key_bind_meta2-5~", "/icl pageup")
  Weechat.buffer_set(@buffer, "key_bind_meta2-6~", "/icl pagedown")
  Weechat.buffer_set(@buffer, "key_bind_meta2-7~", "/icl home")
  Weechat.buffer_set(@buffer, "key_bind_meta2-8~", "/icl end")
  Weechat.buffer_set(@buffer, "key_bind_k",        "/icl kill")
  Weechat.buffer_set(@buffer, "key_bind_a",        "/icl akill")
  Weechat.buffer_set(@buffer, "key_bind_u",        "/icl unset")
  Weechat.buffer_set(@buffer, "key_bind_ctrl-M",   "/icl commit")
  Weechat.buffer_set(@buffer, "key_bind_c",        "/icl clear")
  Weechat.buffer_set(@buffer, "key_bind_r",        "/icl refresh")

  @server_buffer = Weechat.buffer_search("irc", server_name)

  if @server_buffer == nil
    Weechat.print("", "Server buffer cannot be found.")
    return Weechat::WEECHAT_RC_ERROR
  end

  Weechat.hook_print(@server_buffer, "", "Client connecting", 0, "conn_hook", "")
  
  Weechat::WEECHAT_RC_OK
end

def conn_hook(data, buffer, date, tags, displayed, highlight, prefix, message)
  return Weechat::WEECHAT_RC_OK unless message =~ /Client connecting: ([^ ]+) \([^)]+\) \[([0-9.:]+)\]/

  scroll_after_update = @selected == @recent.length - 1

  @recent << ICL_Client.new(Time.now, $1, $2, :unbanned, false)
  @recent.shift if @recent.length > 1000

  if scroll_after_update
    scroll_end
  else
    update_display
  end

  Weechat::WEECHAT_RC_OK
end

def input_cb(data, modifier, modifier_data, string)
  return string if @buffer != Weechat.current_buffer

  ""
end

def cmd(data, buffer, args)
  arr = args.split

  case arr.shift.upcase

  when "DOWN"
    scroll_down
  when "UP"
    scroll_up
  when "PAGEDOWN"
    scroll_page_down
  when "PAGEUP"
    scroll_page_up
  when "HOME"
    scroll_home
  when "END"
    scroll_end
  when "AKILL"
    akill
  when "KILL"
    kill
  when "UNSET"
    unset
  when "COMMIT"
    commit
  when "CLEAR"
    clear
  when "REFRESH"
    update_display
  end

  Weechat::WEECHAT_RC_OK
end

def scroll_down
  @selected += 1 unless @selected == @recent.length - 1

  update_display
end

def scroll_up
  return if @selected == 0
  @selected -= 1

  update_display
end

def scroll_page_down
  height = Weechat.window_get_integer(Weechat.current_window(), "win_chat_height")

  return if @selected + height > @recent.length - 1
  @selected += height

  update_display
end

def scroll_page_up
  height = Weechat.window_get_integer(Weechat.current_window(), "win_chat_height")

  return if @selected == 0

  if @selected - height < 0
    @selected = 0
  else
    @selected -= height
  end

  update_display
end

def scroll_home
  @selected = 0

  update_display
end

def scroll_end
  @selected = @recent.length - 1

  update_display
end

def kill
  return if @recent[@selected] == nil

  @recent[@selected].status = :kill_pending

  scroll_down
end

def akill
  return if @recent[@selected] == nil

  @recent[@selected].status = :akill_pending

  scroll_down
end

def unset
  return if @recent[@selected] == nil
  
  return if @recent[@selected].status == :akilled
  return if @recent[@selected].status == :killed

  @recent[@selected].status = :unbanned

  update_display
end

def commit
  @recent.each do |conn|
    case conn.status
      
    when :akill_pending
      Weechat.command(@server_buffer, "/os AKILL ADD *@#{conn.ip} !T 1h Drones")
      conn.status = :akilled

    when :kill_pending
      Weechat.command(@server_buffer, "/kill #{conn.nick} Drones")
      conn.status = :killed

    end
  end

  update_display
end

def clear
  @selected = 0
  @recent.clear
  update_display
end

def update_display
  Weechat.buffer_clear(@buffer)

  height = Weechat.window_get_integer(Weechat.current_window(), "win_chat_height")

  start = 0

  if @selected + 1 > height
    start = ((@selected / height).floor * height)
  end

  @recent[start..start + height - 1].each_with_index do |conn, index|
    color = ""

    case conn.status

    when :killed
      color << Weechat.color("red")

    when :akilled
      color << Weechat.color("lightred")

    when :kill_pending
      color << Weechat.color("brown")

    when :akill_pending
      color << Weechat.color("yellow")

    else
      color << Weechat.color("green")

    end

    color << Weechat.color("reverse") if index + start == @selected

    str = sprintf("%s\t%s%-40s %s", conn.nick, color, conn.ip, conn.status)
    
    Weechat.print_date_tags(@buffer, conn.time.to_i, "", str)
  end
end
