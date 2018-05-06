# TL;DR?
*Optional: Install [rbenv](https://github.com/rbenv/rbenv) to ensure you are using a supported version of Ruby*
```
git clone git@github.com:reidmain/Git-Leaderboard.git $PATH_FOR_GIT_LEADERBOARD
cd $PATH_FOR_GIT_LEADERBOARD
./Source/git_leaderboard.rb --git-repository $PATH_TO_GIT_REPOSITORY_YOU_WANT_LEADERBOARD_FOR --output-path leaderboard
```
Open up leaderboard.csv and enjoy a tabular representation of your git repository's leaderboard.

# Overview
I am a big fan of [GitHub's contributor insight](https://help.github.com/articles/viewing-contribution-activity-in-a-repository/). It gives a nice visual representation of a person's contributions to a repository over time and who doesn't like to see how many total lines of code they have removed? Also, I will admit, I do enjoy seeing how many imaginary Internet points I have and how they stack up against everyone else.

However there are five shortcomings to GitHub's contributor insight in my opinion:
1. Every commit is treated equally. In every git repository there are some files that are auto-generated or some commits that are made automatically by a bot and in an ideal world these commits would be ignored. I understand why GitHub cannot do this. They do not have context for every repository they host so they cannot make sweeping judgments as to what is a good file modification and what is a bad one.
2. It only recognizes commits whose email address is registered to a GitHub account.
3. It does not highlight how many file modifications were made. Only the number of commits, lines added and lines deleted.
4. It does not compare your statistics to other contributors. You could manually try to compute what percentage of additions or deletions you made to an entire project but if there are hundreds of contributors have fun doing all of that math by hand.
5. It only works with repositories hosted on GitHub. Many companies host their own git repositories and cannot gain access to these insights.

So in my never-ending quest for imaginary Internet points I decided that I would attempt to rectify all of these shortcomings by parsing the commit history of a git repository and computing the data I wanted.

At first I thought I would be clever and access the git file system directly. It couldn't be that hard right? After reading about how insanely difficult it actually was I promptly abandoned that plan. My next attempt involved opening up a bash terminal and trying to parse the output of `git log`. While it is probably possible to do what I was hoping using `awk`, or any number of unix commands that were created before I was born, the documentation was so dense that I just couldn't grok it and ended up abandoning this attempt as well. For plan C I decided it was time to go with the safe choice and fall back to scripting with Ruby which was there I finally succeeded.

I ended up creating three ruby files:  
1. `git_commits.rb` which parses the output of `git log` and converts it into an array of Ruby objects that you can easily iterate over.
2. `git_leaderboard.rb` which consumes that array of commit objects and computes what I think is the definitive version of a leaderboard for a git repository.
3. `git_banzuke.rb` which consumes a configuration file that specifies a number of repositories to compute a leaderboard for exactly like `git_leaderboard.rb`. The only difference is that at the end it computes a [Banzuke](https://en.wikipedia.org/wiki/Banzuke) that is an amalgamation of all of the git repositories leaderboards. The idea was you would use this to generate an overall leaderboard for an organization.

# Installation
I have never shipped a [Ruby gem](https://rubygems.org) before so unfortunately only way to "install" this currently is to clone this git repository and run the scripts directly. You could consider adding the cloned location to your `$PATH` if you found yourself using these scripts so often but I suspect running the scripts directly will be fine for most.

I do use [rbenv](https://github.com/rbenv/rbenv) to specify which version of Ruby I support (at the time of this writing it is v2.4.0). To be absolutely certain the scripts will work correctly I recommend installing [rbenv](https://github.com/rbenv/rbenv) and running the scripts from inside the git repository.

This project has no external dependencies. Everything you need is packaged with Ruby.

# Usage
This project is comprised of three Ruby files: git_commits.rb, git_leaderboard.rb and git_banzuke.rb.

### git_commits.rb
This file defines classes and methods to extract and operate on commits in a git repository.

It has a method called `commits_for` that returns an array of `Commit` objects for a git repository. These `Commit` objects store information like the author's email, all of the file modifications made, etc.

git_commits.rb also has the ability to be run as a script which will leverage the aforementioned method and output the results to the console. You can see what options can be supplied using `git_commits.rb --help`

A `CommitsOptions` class exists to simplify the parsing of arguments passed in via the command line. It is also designed to be subclassed so other scripts that want to gather similar arguments can do so easily. You can see an example of this inheritance in the git_leaderboard.rb file.

### git_leaderboard.rb
This file defines classes and methods to group commits from a git repository and generate a leaderboard.

It has a method called `author_summaries_for` that returns an array of `AuthorSummary` objects. These `AuthorSummary` objects contain information and statistics about commits that an author made to a git repository.

Another method called `generate_leaderboard_for` can then consume these author summaries and generate a leaderboard by grouping all of the author summaries by email and computing the total number of commits, additions, deletions and file modifications relative to the entire repository.

git_leaderboard.rb also has the ability to be run as a script which will leverage the aforementioned methods and output the leaderboard to either a CSV file and/or the console. You can see what options can be supplied using `git_leaderboard.rb --help`

### git_banzuke.rb
The sole purpose of this script is to generate the leaderboards for a number of git repositories and then amalgamate their results into a single "mega repository" that I am referring to as a [Banzuke](https://en.wikipedia.org/wiki/Banzuke). You can see what options can be supplied using `git_banzuke.rb --help`