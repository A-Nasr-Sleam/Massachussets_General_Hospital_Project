/*
1- The CODE and DISCRIPTION columns in the encounters and prosedures tables should have one to one cardinality
	But, the DISCRIPTION column have differnt values for the same code 
	there are (4 codes) in the prosedures
	and       (6 codes) in the encounters tables
	Having this issue they will be normalized to the most general description

	The description will be standardized to the sortest description for a single code 
	which is the most general


2-bronze.encounters, bronze.payers, and bronze.patients tables all was duplicated using the Id column.
  But the bronze.procedures does not have unique identifier so, it was duplicated based on START, PATIENT, and CODE
  As one patient can't have the same procedure at the same time more than once.


3-The durations of the procedures and encounters are calculated based on the difference between the START and END columns 
  in both tables, and both measured in minutes.
  The upper outliers in both tables were capped based on the IQR rules, The lower outliers were (less than 1) were replaced with 1


*/