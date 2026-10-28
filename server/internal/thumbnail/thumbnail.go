package thumbnail

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
)

type Maker struct {
	slots chan struct{}
}

func New(concurrency int) *Maker {
	return &Maker{slots: make(chan struct{}, max(concurrency, 1))}
}

func (m *Maker) Make(ctx context.Context, src io.Reader, size int, video bool) ([]byte, error) {
	select {
	case m.slots <- struct{}{}:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	defer func() { <-m.slots }()

	in, err := os.CreateTemp("", "thumb-src-*")
	if err != nil {
		return nil, fmt.Errorf("creating temp file: %w", err)
	}
	defer os.Remove(in.Name())
	defer in.Close()
	if _, err := io.Copy(in, src); err != nil {
		return nil, fmt.Errorf("buffering source: %w", err)
	}

	out, err := render(ctx, in.Name(), size, video, "1")
	if err == nil && len(out) > 0 {
		return out, nil
	}
	if video {
		return render(ctx, in.Name(), size, video, "0")
	}
	return out, err
}

func render(ctx context.Context, path string, size int, video bool, seek string) ([]byte, error) {
	s := strconv.Itoa(size)
	args := []string{"-v", "error"}
	if video {
		args = append(args, "-ss", seek)
	}
	args = append(args,
		"-i", path,
		"-frames:v", "1",
		"-vf", "scale=w="+s+":h="+s+":force_original_aspect_ratio=decrease",
		"-q:v", "4",
		"-f", "image2", "-c:v", "mjpeg", "pipe:1",
	)
	var stdout, stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, "ffmpeg", args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg: %w: %s", err, stderr.String())
	}
	return stdout.Bytes(), nil
}
