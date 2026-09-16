package hypervisor

import (
	"regexp"
	"strings"
)

var openStackExternalIDRe = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// IsOpenStackExternalID reports Nova server UUIDs (VirtFusion uses numeric ids).
func IsOpenStackExternalID(externalID string) bool {
	return openStackExternalIDRe.MatchString(strings.TrimSpace(externalID))
}
// IsVirtFusionQueueFailed reports immediate VF queue job failure (reset password, build, etc.).
func IsVirtFusionQueueFailed(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "virtfusion: queue") && strings.Contains(msg, "failed")
}

// IsIPPoolExhausted reports VirtFusion has no free IPv4 in the pool (transient — retry/waitlist).
func IsIPPoolExhausted(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "not enough addresses") ||
		strings.Contains(msg, "no free ipv4") ||
		strings.Contains(msg, "no free ip")
}

// IsPasswordChangeUnsupported reports Nova changePassword is unavailable (common on Sunbeam).
func IsPasswordChangeUnsupported(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "change admin password") && strings.Contains(msg, "501") ||
		strings.Contains(msg, "change password") && strings.Contains(msg, "not supported")
}

// IsTransientTemplateError reports VF template faults that can clear after cache/init.
func IsTransientTemplateError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "invalid template id") ||
		strings.Contains(msg, "being initialized")
}

// IsPermanentProvisionError reports VirtFusion / config faults that will not heal on retry.
func IsPermanentProvisionError(err error) bool {
	if err == nil {
		return false
	}
	if IsIPPoolExhausted(err) || IsTransientTemplateError(err) {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "invalid package") ||
		strings.Contains(msg, "invalid template") ||
		strings.Contains(msg, "no package mapping") ||
		strings.Contains(msg, "invalid hypervisor") ||
		strings.Contains(msg, `"422"`) ||
		strings.Contains(msg, "http 422")
}