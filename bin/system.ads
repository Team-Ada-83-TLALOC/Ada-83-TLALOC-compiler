					------
package					SYSTEM
is					------

  type NAME is (X86_64);

  SYSTEM_NAME		:constant NAME	:= X86_64;						-- Intel 64 bits
  STORAGE_UNIT		:constant		:= 8;
  MEMORY_SIZE		:constant		:= 2**48-1;						-- 48 bits d'adresse effective 256 To
  MAX_INT			:constant		:= 16#7FFFFFFFFFFFFFFF#;					-- 2**63-1 Evitement des debordements
  MIN_INT			:constant		:= -16#7FFFFFFFFFFFFFFF# - 1;					-- -(2**63) Evitement des debordements
  MAX_DIGITS		:constant		:= 15;							-- Pour virgule flottante
  MAX_MANTISSA		:constant		:= 63;							-- Pour virgule fixe
  FINE_DELTA		:constant		:= 2.0**(-63);
  TICK			:constant		:= 1.0**(-6);

  subtype PRIORITY		is INTEGER range 0 .. 10;

  subtype ADDRESS		is STANDARD._address;
  NULL_ADDRESS		:constant ADDRESS	:= 0;

   --  Following allows test for predefined SYSTEM withed
   --  (_SYSTEM is visible if it is)
   package _SYSTEM  renames SYSTEM;

	------
end	SYSTEM;
	------
