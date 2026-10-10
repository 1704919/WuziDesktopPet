param([Parameter(Mandatory=$true)][string]$Path, [switch]$Restore)
$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
if ((Split-Path $resolved -Leaf) -ne 'wuzi-permission-fixture' -or $resolved -notlike '*WuziPetBaseline*') {
    throw 'Permission fixture must be inside isolated baseline user data.'
}
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $identity, [System.Security.AccessControl.FileSystemRights]::WriteData,
    [System.Security.AccessControl.AccessControlType]::Deny)
$acl = [System.IO.Directory]::GetAccessControl($resolved)
if ($Restore) { $acl.RemoveAccessRuleSpecific($rule) } else { $acl.AddAccessRule($rule) }
[System.IO.Directory]::SetAccessControl($resolved, $acl)
