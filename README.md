# git-hooks

Automatically update the status of Jira tickets on push.

Currently, the hook runs on ```pre-push``` and looks for the ticket information in the commit message in the format:

```
[prefix-number] -> [QA-2183]
```

## Example

```base
	$ git commit -m "[DEV-2184] Fix memory leak"
	$ git push

Updating [DEV-2184]
```

Handles multiple commits. The hook will parse through your git log starting from the last push to master.
If the ticket is mentioned multiple times, only one request will be sent to Jira.

# Configuration

The hook needs to know your Jira login info and the transition ID each hook should update to.

You can create a YAML configuration file anywhere you wish with the following data:

```yaml
jira_username: your_jira_username
jira_password: your_jira_pssword
jira_url: https://your-jira-link.com
transitions:
  pre-push: 31
````

And then export the path to your config file like so:

```bash
$ export GIT_HOOK_CONFIG=/path/to/your/config.yml
```

You can also export you login info:

```bash
$ export JIRA_USERNAME=your_username
$ export JIRA_PASSWORD=your_password
$ export JIRA_URL=your_url
```

Or even leave your credentials in a ```.netrc```, ```~/.jira-identity```, or ```~/.jira``` file.

Set ```GIT_HOOK_DEBUG=1``` to enable extra warnings.

# Dependencies

Assuming you have ```cpanm``` installed: ```$ cpanm --installdeps .```

If not, you'll need to install the dependencies listed in the ```cpanfile``` yourself.

The hooks rely on [Git::Hooks](http://search.cpan.org/~gnustavo/Git-Hooks-2.1.7/lib/Git/Hooks.pm), [JIRA::REST](http://search.cpan.org/~gnustavo/JIRA-REST-0.010/lib/JIRA/REST.pm), and assumes you have a YAML parser installed (but is not opinionated about which one). Right now, either [YAML::XS](http://search.cpan.org/dist/YAML-LibYAML/lib/YAML/XS.pod) or [YAML](http://search.cpan.org/~ingy/YAML-1.23/lib/YAML.pod) are supported.

# Create the hook

Assuming you have an initialized git repo, move the script to your .git/hooks dir:

```bash
$ cp ~/git-hooks/git-hooks.pl ~/your_repo/.git/hooks/git-hooks.pl
```

Symlink the script:

```bash
$ ln -s your_repo/.git/git-hooks.pl your_repo/.git/hooks/pre-push
$ chmod a+x your_repo/.git/git-hooks.pl
$ chmod a+x your_repo/.git/hooks/pre-push
```

Re-init your repo:

```bash
$ git init
```
