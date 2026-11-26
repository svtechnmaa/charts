#!/usr/bin/env bash
#
# icinga2 zones.conf manager
#
# Consolidates the Endpoint/Zone bookkeeping used by the icinga2 master pods
# (master_zones.conf, rewritten on every start) and the satellite pods (zone
# watcher adds and removes peers) into a single set of functions dispatched by
# name:
#
#   zone-manager.sh <function> [args...]
#
# Examples:
#   zone-manager.sh generate_master_zones /opt/zones.d/master_zones.conf master nmaa-icinga2-master 2 icinga2-headless.ns.svc.cluster.local
#   zone-manager.sh generate_master_endpoint /opt/zones.d/master_zones.conf master master-0 master-0.icinga2-headless.ns.svc.cluster.local
#   zone-manager.sh generate_satellite_endpoint /opt/zones.d/master/zone-satellite-0.conf.shared zone-satellite-0 satellite-0 master
#   zone-manager.sh remove_endpoint /opt/zones.d/master_zones.conf master master-0
#
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ---------------------------------------------------------------------------
# Low-level zones.conf editing primitives
# ---------------------------------------------------------------------------

# Insert a line just before the closing brace of "object Zone <zone> { ... }"
insert_into_zone_block() {
  local file="$1" zone="$2" line_to_insert="$3"
  awk -v zone="$zone" -v newline="$line_to_insert" '
      BEGIN { in_zone = 0; depth = 0 }
      {
        if (!in_zone && $0 ~ ("object[ \t]+Zone[ \t]+\"" zone "\"")) {
          in_zone = 1
          depth = 0
        }
        if (in_zone) {
          line = $0
          n_open  = gsub(/\{/, "{", line)
          n_close = gsub(/\}/, "}", line)
          depth += n_open
          depth -= n_close
          if (depth == 0 && n_close > 0) {
            sub(/}/, newline "\n}")
            print
            in_zone = 0
            next
          }
        }
        print
      }
  ' "$file"
}

# Print the body of "object Zone <zone> { ... }"
extract_zone_block() {
  local file="$1" zone="$2"
  awk -v zone="$zone" '
      BEGIN { in_zone = 0; depth = 0 }
      {
        if (!in_zone && $0 ~ ("object[ \t]+Zone[ \t]+\"" zone "\"")) {
          in_zone = 1
          depth = 0
        }
        if (in_zone) {
          print
          line = $0
          n_open  = gsub(/\{/, "{", line)
          n_close = gsub(/\}/, "}", line)
          depth += n_open
          depth -= n_close
          if (depth == 0 && n_close > 0) {
            in_zone = 0
          }
        }
      }
  ' "$file"
}

# --- Remove the "object Endpoint <name> { ... }" block entirely ---
remove_endpoint_object() {
  local file="$1" name="$2"
  awk -v name="$name" '
      BEGIN { skip = 0; depth = 0 }
      {
        if (!skip && $0 ~ ("object[ \t]+Endpoint[ \t]+\"" name "\"")) {
          skip = 1
          depth = 0
        }
        if (skip) {
          line = $0
          n_open  = gsub(/\{/, "{", line)
          n_close = gsub(/\}/, "}", line)
          depth += n_open
          depth -= n_close
          if (depth == 0 && n_close > 0) {
            skip = 0
          }
          next
        }
        print
      }
  ' "$file"
}

# Remove endpoint <name> from a "object Zone <zone> { ... }" endpoints list,
# whether it was added inline (endpoints = [ "a", "b" ]) or appended on its
# own line (endpoints += [ "name" ])
remove_endpoint_from_zone() {
  local file="$1" zone="$2" name="$3"
  awk -v zone="$zone" -v name="$name" '
      BEGIN { in_zone = 0; depth = 0 }
      {
        if (!in_zone && $0 ~ ("object[ \t]+Zone[ \t]+\"" zone "\"")) {
          in_zone = 1
          depth = 0
        }
        if (in_zone) {
          line = $0
          n_open  = gsub(/\{/, "{", line)
          n_close = gsub(/\}/, "}", line)
          depth += n_open
          depth -= n_close
          if ($0 ~ ("endpoints[ \t]*\\+=.*\"" name "\"")) {
            if (depth == 0 && n_close > 0) { in_zone = 0 }
            next
          }
          if ($0 ~ "endpoints[ \t]*[+]?=") {
            gsub("\"" name "\"[ \t]*,?[ \t]*", "", $0)
            gsub(",[ \t]*]", " ]", $0)
          }
          if (depth == 0 && n_close > 0) {
            in_zone = 0
          }
        }
        print
      }
  ' "$file"
}

# Ensure exactly one blank line follows every top-level "object ... { ... }"
# block (including the last one in the file), collapsing any extra blank
# lines already present.
ensure_blank_lines_between_objects() {
  local file="$1"
  awk '
      BEGIN { depth = 0 }
      {
        print
        line = $0
        n_open  = gsub(/\{/, "{", line)
        n_close = gsub(/\}/, "}", line)
        depth += n_open
        depth -= n_close
        if (depth == 0 && n_close > 0) {
          print ""
        }
      }
  ' "$file" | awk '
      BEGIN { blank = 0 }
      {
        if ($0 == "") {
          blank++
          if (blank > 1) next
        } else {
          blank = 0
        }
        print
      }
  '
}

