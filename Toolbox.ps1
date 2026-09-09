# =========================================================================
# ОСНОВНОЙ МОДУЛЬ POWERSHELL (WINDOWS 7 / 8 / 10 / 11) - СУПЕР-АДМИНИСТРАТОР
# =========================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "USB SysAdmin Universal Toolbox [SUPER-ADMIN]"
$DriveRoot = $PSScriptRoot

# 1. ПРОВЕРКА И САМО-ЭЛЕВАЦИЯ ДО АДМИНИСТРАТОРА (при прямом запуске .ps1)
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Запуск с ограниченными правами. Запрос прав Супер-Администратора..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "RunAs"
    $psi.WorkingDirectory = $DriveRoot
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        Write-Host "[-] Отказано в повышении прав. Часть системных твиков будет недоступна." -ForegroundColor Red
        Pause
    }
}

# 2. АКТИВАЦИЯ СКРЫТЫХ ПРИВИЛЕГИЙ ТОКЕНА (TOKEN PRIVILEGE BOOSTER: SeDebugPrivilege, SeTakeOwnership)
try {
    $privDef = @"
    using System;
    using System.Runtime.InteropServices;
    public class TokenPrivilegeHelper {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TOKEN_PRIVILEGES newst, int len, IntPtr prev, IntPtr relen);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct TOKEN_PRIVILEGES {
            public int PrivilegeCount;
            public long Luid;
            public int Attributes;
        }
        public static bool Enable(string priv) {
            IntPtr hToken = IntPtr.Zero;
            if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, 0x0028, ref hToken)) return false;
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Attributes = 2; // SE_PRIVILEGE_ENABLED
            if (!LookupPrivilegeValue(null, priv, ref tp.Luid)) return false;
            return AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        }
    }
"@
    if (-not ([System.Management.Automation.PSTypeName]'TokenPrivilegeHelper').Type) {
        Add-Type -TypeDefinition $privDef -Language CSharp -ErrorAction SilentlyContinue
    }
    [TokenPrivilegeHelper]::Enable("SeDebugPrivilege") | Out-Null
    [TokenPrivilegeHelper]::Enable("SeTakeOwnershipPrivilege") | Out-Null
    [TokenPrivilegeHelper]::Enable("SeBackupPrivilege") | Out-Null
    [TokenPrivilegeHelper]::Enable("SeRestorePrivilege") | Out-Null
} catch {}

# Безопасное включение современных протоколов TLS для старых Windows 7 / 8.1
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    Write-Host "[-] Замечание: Не удалось принудительно задать TLS 1.2/1.3: $_" -ForegroundColor DarkGray
}

# Сбор информации о системе
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
if (-not $os) { $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue }
$osName = if ($os) { $os.Caption } else { "Windows (Unknown)" }
$isWin11 = $osName -match "Windows 11"
$isWin7  = $osName -match "Windows 7"

$arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

# Проверка сетевой доступности
$isOnline = $false
try {
    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) { $isOnline = $true }
} catch {
    $isOnline = $false
}

# --- ЦЕНТРАЛЬНЫЙ ДИСПЕТЧЕР ЗАПУСКА УТИЛИТ (DRY-ХЕЛПЕР) ---
function Invoke-Tool {
    param(
        [string]$RelativePath,
        [string]$FallbackRelativePath = "",
        [string]$FallbackUrl = "",
        [string]$DownloadName = "",
        [string]$DisplayName = ""
    )
    $primary = Join-Path $DriveRoot $RelativePath
    if (Test-Path $primary) {
        Start-Process $primary
        return
    }
    if ($FallbackRelativePath) {
        $fallback = Join-Path $DriveRoot $FallbackRelativePath
        if (Test-Path $fallback) {
            Start-Process $fallback
            return
        }
    }
    if ($FallbackUrl) {
        Write-Host "`n[+] Скачивание свежего $DownloadName с официального сервера..." -ForegroundColor Cyan
        $dlPath = Join-Path $env:TEMP $DownloadName
        try {
            Invoke-WebRequest -Uri $FallbackUrl -OutFile $dlPath
            Start-Process $dlPath
            Pause
            return
        } catch {
            Write-Host "[-] Ошибка загрузки с сервера: $_" -ForegroundColor Red
            Pause
            return
        }
    }
    $parentDir = Split-Path $primary
    if (Test-Path $parentDir) {
        Write-Host "[-] Утилита не найдена ($RelativePath). Открываю папку..." -ForegroundColor Yellow
        Start-Process $parentDir
    } else {
        Write-Host "[-] Компонент не найден на флешке: $RelativePath" -ForegroundColor Red
        Pause
    }
}

