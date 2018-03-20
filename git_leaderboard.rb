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

class LeaderboardScriptOptions < CommitsScriptOptions
	attr_reader :output_path

	def initialize(args, option_parser)
		option_parser.on(
			"--output-path PATH",
			String,
			"Path to the output of the script.",
			"The output will be in the comma-separated values format."
			) do |output_path|
				@output_path = output_path
		end

		super(args, option_parser)
	end
end

if __FILE__ == $PROGRAM_NAME
	script_options = LeaderboardScriptOptions.new(ARGV, OptionParser.new)

	commits = commits_for_git_repo(script_options.git_repository_path,
		script_options.normalized_names,
		script_options.banned_names,
		script_options.banned_paths)

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
	if script_options.output_path
		csv_file = File.open(script_options.output_path, "w")
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

		if script_options.verbose
			puts author
			puts "\tCommits: #{num_commits} (#{num_commits_percentage}%)"
			puts "\tAdditions: #{num_additions} (#{num_additions_percentage}%)"
			puts "\tDeletions: #{num_deletions} (#{num_deletions_percentage}%)"
			puts "\tFiles Changed: #{num_files_changed} (#{num_files_changed_percentage}%)"
		end

		if (csv_file)
			csv_file.write("\n#{author},#{num_commits},#{num_commits_percentage},#{num_additions},#{num_additions_percentage},#{num_deletions},#{num_deletions_percentage},#{num_files_changed},#{num_files_changed_percentage}")
		end
	end

	if (csv_file)
		csv_file.close
	end
end
