#!/usr/bin/perl

use IO'Socket;
@ARGV<2 && die;
($v,$n,$c)=@ARGV;
$s=new IO'Socket'INET "$v:6667" or die$@;
print$s "user $n $n $n :n\r\nnick $n\r\n";
while() {
  print;/^:(.+) [376|422]/ && print$s "join $c\r\n";
  /^PING/ && print$s "PONG $'\r\n";
  /^.!. .* (.)/ && print $s "privmsg 1 :2" 
}

