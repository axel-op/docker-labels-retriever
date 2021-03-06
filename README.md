![A Dockerfile with multiple labels](picture.png)

# Docker labels retriever

This action retrieves the values of [labels from the metadata of an image](https://docs.docker.com/config/labels-custom-metadata/) on Docker Hub, GitHub Packages or Google Container Registry, by calling the Docker API. The image isn't actually pulled so it's very fast.

## Usage

For each label of the image, this action sets an output whose name is the name of the label **in lower case**. You have to set an id for the step of this action, so you can use the outputs in the next steps of your workflow with `${{ steps.the_id.outputs.name_of_label }}`.

Here's an example of a workflow where the values of two labels, `version` and `maintainer`, set when the image has been previously built, are retrieved:

```yml
    name: Example workflow
    on: push

    jobs:
      build:
        runs-on: ubuntu-latest
        steps:

          - name: Check labels
            id: labels # this id will be reused below
            uses: axel-op/docker-labels-retriever@v1.0.0
            with:
              image: owner/repo/image:tag
              registry: github-packages
              accessToken: ${{ secrets.GITHUB_TOKEN }}

          # You can then get the values
          - name: Another step
            # ... in an if condition:
            if: steps.labels.outputs.version == '...'
            # ... in an environment variable:
            env:
              VERSION: ${{ steps.labels.outputs.version }}
              MAINTAINER: ${{ steps.labels.outputs.maintainer }}
            # ... or directly in your scripts:
            run: |
              echo "${{ steps.labels.outputs.version }}"
              echo "${{ steps.labels.outputs.maintainer }}"
```

### Inputs

* `registry`: **required**. Accepted values are:
  * `docker-hub`
  * `github-packages`
  * `gcr` (Google Container Registry)

* `image`: **required**. Format is:
  * `namespace/repository` with Docker Hub
  * `owner/repository/image_name` with GitHub Packages
  * `project_id/image` with Google Container Registry

  You can add a specific tag. The tag `latest` will be used by default.

#### With Docker Hub

* `dockerHubUsername`: **required only for private images**. It must be the username of an account that can access the image. Omit it with public images.
* `accessToken`: **required only for private images**. It can be a password or an [access token](https://docs.docker.com/docker-hub/access-tokens/). Omit it with public images.

#### With GitHub Packages

* `accessToken`: **required**, even with public images. In most cases the [`GITHUB_TOKEN`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/authenticating-with-the-github_token) should be fine.

#### With Google Container Registry

* `hostname`: **required**. Hostname of the image. Could be:
  * gcr.io
  * eu.gcr.io
  * us.gcr.io
  * asia.gcr.io
* `accessToken`: **required only for private images**. It must be a JSON key of a [service account with sufficient privileges](https://support.google.com/cloud/answer/6158849?hl=fr#serviceaccounts). Omit it with public images.
