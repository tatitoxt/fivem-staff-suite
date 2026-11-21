-- Etiquetas de triaje del staff sobre tickets (ticket_label). JSON array, NULL = sin etiquetas.
ALTER TABLE staff_tickets ADD COLUMN labels TEXT NULL;
