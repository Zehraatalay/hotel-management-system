
-- =========================================================
-- 3.6.3 VIEWS
-- =========================================================

DROP VIEW IF EXISTS v_service_revenue_analysis;
DROP VIEW IF EXISTS v_hotel_occupancy_analysis;
DROP VIEW IF EXISTS v_guest_reservation_summary;

-- Protects contact details by excluding CUSTOMER.phone and CUSTOMER.email.
CREATE VIEW v_guest_reservation_summary AS
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.customer_type,
    r.reservation_id,
    r.booking_date,
    r.status AS reservation_status,
    rs.hotel_id,
    h.name AS hotel_name,
    rs.space_no,
    s.space_type,
    rs.check_in_date,
    rs.check_out_date,
    rs.agreed_nightly_rate,
    (rs.check_out_date - rs.check_in_date) AS night_count,
    rs.agreed_nightly_rate
        * (rs.check_out_date - rs.check_in_date) AS estimated_room_amount
FROM customer c
JOIN reservation r
  ON r.customer_id = c.customer_id
JOIN reservation_space rs
  ON rs.reservation_id = r.reservation_id
JOIN hotel h
  ON h.hotel_id = rs.hotel_id
JOIN space s
  ON s.hotel_id = rs.hotel_id
 AND s.space_no = rs.space_no;

-- Analytical room/space booking view.
CREATE VIEW v_hotel_occupancy_analysis AS
SELECT
    h.hotel_id,
    h.name AS hotel_name,
    h.city,
    s.space_type,
    COUNT(DISTINCT (s.hotel_id, s.space_no)) AS total_spaces,
    COUNT(DISTINCT (rs.reservation_id, rs.hotel_id, rs.space_no))
        FILTER (WHERE r.status IN ('Pending', 'Confirmed')) AS active_booking_count,
    COALESCE(
        SUM(rs.check_out_date - rs.check_in_date)
            FILTER (WHERE r.status IN ('Pending', 'Confirmed')),
        0
    ) AS active_booked_nights,
    COALESCE(
        SUM(
            rs.agreed_nightly_rate
            * (rs.check_out_date - rs.check_in_date)
        ) FILTER (WHERE r.status IN ('Confirmed', 'Completed')),
        0
    ) AS room_revenue
FROM hotel h
JOIN space s
  ON s.hotel_id = h.hotel_id
LEFT JOIN reservation_space rs
  ON rs.hotel_id = s.hotel_id
 AND rs.space_no = s.space_no
LEFT JOIN reservation r
  ON r.reservation_id = rs.reservation_id
GROUP BY
    h.hotel_id,
    h.name,
    h.city,
    s.space_type;

-- Analytical service consumption and revenue view.
CREATE VIEW v_service_revenue_analysis AS
SELECT
    sv.service_id,
    sv.description AS service_name,
    COUNT(su.usage_no) AS usage_record_count,
    COALESCE(SUM(su.quantity), 0) AS total_quantity,
    COALESCE(SUM(su.charged_price), 0) AS total_charged_amount,
    COUNT(DISTINCT r.customer_id) AS distinct_customer_count
FROM service sv
LEFT JOIN service_usage su
  ON su.service_id = sv.service_id
LEFT JOIN reservation r
  ON r.reservation_id = su.reservation_id
GROUP BY
    sv.service_id,
    sv.description;


-- =========================================================
-- 3.6.4 TRIGGERS
-- =========================================================

