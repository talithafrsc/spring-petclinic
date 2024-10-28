# Spring PetClinic

## Design Architecture
![Design Architecture](https://github.com/talithafrsc/spring-petclinic/blob/master/pics/diagram.png)

**Containerization**

The PetClinic application is hosted on a Docker container inside Compute Engine in GCP. An NGINX container acted as reverse proxy in front of the application. By using the blue-green deployment strategy, NGINX helps to minimize downtime during switching from old container to new container. 

PetClinic application & NGINX are located in the same Docker network. Petclinic is assigned to custom network alias, for example `petclinic-app`, so we do not need to modify NGINX configuration during deployment. 

**Database**

A PostgreSQL database hosted in CloudSQL stores the data of PetClinic application. Both of the database & container connected by internal network (VPC). The container accesses the database using private DNS, making it easy to access without changing private IPs.

**User Access**

User can access the application from DNS. Because this is a mock implementation, only internal DNS is provided (http://petclinic.local). Combination of Google Cloud LB & public DNS may be used to expose the web publicly.

**Observability**

The Ops Agent is installed on Compute Engine for sending metrics & logging to Monitoring & Logging Dashboard in GCP. Compute Engine metrics such as CPU & Memory usage can be accessed from Observability menu in GCP console. 

By default, docker container logs is not exported to GCP Logging, so a logging driver for Docker needs to be configured (inside docker-compose.yml). To filter the PetClinic logs, put this query inside GCP logging:

```
jsonPayload.container.metadata.service="petclinic"
```

## CI/CD rules

### Application Changes
1. Clone the repository to your local
2. Create a new branch
3. Make changes in the code
4. Commit & push the changes by using semantic-release convention (starting with "fix:" or "feat:")
5. Create a Pull Request to master branch
6. Merge pull request. This will trigger a workflow to build & deploy the new container

### Infrastructure Changes (Terraform)
(Currently does not support zero downtime deployment when the Terraform is forced to replace the existing infrastructures)
1. Clone the repository to your local
2. Create a new branch
3. Make changes inside terraform repository
4. Commit & push the changes by using semantic-release convention (starting with "fix:" or "feat:")
5. Create a Pull Request to master branch. A workflow will be triggered to dry run your changes in Terraform.
6. Merge pull request. This will trigger workflow to deploy infrastructure changes in GCP

## Provisioning Process

### GCP Preparation
1. Create a new project of GCP & activate its billing
2. Create service account & GCP bucket for Terraform & Github workflow
3. Assign permission for service account
5. Generate a new service account key (json)
4. Activate some of required APIs for Terraform & gcloud access in Github Workflow

### Github Repository Preparation
1. Fork [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) repository to own Github account
2. Generate SSH key for SSH to compute engine during deployment. Put both private & public keys in repository secret
3. Generate new Github token for semantic release. Put in repository secret
4. Put other variables & secrets in repository such as GCP service account key, project, machine name & required PostgreSQL variables

### Infrastructure provisioning (Terraform)
1. Prepare Terraform configurations
    - **backend.tf**: connect to previously created bucket in GCP as terraform backend
    - **main.tf**: Infrastructure resource & datasource configuration
    - **variables.tf**: Declare variables for Terraform
    - **variables.tfvars**: Variables value for Terraform
    - **.github\workflow\terraform-ci.yml**: Github workflow file for Terraform
2. Terraform configuration includes managed infrastructure in GCP, which are:
    - Compute engine
      - No Public IP configured
      - Provision Docker & local DNS by startup-script
    - CloudSQL
      - No Public IP configured
    - Artifact registry repository
    - NAT
      - Provide public IP of compute engine to connect with public network
    - Private DNS zone for CloudSQL
4. Push workflow & configuration files by following CI/CD rules mentioned above, so the workflow will apply the Terraform configuration

### App Deployment
1. Prepare some file for app deployment
    - **Dockerfile**: Script to build a Docker image
    - **docker-compose.yml**: Docker compose configuration, containing PetClinic & NGINX container, network, and log driver
    - **nginx.conf**: Customized NGINX configuration as reverse proxy of PetClinic app
    - **deploy.sh**: Script to execute inside the compute engine, to deploy the app
    - **.github\workflow\app-ci.yml**: Github workflow file for App
2. Push those files by following CI/CD rules mentioned above
3. Once PR is merged, semantic release will analyze the commit message & tag the current commit
4. On build process, the Docker image will be built and pushed to GCP artifact registry using tag generated from semantic release
5. After build completes, deploy job will started. Github workflow connects to Compute Engine by IAP (mentioning VM name), so no private/public IPs required.

(Note for improvement: this process of app deployment does not include unit testing or static code analysis)

### Blue-Green Deployment Process
1. Authenticate to docker registry
2. Check the current running container. If container is running, get the current container name
3. Deploy the new container by scaling the app to 2 without destroying the old container
4. Wait until the new container is ready
5. Stop the old container & reload NGINX configuration
6. Reconfigure docker compose by scaling down the app to 1
