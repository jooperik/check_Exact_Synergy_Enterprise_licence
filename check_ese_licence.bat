@ECHO OFF

:: GET PARAMETERS
SET DBHOSTNAME=%1
SET DBNAME=%2
SET DBUSER=%3
SET DBPASS=%4
SET TRESHOLD=%5

:: GET ExpirationDate FROM DB
CALL SQLCMD.exe -S %DBHOSTNAME% -d %DBNAME% -U %DBUSER% -P %DBPASS% -Q "SET NOCOUNT ON;SELECT ExpirationDate FROM dbo.ExactLicense" -h -1 > %TMP%.\temp.txt
SET /p diff= < %TMP%.\temp.txt
DEL %TMP%.\temp.txt

:: GET RID OF TIME
FOR /F "tokens=1,2 delims=. " %%a IN ("%diff%") DO ( SET datum=%%a )

:: CONVERT FROM YYYY/MM/DD TO DD.MM.YYYY
SET "yyyy=%datum:~0,4%"
SET "mm=%datum:~5,2%"
SET "dd=%datum:~8,2%"
SET "expiry_date=%dd%.%mm%.%yyyy%"

:: COUNT DAYS LEFT TO EXPIRATION DATE
CALL :DATE_DIFF %expire_date% > %TMP%.\temp.txt
SET /p DateDiff= < %TMP%.\temp.txt
DEL %TMP%.\temp.txt

:: FORMAT day/days
SET Days=dny
IF %DateDiff% EQU 1 SET Days=den
IF %DateDiff% GEQ 5 SET Days=dni

IF /I %DateDiff% GEQ %TRESHOLD% ( GOTO OK
) ELSE ( 
	IF /I %DateDiff% LEQ 0 ( GOTO CRITICAL
	) ELSE ( GOTO WARNING )
)


:OK
:: Licence expires in ...
ECHO OK: Licence vyprsi za %DateDiff% %Days%.
EXIT 0

:WARNING
:: Licence expires in ...
ECHO WARNING: Licence vyprsi za %DateDiff% %Days%.
EXIT 1

:CRITICAL
:: Licence expired!
ECHO CRITICAL: Licence vyprsela!
EXIT 2


:DATE_DIFF
::===================================::
::   -         DateDiff          -   ::
::   -           MAIN            -   ::
::===================================::

:: Check the Windows version
IF NOT "%OS%"=="Windows_NT" GOTO Syntax
SETLOCAL

:: Read the Date format from the registry
CALL :ReadDateFormat

:: Check if the first date is valid
(ECHO.%1) | FINDSTR /R /B /C:"[0-9]*\%sDate%[0-9]*\%sDate%[0-9]*" >NUL
IF ERRORLEVEL 1 (
	ECHO Error: %1 is not a valid date
	ECHO.
	GOTO Syntax
)

:: Use today if no second date was specified
IF "%~2"=="" (
	FOR %%A IN (%Date%) DO SET Date2=%%A
) ELSE (
	SET Date2=%2
)

:: Check if the second date is valid
(ECHO.%Date2%) | FINDSTR /R /B /C:"[0-9]*\%sDate%[0-9]*\%sDate%[0-9]*" >NUL
IF ERRORLEVEL 1 (
	ECHO Error: %Date2% is not a valid date
	ECHO.
	GOTO Syntax
)

:: Parse the first date
CALL :ParseDate %1

:: Convert the parsed Gregorian date to Julian
CALL :JDate %GYear% %GMonth% %GDay%

:: Save the resulting Julian date
SET JDate1=%JDate%

:: Parse the second date
CALL :ParseDate %Date2%

:: Convert the parsed Gregorian date to Julian
CALL :JDate %GYear% %GMonth% %GDay%

:: Calculate the absolute value of the difference in days
IF %JDate% GTR %JDate1% (
	SET /A DateDiff = %JDate% - %JDate1%
) ELSE (
	SET /A DateDiff = %JDate1% - %JDate%
)

:: Prefix value with a minus sign if negative
IF %JDate% GTR %JDate1% SET DateDiff=-%DateDiff%

ECHO %DateDiff%
GOTO:EOF

::===================================::
::   -          DateDiff         -   ::
::   -        SUBROUTINES        -   ::
::===================================::
:JDate
:: Convert date to Julian
:: Arguments : YYYY MM DD
:: Returns   : Julian date
::
:: First strip leading zeroes; a logical error in this
:: routine was corrected with help from Alexander Shapiro
SET MM=%2
SET DD=%3
IF 1%MM% LSS 110 SET MM=%MM:~1%
IF 1%DD% LSS 110 SET DD=%DD:~1%
::
:: Algorithm based on Fliegel-Van Flandern
:: algorithm from the Astronomical Almanac,
:: provided by Doctor Fenton on the Math Forum
:: (http://mathforum.org/library/drmath/view/51907.html),
:: and converted to batch code by Ron Bakowski.
SET /A Month1 = ( %MM% - 14 ) / 12
SET /A Year1  = %1 + 4800
SET /A JDate  = 1461 * ( %Year1% + %Month1% ) / 4 + 367 * ( %MM% - 2 -12 * %Month1% ) / 12 - ( 3 * ( ( %Year1% + %Month1% + 100 ) / 100 ) ) / 4 + %DD% - 32075
FOR %%A IN (Month1 Year1) DO SET %%A=
GOTO:EOF 


:ParseDate
:: Parse (Gregorian) date depending on registry's date format settings
:: Argument : Gregorian date in local date format,
:: Requires : sDate (local date separator), iDate (local date format number)
:: Returns  : GYear (4-digit year), GMonth (2-digit month), GDay (2-digit day)
::
IF %iDate%==0 FOR /F "TOKENS=1-3 DELIMS=%sDate%" %%A IN ('ECHO.%1') DO (
	SET GYear=%%C
	SET GMonth=%%A
	SET GDay=%%B
)
IF %iDate%==1 FOR /F "TOKENS=1-3 DELIMS=%sDate%" %%A IN ('ECHO.%1') DO (
	SET GYear=%%C
	SET GMonth=%%B
	SET GDay=%%A
)
IF %iDate%==2 FOR /F "TOKENS=1-3 DELIMS=%sDate%" %%A IN ('ECHO.%1') DO (
	SET GYear=%%A
	SET GMonth=%%B
	SET GDay=%%C
)
GOTO:EOF

:ReadDateFormat
:: Read the Date format from the registry.
:: Arguments : none
:: Returns   : sDate (separator), iDate (date format number)
::
:: First, export registry settings to a temporary file:
START /W REGEDIT /E "%TEMP%.\_TEMP.REG" "HKEY_CURRENT_USER\Control Panel\International"
:: Now, read the exported data:
FOR /F "tokens=1* delims==" %%A IN ('TYPE "%TEMP%.\_TEMP.REG" ^| FIND /I "iDate"') DO SET iDate=%%B
FOR /F "tokens=1* delims==" %%A IN ('TYPE "%TEMP%.\_TEMP.REG" ^| FIND /I "sDate"') DO SET sDate=%%B
:: Remove the temporary file:
DEL "%TEMP%.\_TEMP.REG"
:: Remove quotes from the data read:
:: SET iDate=%iDate:"=%
FOR %%A IN (%iDate%) DO SET iDate=%%~A
:: SET sDate=%sDate:"=%
FOR %%A IN (%sDate%) DO SET sDate=%%~A
GOTO:EOF
