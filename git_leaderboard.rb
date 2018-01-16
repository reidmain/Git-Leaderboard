#!/usr/bin/env ruby

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
	git_repo = ARGV[0]
	git_repo ||= Dir.pwd

	commits = commits_for_git_repo(git_repo)

	author_summaries = Hash.new()

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
