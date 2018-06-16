-- FUNCTION: public.get_nextsequence(integer)

-- DROP FUNCTION public.get_nextsequence(integer);

CREATE OR REPLACE FUNCTION public.get_nextsequence(
	mycode integer)
    RETURNS TABLE(sequenceid integer, sequencename text)
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
    ROWS 1000.0
AS $function$

Declare 
mySequenceID 		varchar(5);
myImplementation	varchar(40);
myNextSequence		varchar(250); 
strSQLStatement		varchar(250);
strPrefix			varchar(20);
strDay				varchar(20);
strMonth			varchar(20);
strYear				varchar(20);
sequenceID			INT;

BEGIN
	SELECT ID, IMPLEMENTATION, PREFIX  from ir_sequence where ID = myCode INTO mySequenceID, myImplementation, strPrefix;
	IF myImplementation = 'standard' THEN 
		mySequenceID = LPAD(mySequenceID,3,'0');
		strSQLStatement := 'Select nextval(''ir_sequence_' || mySequenceID || ''')' ;
		EXECUTE strSQLStatement INTO myNextSequence;
	ELSE
		SELECT number_next FROM ir_sequence WHERE id=myCode FOR UPDATE NOWAIT INTO myNextSequence;
		UPDATE ir_sequence SET number_next=number_next+number_increment WHERE id=myCode;
	END IF;
	sequenceID = myNextSequence;

	--IF returnValue = 'NAME' THEN
	SELECT EXTRACT(DAY FROM TIMESTAMP 'now') INTO strDay;
	SELECT EXTRACT(MONTH FROM TIMESTAMP 'now') INTO strMonth;
	SELECT EXTRACT(YEAR FROM TIMESTAMP 'now') INTO strYear;
	strPrefix = replace(strPrefix,'%(day)s',strDay);
	strPrefix = replace(strPrefix,'%(month)s',strMonth);
	strPrefix = replace(strPrefix,'%(year)s',strYear);
	myNextSequence = strPrefix || myNextSequence;
	--END IF;

	sequenceName = myNextSequence;
	RETURN QUERY SELECT sequenceID, sequenceName;
END;

$function$;

ALTER FUNCTION public.get_nextsequence(integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_nextsequence(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_nextsequence(integer) TO odoo;



