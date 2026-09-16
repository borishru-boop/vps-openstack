package main

import (
	"context"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/borishru-boop/testVPStrade/services/vps/internal/hypervisor"
	"github.com/borishru-boop/testVPStrade/services/vps/internal/monitoring"
	"github.com/borishru-boop/testVPStrade/services/vps/internal/store"
)

func syncNodes(ctx context.Context, st *store.Store, src hypervisor.NodeSyncSource) error {
	if src == nil {
		return nil
	}
	targets, err := st.ListNodesForSync(ctx)
	if err != nil {
		return err
	}
	if len(targets) == 0 {
		return nil
	}

	snapshots, err := src.FetchComputeSnapshots(ctx)
	if err != nil {
		return err
	}
	byExternalID := make(map[string]hypervisor.ComputeSnapshot, len(snapshots))
	for _, snap := range snapshots {
		byExternalID[snap.ExternalID] = snap
	}

	now := time.Now().UTC()
	for _, target := range targets {
		if hypervisor.RegionUsesOpenStack(target.Region) {
			continue
		}
		snap, ok := byExternalID[target.ExternalID]
		if !ok {
			if err := st.MarkNodeSyncMissing(ctx, target.ID, now); err != nil {
				log.Printf("node sync missing %s: %v", target.ID, err)
			}
			continue
		}
		patch := store.PatchFromHypervisor(target.ID, snap, now)
		if host := strings.TrimSpace(snap.IP); host != "" {
			reachable := hypervisor.ProbeTCP(ctx, host, hypervisor.DefaultHypervisorPort)
			store.ApplyReachability(&patch, reachable)
			if !reachable {
				log.Printf("node sync %s (%s): hypervisor unreachable on :%d", target.ID, host, hypervisor.DefaultHypervisorPort)
			}
			applyNodeExporterHostLoad(ctx, &patch, host)
		}
		if err := st.ApplyNodeSync(ctx, patch); err != nil {
			log.Printf("node sync apply %s: %v", target.ID, err)
		}
	}
	return nil
}

func nodeExporterEnabled() bool {
	v := strings.TrimSpace(os.Getenv("VPS_NODE_EXPORTER"))
	if v == "" || v == "1" || strings.EqualFold(v, "true") || strings.EqualFold(v, "on") {
		return true
	}
	return false
}

func nodeExporterPort() int {
	if v := strings.TrimSpace(os.Getenv("VPS_NODE_EXPORTER_PORT")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return 9100
}

func nodeExporterTimeout() time.Duration {
	if v := strings.TrimSpace(os.Getenv("VPS_NODE_EXPORTER_TIMEOUT")); v != "" {
		if d, err := time.ParseDuration(v); err == nil && d > 0 {
			return d
		}
	}
	return 5 * time.Second
}

func applyNodeExporterHostLoad(ctx context.Context, patch *store.NodeSyncPatch, host string) {
	if patch == nil || !nodeExporterEnabled() {
		return
	}
	load, err := monitoring.ScrapeHostLoad(ctx, host, nodeExporterPort(), nodeExporterTimeout())
	if err != nil {
		log.Printf("node sync %s (%s): node_exporter: %v", patch.NodeID, host, err)
		return
	}
	cpu := load.CPUPercent
	mem := load.MemoryPercent
	disk := load.DiskPercent
	patch.HostCPUPercent = &cpu
	patch.HostMemoryPercent = &mem
	patch.HostDiskPercent = &disk
}
