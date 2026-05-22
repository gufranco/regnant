# Observability agent: OpenTelemetry Collector + Vector for log
# forwarding + Node Exporter for host metrics.

otel_collector_user:
  group.present:
    - name: otel
    - system: True
  user.present:
    - name: otel
    - system: True
    - groups: [otel]
    - shell: /usr/sbin/nologin
    - createhome: False

otel_collector_binary:
  cmd.run:
    - name: |
        set -eux
        OTEL_VERSION="0.115.1"
        ARCH="$(dpkg --print-architecture)"
        case "$ARCH" in
          amd64) GO_ARCH=amd64 ;;
          arm64) GO_ARCH=arm64 ;;
          *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
        esac
        curl -fsSL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_${GO_ARCH}.deb" -o /tmp/otelcol.deb
        dpkg -i /tmp/otelcol.deb || apt-get install --yes --fix-broken
        rm -f /tmp/otelcol.deb
    - creates: /usr/bin/otelcol-contrib

otel_collector_config:
  file.managed:
    - name: /etc/otelcol-contrib/config.yaml
    - source: salt://observability/files/agent.yaml
    - mode: '0644'
    - makedirs: True

otel_collector_unit:
  file.managed:
    - name: /etc/systemd/system/otel-collector-agent.service
    - source: salt://observability/files/otel-collector-agent.service
    - mode: '0644'
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: otel_collector_unit

vector_install:
  cmd.run:
    - name: |
        set -eux
        curl -1sSf https://repositories.timber.io/public/vector/setup.deb.sh | bash
        apt-get install --yes vector
    - creates: /usr/bin/vector

vector_config:
  file.managed:
    - name: /etc/vector/vector.yaml
    - source: salt://observability/files/vector.yaml
    - mode: '0644'
    - makedirs: True

node_exporter_install:
  cmd.run:
    - name: |
        set -eux
        NE_VERSION="1.8.2"
        ARCH="$(dpkg --print-architecture)"
        case "$ARCH" in
          amd64) GO_ARCH=amd64 ;;
          arm64) GO_ARCH=arm64 ;;
          *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
        esac
        curl -fsSL "https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/ne.tar.gz
        tar -xzf /tmp/ne.tar.gz -C /tmp
        install -m 0755 "/tmp/node_exporter-${NE_VERSION}.linux-${GO_ARCH}/node_exporter" /usr/local/bin/node_exporter
        rm -rf /tmp/ne.tar.gz /tmp/node_exporter-*
    - creates: /usr/local/bin/node_exporter
