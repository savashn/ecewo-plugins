@echo off
setlocal

set "BASE_DIR=%~dp0"

echo ecewo - Build Script for Windows
echo 2025 (c) Savas Sahin ^<savashn^>
echo.

REM Define repository information
set "REPO=https://github.com/savashn/ecewo"

REM Initialize flags and branch
set "RUN=0"
set "REBUILD=0"
set "UPDATE=0"
set "MIGRATE=0"
set "INSTALL=0"

REM Parse command line arguments
:parse_args
if "%~1"=="" goto after_parse
if /i "%~1"=="/run" set "RUN=1"
if /i "%~1"=="/rebuild" set "REBUILD=1"
if /i "%~1"=="/update" set "UPDATE=1"
if /i "%~1"=="/migrate" set "MIGRATE=1"
if /i "%~1"=="/install" set "INSTALL=1"
shift
goto parse_args
:after_parse

REM Check if no parameters were provided
if "%RUN%%REBUILD%%UPDATE%%MIGRATE%%INSTALL%"=="000000" (
    echo No parameters specified. Please use one of the following:
    echo ==============================================================================
    echo   /run         # Build and run the project
    echo   /rebuild     # Build from scratch
    echo   /update      # Update Ecewo
    echo   /migrate     # Migrate the "CMakeLists.txt" file
    echo   /install     # Install packages
    echo ==============================================================================
    exit /b 0
)

REM --- Priority: run -> update -> rebuild -> migrate -> install
if "%RUN%"=="1"   goto do_run
if "%UPDATE%"=="1"  goto do_update
if "%REBUILD%"=="1" goto do_rebuild
if "%MIGRATE%"=="1" goto do_migrate
if "%INSTALL%"=="1" goto do_install

goto end

:do_run
if "%RUN%"=="1" (
    REM Create build directory if it doesn't exist
    if not exist build mkdir build

    cd build
    echo Configuring with CMake...  
    cmake -G "Visual Studio 17 2022" -A x64 ..

    REM Build the project
    echo Building...
    cmake --build . --config Release

    echo Build completed!
    echo.
    echo Running ecewo server...
    cd Release
    if exist server.exe (
        server.exe
    ) else (
        echo Server executable not found. Check for build errors.
    )

    REM Return to original directory
    cd ..\..
    exit /b 0
)

:do_update
if "%UPDATE%"=="1" (
  echo Updating from %REPO% (branch: main)
  if exist temp_repo rmdir /s /q temp_repo
  mkdir temp_repo
  echo Cloning repository...
  git clone --depth 1 --branch main %REPO% temp_repo || (
    echo Clone failed. Check internet or branch name.
    rmdir /s /q temp_repo
    exit /b 1
  )
  if exist temp_repo\.git rmdir /s /q temp_repo\.git
  echo Copying files...
  robocopy temp_repo . /E /XD build temp_repo /XF *.bat LICENSE README.md
  rmdir /s /q temp_repo
  echo Update complete.
  exit /b 0
)

:do_rebuild
if "%REBUILD%"=="1" (
    echo Cleaning build directory...
    if exist build rmdir /s /q build
    echo Cleaned.
    echo.
    mkdir build

    cd build
    echo Configuring with CMake...  
    cmake -G "Visual Studio 17 2022" -A x64 ..

    REM Build the project
    echo Building...
    cmake --build . --config Release

    echo Build completed!
    echo.
    echo Running ecewo server...
    cd Release
    if exist server.exe (
        server.exe
    ) else (
        echo Server executable not found. Check for build errors.
    )

    REM Return to original directory
    cd ..\..
    exit /b 0
)

:do_migrate
REM Migrate CMakeLists.txt
if "%MIGRATE%"=="1" (
    setlocal EnableDelayedExpansion

    echo Migrating all .c files in src\ and its subdirectories to src\CMakeLists.txt

    set "SRC_DIR=!BASE_DIR!src"
    set "CMAKE_FILE=!SRC_DIR!\CMakeLists.txt"

    if not exist "!SRC_DIR!" (
        echo ERROR: Source directory "!SRC_DIR!" not found!
        endlocal
        exit /b 1
    )

    rem --- Create a temporary file and copy the APP_SRC list ---
    set "TMP_FILE=%TEMP%\app_src_temp.txt"
    > "!TMP_FILE!" echo.
    >> "!TMP_FILE!" echo set(APP_SRC
    pushd "!SRC_DIR!" >nul

    for /R %%F in (*.c) do (
        set "full=%%~fF"
        set "rel=!full:%BASE_DIR%src\=!"
        set "rel=!rel:\=/!"
        >> "!TMP_FILE!" echo     ${CMAKE_CURRENT_SOURCE_DIR}/!rel!
    )
    
    popd >nul
    >> "!TMP_FILE!" echo     PARENT_SCOPE
    >> "!TMP_FILE!" echo ^)

    rem --- Process the existing CMakeLists.txt ---
    set "OUTPUT_FILE=%TEMP%\cmake_temp.txt"
    set "IN_APP_SRC="
    > "!OUTPUT_FILE!" (
        for /F "usebackq delims=" %%L in ("!CMAKE_FILE!") do (
            echo %%L | findstr /C:"set(APP_SRC" >nul
            if !errorlevel! equ 0 (
                set "IN_APP_SRC=1"
            ) else if defined IN_APP_SRC (
                echo %%L | findstr /C:")" >nul
                if !errorlevel! equ 0 set "IN_APP_SRC="
            ) else (
                echo %%L
            )
        )
    )

    rem --- Add new APP_SRC field
    type "!TMP_FILE!" >> "!OUTPUT_FILE!"

    rem --- Change with the original one ---
    copy /Y "!OUTPUT_FILE!" "!CMAKE_FILE!" >nul

    rem --- Delete the temporary one ---
    del "!TMP_FILE!" 2>nul
    del "!OUTPUT_FILE!" 2>nul

    echo Migration complete.
    endlocal
    exit /b 0
)

