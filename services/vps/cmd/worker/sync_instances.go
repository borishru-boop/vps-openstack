package main

import (
	"context"
	"log"
	"strconv"
	"strings"

	"github.com/borishru-boop/testVPStrade/services/vps/internal/hypervisor"
	"github.com/borishru-boop/testVPStrade/services/vps/internal/store"
)

func syncInstanceStates(ctx context.Context, st *store.Store, hv hypervisor.Adapter) error {
	if st == nil || hv == nil {
		return nil
	}
	items, err := st.ListInstancesForHypervisorSync(ctx, 30)
	if err != nil {
		return err
	}
	for _, item := range items {
		if item.State == "reinstalling" {
			syncReinstallingInstance(ctx, st, hv, item)
			continue
		}
		if !looksLikeHypervisorServerID(item.ExternalID) {
			log.Printf("instance sync: invalid external_id %s for %s", item.ExternalID, item.ID)
			if ok, err := st.MarkInstanceOrphaned(ctx, item.ID, "invalid virtfusion external_id"); err != nil {
				log.Printf("instance sync orphan %s: %v", item.ID, err)
			} else if ok {
				failVPSOrphanRefund(ctx, st, item.ID)
			}
			continue
		}
		server, err := hv.GetServer(ctx, item.ExternalID)
		if err != nil {
			if hypervisor.IsServerNotFound(err) {
				log.Printf("instance sync: virtfusion server missing for %s (vf=%s)", item.ID, item.ExternalID)
				missCount, incErr := st.IncrementInstanceSyncMiss(ctx, item.ID)
				if incErr != nil {
					log.Printf("instance sync miss count %s: %v", item.ID, incErr)
					continue
				}
				if missCount >= 3 {
					if ok, err := st.MarkInstanceOrphaned(ctx, item.ID, "virtfusion server missing"); err != nil {
						log.Printf("instance sync orphan %s: %v", item.ID, err)
					} else if ok {
						failVPSOrphanRefund(ctx, st, item.ID)
					}
				}
			}
			continue
		}
		_ = st.ClearInstanceSyncMiss(ctx, item.ID)
		// Portal state sync uses VF commission status only — MapServerPowerState treats
		// remoteState=false as powered off and must not downgrade active billing instances.
		state := hypervisor.MapServerState(server.Status)
		if store.ClientPowerBlocked(item.BillingStatus) && hypervisor.ServerPoweredOn(server) {
			if err := enforceBillingPowerOff(ctx, hv, item.ExternalID); err != nil {
				log.Printf("instance sync billing poweroff %s (vf=%s): %v", item.ID, item.ExternalID, err)
			} else if !billingPowerOffApplied(ctx, hv, item.ExternalID) {
				log.Printf("instance sync billing poweroff %s (vf=%s): guest still running after poweroff+suspend", item.ID, item.ExternalID)
			} else {
				log.Printf("instance sync billing poweroff %s (vf=%s)", item.ID, item.ExternalID)
				_ = st.MarkInstanceStopped(ctx, item.ID)
			}
			continue
		}
		if item.State == "error" || item.HasProvisionError {
			if item.HasProvisionError && item.State == "running" && server.IP != "" && hypervisor.ServerPoweredOn(server) {
				if err := st.ClearInstanceProvisionError(ctx, item.ID); err != nil {
					log.Printf("instance sync heal provision_error %s: %v", item.ID, err)
				} else {
					log.Printf("instance sync cleared stale provision_error %s", item.ID)
				}
			}
			continue
		}
		ip := server.IP
		if err := st.UpdateInstanceFromHypervisor(ctx, item.ID, state, ip); err != nil {
			log.Printf("instance sync apply %s: %v", item.ID, err)
		}
	}
	return nil
}

// syncReinstallingInstance keeps reinstall rows aligned with VirtFusion without
// touching portal power state. Missing VF servers are orphaned without refund;
// stale DB IPs are released when VF has no address yet.
func syncReinstallingInstance(ctx context.Context, st *store.Store, hv hypervisor.Adapter, item store.HypervisorInstanceRow) {
	if !looksLikeHypervisorServerID(item.ExternalID) {
		log.Printf("instance sync reinstall: invalid external_id %s for %s", item.ExternalID, item.ID)
		if ok, err := st.MarkInstanceOrphaned(ctx, item.ID, "invalid virtfusion external_id during reinstall"); err != nil {
			log.Printf("instance sync reinstall orphan %s: %v", item.ID, err)
		} else if ok {
			log.Printf("instance sync reinstall orphaned %s (invalid external_id)", item.ID)
		}
		return
	}
	server, err := hv.GetServer(ctx, item.ExternalID)
	if err != nil {
		if hypervisor.IsServerNotFound(err) {
			log.Printf("instance sync reinstall: virtfusion server missing for %s (vf=%s)", item.ID, item.ExternalID)
			missCount, incErr := st.IncrementInstanceSyncMiss(ctx, item.ID)
			if incErr != nil {
				log.Printf("instance sync reinstall miss count %s: %v", item.ID, incErr)
				return
			}
			if missCount >= 3 {
				if ok, err := st.MarkInstanceOrphaned(ctx, item.ID, "virtfusion server missing during reinstall"); err != nil {
					log.Printf("instance sync reinstall orphan %s: %v", item.ID, err)
				} else if ok {
					log.Printf("instance sync reinstall orphaned %s (vf missing)", item.ID)
				}
			}
		}
		return
	}
	_ = st.ClearInstanceSyncMiss(ctx, item.ID)
	if strings.TrimSpace(server.IP) == "" && item.IPAddress != nil && strings.TrimSpace(*item.IPAddress) != "" {
		if ok, err := st.ClearInstanceIPDuringReinstall(ctx, item.ID); err != nil {
			log.Printf("instance sync reinstall clear ip %s: %v", item.ID, err)
		} else if ok {
			log.Printf("instance sync reinstall cleared stale ip %s", item.ID)
		}
	}
}

func looksLikeHypervisorServerID(id string) bool {
	id = strings.TrimSpace(id)
	if id == "" {
		return false
	}
	if hypervisor.IsOpenStackExternalID(id) {
		return true
	}
	n, err := strconv.Atoi(id)
	return err == nil && n > 0
}
