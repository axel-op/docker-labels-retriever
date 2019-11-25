# Docker label retriever

This action retrieves the value of a [label from the metadata of an image](https://docs.docker.com/config/labels-custom-metadata/) on Docker Hub by calling the Docker API. The image isn't actually pulled so it's very fast.

Private images aren't supported yet but you can always make a pull request.

## Usage

This action has one output which is the value of the specified label. You have to set an id to the step of this action, so you can use this value in the next steps of your workflow with `${{ steps.the_id.outputs.value }}`.

Here's an example:

```yml
    name: Example workflow
    on: push

    jobs:
      build:
        runs-on: ubuntu-latest
        steps:

          - name: Check label
            id: label_version # this id will be reused below
            uses: axel-op/docker-label-retriever@master
            with:
              image: repo/image:stable # omitting the tag will default to latest
              label: version # label whose value must be retrieved

          # You can then use the value
          - name: Another step
            # ... in an if condition:
            if: steps.label_version.outputs.value == '...'
            # ... in an environment variable:
            env:
              VERSION: ${{ steps.label_version.outputs.value }}
            # ... or directly in your scripts:
            run: echo "${{ steps.label_version.outputs.value }}"
```
