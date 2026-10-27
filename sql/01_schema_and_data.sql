BEGIN;

DROP TABLE IF EXISTS contract CASCADE;
DROP TABLE IF EXISTS maintenance_ticket CASCADE;
DROP TABLE IF EXISTS service_usage CASCADE;
DROP TABLE IF EXISTS service CASCADE;
DROP TABLE IF EXISTS reservation_space CASCADE;
DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS employee_phone CASCADE;
DROP TABLE IF EXISTS technician CASCADE;
DROP TABLE IF EXISTS manager CASCADE;
DROP TABLE IF EXISTS housekeeper CASCADE;
DROP TABLE IF EXISTS receptionist CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS luxury_room_amenity CASCADE;
DROP TABLE IF EXISTS conference_space CASCADE;
DROP TABLE IF EXISTS luxury_room CASCADE;
DROP TABLE IF EXISTS standard_room CASCADE;
DROP TABLE IF EXISTS space CASCADE;
DROP TABLE IF EXISTS corporate_client CASCADE;
DROP TABLE IF EXISTS individual_guest CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS hotel_phone CASCADE;
DROP TABLE IF EXISTS hotel CASCADE;

CREATE TABLE hotel (
    hotel_id BIGINT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    street VARCHAR(160) NOT NULL,
    city VARCHAR(80) NOT NULL,
    country VARCHAR(80) NOT NULL
);

CREATE TABLE hotel_phone (
    hotel_id BIGINT NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    PRIMARY KEY (hotel_id, phone_number),
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE CASCADE
);

CREATE TABLE customer (
    customer_id BIGINT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    phone VARCHAR(30),
    email VARCHAR(160),
    customer_type VARCHAR(20) NOT NULL,
    CHECK (customer_type IN ('Individual', 'Corporate'))
);

