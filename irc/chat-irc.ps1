#------------------------------------------------------------------------------
# Copyright 2006-2007 Adrian Milliner (ps1 at soapyfrog dot com)
# http://ps1.soapyfrog.com
#
# This work is licenced under the Creative Commons 
# Attribution-NonCommercial-ShareAlike 2.5 License. 
# To view a copy of this licence, visit 
# http://creativecommons.org/licenses/by-nc-sa/2.5/ 
# or send a letter to 
# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#------------------------------------------------------------------------------

# $Id$

#------------------------------------------------------------------------------
# This script handles chatting to and monitoring IRC servers.

param(
[string[]]$monitor=@(),                   # channel(s) to join and monitor
[string]$sendto=$null,                    # channel to send message to
[string[]]$message=$null,                 # default is input pipeline
[Collections.IEnumerable]$coninfo=$(throw "missing coninfo"),

# include in the output:
[switch]$incprivate = $false,             # msgs to me
[switch]$incchannel = $true,              # msgs to my channel(s)
[switch]$incnotice = $false,              # notices as well as privmsgs
[switch]$incother = $false,               # msgs to other (eg auth msgs)
[switch]$incmotd = $false,                # motd

# shouldn't need to set the following
[int]$throttledelay = 200,                # time in ms between sends
[int]$idledelay = 1000,                   # time in ms to sleep when idle

# handy overrides for verbose and debug variables
[switch]$debug,                           # output debug info
[switch]$verbose                          # output all client/server messages
)

# deal with param switches and error handling
if ($debug) { $DebugPreference="Continue" }
if ($verbose) { $VerbosePreference="Continue" }
$ErrorActionPreference="Stop"
# use $message for input if supplied
if ($message) {
  $messages = $message
}
else {
  $messages = $input
}

# See end of file for main entry point


#------------------------------------------------------------------------------
# Create the session object, based on script params
#
function create-session($coninfo,$monitor,$sendto,$messages) {
  # verify/default arguments
  $coninfo = $coninfo.Clone()
  if (! $coninfo.server) { throw "missing server from coninfo" }
  if (! $coninfo.port) { $coninfo.port = 6667 }
  if (! $coninfo.user) { throw "missing user from coninfo" }
  if (! $coninfo.nick) { $coninfo.nick = $coninfo.user}
  if (! $coninfo.realname) { $coninfo.realname = "inout-irc as $($coninfo.nick)" }
  if (! $coninfo.hostname) { $coninfo.hostname = "localhost" }

  write-debug "Using connection info:" # compact format
  $coninfo.GetEnumerator() | foreach { write-debug "$($_.name): $($_.value)" }

  $session = @{}

  $session.coninfo = $coninfo

  $session.altnick=[int]1
  $session.realnick=$coninfo.nick

  # determine default quit mode. if we've got something for sendto but not monitor
  # we quit after all messages are sent.
  $session.quitonsend = $( if ($sendto -and -not $monitor) { $true } else { $false } )

  # check that we have a channel to send to, and or channels to monitor
  if ($sendto) {
    if ($monitor -eq $sendto) { 
      # weird syntax for contains, no inverse, so do nothing
    }
    else { $monitor += $sendto }
  }

  if ($monitor.length -eq 0) {
    throw "you must supply channels to join (-monitor) or a channel to send to (-sendto)"
  }
  $session.monitor = $monitor
  $session.sendto = $sendto
  $session.messages = $messages

  return $session
}


#------------------------------------------------------------------------------
# make an object out of from,to,msg
# to and msg are strings, from is a hash of prefix,nick,user,host
#
function make-outobj($from,$to,$msg) {
  # start out as a formatted string
  $o = "$($from.nick) : $to : $msg"
  # now add note properties so we can do something else with it.
  $o = add-member -i $o -type "noteproperty" -name "date" -force -passthru (get-date)
  foreach ($k in $from.keys) {
    $o = add-member -i $o -type "noteproperty" -name "$k" -force -passthru $from[$k]
  }
  $o = add-member -i $o -type "noteproperty" -name "to" -force -passthru $to
  $o = add-member -i $o -type "noteproperty" -name "message" -force -passthru $msg
  
  $o
}


