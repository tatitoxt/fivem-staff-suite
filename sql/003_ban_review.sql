-- El ID de la sanción agrupa aliases. La revocación conserva la fila de revisión.
ALTER TABLE staff_bans ADD COLUMN ban_id BIGINT NULL;
ALTER TABLE staff_bans ADD COLUMN revoked_at BIGINT NULL;
