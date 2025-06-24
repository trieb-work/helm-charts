# Google Cloud Storage (GCS) Configuration for Saleor

This document explains how to configure Google Cloud Storage (GCS) for Saleor using the Helm chart.

## Prerequisites

1. A Google Cloud Platform (GCP) account with a project
2. A GCS bucket created for Saleor media files
3. A service account with appropriate permissions to access the GCS bucket
4. A service account key (JSON) for authentication

## Creating a Service Account and Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to "IAM & Admin" > "Service Accounts"
3. Create a new service account or select an existing one
4. Assign the following roles to the service account:
   - Storage Object Admin (`roles/storage.objectAdmin`) for the bucket(s)
   - Storage Admin (`roles/storage.admin`) if you want Saleor to create buckets
5. Create a new JSON key for the service account
6. Download the JSON key file

## Configuring the Helm Chart

Update your `values.yaml` file or use `--set` flags to configure GCS storage:

```yaml
storage:
  gcs:
    enabled: true
    credentials:
      # Paste the entire content of your service account JSON key file
      jsonKey: |
        {
          "type": "service_account",
          "project_id": "your-project-id",
          "private_key_id": "key-id",
          "private_key": "-----BEGIN PRIVATE KEY-----\nkey-content\n-----END PRIVATE KEY-----\n",
          "client_email": "service-account@your-project-id.iam.gserviceaccount.com",
          "client_id": "client-id",
          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
          "token_uri": "https://oauth2.googleapis.com/token",
          "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
          "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/service-account%40your-project-id.iam.gserviceaccount.com"
        }
    config:
      
      # Static files configuration (CSS, JS, email templates)
      staticBucketName: "my-saleor-static"
      
      # Media files configuration (product images, category images)
      mediaBucketName: "my-saleor-media"
      
      # Private files configuration (webhook payloads, private data)
      mediaPrivateBucketName: "my-saleor-private"
      
      # Optional: Custom endpoints for GCS
      # customEndpoint: "https://storage.googleapis.com"
      # mediaCustomEndpoint: "https://storage.googleapis.com"
      
      # Access control and URL settings
      defaultAcl: "publicRead"  # Options: "publicRead", leave empty for private
      queryStringAuth: true     # Enable signed URLs for media access. Optional
      queryStringExpire: 86400  # Signed URLs expiration in seconds (1 day). Optional.
```

## Security Considerations

1. The service account JSON key contains sensitive credentials. Ensure it's properly secured.
2. Consider using Kubernetes Secrets management solutions like Sealed Secrets, Vault, or a cloud provider's secret management service.
3. For the `mediaPrivateBucketName` bucket, ensure it has appropriate access controls to prevent public access to sensitive data.

## CORS Configuration for GCS Buckets

For proper functioning of Saleor with GCS, you need to configure CORS settings on your buckets. This is especially important for serving SVG files, JavaScript files, and other web assets.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to "Storage" > "Browser"
3. Select your bucket
4. Go to the "Permissions" tab
5. Scroll down to the "CORS configuration" section
6. Add a CORS configuration like the following:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CorsConfig>
  <Cors>
    <Origins>
      <Origin>https://your-saleor-domain.com</Origin>
    </Origins>
    <Methods>
      <Method>GET</Method>
      <Method>HEAD</Method>
    </Methods>
    <ResponseHeaders>
      <ResponseHeader>Content-Type</ResponseHeader>
    </ResponseHeaders>
    <MaxAgeSec>3600</MaxAgeSec>
  </Cors>
</CorsConfig>
```

Replace `https://your-saleor-domain.com` with your actual Saleor domain.

## Troubleshooting

1. **Permission Issues**: Ensure the service account has the correct roles assigned for the GCS buckets.
2. **Invalid Credentials**: Verify the JSON key is correctly formatted and not corrupted.
3. **CORS Issues**: If you're experiencing issues with loading assets, check the CORS configuration on your GCS bucket.
4. **Bucket Not Found**: Confirm the bucket names are correct and the buckets exist in the specified project.

## Why Workload Identity Isn't Supported

Saleor requires the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to a JSON file containing the service account credentials. When using Workload Identity in Kubernetes, credentials are provided through the metadata server, not as a JSON file. Since Saleor's storage backend expects a file path, Workload Identity cannot be used directly.

If you're running on GKE and want to avoid managing service account keys, consider implementing a sidecar container that fetches a short-lived service account key and periodically refreshes it for Saleor to use.
