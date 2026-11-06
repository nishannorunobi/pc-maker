# dockerspace — everything Docker on a fresh PC

pc-maker sets up a **new** PC. This folder is all of its Docker work: install Docker,
check it, and tools used as **throwaway containers** — so nothing but Docker is installed
on the PC.

## Fresh PC, in order

1. the OS — `ossetup/debian2debian/`
2. **Docker** — `bash dockerspace/docker_install.sh` (asks for sudo itself)
3. log out and back in once (the docker group)
4. check — `bash dockerspace/docker_status.sh`
5. use a tool — from your project folder, e.g. `bash ~/pc-maker/dockerspace/jdk/java.sh Hello.java`

## Tools (throwaway containers)

| Tool | Commands | Image (`<tool>/tool.conf`) |
|------|----------|----------------------------|
| `jdk/` | `java.sh` · `javac.sh` | `eclipse-temurin:21-jdk` |
| `maven/` | `mvn.sh` (libraries kept in `.cache/maven/`) | `maven:3.9-eclipse-temurin-21` |

Each run: `docker run --rm` · as you (files stay yours) · your current folder at the same path ·
first use downloads the image once. Docker missing → offered.

**Add a tool** = a new folder, nothing else changes:

```
dockerspace/<tool>/
├── tool.conf      IMAGE=<registry/name:version>   (+ CACHE=<folder to keep> · ENV="VAR=value")
├── Dockerfile     only when no ready image exists — built on first use
└── <command>.sh   copy jdk/java.sh, change the last line: run_tool <tool> <default image> <command> "$@"
```

## Files

| File | What |
|------|------|
| `docker_install.sh` | installs Docker Engine + buildx + compose from Docker's repository · Debian, Ubuntu and OSes based on them (Linux Lite, Mint …) · safe to repeat: already there → nothing to do |
| `docker_status.sh` | looks only: installed · running · you in the docker group · tool images |
| `docker.conf` | the repository + codename used when the OS is not recognised (default `ubuntu noble`) |
| `lib/docker_common.sh` | the shared functions of the scripts |
| `lib/run_tool.sh` | `run_tool` — the ONE function every tool uses |
| `.cache/` | what tools keep between runs (git-ignored) |
| `tests/test_dockerspace.sh` | auto tests of install + status — fake docker / apt / sudo, never the real ones |
| `tests/test_tools.sh` | auto tests of the tools — a fake docker records the `docker run`, none is run |

## 🔑 Secrets

None.

## Not for the PC it is written on

The real run is on the fresh PC. The tests use fakes in a temp folder only.
