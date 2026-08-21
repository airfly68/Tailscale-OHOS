package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"tailscale.com/client/local"
	"tailscale.com/ipn/ipnstate"
	"tailscale.com/tsnet"
)

const (
	meshArcDeviceEndpoint            = "http://127.0.0.1:53317/api/mesharc/devices"
	meshArcDeviceSyncPeriod          = 10 * time.Second
	meshArcDeviceTimeout             = 3 * time.Second
	meshArcLocalSendPort             = 53317
	meshArcLocalSendProtocol         = "https"
	meshArcLocalSendVersion          = "2.1"
	meshArcLocalSendRegisterPath     = "/api/localsend/v2/register"
	meshArcLocalSendProbeTimeout     = 1200 * time.Millisecond
	meshArcLocalSendProbeWorkers     = 8
	meshArcLocalSendProbeFingerprint = "mesharc-ohos"
	meshArcLocalSendDeviceType       = "mobile"
)

// meshArcDeviceItem is the array item defined by the MeshArc device API
// contract. alias remains the peer's human-readable name; deviceModel
// identifies the source in the receiving device list.
type meshArcDeviceItem struct {
	Alias       string `json:"alias"`
	IP          string `json:"ip"`
	Port        int    `json:"port"`
	Protocol    string `json:"protocol"`
	Fingerprint string `json:"fingerprint"`
	DeviceType  string `json:"deviceType"`
	DeviceModel string `json:"deviceModel"`
	Version     string `json:"version"`
	Download    bool   `json:"download"`
}

// meshArcLocalSendInfo is the LocalSend v2 register payload. The response
// omits port and protocol in the documented contract, so those fields remain
// optional when decoding a peer's response.
type meshArcLocalSendInfo struct {
	Alias       string `json:"alias"`
	Version     string `json:"version"`
	DeviceModel string `json:"deviceModel"`
	DeviceType  string `json:"deviceType"`
	Fingerprint string `json:"fingerprint"`
	Port        int    `json:"port,omitempty"`
	Protocol    string `json:"protocol,omitempty"`
	Download    bool   `json:"download"`
}

type meshArcPeerCandidate struct {
	peer    *ipnstate.PeerStatus
	address string
}

type meshArcDeviceStatus struct {
	State       string `json:"state"`
	Protocol    string `json:"protocol,omitempty"`
	Port        int    `json:"port,omitempty"`
	Version     string `json:"version,omitempty"`
	CheckedAtMS int64  `json:"checkedAtMs,omitempty"`
}

type meshArcDeviceProbeResult struct {
	Key    string
	Item   meshArcDeviceItem
	Status meshArcDeviceStatus
}

var meshArcDeviceHTTPClient = &http.Client{
	Transport: &http.Transport{
		Proxy:             nil,
		DisableKeepAlives: true,
	},
	CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
		return http.ErrUseLastResponse
	},
}

func (b *backendController) startMeshArcDeviceSync(
	server *tsnet.Server, generation uint64, client *local.Client,
) {
	syncContext, cancel := context.WithCancel(context.Background())
	b.mu.Lock()
	if b.server != server || b.generation != generation {
		b.mu.Unlock()
		cancel()
		return
	}
	previousCancel := b.meshArcDeviceSyncStop
	b.meshArcDeviceSyncStop = cancel
	b.mu.Unlock()
	if previousCancel != nil {
		previousCancel()
	}

	go b.meshArcDeviceSyncLoop(syncContext, server, generation, client)
}

func (b *backendController) meshArcDeviceSyncLoop(
	ctx context.Context, server *tsnet.Server, generation uint64, client *local.Client,
) {
	defer func() {
		b.mu.Lock()
		if b.server == server && b.generation == generation {
			b.meshArcDeviceSyncStop = nil
		}
		b.mu.Unlock()
	}()

	b.syncMeshArcDevicesOnce(ctx, server, generation, client)
	ticker := time.NewTicker(meshArcDeviceSyncPeriod)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			b.syncMeshArcDevicesOnce(ctx, server, generation, client)
		}
	}
}