function Show-Header {
    Clear-Host
    Write-Host "==============================================================================================" -ForegroundColor Cyan
    Write-Host "                           УНИВЕРСАЛЬНЫЙ НАБОР СИСАДМИНА v1.2                                 " -ForegroundColor Yellow
    Write-Host "==============================================================================================" -ForegroundColor Cyan
    Write-Host ("  ОС: " + $osName + " (" + $arch + ")") -ForegroundColor White
    Write-Host ("  Флешка: " + $DriveRoot) -ForegroundColor DarkGray
    Write-Host "  Права: [ СУПЕР-АДМИНИСТРАТОР (HIGH INTEGRITY / SeDebug) ]" -ForegroundColor Green
    if ($isOnline) {
        Write-Host "  Сеть:  [ ОНЛАЙН (Доступ к GitHub активен) ]" -ForegroundColor Green
    } else {
        Write-Host "  Сеть:  [ ОФФЛАЙН (Доступны локальные утилиты флешки) ]" -ForegroundColor Red
    }
    Write-Host "==============================================================================================" -ForegroundColor Cyan
}

function Main-Menu {
    Show-Header
    Write-Host ""

    # Блок 1
    Write-Host "  [ 1 ] ПОСТ-УСТАНОВКА И СОФТ" -ForegroundColor Green
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [1] MAS Активация (HWID/Ohook)    | Вечная цифровая лицензия для Windows и MS Office     |" -ForegroundColor Gray
    Write-Host "  | [2] Chris Titus WinUtil           | Твики системы и пакетная тихая установка софта       |" -ForegroundColor Gray
    Write-Host "  | [3] Win11Debloat                  | Очистка Windows 11 от телеметрии, рекламы и мусора   |" -ForegroundColor Gray
    Write-Host "  | [4] Базовый набор в 1 клик        | Chrome + 7-Zip + VLC + Telegram + Notepad++ (Winget) |" -ForegroundColor Gray
    Write-Host "  | [5] Установка UniGetUI            | Графический менеджер программ (Winget/Chocolatey)    |" -ForegroundColor Gray
    Write-Host "  | [6] Установка MS Office 2024 (Off)| Оффлайн-установка пакета Office 2024 с флешки        |" -ForegroundColor Gray
    Write-Host "  | [7] WPI / MInstAll (Offline)      | Запуск оффлайн-сборника программ с вашей флешки      |" -ForegroundColor Gray
    Write-Host "  | [8] Активатор AAct / KMS (Offline)| Локальная оффлайн-активация без интернета            |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Блок 2
    Write-Host "  [ 2 ] ДИАГНОСТИКА ЖЕЛЕЗА И ТЕСТЫ" -ForegroundColor Yellow
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [1] HTML-отчет о батарее          | Анализ износа аккумулятора и емкости ноутбука        |" -ForegroundColor Gray
    Write-Host "  | [2] Показать пароли Wi-Fi         | Вывод всех сохраненных паролей от сетей на этом ПК   |" -ForegroundColor Gray
    Write-Host "  | [3] Проверка дампов BSOD          | Поиск логов синих экранов в C:\Windows\Minidump      |" -ForegroundColor Gray
    Write-Host "  | [4] Victoria 5.37 (HDD/SSD)       | Глубокий тест поверхности и проверка SMART диска     |" -ForegroundColor Gray
    Write-Host "  | [5] CrystalDiskInfo               | Быстрая оценка здоровья и температуры SSD/HDD        |" -ForegroundColor Gray
    Write-Host "  | [6] Стресс-тесты железа           | Запуск AIDA64, FurMark, OCCT для проверки ПК         |" -ForegroundColor Gray
    Write-Host "  | [7] Snappy Driver Installer (SDI) | Оффлайн-поиск и установка драйверов на любое железо  |" -ForegroundColor Gray
    Write-Host "  | [8] Autoruns & Process Explorer   | Глубокий аудит автозагрузки и скрытых процессов      |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Блок 3
    Write-Host "  [ 3 ] ОЧИСТКА И ЛЕЧЕНИЕ" -ForegroundColor Magenta
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [1] Dism++ GUI комбайн            | Очистка системы, удаление мусора и бэкап Windows     |" -ForegroundColor Gray
    Write-Host "  | [2] Geek Uninstaller              | Чистое удаление программ с подчисткой хвостов        |" -ForegroundColor Gray
    Write-Host "  | [3] Очистка Temp и кэша           | Удаление временных файлов, логов и кэша обновлений   |" -ForegroundColor Gray
    Write-Host "  | [4] Сжатие папки WinSxS           | Очистка старых компонентов и высвобождение места     |" -ForegroundColor Gray
    Write-Host "  | [5] Удаление DDU (Видеодрайвер)   | Чистое удаление видеодрайверов NVIDIA/AMD/Intel      |" -ForegroundColor Gray
    Write-Host "  | [6] Сканер AdwCleaner (Smart)     | Удаление рекламы и вирусов (Локально / Онлайн)       |" -ForegroundColor Gray
    Write-Host "  | [7] Антивирус KVRT                | Экспресс-лечение троянов, майнеров и шифровальщиков  |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Блок 4
    Write-Host "  [ 4 ] СЕТЬ И ИНТЕРНЕТ" -ForegroundColor Cyan
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [1] Сброс сети и DNS кэша         | Восстановление сетевого стека TCP/IP и Winsock       |" -ForegroundColor Gray
    Write-Host "  | [2] Скачать Zapret (YouTube/DS)   | Обход замедления YouTube и Discord с GitHub          |" -ForegroundColor Gray
    Write-Host "  | [3] DNS Jumper 2.3 (Portable)     | Тест скорости и выбор самого быстрого DNS в 1 клик   |" -ForegroundColor Gray
    Write-Host "  | [4] Синхронизация времени         | Фикс ошибок SSL-сертификатов при севшей батарейке    |" -ForegroundColor Gray
    Write-Host "  | [5] Cloudflare DNS (1.1.1.1)      | Быстрый приватный DNS-сервер 1.1.1.1 / 1.0.0.1       |" -ForegroundColor Gray
    Write-Host "  | [6] Google DNS (8.8.8.8)          | Надежный DNS-сервер 8.8.8.8 / 8.8.4.4                |" -ForegroundColor Gray
    Write-Host "  | [7] Сброс DNS на DHCP (Авто)      | Возврат автоматического получения DNS от роутера     |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Блок 5
    Write-Host "  [ 5 ] СИСТЕМНЫЕ ФИКСЫ И ТВЕРДЫЕ ТВЕЙКИ" -ForegroundColor White
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [1] Defender Control (Sordum)     | Включение / отключение Защитника Windows в 1 клик    |" -ForegroundColor Gray
    Write-Host "  | [2] Windows Update Blocker (WUB)  | Отключение авто-обновлений Windows для слабых ПК     |" -ForegroundColor Gray
    Write-Host "  | [3] O&O ShutUp10++ (OOSU10)       | Отключение слежки, телеметрии и фоновых служб        |" -ForegroundColor Gray
    Write-Host "  | [4] Проверка SFC + DISM           | Поиск и авто-восстановление поврежденных файлов Win  |" -ForegroundColor Gray
    Write-Host "  | [5] Сброс очереди принтера        | Очистка зависших документов, когда печать встала     |" -ForegroundColor Gray
    Write-Host "  | [6] Фикс ассоциаций (.exe / .lnk) | Восстановление открытия программ и ярлыков           |" -ForegroundColor Gray
    Write-Host "  | [7] Меню Windows 10 в Win 11      | Включение удобного классического контекстного меню   |" -ForegroundColor Gray
    Write-Host "  | [8] Вернуть меню Windows 11       | Восстановление нового контекстного меню по дефолту   |" -ForegroundColor Gray
    Write-Host "  | [9] Включить 'Администратор'      | Активация встроенного скрытого супер-пользователя    |" -ForegroundColor Gray
    Write-Host "  | [10] Bypass Win11 Check           | Обход требований TPM 2.0 / SecureBoot в реестре      |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    # Блок 6
    Write-Host "  [ 6 ] ПЕРЕЗАГРУЗКА В BIOS / UEFI" -ForegroundColor Red
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | [6] Перезапуск в BIOS             | Прямой вход в настройки материнки (UEFI Firmware)    |" -ForegroundColor Gray
    Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray

    # Блок 7 (если Win 7)
    if ($isWin7) {
        Write-Host ""
        Write-Host "  [ 7 ] ПАКЕТ РЕАНИМАЦИИ WINDOWS 7" -ForegroundColor DarkYellow
        Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
        Write-Host "  | [1] Включить TLS 1.1 / TLS 1.2    | Активация современных защищенных протоколов HTTPS    |" -ForegroundColor Gray
        Write-Host "  | [2] Visual C++ All-in-One         | Установка всех библиотек рантайма с флешки           |" -ForegroundColor Gray
        Write-Host "  +-----------------------------------+------------------------------------------------------+" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  [ 0 ] Выход" -ForegroundColor DarkGray
    Write-Host "----------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

# --- ПОДМЕНЮ 1: СОФТ И АКТИВАЦИЯ ---
function SubMenu-Soft {
    Show-Header
    Write-Host "`n--- [ ПОСТ-УСТАНОВКА И СОФТ ] ---" -ForegroundColor Green
    Write-Host "  [1] MAS (Microsoft Activation Scripts) - Активация Win/Office (Online)"
    Write-Host "  [2] Chris Titus Tech WinUtil - Твики + тихая установка софта (Online)"
    Write-Host "  [3] Win11Debloat - Быстрая чистка Windows 11 от мусора (Online)"
    Write-Host "  [4] Базовый набор в 1 клик (Chrome, 7-Zip, VLC, Telegram, Notepad++)"
    Write-Host "  [5] Установить UniGetUI (Графический менеджер программ)"
    Write-Host "  [6] Установить Microsoft Office 2024 (Оффлайн-установка с флешки)"
    Write-Host "  [7] Запустить локальный WPI / MInstAll с флешки (Offline)"
    Write-Host "  [8] Запустить оффлайн-активатор (AAct / KMS с флешки)"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" { 
            try { irm https://get.activated.win | iex } catch { Write-Host "[-] Ошибка выполнения MAS: $_" -ForegroundColor Red }
            Pause 
        }
        "2" { 
            try { irm christitus.com/win | iex } catch { Write-Host "[-] Ошибка выполнения WinUtil: $_" -ForegroundColor Red }
            Pause 
        }
        "3" { 
            try { irm https://win11debloat.raphire.net | iex } catch { Write-Host "[-] Ошибка выполнения Win11Debloat: $_" -ForegroundColor Red }
            Pause 
        }
        "4" {
            Write-Host "`n[+] Пакетная установка базовых программ через Winget..." -ForegroundColor Cyan
            $apps = @("Google.Chrome", "7zip.7zip", "VideoLAN.VLC", "Telegram.TelegramDesktop", "Notepad++.Notepad++")
            foreach ($app in $apps) {
                Write-Host " -> Установка $app..." -ForegroundColor Yellow
                winget install --id $app --silent --accept-package-agreements --accept-source-agreements
            }
            Write-Host "`n[OK] Завершено выполнение пакетной установки!" -ForegroundColor Green
            Pause
        }
        "5" { winget install --id MartiCliment.UniGetUI --silent --accept-package-agreements; Pause }
        "6" { Invoke-Tool "Programs\Microsoft Office\Office2024-x64.exe" -DisplayName "Office 2024" }
        "7" { Invoke-Tool "Programs\MInst.exe" -FallbackRelativePath "Programs" -DisplayName "MInstAll" }
        "8" { Invoke-Tool "Programs\Activators\aact.exe" -FallbackRelativePath "Programs\Activators" -DisplayName "AAct" }
    }
}

# --- ПОДМЕНЮ 2: ДИАГНОСТИКА ---
function SubMenu-Diag {
    Show-Header
    Write-Host "`n--- [ ДИАГНОСТИКА И ТЕСТЫ ] ---" -ForegroundColor Yellow
    Write-Host "  [1] Сгенерировать HTML-отчет о батарее ноутбука (Износ аккумулятора)"
    Write-Host "  [2] Показать все сохраненные пароли Wi-Fi на этом ПК"
    Write-Host "  [3] Проверить синие экраны (Minidump / BSOD)"
    Write-Host "  [4] Victoria 5.37 (Тест поверхности HDD/SSD и SMART)"
    Write-Host "  [5] Запуск CrystalDiskInfo (Здоровье SSD/HDD)"
    Write-Host "  [6] Запустить стресс-тесты (Папка Diagnostic: AIDA64, FurMark, OCCT)"
    Write-Host "  [7] Запуск Snappy Driver Installer (Установка драйверов)"
    Write-Host "  [8] Открыть Sysinternals (Autoruns 14.30 и Process Explorer 17.12)"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" {
            $report = Join-Path $env:USERPROFILE "Desktop\Battery_Report.html"
            powercfg /batteryreport /output $report
            Write-Host "[OK] Отчет сохранен на Рабочий стол: $report" -ForegroundColor Green
            Start-Process $report
            Pause
        }
        "2" {
            Write-Host "`n[+] Поиск сохраненных Wi-Fi сетей и паролей:`n" -ForegroundColor Cyan
            $profiles = netsh wlan show profiles | Select-String "All User Profile\s*:\s*(.*)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
            foreach ($rawName in $profiles) {
                $safeName = $rawName.Replace('"', '\"')
                $pass = netsh wlan show profile name="$safeName" key=clear | Select-String "Key Content\s*:\s*(.*)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
                Write-Host "  Wi-Fi Сеть: " -NoNewline -ForegroundColor Yellow
                Write-Host $rawName -NoNewline -ForegroundColor White
                Write-Host "  --> Пароль: " -NoNewline -ForegroundColor Cyan
                Write-Host $pass -ForegroundColor Green
            }
            Pause
        }
        "3" {
            $dumps = Get-ChildItem "C:\Windows\Minidump" -ErrorAction SilentlyContinue
            if ($dumps) {
                Write-Host ("`n[!] Найдено дампов падения: " + $dumps.Count) -ForegroundColor Red
                $dumps | Format-Table Name, Length, LastWriteTime -AutoSize
            } else {
                Write-Host "`n[OK] Дампов падений (BSOD) в C:\Windows\Minidump не обнаружено!" -ForegroundColor Green
            }
            Pause
        }
        "4" { Invoke-Tool "Programs\Portable\Victoria-5.37.exe" -DisplayName "Victoria" }
        "5" { Invoke-Tool "Programs\Diagnostic\CrystalDiskInfo9_6_3.exe" -FallbackRelativePath "Programs\First Install\CrystalDiskInfo9_6_3.exe" -DisplayName "CrystalDiskInfo" }
        "6" { Invoke-Tool "Programs\Diagnostic" -DisplayName "Diagnostic" }
        "7" { Invoke-Tool "Programs\SDI\SDI_x64_R.exe" -DisplayName "SDI" }
        "8" {
            $ar = Join-Path $DriveRoot "Programs\Portable\Autoruns-14.30.exe"
            $pe = Join-Path $DriveRoot "Programs\Portable\Process.Explorer-17.12.exe"
            if (Test-Path $ar) { Start-Process $ar }
            if (Test-Path $pe) { Start-Process $pe }
            if (-not (Test-Path $ar) -and -not (Test-Path $pe)) { Start-Process (Join-Path $DriveRoot "Programs\Portable") }
        }
    }
}

