@{
    # Phase 0 baseline: fail CI only on Error severity. Warnings are reported so
    # later phases can burn them down (plain-text secrets, Write-Host, etc.).
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',            # pipeline logs rely on Write-Host
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSAvoidUsingPositionalParameters'
    )
}
