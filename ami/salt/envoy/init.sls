# Install Envoy and stage its bootstrap config.
# Derived from cetanu/envoy-formula structure (see attribution in
# ami/salt/envoy/README.md).

envoy_packages:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - gnupg
      - lsb-release
      - tini

envoy_repo_key:
  file.managed:
    - name: /usr/share/keyrings/getenvoy.gpg
    - source: salt://envoy/files/getenvoy.gpg
    - mode: '0644'
    - skip_verify: True
    - replace: False
    - makedirs: True
    - onlyif: test -f /srv/salt/envoy/files/getenvoy.gpg

envoy_binary:
  cmd.run:
    - name: |
        set -eux
        ENVOY_VERSION="${ENVOY_VERSION:-v1.34.1}"
        ARCH="$(dpkg --print-architecture)"
        case "$ARCH" in
          amd64) FUNC_E_ARCH=x86_64 ;;
          arm64) FUNC_E_ARCH=aarch64 ;;
          *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
        esac
        # Fetch a precompiled Envoy binary. In an air-gapped build, replace
        # this URL with the internal mirror.
        curl -fsSL "https://archive.tetratelabs.io/envoy/download/${ENVOY_VERSION}/envoy-${ENVOY_VERSION}-linux-${FUNC_E_ARCH}.tar.xz" -o /tmp/envoy.tar.xz \
          || curl -fsSL "https://github.com/envoyproxy/envoy/releases/download/${ENVOY_VERSION}/envoy-${ENVOY_VERSION#v}-linux-${FUNC_E_ARCH}" -o /tmp/envoy
        if [ -f /tmp/envoy.tar.xz ]; then
          tar -xJf /tmp/envoy.tar.xz -C /tmp
          install -m 0755 "$(find /tmp -maxdepth 3 -type f -name envoy | head -n1)" /usr/local/bin/envoy
        else
          install -m 0755 /tmp/envoy /usr/local/bin/envoy
        fi
        /usr/local/bin/envoy --version
    - creates: /usr/local/bin/envoy

envoy_user:
  group.present:
    - name: envoy
    - system: True
  user.present:
    - name: envoy
    - system: True
    - groups: [envoy]
    - shell: /usr/sbin/nologin
    - createhome: False

envoy_directories:
  file.directory:
    - names:
      - /etc/envoy
      - /etc/envoy/tls
      - /var/log/envoy
      - /var/lib/envoy
    - user: envoy
    - group: envoy
    - mode: '0750'
    - makedirs: True

envoy_bootstrap_template:
  file.managed:
    - name: /etc/envoy/bootstrap.yaml.tmpl
    - source: salt://envoy/files/bootstrap.yaml.tmpl
    - user: root
    - group: envoy
    - mode: '0640'

envoy_entrypoint:
  file.managed:
    - name: /usr/local/bin/envoy-entrypoint.sh
    - source: salt://envoy/files/envoy-entrypoint.sh
    - mode: '0755'

envoy_systemd_unit:
  file.managed:
    - name: /etc/systemd/system/envoy.service
    - source: salt://envoy/files/envoy.service
    - mode: '0644'
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: envoy_systemd_unit
