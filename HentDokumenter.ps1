param(
[string]$cpr,
[string]$password,
[string]$activation,
[string]$folder = 'c:\data\private\eboks',
[switch]$onlyunread = $false,
[switch]$all = $true
)
# User Settings:
$config = @{
    cpr = $cpr
    password = $password
    activation=$activation
    }

# static strings
$LOGIN_URL = "https://m.e-boks.dk/logon.aspx"
$INBOX_URL = "https://m.e-boks.dk/inbox.aspx"
$DOC_URL = "https://m.e-boks.dk/inbox_document.aspx"
$DOCVIEW_URL = "https://m.e-boks.dk/"
$HEADERS = @{'User-agent' = 'Mozilla/5.0 (Linux; U;) Mobile'}

# setup a session to hold cookies n' stuff
$s = Invoke-WebRequest $LOGIN_URL -Headers $HEADERS -SessionVariable session

$viewstate = $s.InputFields.FindById("__VIEWSTATE").value
$eventvalidation = $s.InputFields.FindById("__EVENTVALIDATION").value

$form = @{
    "__EVENTTARGET"= "lnkOk"
    "__EVENTARGUMENT"= ""
    "__VIEWSTATE" = $viewstate
    "__VIEWSTATEENCRYPTED"= ""
    "__EVENTVALIDATION"= $eventvalidation
    "Identity" = $config["cpr"]
    "Password" =  $config["password"]
    "ActivationCode"= $config["activation"]
}

$login = Invoke-WebRequest $LOGIN_URL  -Body $form -WebSession $session

write-host "[*] Sending login request"


if ("notification warning" -in $login.content) {
    Write-Error "Failed to login."
}


$inbox = Invoke-WebRequest $INBOX_URL -WebSession $session


$msgs = $inbox.Forms.Item("messages_form")

$auth = $msgs.Fields.auth
$fuid = $msgs.Fields.fuid
if($all) {
    $inbox = Invoke-WebRequest "$INBOX_URL`?fuid=$fuid&vdfp=0&vad=1&vnod=1000" -WebSession $session
}
foreach ($msg in $inbox.ParsedHtml.forms.item("messages_form").getElementsByTagName("LI")) {
    if($onlyunread) {
        if ($msg.innerHTML -like '*item_unread*') {
            $msgid = ($msg.getElementsByTagName("a")[0].href -split "'")[1]
            $date = ($msg.getElementsByTagName("span") | where className -eq "recieved").innerText
            $sender = ($msg.getElementsByTagName("span") | where className -eq "sender").innerText -replace "\\",""
            $subject = ($msg.getElementsByTagName("span") | where className -eq "title").innerText -replace "\\|:",""

            write-host "[*] Getting documents for: $subject"

            $form = @{"target"= $msgid; "auth"= $auth; "fuid"= $fuid}
            $document = Invoke-WebRequest $DOC_URL -WebSession $session -Body $form

            foreach( $el in ($document.ParsedHtml.getElementsByTagName("form") | % {$_.getElementsByTagName("li") | % {$_.getElementsByTagName("a")} } )) {
        
                $url = $el.href -replace "about:", ""
                $info = ($el.getelementsbytagname("span") | where classname -eq "info").innertext
                $title = $el.textContent.replace($info,"").trim() -replace "\\|:",""
                $filetype = $info.split(",")[0].replace("(","").trim()
                $filename = "$title.$filetype"
                write-host "[*] Downloading attachment: $filename to folder $folder\$sender\$date $subject"
                mkdir "$folder\$sender\$date $subject" -Force
                Invoke-WebRequest "$DOCVIEW_URL$url" -WebSession $session -OutFile "$folder\$sender\$date $subject\$filename"

            }
        }
    }
    else {
        $msgid = ($msg.getElementsByTagName("a")[0].href -split "'")[1]
        $date = ($msg.getElementsByTagName("span") | where className -eq "recieved").innerText
        $sender = ($msg.getElementsByTagName("span") | where className -eq "sender").innerText -replace "\\",""
        $subject = ($msg.getElementsByTagName("span") | where className -eq "title").innerText -replace "\\|:",""

        write-host "[*] Getting documents for: $subject"

        $form = @{"target"= $msgid; "auth"= $auth; "fuid"= $fuid}
        $document = Invoke-WebRequest $DOC_URL -WebSession $session -Body $form

        foreach( $el in ($document.ParsedHtml.getElementsByTagName("form") | % {$_.getElementsByTagName("li") | % {$_.getElementsByTagName("a")} } )) {
        
            $url = $el.href -replace "about:", ""
            $info = ($el.getelementsbytagname("span") | where classname -eq "info").innertext
            $title = $el.textContent.replace($info,"").trim() -replace "\\|:",""
            $filetype = $info.split(",")[0].replace("(","").trim()
            $filename = "$title.$filetype"
            if(!(Test-Path "$folder\$sender\$date $subject\$filename")) {
                write-host "[*] Downloading attachment: $filename to folder $folder\$sender\$date $subject"
                mkdir "$folder\$sender\$date $subject" -Force
                Invoke-WebRequest "$DOCVIEW_URL$url" -WebSession $session -OutFile "$folder\$sender\$date $subject\$filename"
            }

        }
    }
}