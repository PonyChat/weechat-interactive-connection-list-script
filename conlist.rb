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

# parentheses because vim does not know how to indent without them
CONNECT_REGEX     = (/Client connecting: (?<nick>[^ ]+) \((?<user>[^@]+)@(?<host>[^\)]+)\) \[(?<ip>[a-f0-9.:]+)\]/)
DISCONNECT_REGEX  = (/Client exiting: (?<nick>[^ ]+) \((?<user>[^@]+)@(?<host>[^\)]+)\).+\[(?<ip>[a-f0-9.:]+)\]$/)

def weechat_init
  Weechat.register 'conlist', 'Kabaka', '1.1', 'MIT',
    'Interactive Connection List', '', ''

  @buffer = Weechat.buffer_new 'Connections', 'buf_in_cb',
    '', '', ''

  @clients = Clients.new 1000

  # Change these!

  # Long name for the server buffer.
  server_name = 'server.ponychat'

  # Used as the AKILL reason and the KILL reason.
  @ban_reason = 'Suspicious activity, botnet drone, or ban evasion.'


  Weechat.buffer_set @buffer,
    'title', 'Interactive Connection List'

  Weechat.hook_command 'icl', 'Interactive Connection List Control',
    '', '', '', 'cmd', ''

  Weechat.hook_modifier 'input_text_content', 'input_cb', ''

  Weechat.buffer_set @buffer, 'key_bind_meta2-A',  '/icl up'
  Weechat.buffer_set @buffer, 'key_bind_meta2-B',  '/icl down'
  Weechat.buffer_set @buffer, 'key_bind_meta2-5~', '/icl pageup'
  Weechat.buffer_set @buffer, 'key_bind_meta2-6~', '/icl pagedown'
  Weechat.buffer_set @buffer, 'key_bind_meta2-7~', '/icl home'
  Weechat.buffer_set @buffer, 'key_bind_meta2-8~', '/icl end'
  Weechat.buffer_set @buffer, 'key_bind_meta2-1~', '/icl home'
  Weechat.buffer_set @buffer, 'key_bind_meta2-4~', '/icl end'
  Weechat.buffer_set @buffer, 'key_bind_k',        '/icl kill'
  Weechat.buffer_set @buffer, 'key_bind_a',        '/icl akill'
  Weechat.buffer_set @buffer, 'key_bind_u',        '/icl unset'
  Weechat.buffer_set @buffer, 'key_bind_ctrl-M',   '/icl commit'
  Weechat.buffer_set @buffer, 'key_bind_c',        '/icl clear'
  Weechat.buffer_set @buffer, 'key_bind_r',        '/icl refresh'

  @server_buffer = Weechat.buffer_search("irc", server_name)

  if @server_buffer == nil
    Weechat.print '',
      "#{Weechat.prefix 'error'}Server buffer cannot be found."

    return Weechat::WEECHAT_RC_ERROR
  end

  Weechat.hook_print @server_buffer,
    '', '*** Notice -- Client', 0, 'conn_hook', ''

  Weechat::WEECHAT_RC_OK
end

def conn_hook data, buffer, date, tags, displayed, highlight, prefix, message
  match = message.match CONNECT_REGEX

  return on_connect match if match

  match = message.match DISCONNECT_REGEX

  return on_disconnect match if match

  Weechat::WEECHAT_RC_OK
end

def on_connect match
  @clients << Client.new(@server_buffer, match[:nick], match[:user], match[:ip])

  update_display

  Weechat::WEECHAT_RC_OK
end

def on_disconnect match
  @clients.each do |client|
    if client.ip == match[:ip] and client.user == match[:user]
      client.disconnected

      update_display

      return Weechat::WEECHAT_RC_OK
    end
  end

  Weechat::WEECHAT_RC_OK
end

def input_cb data, modifier, modifier_data, string
  (@buffer == Weechat.current_buffer) ? '' : string
end

def height
  Weechat.window_get_integer Weechat.current_window, 'win_chat_height'
end

def cmd data, buffer, args
  arr = args.split

  case arr.shift.downcase.to_sym

  when :down
    scroll_down
  when :up
    scroll_up
  when :pagedown
    scroll_page_down
  when :pageup
    scroll_page_up
  when :home
    scroll_home
  when :end
    scroll_end
  when :akill
    akill
  when :kill
    kill
  when :unset
    unset
  when :commit
    commit
  when :clear
    clear
  when :refresh
    update_display
  end

  Weechat::WEECHAT_RC_OK