#------------------------------------------------------------------------------
# send and flush a message, write it to verbose channel too
function _send($session,[string]$s) {
  [IO.StreamWriter]$sw=$session.writer
  $sw.WriteLine($s)
  write-verbose ">> $s"
  $sw.Flush()
}

#------------------------------------------------------------------------------
# send a private message
function _privmsg($session,$to,$msg) {
  _send $session "PRIVMSG $to :$msg"
}

#------------------------------------------------------------------------------
# send a notice
function _notice($session,$to,$msg) {
  _send $session "NOTICE $to :$msg"
}

#------------------------------------------------------------------------------
# handle a received message
# if it is deemed interesting (based on switches) make an object out of the
# properties and place it in the output pipeline
function _onprivmsg($session,$from,$to,$msg) {
  $interesting = $incother -or ($incprivate -and $to -eq $session.realnick) -or ($incchannel -and $session.joined.Contains($to)) 
  if ($interesting) {
    make-outobj $from $to $msg
  }
}

#------------------------------------------------------------------------------
# parse a line from the server and returns the prefix nick,user,host,command
# and param array.
function parse-line {
  # parse lines from server
  [string]$prefix = ""
  [string]$command = ""
  [string]$paramstring = ""
  # check for cmd with prefix
  if ($line -match "^:(.+?) +([A-Z]+|[0-9]{3}) +(.*)") {
    $prefix = $matches[1]
    $command = $matches[2]
    $paramstring = $matches[3]
  }
  # check for simple cmd with no prefix
  elseif ($line -match "^([A-Z]+|[0-9]{3}) +(.*)") {
    $command = $matches[1]
    $paramstring = $matches[2]
  }
  if ($command -eq "") {
    write-warning "Unable to parse: $line"
    continue
  }
  # parse the paramstring
  [string]$trailing = ""
  [int]$i = $paramstring.indexOf(":")
  if ($i -ge 0) {
    $trailing = $paramstring.substring($i+1)
    if ($i -gt 0) { $paramstring = $paramstring.substring(0,$i-1) }
    else {$paramstring=""}
  }
  [string[]]$params = $paramstring.split(" ")|where {$_ -ne ""}
  if ($trailing -ne "") { $params += $trailing }
  # all params are equal, the trailing bit is just a workaround for whitespace

  # parse the prefix
  [string]$pfxnick=""
  [string]$pfxuser=""
  [string]$pfxhost=""
  if ($prefix -ne "" -and $prefix -match "([^!@]+)(!([^@]+)){0,1}(@(.*)){0,1}") {
    $pfxnick = $matches[1]
    $pfxuser = $matches[3]
    $pfxhost = $matches[5]
  }

  return @{full=$prefix;nick=$pfxnick;user=$pfxuser;host=$pfxhost},$command,$params
}


#------------------------------------------------------------------------------
# Make the connection, but do not send/process any information.
#
function connect-session($session) {
  $c = new-object Net.Sockets.TcpClient
  $c.Connect($session.coninfo.server, $session.coninfo.port)
  [Net.Sockets.NetworkStream]$ns = $c.GetStream()
  [IO.StreamWriter]$w = new-object IO.StreamWriter($ns,[Text.Encoding]::ASCII)
  # bung them in the session
  $session.client = $c
  $session.netstream = $ns
  $session.writer = $w
}

