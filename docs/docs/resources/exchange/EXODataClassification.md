﻿# EXODataClassification

## Parameters

| Parameter | Attribute | DataType | Description | Allowed Values |
| --- | --- | --- | --- | --- |
| **Identity** | Key | String | The Identity parameter specifies the data classification rule that you want to modify. ||
| **Description** | Write | String | The Description parameter specifies a description for the data classification rule. You use the Description parameter with the Locale and Name parameters to specify descriptions for the data classification rule in different languages.  ||
| **Fingerprints** | Write | StringArray[] | The Fingerprints parameter specifies the byte-encoded document files that are used as fingerprints by the data classification rule. ||
| **IsDefault** | Write | Boolean | IsDefault is used with the Locale parameter to specify the default language for the data classification rule. ||
| **Locale** | Write | String | The Locale parameter adds or removes languages that are associated with the data classification rule. ||
| **Name** | Write | String | The Name parameter specifies a name for the data classification rule. The value must be less than 256 characters. ||
| **Ensure** | Write | String | Specifies if this policy should exist. |Present, Absent|
| **Credential** | Write | PSCredential | Credentials of the Exchange Global Admin ||
| **ApplicationId** | Write | String | Id of the Azure Active Directory application to authenticate with. ||
| **TenantId** | Write | String | Id of the Azure Active Directory tenant used for authentication. ||
| **CertificateThumbprint** | Write | String | Thumbprint of the Azure Active Directory application's authentication certificate to use for authentication. ||
| **CertificatePassword** | Write | PSCredential | Username can be made up to anything but password will be used for CertificatePassword ||
| **CertificatePath** | Write | String | Path to certificate used in service principal usually a PFX file. ||

# EXODataClassification

### Description

Create a new data classification policy in your cloud-based organization.


