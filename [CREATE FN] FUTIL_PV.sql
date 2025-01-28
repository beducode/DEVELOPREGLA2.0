CREATE OR REPLACE FUNCTION FUTIL_PV(
	I DOUBLE PRECISION,
	N DOUBLE PRECISION,
	PMT DOUBLE PRECISION)
    RETURNS NUMERIC
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    PV DECIMAL(32, 6);
BEGIN
    SELECT PMT * (1.00 / POWER(1.00 + I, N)) INTO PV;
    RETURN PV;
END;
$BODY$;