-- Trigger 1: Prevent overlapping active reservations.
CREATE OR REPLACE FUNCTION fn_prevent_reservation_overlap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_status VARCHAR(20);
BEGIN
    SELECT status
      INTO v_new_status
      FROM reservation
     WHERE reservation_id = NEW.reservation_id;

    IF v_new_status IS NULL THEN
        RAISE EXCEPTION
            'Reservation % does not exist.',
            NEW.reservation_id;
    END IF;

    -- Cancelled and completed reservations do not create a new active block.
    IF v_new_status NOT IN ('Pending', 'Confirmed') THEN
        RETURN NEW;
    END IF;

    -- Locks the relevant SPACE row, serializing concurrent booking attempts.
    PERFORM 1
      FROM space
     WHERE hotel_id = NEW.hotel_id
       AND space_no = NEW.space_no
     FOR UPDATE;

    IF EXISTS (
        SELECT 1
          FROM reservation_space rs
          JOIN reservation r
            ON r.reservation_id = rs.reservation_id
         WHERE rs.hotel_id = NEW.hotel_id
           AND rs.space_no = NEW.space_no
           AND r.status IN ('Pending', 'Confirmed')
           AND NEW.check_in_date < rs.check_out_date
           AND NEW.check_out_date > rs.check_in_date
           AND (
               TG_OP = 'INSERT'
               OR (rs.reservation_id, rs.hotel_id, rs.space_no)
                  <> (OLD.reservation_id, OLD.hotel_id, OLD.space_no)
           )
    ) THEN
        RAISE EXCEPTION
            'Space % at hotel % is already booked during % to %.',
            NEW.space_no,
            NEW.hotel_id,
            NEW.check_in_date,
            NEW.check_out_date;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_reservation_overlap
ON reservation_space;

CREATE TRIGGER trg_prevent_reservation_overlap
BEFORE INSERT OR UPDATE OF
    reservation_id,
    hotel_id,
    space_no,
    check_in_date,
    check_out_date
ON reservation_space
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_reservation_overlap();


-- Trigger 2: Only corporate clients may reserve conference spaces.
CREATE OR REPLACE FUNCTION fn_enforce_corporate_conference_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id BIGINT;
BEGIN
    IF EXISTS (
        SELECT 1
          FROM conference_space cs
         WHERE cs.hotel_id = NEW.hotel_id
           AND cs.space_no = NEW.space_no
    ) THEN
        SELECT customer_id
          INTO v_customer_id
          FROM reservation
         WHERE reservation_id = NEW.reservation_id;

        IF v_customer_id IS NULL THEN
            RAISE EXCEPTION
                'Reservation % does not exist.',
                NEW.reservation_id;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM corporate_client cc
             WHERE cc.customer_id = v_customer_id
        ) THEN
            RAISE EXCEPTION
                'Only CORPORATE_CLIENT customers may reserve CONFERENCE_SPACE entities. Customer % is not corporate.',
                v_customer_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_corporate_conference_booking
ON reservation_space;

CREATE TRIGGER trg_corporate_conference_booking
BEFORE INSERT OR UPDATE OF
    reservation_id,
    hotel_id,
    space_no
ON reservation_space
FOR EACH ROW
EXECUTE FUNCTION fn_enforce_corporate_conference_booking();


-- =========================================================
-- OPTIONAL VERIFICATION QUERIES
-- =========================================================

SELECT * FROM v_guest_reservation_summary
ORDER BY reservation_id, hotel_id, space_no;

SELECT * FROM v_hotel_occupancy_analysis
ORDER BY hotel_id, space_type;

SELECT * FROM v_service_revenue_analysis
ORDER BY service_id;

-- Expected failure: overlaps Reservation 1 in Hotel 1 / Space 101.
-- Run separately after creating a temporary valid reservation if desired.
--
-- INSERT INTO reservation
-- (reservation_id, booking_date, status, customer_id)
-- VALUES (100, CURRENT_DATE, 'Confirmed', 2);
--
-- INSERT INTO reservation_space
-- (reservation_id, hotel_id, space_no, agreed_nightly_rate,
--  check_in_date, check_out_date)
-- VALUES
-- (100, 1, '101', 3100.00, DATE '2026-08-11', DATE '2026-08-12');

-- Expected failure: individual Customer 1 tries to reserve conference space.
--
-- INSERT INTO reservation
-- (reservation_id, booking_date, status, customer_id)
-- VALUES (101, CURRENT_DATE, 'Confirmed', 1);
--
-- INSERT INTO reservation_space
-- (reservation_id, hotel_id, space_no, agreed_nightly_rate,
--  check_in_date, check_out_date)
-- VALUES
-- (101, 3, '901', 15000.00, DATE '2026-10-01', DATE '2026-10-02');
