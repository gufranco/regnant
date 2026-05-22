# Container runtime baseline. containerd + runc + crun, with a default
# seccomp profile and a baseline AppArmor profile. Envoy itself is
# installed as a native binary, but every adjacent workload (the OTel
# agent's exporters that need a sidecar, the auth sidecar in real AWS
# deployments) runs containerized via containerd + crun.

container_runtime_packages:
  pkg.installed:
    - pkgs:
      - containerd
      - runc
      - crun
      - skopeo
      - buildah
      - umoci

containerd_config:
  file.managed:
    - name: /etc/containerd/config.toml
    - source: salt://containers/files/containerd_config.toml
    - mode: '0644'
    - makedirs: True

containerd_service:
  service.running:
    - name: containerd
    - enable: True
    - watch:
      - file: containerd_config

seccomp_default:
  file.managed:
    - name: /etc/regnant/seccomp-default.json
    - source: salt://containers/files/seccomp-default.json
    - mode: '0644'
    - makedirs: True

apparmor_container_default:
  file.managed:
    - name: /etc/apparmor.d/regnant-container-default
    - source: salt://containers/files/apparmor_container_default
    - mode: '0644'
