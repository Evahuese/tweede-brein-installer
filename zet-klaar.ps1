# zet-klaar.ps1: het tweede brein neerzetten op een Windows-laptop, voor de ChatGPT-app (Work).
#
# Plak deze ene regel in PowerShell (Start, typ "PowerShell", Enter). <naam>/<repo> invullen:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Evahuese/tweede-brein-installer/main/zet-klaar.ps1))) -Repo <naam>/<repo>
#
# Wat het doet, in vaste volgorde:
#   1. Git installeren als het er nog niet staat, en Python voor de systeemcheck
#   2. De ChatGPT-app installeren uit de Microsoft Store als die er nog niet staat
#   3. De map ophalen van GitHub naar <gebruikersmap>\tweede-brein (of bijwerken als hij er al is).
#      Bij de eerste keer opent Windows een browservenster om in te loggen bij GitHub
#   4. Een naam voor Git instellen in de map, zodat de back-up naar GitHub werkt
#   5. Controleren of AGENTS.md en de skills in .agents\skills er staan
#   6. Het pad van de map kopieren en de ChatGPT-app openen
#
# Dit script is bewust dom, net als installeer.sh: het zegt wat het doet en stopt bij de eerste
# fout. Het verandert geen Windows-instellingen. Voor een Mac is er installeer.sh.

param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Doel = (Join-Path $HOME 'tweede-brein')
)

$ErrorActionPreference = 'Stop'
$SCRIPT_VERSIE = '2026.10.28'

function Zeg($tekst)  { Write-Host ''; Write-Host $tekst -ForegroundColor White }
function Ok($tekst)   { Write-Host "  ok      $tekst" -ForegroundColor Green }
function Doe($tekst)  { Write-Host "  bezig   $tekst" }
function Stop-Hier($tekst) {
  Write-Host ''
  Write-Host "  STOP    $tekst" -ForegroundColor Red
  Write-Host '          Maak een foto van dit scherm en stuur hem naar Eva.'
  Write-Host ''
  throw 'zet-klaar gestopt'
}

function Heeft($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Na een installatie kent dit venster het nieuwe programma nog niet. Dit leest het pad opnieuw in.
function Ververs-Pad {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $gebruiker = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$gebruiker"
}

function ChatGPT-App { Get-StartApps | Where-Object { $_.Name -like 'ChatGPT*' } | Select-Object -First 1 }

Write-Host "zet-klaar $SCRIPT_VERSIE"

# ---------- 0. klopt de opdracht ----------

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
  Stop-Hier "De naam van de map klopt niet: '$Repo'. Die ziet eruit als naam/map, bijvoorbeeld quirine/quirine-tweede-brein."
}
if (-not (Heeft winget)) {
  Stop-Hier 'winget ontbreekt. Werk Windows bij (Instellingen, Windows Update) en installeer "App Installer" uit de Microsoft Store.'
}

# ---------- 1. Git ----------

Zeg 'Git'
if (Heeft git) {
  Ok (git --version)
} else {
  Doe 'Git installeren (een paar minuten)'
  winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { Stop-Hier "Git installeren lukte niet (code $LASTEXITCODE)." }
  Ververs-Pad
  if (-not (Heeft git)) { Stop-Hier 'Git is geinstalleerd, maar dit venster vindt het niet. Sluit PowerShell, open hem opnieuw en plak de regel nog een keer.' }
  Ok (git --version)
}

# ---------- 1b. Python, voor de systeemcheck ----------

# De systeemcheck toetst zijn verslag met een klein Python-script. Lukt de installatie niet, dan
# gaat het script gewoon door: de rest werkt zonder Python, alleen het verslag is dan niet getoetst.
Zeg 'Python, voor de systeemcheck'
$heeftPython = $false
if (Heeft py) { py -3 --version *> $null; if ($LASTEXITCODE -eq 0) { $heeftPython = $true } }
if ($heeftPython) {
  Ok (py -3 --version)
} else {
  Doe 'Python installeren (een paar minuten)'
  winget install --id Python.Python.3.12 -e --source winget --silent --accept-package-agreements --accept-source-agreements
  Ververs-Pad
  if ((Heeft py) -and ($LASTEXITCODE -eq 0)) {
    Ok 'geinstalleerd'
  } else {
    Write-Host '  LET OP  Python is niet gelukt. Alles werkt, alleen de systeemcheck kan zijn verslag niet toetsen.' -ForegroundColor Yellow
  }
}

