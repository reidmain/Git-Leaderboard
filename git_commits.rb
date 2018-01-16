#!/usr/bin/env ruby

require "json"
require "optparse"

class Commit
	class FileModification
		attr_reader :filename
		attr_reader :additions
		attr_reader :deletions

		def initialize(filename, additions, deletions)
			@filename = filename
			@additions = additions
			@deletions = deletions
		end

		def to_s
			return "+#{@additions}\t-#{@deletions}\t#{@filename}"
		end
	end

	attr_reader :author_name
	attr_accessor :author_email
	attr_reader :file_modifications
	attr_reader :additions
	attr_reader :deletions

	def initialize(author_name)
		@author_name = author_name
		@file_modifications = []
		@additions = 0
		@deletions = 0
	end

	def add_file_modification(file_modification)
		file_modifications.push(file_modification)
		@additions += file_modification.additions
		@deletions += file_modification.deletions
	end

	def to_s
		return "Author: #{@author_name}\nEmail: #{@author_email}\nAdditions: #{@additions}\nDeletions: #{@deletions}\n#{@file_modifications.join("\n")}"
	end
end

def commits_for_git_repo(git_repo, normalized_names = {})
	commits = []

	Dir.chdir(git_repo) do
		# We can ignore merges because those shouldn't be making any additional changes.
		git_log = `git log --numstat --no-merges --pretty=format:'Author: %an%nEmail: %aE'`

		current_commit = nil
		git_log.each_line do |line|
			# To detect if we are looking at a new commit we must look for the 'Author:' line.
			if author_match_data = line.match(/^Author: (.+)/)
				author = author_match_data[1]
				if normalized_author = normalized_names[author]
					author = normalized_author
				end
				current_commit = Commit.new(author)

				commits.push(current_commit)
			end

			# If we detect the email line, add it to the current commit.
			if email_match_data = line.match(/^Email: (.+)/)
				email = email_match_data[1]
				current_commit.author_email = email
			end

			# If we find a line that represents a file changed, append it to the current commit.
			if file_modified_match_data = line.match(/^(\d+)\t+(\d+)\t(.*)/)
				additions = file_modified_match_data[1].to_i
				deletions = file_modified_match_data[2].to_i
				filename = file_modified_match_data[3]
				file_modification = Commit::FileModification.new(filename, additions, deletions)
				current_commit.add_file_modification(file_modification)
			end
		end
	end

	return commits
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

	commits.each do |commit|
		puts "#{commit}\n\n"
	end
end
