# $Id$

$rscfg = [management.automation.runspaces.runspaceconfiguration]::Create()
$rs=[management.automation.runspaces.runspacefactory]::createrunspace($host,$rscfg)
$rs.open()
$pipe=$rs.createpipeline('write-output "hello, world!"')
#$pipe=$rs.createpipeline('$host.ui.rawui.BackgroundColor="black";write-host "hello"')
$pipe.input.close()
gm -i $pipe *
$pipe.add_StateChanged( {echo "done"} )
$pipe.InvokeAsync()


$out = $pipe.output.readtoend()
$err = $pipe.error.readtoend()

$pipe.dispose()
$rs.close()


write-host "out"
$out
write-host "err"
$err
