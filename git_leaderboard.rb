#!/usr/bin/env ruby

require "optparse"

require_relative "./git_commits.rb"

class AuthorSummary
	attr_reader :author_name
	attr_reader :commits
	attr_reader :additions
	attr_reader :deletions
	attr_reader :files_modified

	def initialize(author_name)
		@author_name = author_name
		@commits = 0
		@additions = 0
		@deletions = 0
		@files_modified = 0
	end

	def append(commit)
		@commits += 1
		@additions += commit.additions
		@deletions += commit.deletions
		@files_modified += commit.file_modifications.count
	end

	def to_s
		return "Author: #{@author_name}\nCommits: #{@commits}\nAdditions: #{@additions}\nDeletions: #{@deletions}\nFiles Modified: #{@files_modified}"
	end
end

if __FILE__ == $PROGRAM_NAME
	git_repo_path ||= Dir.pwd
	normalized_names = {}

	OptionParser.new do |parser|
		parser.accept(JSON) do |possible_json|
			if File.file?(possible_json)
				json_data = File.read(possible_json)
				json = JSON.parse(json_data)
			else
				json = JSON.parse(possible_json)
			end
		end

		parser.on(
			"--git-repo=PATH",
			"The path to the git repository. Defaults to the directory the script is run from.",
			String
			) do |option_git_repo_path|
				git_repo_path = option_git_repo_path
			end

		parser.on(
			"--normalized-names DATA",
			"Either the path to a JSON file or a JSON string that contains a hash of normalized usernames.",
			JSON
			) do |json|
				normalized_names = json
			end
	end.parse!

	commits = commits_for_git_repo(git_repo_path, normalized_names)

	author_summaries = {}

	commits.each do |commit|
		author_name = commit.author_name

		author_summary = author_summaries[author_name]
		if author_summary == nil
			author_summary = AuthorSummary.new(author_name)
			author_summaries[author_name] = author_summary
		end

		author_summary.append(commit)
	end

	sorted_author_summaries_by_num_commits = author_summaries.values.sort { |x, y| y.commits <=> x.commits }
	puts sorted_author_summaries_by_num_commits
end
