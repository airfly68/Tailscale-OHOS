package main

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"tailscale.com/tailcfg"
)

func TestClassifyTaildropSendError(t *testing.T) {
	tests := []struct {
		message string
		want    string
	}{
		{message: "context deadline exceeded", want: "timeout"},
		{message: "HTTP 502 Bad Gateway", want: "network_interrupted"},
		{message: "write: broken pipe", want: "network_interrupted"},
		{message: "connection reset by peer", want: "target_offline"},
		{message: "file sharing not enabled", want: "admin_disabled"},
		{message: "write failed: no space left on device", want: "no_space"},
	}
	for _, test := range tests {
		if got := classifyTaildropSendError(errors.New(test.message)); got != test.want {
			t.Fatalf("classifyTaildropSendError(%q) = %q, want %q", test.message, got, test.want)
		}
	}
	if !isTransientTaildropSendError(errors.New("HTTP 502 Bad Gateway")) {
		t.Fatal("Bad Gateway should be retried")
	}
	if isTransientTaildropSendError(errors.New("file sharing not enabled")) {
		t.Fatal("admin-disabled Taildrop should not be retried")
	}
	if isTransientTaildropSendError(errors.New("no space left on device")) {
		t.Fatal("low-storage Taildrop failure should not be retried")
	}
}

func TestWaitForTaildropRetryHonorsCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if waitForTaildropRetry(ctx, time.Second) {
		t.Fatal("cancelled retry wait reported success")
	}
}

func TestPeerStableKeyIsDeterministicAndOpaque(t *testing.T) {
	id := tailcfg.StableNodeID("node-1234567890")
	first := peerStableKey(id)
	second := peerStableKey(id)
	if first != second {
		t.Fatalf("stable key changed: %q != %q", first, second)
	}
	if strings.Contains(first, string(id)) {
		t.Fatalf("stable key leaked node ID: %q", first)
	}
	if first == peerStableKey(tailcfg.StableNodeID("node-other")) {
		t.Fatalf("different node IDs produced the same test key: %q", first)
	}
}

func TestValidateTaildropReceiveRequest(t *testing.T) {
	root := t.TempDir()
	request := taildropReceiveRequest{
		RequestID: 42,
		Action:    "stage",
		Name:      "report.pdf",
		InboxRoot: root,
		Path:      filepath.Join(root, "42.taildrop"),
	}
	if err := validateTaildropReceiveRequest(request); err != nil {
		t.Fatalf("valid receive request rejected: %v", err)
	}
	request.Path = filepath.Join(root, "..", "outside.taildrop")
	if err := validateTaildropReceiveRequest(request); err == nil {
		t.Fatal("receive request outside the inbox was accepted")
	}
	request.Action = "delete"
	request.InboxRoot = ""
	request.Path = ""
	if err := validateTaildropReceiveRequest(request); err != nil {
		t.Fatalf("valid delete request rejected: %v", err)
	}
	request.Action = "clear"
	request.Name = ""
	if err := validateTaildropReceiveRequest(request); err != nil {
		t.Fatalf("valid clear request rejected: %v", err)
	}
	request.Name = "report.pdf"
	if err := validateTaildropReceiveRequest(request); err == nil {
		t.Fatal("clear request with file metadata was accepted")
	}
}

func TestStageTaildropWaitingFile(t *testing.T) {
	root := t.TempDir()
	destination := filepath.Join(root, "7.taildrop")
	content := "taildrop receive payload"
	if err := stageTaildropWaitingFile(strings.NewReader(content), int64(len(content)), root, destination); err != nil {
		t.Fatalf("stageTaildropWaitingFile failed: %v", err)
	}
	staged, err := os.ReadFile(destination)
	if err != nil {
		t.Fatalf("read staged file: %v", err)
	}
	if string(staged) != content {
		t.Fatalf("staged content = %q, want %q", staged, content)
	}
	if err := stageTaildropWaitingFile(io.LimitReader(strings.NewReader(content), 3),
		int64(len(content)), root, filepath.Join(root, "8.taildrop")); err == nil {
		t.Fatal("short receive stream was accepted")
	}
}

func TestClassifyPeerDevice(t *testing.T) {
	tests := []struct {
		name  string
		os    string
		model string
		want  string
	}{
		{name: "foldable", os: "harmonyos", model: "Mate X6", want: "foldable"},
		{name: "tablet", os: "harmonyos", model: "MatePad Pro", want: "tablet"},
		{name: "laptop", os: "windows", model: "ThinkPad X1", want: "laptop"},
		{name: "phone", os: "android", model: "Pixel", want: "phone"},
		{name: "computer fallback", os: "linux", model: "", want: "computer"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := classifyPeerDevice(test.os, test.model); got != test.want {
				t.Fatalf("classifyPeerDevice(%q, %q) = %q, want %q", test.os, test.model, got, test.want)
			}
		})
	}
}

func TestHarmonyHostnameFallback(t *testing.T) {
	if got := harmonyHostname("default"); got != "harmonyos-next" {
		t.Fatalf("harmonyHostname(default) = %q", got)
	}
	if got := harmonyHostname("Mate 70 Pro"); got == "" || strings.Contains(got, " ") {
		t.Fatalf("harmonyHostname did not sanitize model: %q", got)
	}
}

func TestMediaServiceResponseClassification(t *testing.T) {
	jellyfin, ok := classifySystemMediaResponse(
		[]byte(`{"ServerName":"Home NAS","Version":"10.10.7","ProductName":"Jellyfin Server","Id":"one"}`),
		"http://100.64.0.10:8096", "/System/Info/Public")
	if !ok || jellyfin.Type != "jellyfin" || jellyfin.Name != "Home NAS" {
		t.Fatalf("Jellyfin fixture not classified: %#v, ok=%v", jellyfin, ok)
	}
	emby, ok := classifySystemMediaResponse(
		[]byte(`{"ServerName":"Media","Version":"4.8.11","ProductName":"Emby Server","Id":"two"}`),
		"http://100.64.0.10:8096", "/emby/System/Info/Public")
	if !ok || emby.Type != "emby" || emby.URL != "http://100.64.0.10:8096/emby" {
		t.Fatalf("Emby fixture not classified: %#v, ok=%v", emby, ok)
	}
	if _, ok := classifySystemMediaResponse(
		[]byte(`{"ServerName":"Other","Version":"1","ProductName":"Generic HTTP"}`),
		"http://100.64.0.10:8096", "/System/Info/Public"); ok {
		t.Fatal("generic HTTP response was accepted as a media server")
	}
	plex, ok := classifyPlexIdentity(
		[]byte(`<MediaContainer size="0" machineIdentifier="fixture" version="1.41.4.9463"/>`),
		"http://100.64.0.10:32400")
	if !ok || plex.Type != "plex" {
		t.Fatalf("Plex fixture not classified: %#v, ok=%v", plex, ok)
	}
	if _, ok := classifyPlexIdentity([]byte(`<html>Plex</html>`),
		"http://100.64.0.10:32400"); ok {
		t.Fatal("non-identity XML was accepted as Plex")
	}
}

func TestMediaProbeSelfTest(t *testing.T) {
	if result := mediaProbeSelfTest(); !strings.Contains(result, `"state":"passed"`) {
		t.Fatalf("media probe self-test failed: %s", result)
	}
}
