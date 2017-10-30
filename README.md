# git-hooks

Automatically change the status of JIRA tickets on commit.

Currently, the hook runs on ```commit-msg``` and looks for the ticket information in the commit message in the format:

```[QA-2183]```

## Example

```$ git commit -m "[DEV-2184] Fix memory leak"```

# Configuration

The hook needs to know your JIRA login info and the ID of the transition each hook should update.

You can create a YAML configuration file anywhere you wish in the following format:

```yaml
jira_username: your_jira_username
jira_password: your_jira_pssword
jira_url: https://your-jira-link.com
transitions:
  commit-msg: 4
````

And then export the path to your config file like so:

```bash
$ export GIT_HOOK_CONFIG=/path/to/your/config.yml
```

Set ```GIT_HOOK_DEBUG=1``` to enable extra warnings.
