-- Tickets F2: primera respuesta, quién resolvió y evidencia con screenshot-basic.
-- Staff Suite la aplica sola al iniciar (staff_schema). Una sentencia ALTER por columna
-- para que el runner pueda saltear las que ya existan.
ALTER TABLE staff_tickets ADD COLUMN first_response_ts BIGINT NULL;
ALTER TABLE staff_tickets ADD COLUMN resolved_by VARCHAR(191) NULL;

CREATE TABLE IF NOT EXISTS staff_evidence (
  ticket_id BIGINT NOT NULL,
  n INT NOT NULL,
  ts BIGINT NOT NULL,
  actor VARCHAR(191) NOT NULL,
  sha256 CHAR(64) NOT NULL,
  size BIGINT NOT NULL,
  audit_seq BIGINT NOT NULL,
  PRIMARY KEY (ticket_id, n),
  FOREIGN KEY (ticket_id) REFERENCES staff_tickets(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