endpoint_object_exists() {
  local file="$1" name="$2"
  grep -qE "object[ \t]+Endpoint[ \t]+\"${name}\"" "$file"
}

zone_block_exists() {
  local file="$1" zone="$2"
  grep -qE "object[ \t]+Zone[ \t]+\"${zone}\"" "$file"
}

endpoint_in_zone() {
  local file="$1" zone="$2" name="$3"
  extract_zone_block "$file" "$zone" | grep -qF "\"${name}\""
}

# ---------------------------------------------------------------------------
# High-level operations
# ---------------------------------------------------------------------------

# generate_master_endpoint <conf_file> <zone> <name> <host> [port=5665]
#
# Ensures <conf_file> declares an Endpoint <name> pointing at <host> and that
# it is a member of Zone <zone>. Creates the file (with the global-templates /
# director-global zones) if it doesn't exist yet.
generate_master_endpoint() {
  local conf_file="$1" zone="$2" name="$3" host="$4" port="${5:-5665}"
  local tmp_file

  if [[ ! -f "$conf_file" ]]; then
    log "${conf_file} not found, creating it and initializing endpoints"
    cat > "$conf_file" <<EOF
object Endpoint "${name}" {
  host = "${host}"
  port = ${port}
}

object Zone "${zone}" {
  endpoints = [ "${name}" ]
}

object Zone "global-templates" {
  global = true
}

object Zone "director-global" {
  global = true
}
EOF
  else
    if ! endpoint_object_exists "$conf_file" "$name"; then
      log "${conf_file} exists, but endpoint ${name} not found, adding it"
      cat >> "$conf_file" <<EOF

object Endpoint "${name}" {
  host = "${host}"
  port = ${port}
}
EOF
    fi

    if ! zone_block_exists "$conf_file" "$zone"; then
      log "${conf_file} exists, but zone ${zone} not found, adding it with endpoint ${name}"
      cat >> "$conf_file" <<EOF

object Zone "${zone}" {
  endpoints = [ "${name}" ]
}
EOF
    elif ! endpoint_in_zone "$conf_file" "$zone" "$name"; then
      log "${conf_file} exists, but endpoint ${name} not found in zone ${zone}, adding it"
      tmp_file="$(mktemp)"
      insert_into_zone_block "$conf_file" "$zone" "  endpoints += [ \"${name}\" ]" > "$tmp_file"
      mv "$tmp_file" "$conf_file"
    fi
  fi

  tmp_file="$(mktemp)"
  ensure_blank_lines_between_objects "$conf_file" > "$tmp_file" && mv "$tmp_file" "$conf_file"
  chmod 644 "$conf_file"
  log "Done. ${conf_file} is up to date for zone ${zone} / endpoint ${name}."
}

# generate_satellite_endpoint <conf_file> <zone> <name> <parent_zone> [port=5665]
#
# Ensures <conf_file> declares an Endpoint <name> (host = <host>, resolved via
# the satellite headless service) and that it is a member of Zone <zone>,
# parented to <parent_zone>. Creates the file if it doesn't exist yet.
generate_satellite_endpoint() {
  local conf_file="$1" zone="$2" name="$3" host="$4" parent_zone="$5" port="${6:-5665}"
  local tmp_file

  if [[ ! -f "$conf_file" ]]; then
    log "${conf_file} not found, creating it and initializing endpoints"
    cat > "$conf_file" <<EOF
object Endpoint "${name}" {
  host = "${host}"
  port = ${port}
}

object Zone "${zone}" {
  endpoints = [ "${name}" ]
  parent = "${parent_zone}"
}
EOF
  else
    if ! endpoint_object_exists "$conf_file" "$name"; then
      log "${conf_file} exists, but endpoint ${name} not found, adding it"
      cat >> "$conf_file" <<EOF

object Endpoint "${name}" {
  host = "${host}"
  port = ${port}
}
EOF
    fi

    if ! endpoint_in_zone "$conf_file" "$zone" "$name"; then
      log "${conf_file} exists, but endpoint ${name} not found in zone ${zone}, adding it"
      tmp_file="$(mktemp)"
      insert_into_zone_block "$conf_file" "$zone" "  endpoints += [ \"${name}\" ]" > "$tmp_file"
      mv "$tmp_file" "$conf_file"
    fi
  fi

  tmp_file="$(mktemp)"
  ensure_blank_lines_between_objects "$conf_file" > "$tmp_file" && mv "$tmp_file" "$conf_file"
  chmod 644 "$conf_file"
  log "Done. ${conf_file} is up to date for zone ${zone} / endpoint ${name}."
}