func (b *backendController) syncMeshArcDevicesOnce(
	ctx context.Context, server *tsnet.Server, generation uint64, client *local.Client,
) {
	if !b.isCurrentBackend(server, generation) {
		return
	}
	statusContext, cancel := context.WithTimeout(ctx, meshArcDeviceTimeout)
	status, err := client.Status(statusContext)
	cancel()
	if err != nil || !b.isCurrentBackend(server, generation) {
		// Keep the last successful list alive. The receiver expires devices that
		// stop arriving, while a transient status failure should not immediately
		// hide every device from the user's transfer list.
		return
	}

	// Tailscale's peer list is only the candidate set. A peer is added to the
	// MeshArc array after its LocalSend /register endpoint answers successfully.
	devices, localSendStatuses := probeMeshArcDeviceItems(ctx, server, status)
	if !b.updateMeshArcDeviceStatuses(server, generation, localSendStatuses) {
		return
	}
	postContext, postCancel := context.WithTimeout(ctx, meshArcDeviceTimeout)
	_ = postMeshArcDevices(postContext, meshArcDeviceEndpoint, devices)
	postCancel()
}

func (b *backendController) isCurrentBackend(server *tsnet.Server, generation uint64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.server == server && b.generation == generation && b.client != nil
}

func (b *backendController) updateMeshArcDeviceStatuses(
	server *tsnet.Server, generation uint64, statuses map[string]meshArcDeviceStatus,
) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.server != server || b.generation != generation || b.client == nil {
		return false
	}
	b.meshArcDeviceStatuses = cloneMeshArcDeviceStatuses(statuses)
	return true
}

// meshArcDeviceStatusesSnapshotLocked must be called while b.mu is held.
func (b *backendController) meshArcDeviceStatusesSnapshotLocked() map[string]meshArcDeviceStatus {
	return cloneMeshArcDeviceStatuses(b.meshArcDeviceStatuses)
}

func cloneMeshArcDeviceStatuses(
	statuses map[string]meshArcDeviceStatus,
) map[string]meshArcDeviceStatus {
	if len(statuses) == 0 {
		return map[string]meshArcDeviceStatus{}
	}
	copyStatuses := make(map[string]meshArcDeviceStatus, len(statuses))
	for key, status := range statuses {
		copyStatuses[key] = status
	}
	return copyStatuses
}

func postMeshArcDevices(ctx context.Context, endpoint string, devices []meshArcDeviceItem) error {
	if devices == nil {
		devices = []meshArcDeviceItem{}
	}
	body, err := json.Marshal(devices)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	request.Header.Set("User-Agent", "MeshArc-Tailscale/1")
	response, err := meshArcDeviceHTTPClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 8<<10))
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("MeshArc device endpoint returned HTTP %d", response.StatusCode)
	}
	return nil
}

