# dockerspace — everything Docker on a fresh PC

pc-maker sets up a **new** PC. This folder is all of its Docker work: install Docker,
check it, and (next story) tools used as **throwaway containers** — so nothing but Docker
is installed on the PC.

## Fresh PC, in order

1. the OS — `ossetup/debian2debian/`
2. **Docker** — `bash dockerspace/docker_install.sh` (asks for sudo itself)
3. log out and back in once (the docker group)
4. check — `bash dockerspace/docker_status.sh`

## Files

| File | What |
|------|------|
| `docker_install.sh` | installs Docker Engine + buildx + compose from Docker's repository · Debian, Ubuntu and OSes based on them (Linux Lite, Mint …) · safe to repeat: already there → nothing to do |
| `docker_status.sh` | looks only: installed · running · you in the docker group · tool images |
| `docker.conf` | the repository + codename used when the OS is not recognised (default `ubuntu noble`) |
| `lib/docker_common.sh` | the shared functions of both scripts |
| `tests/test_dockerspace.sh` | auto tests — fake docker / apt / sudo, never the real ones |

## 🔑 Secrets

None.

## Not for the PC it is written on

The real run is on the fresh PC. The tests use fakes in a temp folder only.
