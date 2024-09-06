CREATE OR REPLACE PACKAGE BODY PKG_ORC IS
--
  FUNCTION SAVE_ITEM_LOC_SOH_SV(I_loc  IN     item_loc_soh.loc%TYPE)
    RETURN BOOLEAN IS
    --
    L_item          item_loc_soh.item%TYPE;
    L_loc           item_loc_soh.loc%TYPE;
    L_dept          item_loc_soh.dept%TYPE;
    L_unit_cost     item_loc_soh.unit_cost%TYPE;
    L_stock_on_hand item_loc_soh.stock_on_hand%TYPE;
    --
    CURSOR C_get_item_stock_soh (C_item item_loc_soh.item%TYPE,
                                 C_loc item_loc_soh.loc%TYPE) IS
    SELECT item,
           loc,
           dept,
           unit_cost,
           stock_on_hand
      FROM item_loc_soh
     WHERE item = C_item
       AND loc = C_loc;
    --
  BEGIN
    --
    IF I_loc IS NOT NULL THEN
      --
      FOR l IN (SELECT item,loc,dept,unit_cost,stock_on_hand
                  FROM item_loc_soh
                 WHERE loc = I_loc) LOOP
        --
        INSERT INTO item_loc_soh_sv (item,loc,dept,unit_cost,stock_on_hand,stock_value)
        VALUES (l.item, l.loc, l.dept, l.unit_cost, l.stock_on_hand, (l.unit_cost * l.stock_on_hand));
        --
      END LOOP;
      --
    ELSE
    /*
      FOR l IN (SELECT item,loc,dept,unit_cost,stock_on_hand
                  FROM item_loc_soh) LOOP
        --
        INSERT INTO item_loc_soh_sv (item,loc,dept,unit_cost,stock_on_hand,stock_value)
        VALUES (l.item, l.loc, l.dept, l.unit_cost, l.stock_on_hand, (l.unit_cost * l.stock_on_hand));
        --
      END LOOP;
    */
      --
      -- desativate index item_loc_soh
      --
      BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE idx_item_loc_soh_dept ON item_loc_soh DISABLE';
        EXECUTE IMMEDIATE 'ALTER TABLE idx_item_loc_soh_loc_dept ON item_loc_soh DISABLE';
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --
      INSERT /*+APPEND*/ INTO item_loc_soh_sv (item,loc,dept,unit_cost,stock_on_hand,stock_value)
      SELECT item,loc,dept,unit_cost,stock_on_hand,(unit_cost * stock_on_hand)
        FROM item_loc_soh;
      --
      -- activate index item_loc_soh
      --
      BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE idx_item_loc_soh_dept ON item_loc_soh REBUILD';
        EXECUTE IMMEDIATE 'ALTER TABLE idx_item_loc_soh_loc_dept ON item_loc_soh REBUILD';
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --
    END IF;
    --
    RETURN TRUE;
    --
  EXCEPTION
    WHEN OTHERS THEN
    --
    RETURN FALSE;
    --
  END SAVE_ITEM_LOC_SOH_SV;
--
  FUNCTION get_locations
    RETURN t_loc_tbl PIPELINED IS
  BEGIN
    --
    FOR r IN (SELECT loc, loc_desc FROM loc ORDER BY loc_desc) LOOP
      --
      PIPE ROW(t_loc_obj(r.loc, r.loc_desc));
      --
    END LOOP;
    --
  END get_locations;
--
  PROCEDURE extract_stock_data_to_csv IS
    -- Declare variables
    CURSOR c_loc IS 
        SELECT DISTINCT loc FROM item_loc_soh;

    CURSOR c_item_loc(p_loc NUMBER) IS
        SELECT item, dept, unit_cost, stock_on_hand, (unit_cost * stock_on_hand) AS stock_value
        FROM item_loc_soh
        WHERE loc = p_loc;

    v_file_handle UTL_FILE.file_type;
    v_line VARCHAR2(1000);
BEGIN
    -- Loop through each location
    FOR loc_rec IN c_loc LOOP
        -- Open the file for the current location
        v_file_handle := UTL_FILE.FOPEN('EXPORT_DIR', 'stock_data_loc_' || loc_rec.loc || '.csv', 'W');

        -- Write the header to the CSV file
        UTL_FILE.PUT_LINE(v_file_handle, 'Item,Dept,Unit_Cost,Stock_On_Hand,Stock_Value');

        -- Loop through the items for the current location
        FOR item_rec IN c_item_loc(loc_rec.loc) LOOP
            -- Prepare a CSV line for each row
            v_line := item_rec.item || ',' ||
                      item_rec.dept || ',' ||
                      TO_CHAR(item_rec.unit_cost, '999.999.999.999,0000') || ',' ||
                      TO_CHAR(item_rec.stock_on_hand, '999.999.999.999,0000') || ',' ||
                      TO_CHAR(item_rec.stock_value, '999.999.999.999,0000');
            
            -- Write the line to the CSV file
            UTL_FILE.PUT_LINE(v_file_handle, v_line);
        END LOOP;

        -- Close the file
        UTL_FILE.FCLOSE(v_file_handle);
    END LOOP;
    
    -- Exception handling
EXCEPTION
    WHEN OTHERS THEN
        -- Close the file if an error occurs
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
        RAISE;
END extract_stock_data_to_csv;
END PKG_ORC;
/