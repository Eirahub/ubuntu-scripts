# ubuntu-scripts

Holder kurslaptopene (Zorin OS / Ubuntu) oppdatert og i standardoppsett, uten håndarbeid.
Kjører ved oppstart og hver 6. time, henter først siste versjon av dette repoet og kjører så modulene.
En liten del (nøkkelringen) kjøres i tillegg før innloggingsskjermen, uten nett.

## Installer på en laptop (én gang)

1. Logg inn med en bruker som kan bruke `sudo`, og åpne terminalen med **Ctrl+Alt+T**.
2. Lim inn denne kommandoen og skriv passordet:

   ```bash
   wget -qO- https://raw.githubusercontent.com/Eirahub/ubuntu-scripts/main/install.sh | sudo bash
   ```

   (`wget` fordi `curl` ikke alltid er installert på Zorin. Installasjonen legger selv inn det den trenger.)
3. Vent til loggen vises. Første kjøring tar 5–10 minutter (Java, VS Code, Brave, MultiMC).
4. **Start maskinen på nytt**, så nøkkelringen blir ordnet før innloggingsskjermen.

Gjør det først på én laptop og sjekk `cat /var/log/ubuntu-scripts.log` før du tar resten.

MultiMC som allerede er installert blir funnet uansett hvor i hjemmemappa den ligger, og instanser
som har moden får alltid siste versjon. Ingenting må gjøres for hånd.

Etter det er alt styrt herfra: endringer som pushes til `main` når laptopene ved neste kjøring.

## Moduler

| Modul | Hva den gjør |
|---|---|
| `pakker` | apt-pakkene kursene trenger (`APT_PACKAGES`), og sjekk av port 2220 til Bandit (Hackerskolen) |
| `java` | Eclipse Temurin 17, 21 og 25 fra Adoptiums apt-repo |
| `vscode` | VS Code fra Microsofts apt-repo, fjerner flatpak/snap-versjonen |
| `brave` | Brave fra apt, åpner `BRAVE_URL` ved innlogging og som startside |
| `multimc` | Installerer MultiMC i `~/MultiMC` hvis den mangler, oppdaterer når nedlastingen endres |
| `instance-java` | Gir hver MultiMC-instans riktig Java (26.x: 25, 1.20.5 til 1.21.x: 21, 1.17 til 1.20.4: 17) |
| `halisoncode` | Siste [Halison Code](https://github.com/halisonworks/mod-halisoncode) (og Fabric API) i MultiMC-instansene |
| `keyring` | Nøkkelring uten passord, så det aldri kommer "lås opp nøkkelring"-vinduer |
| `desktop` | Fester MultiMC, Terminal og VS Code i taskbar og midtstiller ikonene |

Halison Code legges i instanser som har moden fra før, eller som har `Halison` i navnet.
Lag f.eks. en Fabric-instans som heter `Halison Code 1.21.11`, så fylles den ved neste kjøring.

**Slå av/på:** rediger `MODULES` i [config.sh](config.sh). En avslått modul rydder etter seg hvis den kan.

**Én laptop annerledes:** skriv overstyringer i `/etc/ubuntu-scripts/config.local.sh` på den laptopen.

**Ny modul:** lag `modules/<navn>.sh` med en eller flere av funksjonene

- `root_part`: kjøres som root (apt, systemfiler)
- `user_part`: kjøres som hver vanlig bruker (hjemmemappe, innstillinger)
- `uninstall_part`: kjøres som root når modulen er slått av

og legg navnet til i `MODULES`. Hjelpefunksjoner (`log`, `apt_install`, `add_apt_repo`, `multimc_instances` osv.) ligger i [lib/common.sh](lib/common.sh).
En modul som feiler stopper ikke de andre.

## På laptopen

```bash
sudo systemctl start ubuntu-scripts.service   # kjør nå
cat /var/log/ubuntu-scripts.log               # hva skjedde
sudo /opt/ubuntu-scripts/run.sh --modul halisoncode   # bare én modul
/opt/ubuntu-scripts/run.sh --status
```

Fjern: `wget -qO- https://raw.githubusercontent.com/Eirahub/ubuntu-scripts/main/install.sh | sudo bash -s -- --avinstaller`

## Sikkerhet

Laptopene kjører det som ligger på `main` som root. Alle med skrivetilgang til dette repoet har dermed root på
laptopene. Hold tilgangen liten og slå på branch protection for `main`. Legg aldri passord eller tokens her: repoet er offentlig.
