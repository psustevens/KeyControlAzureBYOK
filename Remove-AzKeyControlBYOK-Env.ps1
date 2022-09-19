# Created by: David Stevens (David_L_Stevens@hotmail.com)
# Date: 9/19/2022
# This script destroys a demo environment for performing a demo of Entrust KeyControl
# Specifically, the Azure BYOK feature. As of this date it is for KeyControl v5.5.1
# See the sister script (New-AzKeyControlBYOK-Env.ps1) for building the demo environment.
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

$location = 'eastus'
$resourceGroupName = 'KeyControl-BYOK-RG1'
# $storageAccountName = 'stblobstoragedemo999'
$keyVaultName = 'KeyControl-BYOK-Vault1'
$RSAKeyName = 'Native-RSA-key-01'
$ECKeyName = 'Native-EC-key-01'
$appName = 'KeyControl-BYOK-App1'

Connect-AzAccount

# Get the Tenant ID and Azure Subscription of the user that just logged in
#$tenantId = (Get-AzContext).Tenant.Id
$subscription = (Get-AzContext).Subscription.Id

Set-AzContext -Subscription $subscription

Write-Host "Deleting App Registration:  "  $appName
Write-Host 
Remove-AzADApplication -DisplayName $appName -PassThru


Write-Host "Deleting all keys in KeyVault: "  $keyVaultName
Write-Host
Remove-AzKeyVaultKey -VaultName $keyVaultName -Name $RSAKeyName -Force -PassThru
Remove-AzKeyVaultKey -VaultName $keyVaultName -Name $ECKeyName -Force -PassThru


Write-Host "Preparing to delete and purge KeyVault: " $keyVaultName
Write-Host
if ((Get-AzKeyVault -VaultName $keyVaultName).EnableSoftDelete) {
    Write-Host "Soft Delete is enabled on KeyVault:  " $keyVaultName
    Write-Host
    if (-not ( Get-AzKeyVault -VaultName $keyVaultName).EnablePurgeProtection) {
        Write-Host "Purge Protection is disabled on KeyVault: " $keyVaultName
        Write-Host "Purging KeyVault"
        Write-Host
        # Delete the KeyVault
        Remove-AzKeyVault -VaultName $keyVaultName -Location $location -Force -PassThru
        # Now that it's been deleted, let's purge it completely from the system
        Remove-AzKeyVault -VaultName $keyVaultName -Location $location -InRemovedState -Force -PassThru
    }
}

Write-Host "Be patient while the ResourceGroup " $resourceGroupName "is deleted"
Write-Host
#Remove-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -Force -PassThru
Remove-AzResourceGroup -Name $resourceGroupName -Force
