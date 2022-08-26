-- FSC_ASSOCIATE_DIM --

INSERT INTO core.fsc_scd_columns
values ('FSC_ASSOCIATE_DIM','BRANCH_NUMBER','type2',2);

INSERT INTO core.fsc_scd_columns
values ('FSC_ASSOCIATE_DIM','BRANCH_NAME','type1',1);

-- FSC_ACCOUNT_DIM --

INSERT INTO core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id)
VALUES ('FSC_ACCOUNT_DIM','account_type_desc', 'type2', 82);

INSERT INTO core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id)
VALUES ('FSC_ACCOUNT_DIM','product_category_name', 'type1', 84);

INSERT INTO core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id)
VALUES ('FSC_ACCOUNT_DIM','account_open_date', 'type2', 66);

INSERT INTO core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id)
VALUES ('FSC_ACCOUNT_DIM','product_name', 'type2', 58);

-- FSC_BANK_DIM --

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_BANK_DIM','bank_address_1','type2',1);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_BANK_DIM','bank_name','type2',2);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_BANK_DIM','bank_swift_name','type1',9);

-- FSC_BRANCH_DIM --

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id)
values ('FSC_BRANCH_DIM','street_address_1','type2',4);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_BRANCH_DIM','branch_status_desc','type1',5);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_BRANCH_DIM','branch_name','type1',3);

-- FSC_ADDRESS_DIM --

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_ADDRESS_DIM','address_type_code','type2',6);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_ADDRESS_DIM','address_line_1_text','type2',7);

Insert into core.fsc_scd_columns(
scd_table, scd_column, scd_type, order_id) 
values ('FSC_ADDRESS_DIM','city_name','type1',8);

INSERT INTO core.fsc_scd_columns
values ('FSC_ADDRESS_DIM','POSTAL_CODE','type1',1);

INSERT INTO core.fsc_scd_columns
values ('FSC_ADDRESS_DIM','STATE_NAME','type2',2);

-- FSC_PARTY_DIM --

INSERT INTO core.fsc_scd_columns(
	scd_table, scd_column, scd_type, order_id)
	VALUES ('FSC_PARTY_DIM','party_name','type1',1);
INSERT INTO core.fsc_scd_columns(
	scd_table, scd_column, scd_type, order_id)
	VALUES ('FSC_PARTY_DIM','employer_name','type2',3);
