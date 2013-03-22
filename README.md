# WeeChat Interactive Connection List Script

Quickly `KILL` or `AKILL` network users from an interactive buffer using simple
keyboard shortcuts.

# Requirements

* IRC Network
  * Charybdis-family IRCD
    * KILL Access
    * Global Connection Notices (SNOMASK +F, requires loaded IRCD module)
  * Atheme-Services
    * AKILL Access
* WeeChat
  * Ruby 1.9 Plugin

# Configuration

*For the time being, configuration is done by editing conlist.rb. This will be
moved to configuration settings within WeeChat very shortly.*

* server_name: the long format name of the IRC server buffer which receives the
  connection notices.
* @ban_reason: the reason to use in the KILL and AKILL commands.

# Usage

As clients connect and you receive the connection SNOTES, the `Connections`
buffer will populate with a list of nicks, IPs, and status flags.

To navigate the list, use:

* Up Arrow
* Down Arrow
* Page Up
* Page Down

With an entry highlighted, you may use keyboard shortcuts to mark them for an
action:

* k - `KILL`
* a - `AKILL`
* u - cancel pending action

Once you have marked your targets, press `c` to commit the pending tasks.

**Commands *will* be throttled by your `anti_flood_prio_low` setting.**

# Notes

It is very possible to accidentally remove or ban large numbers of users with
this script. During an incoming drone flood, it is also very easy to
accidentally remove innocent users. To ensure you avoid these things, always
pay close attention before sending commands.

