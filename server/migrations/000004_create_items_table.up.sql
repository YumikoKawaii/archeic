CREATE TABLE IF NOT EXISTS items (
    collection_id CHAR(36) NOT NULL,
    media_id CHAR(36) NOT NULL,
    position INT NOT NULL,
    added_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (collection_id, media_id),
    INDEX idx_collection_position (collection_id, position),
    CONSTRAINT fk_items_collection FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
    CONSTRAINT fk_items_media FOREIGN KEY (media_id) REFERENCES media (id) ON DELETE CASCADE
);
