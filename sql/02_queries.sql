
-- =========================================================
-- BIL 372 - Database Systems Final Project
-- 3.6.5 Basic and Advanced SQL Queries
-- =========================================================

-- Query 1 - Basic Selection and Projection
-- Available luxury spaces
SELECT
    hotel_id,
    space_no,
    capacity,
    base_nightly_rate
FROM space
WHERE space_type = 'Luxury'
  AND status = 'Available'
ORDER BY hotel_id, space_no;


-- Query 2 - Three-Table Join
-- Customers, reservations, and booked spaces
SELECT
    c.customer_id,
    c.name AS customer_name,
    r.reservation_id,
    r.status AS reservation_status,
    rs.hotel_id,
    rs.space_no,
    rs.check_in_date,
    rs.check_out_date
FROM customer c
JOIN reservation r
  ON r.customer_id = c.customer_id
JOIN reservation_space rs
  ON rs.reservation_id = r.reservation_id
ORDER BY r.reservation_id, rs.hotel_id, rs.space_no;


-- Query 3 - Outer Join
-- All employees, including those with no service usage
SELECT
    e.employee_id,
    e.name AS employee_name,
    e.role,
    COUNT(su.usage_no) AS service_usage_count
FROM employee e
LEFT JOIN service_usage su
  ON su.employee_id = e.employee_id
GROUP BY
    e.employee_id,
    e.name,
    e.role
ORDER BY e.employee_id;


-- Query 4 - Aggregate Function with GROUP BY
-- Service usage and revenue summary
SELECT
    s.service_id,
    s.description AS service_name,
    COUNT(su.usage_no) AS usage_record_count,
    COALESCE(SUM(su.quantity), 0) AS total_quantity,
    COALESCE(SUM(su.charged_price), 0) AS total_revenue
FROM service s
LEFT JOIN service_usage su
  ON su.service_id = s.service_id
GROUP BY
    s.service_id,
    s.description
ORDER BY s.service_id;


-- Query 5 - HAVING
-- Customers with more than one reservation
SELECT
    c.customer_id,
    c.name AS customer_name,
    COUNT(r.reservation_id) AS reservation_count
FROM customer c
JOIN reservation r
  ON r.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.name
HAVING COUNT(r.reservation_id) > 1
ORDER BY reservation_count DESC, c.customer_id;


-- Query 6 - Nested Query
-- Service usages charged above the average charged price
SELECT
    su.reservation_id,
    su.usage_no,
    s.description AS service_name,
    su.quantity,
    su.charged_price
FROM service_usage su
JOIN service s
  ON s.service_id = su.service_id
WHERE su.charged_price > (
    SELECT AVG(charged_price)
    FROM service_usage
)
ORDER BY su.charged_price DESC;


-- Query 7 - Correlated EXISTS
-- Hotels with at least one unresolved maintenance ticket
SELECT
    h.hotel_id,
    h.name AS hotel_name,
    h.city
FROM hotel h
WHERE EXISTS (
    SELECT 1
    FROM maintenance_ticket mt
    WHERE mt.hotel_id = h.hotel_id
      AND mt.status IN ('Open', 'Assigned', 'In Progress')
)
ORDER BY h.hotel_id;


-- Query 8 - Division-Style Query with EXCEPT
-- Customers who used every service type
SELECT
    c.customer_id,
    c.name AS customer_name
FROM customer c
WHERE NOT EXISTS (
    SELECT service_id
    FROM service

    EXCEPT

    SELECT su.service_id
    FROM reservation r
    JOIN service_usage su
      ON su.reservation_id = r.reservation_id
    WHERE r.customer_id = c.customer_id
)
ORDER BY c.customer_id;
