#!/bin/bash
# docker_install.sh — Install Docker Engine on Debian/Ubuntu.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash docker_install.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

echo "Installing Docker Engine..."

# ── Remove old versions ───────────────────────────────────────────────────────
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# ── Dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y ca-certificates curl gnupg lsb-release -qq

# ── Docker GPG key ────────────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# ── Docker apt repository ─────────────────────────────────────────────────────
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# ── Install Docker ────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin -qq

# ── Add user to docker group (no sudo needed) ─────────────────────────────────
usermod -aG docker "$REAL_USER"

# ── Enable and start Docker ───────────────────────────────────────────────────
systemctl enable docker
systemctl start docker

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "Done. Docker installed: $(docker --version)"
echo ""
echo "  User '$REAL_USER' added to docker group."
echo "  Log out and back in for group change to take effect."
echo "  Test: docker run hello-world"
