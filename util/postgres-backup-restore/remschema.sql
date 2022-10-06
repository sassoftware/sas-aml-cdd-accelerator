CREATE OR REPLACE FUNCTION drop_all ()
   RETURNS VOID  AS
   $$
   DECLARE rec RECORD;
   BEGIN
       -- Get all the schemas
        FOR rec IN
        SELECT nspname FROM pg_catalog.pg_namespace WHERE (nspname != 'svi_alerts') and (nspname NOT LIKE 'pg_%') and (nspname != 'information_schema') and (nspname != 'public') and (nspname NOT LIKE 'dagentsrv%')
           LOOP
             EXECUTE 'DROP SCHEMA ' || rec.nspname || ' CASCADE';
           END LOOP;
           RETURN;
   END;
   $$ LANGUAGE plpgsql;

SELECT drop_all();
