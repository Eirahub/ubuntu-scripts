# Felles innstillinger for alle laptopene.
# Endringer her når laptopene ved neste kjøring (oppstart eller hver 6. time).
# Én laptop kan overstyre hva som helst i /etc/ubuntu-scripts/config.local.sh.

# Moduler som kjøres, i denne rekkefølgen. Fjern et navn for å slå av modulen.
# En avslått modul rydder etter seg hvis den kan (f.eks. fjerner brave autostart).
# Tilgjengelige: se mappen modules/.
MODULES="pakker java vscode intellij brave multimc instance-java halisoncode elevbruker ssh systeminnstillinger nullstill keyring desktop"

# Hvor laptopene henter siste versjon av dette repoet
REPO_TARBALL="https://codeload.github.com/Eirahub/ubuntu-scripts/tar.gz/refs/heads/main"

# --- pakker: apt-pakker kursene trenger ---
APT_PACKAGES="
  python3 git curl unzip
  openssh-client libimage-exiftool-perl
"
# Hackerskolen (oppgaver.eirahub.no/hackerskolen): python3, git, openssh-client (Bandit),
#   libimage-exiftool-perl (Bildet avslører deg), curl, unzip (hackerlab.zip)
BANDIT_CHECK="bandit.labs.overthewire.org:2220"   # tom = ikke sjekk

# --- java: Eclipse Temurin fra Adoptiums apt-repo ---
JAVA_VERSIONS="17 21 25"
JAVA_KIND="jre"                     # jre eller jdk

# --- intellij: IntelliJ IDEA Community, låst til denne versjonen (siste .x hentes automatisk) ---
INTELLIJ_MAJOR="2025.2"

# --- brave: installer/oppdater Brave og åpne denne siden ved innlogging ---
BRAVE_URL="https://oppgaver.eirahub.no"
# Bokmerkelinja "Kurs": én per linje, "Navn|adresse"
BRAVE_BOOKMARKS="
Oppgaver|https://oppgaver.eirahub.no
Hackerskolen|https://oppgaver.eirahub.no/hackerskolen/
"
BRAVE_SAFE_SEARCH=1                 # 1 = tvungen SafeSearch i Google og begrenset modus i YouTube

# --- vscode: utvidelser for hver bruker ---
VSCODE_EXTENSIONS="ms-python.python"

# --- multimc: installer/oppdater MultiMC for hver bruker ---
MULTIMC_URL="https://files.multimc.org/downloads/mmc-stable-lin64.tar.gz"
MULTIMC_NEW_DIR="MultiMC"           # relativt til hjemmemappen, brukes hvis MultiMC mangler
MULTIMC_MEMORY_MB=""                # minne til Minecraft i MB, tom = en tredel av RAM (2048 til 4096)

# --- instance-java: gi hver MultiMC-instans riktig Java (17, 21 eller 25) ---
# (ingen innstillinger, bruker JAVA_KIND over)

# --- desktop: standardoppsett for skrivebordet, settes på nytt ved hver kjøring ---
# Festede apper i taskbar, i rekkefølge. "a|b" = første som finnes.
DESKTOP_FAVORITES="multimc.desktop|exec:multimc org.gnome.Terminal.desktop|org.gnome.Ptyxis.desktop|org.gnome.Console.desktop code.desktop|com.microsoft.VSCode.desktop intellij-idea-community.desktop"
DESKTOP_FAVORITES_EXACT=0           # 1 = bare disse, 0 = disse først, så det som allerede er festet
DESKTOP_TASKBAR_CENTER=1            # 1 = midtstilte ikoner i Zorin taskbar

# --- systeminnstillinger: GNOME-innstillinger for alle brukere står i files/gnome.ini (låste i files/gnome-laast.txt):
#     skjermen slås ikke av, ingen dvale på strøm, ingen låseskjerm, norsk tastatur, ingen oppdateringsvarsler,
#     bakgrunnsbilde med laptopnavnet.
SYS_TIMEZONE="Europe/Oslo"
SYS_KEYBOARD="no"
WALLPAPER_TEXT="oppgaver.eirahub.no"

# --- elevbruker: elevbrukeren, aldri admin, logges inn automatisk ---
# Passordet er ikke hemmelig og trengs nesten aldri (ingen låseskjerm, automatisk innlogging).
ELEV_USER="bruker"
ELEV_PASSWORD="12345"
ELEV_AUTOLOGIN=1

# --- ssh: admin-kontoene (gruppen sudo) kan logges inn på med disse nøklene, aldri med passord ---
SSH_KEYS="
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9IMuOEi3Zbkt41UjXP8OdPNRX/Xlmy0RUuXwfANXx5
"

# --- nullstill: elevbrukeren tilbakestilles til en ren hjemmemappe før innloggingsskjermen ---
# Øk tallet og push for å nullstille alle laptopene. Skjer ved oppstarten etter at laptopen har hentet
# endringen (oftest to omstarter). På én laptop: sudo /opt/ubuntu-scripts/run.sh --nullstill
RESET_GENERATION=0
# Beholdes (relativt til hjemmemappa): MultiMC med instanser og Microsoft-innlogging
RESET_KEEP="MultiMC .local/share/multimc"
RESET_KEEP_WORLDS=0                 # 1 = behold Minecraft-verdener og Halison-prosjekter i instansene

# --- halisoncode: siste Halison Code-mod (og Fabric API) i MultiMC-instansene ---
# Får moden: instanser som har den fra før, og instanser med dette i navnet.
HALISON_INSTANCE_MATCH="Halison"
HALISON_REPO="halisonworks/mod-halisoncode"
HALISON_PRERELEASE=1                # 1 = ta med pre-releases
HALISON_FABRIC_API=1                # 1 = hent også Fabric API til Fabric-instanser
