package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Port      string
	DSN       string
	RateLimit float64
	RateBurst int

	// Auto-embedding: TiDB Serverless generates embeddings via EMBED_TEXT().
	// When set, takes priority over client-side embedding.
	// Example: "tidbcloud_free/amazon/titan-embed-text-v2"
	EmbedAutoModel string
	EmbedAutoDims  int

	// Client-side embedding provider (optional — omit for keyword-only search).
	EmbedAPIKey  string
	EmbedBaseURL string
	EmbedModel   string
	EmbedDims    int
}

func Load() (*Config, error) {
	dsn := os.Getenv("MNEMO_DSN")
	if dsn == "" {
		return nil, fmt.Errorf("MNEMO_DSN is required")
	}

	cfg := &Config{
		Port:           envOr("MNEMO_PORT", "8080"),
		DSN:            dsn,
		RateLimit:      envFloat("MNEMO_RATE_LIMIT", 100),
		RateBurst:      envInt("MNEMO_RATE_BURST", 200),
		EmbedAutoModel: os.Getenv("MNEMO_EMBED_AUTO_MODEL"),
		EmbedAutoDims:  envInt("MNEMO_EMBED_AUTO_DIMS", 1024),
		EmbedAPIKey:    os.Getenv("MNEMO_EMBED_API_KEY"),
		EmbedBaseURL:   os.Getenv("MNEMO_EMBED_BASE_URL"),
		EmbedModel:     os.Getenv("MNEMO_EMBED_MODEL"),
		EmbedDims:      envInt("MNEMO_EMBED_DIMS", 1536),
	}
	return cfg, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envFloat(key string, fallback float64) float64 {
	if v := os.Getenv(key); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
