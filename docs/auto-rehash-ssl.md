# Configuring hashpipe to automatically /rehash ssl when LetsEncrypt updates certs

First, you'll want to add a new oper that can REHASH and SAJOIN (see the OperBot class and Bot type). I've named mine operbot.

Set up a script that'll dump the appropriate commands through hashpipe (note both my and operbot's nicks; you may want to change those):

`/opt/irc-config/ssl-rehash.sh`
```
#!/bin/bash

(cat /opt/irc-config/oper-cmd;\
sleep 10; \
echo "REHASH :ssl"; \
sleep 2; \
echo "SAJOIN operbot #wobscale";  \
sleep 2; \
echo "PRIVMSG #wobscale :\`lm\`: rehashed your inspircd's ssl"; \
sleep 2; \
echo "QUIT :#|" \
) | rkt run --stage1-name=coreos.com/rkt/stage1-fly:1.21.0 --uuid-file-save=/var/lib/rehash.uuid --insecure-options=image,ondisk docker://euank/hashpipe -- -s localhost -n operbot -iv
```

And a file that'll keep operbot's password outta ps...or you could just echo it as part of ssl-rehash.sh:

`/opt/irc-config/oper-cmd`
```
OPER operbot <ya password>
```

Now, the systemd service files. There are two; one to set the path to watch and the other to start the service.

`/etc/systemd/system/rehash.path`
```
[Unit]
Description=Rehash SSL when certs are updated

[Path]
PathModified=/var/certs/irc/certs/ssl.key

[Install]
WantedBy=multi-user.target
```


`/etc/systemd/system/rehash.service`
```
[Unit]
Description=Rehash SSL

[Service]
Type=oneshot
ExecStart=/opt/irc-config/ssl-rehash.sh
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/lib/rehash.uuid
```

Turn it on: `systemctl enable rehash.path && systemctl start rehash.path`

You can verify this works with `touch /var/certs/irc/certs/ssl.key`