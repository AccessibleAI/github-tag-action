### Usage 

```Dockerfile
name: Docker Image CI

on:
  push:
  workflow_dispatch:
    inputs:
      msg:
        description: "Msg instead of commit log"
        required: true
        default: 'false'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Bump version and push tag
      uses: AccessibleAI/github-tag-action@1.1.0
      id: tag_bump
      env:
        MSG: ${{ github.event.inputs.msg }}
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
#### Options

**Environment Variables**

- **GITHUB_TOKEN** **_(required)_** - Required for permission to tag the repo.
- **DEFAULT_BUMP** _(optional)_ - Which type of bump to use when none explicitly provided (default: `none`).
- **WITH_V** _(optional)_ - Tag version with `v` character.
- **RELEASE_BRANCHES** _(optional)_ - Comma separated list of branches (bash reg exp accepted) that will generate the release tags. Other branches and pull-requests generate versions postfixed with the commit hash and do not generate any tag. Examples: `master` or `.*` or `release.*,hotfix.*,master` ...
- **CUSTOM_TAG** _(optional)_ - Set a custom tag, useful when generating tag based on f.ex FROM image in a docker image. **Setting this tag will invalidate any other settings set!**
- **SOURCE** _(optional)_ - Operate on a relative path under $GITHUB_WORKSPACE.
- **INITIAL_VERSION** _(optional)_ - Set initial version before bump. Default `0.0.0`.
- **VERBOSE** _(optional)_ - Print git logs. For some projects these logs may be very large. Possible values are `true` (default) and `false`.

#### Outputs

- **new_tag** - The value of the newly created tag.
- **tag** - The value of the latest tag after running this action.
- **part** - The part of version which was bumped.
- **log** - The commit message.

### Bumping

**Manual Bumping:** Any commit message that includes `#major`, `#minor`, `#patch`, or `#none` will trigger the respective version bump. If two or more are present, the highest-ranking one will take precedence.
If `#none` is contained in the commit message, it will skip bumping regardless `DEFAULT_BUMP`.

**Automatic Bumping:** If no `#major`, `#minor` or `#patch` tag is contained in the commit messages, it will bump whichever `DEFAULT_BUMP` is set to (which is `minor` by default). Disable this by setting `DEFAULT_BUMP` to `none`.


### Workflow

- Add this action to your repo
- Commit some changes
- Either push to master or open a PR
- On push (or merge), the action will:
  - Get latest tag
  - Bump tag with minor version unless any commit message contains `#major` or `#patch`
  - Pushes tag to github
  - If triggered on your repo's default branch (`master` or `main` if unchanged), the bump version will be a release tag.
  - If triggered on any other branch, a prerelease will be generated, depending on the bump, starting with `*-<BRANCH>.1`, `*-<BRANCH>.2`, ...

### Semver Keyword Options - for example: git commit -m "blabla #major blabla"
- **major** - 1.0.0 -> 2.0.0
- **minor** - 1.0.0 -> 1.1.0
- **patch/hotfix** - 1.0.0 -> 1.1.1
- **premajor** - 1.0.0 -> 2.0.0-rc.0
- **preminor** - 1.0.0 -> 1.1.0-rc.0
- **prehotfix/prerelease/rc** - 1.0.0 -> 1.0.1-rc.0
- **dirty** - dirty-(randomstring)
- **custom** - eliowns-testing-1.1.1
