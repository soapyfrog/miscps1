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
#
# This is a dot-sourceable module for handling IRC communication.

#------------------------------------------------------------------------------
# demo stuff
#
param(
[string]$message="Test message",
[string]$server="chat.freenode.net",
[int]$port = 6667,
[string]$user = "goronA",
[string]$pwd = "",
[string]$nick="goronb",
[string]$realname = "Adrian Milliner",
[string]$hostname = "soapyfrog.com",
[string]$channel="#test",
[switch]$incprivate = $false,             # include private msgs in output
[switch]$incchannel = $true,              # include channel msgs in output
[switch]$incmotd = $false,                # include motd msgs in output
[switch]$debug,                           # output debug info
[switch]$verbose                          # output all client/server messages
)

# deal with param switches
if ($debug) { $DebugPreference="Continue" }
if ($verbose) { $VerbosePreference="Continue" }

$ErrorActionPreference="Stop"

[int]$altnick=1


# if a message is supplied, use for writing, else send whatever's
# in the pipeline
if ($message) {
  $input = $message
}

# send and flush a message, write it to debug too
function _send([IO.StreamWriter]$sw,[string]$s) {
  $sw.WriteLine($s)
  write-verbose ">> $s"
  $writer.Flush()
}

$client = new-object Net.Sockets.TcpClient
$client.Connect($server, $port)
[Net.Sockets.NetworkStream]$ns = $client.GetStream()
$ns.ReadTimeout = 120000 # debug - we want errors if we get nothing for 2 mins
[IO.StreamWriter]$writer = new-object IO.StreamWriter($ns,[Text.Encoding]::ASCII)
[IO.StreamReader]$reader = new-object IO.StreamReader($ns,[Text.Encoding]::ASCII)
if ($pwd -ne "") { _send $writer "PASS $pwd" }
_send $writer "NICK $nick" 
_send $writer "USER $user $hostname $server :$realname" 


$active = $true
$joined = @{}
while ($active) {
  [string]$line = $reader.ReadLine()
  if (!$line) { break }
  write-verbose "<< $line"

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
  
  write-debug "prefix=$prefix command=$command params=$params"

  # route messages accordingly
  switch ($command) {
    "PING" { # send a ping
      $active=$false
      break
    }
    "372" { # MOTD text
      if ($incmotd) {
        $params[1]
      }
      break
    }
    "376" { # end of motd message - connected and free to do stuff
      _send $writer "JOIN $channel"
      break
    }
    "332" { # RPL_TOPIC - we have joined a channel
      write-debug "We have joined channel $($params[0])"
      $joined[$params[0]] = $true
      _send $writer "PRIVMSG $channel :$message"
      #_send $writer "PART $channel"
      #$active = $false
      break
    }
    "433" { # ERR_NICKNAMEINUSE try another
      $altnick++
      _send $writer "NICK ${nick}$altnick"
      break
    }
    "PRIVMSG" { # a private message, presumable to me
      "$pfxnick/$pfxuser@$pfxhost : $($params[1])"
      write-debug "Got a priv msg!  $params"
      if ($params[1] -match "wibble") { $active = $false }
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
