#!/bin/sh
# phenix image build script for Kali Purple (defensive Kali) plus parseus.
# Nothing here needs a running docker daemon (the build is a chroot); parseus itself is
# installed on first boot by parseus-install.service. Two modes:
#  - offline: the overlay from scripts/parseus-bundle.sh put parseus's bundle (source + container
#    image archives) at /opt/parseus-bundle; first boot runs `install --method bundle`, no network.
#  - network (no bundle): the source is cloned to /opt/parseus-src; first boot builds/pulls images.

set -ex

export DEBIAN_FRONTEND=noninteractive

# Parseus source to stage. feat-zeek-ics-dpi on the adamsrnmsu/parseus fork carries the Zeek
# DPI (DNP3/Modbus) work until sandialabs/parseus#4 merges; set PARSEUS_INTEGRATIONS=zeek
# alongside it (older refs reject the zeek integration name).
PARSEUS_REPO="${PARSEUS_REPO:-https://github.com/sandialabs/parseus.git}"
PARSEUS_REF="${PARSEUS_REF:-main}"
PARSEUS_INTEGRATIONS="${PARSEUS_INTEGRATIONS:-}"
PARSEUS_SRC=/opt/parseus-src
PARSEUS_BUNDLE=/opt/parseus-bundle

apt-get update

# Kali Purple = xfce desktop + purple theme/menu (kali-themes-purple, kali-menu-purple) + defensive tools.
apt-get install -y kali-desktop-xfce kali-themes-purple kali-menu-purple suricata tcpdump wireshark jq \
  kali-grant-root ntpsec dos2unix zip unzip tree nano
# Parseus runs as a docker compose stack.
apt-get install -y docker.io docker-compose python3 openssl git ca-certificates curl

# Kali Linux uses ntpsec (a hardened fork of NTP) instead of ntp, and comes installed with it by default.
# This is problematic from a SCEPTRE perspective, since the ntp app just assumes everything uses NTP, and
# injects /etc/ntp.conf on all Linux systems. To work around this, make ntpsec's configuration a symlink
# to /etc/ntp.conf, so it uses the NTP configuration injected by SCEPTRE.
mv /etc/ntpsec/ntp.conf /etc/ntpsec/ntp.conf.bak
ln -s /etc/ntp.conf /etc/ntpsec/ntp.conf
systemctl enable ntpsec

dpkg-reconfigure kali-grant-root

if [ -f "$PARSEUS_BUNDLE/manage_parseus.py" ]; then
  OFFLINE=1
  PARSEUS_CMD="$PARSEUS_BUNDLE/manage_parseus.py install --method bundle"
else
  # Stage parseus source (idempotent).
  OFFLINE=0
  PARSEUS_CMD="$PARSEUS_SRC/manage_parseus.py install"
  rm -rf "$PARSEUS_SRC"
  git clone --depth 1 --branch "$PARSEUS_REF" "$PARSEUS_REPO" "$PARSEUS_SRC"
fi

INTEGRATIONS_ARG=""
[ -n "$PARSEUS_INTEGRATIONS" ] && INTEGRATIONS_ARG="--integrations $PARSEUS_INTEGRATIONS"

# PEAT (Sandia Process Extraction and Analysis Tool, GPL-3.0), installed at build time so first boot
# needs no network. Every asset is pinned by sha256; bump PEAT_VERSION and the hashes together.
#  - x86_64: the release's self-contained binary (tarball with the man page).
#  - other arches (arm64): the release's pure-Python wheel in a venv. PEAT needs Python < 3.14 and
#    Kali's python3 is 3.14, so it uses python3.13. pip pulls PEAT's dependencies from PyPI.
# ponytail: python3.13 leaves Kali rolling eventually; switch arm64 to the release's peat_linux_arm64
# binary (sandialabs/PEAT#113) once a release ships it.
PEAT_VERSION="${PEAT_VERSION:-v2026.9.2}"
PEAT_SHA256="${PEAT_SHA256:-b3675d450429e284422a2c52521ab55410cc1daa0c6dcc58b57ac25175785666}"
# v2026.9.2's wheel was built just before the tag, so it carries a pre-tag version string (2026.2.11.dev40).
PEAT_WHEEL="${PEAT_WHEEL:-peat-2026.2.11.dev40+gf4bdc81-py3-none-any.whl}"
PEAT_WHEEL_SHA256="${PEAT_WHEEL_SHA256:-4eadbbd0f11654a16b6dc0cbe4cd5171aebeb3965b43fd3e9dede49a56af0184}"
PEAT_MAN_SHA256="${PEAT_MAN_SHA256:-5781b2b0640ce315c32e302ace6cc7e3a3d819864b3d7b1747e2b79b9c8d440d}"
PEAT_URL="https://github.com/sandialabs/PEAT/releases/download/$PEAT_VERSION"
PEAT_TMP=$(mktemp -d)
if [ "$(uname -m)" = x86_64 ]; then
  curl -fsSL -o "$PEAT_TMP/peat.tgz" "$PEAT_URL/peat_linux_$PEAT_VERSION.tgz"
  echo "$PEAT_SHA256  $PEAT_TMP/peat.tgz" | sha256sum -c -
  tar -xzf "$PEAT_TMP/peat.tgz" -C "$PEAT_TMP"
  install -m 0755 "$PEAT_TMP/peat_linux/peat" /usr/local/bin/peat
  install -D -m 0644 "$PEAT_TMP/peat_linux/peat.1" /usr/local/share/man/man1/peat.1
