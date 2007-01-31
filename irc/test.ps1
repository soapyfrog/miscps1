$coninfo = @{
  server="chat.freenode.net"
  xxserver="192.168.0.8"
  pwd="lampard8"
  user="soapybot"
  }


#"testing","#moo","one","two","three" | chat-irc  -monitor "#test","#test2" -sendto "#test" -coninfo $coninfo -incprivate -incchannel -verbose -debug


#"testing","one","two","three" | chat-irc -sendto "#test" -coninfo $coninfo -incprivate -incchannel -verbose -debug

ps | out-string -stream | chat-irc  -monitor "#test","#test2" -sendto "#test2" -coninfo $coninfo -incprivate -incchannel -verbose -debug

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
