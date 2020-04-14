. .\Send-MailMessage.ps1

$mailcred = (Get-Credential)
$msolcreds = (Get-Credential)

Function Send-Email {

$enc  = New-Object System.Text.utf8encoding
$Subject = "Good News E-Mail Account Created"
$images = @{
    image1 = 'C:\images\GNC_Logo.gif'
}

$body = @"

<html><head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<style>
	body {margin:0;padding:0;}
	table td {border-collapse:collapse;margin:0;padding:0;}
</style>
</head>
<body style="margin:0;padding:0;">
<!-- <span style="display: none !important;">Good News Email</span> -->
<table border="0" width="100%" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="background-color: #eee;" align="right" valign="top" width="50%">&nbsp;</td>
<td style="background-color: #f47524;" valign="top"><!-- PREHEADER-->
<table border="0" width="676" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td>&nbsp;</td>
</tr>
</tbody>
</table>
<!-- /PREHEADER --> <!-- BODY -->
<table style="width: 676px;" border="0" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="width: 45.8833px;" bgcolor="#ffffff">&nbsp;</td>
<td style="padding: 13px 0px; width: 606.117px;" align="left" valign="middle" bgcolor="#ffffff" height="65"><img src="cid:image1" /></td>
<td style="width: 14px;" bgcolor="#ffffff">&nbsp;</td>
</tr>
</tbody>
</table>
<table border="0" width="676" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td style="background: #ffffff; line-height: 1px;" width="50">&nbsp;</td>
<td style="background: #fff; padding: 40px 0;" align="left" valign="top" width="576">
<table border="0" width="576" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td align="left" width="576"><span style="color: #404041; font-family: 'Segoe UI',Arial,sans-serif; font-size: 17px; font-weight: 100; line-height: 17px; padding-bottom: 21px;"> Dear $Name,</span> <br /> <br />
<p>Welcome to Good News Ocala Email powered by Office 365! This is the first step in our journey to virtual community groups!</p>
<p>Your username is: $UserPrincipalName<br />Your temporary password is: $UserPassword</p>
<p>You may now access your new account by visiting <a href="http://www.office.com">http://www.office.com</a></p>
<p>Please note that you will be prompted to change your password after your first login.</p>
<p>After logging into your new @yourdomain.com Email be on the look out for your Microsoft Teams invitation.</p>
<p>If you have any questions about setting this up after getting your Good News email address and Microsoft Teams invite, please call or text the church at ***-***-****</p>
<p><strong>**PLEASE DO NOT REPLY. THIS MAILBOX IS NOT MONITORED**</strong></p>
</td>
</tr>
</tbody>
</table>
</td>
<td style="background: #ffffff; line-height: 1px;" width="50">&nbsp;</td>
</tr>
</tbody>
</table>
<!-- /BODY -->
<table border="0" width="676" cellspacing="0" cellpadding="0">
<tbody>
<tr>
<td bgcolor="#F47524" width="15">&nbsp;</td>
</tr>
</tbody>
</table>
</td>
<td style="background-color: #eee;" align="left" valign="top" width="50%">&nbsp;</td>
</tr>
</tbody>
</table>
</body></html>
"@

Send-MailMessage -SmtpServer "smtp.office365.com" -Port 587 -From "Do-Not-Reply@yourdomain.com" -BodyAsHtml -To $User.Email -Subject $Subject -Body $body -UseSsl -Credential $mailcred -InlineAttachments $images

}

Connect-MsolService -Credential $msolcreds

#Import User List
$Users = Import-Csv -path "PathToYour.csv"

foreach ($User in $Users) {

$Name = ($User.First + " " + $User.Last)
$UserPrincipalName = (($user.First).ToLower() +"." + ($user.Last).ToLower() + '@yourdomain.com')
$Numbers = Get-Random -maximum 20000 -Minimum 100
$Letters = -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})
$UserPassword = ($Numbers.ToString() + $Letters.ToString() + "!").ToString()

#Create users in Office 365

New-MsolUser -DisplayName $Name -FirstName $_.First -LastName $_.Last -UserPrincipalName $UserPrincipalName -Title "Group Leader" -UsageLocation US -LicenseAssignment "yourtenantname:O365_BUSINESS_ESSENTIALS" -AlternateEmailAddresses $user.Email -Password $UserPassword -ForceChangePassword $true

Send-Email

}

Connect-MicrosoftTeams -TenantId "Your Tenant ID" -Credential $msolcreds
$team = Get-Team -DisplayName "Your Team Name"

$Leaders = Get-MsolUser | Where-Object {$_.Title -eq "Group Leader" -or $_.Title -eq "Staff" -or $_.Title -eq "Elder" } | Select-Object -exp UserPrincipalName

foreach ($Leader in $Leaders) {
	
	Add-TeamUser -GroupId $Team.GroupId -User $leader -Role Member -ErrorAction SilentlyContinue

}