package hvinit

import (
	"log"
	"os"
	"strings"

	"github.com/borishru-boop/testVPStrade/services/vps/internal/hypervisor"
	"github.com/borishru-boop/testVPStrade/services/vps/internal/virtfusion"
)

func NewAdapter() hypervisor.Adapter {
	if hypervisor.MockEnabled() {
		return hypervisor.NewMock()
	}
	baseURL := strings.TrimSpace(os.Getenv("VIRTFUSION_API_URL"))
	var vf hypervisor.Adapter
	if baseURL != "" {
		vf = virtfusion.NewHTTP(baseURL, os.Getenv("VIRTFUSION_API_KEY"), hypervisor.LoadConfig())
	} else {
		vf = hypervisor.NewMock()
	}
	osAdapter := openstackAdapter()
	if osAdapter == nil {
		return vf
	}
	router, err := newRegionRouter(vf, osAdapter)
	if err != nil {
		log.Printf("hvinit: openstack router disabled: %v", err)
		return vf
	}
	log.Printf("hvinit: hybrid virtfusion + openstack (regions=%s)", os.Getenv("OPENSTACK_PROVISION_REGIONS"))
	return router
}

func NewNodeSync() hypervisor.NodeSyncSource {
	if hypervisor.MockEnabled() {
		return hypervisor.NewMock()
	}
	baseURL := strings.TrimSpace(os.Getenv("VIRTFUSION_API_URL"))
	if baseURL != "" {
		return virtfusion.NewHTTP(baseURL, os.Getenv("VIRTFUSION_API_KEY"), hypervisor.LoadConfig())
	}
	return hypervisor.NewMock()
}

func NewOSSync() hypervisor.OSSyncSource {
	if hypervisor.MockEnabled() {
		return hypervisor.NewMock()
	}
	baseURL := strings.TrimSpace(os.Getenv("VIRTFUSION_API_URL"))
	if baseURL != "" {
		return virtfusion.NewHTTP(baseURL, os.Getenv("VIRTFUSION_API_KEY"), hypervisor.LoadConfig())
	}
	return hypervisor.NewMock()
}
