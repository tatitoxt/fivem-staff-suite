-- Aplicar antes de iniciar Staff Suite con Config.Persistence = 'oxmysql'.
-- staff_state conserva el esquema de 0.1.0 para importar instalaciones existentes.
CREATE TABLE IF NOT EXISTS staff_state (
  k VARCHAR(64) PRIMARY KEY,
  v VARCHAR(64),
  data LONGTEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_audit (
  seq BIGINT PRIMARY KEY,
  ts BIGINT NOT NULL,
  actor LONGTEXT NOT NULL,
  action LONGTEXT NOT NULL,
  target LONGTEXT NOT NULL,
  reason LONGTEXT NOT NULL,
  payload LONGTEXT NOT NULL,
  prev_hash CHAR(64) NOT NULL,
  hash CHAR(64) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_tickets (
  id BIGINT PRIMARY KEY,
  reporter VARCHAR(191) NOT NULL,
  category VARCHAR(64) NOT NULL,
  priority VARCHAR(32) NOT NULL,
  description LONGTEXT NOT NULL,
  state VARCHAR(32) NOT NULL,
  claimer VARCHAR(191),
  created_ts BIGINT,
  updated_ts BIGINT,
  resolution LONGTEXT,
  rating INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_messages (
  ticket_id BIGINT NOT NULL,
  position INT NOT NULL,
  author VARCHAR(191) NOT NULL,
  body LONGTEXT NOT NULL,
  internal TINYINT NOT NULL,
  ts BIGINT,
  PRIMARY KEY (ticket_id, position),
  FOREIGN KEY (ticket_id) REFERENCES staff_tickets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_duty (
  actor VARCHAR(191) PRIMARY KEY,
  on_duty TINYINT NOT NULL,
  since_ts BIGINT,
  total_seconds BIGINT NOT NULL,
  sessions INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_stats (
  actor VARCHAR(191) PRIMARY KEY,
  resolved INT NOT NULL,
  response_sum BIGINT NOT NULL,
  response_n INT NOT NULL,
  ratings_sum BIGINT NOT NULL,
  ratings_n INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS staff_bans (
  identifier VARCHAR(191) PRIMARY KEY,
  actor VARCHAR(191) NOT NULL,
  reason LONGTEXT NOT NULL,
  created_at BIGINT NOT NULL,
  expires_at BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
