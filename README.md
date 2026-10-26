# tweede-brein-installer

Eén script dat een tweede brein op een Mac neerzet en later bijwerkt. Gemaakt door Eva Huese
(EV-AI) voor haar klanten. Het script bevat geen klantgegevens en geen inhoud van het tweede
brein zelf; die staan in de privérepo van de klant.

Op een verse Mac, één regel in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Evahuese/tweede-brein-installer/main/installeer.sh | bash -s -- install <eigenaar>/<naam-tweede-brein>
```

Het script installeert wat er mist (Apple ontwikkeltools, Homebrew, GitHub CLI, Obsidian,
Claude Code), logt in bij GitHub, haalt de map op, bewijst de grendel en legt de versie vast.
Daarna, vanuit de map zelf:

```bash
bash ~/tweede-brein/installeer.sh update     de nieuwste versie ophalen
bash ~/tweede-brein/installeer.sh check      wat staat er op deze Mac
bash ~/tweede-brein/installeer.sh gmail <kenmerk>
```

Alleen voor macOS. Het script zegt wat het doet en stopt bij de eerste fout.

## Windows

`zet-klaar.ps1` zet het tweede brein neer op Windows, voor de ChatGPT-app (Work). Eén regel in PowerShell, zie de kop van het script.
