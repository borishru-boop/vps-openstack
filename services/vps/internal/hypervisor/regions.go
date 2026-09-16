package hypervisor

import (
	"os"
	"strings"
)

// OpenStackConfigured reports whether OpenStack auth URL is set.
func OpenStackConfigured() bool {
	return strings.TrimSpace(os.Getenv("OPENSTACK_AUTH_URL")) != "" ||
		strings.TrimSpace(os.Getenv("OS_AUTH_URL")) != ""
}

func openstackProvisionRegions() map[string]struct{} {
	return parseRegionSet(os.Getenv("OPENSTACK_PROVISION_REGIONS"))
}

// RegionUsesOpenStack is true when the region is listed in OPENSTACK_PROVISION_REGIONS and OS is configured.
func RegionUsesOpenStack(region string) bool {
	if !OpenStackConfigured() {
		return false
	}
	regions := openstackProvisionRegions()
	if len(regions) == 0 {
		return false
	}
	_, ok := regions[strings.ToLower(strings.TrimSpace(region))]
	return ok
}

// RegionEnabled is true when either VirtFusion or OpenStack accepts the region.
func RegionEnabled(region string) bool {
	if RegionUsesOpenStack(region) {
		return true
	}
	cfg := LoadConfig()
	if len(cfg.ProvisionRegions) == 0 {
		return !OpenStackConfigured()
	}
	_, ok := cfg.ProvisionRegions[strings.ToLower(strings.TrimSpace(region))]
	return ok
}

// InsecureTLS is true when either backend skips TLS verification.
func InsecureTLS() bool {
	if envBool("OPENSTACK_INSECURE_TLS", false) {
		return true
	}
	return LoadConfig().InsecureTLS
}

// LooksLikeOpenStackServerID heuristically detects Nova UUID external ids.
func LooksLikeOpenStackServerID(id string) bool {
	id = strings.TrimSpace(id)
	if len(id) != 36 {
		return false
	}
	parts := strings.Split(id, "-")
	return len(parts) == 5
}
