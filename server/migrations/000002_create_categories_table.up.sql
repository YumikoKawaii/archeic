CREATE TABLE IF NOT EXISTS categories (
    id CHAR(36) PRIMARY KEY,
    slug VARCHAR(64) NOT NULL,
    name VARCHAR(255) NOT NULL,
    layout ENUM('gallery', 'library', 'episodic', 'timeline') NOT NULL,
    position INT NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    UNIQUE KEY uq_slug (slug),
    INDEX idx_position (position)
);
