UPDATE vps.outbox
SET published = false,
    worker_poll_claimed_at = NULL,
    worker_poll_claimed_by = NULL
WHERE id = 622;
