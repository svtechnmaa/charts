-- Fresh Gateway schema only. Select the customer Gateway database before running.
-- IF NOT EXISTS does not upgrade or reconcile an existing schema.
CREATE TABLE IF NOT EXISTS apps (
    id VARCHAR(64) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL,
    upstream_url VARCHAR(1024) NOT NULL,
    routing_mode VARCHAR(32) NOT NULL DEFAULT 'gateway',
    public_prefix VARCHAR(255) NOT NULL DEFAULT '',
    auth_mode VARCHAR(32) NOT NULL DEFAULT 'none',
    accent VARCHAR(32) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    app_id VARCHAR(64) NOT NULL,
    label VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    FOREIGN KEY (app_id) REFERENCES apps(id)
);

CREATE TABLE IF NOT EXISTS upstream_cookies (
    gateway_session_id VARCHAR(64) NOT NULL,
    app_id VARCHAR(64) NOT NULL,
    scope_hash BINARY(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    cookie_value TEXT NOT NULL,
    domain VARCHAR(255) NOT NULL DEFAULT '',
    path VARCHAR(1024) NOT NULL DEFAULT '/',
    expires_at DATETIME NULL,
    secure BOOLEAN NOT NULL DEFAULT FALSE,
    http_only BOOLEAN NOT NULL DEFAULT FALSE,
    same_site VARCHAR(16) NOT NULL DEFAULT '',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (gateway_session_id, app_id, scope_hash),
    INDEX idx_cookie_expiry (expires_at),
    FOREIGN KEY (app_id) REFERENCES apps(id)
);

