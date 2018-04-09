#!/usr/bin/env ruby

require "optparse"

require_relative "./git_commits.rb"

class AuthorSummary
	attr_reader :author_name
	attr_reader :number_of_commits
	attr_reader :number_of_additions
	attr_reader :number_of_deletions
	attr_reader :number_of_files_modified

	def initialize(author_name:, number_of_commits: 0, number_of_additions: 0, number_of_deletions:0, number_of_files_modified: 0)
		@author_name = author_name
		@number_of_commits = number_of_commits
		@number_of_additions = number_of_additions
		@number_of_deletions = number_of_deletions
		@number_of_files_modified = number_of_files_modified
	end

	def append(commit)
		@number_of_commits += 1
		@number_of_additions += commit.additions
		@number_of_deletions += commit.deletions
		@number_of_files_modified += commit.file_modifications.count
	end

	def to_s
		return "Author: #{@author_name}\nCommits: #{@number_of_commits}\nAdditions: #{@number_of_additions}\nDeletions: #{@number_of_deletions}\nFiles Modified: #{@number_of_files_modified}"
	end
end

def author_summaries_for(
	git_repository_path:,
	normalized_names:,
	banned_names:,
	banned_paths:,
	verbose:
)
	commits = commits_for_git_repo(git_repository_path,
		normalized_names,
		banned_names,
		banned_paths,
		verbose)

	author_summaries = {}

	commits.each do |commit|
		author_name = commit.author_name

		author_summary = author_summaries[author_name]
		if author_summary == nil
			author_summary = AuthorSummary.new(author_name: author_name)
			author_summaries[author_name] = author_summary
		end

		if commit.file_modifications.count > 0
			author_summary.append(commit)
		end
	end

	return author_summaries
end

def process(
	author_summaries:,
	output_path: nil,
	verbose: false
)
	sorted_author_summaries_by_number_of_commits = author_summaries.values.sort { |x, y| y.number_of_commits <=> x.number_of_commits }
	total_commits = sorted_author_summaries_by_number_of_commits.sum { |x| x.number_of_commits }
	total_additions = sorted_author_summaries_by_number_of_commits.sum { |x| x.number_of_additions }
	total_deletions = sorted_author_summaries_by_number_of_commits.sum { |x| x.number_of_deletions }
	total_files_modified = sorted_author_summaries_by_number_of_commits.sum { |x| x.number_of_files_modified }

	csv_file = nil
	if output_path
		csv_file = File.open(File.expand_path("#{output_path}.csv"), "w")
		csv_file.write("Author,Commits,% of Commits,Additions,% of Additions,Deletions,% of Deletions,Files Modified,% of Files Modified")
		csv_file.write("\n,#{total_commits},100,#{total_additions},100,#{total_deletions},100,#{total_files_modified},100")
	end

	sorted_author_summaries_by_number_of_commits.each do |author_summary|
		author = author_summary.author_name
		number_of_commits = author_summary.number_of_commits
		number_of_additions = author_summary.number_of_additions
		number_of_deletions = author_summary.number_of_deletions
		number_of_files_modified = author_summary.number_of_files_modified

		commits_percentage = (number_of_commits / total_commits.to_f * 100).round(2)
		additions_percentage = (number_of_additions / total_additions.to_f * 100).round(2)
		deletions_percentage = (number_of_deletions / total_deletions.to_f * 100).round(2)
		files_modified_percentage = (number_of_files_modified / total_files_modified.to_f * 100).round(2)

		if verbose
			puts author
			puts "\tCommits: #{number_of_commits} (#{commits_percentage}%)"
			puts "\tAdditions: #{number_of_additions} (#{additions_percentage}%)"
			puts "\tDeletions: #{number_of_deletions} (#{deletions_percentage}%)"
			puts "\tFiles Modified: #{number_of_files_modified} (#{files_modified_percentage}%)"
		end

		if (csv_file)
			csv_file.write("\n#{author},#{number_of_commits},#{commits_percentage},#{number_of_additions},#{additions_percentage},#{number_of_deletions},#{deletions_percentage},#{number_of_files_modified},#{files_modified_percentage}")
		end
	end

	if (csv_file)
		csv_file.close
	end
end

class LeaderboardScriptOptions < CommitsScriptOptions
	attr_reader :output_path

	def initialize(args, option_parser)
		option_parser.on(
			"--output-path PATH",
			String,
			"The path that the script should save its output to.",
			"The output will be a comma-separated values text file and as such will automatically have \".csv\" appended to it."
			) do |output_path|
				@output_path = output_path
		end

		super(args, option_parser)
	end
end

if __FILE__ == $PROGRAM_NAME
	script_options = LeaderboardScriptOptions.new(ARGV, OptionParser.new)

	author_summaries = author_summaries_for(
		git_repository_path: script_options.git_repository_path,
		normalized_names: script_options.normalized_names,
		banned_names: script_options.banned_names,
		banned_paths: script_options.banned_paths,
		verbose: script_options.verbose
	)

	process(
		author_summaries: author_summaries,
		output_path: script_options.output_path,
		verbose: script_options.verbose
	)
end
