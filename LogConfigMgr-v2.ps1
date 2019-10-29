$cfgfile = "C:\Program Files\SplunkUniversalForwarder\etc\log.cfg"

$ChangeToWARN=@(
"Metrics"
,"PeriodicHealthReporter"
,"ModularInputs"
,"LMTracker"
,"TailingProcessor"
,"ExecProcessor"
,"TcpOutputProc"
,"WatchedFile"
,"TailReader"
,"LMConfig"
,"LMStackMgr"
,"PipelineComponent"
,"DC:DeploymentClient"
,"TcpInputProc"
,"DS_DC_Common"
,"LicenseMgr"
,"CascadingReplicationManager"
,"CertStorageProvider"
,"ClusteringMgr"
,"IntrospectionGenerator:disk_objects"
,"LMSlaveInfo"
,"SHClusterMgr"
,"PipeFlusher"
,"ProxyConfig"
,"ApplicationLicense"
,"BundlesSetup"
,"ChunkedLBProcessor"
,"DC:PhonehomeThread"
,"FileAndDirectoryEliminator"
,"IndexerInit"
,"LMStack"
,"Rsa2FA"
,"ScheduledViewsReaper"
,"UiHttpListener"
,"Watchdog"
,"WorkloadManager"
,"WatchdogActions"
,"ShutdownHandler"
,"StatusMgr"
,"SpecFiles"
)

$ChangeToWARN = $ChangeToWARN | Select-Object -Unique

$cfgfile_new = @()

if (Test-Path -Path $cfgfile) {
    $cfgfile_content = Get-Content -Path $cfgfile
    foreach ($line in $cfgfile_content) {
        $matchfound = ""
        
        if (($line -notmatch "^#") -and ($line -match "=(INFO|WARN|ERROR)")) {
            foreach ($item in $ChangeToWARN) {
                if ($line -match "$($item)=") {
                    $matchfound = $line
                }
               
            }
        }
        if ($matchfound -eq "") {
            $cfgfile_new += $line
        } else {
            $cfgfile_new += "# The following line has been changed from default by LogCfgMgr.ps1"
            $newline = $line -replace "INFO","WARN"               
            $cfgfile_new += $newline

        }
    }
}

$cfgfile | Rename-Item -NewName "log.cfg.old"
$cfgfile_new | Set-Content -Path $cfgfile