# --- ПОДМЕНЮ 3: ОЧИСТКА И ЛЕЧЕНИЕ ---
function SubMenu-Clean {
    Show-Header
    Write-Host "`n--- [ ОЧИСТКА И УДАЛЕНИЕ ] ---" -ForegroundColor Magenta
    Write-Host "  [1] Dism++ GUI комбайн (Очистка системы, бэкап, драйверы)"
    Write-Host "  [2] Geek Uninstaller (Быстрое удаление программ с подчисткой)"
    Write-Host "  [3] Полная очистка Temp, кэша Windows Update и Prefetch"
    Write-Host "  [4] Сжатие и глубокая очистка папки WinSxS (DISM ComponentCleanup)"
    Write-Host "  [5] Удаление видеодрайверов под ноль (Запуск DDU)"
    Write-Host "  [6] Сканер AdwCleaner (Локально с флешки или онлайн с официального сервера)"
    Write-Host "  [7] Скачать и запустить KVRT (Kaspersky Virus Removal Tool)"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" { Invoke-Tool "Programs\Portable\Dism++10.1.1002.1B.exe" -DisplayName "Dism++" }
        "2" { Invoke-Tool "Programs\Portable\geek-1.5.3.170.exe" -DisplayName "Geek Uninstaller" }
        "3" {
            Write-Host "`n[+] Очистка временных файлов..." -ForegroundColor Yellow
            $clearedCount = 0
            Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $clearedCount++ } catch {}
            }
            Get-ChildItem "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $clearedCount++ } catch {}
            }
            Write-Host "[OK] Временные файлы очищены ($clearedCount элементов обработано)!" -ForegroundColor Green
            Pause
        }
        "4" {
            Write-Host "`n[+] Очистка и сжатие WinSxS..." -ForegroundColor Yellow
            dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
            Write-Host "[OK] Хранилище компонентов очищено!" -ForegroundColor Green; Pause
        }
        "5" { Invoke-Tool "Programs\Diagnostic\DDU\Display Driver Uninstaller.exe" -FallbackRelativePath "Programs\Diagnostic" -DisplayName "DDU" }
        "6" {
            Invoke-Tool "Programs\Portable\adwcleaner-8.8.1.exe" `
                -FallbackUrl "https://downloads.malwarebytes.com/file/adwcleaner" `
                -DownloadName "adwcleaner.exe" `
                -DisplayName "AdwCleaner"
        }
        "7" {
            Invoke-Tool "Programs\Portable\KVRT.exe" `
                -FallbackUrl "https://devbuilds.s.kaspersky-labs.com/devbuilds/KVRT/latest/full/KVRT.exe" `
                -DownloadName "KVRT.exe" `
                -DisplayName "KVRT"
        }
    }
}

