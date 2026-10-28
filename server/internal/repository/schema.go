package repository

var schema = []string{
	`CREATE TABLE IF NOT EXISTS media (
		id CHAR(36) PRIMARY KEY,
		name VARCHAR(512) NOT NULL,
		kind VARCHAR(16) NOT NULL,
		content_type VARCHAR(128) NOT NULL,
		size BIGINT NOT NULL,
		object_key VARCHAR(512) NOT NULL,
		created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
		INDEX idx_kind_created (kind, created_at)
	)`,
	`CREATE TABLE IF NOT EXISTS categories (
		id CHAR(36) PRIMARY KEY,
		slug VARCHAR(64) NOT NULL,
		name VARCHAR(255) NOT NULL,
		layout ENUM('gallery', 'library', 'episodic', 'timeline') NOT NULL,
		position INT NOT NULL,
		created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
		updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
		UNIQUE KEY uq_slug (slug),
		INDEX idx_position (position)
	)`,
	`CREATE TABLE IF NOT EXISTS collections (
		id CHAR(36) PRIMARY KEY,
		category_id CHAR(36) NOT NULL,
		parent_id CHAR(36) NULL,
		name VARCHAR(255) NOT NULL,
		cover_id CHAR(36) NULL,
		created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
		updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
		UNIQUE KEY uq_parent_name (category_id, parent_id, name),
		CONSTRAINT fk_collections_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
		CONSTRAINT fk_collections_parent FOREIGN KEY (parent_id) REFERENCES collections (id) ON DELETE CASCADE,
		CONSTRAINT fk_collections_cover FOREIGN KEY (cover_id) REFERENCES media (id) ON DELETE SET NULL
	)`,
	`CREATE TABLE IF NOT EXISTS items (
		collection_id CHAR(36) NOT NULL,
		media_id CHAR(36) NOT NULL,
		position INT NOT NULL,
		added_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
		PRIMARY KEY (collection_id, media_id),
		INDEX idx_collection_position (collection_id, position),
		CONSTRAINT fk_items_collection FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
		CONSTRAINT fk_items_media FOREIGN KEY (media_id) REFERENCES media (id) ON DELETE CASCADE
	)`,
}