CREATE TABLE individual_guest (
    customer_id BIGINT PRIMARY KEY,
    loyalty_points INTEGER NOT NULL DEFAULT 0,
    date_of_birth DATE NOT NULL,
    CHECK (loyalty_points >= 0),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE corporate_client (
    customer_id BIGINT PRIMARY KEY,
    company_name VARCHAR(160) NOT NULL,
    tax_id VARCHAR(40) NOT NULL UNIQUE,
    credit_limit NUMERIC(12,2) NOT NULL DEFAULT 0,
    CHECK (credit_limit >= 0),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE space (
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    capacity INTEGER NOT NULL,
    base_nightly_rate NUMERIC(12,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    space_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (hotel_id, space_no),
    CHECK (capacity > 0),
    CHECK (base_nightly_rate >= 0),
    CHECK (status IN ('Available', 'Occupied', 'Maintenance', 'Inactive')),
    CHECK (space_type IN ('Standard', 'Luxury', 'Conference')),
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE RESTRICT
);

CREATE TABLE standard_room (
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    bed_count INTEGER NOT NULL,
    PRIMARY KEY (hotel_id, space_no),
    CHECK (bed_count > 0),
    FOREIGN KEY (hotel_id, space_no) REFERENCES space(hotel_id, space_no) ON DELETE CASCADE
);

CREATE TABLE luxury_room (
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    bed_count INTEGER NOT NULL,
    view_type VARCHAR(60) NOT NULL,
    PRIMARY KEY (hotel_id, space_no),
    CHECK (bed_count > 0),
    FOREIGN KEY (hotel_id, space_no) REFERENCES space(hotel_id, space_no) ON DELETE CASCADE
);

CREATE TABLE conference_space (
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    seating_capacity INTEGER NOT NULL,
    has_projector BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (hotel_id, space_no),
    CHECK (seating_capacity > 0),
    FOREIGN KEY (hotel_id, space_no) REFERENCES space(hotel_id, space_no) ON DELETE CASCADE
);

CREATE TABLE luxury_room_amenity (
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    amenity VARCHAR(100) NOT NULL,
    PRIMARY KEY (hotel_id, space_no, amenity),
    FOREIGN KEY (hotel_id, space_no) REFERENCES luxury_room(hotel_id, space_no) ON DELETE CASCADE
);

CREATE TABLE employee (
    employee_id BIGINT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    hire_date DATE NOT NULL,
    role VARCHAR(20) NOT NULL,
    hotel_id BIGINT NOT NULL,
    supervisor_id BIGINT,
    CHECK (role IN ('Receptionist', 'Housekeeper', 'Manager', 'Technician')),
    CHECK (supervisor_id IS NULL OR supervisor_id <> employee_id),
    FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE RESTRICT
);

CREATE TABLE receptionist (
    employee_id BIGINT PRIMARY KEY,
    shift_type VARCHAR(20) NOT NULL,
    CHECK (shift_type IN ('Morning', 'Evening', 'Night')),
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE
);

CREATE TABLE housekeeper (
    employee_id BIGINT PRIMARY KEY,
    assigned_floor INTEGER NOT NULL,
    CHECK (assigned_floor > 0),
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE
);

CREATE TABLE manager (
    employee_id BIGINT PRIMARY KEY,
    office_extension VARCHAR(20),
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE
);

CREATE TABLE technician (
    employee_id BIGINT PRIMARY KEY,
    specialty VARCHAR(100) NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE
);

ALTER TABLE employee
ADD CONSTRAINT fk_employee_supervisor
FOREIGN KEY (supervisor_id) REFERENCES manager(employee_id) ON DELETE SET NULL;

CREATE TABLE employee_phone (
    employee_id BIGINT NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    PRIMARY KEY (employee_id, phone_number),
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE
);

CREATE TABLE reservation (
    reservation_id BIGINT PRIMARY KEY,
    booking_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    customer_id BIGINT NOT NULL,
    CHECK (status IN ('Pending', 'Confirmed', 'Cancelled', 'Completed')),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE RESTRICT
);

CREATE TABLE reservation_space (
    reservation_id BIGINT NOT NULL,
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    agreed_nightly_rate NUMERIC(12,2) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    PRIMARY KEY (reservation_id, hotel_id, space_no),
    CHECK (agreed_nightly_rate >= 0),
    CHECK (check_out_date > check_in_date),
    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
    FOREIGN KEY (hotel_id, space_no) REFERENCES space(hotel_id, space_no) ON DELETE RESTRICT
);

CREATE TABLE service (
    service_id BIGINT PRIMARY KEY,
    description VARCHAR(160) NOT NULL,
    base_price NUMERIC(12,2) NOT NULL,
    CHECK (base_price >= 0)
);

CREATE TABLE service_usage (
    reservation_id BIGINT NOT NULL,
    usage_no INTEGER NOT NULL,
    usage_timestamp TIMESTAMP NOT NULL,
    quantity INTEGER NOT NULL,
    charged_price NUMERIC(12,2) NOT NULL,
    service_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    PRIMARY KEY (reservation_id, usage_no),
    CHECK (usage_no > 0),
    CHECK (quantity > 0),
    CHECK (charged_price >= 0),
    FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES service(service_id) ON DELETE RESTRICT,
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE RESTRICT
);

CREATE TABLE maintenance_ticket (
    ticket_id BIGINT PRIMARY KEY,
    reported_date DATE NOT NULL,
    description VARCHAR(300) NOT NULL,
    status VARCHAR(20) NOT NULL,
    hotel_id BIGINT NOT NULL,
    space_no VARCHAR(20) NOT NULL,
    technician_id BIGINT,
    CHECK (status IN ('Open', 'Assigned', 'In Progress', 'Resolved', 'Closed')),
    FOREIGN KEY (hotel_id, space_no) REFERENCES space(hotel_id, space_no) ON DELETE RESTRICT,
    FOREIGN KEY (technician_id) REFERENCES technician(employee_id) ON DELETE SET NULL
);

CREATE TABLE contract (
    contract_id BIGINT PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    terms TEXT NOT NULL,
    manager_id BIGINT NOT NULL,
    CHECK (end_date > start_date),
    FOREIGN KEY (manager_id) REFERENCES manager(employee_id) ON DELETE RESTRICT
);

INSERT INTO hotel (hotel_id, name, street, city, country) VALUES
(1, 'Ankara Grand Hotel', 'Ataturk Boulevard 120', 'Ankara', 'Türkiye'),
(2, 'Bosphorus Palace Hotel', 'Sahil Road 48', 'Istanbul', 'Türkiye'),
(3, 'Izmir Marina Hotel', 'Kordon Avenue 75', 'Izmir', 'Türkiye');

INSERT INTO hotel_phone (hotel_id, phone_number) VALUES
(1, '+90-312-555-0101'), (1, '+90-312-555-0102'),
(2, '+90-212-555-0201'), (3, '+90-232-555-0301');

INSERT INTO customer (customer_id, name, phone, email, customer_type) VALUES
(1, 'Ayse Yilmaz', '+90-530-100-0001', 'ayse@example.com', 'Individual'),
(2, 'Mehmet Kaya', '+90-530-100-0002', 'mehmet@example.com', 'Individual'),
(3, 'Elif Demir', '+90-530-100-0003', 'elif@example.com', 'Individual'),
(4, 'Can Arslan', '+90-530-100-0004', 'can@example.com', 'Individual'),
(5, 'Zeynep Aydin', '+90-530-100-0005', 'zeynep@example.com', 'Individual'),
(6, 'Burak Celik', '+90-530-100-0006', 'burak@example.com', 'Individual'),
(7, 'Selin Sahin', '+90-530-100-0007', 'selin@example.com', 'Individual'),
(8, 'Emre Koc', '+90-530-100-0008', 'emre@example.com', 'Individual'),
(9, 'Atlas Technology', '+90-312-700-1001', 'events@atlas.com', 'Corporate'),
(10, 'Nova Consulting', '+90-212-700-1002', 'office@nova.com', 'Corporate'),
(11, 'Orion Logistics', '+90-232-700-1003', 'meetings@orion.com', 'Corporate'),
(12, 'Mira Health', '+90-312-700-1004', 'admin@mirahealth.com', 'Corporate'),
(13, 'Pera Finance', '+90-212-700-1005', 'corporate@perafinance.com', 'Corporate');

INSERT INTO individual_guest (customer_id, loyalty_points, date_of_birth) VALUES
(1, 1200, DATE '1994-05-14'), (2, 450, DATE '1988-09-22'),
(3, 2200, DATE '1997-01-10'), (4, 0, DATE '1992-11-03'),
(5, 780, DATE '1985-07-30'), (6, 150, DATE '1999-04-18'),
(7, 3100, DATE '1990-12-12'), (8, 930, DATE '1996-06-25');

INSERT INTO corporate_client (customer_id, company_name, tax_id, credit_limit) VALUES
(9, 'Atlas Technology A.S.', 'TR-ATLAS-1001', 250000.00),
(10, 'Nova Consulting Ltd.', 'TR-NOVA-1002', 175000.00),
(11, 'Orion Logistics A.S.', 'TR-ORION-1003', 300000.00),
(12, 'Mira Health Group', 'TR-MIRA-1004', 220000.00),
(13, 'Pera Finance A.S.', 'TR-PERA-1005', 400000.00);

INSERT INTO space (hotel_id, space_no, capacity, base_nightly_rate, status, space_type) VALUES
(1, '101', 2, 3200.00, 'Available', 'Standard'),
(1, '102', 3, 3600.00, 'Available', 'Standard'),
(1, '201', 2, 5800.00, 'Available', 'Luxury'),
(1, '202', 4, 7200.00, 'Available', 'Luxury'),
(1, '901', 80, 18000.00, 'Available', 'Conference'),
(2, '101', 2, 4100.00, 'Available', 'Standard'),
(2, '102', 3, 4600.00, 'Available', 'Standard'),
(2, '201', 2, 7600.00, 'Available', 'Luxury'),
(2, '901', 120, 25000.00, 'Available', 'Conference'),
(3, '101', 2, 3500.00, 'Available', 'Standard'),
(3, '102', 2, 3900.00, 'Available', 'Standard'),
(3, '201', 3, 6500.00, 'Available', 'Luxury'),
(3, '901', 60, 15000.00, 'Available', 'Conference');

INSERT INTO standard_room (hotel_id, space_no, bed_count) VALUES
(1, '101', 1), (1, '102', 2), (2, '101', 1),
(2, '102', 2), (3, '101', 1), (3, '102', 2);

INSERT INTO luxury_room (hotel_id, space_no, bed_count, view_type) VALUES
(1, '201', 1, 'City View'), (1, '202', 2, 'Panoramic View'),
(2, '201', 1, 'Bosphorus View'), (3, '201', 2, 'Sea View');

INSERT INTO conference_space (hotel_id, space_no, seating_capacity, has_projector) VALUES
(1, '901', 80, TRUE), (2, '901', 120, TRUE), (3, '901', 60, TRUE);

INSERT INTO luxury_room_amenity (hotel_id, space_no, amenity) VALUES
(1, '201', 'Jacuzzi'), (1, '201', 'Minibar'),
(1, '202', 'Private Terrace'), (1, '202', 'Jacuzzi'),
(2, '201', 'Executive Lounge Access'), (2, '201', 'Minibar'),
(3, '201', 'Sea View Balcony'), (3, '201', 'Minibar');

INSERT INTO employee (employee_id, name, hire_date, role, hotel_id, supervisor_id) VALUES
(1, 'Aylin Erdem', DATE '2018-03-12', 'Manager', 1, NULL),
(2, 'Mert Aksoy', DATE '2023-06-01', 'Receptionist', 1, NULL),
(3, 'Derya Polat', DATE '2022-02-15', 'Housekeeper', 1, NULL),
(4, 'Kerem Uslu', DATE '2021-09-10', 'Technician', 1, NULL),
(5, 'Seda Gunes', DATE '2017-11-20', 'Manager', 2, NULL),
(6, 'Okan Yildiz', DATE '2024-01-05', 'Receptionist', 2, NULL),
(7, 'Tolga Inan', DATE '2020-05-17', 'Technician', 2, NULL),
(8, 'Nihan Tas', DATE '2019-08-08', 'Manager', 3, NULL),
(9, 'Pelin Kurt', DATE '2022-10-03', 'Housekeeper', 3, NULL),
(10, 'Hakan Efe', DATE '2021-04-22', 'Technician', 3, NULL);

INSERT INTO receptionist (employee_id, shift_type) VALUES (2, 'Morning'), (6, 'Evening');
INSERT INTO housekeeper (employee_id, assigned_floor) VALUES (3, 2), (9, 2);
INSERT INTO manager (employee_id, office_extension) VALUES (1, '1101'), (5, '2101'), (8, '3101');
INSERT INTO technician (employee_id, specialty) VALUES
(4, 'Electrical Systems'), (7, 'HVAC Systems'), (10, 'Plumbing Systems');

UPDATE employee SET supervisor_id = 1 WHERE employee_id IN (2,3,4);
UPDATE employee SET supervisor_id = 5 WHERE employee_id IN (6,7);
UPDATE employee SET supervisor_id = 8 WHERE employee_id IN (9,10);

INSERT INTO employee_phone (employee_id, phone_number) VALUES
(1, '+90-532-200-0001'), (2, '+90-532-200-0002'),
(4, '+90-532-200-0004'), (5, '+90-532-200-0005'),
(7, '+90-532-200-0007'), (8, '+90-532-200-0008'),
(10, '+90-532-200-0010');

INSERT INTO reservation (reservation_id, booking_date, status, customer_id) VALUES
(1, DATE '2026-07-15', 'Confirmed', 1),
(2, DATE '2026-07-16', 'Confirmed', 2),
(3, DATE '2026-07-17', 'Confirmed', 3),
(4, DATE '2026-07-18', 'Confirmed', 4),
(5, DATE '2026-06-20', 'Completed', 5),
(6, DATE '2026-06-22', 'Completed', 6),
(7, DATE '2026-07-20', 'Confirmed', 7),
(8, DATE '2026-07-21', 'Confirmed', 8),
(9, DATE '2026-07-22', 'Confirmed', 1),
(10, DATE '2026-07-23', 'Confirmed', 2),
(11, DATE '2026-07-25', 'Confirmed', 9),
(12, DATE '2026-07-26', 'Confirmed', 10),
(13, DATE '2026-07-27', 'Confirmed', 11),
(14, DATE '2026-07-28', 'Confirmed', 12),
(15, DATE '2026-07-29', 'Confirmed', 13);

INSERT INTO reservation_space
(reservation_id, hotel_id, space_no, agreed_nightly_rate, check_in_date, check_out_date) VALUES
(1, 1, '101', 3000.00, DATE '2026-08-10', DATE '2026-08-13'),
(1, 1, '102', 3400.00, DATE '2026-08-10', DATE '2026-08-13'),
(2, 1, '201', 5500.00, DATE '2026-08-14', DATE '2026-08-16'),
(3, 2, '101', 3900.00, DATE '2026-08-10', DATE '2026-08-12'),
(3, 2, '102', 4400.00, DATE '2026-08-10', DATE '2026-08-12'),
(4, 2, '201', 7300.00, DATE '2026-08-15', DATE '2026-08-18'),
(5, 3, '101', 3300.00, DATE '2026-07-10', DATE '2026-07-12'),
(6, 3, '102', 3700.00, DATE '2026-07-13', DATE '2026-07-15'),
(7, 3, '201', 6200.00, DATE '2026-08-20', DATE '2026-08-23'),
(8, 1, '202', 6900.00, DATE '2026-08-18', DATE '2026-08-20'),
(9, 2, '101', 4000.00, DATE '2026-08-20', DATE '2026-08-22'),
(10, 3, '102', 3800.00, DATE '2026-08-25', DATE '2026-08-27'),
(11, 1, '901', 17500.00, DATE '2026-09-01', DATE '2026-09-02'),
(12, 2, '901', 24000.00, DATE '2026-09-03', DATE '2026-09-04'),
(12, 2, '201', 7400.00, DATE '2026-09-03', DATE '2026-09-04'),
(13, 3, '901', 14500.00, DATE '2026-09-05', DATE '2026-09-06'),
(14, 1, '901', 17800.00, DATE '2026-09-07', DATE '2026-09-08'),
(15, 2, '901', 24500.00, DATE '2026-09-09', DATE '2026-09-10');

INSERT INTO service (service_id, description, base_price) VALUES
(1, 'Dining', 650.00), (2, 'Spa Session', 1400.00),
(3, 'Airport Transfer', 1800.00), (4, 'Laundry', 350.00);

INSERT INTO service_usage
(reservation_id, usage_no, usage_timestamp, quantity, charged_price, service_id, employee_id) VALUES
(1, 1, TIMESTAMP '2026-08-10 19:30:00', 2, 1200.00, 1, 2),
(1, 2, TIMESTAMP '2026-08-11 10:00:00', 1, 1350.00, 2, 3),
(1, 3, TIMESTAMP '2026-08-13 08:00:00', 1, 1750.00, 3, 4),
(1, 4, TIMESTAMP '2026-08-12 14:00:00', 3, 900.00, 4, 3),
(2, 1, TIMESTAMP '2026-08-14 20:00:00', 1, 650.00, 1, 2),
(3, 1, TIMESTAMP '2026-08-11 11:00:00', 1, 1400.00, 2, 6),
(4, 1, TIMESTAMP '2026-08-18 07:30:00', 1, 1800.00, 3, 7),
(5, 1, TIMESTAMP '2026-07-10 19:00:00', 2, 1250.00, 1, 9),
(6, 1, TIMESTAMP '2026-07-14 09:00:00', 2, 600.00, 4, 9),
(7, 1, TIMESTAMP '2026-08-21 15:00:00', 1, 1400.00, 2, 10),
(8, 1, TIMESTAMP '2026-08-18 21:00:00', 1, 650.00, 1, 2),
(9, 1, TIMESTAMP '2026-08-21 13:00:00', 2, 700.00, 4, 6),
(10, 1, TIMESTAMP '2026-08-27 06:30:00', 1, 1800.00, 3, 10);

INSERT INTO maintenance_ticket
(ticket_id, reported_date, description, status, hotel_id, space_no, technician_id) VALUES
(1, DATE '2026-07-30', 'Air conditioner produces unusual noise.', 'Open', 1, '102', 4),
(2, DATE '2026-07-15', 'Conference projector connection failure.', 'Resolved', 2, '901', 7),
(3, DATE '2026-07-28', 'Bathroom water pressure is below normal.', 'In Progress', 3, '201', 10);

INSERT INTO contract (contract_id, start_date, end_date, terms, manager_id) VALUES
(1, DATE '2026-01-01', DATE '2026-12-31', 'Annual catering supplier agreement.', 1),
(2, DATE '2026-02-01', DATE '2027-01-31', 'Conference technology maintenance agreement.', 5),
(3, DATE '2026-03-01', DATE '2027-02-28', 'Laundry service partnership agreement.', 8);

COMMIT;