# --- ПОДМЕНЮ 4: СЕТЬ ---
function SubMenu-Network {
    Show-Header
    Write-Host "`n--- [ СЕТЬ И ИНТЕРНЕТ ] ---" -ForegroundColor Cyan
    Write-Host "  [1] Полный сброс стека TCP/IP, Winsock и очистка кэша DNS"
    Write-Host "  [2] Скачать и распаковать свежий Zapret (Обход блокировок YouTube/Discord)"
    Write-Host "  [3] Запуск DNS Jumper 2.3 (Тест скорости и переключение DNS)"
    Write-Host "  [4] Принудительная синхронизация точного времени (Fix SSL / Time Sync)"
    Write-Host "  [5] Установить быстрый и безопасный DNS Cloudflare (1.1.1.1 / 1.0.0.1)"
    Write-Host "  [6] Установить Google DNS (8.8.8.8 / 8.8.4.4)"
    Write-Host "  [7] Вернуть автоматическое получение DNS (по DHCP от роутера)"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" {
            ipconfig /flushdns
            netsh winsock reset
            netsh int ip reset
            Write-Host "`n[OK] Сетевые параметры сброшены! Рекомендуется перезагрузка." -ForegroundColor Green; Pause
        }
        "2" {
            Write-Host "`n[+] Скачивание актуального пакета Zapret (YouTube/Discord) с GitHub..." -ForegroundColor Cyan
            $zapretZip = Join-Path $env:TEMP "zapret-discord-youtube.zip"
            $targetDir = Join-Path $DriveRoot "Programs\Zapret"
            if (-not (Test-Path $targetDir)) { 
                New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction SilentlyContinue | Out-Null 
            }
            try {
                Invoke-WebRequest -Uri "https://github.com/Flowseal/zapret-discord-youtube/releases/latest/download/zapret-discord-youtube.zip" -OutFile $zapretZip
                Write-Host "[+] Распаковка в папку: $targetDir" -ForegroundColor Cyan
                Expand-Archive -Path $zapretZip -DestinationPath $targetDir -Force
                Remove-Item $zapretZip -Force -ErrorAction SilentlyContinue
                Write-Host "`n[OK] Zapret успешно сохранен на флешку в Programs\Zapret!" -ForegroundColor Green
                Start-Process explorer.exe $targetDir
            } catch {
                Write-Host ("[-] Ошибка загрузки Zapret: " + $_) -ForegroundColor Red
            }
            Pause
        }
        "3" { Invoke-Tool "Programs\Portable\DNS.Jumper-2.3.exe" -DisplayName "DNS Jumper" }
        "4" {
            Write-Host "`n[+] Запуск службы времени и принудительная синхронизация с серверами NTP..." -ForegroundColor Cyan
            try {
                Start-Service w32time -ErrorAction SilentlyContinue
                w32tm /config /syncfromflags:manual /manualpeerlist:"time.windows.com,pool.ntp.org" /update | Out-Null
                w32tm /resync /force
                Write-Host "`n[OK] Системное время синхронизировано! Ошибки сертификатов исправлены." -ForegroundColor Green
            } catch {
                Write-Host "[-] Ошибка синхронизации времени: $_" -ForegroundColor Red
            }
            Pause
        }
        "5" {
            Get-NetAdapter | Where-Object Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("1.1.1.1","1.0.0.1")
            Write-Host "`n[OK] Установлен Cloudflare DNS (1.1.1.1)" -ForegroundColor Green; Pause
        }
        "6" {
            Get-NetAdapter | Where-Object Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("8.8.8.8","8.8.4.4")
            Write-Host "`n[OK] Установлен Google DNS (8.8.8.8)" -ForegroundColor Green; Pause
        }
        "7" {
            Get-NetAdapter | Where-Object Status -eq "Up" | Set-DnsClientServerAddress -ResetServerAddresses
            Write-Host "`n[OK] DNS сброшен на авто (DHCP)" -ForegroundColor Green; Pause
        }
    }
}

