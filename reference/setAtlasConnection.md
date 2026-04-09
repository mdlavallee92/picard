# Set Atlas Connection

Create a WebApiConnection object using credentials from either .Renviron
or keyring package. Supports secure credential management through
keyring for enhanced security.

## Usage

``` r
setAtlasConnection(useKeyring = FALSE)
```

## Arguments

- useKeyring:

  Logical. If TRUE, retrieves credentials from keyring package. If FALSE
  (default), uses environment variables from .Renviron. Default: FALSE

## Value

An R6 class of WebApiConnection containing the ATLAS WebAPI connection
details

## Details

Credentials are stored using a standardized structure in the system
keyring. All ATLAS credentials are grouped under the service "picard"
with individual identifiers for each credential type.

### Using .Renviron (Default - Backwards Compatible)

    # Credentials must be set in .Renviron:
    # atlasBaseUrl='https://organization-atlas.com/WebAPI'
    # atlasAuthMethod='ad'
    # atlasUser='user@organization.com'
    # atlasPassword='YourPassword'

    atlasCon <- setAtlasConnection()

### Using keyring (Recommended for Security)

First, store credentials securely in the default keyring:

    # Store each credential in keyring under service "picard"
    keyring::key_set(service = "picard", username = "atlasBaseUrl")
    keyring::key_set(service = "picard", username = "atlasAuthMethod")
    keyring::key_set(service = "picard", username = "atlasUser")
    keyring::key_set(service = "picard", username = "atlasPassword")

    # Verify stored credentials
    keyring::key_list(service = "picard")

Then retrieve and connect:

    atlasCon <- setAtlasConnection(useKeyring = TRUE)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Using .Renviron (default)
  atlasCon <- setAtlasConnection()

  # Using keyring
  atlasCon <- setAtlasConnection(useKeyring = TRUE)
} # }
```
