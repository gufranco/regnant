#!/usr/bin/env bash
# Pin all network interrupts to CPU 0 so that the remaining cores can
# serve Envoy without context-switching to interrupt handlers. Run by
# the cpufreq-performance.service unit on boot.

set -euo pipefail

for irq_dir in /proc/irq/[0-9]*; do
  if grep -qiE '(eth|en[ospx][0-9]+|virtio)' "$irq_dir"/../irq/*/affinity_hint 2>/dev/null; then
    irq=$(basename "$irq_dir")
    echo 1 > "/proc/irq/${irq}/smp_affinity" 2>/dev/null || true
  fi
done

# Disable the NMI watchdog at runtime so soft-lockup checks do not
# preempt Envoy worker threads.
sysctl -w kernel.nmi_watchdog=0 >/dev/null 2>&1 || true

# Push CPU governor to performance everywhere.
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  gov="$cpu/cpufreq/scaling_governor"
  if [ -w "$gov" ]; then
    echo performance > "$gov" 2>/dev/null || true
  fi
done