# --- ПОДМЕНЮ 5: СИСТЕМНЫЕ ФИКСЫ ---
function SubMenu-Fixes {
    Show-Header
    Write-Host "`n--- [ СИСТЕМНЫЕ ФИКСЫ И ТВЕРДЫЕ ТВЕЙКИ ] ---" -ForegroundColor White
    Write-Host "  [1] Defender Control (Включение / отключение Защитника Windows в 1 клик)"
    Write-Host "  [2] Windows Update Blocker (Полное отключение обновлений Windows)"
    Write-Host "  [3] O&O ShutUp10++ (Тонкая настройка приватности и отключение телеметрии)"
    Write-Host "  [4] Проверка и восстановление системных файлов (SFC /SCANNOW + DISM)"
    Write-Host "  [5] Сброс зависшей очереди печати принтера (Print Spooler Reset)"
    Write-Host "  [6] Восстановление ассоциаций файлов (.exe / .lnk / .bat)"
    Write-Host "  [7] Включить классическое контекстное меню Windows 10 (для Windows 11)"
    Write-Host "  [8] Вернуть новое контекстное меню Windows 11 по умолчанию"
    Write-Host "  [9] Активировать встроенную учетную запись Администратор"
    Write-Host "  [10] Применить реестровый обход проверки TPM 2.0 / SecureBoot при установке"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" { Invoke-Tool "Programs\Portable\DefenderControl-2.1.exe" -DisplayName "Defender Control" }
        "2" { Invoke-Tool "Programs\Portable\Windows.Update.Blocker-1.8.exe" -DisplayName "Windows Update Blocker" }
        "3" { Invoke-Tool "Programs\Portable\OOSU10-3.2.1111.exe" -DisplayName "O&O ShutUp10" }
        "4" {
            Write-Host "`n[+] Запуск SFC и DISM..." -ForegroundColor Yellow
            sfc /scannow
            dism /online /cleanup-image /restorehealth
            Write-Host "[OK] Проверка завершена!" -ForegroundColor Green; Pause
        }
        "5" {
            Write-Host "`n[+] Остановка службы диспетчера печати и очистка очереди..." -ForegroundColor Cyan
            Stop-Service spooler -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue
            Start-Service spooler -ErrorAction SilentlyContinue
            Write-Host "`n[OK] Очередь печати очищена! Принтер разблокирован." -ForegroundColor Green
            Pause
        }
        "6" {
            Write-Host "`n[+] Восстановление стандартных ассоциаций исполняемых файлов в реестре..." -ForegroundColor Cyan
            reg add "HKCR\.exe" /ve /t REG_SZ /d "exefile" /f | Out-Null
            reg add "HKCR\exefile\shell\open\command" /ve /t REG_SZ /d '\"%1\" %*' /f | Out-Null
            reg add "HKCR\.lnk" /ve /t REG_SZ /d "lnkfile" /f | Out-Null
            reg add "HKCR\lnkfile\shell\open\command" /ve /t REG_SZ /d '\"%1\" %*' /f | Out-Null
            Write-Host "`n[OK] Ассоциации .exe и .lnk восстановлены!" -ForegroundColor Green
            Pause
        }
        "7" {
            reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Write-Host "`n[OK] Классическое меню включено!" -ForegroundColor Green; Pause
        }
        "8" {
            reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Write-Host "`n[OK] Меню Windows 11 восстановлено!" -ForegroundColor Green; Pause
        }
        "9" {
            net user Administrator /active:yes
            Write-Host "`n[OK] Пользователь Администратор активирован!" -ForegroundColor Green; Pause
        }
        "10" {
            reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f | Out-Null
            reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "`n[OK] Ключи обхода требований Windows 11 внесены в реестр!" -ForegroundColor Green; Pause
        }
    }
}

