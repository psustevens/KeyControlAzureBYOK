# Created by: David Stevens 
# Twitter: @PSUStevens
# Initial Creation Date: 9/19/2022
#
# This script creates a demo environment for performing a demo of Entrust KeyControl
# Specifically, the Azure BYOK feature. As of this date it is for KeyControl v5.5.1
# See the sister script (Remove-AzKeyControlBYOK-Env.ps1) for destroying the demo environment in order to save resources/money.
#
# You will need to make sure you have the following installed on your machine:
#   : PowerShell (latest version recommended)
#   : Azure Az PowerShell module installed
#
# Refer to the documentation on how to install the Azure Az PowerShell module over at:
# https://learn.microsoft.com/en-us/powershell/azure/install-az-ps
#
# You can also take your chances and run this command at a PowerShell prompt:
# Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

# Variables needed for constructing an Azure BYOK environment for a KeyControl
# BYOK in Azure.
# You should change the username (dstevens) for each of the Azure resources to your username

[String] $location = 'eastus'
[String] $resourceGroupName = 'dstevens-KeyControl-BYOK-RG'
# [String] $storageAccountName = 'KeyControl-Storage-Acct'
[String] $keyVaultName = 'dstevens-KeyControl-BYOK-Vault'
[Int32] $softDeleteRetention = 7
[String] $RSAKeyName = 'Native-RSA-key-01'
[String] $ECKeyName = 'Native-EC-key-01'
[String] $appName = 'dstevens-KeyControl-BYOK-App'


Connect-AzAccount

# Get the Tenant ID and Azure Subscription of the user that just logged in
#$tenantId = (Get-AzContext).Tenant.Id
$subscription = (Get-AzContext).Subscription.Id

Set-AzContext -Subscription $subscription

# Create a resource group for the KeyVault
Write-Host "Creating Azure Resource Group " $resourceGroupName
Write-Host
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create a KeyVault for storing BYOK keys in
Write-Host "Creating Azure KeyVault for storing KeyControl Azure BYOK keys: " $keyVaultName
Write-Host
New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -SoftDeleteRetentionInDays $softDeleteRetention -Sku 'Standard'

# Create encryption keys in KeyVault to import into KeyControl
# Create an RSA key with the default key length of 2048 bits in software, not in an HSM-enabled KeyVault
Write-Host "Creating RSA 2048 bit key: " $RSAKeyName
Write-Host
Add-AzKeyVaultKey -VaultName $keyVaultName -Name $RSAKeyName -Destination Software -KeyType RSA
# Create an EC key with the default curve name of P-256 in software, not in an HSM-enabled KeyVault
Write-Host "Creating EC P-256 key: " $ECKeyName
Write-Host
Add-AzKeyVaultKey -VaultName $keyVaultName -Name $ECKeyName -Destination Software -KeyType EC


# Create an Azure AD App Registration
Write-Host "Creating App Registration " $appName
Write-Host
New-AzADApplication -DisplayName $appName -SignInAudience AzureADMyOrg
$appId = (Get-AzADApplication -DisplayName $appName).AppId

# Create an AD Service Principal for the new App otherwise the role assignment will not work
New-AzADServicePrincipal -ApplicationId $appId

# Get a start and end date for the app secret in the next step
$startDate = Get-Date 
$endDate = $startDate.AddYears(1)

# Create a secret for the newly create AD App
$appSecret = (Get-AzADApplication -ApplicationId $appId | New-AzADAppCredential -StartDate $startDate -EndDate $endDate).SecretText

# Add API Permissions to the newly created App
# Add the Microsoft Graph - User.Read permission
Add-AzADAppPermission -ApplicationId $appId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId e1fe6dd8-ba31-4d61-89e7-88639da4683d
# Add the Microsoft Graph - Application.ReadWrite.All permission
Add-AzADAppPermission -ApplicationId $appId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId bdfbf15f-ee85-4955-8675-146e8e5296b5
# Add the Azure Active Directory Graph - User.Read permission
Add-AzADAppPermission -ApplicationId $appId -ApiId 00000002-0000-0000-c000-000000000000 -PermissionId 311a71cc-e848-46a1-bdf8-97ff7156d8e6
# Add the Azure Service Management - user_impersonation permission
Add-AzADAppPermission -ApplicationId $appId -ApiId 797f4846-ba00-4fd7-ba43-dac1f8f63013 -PermissionId 41094075-9dad-400e-a0bd-54e686782033
# Add the Azure Key Vault - user_impersonation permission
Add-AzADAppPermission -ApplicationId $appId -ApiId cfa8b339-82a2-471a-a3c9-0fc0be7a4093 -PermissionId f53da476-18e3-4152-8e01-aec403e6edc0

# Add the Contributor Role Assignment to the newly created app
Write-Host "Assigning the Contributor role to app:  " $appName
Write-Host
# This is the scope (Subscription) where the role is located in Azure
$scope = '/subscriptions/' + $subscription
New-AzRoleAssignment -ApplicationId $appId -RoleDefinitionName Contributor -Scope $scope

Write-Host "Granting Key Vault permissions to:  " $appName
Write-Host
# Grant Key Vault permissions to the App Registration
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId (Get-AzADServicePrincipal -SearchString $appName).id -PermissionsToKeys Get,List,Update,Create,Import,Delete,Recover,Backup,Restore,Decrypt,Encrypt,UnwrapKey,WrapKey,Verify,Sign,Purge,Release,Rotate,GetRotationPolicy,SetRotationPolicy

# Create a storage account when/if needed
#New-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Location $location -SkuName Standard_LRS


Write-Host "Enter this information into the CSP fields for Azure BYOK in KeyControl"
Write-Host
Write-Host "Azure AD Tenant ID:  " (Get-AzContext).Tenant.Id
Write-Host "Subscription ID:  " (Get-AzContext).Subscription.Id
Write-Host "Application (Client) ID:  " $appId
Write-Host "Client Secret:  " $appSecret
