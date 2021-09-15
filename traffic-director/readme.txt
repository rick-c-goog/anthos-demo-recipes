0. Ensure you are running terraform 0.12 or later (requirement already satisfied if running on Cloud Shell)
1. terraform init
2. terraform apply
3. source ./create_envs.sh
  If you want to skip through the codelab sections, run the following which will autocomplete:
4. bash automate-deploy-cart.sh
5. bash automate-deploy-payment.sh
6. bash automate-payment-delivery.sh

Cleanup:

1. bash td-cleanup.sh
2. terraform destroy