# --- ПОДМЕНЮ 6: ПЕРЕЗАГРУЗКА В BIOS / UEFI ---
function Action-RebootToBios {
    Show-Header
    Write-Host "`n--- [ ПЕРЕЗАГРУЗКА В BIOS / UEFI ] ---" -ForegroundColor Red
    Write-Host "Внимание! Компьютер будет немедленно перезагружен напрямую в настройки BIOS / UEFI." -ForegroundColor Yellow
    $confirm = Read-Host "Вы уверены? Введите Y для подтверждения или Enter для отмены"
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        Write-Host "`n[+] Отправка команды перезагрузки в UEFI Firmware Settings..." -ForegroundColor Cyan
        try {
            $process = Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /fw /t 1" -NoNewWindow -PassThru -Wait
            if ($process.ExitCode -ne 0) {
                Write-Host "`n[-] Ошибка: Ваша материнская плата или Windows загружена в режиме Legacy BIOS (не UEFI)." -ForegroundColor Red
                Write-Host "    Вход в BIOS на этой системе возможен только клавишами Del / F2 при старте ПК." -ForegroundColor Yellow
                Pause
            }
        } catch {
            Write-Host ("[-] Не удалось выполнить команду: " + $_) -ForegroundColor Red
            Pause
        }
    }
}

