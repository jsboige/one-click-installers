@echo off
setlocal enabledelayedexpansion

:: Choosing the Models to run simultanously in distinct processes: uncomment and edit the lines below to set up instances with table indices incrementing from 0 and distinct ports. 
:: Approximate size in VRAM is given in the comments. Try not to max out your GPU VRAM. 
:: Note that GGML come with various quantizers of different sizes and capabilities. Reference data is for best mixed 4 bits quantization available.
:: Default value are chosen to fit comfortably in a 16 GB VRAM GPU (e.g. NVidia 3080).

:: Instance Data: LISTEN_PORT, API_BLOCKING_PORT, API_STREAMING_PORT, STATIC_FLAGS

:: GPT2 : 900 MB
set "INSTANCE_DATA[0]=7860,5000,5005,--model gpt2 --loader transformers --monkey-patch --xformers --n-gpu-layers 200000"
:: Pythia 1.4B : 3.4 GB
::set "INSTANCE_DATA[0]=7861,5001,5006,--model EleutherAI_pythia-1.4b-deduped --loader transformers --monkey-patch --xformers --n-gpu-layers 200000"
:: Orca Mini 3B q4 GGML: 4 GB
set "INSTANCE_DATA[1]=7862,5002,5007,--model TheBloke_orca_mini_3B-GGML --loader llama.cpp --monkey-patch --xformers --n-gpu-layers 200000"
:: Red Pajama 3B : 6.2 GB
:: set "INSTANCE_DATA[1]=7863,5003,5008,--model togethercomputer_RedPajama-INCITE-Chat-3B-v1 --loader transformers --monkey-patch --xformers --n-gpu-layers 200000" 
:: Stable Beluga 7B q4 GGML : 6.2 GB
set "INSTANCE_DATA[2]=7864,5004,5009,--model TheBloke_StableBeluga-7B-GGML --loader llama.cpp --monkey-patch --xformers --n-gpu-layers 200000"
:: Stable Beluga 13B q4 GGML : 10.3 GB
::set "INSTANCE_DATA[3]=7865,5005,5010,--model TheBloke_StableBeluga-13B-GGML --loader llama.cpp --monkey-patch --xformers --n-gpu-layers 200000"
:: ... add more instances as needed ...


::echo Debug: Array 0: !INSTANCE_DATA[0]!
::echo Debug: Array 1: !INSTANCE_DATA[1]!


:: Detect WSL IP address
FOR /F %%a IN ('wsl -e bash -c "ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -f1 -d '/'"') DO SET WslIP=%%a

echo Detected WSL IP: %WslIP%

:: Detect Windows IP address for the Ethernet interface
FOR /F %%a IN ('powershell -command "Get-NetIPConfiguration | Where-Object { $_.InterfaceAlias -eq 'Ethernet' } | ForEach-Object { $_.IPv4Address.IPAddress }"') DO SET WinIP=%%a

echo Detected Win IP: %WinIP%


:: Loop through instances and set ports
for /L %%j in (0,1,9) do (
    if defined INSTANCE_DATA[%%j] (
        set "currentInstance=!INSTANCE_DATA[%%j]!"
        echo Instance Data for %%j is: !currentInstance!
        
        :: Extract data for current instance
        for /f "tokens=1-4 delims=," %%a in ("!currentInstance!") do (
            set LISTEN_PORT=%%a
            set API_BLOCKING_PORT=%%b
            set API_STREAMING_PORT=%%c
            set STATIC_FLAGS=%%d
        )

        echo Starting instance with ports:
        echo LISTEN_PORT: !LISTEN_PORT!
        echo API_BLOCKING_PORT: !API_BLOCKING_PORT!
        echo API_STREAMING_PORT: !API_STREAMING_PORT!

        :: Use netsh to setup the port redirection
        netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=!LISTEN_PORT!
        netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=!API_BLOCKING_PORT!
        netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=!API_STREAMING_PORT!

        netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=!LISTEN_PORT! connectaddress=%WslIP% connectport=!LISTEN_PORT!

        if ERRORLEVEL 1 echo Failed to set up port forwarding for port !LISTEN_PORT!

        netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=!API_BLOCKING_PORT! connectaddress=%WslIP% connectport=!API_BLOCKING_PORT!
        netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=!API_STREAMING_PORT! connectaddress=%WslIP% connectport=!API_STREAMING_PORT!
    
    
        :: Set the environment variable for flags
        set OOBABOOGA_FLAGS=--listen --api --verbose !STATIC_FLAGS! --listen-host "0.0.0.0" --listen-port "!LISTEN_PORT!" --api-blocking-port "!API_BLOCKING_PORT!" --api-streaming-port   "!API_STREAMING_PORT!"
    
        :: Export environment variables to WSL and call the original script
        set "WSLENV=OOBABOOGA_FLAGS/u"

        echo About to launch with:
        echo OOBABOOGA_FLAGS: !OOBABOOGA_FLAGS!

        :: Start the main script in a new process
        start call start_wsl.bat
    
        set "OOBABOOGA_FLAGS="

    )
)

:: Pause at the end for user to see the results
pause
