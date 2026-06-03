package disks

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type LargestDiskFinder struct{}

func NewLargestDiskFinder() *LargestDiskFinder {
	return &LargestDiskFinder{}
}

func (f *LargestDiskFinder) Find() (string, error) {
	file, err := os.Open("/proc/partitions")
	if err != nil {
		return "", err
	}
	defer file.Close()

	var largestDevice string
	var largestSize int64

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "major") || line == "" {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}

		deviceName := fields[3]

		if !isWholeDisk(deviceName) {
			continue
		}

		sizeBlocks, err := strconv.ParseInt(fields[2], 10, 64)
		if err != nil {
			continue
		}

		sizeBytes := sizeBlocks * 1024

		if sizeBytes > largestSize {
			largestSize = sizeBytes
			largestDevice = "/dev/" + deviceName
		}
	}

	if err := scanner.Err(); err != nil {
		return "", err
	}

	if largestDevice == "" {
		return "", fmt.Errorf("no whole disk found")
	}

	return largestDevice, nil
}