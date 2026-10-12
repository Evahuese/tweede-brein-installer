#!/bin/bash
# installeer.sh: het tweede brein neerzetten op een Mac, en later bijwerken.
#
#   bash installeer.sh install <repo> [doelmap]   de map ophalen en alles klaarzetten
#   bash installeer.sh update                     de nieuwste versie ophalen, en de grendel opnieuw bewijzen
#   bash installeer.sh gmail <kenmerk>            het Gmail-kenmerk invullen in .claude/settings.json
#   bash installeer.sh eigen-adres <adres>        haar eigen adres invullen voor de wekelijkse mail
#   bash installeer.sh check                      alleen kijken wat er op deze Mac staat
#
# Op een verse Mac, zonder iets te installeren:
#   curl -fsSL https://raw.githubusercontent.com/Evahuese/tweede-brein-installer/main/installeer.sh | bash -s -- install Evahuese/naam-tweede-brein
#
# <repo> is "Evahuese/naam-tweede-brein" (via GitHub) of een pad of URL voor git.
# Doelmap is standaard ~/tweede-brein. Niet in iCloud of Dropbox, tenzij zij dat bewust wil.
#
# Dit script is bewust dom: het doet elke stap in vaste volgorde, zegt wat het doet,
# en stopt bij de eerste fout. Niets gebeurt stil.

set -euo pipefail

SCRIPT_VERSIE="2026.10.12"
MODE="${1:-help}"

zeg()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  ok      %s\n' "$1"; }
mis()  { printf '  MIST    %s\n' "$1"; }
stop() { printf '\n  STOP    %s\n\n' "$1"; exit 1; }

# ---------- 1. gereedschap ----------

heeft() { command -v "$1" >/dev/null 2>&1; }

check_gereedschap() {
  zeg "Gereedschap op deze Mac"
  [ "$(uname)" = "Darwin" ] || stop "Dit script is voor een Mac. Voor Windows is er nog geen versie."

  if xcode-select -p >/dev/null 2>&1; then ok "Apple ontwikkeltools (git zit hierin)"; else
    mis "Apple ontwikkeltools"; ONTBREEKT=1; fi
  if heeft brew;     then ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"; else mis "Homebrew"; ONTBREEKT=1; fi
  if heeft gh;       then ok "GitHub CLI $(gh --version | head -1 | awk '{print $3}')"; else mis "GitHub CLI (gh)"; ONTBREEKT=1; fi
  if heeft claude;   then ok "Claude Code $(claude --version 2>/dev/null | awk '{print $1}')"; else mis "Claude Code"; ONTBREEKT=1; fi
  if [ -d "/Applications/Obsidian.app" ]; then ok "Obsidian"; else mis "Obsidian"; ONTBREEKT=1; fi
  if heeft gh && gh auth status >/dev/null 2>&1; then ok "GitHub: ingelogd als $(gh api user --jq .login 2>/dev/null || echo '?')"; else
    mis "GitHub: niet ingelogd"; ONTBREEKT=1; fi
}

installeer_gereedschap() {
  zeg "Ontbrekend gereedschap installeren"
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "  Apple ontwikkeltools. Er komt een venster van Apple, klik op Installeren en wacht tot het klaar is."
    xcode-select --install || true
    stop "Draai dit script opnieuw zodra de ontwikkeltools klaar zijn."
  fi
  if ! heeft brew; then
    echo "  Homebrew installeren. Dit vraagt één keer om het wachtwoord van de Mac."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  heeft gh || brew install gh
  [ -d "/Applications/Obsidian.app" ] || brew install --cask obsidian
  if ! heeft claude; then
    echo "  Claude Code installeren met het officiële installatieprogramma van Anthropic."
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "  Inloggen bij GitHub. Er opent een browser; log in met het account van het bedrijf, niet een privé-account."
    gh auth login --web --git-protocol https
  fi
}

# ---------- 2. de map ----------

haal_map() {
  local repo="$1" doel="$2"
  zeg "De map ophalen"
  [ -e "$doel" ] && stop "Er staat al iets op $doel. Gebruik 'update' om bij te werken, of kies een andere doelmap."
  case "$doel" in
    *"Mobile Documents"*|*Dropbox*|*"Google Drive"*) echo "  Let op: $doel synchroniseert met de cloud. Alleen doen als zij dat bewust wil." ;;
  esac
  if [ -d "$repo" ] || [[ "$repo" == *"://"* ]] || [[ "$repo" == git@* ]]; then
    git clone --quiet "$repo" "$doel"
  else
    gh repo clone "$repo" "$doel" -- --quiet
  fi
  ok "staat op $doel"
}

# ---------- 3. bewijzen en vastleggen ----------

