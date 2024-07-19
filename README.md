# wizdemo

Steps to deploy:

1. Deploy the database tier first

2. Retrieve some outputs from database (vpc_id, gateway_id, dbtier_subnet_id) deployment and update Kubernetes project related variables

3. Deploy the EKS tier second

4. Deploy AWS Config last 
