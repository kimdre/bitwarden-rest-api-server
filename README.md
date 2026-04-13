# Bitwarden REST API Server

## Overview
This project provides a containerized REST API server based on the Bitwarden CLI that allows you to interact with your Bitwarden vault using HTTP requests.

## Getting Started
### Setting up environment variables
1. [Follow these instructions](https://bitwarden.com/help/personal-api-key/#get-your-personal-api-key) to get your `client_id` and `client_secret`
2. Add the following lines to a `.env` file in the same directory as your `docker-compose.yml` file, replacing the values with your own:

```env
# replace with https://vault.bitwarden.eu for EU users or your own instance URL
BW_HOST=https://vault.bitwarden.com 
BW_CLIENTID=<your_client_id>
BW_CLIENTSECRET=<your_client_secret>
BW_PASSWORD=<your_master_password>

# optional: set the vault synchronization interval in seconds (default is 120 seconds)
VAULT_SYNC_INTERVAL=120

# optional: set the path for vault data storage (default is /data in the container)
BITWARDENCLI_APPDATA_DIR=/data
```

### Using your own Bitwarden server instance
If you're using your own instance of Bitwarden, set the host name in the environment variable `BW_HOST`. 
The docker container will automatically configure the CLI/API to use this host when the container is started or restarted. 

> 🔗 [Using an API key](https://bitwarden.com/help/cli/#using-an-api-key)

#### Persistent Vault State

The vault state/data is by default stored in a temporary volume (tmpfs) that is deleted when the container is removed.
To persist the vault data across container restarts, you can modify the `docker-compose.yml` file to use a named volume instead of a tmpfs, see the [persistent-data.compose.yml](persistent-data.compose.yml) file for the necessary changes.

You can change the path of the vault data with the `BITWARDENCLI_APPDATA_DIR` environment variable, which is by default set to `/data` in the container.

To run the container with a persistent volume, add the patch to the compose command like this:

```sh
docker compose -f docker-compose.yml -f persistent-data.compose.yml up -d
```

### Running the container
To run the container, run the docker compose configuration in [docker-compose.yml](docker-compose.yml) and execute the following command in the terminal:

```sh
docker compose up -d
```

### API Endpoints

See the [API documentation](https://bitwarden.com/help/vault-management-api/) for a complete list of available endpoints and their usage.

### Example Usage
You can run commands in the local host's shell using `curl`:

```sh
curl http://localhost:8087/object/item/{id}
```

#### Synchronize vault

The `/sync` endpoint synchronizes the vault with the Bitwarden server.

By default, the vault is automatically synchronized every 120 seconds.
To change the synchronization interval, you set the `VAULT_SYNC_INTERVAL` environment variable to a desired value in seconds (e.g., `VAULT_SYNC_INTERVAL=60` for 1 minute).

You can also trigger a manual synchronization using the following command:

```sh
curl -X POST http://localhost:8087/sync?force=true
```

## Building and running the image locally

1. Clone the repository
2. Specify the required environment variables in the `.env` file
3. Build and run the container using the following command:
    ```sh
   docker compose -f docker-compose.yml -f dev.compose.yml up
   ```

## Links
- [Bitwarden Password Manager CLI Documentation](https://bitwarden.com/help/cli/)
- [Bitwarden Vault Management API Documentation](https://bitwarden.com/help/vault-management-api/)