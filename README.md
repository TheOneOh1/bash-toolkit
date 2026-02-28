# Bash Utility Scripts 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


Collection of small, focused Bash utilities for day‑to‑day system and development tasks.

---

## `ssl-check/ssl-check.sh` – SSL certificate expiry checker

**Description**  
Checks SSL certificate expiry for a list of domains and prints a table with domain, days remaining, and expiry date.

**Requirements**
- **Bash**
- **openssl**
- **date** with `-d` support (GNU date)

**Domain list format**
- One domain per line.
- Empty lines are ignored.
- Lines starting with `#` are treated as comments.

Example `domains.txt`:

```text
git-scm.com
github.com
# comment line
sonarsource.com
```

**Usage**

```bash
cd bash-scripts
chmod +x ssl-check/ssl-check.sh
./ssl-check/ssl-check.sh ssl-check/domains.txt
```

**General syntax**

```bash
./ssl-check/ssl-check.sh <path-to-domains-file>
```

**Example output (shape)**

```text
Domain                         | Days Remaining  | Expiry Date
------------------------------------------------------------------------
github.com                    | 75              | May 10 12:34:56 2026 GMT
example.com                   | ERROR           | Failed to fetch certificate
```

---

## `disk-util.sh` – Disk utilization for a directory

**Description**  
Shows disk usage for the top-level entries inside a given directory, sorted by size (largest first).

**Requirements**
- **Bash**
- Common Unix utilities: `du`, `sort`, `awk`, `column`

**Behavior**
- If no argument is provided, uses the current directory (`.`).
- If a directory is provided, validates that it exists before scanning.
- Only top-level items (`DIR/*`) are included in the report.

**Usage**

```bash
cd bash-scripts
chmod +x disk-util.sh
./disk-util.sh            # scan current directory
./disk-util.sh /var/log   # scan specific directory
```

**General syntax**

```bash
./disk-util.sh [DIRECTORY]
```


---

## `port-check.sh` – Occupied ports and processes

**Description**  
Prints a list of currently occupied TCP/UDP ports along with their state and owning process name.

**Requirements**
- **Bash**
- `ss` command (usually provided by `iproute2` on Linux)

**Behavior**
- Verifies that `ss` is available before running.
- Uses `ss -tunlp` and formats each line as:
  - `State: <STATE> | Port: <PORT> | Process: <PROCESS_NAME>`

**Usage**

```bash
cd bash-scripts
chmod +x port-check.sh
./port-check.sh
```

No arguments are required; the script immediately prints the occupied ports table.

---

## `docker-reaper` – Docker resource cleanup helper

**Description**  
Cleans up stopped containers, dangling images, and orphaned volumes. By default it runs in **dry-run mode**, showing what would be removed without actually deleting anything.

**Requirements**
- **Bash**
- **Docker CLI** (`docker` command)
- Access to a running Docker daemon

**Behavior**
- Validates that `docker` is installed and the daemon is reachable.
- Lists:
  - Stopped containers (`docker ps -aq -f status=exited`)
  - Dangling images (`docker images -f dangling=true -q`)
  - Orphaned volumes (`docker volume ls -qf dangling=true`)
- In dry-run mode it only prints IDs; with `--force` it actually removes them.

**Usage**

```bash
cd bash-scripts
chmod +x docker-reaper
./docker-reaper            # dry run (no deletions)
./docker-reaper --force    # actually delete resources
./docker-reaper --help     # show usage
```


