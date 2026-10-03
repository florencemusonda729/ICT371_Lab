-- ==========================================
-- SCENARIO 2: COMPUTER LABORATORY RESERVATIONS
-- ==========================================

-- 1. Drop old tables to avoid "already exists" errors (Order matters due to foreign keys)
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

-- 1. Create tables and insert data
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100),
    available_workstations INT
);

CREATE TABLE reservations (
    res_id SERIAL PRIMARY KEY,
    lecturer VARCHAR(100),
    session_id INT REFERENCES lab_sessions(session_id),
    workstations INT,
    status VARCHAR(20) DEFAULT 'Active'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES 
('Database Practical', 30),
('Networks Lab', 5),
('Security Workshop', 0);

-- 2. IF ELSIF ELSE to check capacity
DO $$
DECLARE v_ws INT;
BEGIN
    SELECT available_workstations INTO v_ws FROM lab_sessions WHERE session_id = 1;
    IF v_ws = 0 THEN
        RAISE NOTICE 'Session 1 is full.';
    ELSIF v_ws < 10 THEN
        RAISE NOTICE 'Session 1 is nearly full.';
    ELSE
        RAISE NOTICE 'Session 1 has enough workstations.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR loops
DO $$
DECLARE counter INT := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', counter;
        counter := counter + 1;
    END LOOP;
    
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', i;
    END LOOP;
END $$;

-- 4 & 8. Create reserve_workstations procedure with EXCEPTION handling
CREATE OR REPLACE PROCEDURE reserve_workstations(p_lecturer VARCHAR, p_session_id INT, p_ws INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    -- Requirement 8: Handle invalid quantity (zero or negative)
    IF p_ws <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Must be greater than zero.';
    END IF;

    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = p_session_id;
    
    IF v_avail >= p_ws THEN
        UPDATE lab_sessions SET available_workstations = available_workstations - p_ws WHERE session_id = p_session_id;
        INSERT INTO reservations (lecturer, session_id, workstations, status) VALUES (p_lecturer, p_session_id, p_ws, 'Active');
        RAISE NOTICE 'Reservation recorded successfully for %.', p_lecturer;
    ELSE
        RAISE EXCEPTION 'Not enough workstations available.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error caught: %', SQLERRM;
END; $$;

-- 5. Call reserve_workstations (2 valid, 1 exceeding capacity)
CALL reserve_workstations('Dr. Smith', 1, 10); -- Valid (30 available)
CALL reserve_workstations('Dr. Jones', 2, 3);  -- Valid (5 available)
CALL reserve_workstations('Dr. Brown', 3, 1);  -- Exceeds capacity (0 available)

-- Query tables to show changes after step 5
SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Create cancel_reservation procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_res_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_ws INT; v_sid INT;
BEGIN
    SELECT status, workstations, session_id INTO v_status, v_ws, v_sid FROM reservations WHERE res_id = p_res_id;
    
    IF v_status = 'Active' THEN
        UPDATE reservations SET status = 'Cancelled' WHERE res_id = p_res_id;
        UPDATE lab_sessions SET available_workstations = available_workstations + v_ws WHERE session_id = v_sid;
        RAISE NOTICE 'Reservation cancelled. Workstations released.';
    ELSE
        RAISE NOTICE 'Reservation already cancelled or invalid. No workstations released.';
    END IF;
END; $$;

-- Call cancel_reservation twice for the same reservation (Res ID 1)
CALL cancel_reservation(1); -- First call (releases workstations)
CALL cancel_reservation(1); -- Second call (should say already cancelled)

-- 7. Explicit cursor for low availability
DO $$
DECLARE 
    cur_sessions CURSOR FOR SELECT session_id, session_name, available_workstations FROM lab_sessions WHERE available_workstations < 10;
    rec_session RECORD;
BEGIN
    OPEN cur_sessions;
    LOOP
        FETCH cur_sessions INTO rec_session;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Availability: Session % (%) has % workstations left.', rec_session.session_id, rec_session.session_name, rec_session.available_workstations;
    END LOOP;
    CLOSE cur_sessions;
END $$;

-- 8. Try to reserve zero workstations (Handled by EXCEPTION in procedure above)
CALL reserve_workstations('Dr. White', 1, 0); 

-- 9. Final Query to show final availability and statuses
SELECT * FROM lab_sessions;
SELECT * FROM reservations;