func probeMeshArcDeviceItems(
	ctx context.Context, server *tsnet.Server, status *ipnstate.Status,
) ([]meshArcDeviceItem, map[string]meshArcDeviceStatus) {
	items := make([]meshArcDeviceItem, 0)
	statuses := make(map[string]meshArcDeviceStatus)
	checkedAtMS := time.Now().UnixMilli()
	if status != nil && status.BackendState == "Running" {
		for _, peer := range status.Peer {
			if peer == nil || !peer.Online || peer.Expired {
				continue
			}
			statuses[peerStableKey(peer.ID)] = meshArcDeviceStatus{
				State:       "unavailable",
				CheckedAtMS: checkedAtMS,
			}
		}
	}
	candidates := collectMeshArcPeerCandidates(status)
	if server == nil || len(candidates) == 0 {
		return items, statuses
	}

	probeClient := newMeshArcProbeHTTPClient(server)
	if probeClient == nil {
		return items, statuses
	}
	defer closeMeshArcProbeHTTPClient(probeClient)

	workerCount := meshArcLocalSendProbeWorkers
	if len(candidates) < workerCount {
		workerCount = len(candidates)
	}
	jobs := make(chan meshArcPeerCandidate, len(candidates))
	results := make(chan meshArcDeviceProbeResult, len(candidates))
	for _, candidate := range candidates {
		jobs <- candidate
	}
	close(jobs)

	var workers sync.WaitGroup
	workers.Add(workerCount)
	for index := 0; index < workerCount; index++ {
		go func() {
			defer workers.Done()
			for candidate := range jobs {
				probeContext, cancel := context.WithTimeout(ctx, meshArcLocalSendProbeTimeout)
				info, protocol, ok := probeMeshArcLocalSend(probeContext, probeClient, candidate.address)
				cancel()
				if !ok {
					continue
				}
				results <- meshArcDeviceProbeResult{
					Key:  peerStableKey(candidate.peer.ID),
					Item: buildMeshArcDeviceItem(candidate, info, protocol),
					Status: meshArcDeviceStatus{
						State:       "available",
						Protocol:    protocol,
						Port:        meshArcLocalSendPort,
						Version:     strings.TrimSpace(info.Version),
						CheckedAtMS: checkedAtMS,
					},
				}
			}
		}()
	}
	workers.Wait()
	close(results)
	for result := range results {
		items = append(items, result.Item)
		statuses[result.Key] = result.Status
	}
	sortMeshArcDeviceItems(items)
	return items, statuses
}

func collectMeshArcPeerCandidates(status *ipnstate.Status) []meshArcPeerCandidate {
	candidates := make([]meshArcPeerCandidate, 0)
	if status == nil || status.BackendState != "Running" {
		return candidates
	}
	for _, peer := range status.Peer {
		if peer == nil || !peer.Online || peer.Expired {
			continue
		}
		address := meshArcPeerAddress(peer.TailscaleIPs)
		if address == "" {
			continue
		}
		candidates = append(candidates, meshArcPeerCandidate{peer: peer, address: address})
	}
	return candidates
}

func newMeshArcProbeHTTPClient(server *tsnet.Server) *http.Client {
	if server == nil {
		return nil
	}
	transport := &http.Transport{
		Proxy:             nil,
		DialContext:       server.Dial,
		DisableKeepAlives: true,
		TLSClientConfig: &tls.Config{
			MinVersion:         tls.VersionTLS12,
			InsecureSkipVerify: true, // #nosec G402 -- LocalSend uses per-device self-signed certificates.
		},
	}
	return &http.Client{
		Transport: transport,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
}

func closeMeshArcProbeHTTPClient(client *http.Client) {
	if client == nil {
		return
	}
	if transport, ok := client.Transport.(*http.Transport); ok {
		transport.CloseIdleConnections()
	}
}

func probeMeshArcLocalSend(
	ctx context.Context, httpClient *http.Client, address string,
) (meshArcLocalSendInfo, string, bool) {
	if httpClient == nil || strings.TrimSpace(address) == "" {
		return meshArcLocalSendInfo{}, "", false
	}
	for _, protocol := range []string{meshArcLocalSendProtocol, "http"} {
		probeRequest := meshArcLocalSendInfo{
			Alias:       "MeshArc",
			Version:     meshArcLocalSendVersion,
			DeviceModel: "MeshArc",
			DeviceType:  meshArcLocalSendDeviceType,
			Fingerprint: meshArcLocalSendProbeFingerprint,
			Port:        meshArcLocalSendPort,
			Protocol:    protocol,
			Download:    false,
		}
		body, err := json.Marshal(probeRequest)
		if err != nil {
			return meshArcLocalSendInfo{}, "", false
		}
		endpoint := protocol + "://" + net.JoinHostPort(address, strconv.Itoa(meshArcLocalSendPort)) + meshArcLocalSendRegisterPath
		request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
		if err != nil {
			continue
		}
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("Accept", "application/json")
		request.Header.Set("User-Agent", "MeshArc-LocalSendProbe/1")
		response, err := httpClient.Do(request)
		if err != nil {
			continue
		}
		responseBody, readErr := io.ReadAll(io.LimitReader(response.Body, 64<<10))
		response.Body.Close()
		if readErr != nil || response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
			continue
		}
		var info meshArcLocalSendInfo
		if err := json.Unmarshal(responseBody, &info); err != nil || !validMeshArcLocalSendInfo(info) {
			continue
		}
		return info, protocol, true
	}
	return meshArcLocalSendInfo{}, "", false
}

