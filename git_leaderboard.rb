#!/usr/bin/env ruby

require "optparse"

require_relative "./git_commits.rb"

module Git
	class AuthorSummary
		attr_reader :author_name
		attr_reader :author_email
		attr_reader :number_of_commits
		attr_reader :number_of_additions
		attr_reader :number_of_deletions
		attr_reader :number_of_files_modified

		def initialize(
			author_name:,
			author_email:,
			number_of_commits: 0,
			number_of_additions: 0,
			number_of_deletions:0,
			number_of_files_modified: 0
		)
			@author_name = author_name
			@author_email = author_email
			@number_of_commits = number_of_commits
			@number_of_additions = number_of_additions
			@number_of_deletions = number_of_deletions
			@number_of_files_modified = number_of_files_modified
		end

		def append(commit)
			@number_of_commits += 1
			@number_of_additions += commit.number_of_additions
			@number_of_deletions += commit.number_of_deletions
			@number_of_files_modified += commit.file_modifications.count
		end

		def to_s
			return "Author: #{@author_name}\nEmail: #{author_email}\nCommits: #{@number_of_commits}\nAdditions: #{@number_of_additions}\nDeletions: #{@number_of_deletions}\nFiles Modified: #{@number_of_files_modified}"
		end
	end

	def self.author_summaries_for(
		git_repository_path:,
		normalized_email_addresses: {},
		normalized_names: {},
		banned_email_addresses: [],
		banned_paths: [],
		verbose: false
	)
		commits = commits_for_git_repo(
			git_repository_path: git_repository_path,
			normalized_email_addresses: normalized_email_addresses,
			normalized_names: normalized_names,
			banned_email_addresses: banned_email_addresses,
			banned_paths: banned_paths,
			verbose: verbose
		)

		author_summaries = {}

		commits.each do |commit|
			author_email = commit.author_email

			author_summary = author_summaries[author_email]
			if author_summary == nil
				author_summary = AuthorSummary.new(
					author_name: commit.author_name,
					author_email: author_email
				)
				author_summaries[author_email] = author_summary
			end

			if commit.file_modifications.count > 0
				author_summary.append(commit)
			end
		end

		return author_summaries
	end

	def self.collate(
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
			csv_file.write("Author,Email,Commits,% of Commits,Additions,% of Additions,Deletions,% of Deletions,Files Modified,% of Files Modified")
			csv_file.write("\n,,#{total_commits},100,#{total_additions},100,#{total_deletions},100,#{total_files_modified},100")
		end

		sorted_author_summaries_by_number_of_commits.each do |author_summary|
			author_name = author_summary.author_name
			author_email = author_summary.author_email
			number_of_commits = author_summary.number_of_commits
			number_of_additions = author_summary.number_of_additions
			number_of_deletions = author_summary.number_of_deletions
			number_of_files_modified = author_summary.number_of_files_modified

			commits_percentage = (number_of_commits / total_commits.to_f * 100).round(2)
			additions_percentage = (number_of_additions / total_additions.to_f * 100).round(2)
			deletions_percentage = (number_of_deletions / total_deletions.to_f * 100).round(2)
			files_modified_percentage = (number_of_files_modified / total_files_modified.to_f * 100).round(2)

			if verbose
				puts "#{author_name} (#{author_email})"
				puts "\tCommits: #{number_of_commits} (#{commits_percentage}%)"
				puts "\tAdditions: #{number_of_additions} (#{additions_percentage}%)"
				puts "\tDeletions: #{number_of_deletions} (#{deletions_percentage}%)"
				puts "\tFiles Modified: #{number_of_files_modified} (#{files_modified_percentage}%)"
			end

			if (csv_file)
				csv_file.write("\n#{author_name},#{author_email},#{number_of_commits},#{commits_percentage},#{number_of_additions},#{additions_percentage},#{number_of_deletions},#{deletions_percentage},#{number_of_files_modified},#{files_modified_percentage}")
			end
		end

		if (csv_file)
			csv_file.close
		end
	end

	def self.leaderboard_for(
		git_repository_path:,
		normalized_email_addresses:,
		normalized_names:,
		banned_email_addresses:,
		banned_paths:,
		output_path:,
		output_raw:,
		verbose:
	)
		author_summaries = author_summaries_for(
			git_repository_path: git_repository_path,
			normalized_email_addresses: normalized_email_addresses,
			normalized_names: normalized_names,
			banned_email_addresses: banned_email_addresses,
			banned_paths: banned_paths,
			verbose: verbose
		)

		process(
			author_summaries: author_summaries,
			output_path: output_path,
			verbose: verbose
		)

		if output_raw and output_path.nil? == false
			raw_author_summaries = author_summaries_for(
				git_repository_path: git_repository_path,
				normalized_email_addresses: normalized_email_addresses,
				normalized_names: normalized_names,
				verbose: false
			)

			process(
				author_summaries: raw_author_summaries,
				output_path: "#{output_path}_raw",
				verbose: false
			)
		end
	end
end

class LeaderboardScriptOptions < CommitsScriptOptions
	attr_reader :output_path
	attr_reader :output_raw

	def initialize(
		args:, 
		option_parser:
	)
		@output_raw = true

		option_parser.on(
			"--output-path PATH",
			String,
			"The path that the script should save its output to.",
			"The output will be a comma-separated values text file and as such will automatically have \".csv\" appended to it."
		) do |output_path|
			@output_path = output_path
		end

		option_parser.on(
			"--output-raw BOOL",
			"A switch to determine if the unfiltered leaderboard should also be outputted.",
			"Defaults to true.",
			TrueClass
		) do |flag|
			@verbose = flag
		end

		super(
			args: args, 
			option_parser: option_parser
		)
	end
end

if __FILE__ == $PROGRAM_NAME
	script_options = LeaderboardScriptOptions.new(
		args: ARGV, 
		option_parser: OptionParser.new
	)

	leaderboard_for(
		git_repository_path: script_options.git_repository_path,
		normalized_email_addresses: script_options.normalized_email_addresses,
		normalized_names: script_options.normalized_names,
		banned_email_addresses: script_options.banned_email_addresses,
		banned_paths: script_options.banned_paths,
		output_path: script_options.output_path,
		output_raw: script_options.output_raw,
		verbose: script_options.verbose
	)
end
