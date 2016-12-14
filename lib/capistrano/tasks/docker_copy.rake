# This trick lets us access the Git plugin within `on` blocks.
docker_copy_plugin = self

namespace :docker_copy do
  desc 'Check that the build is available'
  task :check do
    docker_copy_plugin.check
  end

  desc 'Update the docker image'
  task :update do
    docker_copy_plugin.update
  end

  desc 'Copy build to releases'
  task create_release: :'docker_copy:update' do
    docker_copy_plugin.release
  end

  desc 'Determine the revision that will be deployed'
  task :set_current_revision do
    set :current_revision, docker_copy_plugin.fetch_revision
  end
end
