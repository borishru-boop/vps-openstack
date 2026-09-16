package openstack

import (
	"bytes"
	"strings"
)

func buildCloudInitUserData(rootPassword string, sshKeys []string) []byte {
	rootPassword = strings.TrimSpace(rootPassword)
	var keys []string
	for _, k := range sshKeys {
		k = strings.TrimSpace(k)
		if k != "" {
			keys = append(keys, k)
		}
	}
	if rootPassword == "" && len(keys) == 0 {
		return nil
	}

	var b bytes.Buffer
	b.WriteString("#cloud-config\n")
	if rootPassword != "" {
		b.WriteString("packages:\n")
		b.WriteString("  - openssh-server\n")
		b.WriteString("chpasswd:\n")
		b.WriteString("  expire: false\n")
		b.WriteString("  list: |\n")
		b.WriteString("    root:" + rootPassword + "\n")
		b.WriteString("    ubuntu:" + rootPassword + "\n")
		b.WriteString("ssh_pwauth: true\n")
		b.WriteString("disable_root: false\n")
		b.WriteString("runcmd:\n")
		b.WriteString("  - [ sh, -c, \"sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true\" ]\n")
	}
	if len(keys) > 0 {
		b.WriteString("ssh_authorized_keys:\n")
		for _, k := range keys {
			b.WriteString("  - ")
			b.WriteString(k)
			b.WriteByte('\n')
		}
	}
	return b.Bytes()
}
