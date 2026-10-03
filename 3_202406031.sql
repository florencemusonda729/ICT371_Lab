-- ==========================================
-- SCENARIO 3: STUDENT HOSTEL ROOM ALLOCATION
-- ==========================================

-- 1. Drop old tables to avoid "already exists" errors (Order matters due to foreign keys)
DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

-- 1. Create tables and insert data
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10),
    available_beds INT
);

CREATE TABLE allocations (
    alloc_id SERIAL PRIMARY KEY,
    student_no VARCHAR(20),
    room_id INT REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) DEFAULT 'Allocated'
);

INSERT INTO hostel_rooms (room_number, available_beds) VALUES 
('R101', 3),
('R102', 1),
('R103', 0);

-- 2. IF ELSIF ELSE to check room capacity
DO $$
DECLARE v_beds INT;
BEGIN
    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE room_id = 1;
    IF v_beds = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF v_beds = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE 'Room has several spaces.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR loops
DO $$
DECLARE counter INT := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', counter;
        counter := counter + 1;
    END LOOP;
    
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check %', i;
    END LOOP;
END $$;

-- 4 & 8. Create allocate_room procedure with EXCEPTION handling
CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_avail INT;
BEGIN
    -- Requirement 8: Handle invalid input (blank student number)
    IF p_student IS NULL OR trim(p_student) = '' THEN
        RAISE EXCEPTION 'Invalid student number: Cannot be blank.';
    END IF;

    SELECT available_beds INTO v_avail FROM hostel_rooms WHERE room_id = p_room_id;
    
    IF v_avail > 0 THEN
        UPDATE hostel_rooms SET available_beds = available_beds - 1 WHERE room_id = p_room_id;
        INSERT INTO allocations (student_no, room_id, status) VALUES (p_student, p_room_id, 'Allocated');
        RAISE NOTICE 'Allocation successful for student %.', p_student;
    ELSE
        RAISE EXCEPTION 'Room is full.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error caught: %', SQLERRM;
END; $$;

-- 5. Call allocate_room (2 valid, 1 to a full room)
CALL allocate_room('S100', 1); -- Valid (R101 has 3 beds)
CALL allocate_room('S101', 2); -- Valid (R102 has 1 bed)
CALL allocate_room('S102', 3); -- Full room (R103 has 0 beds)

-- Query tables to show changes after step 5
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Create check_out procedure
CREATE OR REPLACE PROCEDURE check_out(p_alloc_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_rid INT;
BEGIN
    SELECT status, room_id INTO v_status, v_rid FROM allocations WHERE alloc_id = p_alloc_id;
    
    IF v_status = 'Allocated' THEN
        UPDATE allocations SET status = 'Checked Out' WHERE alloc_id = p_alloc_id;
        UPDATE hostel_rooms SET available_beds = available_beds + 1 WHERE room_id = v_rid;
        RAISE NOTICE 'Check out successful. Bed space released.';
    ELSE
        RAISE NOTICE 'Already checked out or invalid. No bed space released.';
    END IF;
END; $$;

-- Call check_out twice for the same allocation (Alloc ID 1)
CALL check_out(1); -- First call (releases bed space)
CALL check_out(1); -- Second call (should say already checked out)

-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE 
    cur_rooms CURSOR FOR SELECT room_id, room_number, available_beds FROM hostel_rooms WHERE available_beds <= 1;
    rec_room RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec_room;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Availability: Room % (%) has % beds left.', rec_room.room_id, rec_room.room_number, rec_room.available_beds;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- 8. Attempt allocation with a blank student number (Handled by EXCEPTION in procedure above)
CALL allocate_room('', 1); 

-- 9. Final Query to show final available spaces and allocation statuses
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;