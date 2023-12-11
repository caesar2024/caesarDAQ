# CAESAR SOP

## Aircraft IP addresses: 
SMPS: 192.168.84.44 (Centos)
CCN: 192.168.84.45 (Win 10 Enterprise)
SP2: 192.168.84.46 (Win 10)

NTP Server: 192.168.84.10
Gateway: 192.168.84.2

## CCNc
(0) Verify that CCN supply bottle is sufficiently full (more than 200 ml for a flight)
(1) Turn on CCN using po wer button on the top left.
(2) Set SS program
(3) Check that temperature stabilizes (may take a few minutes)
(4) Check that flow stabilizes (may take a few minutes)
(5) Check that CCN is draining (watch bubble move to drain bottle)
(6) Check that CCN is filling (watch bubble move from supply bottle)

## SMPS
(0) Verify that valve is set to SDI inlet (handle should point toward cockpit)
(1) Turn on power strip.
(2) Verify that system is powered up. Left screen should boot. Double tab Firefox button on touchscreen after boot to show gui.
(3) Verify that CPC is powered on and warms up.
(4) Verify that system is scanning voltage and the CPC concentration varies with voltage. **Note: needs SP2 powered up and pump turned on.**
(5) Check that Serial and Pulse are both reading

## SP2
(0) When power strip is on, press start button of SP2. It's behind the seat. Ask CVI operator for help if it cannot reached.
(1) Verify windows login screen on right computer.


## Remote Connection from CCNc
(0) Start Remote Desktop Connection to 192.168.84.46 and USER
(1) Start SP2 Software
(2) Turn on SP2 Pump in Control tab
(3) Let flow stabilize to 120 ccm
(4) Start Laser in Control tab
(5) Start writing data to file

(6) Open PowerShell
(7) Start SSH tunnel: ssh -L 8000:127.0.0.1:8000 aerosol@192.168.84.44 (use up-arrow). Keep this window open
(8) Open Edge
(9) Open file `gui.html` in Documents folder (CTRL-O) for open
(10) Exit fullsreen of remote. Arrange screens. 
(11) Move remote connection to Desktop 2. Arrange SP2 and SMPS gui for optimal viewing. 

## Verify Time Synchronization
(1) Times in UTC
(2) Times Accurate
(3) Timeserver Synchronized

## Shutdown
(0) Run `sudo shutdown --now` in PowerShell ssh connection 
(1) Stop laser in control tab
(2) Stop pump in control tab
(3) Exit SP2 software
(5) Exit Edge
(6) Shutdown computer
(7) Shutdown power strip
(8) Run shutdown menu on CCN

### Optional
Check on Linux that NTP service is running and synchronized
chronyc sources (must run as sudo)

Compare clocks

### Manual NTP Server Windows
sc stop w32time
w32tm /unregister
w32tm /register
sc start w32time
w32tm /config /update /syncfromflags:manual /manualpeerlist:192.168.84.10
w32tm /resync /rediscover /nowait
