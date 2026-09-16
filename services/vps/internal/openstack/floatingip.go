package openstack

import (
	"context"
	"fmt"
	"time"

	"github.com/gophercloud/gophercloud/openstack/compute/v2/servers"
	"github.com/gophercloud/gophercloud/openstack/networking/v2/ports"
)

func (a *Adapter) assignFloatingIP(ctx context.Context, serverID string) (string, error) {
	if a.cfg.FloatingNetworkID == "" {
		return "", nil
	}
	cli, err := a.clients(ctx)
	if err != nil {
		return "", err
	}
	if err := waitServerActive(cli, serverID); err != nil {
		return "", err
	}
	portID, err := a.serverPortIDWithRetry(cli, serverID, 30, 2*time.Second)
	if err != nil {
		return "", err
	}
	return a.createFloatingIPForPort(cli, portID)
}

// ensureServerFloatingIP assigns a public IPv4 when the pool is configured and none is attached yet.
func (a *Adapter) ensureServerFloatingIP(ctx context.Context, serverID string) (string, error) {
	if a.cfg.FloatingNetworkID == "" {
		return "", nil
	}
	cli, err := a.clients(ctx)
	if err != nil {
		return "", err
	}
	fips, err := a.listServerFloatingIPs(cli, serverID)
	if err != nil {
		return "", err
	}
	if len(fips) > 0 {
		return fips[0].Address, nil
	}
	return a.assignFloatingIP(ctx, serverID)
}

func (a *Adapter) serverPortID(cli *Clients, serverID string) (string, error) {
	page, err := ports.List(cli.Network, ports.ListOpts{DeviceID: serverID}).AllPages()
	if err != nil {
		return "", err
	}
	all, err := ports.ExtractPorts(page)
	if err != nil {
		return "", err
	}
	for _, p := range all {
		if p.ID != "" {
			return p.ID, nil
		}
	}
	return "", fmt.Errorf("openstack: no port for server %s", serverID)
}

func (a *Adapter) serverPortIDWithRetry(cli *Clients, serverID string, attempts int, delay time.Duration) (string, error) {
	if attempts < 1 {
		attempts = 1
	}
	var lastErr error
	for i := 0; i < attempts; i++ {
		portID, err := a.serverPortID(cli, serverID)
		if err == nil {
			return portID, nil
		}
		lastErr = err
		if i+1 < attempts {
			time.Sleep(delay)
		}
	}
	return "", lastErr
}

func waitServerActive(cli *Clients, serverID string) error {
	return servers.WaitForStatus(cli.Compute, serverID, "ACTIVE", 600)
}
