1. In the UI

1.1. Disable Block public access (bucket settings)

1.2. Add Bucket Policy

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::mongo-bkup-9b4e3640f0365c9b/*"
        }
    ]
}
```

2. Test access:

```sh
wget https://mongo-bkup-9b4e3640f0365c9b.s3.eu-west-3.amazonaws.com/backup-2024-07-15.gz
```
