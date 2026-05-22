# Network and CPU tuning. Draws from the author's "Profit or Poverty"
# series on NUMA, real-time kernel, and TLB. References:
#   https://cetanu.github.io/blog/why-numa-is-important-in-trading/
#   https://cetanu.github.io/blog/linux-is-not-a-realtime-system/
#   https://cetanu.github.io/blog/translation-lookaside-buffer/

network_tuning_packages:
  pkg.installed:
    - pkgs:
      - numactl
      - util-linux
      - hwloc
      - ethtool
      - irqbalance
      - cpufrequtils

network_tuning_sysctl:
  file.managed:
    - name: /etc/sysctl.d/99-regnant-network.conf
    - source: salt://network/files/sysctl_network.conf
    - mode: '0644'
    - makedirs: True
  cmd.run:
    - name: sysctl -p /etc/sysctl.d/99-regnant-network.conf || true
    - onchanges:
      - file: network_tuning_sysctl

hugepages_config:
  file.managed:
    - name: /etc/sysctl.d/99-regnant-hugepages.conf
    - source: salt://network/files/sysctl_hugepages.conf
    - mode: '0644'
    - makedirs: True

numa_balancing_disable:
  file.managed:
    - name: /etc/sysctl.d/99-regnant-numa.conf
    - source: salt://network/files/sysctl_numa.conf
    - mode: '0644'
    - makedirs: True

irq_affinity_helper:
  file.managed:
    - name: /usr/local/sbin/regnant-irq-pin.sh
    - source: salt://network/files/irq-pin.sh
    - mode: '0755'

cpu_governor_performance:
  file.managed:
    - name: /etc/systemd/system/cpufreq-performance.service
    - source: salt://network/files/cpufreq-performance.service
    - mode: '0644'
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: cpu_governor_performance

grub_realtime_cmdline:
  file.managed:
    - name: /etc/default/grub.d/99-regnant.cfg
    - source: salt://network/files/grub_99-regnant.cfg
    - mode: '0644'
    - makedirs: True

ulimits_nofile:
  file.managed:
    - name: /etc/security/limits.d/99-regnant.conf
    - source: salt://network/files/limits_99-regnant.conf
    - mode: '0644'
    - makedirs: True
