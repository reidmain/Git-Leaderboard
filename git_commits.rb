#!/usr/bin/env ruby

require "json"
require "optparse"

class Commit
	class FileModification
		attr_reader :path
		attr_reader :original_path
		attr_reader :additions
		attr_reader :deletions

		def initialize(path, original_path, additions, deletions)
			@path = path
			@original_path = original_path
			@additions = additions
			@deletions = deletions
		end

		def to_s
			return "+#{@additions}\t-#{@deletions}\t#{@path}"
		end
	end

	attr_reader :author_name
	attr_reader :author_email
	attr_reader :hash
	attr_reader :file_modifications
	attr_reader :additions
	attr_reader :deletions

	def initialize(author_name, author_email, hash)
		@author_name = author_name
		@author_email = author_email
		@hash = hash
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
		return "Author: #{@author_name}\nHash: #{@hash}\nAdditions: #{@additions}\nDeletions: #{@deletions}\n#{@file_modifications.join("\n")}"
	end
end

def commits_for_git_repo(git_repo, normalized_names = {}, banned_filenames)
	commits = []
	banned_filenames_regexp = Regexp.union(banned_filenames.map { |string| Regexp.new(string) })

	Dir.chdir(git_repo) do
		git_log_output = `git log --numstat --no-merges --pretty=format:'Author: %an%nEmail: %aE%nHash: %H' -z`

		git_log_output.scan(/Author: (.*)\nEmail: (.*)\nHash: (.*)[\n]?(.*)\x0/).each do |commit_match|
			author_name = commit_match[0]

			if normalized_author = normalized_names[author_name]
				author_name = normalized_author
			end

			author_email = commit_match[1]
			commit_hash = commit_match[2]

			current_commit = Commit.new(author_name, author_email, commit_hash)
			commits.push(current_commit)

			file_modifications_string = commit_match[3].split("\x0")
			i = 0
			while i < file_modifications_string.length
				file_modification_string = file_modifications_string[i]

				if file_match_data = file_modification_string.match(/^(\d+)\t+(\d+)\t(.*)/)
					additions = file_match_data[1].to_i
					deletions = file_match_data[2].to_i
					path = file_match_data[3]
					original_path = nil
					if path.empty?
						i += 2
						path = file_modifications_string[i]
						original_path = file_modifications_string[i - 1]
					end

					if path.match(banned_filenames_regexp).nil? == true
						file_modification = Commit::FileModification.new(path, original_path, additions, deletions)
						current_commit.add_file_modification(file_modification)
					end
				end

				i += 1
			end
		end
	end

	return commits
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

	commits.each do |commit|
		puts "#{commit}\n\n"
	end
end
