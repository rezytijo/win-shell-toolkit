$env:CUSTOMSCRIPTS_SKIP_MAIN = '1'
. "$PSScriptRoot\..\setup.ps1"
$env:CUSTOMSCRIPTS_SKIP_MAIN = $null

Describe 'Enable-WindowsSudoMode' {
    It 'skips when sudo.exe is not available' {
        Mock Get-WindowsSudoCommand { $null }
        Mock Get-WindowsSudoConfig { throw 'should not be called' }
        Mock Set-WindowsSudoConfig { throw 'should not be called' }

        { Enable-WindowsSudoMode } | Should Not Throw
        Assert-MockCalled Get-WindowsSudoConfig -Times 0
        Assert-MockCalled Set-WindowsSudoConfig -Times 0
    }

    It 'does not re-enable when Force New Window is already active' {
        Mock Get-WindowsSudoCommand { [PSCustomObject]@{ Name = 'sudo.exe' } }
        Mock Get-WindowsSudoConfig { 'Sudo is currently in Force New Window mode on this machine' }
        Mock Test-IsAdministrator { $true }
        Mock Set-WindowsSudoConfig { throw 'should not be called' }

        { Enable-WindowsSudoMode } | Should Not Throw
        Assert-MockCalled Set-WindowsSudoConfig -Times 0
    }

    It 'enables sudo when available, not yet active, and running as admin' {
        Mock Get-WindowsSudoCommand { [PSCustomObject]@{ Name = 'sudo.exe' } }
        Mock Get-WindowsSudoConfig { 'Sudo is currently disabled on this machine' }
        Mock Test-IsAdministrator { $true }
        Mock Set-WindowsSudoConfig { [PSCustomObject]@{ ExitCode = 0; Output = 'ok' } }

        { Enable-WindowsSudoMode } | Should Not Throw
        Assert-MockCalled Set-WindowsSudoConfig -Times 1 -ParameterFilter { $Mode -eq 'forceNewWindow' }
    }
}
