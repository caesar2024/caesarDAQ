# CAESAR Standard Operating Procedure

Notes to start and shutdown the UCR CCN, SMPS, and SP2 instrument for the CAESAR campaign.

## Aircraft IP addresses 
### UCR
SMPS: 192.168.84.44 (Centos) <br>
CCN: 192.168.84.45 (Win 10 Enterprise)<br>
SP2: 192.168.84.46 (Win 10) <br>

### NCAR
NTP Server: 192.168.84.10 <br>
Gateway: 192.168.84.2 <br>

# Startup System
## CCNc
The CCNc main computer for UCR to monitor instruments. This instrument should be started first. It is powered by 28 VDC and plugged into the bottom.   

1. Verify that CCN supply bottle is sufficiently full (more than 200 ml for a flight)
2. Turn on CCN using power button on the top left.
3. Set supersaturation program. 
4. Check that temperature stabilizes (may take a few minutes)
5. Check that flow stabilizes (may take a few minutes)
6. Check that CCN is draining (watch bubble move to drain bottle)
7. Check that CCN is filling (watch bubble move from supply bottle)

## SMPS
1. Verify that valve is set to SDI inlet (handle should point toward cockpit)
2. Turn on power strip. 
3. Plug in the sheath flow pump. This pump must go into it's dedicated outlet box 3 (one of the two sockets where the line terminates, labelled as "pump"). 
4. Verify that system is powered up. Left screen should boot. Double tab Firefox button on touchscreen after boot to show gui.
5. Verify that CPC is powered on and warms up.
6. Verify that system is scanning voltage and the CPC concentration varies with voltage. 

> [!NOTE] For the CPC flow to work, the SP2 needs to be powered up and pump turned on. See below.

7. Check that serial port and pulse output are both displaying concentration. Check below for remote setup.

## SP2
1. Verify that power strip is on.
2. Press start button of SP2. It's behind the seat. Ask CVI operator for help if it cannot reached.
3. Verify that windows user is logged in on the right computer.


## Remote Connection from CCNc

### Setup remote to SP2 computer
1. Start `Remote Desktop Connection` to `192.168.84.46` and `USER`. (Super + Remote should bring up the remote desktop software. The values can be found in CCNc desktop).
2. Move the remote screen to `Desktop 2`. To do so 
- Exit full screen
- Hit Super-Tab
- Move to desktop 2
 
3. Go into fullscreen mode again

### Startup SP2  
1. Start SP2 Software
2. Turn on SP2 Pump in `Control` tab (click `on`)
3. Let flow stabilize to 120 ccm. Watch on first tab
4. Start Laser in `Control` tab (click `on`)
5. Check that all detectors are reading. Check that there is a scattering and incandescence time series.
6. Start writing data to file
> [!IMPORTANT]  
If you miss this step, the SP2 will not collect data and you will be very unhappy during the debriefing.

### Startup SMPS viewer on SP2 computer
1. Open PowerShell
2. Start SSH tunnel: ssh -L 8000:127.0.0.1:8000 aerosol@192.168.84.44 (use up-arrow so you don't have to type this). 
3. Keep this window open. You can use to check the running DAQ system on the SMPS computer. You also need it so that the `gui.html` works, since it polls 127.0.0.1 and this is served via port forwarding through `ssh`
4. Open Edge Browser
5. Open file `gui.html` in `Documents` folder (CTRL-O) for open file. It should bring up the three plots. Verify that they are updating.
- Verify the CPC flow rate is 400 vccm
- Verify that voltage is scanning
- Verify that both pulse and serial output are reading
6. Exit fullsreen of remote.  

## Verify Time Synchronization
1. Check that all times in UTC
2. Check that timeserver is synchronized. 

### Linux
```bash
chronyc sources
```

(must run as sudo)

Compare clocks to the second.

### Windows
Run these in PowerShell (Only works in SP2 computer)

1. `sc start w32time`
2. `w32tm /config /update /syncfromflags:manual /manualpeerlist:192.168.84.10`
3. `w32tm /resync /rediscover /nowait`


# Data Backup
1. Plug hard drive (or any storage device) into CCN computer on middle left
2. Copy CCN data on the desktop, then eject the device
3. Plug into SP2 computer
4. Copy SP2 data
5. Run `sftp aerosol@192.168.84.46` in a new PowerShell window, enter password
6. cd to `Data`, run `get -R (filename/foldername)` to get SMPS and CPC data
7. Copy downloaded data at `C:\User\user`
8. Check all the data are copied, then can start shutdown (below)


# Shutdown
1. Run `sudo shutdown --now` in PowerShell ssh connection on SP2 computer 
2. Stop laser in control tab
3. Stop pump in control tab
4. Exit SP2 software
5. Exit Edge Browser
6. Shutdown SP2 Computer (Power Off through Windows)
7. Shutdown power strip. Unplug sheath flow pump
8. Exit CCN software, Run shutdown menu on CCN
9. Power off CCNc unit
10. Exit aircraft