func validMeshArcLocalSendInfo(info meshArcLocalSendInfo) bool {
	return strings.TrimSpace(info.Alias) != "" &&
		strings.TrimSpace(info.Version) != "" &&
		strings.TrimSpace(info.Fingerprint) != ""
}

func buildMeshArcDeviceItem(
	candidate meshArcPeerCandidate, info meshArcLocalSendInfo, protocol string,
) meshArcDeviceItem {
	alias := strings.TrimSuffix(strings.TrimSpace(info.Alias), ".")
	if alias == "" {
		alias = meshArcPeerName(candidate.peer)
	}
	fingerprint := strings.TrimSpace(info.Fingerprint)
	if fingerprint == "" {
		fingerprint = peerStableKey(candidate.peer.ID)
	}
	if fingerprint == "" {
		fingerprint = "mesharc-" + candidate.address
	}
	model := strings.TrimSpace(info.DeviceModel)
	if model == "" || strings.EqualFold(model, "default") {
		model = strings.TrimSpace(candidate.peer.DeviceModel)
	}
	if model == "" || strings.EqualFold(model, "default") {
		model = "MeshArc"
	}
	version := strings.TrimSpace(info.Version)
	if version == "" {
		version = meshArcLocalSendVersion
	}
	return meshArcDeviceItem{
		Alias:       alias,
		IP:          candidate.address,
		Port:        meshArcLocalSendPort,
		Protocol:    protocol,
		Fingerprint: fingerprint,
		DeviceType:  normalizeMeshArcDeviceType(info.DeviceType, candidate.peer.OS, model),
		DeviceModel: model,
		Version:     version,
		Download:    info.Download,
	}
}

func meshArcPeerName(peer *ipnstate.PeerStatus) string {
	if peer == nil {
		return "Unnamed device"
	}
	name := strings.TrimSuffix(strings.TrimSpace(peer.DNSName), ".")
	if name == "" {
		name = strings.TrimSpace(peer.HostName)
	}
	if name == "" {
		return "Unnamed device"
	}
	return name
}

func normalizeMeshArcDeviceType(deviceType, osName, deviceModel string) string {
	switch strings.ToLower(strings.TrimSpace(deviceType)) {
	case "mobile", "desktop", "web", "headless", "server":
		return strings.ToLower(strings.TrimSpace(deviceType))
	default:
		return meshArcDeviceType(osName, deviceModel)
	}
}

func sortMeshArcDeviceItems(items []meshArcDeviceItem) {
	sort.Slice(items, func(left, right int) bool {
		leftName := strings.ToLower(items[left].Alias)
		rightName := strings.ToLower(items[right].Alias)
		if leftName != rightName {
			return leftName < rightName
		}
		return items[left].IP < items[right].IP
	})
}

func meshArcPeerAddress(addresses []netip.Addr) string {
	for _, address := range addresses {
		if address.IsValid() && address.Is4() {
			return address.String()
		}
	}
	for _, address := range addresses {
		if address.IsValid() {
			return address.String()
		}
	}
	return ""
}

func meshArcDeviceType(osName, deviceModel string) string {
	value := strings.ToLower(strings.TrimSpace(osName) + " " + strings.TrimSpace(deviceModel))
	switch {
	case containsAny(value, "nas", "server"):
		return "server"
	case containsAny(value, "headless"):
		return "headless"
	case containsAny(value, "web browser", "web"):
		return "web"
	case containsAny(value, "android", "ios", "ipados", "harmony", "ohos"):
		return "mobile"
	default:
		return "desktop"
	}
}