:do_install
REM Installation
if "%INSTALL%"=="1" (
    @echo Off
    setlocal EnableDelayedExpansion

    set "TARGET_DIR=%BASE_DIR%ecewo\vendors"
    set "HAS_PACKAGE_ARG=0"

    for %%A in (%*) do (
        if "%%~A"=="--cjson" set HAS_PACKAGE_ARG=1
        if "%%~A"=="--dotenv" set HAS_PACKAGE_ARG=1
        if "%%~A"=="--sqlite" set HAS_PACKAGE_ARG=1
        if "%%~A"=="--session" set HAS_PACKAGE_ARG=1
        if "%%~A"=="--async" set HAS_PACKAGE_ARG=1
    )

    if "!HAS_PACKAGE_ARG!"=="0" (
        echo ecewo - Build Script for Windows
        echo 2025 ^(c^) Savas Sahin ^<savashn^>
        echo.
        echo Available packages:
        echo ===============================================
        echo    cJSON:      ecewo.bat /install --cjson
        echo    .env:       ecewo.bat /install --dotenv
        echo    SQLite3:    ecewo.bat /install --sqlite
        echo    Session:    ecewo.bat /install --session
        echo    Async:      ecewo.bat /install --async
        echo ===============================================
        endlocal
        exit /b 0
    )

    if not exist "!TARGET_DIR!\" (
        mkdir "!TARGET_DIR!"
    )

    for %%A in (%*) do (
        if "%%~A"=="--cjson" (
            echo Installing cJSON...
            curl -s -o "!TARGET_DIR!\cJSON.c" https://raw.githubusercontent.com/DaveGamble/cJSON/master/cJSON.c
            curl -s -o "!TARGET_DIR!\cJSON.h" https://raw.githubusercontent.com/DaveGamble/cJSON/master/cJSON.h
        )
        if "%%~A"=="--dotenv" (
            echo Installing dotenv...
            curl -s -o "!TARGET_DIR!\dotenv.c" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/dotenv.c
            curl -s -o "!TARGET_DIR!\dotenv.h" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/dotenv.h
        )
        if "%%~A"=="--sqlite" (
            echo Installing SQLite3...
            curl -s -o "!TARGET_DIR!\sqlite3.c" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/sqlite3.c
            curl -s -o "!TARGET_DIR!\sqlite3.h" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/sqlite3.h
        )
        if "%%~A"=="--session" (
            echo Installing Session...
            curl -s -o "!TARGET_DIR!\session.c" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/session.c
            curl -s -o "!TARGET_DIR!\session.h" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/session.h
        )
        if "%%~A"=="--async" (
            echo Installing Asynchronous Support...
            curl -s -o "!TARGET_DIR!\async.c" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/async.c
            curl -s -o "!TARGET_DIR!\async.h" https://raw.githubusercontent.com/savashn/ecewo-plugins/main/async.h
        )
    )

    echo.
    echo Installation completed to "!TARGET_DIR!"

    set "SRC_DIR=ecewo"
    set "CMAKE_FILE=!BASE_DIR!!SRC_DIR!\CMakeLists.txt"

    if not exist "!CMAKE_FILE!" (
        echo ERROR: CMakeLists.txt not found: "!CMAKE_FILE!"
        endlocal & exit /b 1
    )

    set "TMP_FILE=%TEMP%\src_files_temp.txt"
    >"!TMP_FILE!" echo set(SRC_FILES
    pushd "!SRC_DIR!" >nul
    for /R %%F in (*.c) do (
        set "full=%%~fF"
        set "rel=!full:%BASE_DIR%ecewo\=!"
        set "rel=!rel:\=/!"
        >>"!TMP_FILE!" echo    !rel!
    )
    popd >nul
    >>"!TMP_FILE!" echo ^)

    set "OUTPUT_FILE=%TEMP%\cmake_temp.txt"

     > "!OUTPUT_FILE!" (
        for /F "usebackq delims=" %%L in (`
            findstr /R /N "^^" "!CMAKE_FILE!"
        `) do (
            rem %%L: "NN:actual line"
            set "NUM_LINE=%%L"
            set "LINE=!NUM_LINE:*:=!"

            echo(!LINE! | findstr /C:"# List of source files" >nul
            if !errorlevel! equ 0 (
                echo(!LINE!
                type "!TMP_FILE!"
                set "COMMENT_FOUND=1"
            ) else (
                echo(!LINE! | findstr /C:"set(SRC_FILES" >nul
                if !errorlevel! equ 0 (
                    set "IN_SRC_FILES=1"
                ) else if defined IN_SRC_FILES (
                    echo(!LINE! | findstr /C:")" >nul
                    if !errorlevel! equ 0 (
                        set "IN_SRC_FILES="
                    )
                ) else (
                    echo(!LINE!
                )
            )
        )
    )

    copy /Y "!OUTPUT_FILE!" "!CMAKE_FILE!" >nul

    del "!TMP_FILE!" 2>nul
    del "!OUTPUT_FILE!" 2>nul

    echo Migration complete.

    endlocal
    exit /b 0
)

endlocal
:end
exit /b 0
