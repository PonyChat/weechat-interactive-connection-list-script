ICL_Client = Struct.new(:time, :nick, :ip, :status, :current)

def weechat_init
  Weechat.register("conlist", "Kabaka", "1.0", "MIT", "Interactive Connection List", "", "")

  @buffer = Weechat.buffer_new("Connections", "buf_in_cb", "", "", "")
  @recent, @selected = [], 0

  server_name = "server.load_testing"

  Weechat.buffer_set(@buffer, "title", "Interactive Connection List")

  Weechat.hook_command("icl", "Connection List Control", "", "", "", "cmd", "")
  Weechat.hook_modifier("input_text_content", "input_cb", "")

  Weechat.buffer_set(@buffer, "key_bind_meta2-A",  "/icl up")
  Weechat.buffer_set(@buffer, "key_bind_meta2-B",  "/icl down")
  Weechat.buffer_set(@buffer, "key_bind_meta2-5~", "/icl pageup")
  Weechat.buffer_set(@buffer, "key_bind_meta2-6~", "/icl pagedown")
  Weechat.buffer_set(@buffer, "key_bind_k",        "/icl kill")
  Weechat.buffer_set(@buffer, "key_bind_a",        "/icl akill")
  Weechat.buffer_set(@buffer, "key_bind_u",        "/icl unset")
  Weechat.buffer_set(@buffer, "key_bind_ctrl-M",   "/icl commit")
  Weechat.buffer_set(@buffer, "key_bind_c",        "/icl clear")
  Weechat.buffer_set(@buffer, "key_bind_r",        "/icl refresh")

  @server_buffer = Weechat.buffer_search("irc", @server_name)

  if @server_buffer == nil
    Weechat.print("", "Server buffer cannot be found.")
    return Weechat::WEECHAT_RC_ERROR
  end

  Weechat.hook_print(@server_buffer, "", "Client connecting", 0, "conn_hook", "")
  
  Weechat::WEECHAT_RC_OK
end

def conn_hook(data, buffer, date, tags, displayed, highlight, prefix, message)
  return Weechat::WEECHAT_RC_OK unless message =~ /Client connecting: ([^ ]+) \([^)]+\) \[([0-9.:]+)\]/

  @recent << ICL_Client.new(Time.now, $1, $2, :unbanned, false)
  @recent.shift if @recent.length > 5000

  update_display

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
    down
  when "UP"
    up
  when "PAGEDOWN"
    pagedown
  when "PAGEUP"
    pageup
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

def down
  @selected += 1 unless @selected == @recent.length - 1

  update_display
end

def up
  return if @selected == 0
  @selected -= 1

  update_display
end

def pagedown
  height = Weechat.window_get_integer(Weechat.current_window(), "win_chat_height")

  return if @selected + height > @recent.length - 1
  @selected += height

  update_display
end

def pageup
  height = Weechat.window_get_integer(Weechat.current_window(), "win_chat_height")

  return if @selected - height < 0
  @selected -= height

  update_display
end

def kill
  return if @recent[@selected] == nil

  @recent[@selected].status = :kill_pending

  down
end

def akill
  return if @recent[@selected] == nil

  @recent[@selected].status = :akill_pending

  down
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

  Weechat.print("", @selected.to_s)

end