# Print <file> without every top-level "object <type> "<name>" { ... }" block
# whose name matches the regex <name_re> (whole name, without the quotes).
remove_objects_matching() {
  local file="$1" type="$2" name_re="$3"
  awk -v type="$type" -v name_re="$name_re" '
      BEGIN { skip = 0; depth = 0 }
      {
        if (!skip && depth == 0 && $0 ~ ("^[ \t]*object[ \t]+" type "[ \t]+\"" name_re "\"")) {
          skip = 1
        }
        line = $0
        n_open  = gsub(/\{/, "{", line)
        n_close = gsub(/\}/, "}", line)
        depth += n_open - n_close
        if (skip) {
          if (depth == 0 && n_close > 0) { skip = 0 }
          next
        }
        print
      }
  ' "$file"
}

# generate_master_zones <conf_file> <zone> <name_prefix> <replicas> <domain> [port=5665]
#
# Writes Endpoint <name_prefix>-0 .. <name_prefix>-<replicas-1> (host
# <name>.<domain>), Zone <zone> listing all of them, and the global-templates /
# director-global zones, always with the same content and order. Any other
# object already in <conf_file> is kept after them. The file is only replaced
# when that content differs (it is shared through Syncthing).
#
# Every master writes the same file whichever pod starts first, and no pod
# removes its own Endpoint when it stops: the Endpoint of a pod that is down
# stays declared, so its master/<pod>.conf host (command_endpoint) still
# validates, and a master that starts already knows its peer.
generate_master_zones() {
  local conf_file="$1" zone="$2" prefix="$3" replicas="$4" domain="$5" port="${6:-5665}"
  local work new_file i z members=""

  if [[ ! "$replicas" =~ ^[1-9][0-9]*$ ]]; then
    log "ERROR: invalid replica count '${replicas}'"
    return 1
  fi
  work="$(mktemp -d)"
  if [[ -f "$conf_file" ]]; then
    remove_objects_matching "$conf_file" Endpoint "${prefix}-[0-9]+" > "$work/rest"
    for z in "$zone" global-templates director-global; do
      remove_objects_matching "$work/rest" Zone "$z" > "$work/rest.1"
      mv "$work/rest.1" "$work/rest"
    done
  else
    : > "$work/rest"
  fi

  for ((i = 0; i < replicas; i++)); do
    members+="${members:+, }\"${prefix}-${i}\""
  done
  {
    printf 'object Zone "%s" {\n  endpoints = [ %s ]\n}\n\n' "$zone" "$members"
    for ((i = 0; i < replicas; i++)); do
      printf 'object Endpoint "%s-%d" {\n  host = "%s-%d.%s"\n  port = %s\n}\n\n' \
        "$prefix" "$i" "$prefix" "$i" "$domain" "$port"
    done
    printf 'object Zone "global-templates" {\n  global = true\n}\n\n'
    printf 'object Zone "director-global" {\n  global = true\n}\n\n'
    cat "$work/rest"
  } > "$work/raw"
  ensure_blank_lines_between_objects "$work/raw" > "$work/new"

  if [[ -f "$conf_file" ]] && cmp -s "$work/new" "$conf_file"; then
    log "${conf_file} already lists ${prefix}-0..$((replicas - 1)) in zone ${zone}"
  else
    # rename inside the target directory: Syncthing never sees a half-written file
    new_file="$(mktemp "$(dirname "$conf_file")/.master_zones.XXXXXX")"
    cat "$work/new" > "$new_file"
    chmod 644 "$new_file"
    mv -f "$new_file" "$conf_file"
    log "${conf_file} written: zone ${zone} = ${prefix}-0..$((replicas - 1))"
  fi
  rm -rf "$work"
}

# remove_endpoint <conf_file> <zone> <name>
#
# Used by the satellite zone watcher: removes the Endpoint object and its membership in the
# given Zone's endpoints list. No-op if the file doesn't exist.
remove_endpoint() {
  local conf_file="$1" zone="$2" name="$3"

  if [[ ! -f "$conf_file" ]]; then
    log "${conf_file} not found, nothing to clean up"
    return
  fi

  log "Removing Endpoint \"${name}\" and its membership in zone \"${zone}\" from ${conf_file}"
  local tmp_file
  tmp_file="$(mktemp)"
  remove_endpoint_object "$conf_file" "$name" > "$tmp_file" && mv "$tmp_file" "$conf_file"
  tmp_file="$(mktemp)"
  remove_endpoint_from_zone "$conf_file" "$zone" "$name" > "$tmp_file" && mv "$tmp_file" "$conf_file"
  tmp_file="$(mktemp)"
  ensure_blank_lines_between_objects "$conf_file" > "$tmp_file" && mv "$tmp_file" "$conf_file"
  chmod 644 "$conf_file"
  log "Done. ${name} removed from ${conf_file}."
}

# ---------------------------------------------------------------------------
# Dispatch: `zone-manager.sh <function> [args...]`
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <function> [args...]" >&2
  echo "Functions: generate_master_zones, generate_master_endpoint, generate_satellite_endpoint, remove_endpoint" >&2
  exit 1
fi

"$@"