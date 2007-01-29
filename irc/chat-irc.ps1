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
# This script handles chatting and listing to IRC servers.

param(
[string[]]$join=@(),                      # channel(s) to join
[string]$sendto=$null,                    # channel to send message to
[string[]]$message=$null,                 # default is input pipeline
[Collections.IEnumerable]$coninfo=$(throw "missing coninfo"),
                                        # include in the output:
[switch]$incprivate = $false,             # msgs to me
[switch]$incchannel = $true,              # msgs to my channel(s)
[switch]$incnotice = $false,              # notices as well as privmsgs
[switch]$incother = $false,               # msgs to other (eg auth msgs)
[switch]$incmotd = $false,                # motd

[switch]$debug,                           # output debug info
[switch]$verbose                          # output all client/server messages
)

# deal with param switches and error handling
if ($debug) { $DebugPreference="Continue" }
if ($verbose) { $VerbosePreference="Continue" }
$ErrorActionPreference="Stop"
# use $message for input if supplied
if ($message) { $input = $message }

# See end of file for main entry point


#------------------------------------------------------------------------------
# Create the session object, based on script params
#
function create-session($coninfo,$join,$sendto,$input) {
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

  # check that we have a channel to send to
  if ($sendto) {
    if ($join -eq $sendto) { 
      # weird syntax for contains, no inverse, so do nothing
    }
    else { $join += $sendto }
  }

  if ($join.length -eq 0) {
    throw "you must supply channels to join (-join) or a channel to send to (-sendto)"
  }
  $session.join = $join
  $session.sendto = $sendto
  $session.input = $input

  return $session
}



#------------------------------------------------------------------------------
# send and flush a message, write it to debug too
function _send($session,[string]$s) {
  [IO.StreamWriter]$sw=$session.writer
  $sw.WriteLine($s)
  write-verbose ">> $s"
  $sw.Flush()
}

#------------------------------------------------------------------------------
function _privmsg($session,$to,$msg) {
  _send $session "PRIVMSG $to :$msg"
}

#------------------------------------------------------------------------------
function _notice($session,$who,$msg) {
  _send $session "NOTICE $to :$msg"
}

#------------------------------------------------------------------------------
function _onprivmsg($session,$from,$to,$msg) {
  $ok = $incother -or ($incprivate -and $to -eq $realnick) -or ($incchannel -and $session.joined.Contains($to)) 
  if ($ok) {
    "$from : $to : $msg" # TODO make this an object
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

  return $pfxnick,$pfxuser,$pfxhost,$command,$params
}


#------------------------------------------------------------------------------
# Make the connection, but do not send/process any information.
#
function connect-session($session) {
  $c = new-object Net.Sockets.TcpClient
  $c.Connect($session.coninfo.server, $session.coninfo.port)
  [Net.Sockets.NetworkStream]$ns = $c.GetStream()
  $ns.ReadTimeout = 240000 # debug - we want errors if we get nothing for 4 mins
  [IO.StreamWriter]$w = new-object IO.StreamWriter($ns,[Text.Encoding]::ASCII)
  [IO.StreamReader]$r = new-object IO.StreamReader($ns,[Text.Encoding]::ASCII)
  # bung them in the session
  $session.client = $c
  $session.netstream = $ns
  $session.writer = $w
  $session.reader = $r
}


#------------------------------------------------------------------------------
# Run the session.
# Do the authentication/identification bit, then join channels,
# send messages, handle responses.
# Quit condition depends on session type. Default is to write
# messages, then quit when done.
# TODO: flesh this out
#
function run-session($session) {
  if ($session.coninfo.pwd -ne "") { _send $session "PASS $($session.coninfo.pwd)" }
  _send $session "NICK $($session.realnick)" 
  _send $session "USER $($session.coninfo.user) $($session.coninfo.hostname) $($session.coninfo.server) :$($session.coninfo.realname)" 
  # here follows the main event loop.
  $session.active = $true
  $session.joined = @{} # channels that have been joined 

  while ($session.active) {
    [string]$line = $session.reader.ReadLine()
    if (!$line) { break }
    write-verbose "<< $line"

    $pfxnick,$pfxuser,$pfxhost,$command,$params = parse-line $line

    # route messages accordingly
    switch ($command) {
      "PING" { 
        _send $session "PONG $($params[0])"
        break
      }
      "372" { # MOTD text
        if ($incmotd) {
          $params[1]
        }
        break
      }
      "376" { # end of motd message - connected and free to do stuff
        $channels = [string]::join(",",$session.join)
        _send $session "JOIN $channels"
        break
      }
      "JOIN" { # got a JOIN msg - it might have been me
        if ($pfxnick -eq $session.realnick) {
          $chan = $params[0]
          write-debug "We may have joined channel $chan"
          $session.joined[$chan] = $true
          if ($chan -eq $session.sendto) {
            # send the message TODO: fix this rubbish
            _privmsg $session $chan "hello"
          }
        }
      }
      "332" { # RPL_TOPIC - we have joined a channel
        if ($params[0] -eq $session.realnick) {
          $chan = $params[1]
          write-debug "We have joined channel $chan"
          $session.joined[$chan] = $true
          # TODO tie this up with JOIN above
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
        # TODO: fix the 'from' bit - should be more than just $pfxnick
        _onprivmsg $session $pfxnick $params[0] $params[1]
        break
      }
      "PRIVMSG" { # a private message, either to channel or me
        _onprivmsg $session -from $pfxnick -to $params[0] -msg $params[1]
        if ($params[1] -match "wibble") {
          $session.active=$false # code word to quit TODO: fix this
        }
        break
      }
      default {
        write-debug "Ignoring: $command"
      }
    }
  }
}


#------------------------------------------------------------------------------
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
$sess = create-session $coninfo $join $sendto $input
connect-session $sess 
run-session $sess
disconnect-session $sess



