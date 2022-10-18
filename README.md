# VVV Roots Bedrock Site Provisioner

A Roots Bedrock project provisioner for [VVV](https://varyingvagrantvagrants.org/).
This tells VVV how to install [Bedrock](https://roots.io/bedrock/) project, install
[Sage](https://roots.io/sage/) starter theme (optionally) and set up Nginx.

## Custom Configuration Options

These are custom options unique to the custom site template, and go in the 
custom: section of the site in `config.yml`. For example here is how to 
use `bedrock_version`:

```yaml
  bedrock-site:
    repo: https://github.com/valenjeb/vvv-bedrock-template.git
    hosts:
      - bedrock.test
    custom:
      bedrock_version: 1.0.0
```

Below is a full list of the custom options this template implements:

| Key               | Type           | Default                    | Description                                                                                                                                                                                                                                                                                                                                                        |
|-------------------|----------------|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `admin_email`     | string         | `admin@local.test`         | The email address of the initial admin user                                                                                                                                                                                                                                                                                                                        |
| `admin_password`  | string         | `password`                 | The password for the initial admin user                                                                                                                                                                                                                                                                                                                            |
| `admin_user`      | string         | `admin`                    | The name of the initial admin user                                                                                                                                                                                                                                                                                                                                 |
| `db_name`         | string         | The sites name             | The name of the MySQL database to create and install to                                                                                                                                                                                                                                                                                                            |
| `db_prefix`       | string         | `wp_`                      | The WP table prefix                                                                                                                                                                                                                                                                                                                                                |
| `live_url`        | string         |                            | The production site URL, e.g. `https://example.com`. This tells Nginx to browser redirect requests for assets at `/wp-content/uploads` to the production server if they're not found. This prevents the need to store those assets locally.  <br>If you do not use the `wp-content/uploads` path then this will not work, and you should not add a trailing slash. |
| `site_title`      | string         | The first host of the site | The main name/title of the site, defaults to `sitename.test`                                                                                                                                                                                                                                                                                                       |
| `bedrock_version` | string         | `*`                        | The version of Bedrock to install if no installation is present                                                                                                                                                                                                                                                                                                    |
| `bedrock_dir`     | string         | `htdocs`                   | The root directory for Bedrock installation.                                                                                                                                                                                                                                                                                                                       |
| `sage`            | true or string |                            | Set to `true` to install Sage theme named `core-theme` or set the desired theme name. Keep empty to skip the Sage theme installation.                                                                                                                                                                                                                              |

