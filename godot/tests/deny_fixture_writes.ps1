 1 | param([Parameter(Mandatory=$true)][string]$Path, [switch]$Restore)
 2 | $ErrorActionPreference = 'Stop'
 3 | $resolved = (Resolve-Path -LiteralPath $Path).Path
 4 | if ((Split-Path $resolved -Leaf) -ne 'wuzi-permission-fixture' -or $resolved -notlike '*WuziPetBaseline*') {
 5 |     throw 'Permission fixture must be inside isolated baseline user data.'
 6 | }
 7 | $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
 8 | $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
 9 |     $identity, [System.Security.AccessControl.FileSystemRights]::WriteData,
    [System.Security.AccessControl.AccessControlType]::Deny)
$acl = [System.IO.Directory]::GetAccessControl($resolved)
if ($Restore) { $acl.RemoveAccessRuleSpecific($rule) } else { $acl.AddAccessRule($rule) }
[System.IO.Directory]::SetAccessControl($resolved, $acl)
