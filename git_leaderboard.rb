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
	banned_filenames = []

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
			"--normalized-names JSON",
			"Either the path to a JSON file or a JSON string that contains a hash of normalized usernames.",
			JSON
			) do |json|
				normalized_names = json
			end

		parser.on(
			"--banned-filenames JSON",
			"Either the path to a JSON file or a JSON string that contains an array of banned filenames. Regex is acceptable..",
			JSON
			) do |json|
				banned_filenames = json
			end
	end.parse!

	commits = commits_for_git_repo(git_repo_path, normalized_names, banned_filenames)

	author_summaries = {}

	commits.each do |commit|
		author_name = commit.author_name

		author_summary = author_summaries[author_name]
		if author_summary == nil
			author_summary = AuthorSummary.new(author_name)
			author_summaries[author_name] = author_summary
		end

		if commit.file_modifications.count > 0
			author_summary.append(commit)
		end
	end

	sorted_author_summaries_by_num_commits = author_summaries.values.sort { |x, y| y.commits <=> x.commits }
	total_commits = sorted_author_summaries_by_num_commits.sum { |x| x.commits }
	total_additions = sorted_author_summaries_by_num_commits.sum { |x| x.additions }
	total_deletions = sorted_author_summaries_by_num_commits.sum { |x| x.deletions }
	total_files_changed = sorted_author_summaries_by_num_commits.sum { |x| x.files_modified }

	csv_file = nil
	filename = "output"
	if (filename)
		csv_file = File.open("#{filename}.csv", "w")
		csv_file.write("Author,Commits,% of Commits,Additions,% of Additions,Deletions,% of Deletions,Files Changed,% of Files Changed")
	end

	sorted_author_summaries_by_num_commits.each do |author_summary|
		author = author_summary.author_name
		num_commits = author_summary.commits
		num_additions = author_summary.additions
		num_deletions = author_summary.deletions
		num_files_changed = author_summary.files_modified

		num_commits_percentage = (num_commits / total_commits.to_f * 100).round(2)
		num_additions_percentage = (num_additions / total_additions.to_f * 100).round(2)
		num_deletions_percentage = (num_deletions / total_deletions.to_f * 100).round(2)
		num_files_changed_percentage = (num_files_changed / total_files_changed.to_f * 100).round(2)

		puts author
		puts "\tCommits: #{num_commits} (#{num_commits_percentage}%)"
		puts "\tAdditions: #{num_additions} (#{num_additions_percentage}%)"
		puts "\tDeletions: #{num_deletions} (#{num_deletions_percentage}%)"
		puts "\tFiles Changed: #{num_files_changed} (#{num_files_changed_percentage}%)"

		if (csv_file)
			csv_file.write("\n#{author},#{num_commits},#{num_commits_percentage},#{num_additions},#{num_additions_percentage},#{num_deletions},#{num_deletions_percentage},#{num_files_changed},#{num_files_changed_percentage}")
		end
	end

	if (csv_file)
		csv_file.close
	end
end
