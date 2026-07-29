package main

import (
	"errors"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/tailscale/wireguard-go/tun"
	"golang.org/x/sys/unix"
)

// harmonyTunDevice adapts the raw IP packet descriptor returned by
// vpnExtension.VpnConnection.create to wireguard-go's tun.Device interface.
// HarmonyOS owns interface creation and routing, so Linux TUN ioctls and
// netlink monitoring are intentionally not used here.
type harmonyTunDevice struct {
	file             *os.File
	mtu              int
	events           chan tun.Event
	closeOnce        sync.Once
	readCount        atomic.Uint64
	writeCount       atomic.Uint64
	readByteCount    atomic.Uint64
	writeByteCount   atomic.Uint64
	readErrorCount   atomic.Uint64
	writeErrorCount  atomic.Uint64
	trafficSession   uint64
	dnsQueryCount    atomic.Uint64
	dnsResponseCount atomic.Uint64
	dnsAnswerCount   atomic.Uint64
}

func newHarmonyTunDevice(fd, mtu int) (*harmonyTunDevice, error) {
	if fd < 0 {
		return nil, errors.New("invalid TUN descriptor")
	}
	duplicate, err := unix.Dup(fd)
	if err != nil {
		return nil, err
	}
	if err := unix.SetNonblock(duplicate, true); err != nil {
		_ = unix.Close(duplicate)
		return nil, err
	}
	device := &harmonyTunDevice{
		file:           os.NewFile(uintptr(duplicate), "harmony-vpn-tun"),
		mtu:            mtu,
		events:         make(chan tun.Event, 2),
		trafficSession: uint64(time.Now().UnixMilli()),
	}
	device.events <- tun.EventUp
	return device, nil
}

func (d *harmonyTunDevice) File() *os.File { return d.file }

func (d *harmonyTunDevice) Read(bufs [][]byte, sizes []int, offset int) (int, error) {
	if len(bufs) == 0 || len(sizes) == 0 || offset < 0 || offset >= len(bufs[0]) {
		return 0, errors.New("invalid TUN read buffer")
	}
	n, err := d.file.Read(bufs[0][offset:])
	if n > 0 {
		sizes[0] = n
		d.readCount.Add(1)
		d.readByteCount.Add(uint64(n))
		d.observeDNSPacket(bufs[0][offset:offset+n], true)
		return 1, nil
	}
	if err != nil && !isRetriableTunError(err) {
		d.readErrorCount.Add(1)
	}
	return 0, err
}

func (d *harmonyTunDevice) Write(bufs [][]byte, offset int) (int, error) {
	written := 0
	for _, buf := range bufs {
		if offset < 0 || offset > len(buf) {
			return written, errors.New("invalid TUN write buffer")
		}
		n, err := d.file.Write(buf[offset:])
		if err != nil {
			if !isRetriableTunError(err) {
				d.writeErrorCount.Add(1)
			}
			return written, err
		}
		if n > 0 {
			d.writeCount.Add(1)
			d.writeByteCount.Add(uint64(n))
			d.observeDNSPacket(buf[offset:offset+n], false)
		}
		written++
	}
	return written, nil
}

func (d *harmonyTunDevice) MTU() (int, error) { return d.mtu, nil }

func (d *harmonyTunDevice) Name() (string, error) { return "tailscale0", nil }

func (d *harmonyTunDevice) Events() <-chan tun.Event { return d.events }

func (d *harmonyTunDevice) Close() error {
	var err error
	d.closeOnce.Do(func() {
		d.events <- tun.EventDown
		close(d.events)
		err = d.file.Close()
	})
	return err
}

func (d *harmonyTunDevice) BatchSize() int { return 1 }

func (d *harmonyTunDevice) packetCounts() (read uint64, written uint64) {
	return d.readCount.Load(), d.writeCount.Load()
}

// trafficCounts reports bytes for the current VPN TUN lifetime. Reading from
// the TUN is device upload; writing decrypted packets back is device download.
func (d *harmonyTunDevice) trafficCounts() (txBytes uint64, rxBytes uint64, session uint64) {
	return d.readByteCount.Load(), d.writeByteCount.Load(), d.trafficSession
}

func (d *harmonyTunDevice) errorCounts() (readErrors uint64, writeErrors uint64) {
	return d.readErrorCount.Load(), d.writeErrorCount.Load()
}

func isRetriableTunError(err error) bool {
	return errors.Is(err, unix.EAGAIN) ||
		errors.Is(err, unix.EWOULDBLOCK) ||
		errors.Is(err, unix.EINTR)
}

func (d *harmonyTunDevice) dnsCounts() (queries uint64, responses uint64, answers uint64) {
	return d.dnsQueryCount.Load(), d.dnsResponseCount.Load(), d.dnsAnswerCount.Load()
}

// observeDNSPacket records only coarse DNS counters. It deliberately does not
// retain query names, addresses, transaction IDs, or packet payloads.
func (d *harmonyTunDevice) observeDNSPacket(packet []byte, fromSystem bool) {
	if len(packet) < 20 || packet[0]>>4 != 4 {
		return
	}
	headerLength := int(packet[0]&0x0f) * 4
	if headerLength < 20 || len(packet) < headerLength+8+12 || packet[9] != 17 {
		return
	}
	udp := packet[headerLength:]
	sourcePort := uint16(udp[0])<<8 | uint16(udp[1])
	destinationPort := uint16(udp[2])<<8 | uint16(udp[3])
	dns := udp[8:]
	isResponse := dns[2]&0x80 != 0
	if fromSystem && destinationPort == 53 && !isResponse {
		d.dnsQueryCount.Add(1)
		return
	}
	if !fromSystem && sourcePort == 53 && isResponse {
		d.dnsResponseCount.Add(1)
		answerCount := uint16(dns[6])<<8 | uint16(dns[7])
		if answerCount > 0 {
			d.dnsAnswerCount.Add(1)
		}
	}
}

var _ tun.Device = (*harmonyTunDevice)(nil)
