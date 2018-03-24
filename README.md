# TL;DR?
*Optional: Install [rbenv](https://github.com/rbenv/rbenv) to ensure you are using a supported version of Ruby*
```
git clone git@github.com:reidmain/Git-Leaderboard.git $PATH_FOR_GIT_LEADERBOARD
cd $PATH_FOR_GIT_LEADERBOARD
./git_leaderboard.rb --git-repository $PATH_TO_GIT_REPOSITORY_YOU_WANT_LEADERBOARD_FOR --output-path leaderboard.csv
```
Open up leaderboard.csv and enjoy a tabular representation of your git repository's leaderboard.

# Overview
I am a big fan of [GitHub's contributor insight](https://help.github.com/articles/viewing-contribution-activity-in-a-repository/). It gives a nice visual representation of a person's contributions to a repository over time and who doesn't like to see how many total lines of code they have removed? Also, I will admit, I do enjoy seeing how many imaginary Internet points I have and how they stack up against everyone else.

However there are five shortcomings to GitHub's contributor insight in my opinion:
1. Every commit is treated equally. In every git repository there are some files that are auto-generated or some commits that are made automatically by a bot and in an ideal world these commits would be ignored. I understand why GitHub cannot do this. They do not have context for every repository they host so they cannot make sweeping judgements as to what is a good file modification and what is a bad one.
2. It only recognizes commits whose email address is registered to a GitHub account.
3. It does not highlight how many file modifications were made. Only the number of commits, lines added and lines deleted.
4. It does not compare your statistics to other contributors. You could manually try to compute what percentage of additions or deletions you made to an entire project but if there are hundreds of contributors have fun doing all of that math by hand.
5. It only works with repositories hosted on GitHub. Many companies host their own git repositories and cannot gain access to these insights.

So in my neverending quest for imaginary Internet points I decided that I would attempt to rectify all of these shortcomings by parsing the commit history of a git repository and computing the data I wanted.

At first I thought I would be clever and access the git file system directly. It couldn't be that hard right? After reading about how insanely difficult it actually was I promptly abandoned that plan. My next attempt involved opening up a bash terminal and trying to parse the output of `git log`. While it is probably possible to do what I was hoping using `awk`, or any number of unix commands that were created before I was born, the documentation was so dense that I just couldn't grok it and ended up abandoning this attempt as well. For plan C I decided it was time to go with the safe choice and fall back to scripting with Ruby which was there I finally succeeded.

I ended up creating two ruby files:  
`git_commits.rb` which parses the output of `git log` and converts it into an array of Ruby objects that you can easily iterate over and  
`git_leaderboard.rb` which consumes that array of commit objects and computes what I think is the definitive version of a leaderboard for a git repository.

# Installation
I have never shipped a [Ruby gem](https://rubygems.org) before so unfortunately only way to "install" this currently is to clone this git repository and run the scripts directly. You could consider adding the cloned location to your `$PATH` if you found yourself using these scripts so often but I suspect running the scripts directly will be fine for most.

I do use [rbenv](https://github.com/rbenv/rbenv) to specify which version of Ruby I support (at the time of this writing it is v2.4.0). To be absolutely certain the scripts will work correctly I recommend installing [rbenv](https://github.com/rbenv/rbenv) and running the scripts from inside the git repository.

This project has no external dependencies. Everything you need is packaged with Ruby.

# Usage
This project is comprised of two Ruby files: git_commits.rb and git_leaderboard.rb.

### git_commits.rb
This file defines a `Commit` object which represents a single git commit. It also defines a method, `commits_for_git_repo`, that allows you to get an array of `Commit` objects for a git repository. This is useful if you want to grok these `Commit` objects in another bit of Ruby code which is exactly what the `git_leaderboard.rb` does.

git_commits.rb also has the ability to be run as a script which will leverage the aforementioned method and output the results to the console.

You can see what parameters can be supplied using `./git_commits.rb --help`

```
--git-repository PATH		Path to the git repository to analyze.
							Defaults to the current directory if no path is provided.
--normalized-names JSON		A JSON object where the keys are the committers' names and the values are what the names should be normalized to.
							For when a single author has committed under multiple names or for that one crazy committer whose name makes absolutely no sense.
							Can be either a JSON string or a path to a JSON file.
--banned-names JSON			A JSON array of author names whose commits should be ignored.
							Primarily designed for authors whose commits are automated.
							Can be either a JSON string or a path to a JSON file.
--banned-paths JSON			A JSON array of regular expressions used to omit file modifications to specific paths.
							Can be either a JSON string or a path to a JSON file.
--verbose BOOL				A switch to determine if actions taken should be outputted to the console.
							Defaults to true.
```

A `CommitsScriptOptions` object is defined to make it easy to parse the input of the script as well as allow other scripts to inherit these same options. You can see an example of this inheritance in the git_leaderboard.rb file.

### git_leaderboard.rb
This file is a script that leverages git_commits.rb to group all of the commits by author and then compute the total number of commits, additions, deletions and file modifications relative to the entire repository.

You can see what parameters can be supplied using `./git_leaderboard.rb --help`

```
--output-path PATH			Path to the output of the script.
							The output will be in the comma-separated values format.
--git-repository PATH		Path to the git repository to analyze.
							Defaults to the current directory if no path is provided.
--normalized-names JSON		A JSON object where the keys are the committers' names and the values are what the names should be normalized to.
							For when a single author has committed under multiple names or for that one crazy committer whose name makes absolutely no sense.
							Can be either a JSON string or a path to a JSON file.
--banned-names JSON			A JSON array of author names whose commits should be ignored.
							Primarily designed for authors whose commits are automated.
							Can be either a JSON string or a path to a JSON file.
--banned-paths JSON			A JSON array of regular expressions used to omit file modifications to specific paths.
							Can be either a JSON string or a path to a JSON file.
--verbose BOOL				A switch to determine if actions taken should be outputted to the console.
							Defaults to true.
```
