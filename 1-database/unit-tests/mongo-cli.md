# Steps to check mongodb connection

1. Connect to mongodb server (where mongosh is installed)

```sh
ssh -i ssh_keys/mirantis-demo-dvi ubuntu@15.237.190.66
```

2. Connect to the mongodb instance

```sh
mongosh "mongodb://admin:password@mongodb.mirantisdemo.com" --apiVersion 1
```
