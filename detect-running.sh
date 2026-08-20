#!/usr/bin/env bash
#
# Detecta instancias de Prism Launcher corriendo actualmente.
# Salida: JSON array [{ "instanceId": "...", "pid": N, "startEpoch": N }, ...]
#
# Uso: detect-running.sh [PRISM_INSTANCES_DIR]
# Default de PRISM_INSTANCES_DIR: ~/.local/share/PrismLauncher/instances

set -euo pipefail

INSTANCES_DIR="${1:-$HOME/.local/share/PrismLauncher/instances}"

# Boot time del sistema, para convertir "clock ticks desde el boot" a epoch real.
# /proc/uptime campo 1 = segundos desde el boot (float)
BOOT_EPOCH=$(awk '{printf "%d", systime() - $1}' /proc/uptime)
CLK_TCK=$(getconf CLK_TCK)  # normalmente 100

results=()

for pid in $(pgrep -x java 2>/dev/null || true); do
  # Todo acceso a /proc/$pid/* puede fallar si el proceso murió entre el pgrep
  # y esta lectura (condición de carrera) -> lo toleramos con '|| continue'.

  cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue

  instance_id=""

  # Método 1: CWD -> .../instances/<id>/minecraft
  if [[ "$cwd" == "$INSTANCES_DIR"/*/minecraft ]]; then
    rel="${cwd#"$INSTANCES_DIR"/}"      # "<id>/minecraft"
    instance_id="${rel%/minecraft}"
  fi

  # Método 2 (confirmación cruzada): cmdline -> .../instances/<id>/natives
  if [[ -z "$instance_id" ]] && [[ "$cmdline" == *"$INSTANCES_DIR"/*"/natives"* ]]; then
    tmp="${cmdline#*"$INSTANCES_DIR"/}"
    instance_id="${tmp%%/natives*}"
    instance_id="${instance_id%% *}"    # por si quedó basura pegada
  fi

  [[ -z "$instance_id" ]] && continue

  # startEpoch real del proceso: campo 22 de /proc/$pid/stat = starttime en clock ticks desde el boot
  stat_line=$(cat "/proc/$pid/stat" 2>/dev/null) || continue
  # El comm (campo 2) puede tener espacios/paréntesis, así que parseamos desde el ')' final
  after_comm="${stat_line#*) }"
  read -ra fields <<< "$after_comm"
  starttime_ticks="${fields[19]}"  # campo 22 global = índice 19 después del comm (campo 3 en adelante = índice 0)

  if [[ -z "$starttime_ticks" ]]; then
    continue
  fi

  start_epoch=$(( BOOT_EPOCH + starttime_ticks / CLK_TCK ))

  results+=("{\"instanceId\":\"$instance_id\",\"pid\":$pid,\"startEpoch\":$start_epoch}")
done

if [[ ${#results[@]} -eq 0 ]]; then
  echo "[]"
else
  IFS=,; echo "[${results[*]}]"
fi
