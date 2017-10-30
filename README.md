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

# Dependencies

Assuming you have ```cpanm``` installed, ```$ cpanm --installdeps .```

If not, you'll need to install the dependencies listed in the ```cpanfile``` yourself.

The hooks rely on [Git::Hooks](http://search.cpan.org/~gnustavo/Git-Hooks-2.1.7/lib/Git/Hooks.pm), [JIRA::REST](http://search.cpan.org/~gnustavo/JIRA-REST-0.010/lib/JIRA/REST.pm), and assumes you have a YAML parser installed (but is not opionated by which one). Right now, either [YAML::XS](http://search.cpan.org/dist/YAML-LibYAML/lib/YAML/XS.pod) and [YAML](http://search.cpan.org/~ingy/YAML-1.23/lib/YAML.pod) are supported.