bewijs_grendel() {
  local map="$1"
  zeg "De grendel bewijzen"
  if [ -x "$map/test/grendel-test.sh" ] || [ -f "$map/test/grendel-test.sh" ]; then
    local uitslag
    uitslag="$(bash "$map/test/grendel-test.sh" 2>&1 | tail -3)"
    echo "$uitslag" | sed 's/^/  /'
    echo "$uitslag" | grep -Eq "Uitslag: [0-9]+ goed, 0 mislukt" || stop "De grendel-test faalt. Niet opleveren tot dit groen is."
    mkdir -p "$map/veiligheid"
    printf '%s  grendel-test via installeer.sh (%s): %s\n' "$(date +%Y-%m-%d)" "$MODE" "$(echo "$uitslag" | tail -1)" >> "$map/veiligheid/grendel-uitslagen.md"
  else
    echo "  geen test/grendel-test.sh gevonden, overgeslagen"
  fi
  if [ -f "$map/test/vingerafdruk.py" ]; then
    if [ "$MODE" = "install" ]; then
      (cd "$map" && python3 test/vingerafdruk.py --leg-vast >/dev/null 2>&1) && ok "vingerafdruk van de vangrails vastgelegd" || echo "  vingerafdruk vastleggen mislukte, later met de hand: python3 test/vingerafdruk.py --leg-vast"
    else
      (cd "$map" && python3 test/vingerafdruk.py >/dev/null 2>&1) && ok "vangrails ongewijzigd sinds de vorige vingerafdruk" || echo "  LET OP: de vangrails zijn veranderd sinds de vorige vingerafdruk. Kijk na, en leg opnieuw vast met: python3 test/vingerafdruk.py --leg-vast"
    fi
  fi
}

schrijf_versie_in_logboek() {
  local map="$1" hash datum
  hash="$(cd "$map" && git rev-parse --short HEAD)"
  datum="$(date +%d-%m-%Y)"
  if [ -f "$map/logboek.md" ] && grep -q "INVULLEN" "$map/logboek.md"; then
    sed -i '' "s/\[INVULLEN: de eerste zeven tekens van het opslagpunt\]/$hash/; s/| Ingericht op | \[INVULLEN\]/| Ingericht op | $datum/" "$map/logboek.md"
    (cd "$map" && git add logboek.md && git commit --quiet -m "Ingericht op $datum, versie $hash") || true
    ok "logboek.md: versie $hash, ingericht op $datum"
  fi
}

toon_versie() {
  local map="$1"
  if [ -f "$map/VERSIE" ]; then ok "versie van de mal: $(cat "$map/VERSIE")"; fi
  ok "opslagpunt: $(cd "$map" && git rev-parse --short HEAD)"
}

# ---------- de standen ----------

