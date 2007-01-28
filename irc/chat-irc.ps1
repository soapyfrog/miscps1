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
if ($message) {
  $input = $message
}

# See end of file for main entry point


function createSession($coninfo) {
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

  $session.altnick=[int]1
  $session.realnick=$coninfo.nick

  return $session
}


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

# send and flush a message, write it to debug too
function _send([IO.StreamWriter]$sw,[string]$s) {
  $sw.WriteLine($s)
  write-verbose ">> $s"
  $writer.Flush()
}

function _privmsg($who,$msg) {
  _send $writer "PRIVMSG $who :$msg"
}

function _notice($who,$msg) {
  _send $writer "NOTICE $who :$msg"
}

function _onprivmsg {
  $to = $params[0]
  $ok = $incother -or ($incprivate -and $to -eq $realnick) -or ($incchannel -and $joined.Contains($to)) 
  if ($ok) {
    $from = "$pfxnick ! $pfxuser@$pfxhost"
    $msg = $params[1]
    "$from : $to : $msg"
  }
}

#------------------------------------------------------------------------------
# parse a line from the server and returns the prefix nick,user,host,command
# and param array.
function parseline {
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


$script:client = new-object Net.Sockets.TcpClient
$client.Connect($coninfo.server, $coninfo.port)
[Net.Sockets.NetworkStream]$script:ns = $client.GetStream()
$ns.ReadTimeout = 240000 # debug - we want errors if we get nothing for 4 mins
[IO.StreamWriter]$script:writer = new-object IO.StreamWriter($ns,[Text.Encoding]::ASCII)
[IO.StreamReader]$script:reader = new-object IO.StreamReader($ns,[Text.Encoding]::ASCII)
if ($coninfo.pwd -ne "") { _send $writer "PASS $($coninfo.pwd)" }
_send $writer "NICK $realnick" 
_send $writer "USER $($coninfo.user) $($coninfo.hostname) $($coninfo.server) :$($coninfo.realname)" 



# here follows the main event loop.
$active = $true
$joined = @{} # channels that have been joined 

while ($active) {
  [string]$line = $reader.ReadLine()
  if (!$line) { break }
  write-verbose "<< $line"

  $pfxnick,$pfxuser,$pfxhost,$command,$params = parseline $line

  # route messages accordingly
  switch ($command) {
    "PING" { 
      _send $writer "PONG $($params[0])"
      break
    }
    "372" { # MOTD text
      if ($incmotd) {
        $params[1]
      }
      break
    }
    "376" { # end of motd message - connected and free to do stuff
      $channels = [string]::join(",",$join)
      _send $writer "JOIN $channels"
      break
    }
    "JOIN" { # got a JOIN msg - it might have been me
      if ($pfxnick -eq $realnick) {
        $chan = $params[0]
        write-debug "We may have joined channel $chan"
        $joined[$chan] = $true
        if ($chan -eq $sendto) {
          # send the message TODO: fix this rubbish
          _privmsg $chan $message
        }
      }
    }
    "332" { # RPL_TOPIC - we have joined a channel
      if ($params[0] -eq $realnick) {
        $chan = $params[1]
        write-debug "We have joined channel $chan"
        $joined[$chan] = $true
        # TODO tie this up with JOIN above
      }
      break
    }
    "433" { # ERR_NICKNAMEINUSE try another
      $t = $realnick
      $altnick++
      $realnick = "$($coninfo.nick)$altnick"
      write-debug "NICK $t was in use, trying $realnick"
      _send $writer "NICK $realnick"
      break
    }
    "NOTICE" { # a notice that should not be replied to
      if (! $incnotice ) { break }
      # else treat as a privmsg
      _onprivmsg $params
    }
    "PRIVMSG" { # a private message, either to channel or me
      _onprivmsg $params
      if ($params[1] -match "wibble") {
        $active=$false # code word to quit
      }
      break
    }
    default {
      write-debug "Ignoring: $command"
    }
  }
}

# leave any joined channels
$joined.GetEnumerator() | where {$_.value} | foreach {
  _send $writer "PART $($_.name)"
}
# quit
_send $writer "QUIT :bye bye"

$client.Close();




#--
# program starts here
#
$session = createSession($coninfo)

