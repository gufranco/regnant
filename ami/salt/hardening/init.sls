# Host hardening. Aligned with the CIS Debian 12 benchmark plus the
# subset that actually matters for the Envoy edge box: SSH baseline,
# auditd ruleset, fail2ban, AppArmor on the envoy binary, kernel
# lockdown directives.

hardening_packages:
  pkg.installed:
    - pkgs:
      - openssh-server
      - auditd
      - audispd-plugins
      - fail2ban
      - apparmor
      - apparmor-utils
      - apparmor-profiles
      - libpam-pwquality

sshd_config:
  file.managed:
    - name: /etc/ssh/sshd_config.d/99-regnant.conf
    - source: salt://hardening/files/sshd_99-regnant.conf
    - mode: '0600'
    - makedirs: True

auditd_rules:
  file.managed:
    - name: /etc/audit/rules.d/99-regnant.rules
    - source: salt://hardening/files/audit_99-regnant.rules
    - mode: '0640'
    - makedirs: True
  cmd.run:
    - name: augenrules --load || true
    - onchanges:
      - file: auditd_rules

fail2ban_jail:
  file.managed:
    - name: /etc/fail2ban/jail.d/regnant.conf
    - source: salt://hardening/files/fail2ban_regnant.conf
    - mode: '0644'
    - makedirs: True

apparmor_envoy_profile:
  file.managed:
    - name: /etc/apparmor.d/usr.local.bin.envoy
    - source: salt://hardening/files/apparmor_envoy
    - mode: '0644'

kernel_lockdown_sysctl:
  file.managed:
    - name: /etc/sysctl.d/99-regnant-lockdown.conf
    - source: salt://hardening/files/sysctl_lockdown.conf
    - mode: '0644'
    - makedirs: True

pam_pwquality:
  file.managed:
    - name: /etc/security/pwquality.conf.d/99-regnant.conf
    - source: salt://hardening/files/pwquality_99-regnant.conf
    - mode: '0644'
    - makedirs: True

disable_root_login:
  file.line:
    - name: /etc/passwd
    - mode: replace
    - match: '^root:.*'
    - content: 'root:x:0:0:root:/root:/usr/sbin/nologin'
