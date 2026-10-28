CREATE TABLE IF NOT EXISTS media (
    id CHAR(36) PRIMARY KEY,
    name VARCHAR(512) NOT NULL,
    kind VARCHAR(16) NOT NULL,
    content_type VARCHAR(128) NOT NULL,
    size BIGINT NOT NULL,
    object_key VARCHAR(512) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_kind_created (kind, created_at)
);