end

def scroll_down
  @clients.down and update_display
end

def scroll_up
  @clients.up and update_display
end

def scroll_page_down
  @clients.down(height) and update_display
end

def scroll_page_up
  @clients.up(height) and update_display
end

def scroll_home
  @clients.top and update_display
end

def scroll_end
  @clients.bottom and update_display
end

def kill
  @clients.kill and scroll_down

  update_display
end

def akill
  @clients.akill and scroll_down

  update_display
end

def unset
  @clients.reset_status and update_display
end

def commit
  @clients.commit! @ban_reason

  update_display
end

def clear
  @clients.clear and update_display
end

def update_display
  Weechat.buffer_clear @buffer

  my_height = height
  start     = 0

  if @clients.position + 1 > my_height
    start = ((@clients.position / my_height).floor * my_height)
  end

  @clients[start..start + my_height - 1].each_with_index do |client, index|
    str = sprintf "%s%s\t%s%-20s%-40s%s",
      client.nick_color, client.nick,
      client.line_color, client.user, client.ip, client.status

    Weechat.print_date_tags @buffer,
      client.time.to_i, "prefix_nick_#{client.nick_color}", str
  end
end

class Clients < Array
  attr_accessor :position

  def initialize max, *args
    @max_length = max
    @position   = 0
    super(*args)
  end

  def << client
    client.select if empty?

    at_end = last?

    selected.unselect if at_end

    super(client)

    if length > @max_length
      shift
    end
      
    if at_end
      bottom
    end
  end

  def selected
    self[@position]
  end

  def kill
    mark :kill_pending
  end

  def akill
    mark :akill_pending
  end

  def reset_status
    selected.reset_status
  end

  def mark flag
    return false if empty?

    selected.mark flag
  end

  def commit! reason = ''
    each do |client|
      client.commit! reason
    end
  end

  def clear
    return false if empty?

    @position = 0
    super

    true
  end

  def down distance = 1
    return false if last?

    selected.unselect

    if @position + distance > length - 1
      @position = length - 1
    else
      @position += distance
    end

    selected.select
  end

  def up distance = 1
    return false if first?

    selected.unselect

    if @position - distance < 0
      @position = 0
    else
      @position -= distance
    end

    selected.select
  end

  def top
    selected.unselect

    @position = 0

    selected.select
  end

  def bottom
    selected.unselect

    @position = length - 1

    selected.select
  end

  def first?
    @position == 0
  end

  def last?
    @position == length - 1
  end
end

class Client
  attr_reader :time, :nick, :user, :ip, :status

  def initialize buffer, nick, user, ip
    @time     = Time.now
    @status   = :online
    @online   = true
    @selected = false

    @buffer = buffer

    @nick, @user, @ip = nick, user, ip
  end

  def nick_color
    Weechat.info_get 'irc_nick_color', @nick
  end

  def line_color
    case @status

    when :killed
      c = Weechat.color 'red'

    when :akilled
      c = Weechat.color 'lightred'

    when :kill_pending
      c = Weechat.color 'brown'

    when :akill_pending
      c = Weechat.color 'yellow'

    when :online
      c = Weechat.color 'green'

    when :offline
      c = Weechat.color 'green'

    end

    if selected?
      c << Weechat.color('reverse')
    end

    c
  end

  def online?
    @online
  end

  def disconnected
    @online = false

    return if @status == :akilled or @status == :killed

    @status = :offline
  end

  def select
    @selected = true
  end

  def unselect
    @selected = false
  end

  def selected?
    @selected
  end

  def reset_status
    return false if @status == :akilled or @status == :killed

    @status = @online ? :online : :offline
  end

  def commit! reason = ''
    case @status
    when :kill_pending
      kill! reason
    when :akill_pending
      akill! reason
    end
  end

  def mark status
    case status
    when :kill_pending
      return if @status == :offline
    end

    @status = status
  end

  private

  def kill! reason
    Weechat.command @buffer,
      "/kill #{@nick} #{reason}"

    @status = :killed
  end

  def akill! reason
    Weechat.command @buffer,
      "/os AKILL ADD *@#{@ip} !T 1h #{reason}"

    @status = :akilled
  end

end
