CREATE TABLE IF NOT EXISTS collections (
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
);
