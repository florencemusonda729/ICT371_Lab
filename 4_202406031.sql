-- ==========================================
-- SCENARIO 4: CAMPUS CLINIC MEDICINE DISPENSING
-- ==========================================

-- 1. Drop old tables to avoid "already exists" errors (Order matters due to foreign keys)
DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

-- 1. Create tables and insert data
CREATE TABLE medicines (
    med_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    stock_qty INT
);

CREATE TABLE dispensing_records (
    rec_id SERIAL PRIMARY KEY,
    student_no VARCHAR(20),
    med_id INT REFERENCES medicines(med_id),
    qty INT,
    status VARCHAR(20) DEFAULT 'Dispensed'
);

INSERT INTO medicines (name, stock_qty) VALUES 
('Paracetamol', 50),
('Ibuprofen', 5),
('Aspirin', 0);

-- 2. IF ELSIF ELSE to check stock
DO $$
DECLARE v_stock INT;
BEGIN
    SELECT stock_qty INTO v_stock FROM medicines WHERE med_id = 1;
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF v_stock < 10 THEN
        RAISE NOTICE 'Medicine is low on stock.';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR loops
DO $$
DECLARE counter INT := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Stock review day %', counter;
        counter := counter + 1;
    END LOOP;
    
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', i;
    END LOOP;
END $$;

-- 4 & 8. Create dispense_medicine procedure with EXCEPTION handling
CREATE OR REPLACE PROCEDURE dispense_medicine(p_student VARCHAR, p_med_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE v_stock INT;
BEGIN
    -- Requirement 8: Handle invalid input (negative quantity)
    IF p_qty < 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Cannot be negative.';
    END IF;

    SELECT stock_qty INTO v_stock FROM medicines WHERE med_id = p_med_id;
    
    IF v_stock >= p_qty THEN
        UPDATE medicines SET stock_qty = stock_qty - p_qty WHERE med_id = p_med_id;
        INSERT INTO dispensing_records (student_no, med_id, qty, status) VALUES (p_student, p_med_id, p_qty, 'Dispensed');
        RAISE NOTICE 'Medicine dispensed successfully to student %.', p_student;
    ELSE
        RAISE EXCEPTION 'Insufficient stock available.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error caught: %', SQLERRM;
END; $$;

-- 5. Call dispense_medicine (2 valid, 1 exceeding stock)
CALL dispense_medicine('S200', 1, 10); -- Valid (Paracetamol has 50)
CALL dispense_medicine('S201', 2, 2);  -- Valid (Ibuprofen has 5)
CALL dispense_medicine('S202', 3, 1);  -- Exceeds stock (Aspirin has 0)

-- Query tables to show changes after step 5
SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Create reverse_dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_rec_id INT)
LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR; v_qty INT; v_mid INT;
BEGIN
    SELECT status, qty, med_id INTO v_status, v_qty, v_mid FROM dispensing_records WHERE rec_id = p_rec_id;
    
    IF v_status = 'Dispensed' THEN
        UPDATE dispensing_records SET status = 'Reversed' WHERE rec_id = p_rec_id;
        UPDATE medicines SET stock_qty = stock_qty + v_qty WHERE med_id = v_mid;
        RAISE NOTICE 'Dispensing reversed. Stock restored.';
    ELSE
        RAISE NOTICE 'Already reversed or invalid. Stock not restored.';
    END IF;
END; $$;

-- Call reverse_dispensing twice for the same record (Rec ID 1)
CALL reverse_dispensing(1); -- First call (restores stock)
CALL reverse_dispensing(1); -- Second call (should say already reversed)

-- 7. Explicit cursor for low stock medicines
DO $$
DECLARE 
    cur_meds CURSOR FOR SELECT med_id, name, stock_qty FROM medicines WHERE stock_qty < 10;
    rec_med RECORD;
BEGIN
    OPEN cur_meds;
    LOOP
        FETCH cur_meds INTO rec_med;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Alert: % (%) has % units left.', rec_med.med_id, rec_med.name, rec_med.stock_qty;
    END LOOP;
    CLOSE cur_meds;
END $$;

-- 8. Try to dispense a negative quantity (Handled by EXCEPTION in procedure above)
CALL dispense_medicine('S203', 1, -5); 

-- 9. Final Query to show final stock and dispensing statuses
SELECT * FROM medicines;
SELECT * FROM dispensing_records;