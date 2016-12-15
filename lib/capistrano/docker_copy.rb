require 'capistrano/scm/plugin'

class Capistrano::DockerCopy < Capistrano::SCM::Plugin
  #
  # Plugins methods
  #

  def set_defaults
    I18n.backend.store_translations(:en, capistrano: {
      revision_log_message: '%{sha} deployed as release %{release} by %{user}'
    })

    set_if_empty :docker_tag, 'latest'
    set_if_empty :docker_container_name, 'capistrano_deploy'
    set_if_empty :docker_roles, %(app)
    set_if_empty :local_temporary_root, File.expand_path('./tmp/deploy', Dir.pwd)
  end

  def register_hooks
    after 'deploy:new_release_path', 'docker_copy:create_release'
    before 'deploy:check', 'docker_copy:check'
    before 'deploy:set_current_revision', 'docker_copy:set_current_revision'
  end

  def define_tasks
    eval_rakefile File.expand_path('./tasks/docker_copy.rake', __dir__)
  end

  #
  # Attributes
  #

  def local_temporary_root
    fetch(:local_temporary_root, File.expand_path('~/tmp'))
  end

  def local_source
    File.join(local_temporary_root, 'source')
  end

  def local_archive_path
    File.join(local_temporary_root, "archive.#{release_timestamp}.tar.gz")
  end

  def remote_temporary_root
    File.join(fetch(:tmp_dir), fetch(:application))
  end

  def remote_archive_path
    File.join(remote_temporary_root, "archive.#{release_timestamp}.tar.gz")
  end


  #
  # Methods
  #

  def check
    me = self

    run_locally do
      execute :which, 'docker'
      execute :mkdir, '-p', me.local_temporary_root
    end
  end

  def update
    docker :pull, "#{fetch(:docker_repository)}:#{fetch(:docker_tag)}"
    docker :run,
      '--name', fetch(:docker_container_name),
      "-t #{fetch(:docker_repository)}:#{fetch(:docker_tag)}",
      '/bin/true'
    docker :cp, "#{fetch(:docker_container_name)}:#{fetch(:docker_source)}",
      local_source
  ensure
    docker :rm, fetch(:docker_container_name)
  end

  def release
    build_archive
    copy_to_server
  ensure
    cleanup
  end

  def fetch_revision
    fetch(:docker_tag)
  end

  def docker(*args)
    run_locally do
      execute :docker, *args
    end
  end

  private

  def build_archive
    me = self

    run_locally do
      within me.local_source do
        execute :tar, '-cpzf', me.local_archive_path, '.'
      end
    end
  end

  def copy_to_server
    me = self

    on release_roles fetch(:docker_roles) do
      execute :mkdir, '-p', me.remote_temporary_root
      upload! me.local_archive_path, me.remote_temporary_root

      execute :mkdir, '-p', release_path
      within release_path do
        execute :tar, '-xozf', me.remote_archive_path
      end
    end
  end

  def cleanup
    me = self

    run_locally do
      execute :rm, '-rf', me.local_temporary_root
    end

    on release_roles fetch(:docker_roles) do
      execute :rm, '-f', me.remote_archive_path
    end
  end
end
