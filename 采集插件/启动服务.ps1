# 垂类系统本地服务 - PowerShell版（推荐）
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  垂类系统本地服务" -ForegroundColor White
Write-Host "  地址: http://localhost:8080" -ForegroundColor Green
Write-Host "  页面: 前端_产品管理系统.html" -ForegroundColor Green  
Write-Host "  按 Ctrl+C 停止服务" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Set-Location "C:\Users\Administrator\Desktop\垂类"
Start-Process "http://localhost:8080/前端_产品管理系统.html"
python -m http.server 8080
