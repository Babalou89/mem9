package service

import (
	"strings"
	"testing"
)

func TestTenantSchemaConstants(t *testing.T) {
	memoryChecks := []string{
		"CREATE TABLE IF NOT EXISTS memories",
		"id              VARCHAR(36)",
		"embedding       VECTOR(1536)",
		"INDEX idx_updated",
	}
	for _, needle := range memoryChecks {
		if !strings.Contains(tenantMemorySchema, needle) {
			t.Fatalf("tenantMemorySchema missing %q", needle)
		}
	}
}
