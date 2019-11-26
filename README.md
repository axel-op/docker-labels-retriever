# Docker labels retriever

This action retrieves the values of [labels from the metadata of an image](https://docs.docker.com/config/labels-custom-metadata/) on Docker Hub by calling the Docker API. The image isn't actually pulled so it's very fast.

Private images aren't supported yet but you can always make a pull request.

## Usage

For each label of the image, this action sets an output whose name is the name of the label **in lower case**. You have to set an id for the step of this action, so you can use the outputs in the next steps of your workflow with `${{ steps.the_id.outputs.name_of_label }}`.

Here's an example of a workflow where the value of the label `version` is retrieved:

```yml
    name: Example workflow
    on: push

    jobs:
      build:
        runs-on: ubuntu-latest
        steps:

          - name: Check labels
            id: labels # this id will be reused below
            uses: axel-op/docker-labels-retriever@master
            with:
              image: repo/image:stable # omitting the tag will default to latest

          # You can then get the values ('version' is the name of the label)
          - name: Another step
            # ... in an if condition:
            if: steps.labels.outputs.version == '...'
            # ... in an environment variable:
            env:
              VERSION: ${{ steps.labels.outputs.version }}
            # ... or directly in your scripts:
            run: echo "${{ steps.labels.outputs.version }}"
```