# --- ПОДМЕНЮ 7: СПЕЦИАЛЬНО ДЛЯ WINDOWS 7 ---
function SubMenu-Win7 {
    Show-Header
    Write-Host "`n--- [ ПАКЕТ РЕАНИМАЦИИ WINDOWS 7 ] ---" -ForegroundColor DarkYellow
    Write-Host "  [1] Включить поддержку протоколов TLS 1.1 / TLS 1.2 в системе"
    Write-Host "  [2] Запустить установку Visual C++ All-in-One (с флешки)"
    Write-Host "  [0] Назад в главное меню"
    
    $c = Read-Host "`nВыберите пункт"
    switch ($c) {
        "1" {
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "DisabledByDefault" /t REG_DWORD /d 0 /f | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "Enabled" /t REG_DWORD /d 1 /f | Out-Null
            Write-Host "`n[OK] Системный TLS 1.2 включен!" -ForegroundColor Green; Pause
        }
        "2" {
            Invoke-Tool "Programs\First Install\VisualCppRedist_AIO.exe" `
                -FallbackRelativePath "Programs\System\RuntimePack_Lite-20.3.3.exe" `
                -DisplayName "Visual C++ Runtime"
        }
    }
}

# ГЛАВНЫЙ ЦИКЛ ПРИЛОЖЕНИЯ
do {
    Main-Menu
    $mainChoice = Read-Host "Выберите раздел (0-6)"
    switch ($mainChoice) {
        "1" { SubMenu-Soft }
        "2" { SubMenu-Diag }
        "3" { SubMenu-Clean }
        "4" { SubMenu-Network }
        "5" { SubMenu-Fixes }
        "6" { Action-RebootToBios }
        "7" { if ($isWin7) { SubMenu-Win7 } }
    }
} while ($mainChoice -ne "0")
