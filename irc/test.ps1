$coninfo = @{
  server="chat.freenode.net"
  pwd="lampard8"
  user="soapybot"
  }


"testing","#moo","one","two","three" | chat-irc  -monitor "#test","#test2","#archlinux" -sendto "#test" -coninfo $coninfo -incprivate -incchannel -verbose -debug


#"testing","one","two","three" | chat-irc -sendto "#test" -coninfo $coninfo -incprivate -incchannel -verbose -debug


# simple string output
# test
#
# test | select data,from,to,message
# 
# or full set
# test | select date,nick,user,host,to,message 
#
# and of course
# test | select date,nick,message | convertto-html > capture.html
