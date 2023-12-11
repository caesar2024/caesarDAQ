# caesarDAQ


Add to crontab

```
@reboot /sbin/runuser -l aerosol -c "tmux new-session -d -s smps /home/aerosol/startup.sh" > cron.log 2>&1
```

This is the startup script:

```bash
#!/bin/bash

cd /home/aerosol/opt/caesarDAQ/src/
/usr/local/bin/julia -i main.jl
```