case "$MODE" in
  check)
    ONTBREEKT=0; check_gereedschap
    [ "$ONTBREEKT" = 1 ] && echo && echo "  Draai 'bash installeer.sh install <repo>' om het ontbrekende te installeren." || true
    ;;

  install)
    REPO="${2:-}"; DOEL="${3:-$HOME/tweede-brein}"
    [ -n "$REPO" ] || stop "Zeg welke repo: bash installeer.sh install Evahuese/naam-tweede-brein"
    ONTBREEKT=0; check_gereedschap
    [ "$ONTBREEKT" = 1 ] && installeer_gereedschap
    haal_map "$REPO" "$DOEL"
    toon_versie "$DOEL"
    schrijf_versie_in_logboek "$DOEL"
    bewijs_grendel "$DOEL"
    (cd "$DOEL" && git add -A && git commit --quiet -m "Oplevering: grendel bewezen, vingerafdruk vastgelegd") || true
    zeg "Klaar. Wat nu"
    echo "  1. Open Terminal, typ:  cd \"$DOEL\" && claude"
    echo "  2. Sluit Gmail aan in Claude, laat hem één keer iets zoeken, en vul het kenmerk in:"
    echo "        bash \"$DOEL/installeer.sh\" gmail <kenmerk van 36 tekens>"
    echo "  3. Open de map in Obsidian (Open folder as vault) en lees LEES-DIT-EERST.md"
    echo "  Bijwerken, later:  bash \"$DOEL/installeer.sh\" update"
    ;;

  update)
    MAP="$(cd "$(dirname "$0")" && pwd)"
    [ -d "$MAP/.git" ] || stop "Draai 'update' vanuit de map zelf: bash ~/tweede-brein/installeer.sh update"
    zeg "Bijwerken van $MAP"
    NIEUWSCRIPT="$(curl -fsSL "https://raw.githubusercontent.com/Evahuese/tweede-brein-installer/main/installeer.sh" 2>/dev/null || true)"
    if [ -n "$NIEUWSCRIPT" ] && [ "$NIEUWSCRIPT" != "$(cat "$0")" ]; then
      printf '%s\n' "$NIEUWSCRIPT" > "$0"
      ok "het script zelf is bijgewerkt vanaf github.com/Evahuese/tweede-brein-installer, draai 'update' nog één keer"
      exit 0
    fi
    (cd "$MAP" && git fetch --quiet origin)
    NIEUW="$(cd "$MAP" && git log --oneline HEAD..origin/main 2>/dev/null || true)"
    if [ -z "$NIEUW" ]; then
      ok "al bij de tijd, niets nieuws"
    else
      echo "  Dit komt erbij:"; echo "$NIEUW" | sed 's/^/    /'
      if [ -n "$(cd "$MAP" && git status --porcelain)" ]; then
        echo "  Er staan eigen wijzigingen die nog niet zijn vastgelegd. Die worden eerst opgeslagen."
        (cd "$MAP" && git add -A && git commit --quiet -m "Eigen werk vastgelegd vóór het bijwerken van $(date +%Y-%m-%d)")
      fi
      (cd "$MAP" && git pull --quiet --no-rebase origin main) || stop "Samenvoegen lukte niet. Bel Eva, niets is kwijt."
      ok "bijgewerkt"
    fi
    toon_versie "$MAP"
    bewijs_grendel "$MAP"
    # AGENTS.md gelijk houden met CLAUDE.md, zonder de uitlegregel bovenaan te verliezen
    if [ -f "$MAP/CLAUDE.md" ] && [ -f "$MAP/AGENTS.md" ]; then
      { sed -n '1,/^-->$/p' "$MAP/AGENTS.md"; echo; cat "$MAP/CLAUDE.md"; } > "$MAP/AGENTS.md.nieuw" && mv "$MAP/AGENTS.md.nieuw" "$MAP/AGENTS.md" && ok "AGENTS.md gelijkgetrokken met CLAUDE.md"
    fi
    ;;

  gmail)
    ID="${2:-}"; MAP="$(cd "$(dirname "$0")" && pwd)"
    [ -n "$ID" ] || stop "Geef het kenmerk mee: bash installeer.sh gmail <36 tekens>"
    [ ${#ID} -ge 20 ] || stop "Dat lijkt geen kenmerk. Het is de reeks tussen mcp__ en __ in de toolnaam, meestal 36 tekens."
    zeg "Gmail-kenmerk invullen"
    grep -q "VUL-IN-GMAIL-ID" "$MAP/.claude/settings.json" || stop "Er staat geen VUL-IN-GMAIL-ID meer in .claude/settings.json. Al ingevuld?"
    sed -i '' "s/VUL-IN-GMAIL-ID/$ID/g" "$MAP/.claude/settings.json"
    ok "$(grep -c "$ID" "$MAP/.claude/settings.json") regels ingevuld"
    (cd "$MAP" && git add .claude/settings.json && git commit --quiet -m "Gmail-kenmerk ingevuld" 2>/dev/null) || true
    ;;

  eigen-adres)
    ADRES="${2:-}"; MAP="$(cd "$(dirname "$0")" && pwd)"
    [ -n "$ADRES" ] || stop "Geef haar eigen adres mee: bash installeer.sh eigen-adres <adres>"
    [ -f "$MAP/.claude/grendel-eigen-adres.json" ] || stop "Geen .claude/grendel-eigen-adres.json gevonden. Draai dit vanuit haar tweede brein."
    zeg "Haar eigen adres invullen"
    python3 - "$MAP/.claude/grendel-eigen-adres.json" "$ADRES" <<'PY'
import json, pathlib, re, sys
pad = pathlib.Path(sys.argv[1])
adres = sys.argv[2].strip()
if not re.fullmatch(r"[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+", adres):
    sys.exit("  STOP    Geef precies één mailadres mee, zonder naam of tweede adres.")
try:
    instelling = json.loads(pad.read_text(encoding="utf-8"))
except (OSError, ValueError):
    sys.exit("  STOP    De instelling voor haar eigen adres is onleesbaar.")
if not isinstance(instelling, dict) or not instelling.get("onderwerp_begint_met"):
    sys.exit("  STOP    Het vaste onderwerpvoorvoegsel ontbreekt.")
instelling["adres"] = adres
pad.write_text(json.dumps(instelling, ensure_ascii=False) + "\n", encoding="utf-8")
PY
    ok "haar eigen adres ingevuld voor de wekelijkse mail"
    (cd "$MAP" && git add .claude/grendel-eigen-adres.json && git commit --quiet -m "Eigen adres ingevuld" 2>/dev/null) || true
    ;;

  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac
