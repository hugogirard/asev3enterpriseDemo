- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Generate SSL Certificat](#generating-ssl-certificate-with-azure-dns-public-zone-(optional))
  - [Create Azure DNS Public Zone](#create-azure-dns-public-zone)
  - [Run the Powershell script](#run-the-powershell-script)
- [Create the environment](#create-the-environment)
  - [Get the base64 encoded value of your certificate](#get-the-base64-encoded-value-of-your-certificate)
  - [Create Github Secrets](#create-github-secrets)
  - [Run Create Azure Resources GitHub Action](#run-create-azure-resources-gitHub-action)
  - [Configure the firewall rules](#configure-the-firewall-rules)
  - [Configure the Github Runner](#configure-the-github-runner)
  - [Run Deploys Apis GitHub Action](#run-deploys-apis-gitHub-action)
  - [Run Create Application Gateway GitHub Action](#run-create-application-gateway-gitHub-action)
  - [Test the apis](#test-the-apis)

# Introduction

The purpose of this demo is to illustrate a common setup leveraging App Service Environment v3 (ASE) with a hub and multiple spokes.

The App Service Environment will be of type internal, all ingress will be going into Azure Application Gateway with WAF and all egress thru the Azure Firewall when they need to consume other resources from other spokes or the Internet.

# Architecture

This diagram illustrates the architecture for this demo repository.  The networking topology used its [hub and spoke](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke?tabs=cli).

<img src=https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/architecture.png />

Here you have two APIs hosted in the ASE, the Weather API doesn't consume any other Azure Resources and doesn't egress thru the firewall.  

The fibonacci API will calculate a [fibonacci number](https://en.wikipedia.org/wiki/Fibonacci_number) based on a len passed in parameters.

Before calculating the sequence, the API will validate if the result its present in an Azure Redis Cache.  If it's the case, no calculation will be done at the API level and the cached result will be returned.

If the sequence is not present in the cache, it will be calculated and saved in the cache for future reference. 

When retrieving/writing values from the cache, all traffic will go thru the Azure Firewall.  **Neither spoke is peered together, all the traffic between them flow thru the Azure Firewall.**

# Prerequisites

First step is to Fork this repository.

Next, you will need to have a public domain name and a wildcard certificate. 

If you already own a public domain but you don't have a wild certificate here some step to create one using [Azure DNS Public Zone](https://docs.microsoft.com/en-us/azure/dns/dns-getstarted-portal).

# Generating SSL certificate with Azure DNS Public Zone (optional)

Here the tool you need to installe on your machine.

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

- [Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1)

- Install the official [Powershell](https://github.com/rmbolger/Posh-ACME) **Let's Encrypt client**

Here the [list](https://letsencrypt.org/docs/client-options/) of all supported clients if you want to implement your own logic for the **Let's Encrypt Certificate**.

## Create Azure DNS Public Zone

This demo is using Azure Public DNS Zone, you will need to have a domain that you own from any register.  Once it is done, you need to configure your DNS in your domain register with Azure DNS Public Zone entry.

It all explain [here](https://docs.microsoft.com/en-us/azure/dns/dns-getstarted-portal).


## Run the Powershell script

Be sure you already configured your **Azure Public DNS Zone**.

First create a service principal running the following command.

```Bash
$ az ad sp create-for-rbac --name <ServicePrincipalName> --sdk-auth --role contributor --scope '/subscriptions/{subscriptionId}'
```

Take note of the output you will need it to create Github Secrets.

Now go to the folder scripts, there you have a powershell called **letsEncrypt.ps1**.

This script will connect to your Azure Subscription passed in parameters and create a **TXT** challenge in your **Azure DNS Public Zone**.  

First run this command in a PowerShell terminal

```bash
$ Set-PAServer LE_PROD
```

Now with the information retrieved when you created the **service principal** you can create your certificate.

Be sure your **Service Principal** have access to modify your Azure Public DNS Zone.  If you want to use least privilege refers to this [doc](https://github.com/rmbolger/Posh-ACME/blob/main/Posh-ACME/Plugins/Azure-Readme.md#create-a-custom-role).

*Be sure the username, password and certificate password are in double quotes**

$ .\letsEncrypt.ps1 -certNames *.contoso.com -acmeContact john@contoso.com -aZSubscriptionId <subId> -aZTenantId <tenantId> -aZAppUsername "<sp_clientId>" -aZAppPassword "<sp_password>" -pfxPassword "<pfxPassword>"

When the command is finished, a new folder called **pa** will be created inside the scripts folder.

If you browse in it inside the last child folder of **acme-v02.api.letsencrypt.org** you will see those files. The important file is called cert.pfx.

# Create the Azure Resources

## Get the base64 encoded value of your certificate

You will need to create GitHub secrets to configure this repository.  Two of them are related to your certificate and needed when communicating with the Application Gateway.

You will need to find the base64 value of your certificate and save it in a GitHub Secret.  To do so run the following command and get the value from the text file generated.

```
$fileContentBytes = get-content 'cert.pfx' -Encoding Byte
[System.Convert]::ToBase64String($fileContentBytes) | Out-File 'pfx-bytes.txt'
```

## Create Github Secrets

You will need to create some [GitHub repository secrets](https://docs.github.com/en/codespaces/managing-codespaces-for-your-organization/managing-encrypted-secrets-for-your-repository-and-organization-for-codespaces#adding-secrets-for-a-repository) first.  Here the list of secrets you will need to create.

| Secret Name | Value | Link
|-------------|-------|------|
| AZURE_CREDENTIALS | The service principal credentials needed in the Github Action | [GitHub Action](https://github.com/marketplace/actions/azure-login)
| AZURE_SUBSCRIPTION | The subscription ID where the resources will be created |
| CERTIFICATE_DATA | The base64 value of your pfx certificate file |
| CERTIFICATE_PASSWORD | The password of your pfx file |
| CUSTOM_DOMAIN_FIBONACCI_API | The custom domain of the fibonacci API like fibonacciapi.contoso.com |
| CUSTOM_DOMAIN_WEATHER_API | The custom domain of the weather API like weatherapi.contoso.com |
| PA_TOKEN | Needed to create GitHub repository secret within the GitHub action |  [Github Action](https://github.com/gliech/create-github-secret-action)
| VM_PASSWORD | The password needed for the Github Self Runner |
| VM_USERNAME | The username needed for the Github Self Runner |

## Run Create Azure Resources GitHub Action

Now you can go to the Actions tab and Run the Create Azure Resources [GitHub Actions](https://docs.github.com/en/actions).

This GitHub Action can take up to 3 hours to run.  Once is completed you should have 3 resources groups created in Azure.

<ul>
  <li>rh-hub-ase-demo</li>
  <li>rg-spoke-ase-demo</li>  
  <li>rg-spoke-db-demo</li>
</ul>

## Configure the firewall rules

Once all resources are created, you will need to configure the **firewall policy**.  

You will see this resource in the resource group called **rg-hub-ase-demo**.  Click on it and click on Network rules.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/firewall network rule.png' />

Click on Add a rule collection.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/addrule.png' />

You will need to configure a rule that look like this.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/rule collection fw.png' >

What is important here is the Source and Destination.

The Source will be equal to the subnet CIDR that you can find in the vnet-spoke for the snet-ase subnet.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/vnet-spoke.png' />

The destination will be equal to the subnet CIDR that you can find in the vnet-spoke-db for the snet-prvEndpoint.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/vnet-spoke-db.png' />

## Configure the Github Runner

Because the Application Service Environment is of type internal, you will need to deploy the APIs using [GitHub Self Runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners).

Connect to VM created in the resource group **rg-hub-ase-demo** and follow the installation procedure.

If you want to run the runner agent as a service (recommended) follows this [link](https://docs.github.com/en/actions/hosting-your-own-runners/configuring-the-self-hosted-runner-application-as-a-service) after the installation.

## Run Deploys Apis GitHub Action

Now you need to execute the **Deploy Apis** GitHub action.  This will deploy the two apis in the ASE.

## Run Create Application Gateway GitHub Action

Once the apis are deployed, you can now create the Application Gateway to receive the ingress traffic.  To do so, execute the Create Application Gateway GitHub Action.

One is completed, you will need to configure the public IP of the Application Gateway to your public domain for the two apis.

You can find the Public IP of Application Gateway in the Azure Portal.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/ipappgw.png'>

In the previous step, you created two secrets for the custom domain of both API.

You will need to configure those two entries in your DNS Server, here for example we are using Azure Public DNS Zone.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/DNS.png'>

## Test the apis

Now you should be able to test the weatherapi, to test it open a browser and enter this URL (replace weatherapi.hugogirard.net with your custom domain).

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/weatherapi.png' />

Do the same for the fibonacci api.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/fibonacci.png' />

To test you can reach the redis cache execute the getSequence with a len of 5.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/notcached.png' />

You will see in the JSON result the **property valueFromCache** returning false.

Execute the API again.

<img src='https://raw.githubusercontent.com/hugogirard/asev3enterpriseDemo/main/pictures/cached.png' />

The property **valueFromCache** will return true.
