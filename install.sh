#!/bin/sh
set -e

UNIX_USER="nebula"
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
if id "$UNIX_USER" &>/dev/null; then
    echo "$UNIX_USER user exists"
else
    echo "You have to create an account for $UNIX_USER using the web GUI first! Aborting."
    exit 1
fi
INSTALL_DIR=$(dirname $(readlink -f "$0"))
if [ ! -f "${INSTALL_DIR}/config/config.yml" ]; then
    echo "Config file in \"${INSTALL_DIR}/config/config.yml\" does not exist! Place a valid nebula configuration at this location and re-execute the installer."
    exit 1
fi
ARCHITECTURE=""
case $(uname -m) in
    i386)    ARCHITECTURE="386" ;;
    x86_64)  ARCHITECTURE="amd64" ;;
    aarch64) ARCHITECTURE="arm64" ;;
    arm)     ARCHITECTURE="arm-7" ;;
esac
SYSTEMD_SERVICE_NAME="nebula.service"
ASSET_NAME="nebula-linux-${ARCHITECTURE}.tar.gz"
GITHUB_API_BASE="https://api.github.com"
REPO="slackhq/nebula"
RELEASE_JSON=$(curl -s "${GITHUB_API_BASE}/repos/${REPO}/releases/latest")
VERSION=$(echo "$RELEASE_JSON" | jq -r '.tag_name' )
ASSET_INDEX=$(echo $RELEASE_JSON | jq ".assets | map(.name == \"${ASSET_NAME}\") | index(true)")
DOWNLOAD_URL=$(echo $RELEASE_JSON | jq -r ".assets[$ASSET_INDEX].browser_download_url")
echo "Downloading nebula ${VERSION} for ${ARCHITECTURE} from ${DOWNLOAD_URL}"
mkdir -p ${INSTALL_DIR}/bin
curl -sL "$DOWNLOAD_URL" -o "${INSTALL_DIR}/$ASSET_NAME"
tar -xzf "${INSTALL_DIR}/$ASSET_NAME"
rm "${INSTALL_DIR}/$ASSET_NAME"
mv ${INSTALL_DIR}/nebula{,-cert} "${INSTALL_DIR}/bin/"
chown "$UNIX_USER" "${INSTALL_DIR}/bin/nebula"
cp "${INSTALL_DIR}/systemd/nebula.service.sample" "${INSTALL_DIR}/systemd/nebula.service"
sed -i "/Environment=INSTALL_DIR=/c Environment=INSTALL_DIR=${INSTALL_DIR}" "${INSTALL_DIR}/systemd/nebula.service"
cp "${INSTALL_DIR}/systemd/nebula.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable ${SYSTEMD_SERVICE_NAME}
systemctl start ${SYSTEMD_SERVICE_NAME}
