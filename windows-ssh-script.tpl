add-content -path c:/users/harmo/.ssh/config -value @'

Host ${hostname}
    HostName ${hostname}
    User ${user}
    IdentityFile ${identityfile}
'@