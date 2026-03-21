#!/usr/bin/env bash
set -euo pipefail
# -e  : exit immediately if a command exits with a non-zero status
# -u  : treat unset variables as an error
# -o pipefail : pipeline fails if any command fails

IFS=$'\n\t'

#######################################
# GLOBAL CONSTANTS
#######################################
TODO_FILE="${HOME}/.todo_list.json"

#######################################
# LOGGING FUNCTIONS
#######################################
log_info() {
  local message="$1"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") INFO: ${message}"
}

log_error() {
  local message="$1"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ERROR: ${message}" >&2
}

#######################################
# CLEANUP HANDLER
#######################################
cleanup() {
  :
}
trap cleanup EXIT SIGINT SIGTERM

#######################################
# DEPENDENCY CHECK
#######################################
check_dependencies() {
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Please install jq and retry."
    exit 1
  fi
}

#######################################
# INITIALIZE STORAGE
#######################################
init_storage() {
  if [[ ! -f "${TODO_FILE}" ]]; then
    echo "[]" > "${TODO_FILE}"
  fi
}

#######################################
# VALIDATE INTEGER
#######################################
validate_integer() {
  local value="$1"

  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    log_error "Invalid ID '${value}'. ID must be an integer."
    exit 1
  fi
}

#######################################
# GET NEXT TASK ID
#######################################
get_next_id() {
  jq 'if length == 0 then 1 else (map(.id) | max + 1) end' "${TODO_FILE}"
}

#######################################
# ADD TASK
#######################################
add_task() {
  local description="$1"
  local id

  id="$(get_next_id)"

  local tmp
  tmp="$(mktemp)"

  jq \
    --arg desc "${description}" \
    --argjson id "${id}" \
    '. += [{"id": $id, "description": $desc, "completed": false}]' \
    "${TODO_FILE}" > "${tmp}"

  mv "${tmp}" "${TODO_FILE}"

  log_info "Task added with ID ${id}"
}

#######################################
# DELETE TASK
#######################################
delete_task() {
  local id="$1"

  validate_integer "${id}"

  local exists
  exists="$(jq --argjson id "${id}" 'map(select(.id == $id)) | length' "${TODO_FILE}")"

  if [[ "${exists}" -eq 0 ]]; then
    log_error "Task with ID ${id} does not exist."
    exit 1
  fi

  local tmp
  tmp="$(mktemp)"

  jq --argjson id "${id}" 'map(select(.id != $id))' "${TODO_FILE}" > "${tmp}"

  mv "${tmp}" "${TODO_FILE}"

  log_info "Task ${id} deleted"
}

#######################################
# COMPLETE TASK
#######################################
complete_task() {
  local id="$1"

  validate_integer "${id}"

  local exists
  exists="$(jq --argjson id "${id}" 'map(select(.id == $id)) | length' "${TODO_FILE}")"

  if [[ "${exists}" -eq 0 ]]; then
    log_error "Task with ID ${id} does not exist."
    exit 1
  fi

  local tmp
  tmp="$(mktemp)"

  jq \
    --argjson id "${id}" \
    'map(if .id == $id then .completed = true else . end)' \
    "${TODO_FILE}" > "${tmp}"

  mv "${tmp}" "${TODO_FILE}"

  log_info "Task ${id} marked as completed"
}

#######################################
# VIEW TASKS
#######################################
view_tasks() {
  if [[ ! -s "${TODO_FILE}" ]]; then
    echo "No tasks found."
    return
  fi

  {
    echo -e "ID\tSTATUS\tDESCRIPTION"
    jq -r '
      .[]
      | [
          .id,
          (if .completed then "[x]" else "[ ]" end),
          .description
        ]
      | @tsv
    ' "${TODO_FILE}"
  } | column -t -s $'\t'
}

#######################################
# USAGE
#######################################
usage() {
  cat <<EOF
Usage:
  todo add "task description"
  todo delete <ID>
  todo complete <ID>
  todo view
EOF
}

#######################################
# MAIN
#######################################
main() {
  check_dependencies
  init_storage

  if [[ "$#" -lt 1 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift || true

  case "${command}" in
    add)
      if [[ "$#" -ne 1 ]]; then
        log_error "add requires a task description"
        usage
        exit 1
      fi
      add_task "$1"
      ;;
    delete)
      if [[ "$#" -ne 1 ]]; then
        log_error "delete requires a task ID"
        usage
        exit 1
      fi
      delete_task "$1"
      ;;
    complete)
      if [[ "$#" -ne 1 ]]; then
        log_error "complete requires a task ID"
        usage
        exit 1
      fi
      complete_task "$1"
      ;;
    view)
      if [[ "$#" -ne 0 ]]; then
        log_error "view does not take arguments"
        usage
        exit 1
      fi
      view_tasks
      ;;
    *)
      log_error "Unknown command: ${command}"
      usage
      exit 1
      ;;
  esac
}

main "$@"