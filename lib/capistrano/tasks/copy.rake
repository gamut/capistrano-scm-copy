namespace :copy do

  archive_name = "archive.tar.gz"
  include_dir  = fetch(:include_dir) || "*"
  exclude_dir  = Array(fetch(:exclude_dir))
  limit_to_git = fetch(:limit_to_git) || false

  exclude_args = exclude_dir.map { |dir| "--exclude '#{dir}'"}

  # Defalut to :all roles
  tar_roles = fetch(:tar_roles, :all)

  tar_verbose = fetch(:tar_verbose, true) ? "v" : ""

  git_repos = limit_to_git ? Dir.glob("**/.git") : []

  desc "Archive files to #{archive_name}"
  if git_repos.any?
    file_array = Dir.glob("**/.git").map do |git_path|
      repo_path = File.dirname git_path
      `git --git-dir "#{git_path}" ls-files --exclude-standard`.split("\n").map do |git_file|
        File.join repo_path, git_file
      end
    end
    file_list =  FileList.new(file_array)
  else
    file_list = FileList[include_dir]
  end

  file archive_name => file_list.exclude(archive_name) do |t|
    cmd = ["tar -ch#{tar_verbose}zf #{t.name}", *exclude_args, *t.prerequisites]
    sh cmd.join(' ')
  end

  desc "Deploy #{archive_name} to release_path"
  task :deploy => archive_name do |t|
    tarball = t.prerequisites.first

    on roles(tar_roles) do
      # Make sure the release directory exists
      puts "==> release_path: #{release_path} is created on #{tar_roles} roles <=="
      execute :mkdir, "-p", release_path

      # Create a temporary file on the server
      tmp_file = capture("mktemp")

      # Upload the archive, extract it and finally remove the tmp_file
      upload!(tarball, tmp_file)
      execute :tar, "-xzf", tmp_file, "-C", release_path
      execute :rm, tmp_file
    end
  end

  task :clean do |t|
    # Delete the local archive
    File.delete archive_name if File.exists? archive_name
  end

  after 'deploy:finished', 'copy:clean'

  task :create_release => :deploy
  task :check
  task :set_current_revision

end
