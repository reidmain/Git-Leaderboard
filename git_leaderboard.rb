#!/usr/bin/env ruby

require "optparse"

require_relative "./git_commits.rb"

module Git
	# A class that represents information about all of the commits for an author in a git repository.
	class AuthorSummary
		# @return [String] the name of the author.
		attr_reader :author_name
		# @return [String] the email address of the author.
		attr_reader :author_email
		# @return [Integer] the total number of commits made by the author.
		attr_reader :number_of_commits
		# @return [Integer] the total number of lines added by the author.
		attr_reader :number_of_additions
		# @return [Integer] the total number of lines deleted by the author.
		attr_reader :number_of_deletions
		# @return [Integer] the total number of files modified by the author.
		attr_reader :number_of_files_modified

		# Initializes a new instance of {AuthorSummary}.
		#
		# @param [String] author_name The name of the author of the commit.
		# @param [String] author_email The email of the author of the commit.
		# @param [Integer] number_of_commits The total number of commits made by the author.
		# @param [Integer] number_of_additions The total number of lines added by the author.
		# @param [Integer] number_of_deletions The total number of lines deleted by the author.
		# @param [Integer] number_of_files_modified The total number of files modified by the author.
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

		# Uses the commit to increment the various values the author summary is tracking.
		#
		# This is predominantly a helper method because it would be more taxing to keep an array of all {Commit} objects for an author and then pass them into the initializer.
		#
		# @param [Commit] commit The commmit to add to the author summary.
		def append(commit:)
			@number_of_commits += 1
			@number_of_additions += commit.number_of_additions
			@number_of_deletions += commit.number_of_deletions
			@number_of_files_modified += commit.file_modifications.count
		end

		# @return [String] a human readable string representation of the author summary.
		def to_s
			return "Author: #{@author_name}\nEmail: #{author_email}\nCommits: #{@number_of_commits}\nAdditions: #{@number_of_additions}\nDeletions: #{@number_of_deletions}\nFiles Modified: #{@number_of_files_modified}"
		end
	end

	# Generates an array of {AuthorSummary} objects for a git repository.
	#
	# The {Commit}s for the repository are queried and then grouped together by their author's email addresses.
	#
	# These Commit objects may be sanitized if any of the normalization or filtering parameters are provided. By default the Commit objects will match the raw information provided by "git log".
	#
	# @param [String] git_repository_path The path to the root of the git repository to generate author summaries from.
	# @param [Hash{String => String}] normalized_email_addresses A hash where the keys are a author's email address and the values are what that email address should be normalized to. Defaults to an empty hash.
	# @param [Hash{String => String}] normalized_names A hash where the keys are a author's email address and the values are what that author's name should be normalized to. This mapping is applied after the email addresses have already been normalized by the normalized_email_addresses parameter so you should typically have to only normalize a author's name once. Defaults to an empty hash.
	# @param [Array<String>] banned_email_addresses An array of email addresses for authors whose commits should be ignored. Defaults to an empty array.
	# @param [Array<String>] banned_paths An array of regular expressions that will be evaluated against file modification paths to determine if the file modification should be omitted or not. Defaults to an empty array.
	# @param [Boolean] verbose A flag indicating if actions should be outputted to the console. Defaults to false.
	#
	# @return [Array<AuthorSummary>] An array of author summary objects.
	def self.author_summaries_for(
		git_repository_path:,
		normalized_email_addresses: {},
		normalized_names: {},
		banned_email_addresses: [],
		banned_paths: [],
		verbose: false
	)
		commits = commits_for(
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
				author_summary.append(commit: commit)
			end
		end

		return author_summaries
	end

	# Consumes an array of {AuthorSummary} objects, sorts them by number of commits and then outputs the results to a CSV file and/or the console.
	#
	# @param [Array<AuthorSummary>] author_summaries An array of author summaries to collate.
	# @param [String] output_path The path where a comma-separated values text file should be outtputed to. The extension \".csv\" will automatically be  appended.
	# @param [Boolean] verbose A flag indicating if actions should be outputted to the console. Defaults to false.
	def self.output_leaderboard_for(
		author_summaries:,
		output_path:,
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

	# Generates a leaderboard for a git repository.
	#
	# The leaderboard is constructed by querying all of the {Commit}s for the repository (normalizing and filtering as necessary) and then grouping them by author's email address. The results can be either outputted to a csv file and/or the console.
	#
	# @param [String] git_repository_path The path to the root of the git repository to generate the leaderboard for.
	# @param [Hash{String => String}] normalized_email_addresses A hash where the keys are a author's email address and the values are what that email address should be normalized to.
	# @param [Hash{String => String}] normalized_names A hash where the keys are a author's email address and the values are what that author's name should be normalized to. This mapping is applied after the email addresses have already been normalized by the normalized_email_addresses parameter so you should typically have to only normalize a author's name once.
	# @param [Array<String>] banned_email_addresses An array of email addresses for authors whose commits should be ignored.
	# @param [Array<String>] banned_paths An array of regular expressions that will be evaluated against file modification paths to determine if the file modification should be omitted or not.
	# @param [String, nil] output_path The path where a comma-separated values text file should be outtputed to. The extension \".csv\" will automatically be  appended.
	# @param [Boolean] output_raw A flag indicating if a second leaderboard with no filtering should also be generatated.
	# @param [Boolean] verbose A flag indicating if actions should be outputted to the console.
	def self.generate_leaderboard_for(
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

		output_leaderboard_for(
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

			output_leaderboard_for(
				author_summaries: raw_author_summaries,
				output_path: "#{output_path}_raw",
				verbose: false
			)
		end
	end
end

# A class to represent all of the arguments that can be passed into the git_leaderboards.rb script via the command line.
#
# While it's primary function is to parse arguments passed in from the command line it is also designed to be subclassed. This is to make it easier for scripts that want to leverage git_leaderboards.rb to gather the same type of information.
class LeaderboardScriptOptions < CommitsScriptOptions
	# @return [String, nil] the value of the "--output-path" argument.
	attr_reader :output_path
	# @return [Boolean] the value of the "--output-raw" argument.
	attr_reader :output_raw

	# Initializes a new instance of {LeaderboardScriptOptions} that will automatically parse command line arguments.
	#
	# @param [Array<String>] args The arguments that were passed into the command line.
	# @param [OptionParser] option_parser An OptionParser to use to parse the args parameter.
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

	Git.generate_leaderboard_for(
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