#------------------------------------------------------------------------------
# Process one line from the server.
#
function process-line($session,$line) {
    write-verbose "<< $line"

    #$pfxnick,$pfxuser,$pfxhost,$command,$params = parse-line $line
    $prefix,$command,$params = parse-line $line

    # route messages accordingly
    switch ($command) {
      "PING" { 
        _send $session "PONG $($params[0])"
        break
      }
      "372" { # MOTD text
        if ($incmotd) {
          $params[1] # need to param
        }
        break
      }
      "376" { # end of motd message - connected and free to do stuff
        $channels = [string]::join(",",$session.monitor)
        _send $session "JOIN $channels"
        break
      }
      "JOIN" { # got a JOIN msg - it might have been me
        if ($prefix.nick -eq $session.realnick) {
          $chan = $params[0]
          write-debug "We may have joined channel $chan"
          $session.joined[$chan] = $true
        }
        # TODO: support PART,KICK,BAN and so on.
      }
      "332" { # RPL_TOPIC - we have joined a channel
        if ($params[0] -eq $session.realnick) {
          $chan = $params[1]
          write-debug "We have joined channel $chan"
          $session.joined[$chan] = $true
        }
        break
      }
      "433" { # ERR_NICKNAMEINUSE try another
        $t = $session.realnick
        $session.altnick = $session.altnick +1
        $session.realnick = "$($session.coninfo.nick)$($session.altnick)"
        write-debug "NICK $t was in use, trying $($session.realnick)"
        _send $session "NICK $($session.realnick)"
        break
      }
      "NOTICE" { # a notice that should not be replied to
        if (! $incnotice ) { break }
        # else treat as a privmsg 
        _onprivmsg $session -from $prefix -to $params[0] -msg $params[1]
        break
      }
      "PRIVMSG" { # a private message, either to channel or me
        _onprivmsg $session -from $prefix -to $params[0] -msg $params[1]
        if ($params[1] -match "stopstopstop" ) {
          $session.active=$false 
      default {
        # not sure what to do here... 
        # you can see what's going on if -verbose
      }
    }
}

#------------------------------------------------------------------------------
# Do things during idle time (when nothing received from server).
# This is where the input messages are written.
# If we are not configured to monitor channels, we set session
# to inactive if there is no more input.
#
function process-idle($session) {
  # write pending input messages or just hang about
  $delay = $idledelay
  if ($session.joined[$session.sendto]) {
    if ($session.messages.MoveNext()) {
      _privmsg $session $session.sendto $session.messages.Current
      $throttle = $throttledelay
    }
    else {
      if ($session.quitonsend) {
        $session.active = $false
      }
    }
  }
  start-sleep -millis $delay
}

#------------------------------------------------------------------------------
# Run the session.
# Do the authentication/identification bit, then join channels,
# send messages, handle responses.
# Will continue until the active flag in the session is set to false.
#
function run-session($session) {
  if ($session.coninfo.pwd -ne "") { _send $session "PASS $($session.coninfo.pwd)" }
  _send $session "NICK $($session.realnick)" 
  _send $session "USER $($session.coninfo.user) $($session.coninfo.hostname) $($session.coninfo.server) :$($session.coninfo.realname)" 
  # here follows the main event loop.
  $session.active = $true
  $session.joined = @{} # channels that have been joined 

  # building up a line of text from the server
  $line = [string]""

  # while we're active and the client is connected
  while (($session.active) -and ($session.client.Connected) ) {
    # read data if available, else do idle stuff
    if ($session.netstream.DataAvailable) {
      # byte at a time might seem inefficient, but code is simpler and
      # it's only as fast as the network+server anyway
      # note cast from byte to char is more or less ok as irc
      # is a dumb 8-bit character stream anyway
      [char]$ch = $session.netstream.ReadByte()
      if ($ch -eq 13) {
        process-line $session $line
        $line = ""
      }
      elseif ($ch -ne 10) {
        # unless a newline, accumulate in the string
        $line += $ch 
      }
    }
    else {
      process-idle $session
    }
  }
}


#------------------------------------------------------------------------------
# leave any joined channels, then quit
#
function disconnect-session($session) {
  # leave any joined channels
  $session.joined.GetEnumerator() | where {$_.value} | foreach {
    _send $session "PART $($_.name)"
  }
  _send $session "QUIT :bye bye"
  # close the client connection
  $session.client.Close()
  $session.client = $null
}


#------------------------------------------------------------------------------
# program starts here
#
$sess = create-session $coninfo $monitor $sendto $messages
connect-session $sess 
run-session $sess
disconnect-session $sess
