# $Id$

$rscfg = [management.automation.runspaces.runspaceconfiguration]::Create()
$rs=[management.automation.runspaces.runspacefactory]::CreateRunspace($rscfg)

# open the runspace
$rs.Open()

# define the block of code to execute asyncronously
$block = {
  $sum=0
  "adding numbers in background!"
  foreach($i in $input) {
    $sum+=$i 
    start-sleep 1 # pretent it takes ages to compute this
    "adding number $i"
  }
  "that's it, sum is $sum"
}

# create a pipeline for it
$pipe=$rs.CreatePipeline($block)

# get the input writer - this is where we feed input to the pipeline
$writer = $pipe.Input

# do something when state changes
$pipe.add_StateChanged( { write-host ("State: " + $_.PipelineStateInfo.State);$true } )

# run pipe in the background
$pipe.InvokeAsync()

# feed 5 numbers to the pipeline (true means expand the 1..5 range)
# then close the input
$numwritten = $writer.Write(1..5,$true)
$writer.Close()

# do something important in the foreground
# .. will take about 3 seconds
1..3 | foreach { start-sleep 1; "busy in foreground $_" }

# the background pipeline has been busy for 3 seconds and 
# probably has a couple of seconds to go.
# lets read the output so far and block for the rest.
$reader = $pipe.Output
while (-not $reader.EndOfPipeline) {
  $o = $reader.Read()
  write-host "$o"
}

# if we didn't care about reading the results one by one,
# we would simply do this instead of the loop above:
# $out = $reader.ReadToEnd()

# dump out any errors
$pipe.Error.ReadToEnd()

# cleanup
$pipe.Dispose()
$rs.Close()