# ---------- 2. de ChatGPT-app ----------

Zeg 'De ChatGPT-app'
if (ChatGPT-App) {
  Ok 'staat erop'
} else {
  Doe 'de ChatGPT-app installeren uit de Microsoft Store'
  winget install --id 9PLM9XGG6VKS -s msstore --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { Stop-Hier "De ChatGPT-app installeren lukte niet (code $LASTEXITCODE). Installeer hem met de hand uit de Microsoft Store en plak de regel daarna opnieuw." }
  if (-not (ChatGPT-App)) { Stop-Hier 'De app lijkt geinstalleerd maar staat niet in het Startmenu. Herstart de laptop en plak de regel opnieuw.' }
  Ok 'geinstalleerd'
}

# ---------- 3. de map ----------

Zeg "De map: $Doel"
if (Test-Path (Join-Path $Doel '.git')) {
  Doe 'de map bestaat al, de nieuwste versie ophalen'
  git -C $Doel pull --ff-only
  if ($LASTEXITCODE -ne 0) { Stop-Hier 'Bijwerken lukte niet. Er staan waarschijnlijk wijzigingen in de map die nog niet zijn opgeslagen.' }
  Ok 'bijgewerkt'
} elseif (Test-Path $Doel) {
  Stop-Hier "Er staat al een map $Doel, maar die komt niet van GitHub. Verplaats of hernoem hem en plak de regel opnieuw."
} else {
  Doe "ophalen van github.com/$Repo. Log in het browservenster in bij GitHub als daarom gevraagd wordt"
  git clone "https://github.com/$Repo.git" $Doel
  if ($LASTEXITCODE -ne 0) { Stop-Hier "Ophalen lukte niet. Klopt de naam '$Repo', en heb je de overdracht op GitHub geaccepteerd?" }
  Ok 'opgehaald'
}

# ---------- 4. een naam voor Git ----------

# Aan het eind van een sessie zet de assistent haar wijzigingen weg op GitHub. Git wil dan weten
# op wiens naam een wijziging staat. Staat er nog niets, dan gebruiken we haar GitHub-naam,
# alleen voor deze map.
Zeg 'Een naam voor de back-up'
$naam = git -C $Doel config user.name
if ($naam) {
  Ok "staat al: $naam"
} else {
  $eigenaar = $Repo.Split('/')[0]
  git -C $Doel config user.name $eigenaar
  git -C $Doel config user.email "$eigenaar@users.noreply.github.com"
  Ok "ingesteld: $eigenaar"
}

# ---------- 5. controle ----------

Zeg 'Controle'
if (-not (Test-Path (Join-Path $Doel 'AGENTS.md'))) { Stop-Hier 'AGENTS.md ontbreekt in de map. Dat moet Eva rechtzetten.' }
Ok 'AGENTS.md'
$skills = @(Get-ChildItem -Path (Join-Path $Doel '.agents\skills') -Filter 'SKILL.md' -Recurse -ErrorAction SilentlyContinue)
if ($skills.Count -eq 0) { Stop-Hier 'Er staan geen skills in .agents\skills. Dat moet Eva rechtzetten.' }
Ok "$($skills.Count) skills in .agents\skills"

# ---------- 6. openen ----------

Zeg 'Klaar'
Set-Clipboard -Value $Doel
Start-Process "shell:AppsFolder\$((ChatGPT-App).AppID)"
Write-Host "  Het pad $Doel staat op je klembord en ChatGPT gaat open."
Write-Host '  Daar: kies Work, open een nieuw project, plak het pad (Ctrl+V)'
Write-Host '  en zet de stand onder het invoerveld op "Vragen om goedkeuring".'
Write-Host ''