else
  apt-get install -y python3.13-venv
  curl -fsSL -o "$PEAT_TMP/$PEAT_WHEEL" "$PEAT_URL/$PEAT_WHEEL"
  curl -fsSL -o "$PEAT_TMP/peat.1" "$PEAT_URL/peat.1"
  printf '%s  %s\n%s  %s\n' "$PEAT_WHEEL_SHA256" "$PEAT_TMP/$PEAT_WHEEL" "$PEAT_MAN_SHA256" "$PEAT_TMP/peat.1" | sha256sum -c -
  rm -rf /opt/peat
  python3.13 -m venv /opt/peat
  /opt/peat/bin/pip install --no-cache-dir "$PEAT_TMP/$PEAT_WHEEL"
  ln -sf /opt/peat/bin/peat /usr/local/bin/peat
  install -D -m 0644 "$PEAT_TMP/peat.1" /usr/local/share/man/man1/peat.1
fi
rm -rf "$PEAT_TMP"
peat --version

# First-boot install (network mode needs network to build/pull container images). parseus-first-install is
# retry-safe: a failed install leaves runtime markers (and possibly docker volumes) but no manifest,
# which parseus then rejects as "already installed". The wrapper removes only the two regenerable
# rendered compose markers, so install resumes; it never touches config/secrets (parseus keeps
# existing env values), certs or docker volumes, and re-running install over them is idempotent.
cat > /usr/local/sbin/parseus-first-install <<'WRAP'
#!/bin/sh
set -eu
state=/var/lib/parseus
[ -e "$state/state/current_manifest.json" ] && exit 0
if [ -e "$state/runtime/compose.runtime.yaml" ] && [ -e "$state/runtime/compose.images.yaml" ]; then
  echo "parseus: previous install did not finish; clearing its runtime markers to resume"
  rm -f "$state/runtime/compose.runtime.yaml" "$state/runtime/compose.images.yaml"
fi
exec /usr/bin/python3 "$@"
WRAP
chmod 0755 /usr/local/sbin/parseus-first-install

if [ "$OFFLINE" = 1 ]; then
  UNIT_AFTER="After=docker.service"
  UNIT_WANTS=""
  # The bundle is installed; free the ~2 GB of image archives (docker holds the loaded images).
  UNIT_POST="ExecStartPost=/bin/rm -rf $PARSEUS_BUNDLE/images"
else
  UNIT_AFTER="After=network-online.target docker.service"
  UNIT_WANTS="Wants=network-online.target"
  UNIT_POST=""
fi
cat > /etc/systemd/system/parseus-install.service <<UNIT
[Unit]
Description=Parseus first-boot install
$UNIT_AFTER
$UNIT_WANTS
Requires=docker.service
ConditionPathExists=!/var/lib/parseus/state/current_manifest.json
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/parseus-first-install $PARSEUS_CMD $INTEGRATIONS_ARG
$UNIT_POST
# Docker or registry not ready yet: retry with growing delay (15s, up to 10min).
Restart=on-failure
RestartSec=15
RestartSteps=6
RestartMaxDelaySec=600
TimeoutStartSec=infinity
StandardOutput=journal
StandardError=journal
SyslogIdentifier=parseus-install

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable parseus-install.service docker.service
