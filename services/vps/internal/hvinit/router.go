package hvinit

import (
	"context"
	"fmt"

	"github.com/borishru-boop/testVPStrade/services/vps/internal/hypervisor"
	"github.com/borishru-boop/testVPStrade/services/vps/internal/openstack"
)

type regionRouter struct {
	vf hypervisor.Adapter
	os hypervisor.Adapter
}

func (r *regionRouter) byRegion(region string) hypervisor.Adapter {
	if hypervisor.RegionUsesOpenStack(region) {
		if r.os != nil {
			return r.os
		}
	}
	return r.vf
}

func (r *regionRouter) byServerID(id string) hypervisor.Adapter {
	if hypervisor.LooksLikeOpenStackServerID(id) && r.os != nil {
		return r.os
	}
	return r.vf
}

func (r *regionRouter) AllocateServer(ctx context.Context, opts hypervisor.CreateOptions) (*hypervisor.Server, error) {
	return r.byRegion(opts.Region).AllocateServer(ctx, opts)
}

func (r *regionRouter) BuildServer(ctx context.Context, serverID string, opts hypervisor.CreateOptions) error {
	return r.byRegion(opts.Region).BuildServer(ctx, serverID, opts)
}

func (r *regionRouter) CreateServer(ctx context.Context, opts hypervisor.CreateOptions) (*hypervisor.Server, error) {
	return r.byRegion(opts.Region).CreateServer(ctx, opts)
}

func (r *regionRouter) GetServer(ctx context.Context, id string) (*hypervisor.Server, error) {
	return r.byServerID(id).GetServer(ctx, id)
}

func (r *regionRouter) StartServer(ctx context.Context, id string) error {
	return r.byServerID(id).StartServer(ctx, id)
}

func (r *regionRouter) StopServer(ctx context.Context, id string) error {
	return r.byServerID(id).StopServer(ctx, id)
}

func (r *regionRouter) PowerOffServer(ctx context.Context, id string) error {
	return r.byServerID(id).PowerOffServer(ctx, id)
}

func (r *regionRouter) SuspendServer(ctx context.Context, id string) error {
	return r.byServerID(id).SuspendServer(ctx, id)
}

func (r *regionRouter) UnsuspendServer(ctx context.Context, id string) error {
	return r.byServerID(id).UnsuspendServer(ctx, id)
}

func (r *regionRouter) RebootServer(ctx context.Context, id string) error {
	return r.byServerID(id).RebootServer(ctx, id)
}

func (r *regionRouter) DeleteServer(ctx context.Context, id string) error {
	return r.byServerID(id).DeleteServer(ctx, id)
}

func (r *regionRouter) ResizeServer(ctx context.Context, id string, packageID int, preserveDisk bool) error {
	return r.byServerID(id).ResizeServer(ctx, id, packageID, preserveDisk)
}

func (r *regionRouter) SyncServerPlan(ctx context.Context, serverID, catalogPlanID string) error {
	return r.byServerID(serverID).SyncServerPlan(ctx, serverID, catalogPlanID)
}

func (r *regionRouter) AddPrimaryIPv4(ctx context.Context, serverID string) (string, error) {
	return r.byServerID(serverID).AddPrimaryIPv4(ctx, serverID)
}

func (r *regionRouter) AddExtraIPv4(ctx context.Context, serverID string, qty int) ([]string, error) {
	return r.byServerID(serverID).AddExtraIPv4(ctx, serverID, qty)
}

func (r *regionRouter) RemovePrimaryIPv4(ctx context.Context, serverID, ip string) error {
	return r.byServerID(serverID).RemovePrimaryIPv4(ctx, serverID, ip)
}

func (r *regionRouter) SyncServerNetworkFilters(ctx context.Context, serverID string) error {
	return r.byServerID(serverID).SyncServerNetworkFilters(ctx, serverID)
}

func (r *regionRouter) PrimaryIPv4Info(ctx context.Context, serverID string) ([]string, string, string, error) {
	return r.byServerID(serverID).PrimaryIPv4Info(ctx, serverID)
}

func (r *regionRouter) HasFreePrimaryIPv4(ctx context.Context, region, hypervisorID string) (bool, error) {
	return r.byRegion(region).HasFreePrimaryIPv4(ctx, region, hypervisorID)
}

func (r *regionRouter) EnsureServerOS(ctx context.Context, serverID, catalogOSTemplateID, rootPassword string, sshKeys []string) (bool, error) {
	return r.byServerID(serverID).EnsureServerOS(ctx, serverID, catalogOSTemplateID, rootPassword, sshKeys)
}

func (r *regionRouter) ReinstallServer(ctx context.Context, id, planID, osTemplateID, rootPassword string, sshKeys []string) error {
	return r.byServerID(id).ReinstallServer(ctx, id, planID, osTemplateID, rootPassword, sshKeys)
}

func (r *regionRouter) ResetRootPassword(ctx context.Context, id, osTemplateID string) (string, error) {
	return r.byServerID(id).ResetRootPassword(ctx, id, osTemplateID)
}

func (r *regionRouter) SetRootPassword(ctx context.Context, id, password string) error {
	return r.byServerID(id).SetRootPassword(ctx, id, password)
}

func (r *regionRouter) GetConsole(ctx context.Context, id string) (*hypervisor.ConsoleSession, error) {
	return r.byServerID(id).GetConsole(ctx, id)
}

func (r *regionRouter) GetMetrics(ctx context.Context, id string) (*hypervisor.Metrics, error) {
	return r.byServerID(id).GetMetrics(ctx, id)
}

func (r *regionRouter) CreateSnapshot(ctx context.Context, id, name string) (*hypervisor.Snapshot, error) {
	return r.byServerID(id).CreateSnapshot(ctx, id, name)
}

func (r *regionRouter) DeleteSnapshot(ctx context.Context, id, snapshotID string) error {
	return r.byServerID(id).DeleteSnapshot(ctx, id, snapshotID)
}

func newRegionRouter(vf, os hypervisor.Adapter) (*regionRouter, error) {
	if vf == nil {
		return nil, fmt.Errorf("virtfusion adapter required for hybrid routing")
	}
	return &regionRouter{vf: vf, os: os}, nil
}

func openstackAdapter() hypervisor.Adapter {
	if !hypervisor.OpenStackConfigured() {
		return nil
	}
	return openstack.NewAdapter(openstack.LoadConfig())
}
