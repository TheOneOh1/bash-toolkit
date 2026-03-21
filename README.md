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

---

## `health-check/health-check.sh` – Service health checker for Spring Boot applications

**Description**  
Checks the health of a Java Spring Boot application by verifying the port is listening and querying the /actuator/health endpoint.

**Requirements**
- **Bash**
- **curl**
- **ss** (for port checking, usually provided by iproute2 on Linux)

**Behavior**
- Takes service name, port, and optional host (default localhost).
- Checks if the port is listening.
- Queries /actuator/health endpoint, expecting HTTP 200 and "status":"UP".
- Retries up to 5 times with 3-second intervals.
- Exit codes: 0 (success), 1 (failure), 2 (service running but actuator not exposed).

**Usage**

```bash
cd bash-scripts
chmod +x health-check/health-check.sh
./health-check/health-check.sh my-service 8080
./health-check/health-check.sh my-service 8080 remote-host
```

**General syntax**

```bash
./health-check/health-check.sh <SERVICE_NAME> <PORT> [HOST]
```

---

## `artifact-backup/artifact-backup.sh` – Artifact backup script

**Description**  
Backs up specified artifacts (e.g., WAR/JAR files) to a backup directory with timestamps and maintains a retention policy.

**Requirements**
- **Bash**
- Must be run as root
- Access to the artifact files and backup directory (/opt/artifact-backups)

**Behavior**
- Backs up a predefined list of artifacts.
- Creates backups in /opt/artifact-backups with service subdirectories.
- Appends timestamp to backup filenames.
- Keeps only the last 5 backups per artifact, removing older ones.
- Logs operations with timestamps.

**Usage**

```bash
cd bash-scripts
chmod +x artifact-backup/artifact-backup.sh
sudo ./artifact-backup/artifact-backup.sh
```

No arguments required; the script uses a hardcoded list of artifacts.

---

## `cli-todo/cli-todo.sh` – CLI Todo Manager

**Description**  
A command-line todo list manager that allows you to add, view, delete, and mark tasks as complete. Tasks are stored in a JSON file in your home directory.

**Requirements**
- **Bash**
- **jq** (for JSON manipulation)

**Behavior**
- Stores tasks in `~/.todo_list.json` as a JSON array.
- Each task has an ID, description, and completion status.
- Commands: `add`, `delete`, `complete`, `view`.
- Validates inputs and provides error messages.
- Logs operations with timestamps.

**Usage**

```bash
cd bash-toolkit
chmod +x cli-todo/cli-todo.sh
./cli-todo/cli-todo.sh add "Buy groceries"
./cli-todo/cli-todo.sh view
./cli-todo/cli-todo.sh complete 1
./cli-todo/cli-todo.sh delete 1
```

**General syntax**

```bash
./cli-todo/cli-todo.sh <command> [arguments]
```

Where `<command>` is one of:
- `add "description"`: Add a new task
- `delete <ID>`: Delete task by ID
- `complete <ID>`: Mark task as completed
- `view`: List all tasks

**Example output for `view`**

```text
ID  STATUS  DESCRIPTION
1   [ ]     Buy groceries
2   [x]     Finish report
```

---

## `log-rotate/log-rotate.sh` – Smart log rotation and compression

**Description**  
Smart log rotation and compression for application logs. Handles size limits, max age, and archiving to a configurable directory. Can be used as a standalone script or incorporated easily into a cron job.

**Requirements**
- **Bash**
- Common Unix utilities: `gzip`, `find`, `stat`, `date`, `cp`, `mv`

**Behavior**
- Checks targeted log files; if their size exceeds the limit (default 30MB), copies and truncates the log, then compresses it using `gzip`.
- Finds archived (`*.gz`) logs older than the maximum age (default 30 days) and moves them directly to an archive directory.
- Supports both single log files and complete directories.

**Usage**

```bash
cd bash-toolkit-1
chmod +x log-rotate/log-rotate.sh
./log-rotate/log-rotate.sh --log-path /var/log/myapp/app.log
```

**General syntax**

```bash
./log-rotate/log-rotate.sh --log-path <path> [options]
```

**Options**
- `--log-path <path>`: Target log file or directory (Required).
- `--max-size <MB>`: Max size in megabytes before rotation (Default: 30).
- `--max-age <days>`: Max age in days before old logs are archived (Default: 30).
- `--archive-dir <path>`: Directory to move archived logs (Default: `<log-path-dir>/archive`).

---

## `secret-scan/secret-scan.sh` – Secret pattern scanner

**Description**  
Recursively scans files in a directory for common secret patterns — AWS keys, Bearer tokens, private keys, `.env` literals — and reports findings with line numbers. Useful as a quick pre-commit sanity check or a scheduled sweep of your codebase.

**Requirements**
- **Bash**
- Common Unix utilities: `grep` (with `-P` Perl regex support), `find`, `file`, `sed`

**Behavior**
- Scans every file recursively in the given directory.
- Checks against 16 built-in patterns covering AWS keys, GitHub/Slack/Heroku tokens, Bearer tokens, PEM private keys, hardcoded passwords/secrets/tokens, database URLs, and `.env`-style secrets.
- Skips binary files automatically.
- Reports each finding with the file path, line number, matched pattern label, and a trimmed preview of the offending line.
- Exits with code `1` if any secrets are found, `0` if clean.

**Usage**

```bash
cd bash-toolkit-1
chmod +x secret-scan/secret-scan.sh
./secret-scan/secret-scan.sh --dir /path/to/your/project
```

**General syntax**

```bash
./secret-scan/secret-scan.sh --dir <path> [options]
```

**Options**
- `--dir <path>`: Directory to scan recursively (Required).
- `-h, --help`: Show help.

**Example output (shape)**

```text
========================================
 Secret Scan Started
========================================

[INFO] Target      : /home/user/myproject
[INFO] Patterns    : 16 rules loaded

  📄 /home/user/myproject/.env
  ────────────────────────────────────
  ⚠  AWS Access Key ID
     Line 3: AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE

  ⚠  Secret Assignment
     Line 5: SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

========================================
 Scan Complete
========================================

[INFO] Files scanned   : 42
[WARN] Findings        : 2 potential secret(s) in 1 file(s)
```

---

## `sys-snapshot/sys-snapshot.sh` – Point-in-time system state capture

**Description**  
Takes a point-in-time snapshot of CPU usage, memory, top 20 processes, disk I/O, disk usage, open file descriptors, and network connections. Useful for capturing system state during incidents or performance investigations. Output goes to both terminal and a timestamped file.

**Requirements**
- **Bash**
- **Linux** (uses `/proc` filesystem, `free`, `ps`, `df`, etc.)
- Optional: `mpstat`, `iostat` (from `sysstat` package) for richer CPU/disk stats

**Behavior**
- Captures uptime, CPU breakdown, memory usage, top 20 processes by CPU, disk I/O stats, disk usage, open file descriptor counts, and network connection summary.
- Outputs everything to the terminal AND saves a clean (ANSI-stripped) copy to a timestamped file like `snapshot_20260321_140000.txt`.
- Gracefully skips sections when optional tools (`mpstat`, `iostat`) aren't installed.

**Usage**

```bash
cd bash-toolkit-1
chmod +x sys-snapshot/sys-snapshot.sh
./sys-snapshot/sys-snapshot.sh
./sys-snapshot/sys-snapshot.sh --output-dir /tmp/snapshots
```

**General syntax**

```bash
./sys-snapshot/sys-snapshot.sh [options]
```

**Options**
- `--output-dir <path>`: Directory to save the snapshot file (Default: current directory).
- `-h, --help`: Show help.
