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
[string]$nick="goronb",
[string]$realname = "Adrian Milliner",
[string]$channel="#test"
)

[int]$altnick=1

$DebugPreference="Continue" # shows raw irc responses
$ErrorActionPreference="Stop"

function _send([IO.StreamWriter]$sw,[string]$s) {
  $sw.WriteLine($s)
  write-debug $s
  $writer.Flush()
}

$client = new-object Net.Sockets.TcpClient
$client.Connect($server, $port)
[Net.Sockets.NetworkStream]$ns = $client.GetStream()
$ns.ReadTimeout = 10000 # debug - we want errors if we get nothing for 10 seconds
[IO.StreamWriter]$writer = new-object IO.StreamWriter($ns)
[IO.StreamReader]$reader = new-object IO.StreamReader($ns)
_send $writer "NICK $nick" 
_send $writer "USER $user foo.com $server :$realname" 


$active = $true
while ($active) {
  [string]$line = $reader.ReadLine()
  if (!$line) { break }
  write-debug $line

  switch -regex ($line) {
    " 376 " {
      # end of motd message - connected and free to do stuff
      _send $writer "JOIN $channel"
      break;
    }
    " 332 " {
      # topic message - sent when joining a channel
      _send $writer "PRIVMSG $channel :$message"
      _send $writer "PART $channel"
      $active = $false
      break;
    }
    " 433 " { 
      # nick collision, try another
      $altnick++
      _send $writer "NICK ${nick}$altnick"
      break;
    }
  }
}

$client.Close();
