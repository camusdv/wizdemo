# Deploy

```sh
terraform init
terraform apply
```

# Post deployment manual updates

1. Log-in the EC2 instance using the `ubuntu` account.

2. Check that mongodb is properly running

```sh
ps aux |grep mongo
netstat -nlp | grep 27017
```

3. Add mongodb authentication account

```sh
#!/bin/sh

mongosh <<-EOF2
  use admin
  db.createUser({
  user: 'admin',
  pwd: 'password',
  roles: [{ role: 'root', db: 'admin' }]
  })
EOF2
```

4. Add external IP to mongodb binding list:

```sh
cat mongod.conf |grep bindIp

  bindIp: "127.0.0.1,10.0.1.178"
```

4. Restart mongodb

```sh
sudo systemctl restart mongod.service
```

5. Test connection to mongodb

```sh
telnet <external IP> 27017
```
